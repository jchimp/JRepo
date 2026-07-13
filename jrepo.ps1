<#
.SYNOPSIS
    JRepo - A dead-simple file sync tool for developers.

.DESCRIPTION
    Usage:
        jrepo push <UNC-PATH> [--all] [--force] [--dry-run]
        jrepo pull <UNC-PATH> [--all] [--force] [--dry-run]
        jrepo init
        jrepo help

    Commands:
        push    Mirror the current directory TO a remote path (Robocopy /MIR)
        pull    Mirror a remote path INTO the current directory (Robocopy /MIR)
        init    Create a default .jrepoignore in the current directory
        help    Show this help message

    Flags:
        --all       Sync ALL files; ignore .jrepoignore exclusions
        --force     Wipe destination first, then sync clean (prompts 'yes' to confirm)
        --dry-run   Preview only - no files are copied or deleted

.EXAMPLE
    jrepo push \\nas01\repos\myapp

.EXAMPLE
    jrepo push \\nas01\repos\myapp --dry-run

.EXAMPLE
    jrepo pull \\nas01\repos\myapp --force

.EXAMPLE
    jrepo init
#>

$ErrorActionPreference = "Stop"

# ===================================================================
#  Helpers
# ===================================================================

$script:Rule = "------------------------------------------------------------"

function Write-JRepo {
    param([string]$Level, [string]$Message)
    $colours = @{ INFO = "Cyan"; OK = "Green"; WARN = "Yellow"; ERR = "Red" }
    $colour = "White"
    if ($colours.ContainsKey($Level)) { $colour = $colours[$Level] }
    Write-Host $Message -ForegroundColor $colour
}

function Write-Rule { Write-JRepo "INFO" $script:Rule }

# Aligned "Label   value" line (label padded so values line up).
function Write-KV {
    param([string]$Label, [string]$Value)
    Write-JRepo "INFO" ("  {0,-8} {1}" -f $Label, $Value)
}

function Get-DirStats {
    param([string]$Path)
    try {
        if (-not (Test-Path $Path)) {
            return @{ Files = 0; Bytes = [long]0 }
        }
        $items = Get-ChildItem -Path $Path -Recurse -File -Force -ErrorAction SilentlyContinue
        if (-not $items) {
            return @{ Files = 0; Bytes = [long]0 }
        }
        $measure = $items | Measure-Object -Property Length -Sum
        return @{
            Files = [int]$measure.Count
            Bytes = [long]$measure.Sum
        }
    }
    catch {
        return @{ Files = 0; Bytes = [long]0 }
    }
}

function Format-Bytes {
    param([long]$Bytes)
    if     ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    elseif ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    elseif ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    else                    { return "$Bytes B" }
}

function Format-Delta {
    param([long]$Before, [long]$After)
    $d = $After - $Before
    if     ($d -gt 0) { return "+$d" }
    elseif ($d -lt 0) { return "$d" }
    else              { return "0" }
}

function Show-Help {
    Write-JRepo "INFO" ""
    Write-JRepo "INFO" "  JRepo - A dead-simple file sync tool"
    Write-JRepo "INFO" ""
    Write-JRepo "INFO" "  Usage:"
    Write-JRepo "INFO" "    jrepo push <UNC-PATH> [--all] [--force] [--dry-run]"
    Write-JRepo "INFO" "    jrepo pull <UNC-PATH> [--all] [--force] [--dry-run]"
    Write-JRepo "INFO" "    jrepo init"
    Write-JRepo "INFO" "    jrepo help"
    Write-JRepo "INFO" ""
    Write-JRepo "INFO" "  Commands:"
    Write-JRepo "INFO" "    push    Mirror current directory TO a remote path"
    Write-JRepo "INFO" "    pull    Mirror a remote path INTO current directory"
    Write-JRepo "INFO" "    init    Create a default .jrepoignore"
    Write-JRepo "INFO" "    help    Show this help message"
    Write-JRepo "INFO" ""
    Write-JRepo "INFO" "  Flags:"
    Write-JRepo "INFO" "    --all       Sync ALL files (ignore .jrepoignore)"
    Write-JRepo "INFO" "    --force     Wipe destination first (prompts to confirm)"
    Write-JRepo "INFO" "    --dry-run   Preview only, no changes made"
    Write-JRepo "INFO" ""
}

function Write-DefaultIgnore {
    param([string]$FilePath)
    $content = @"
# ---------------------------------------------
#  .jrepoignore - JRepo exclusion rules
#
#  Pattern guide:
#    /dirname      Directory  (leading /)
#    dirname/      Directory  (trailing /)
#    *.ext         Extension / wildcard file
#    name.ext      Specific file (has a dot)
#    name          Ambiguous -> excluded as both dir AND file
#
#  Lines starting with # are comments.
#  Blank lines are ignored.
# ---------------------------------------------

# Python
*.pyc
/__pycache__

# Node
/node_modules

# Virtual environments
/.venv
/venv

# Environment / secrets
.env
*.key
*.crt
*.pem

# Logs
*.log

# Temp files
*.tmp
*~
*.old

# OS junk
Thumbs.db
.DS_Store

# Version control
/.git
/.svn

# Data & build directories
/data
/dist
/build
/.vscode

# Docker volumes
/volumes
"@
    Set-Content -Path $FilePath -Value $content -Encoding UTF8
}

# ===================================================================
#  Parse command and arguments
# ===================================================================

$Command    = $null
$RemotePath = $null
$All        = $false
$Force      = $false
$DryRun     = $false
$roboExit   = 0
$confirm    = ""

if ($args.Count -eq 0) {
    Show-Help
    exit 0
}

$Command = ([string]$args[0]).ToLower()

if ($Command -notin @("push", "pull", "init", "help")) {
    Write-JRepo "ERR" "Unknown command: $Command"
    Write-JRepo "INFO" "Commands: push, pull, init, help"
    exit 1
}

if ($Command -eq "help") {
    Show-Help
    exit 0
}

# Parse remaining args
$i = 1
while ($i -lt $args.Count) {
    $a = [string]$args[$i]
    if ($a -eq "--all")     { $All    = $true;  $i++; continue }
    if ($a -eq "--force")   { $Force  = $true;  $i++; continue }
    if ($a -eq "--dry-run") { $DryRun = $true;  $i++; continue }
    if ($a.StartsWith("--")) {
        Write-JRepo "ERR" "Unknown flag: $a"
        exit 1
    }
    if (-not $RemotePath) {
        $RemotePath = $a
    } else {
        Write-JRepo "ERR" "Unexpected argument: $a"
        exit 1
    }
    $i++
}

# ===================================================================
#  INIT command
# ===================================================================

if ($Command -eq "init") {
    $ProjectDir = (Get-Location).Path
    $IgnoreFile = Join-Path $ProjectDir ".jrepoignore"

    Write-JRepo "INFO" "Initializing JRepo in: $ProjectDir"

    if (Test-Path $IgnoreFile) {
        Write-JRepo "WARN" ".jrepoignore already exists at:"
        Write-JRepo "WARN" "  $IgnoreFile"
        $confirm = Read-Host "Overwrite? (y/N)"
        if ($confirm -notmatch '^(y|yes)$') {
            Write-JRepo "INFO" "Aborted. Existing file unchanged."
            exit 0
        }
    }

    Write-DefaultIgnore $IgnoreFile

    Write-JRepo "OK" "Created .jrepoignore at:"
    Write-JRepo "OK" "  $IgnoreFile"
    Write-JRepo "INFO" "Edit this file to customize exclusions for your project."
    exit 0
}

# ===================================================================
#  PUSH / PULL  — require a remote path
# ===================================================================

if (-not $RemotePath) {
    Write-JRepo "ERR" "No path supplied."
    Write-JRepo "INFO" "Usage:  jrepo $Command <UNC-PATH> [--all] [--force] [--dry-run]"
    exit 1
}

$ProjectDir = (Get-Location).Path

# Determine direction
if ($Command -eq "push") {
    $Op           = "Push"
    $SourceDir    = $ProjectDir
    $DestDir      = $RemotePath
    $SourceLabel  = "Source"
    $DestLabel    = "Target"
    $SummaryTitle = "Push Summary"
    $ForceTarget  = "target"
}
else {
    # pull — verify remote exists
    if (-not (Test-Path $RemotePath)) {
        Write-JRepo "ERR" "Source path does not exist: $RemotePath"
        exit 1
    }
    $Op           = "Pull"
    $SourceDir    = $RemotePath
    $DestDir      = $ProjectDir
    $SourceLabel  = "Source"
    $DestLabel    = "Local"
    $SummaryTitle = "Pull Summary"
    $ForceTarget  = "local directory"
}

# -- Header
Write-Host ""
Write-Rule
Write-JRepo "INFO" "  JRepo $Op"
Write-Rule
Write-KV "${SourceLabel}:" $SourceDir
Write-KV "${DestLabel}:"   $DestDir

# ===================================================================
#  Folder-name mismatch check
# ===================================================================

$localFolder  = Split-Path $ProjectDir -Leaf
$remoteFolder = Split-Path $RemotePath -Leaf

if ($localFolder -ne $remoteFolder) {
    Write-JRepo "WARN" "Folder name mismatch!"
    Write-JRepo "WARN" "  Local:   $ProjectDir  ($localFolder)"
    Write-JRepo "WARN" "  Remote:  $RemotePath  ($remoteFolder)"
    if (-not $DryRun) {
        $confirm = Read-Host "Folder names differ. Continue? (y/N)"
        if ($confirm -notmatch '^(y|yes)$') {
            Write-JRepo "INFO" "Aborted by user."
            exit 0
        }
    }
}

# ===================================================================
#  Parse .jrepoignore  (skipped when --all)
# ===================================================================

$xDirs  = @()
$xFiles = @()
$IgnoreFile = Join-Path $ProjectDir ".jrepoignore"

if ($All) {
    Write-JRepo "INFO" "Syncing ALL files (ignoring .jrepoignore)."
}
else {
    if (Test-Path $IgnoreFile) {
        Write-JRepo "INFO" "Reading .jrepoignore..."
        $lines = Get-Content $IgnoreFile
        foreach ($rawLine in $lines) {
            $entry = $rawLine.Trim()
            if ([string]::IsNullOrWhiteSpace($entry)) { continue }
            if ($entry.StartsWith("#")) { continue }

            if ($entry.StartsWith("/")) {
                $xDirs += $entry.TrimStart("/")
            }
            elseif ($entry.EndsWith("/")) {
                $xDirs += $entry.TrimEnd("/")
            }
            elseif ($entry.StartsWith("*")) {
                $xFiles += $entry
            }
            elseif ($entry.Contains(".")) {
                $xFiles += $entry
            }
            else {
                $xDirs  += $entry
                $xFiles += $entry
            }
        }
        Write-JRepo "INFO" ("Excluded dirs : " + ($xDirs -join ", "))
        Write-JRepo "INFO" ("Excluded files: " + ($xFiles -join ", "))
    }
    else {
        Write-JRepo "ERR" "No .jrepoignore file found. Use --all to sync without exclusions."
        exit 1
    }
}

# ===================================================================
#  Force mode
# ===================================================================

$IgnoreBackup = $null

if ($Force) {
    if ($DryRun) {
        Write-JRepo "WARN" ""
        Write-JRepo "WARN" "  [DRY RUN] ================================================"
        Write-JRepo "WARN" "  Would DELETE all contents at ${ForceTarget}:"
        Write-JRepo "WARN" "    $DestDir"
        Write-JRepo "WARN" "  Then $Command a fresh copy."
        Write-JRepo "WARN" "  =========================================================="
    }
    else {
        Write-JRepo "WARN" ""
        Write-JRepo "WARN" "  =========================================================="
        Write-JRepo "WARN" "  WARNING: --force will DELETE all contents at ${ForceTarget}!"
        Write-JRepo "WARN" "  =========================================================="
        Write-JRepo "WARN" "  $DestDir"
        Write-JRepo "WARN" ""
        Write-JRepo "WARN" "  Then $Command a fresh copy from:"
        Write-JRepo "WARN" "  $SourceDir"
        Write-JRepo "WARN" ""
        $confirm = Read-Host "Type 'yes' to confirm, anything else to abort"
        if ($confirm -ne "yes") {
            Write-JRepo "INFO" "Aborted by user."
            exit 0
        }

        # For pull --force: back up .jrepoignore before wiping local dir
        if ($Command -eq "pull" -and (-not $All) -and (Test-Path $IgnoreFile)) {
            $IgnoreBackup = Join-Path $env:TEMP "jrepo-ignore-backup.tmp"
            Copy-Item -Path $IgnoreFile -Destination $IgnoreBackup -Force
            Write-JRepo "INFO" "Backed up .jrepoignore."
        }

        if (Test-Path $DestDir) {
            Get-ChildItem -Path $DestDir -Force | Remove-Item -Recurse -Force
            Write-JRepo "OK" "Destination wiped."
        }
        else {
            Write-JRepo "INFO" "Destination does not exist yet; nothing to wipe."
        }

        # Restore .jrepoignore after wipe
        if ($IgnoreBackup -and (Test-Path $IgnoreBackup)) {
            Copy-Item -Path $IgnoreBackup -Destination $IgnoreFile -Force
            Remove-Item -Path $IgnoreBackup -Force
            Write-JRepo "INFO" "Restored .jrepoignore."
        }
    }
}

# ===================================================================
#  Pre-stats
# ===================================================================

$preStats  = Get-DirStats $DestDir
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# ===================================================================
#  Build Robocopy options
# ===================================================================

# /NP no progress, /NJH no job header, /NJS no job summary table.
# Normal run also adds /NDL /NFL to suppress the per-file/dir listing; the
# summary footer reports the totals. Dry-run keeps the listing so the preview
# shows what would change.
$roboFlags = @("/MIR", "/R:2", "/W:1", "/NP", "/NJH", "/NJS")
if ($DryRun) {
    $roboFlags += "/L"
    Write-JRepo "WARN" "[DRY RUN] No files will be copied."
}
else {
    $roboFlags += @("/NDL", "/NFL")
}

$xdArg = @()
$xfArg = @()
if (-not $All) {
    if ($xDirs.Count  -gt 0) { $xdArg = @("/XD") + $xDirs  }
    if ($xFiles.Count -gt 0) { $xfArg = @("/XF") + $xFiles }
}

# ===================================================================
#  Run Robocopy
# ===================================================================

Write-JRepo "INFO" ""
Write-JRepo "INFO" "Syncing..."

ROBOCOPY.exe $SourceDir $DestDir @roboFlags @xdArg @xfArg

$roboExit = $LASTEXITCODE
$stopwatch.Stop()

# ===================================================================
#  Post-stats & summary
# ===================================================================

if ($DryRun) { $postStats = $preStats }
else         { $postStats = Get-DirStats $DestDir }

$elapsed    = "{0:N1}" -f $stopwatch.Elapsed.TotalSeconds
$fileDelta  = Format-Delta $preStats.Files $postStats.Files
$bytesDelta = Format-Delta $preStats.Bytes $postStats.Bytes

$preSize  = Format-Bytes $preStats.Bytes
$postSize = Format-Bytes $postStats.Bytes

Write-Host ""
Write-Rule
Write-JRepo "INFO" "  $SummaryTitle"
Write-Rule
Write-KV "${SourceLabel}:" $SourceDir
Write-KV "${DestLabel}:"   $DestDir
Write-KV "Files:" "$($preStats.Files) -> $($postStats.Files)  ($fileDelta)"
Write-KV "Size:"  "$preSize -> $postSize  ($bytesDelta bytes)"
Write-KV "Time:"  "${elapsed}s"
Write-Rule

if ($roboExit -lt 8) {
    if ($DryRun) { Write-JRepo "WARN" "[DRY RUN] Complete - no changes were made." }
    else         { Write-JRepo "OK"   "$SummaryTitle - completed successfully." }
    exit 0
}
else {
    Write-JRepo "ERR" "Robocopy failed with exit code: $roboExit"
    exit $roboExit
}
