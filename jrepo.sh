#!/usr/bin/env bash
# ===================================================================
#  JRepo - A dead-simple file sync tool for developers.
#
#  Usage:
#      jrepo push <PATH> [--all] [--force] [--dry-run]
#      jrepo pull <PATH> [--all] [--force] [--dry-run] [--no-eol]
#      jrepo init
#      jrepo help
#
#  Commands:
#      push    Mirror current directory TO a remote path (rsync)
#      pull    Mirror a remote path INTO current directory (rsync)
#      init    Create a default .jrepoignore
#      help    Show this help message
# ===================================================================
set -euo pipefail

# ===================================================================
#  Helpers
# ===================================================================

_c_reset="\033[0m"
_c_cyan="\033[36m"
_c_green="\033[32m"
_c_yellow="\033[33m"
_c_red="\033[31m"
_c_gray="\033[90m"

_rule="------------------------------------------------------------"

info()  { echo -e "${_c_cyan}$*${_c_reset}"; }
ok()    { echo -e "${_c_green}$*${_c_reset}"; }
warn()  { echo -e "${_c_yellow}$*${_c_reset}"; }
err()   { echo -e "${_c_red}$*${_c_reset}" >&2; }

# Aligned "Label   value" line (label padded so values line up).
kv()    { info "$(printf '  %-8s %s' "$1" "$2")"; }

# Header / footer wrap the (quiet) copy step.
rule()  { info "$_rule"; }

get_file_count() {
    if [[ -d "$1" ]]; then
        find "$1" -type f 2>/dev/null | wc -l | tr -d ' '
    else
        echo 0
    fi
}

get_dir_bytes() {
    if [[ -d "$1" ]]; then
        local b
        b=$(du -sb "$1" 2>/dev/null | cut -f1)
        echo "${b:-0}"
    else
        echo 0
    fi
}

format_bytes() {
    local bytes="$1"
    if   (( bytes >= 1073741824 )); then echo "$(echo "scale=2; $bytes / 1073741824" | bc) GB"
    elif (( bytes >= 1048576 ));    then echo "$(echo "scale=2; $bytes / 1048576"    | bc) MB"
    elif (( bytes >= 1024 ));       then echo "$(echo "scale=2; $bytes / 1024"       | bc) KB"
    else                                 echo "${bytes} B"
    fi
}

format_delta() {
    local d=$(( $2 - $1 ))
    if   (( d > 0 )); then echo "+${d}"
    elif (( d < 0 )); then echo "${d}"
    else                    echo "0"
    fi
}

fix_line_endings() {
    local dir="$1"
    local scanned=0
    local fixed=0

    while IFS= read -r -d '' f; do
        local mime
        mime=$(file -b --mime-type "$f" 2>/dev/null || true)
        if [[ "$mime" == text/* ]]; then
            scanned=$((scanned + 1))
            if grep -cP '\r$' "$f" >/dev/null 2>&1; then
                sed -i 's/\r$//' "$f"
                fixed=$((fixed + 1))
            fi
        fi
    done < <(find "$dir" -type f -print0 2>/dev/null)

    if (( fixed > 0 )); then
        info "Line endings: scanned $scanned text files, fixed CRLF->LF in $fixed file(s)."
    else
        info "Line endings: scanned $scanned text files. All OK."
    fi
}

# After a pull, files land as 644 (see --chmod above). Restore the execute bit
# on real scripts: anything named *.sh / *.bash, or whose first two bytes are
# a shebang (#!).
restore_exec_bits() {
    local dir="$1"
    local marked=0

    while IFS= read -r -d '' f; do
        case "$f" in
            *.sh|*.bash) chmod +x "$f"; marked=$((marked + 1)); continue ;;
        esac
        if [[ "$(head -c2 "$f" 2>/dev/null)" == '#!' ]]; then
            chmod +x "$f"
            marked=$((marked + 1))
        fi
    done < <(find "$dir" -type f -print0 2>/dev/null)

    if (( marked > 0 )); then
        info "Exec bits: marked $marked script(s) executable."
    else
        info "Exec bits: no scripts found."
    fi
}

show_help() {
    info ""
    info "  JRepo - A dead-simple file sync tool"
    info ""
    info "  Usage:"
    info "    jrepo push <PATH> [--all] [--force] [--dry-run]"
    info "    jrepo pull <PATH> [--all] [--force] [--dry-run] [--no-eol]"
    info "    jrepo init"
    info "    jrepo help"
    info ""
    info "  Commands:"
    info "    push    Mirror current directory TO a remote path"
    info "    pull    Mirror a remote path INTO current directory"
    info "    init    Create a default .jrepoignore"
    info "    help    Show this help message"
    info ""
    info "  Flags:"
    info "    --all       Sync ALL files (ignore .jrepoignore)"
    info "    --force     Wipe destination first (prompts to confirm)"
    info "    --dry-run   Preview only, no changes made"
    info "    --no-eol    Skip CRLF->LF fix (pull only)"
    info ""
    info "  Pull normalizes perms to 644 (dirs 755) and re-marks"
    info "  scripts (*.sh / shebang) executable."
    info ""
}

write_default_ignore() {
    cat > "$1" << 'EOF'
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
EOF
}

# ===================================================================
#  Parse command and arguments
# ===================================================================

COMMAND=""
REMOTE_PATH=""
ALL=false
FORCE=false
DRY_RUN=false
NO_EOL=false

if [[ $# -eq 0 ]]; then
    show_help
    exit 0
fi

COMMAND="$1"
shift

case "$COMMAND" in
    push|pull|init|help) ;;
    *)
        err "Unknown command: $COMMAND"
        info "Commands: push, pull, init, help"
        exit 1
        ;;
esac

if [[ "$COMMAND" == "help" ]]; then
    show_help
    exit 0
fi

# Parse remaining args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)     ALL=true;     shift ;;
        --force)   FORCE=true;   shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --no-eol)  NO_EOL=true;  shift ;;
        --*)       err "Unknown flag: $1"; exit 1 ;;
        *)
            if [[ -z "$REMOTE_PATH" ]]; then REMOTE_PATH="$1"
            else err "Unexpected argument: $1"; exit 1
            fi
            shift ;;
    esac
done

# ===================================================================
#  INIT command
# ===================================================================

if [[ "$COMMAND" == "init" ]]; then
    PROJECT_DIR="$(pwd)"
    IGNORE_FILE="$PROJECT_DIR/.jrepoignore"

    info "Initializing JRepo in: $PROJECT_DIR"

    if [[ -f "$IGNORE_FILE" ]]; then
        warn ".jrepoignore already exists at:"
        warn "  $IGNORE_FILE"
        read -rp "Overwrite? (y/N): " confirm
        if [[ ! "$confirm" =~ ^(y|yes|Y|Yes)$ ]]; then
            info "Aborted. Existing file unchanged."
            exit 0
        fi
    fi

    write_default_ignore "$IGNORE_FILE"

    ok "Created .jrepoignore at:"
    ok "  $IGNORE_FILE"
    info "Edit this file to customize exclusions for your project."
    exit 0
fi

# ===================================================================
#  PUSH / PULL  — require a path
# ===================================================================

if [[ -z "$REMOTE_PATH" ]]; then
    err "No path supplied."
    info "Usage:  jrepo $COMMAND <PATH> [--all] [--force] [--dry-run]"
    exit 1
fi

PROJECT_DIR="$(pwd)"
IGNORE_FILE="$PROJECT_DIR/.jrepoignore"

# Determine direction
if [[ "$COMMAND" == "push" ]]; then
    SOURCE_DIR="$PROJECT_DIR"
    DEST_DIR="$REMOTE_PATH"
    OP="Push"
    SOURCE_LABEL="Source"
    DEST_LABEL="Target"
    SUMMARY_TITLE="Push Summary"
    FORCE_TARGET="target"
else
    # pull — verify remote exists
    if [[ ! -d "$REMOTE_PATH" ]]; then
        err "Source path does not exist: $REMOTE_PATH"
        exit 1
    fi
    SOURCE_DIR="$REMOTE_PATH"
    DEST_DIR="$PROJECT_DIR"
    OP="Pull"
    SOURCE_LABEL="Source"
    DEST_LABEL="Local"
    SUMMARY_TITLE="Pull Summary"
    FORCE_TARGET="local directory"
fi

# -- Header
echo ""
rule
info "  JRepo $OP"
rule
kv "${SOURCE_LABEL}:" "$SOURCE_DIR"
kv "${DEST_LABEL}:"   "$DEST_DIR"

# ===================================================================
#  Folder-name mismatch check
# ===================================================================

local_folder=$(basename "$PROJECT_DIR")
remote_folder=$(basename "${REMOTE_PATH%/}")

if [[ "$local_folder" != "$remote_folder" ]]; then
    warn "Folder name mismatch!"
    warn "  Local:   $PROJECT_DIR  ($local_folder)"
    warn "  Remote:  $REMOTE_PATH  ($remote_folder)"
    if [[ "$DRY_RUN" != true ]]; then
        read -rp "Folder names differ. Continue? (y/N): " confirm
        if [[ ! "$confirm" =~ ^(y|yes|Y|Yes)$ ]]; then
            info "Aborted by user."
            exit 0
        fi
    fi
fi

# ===================================================================
#  Parse .jrepoignore
# ===================================================================

TEMP_IGNORE=""

if [[ "$ALL" == true ]]; then
    info "Syncing ALL files (ignoring .jrepoignore)."
else
    if [[ ! -f "$IGNORE_FILE" ]]; then
        err "No .jrepoignore file found. Use --all to sync without exclusions."
        exit 1
    fi
    info "Reading .jrepoignore..."
fi

# ===================================================================
#  Force mode
# ===================================================================

if [[ "$FORCE" == true ]]; then
    if [[ "$DRY_RUN" == true ]]; then
        warn ""
        warn "  [DRY RUN] ================================================"
        warn "  Would DELETE all contents at ${FORCE_TARGET}:"
        warn "    $DEST_DIR"
        warn "  Then $COMMAND a fresh copy."
        warn "  =========================================================="
    else
        warn ""
        warn "  =========================================================="
        warn "  WARNING: --force will DELETE all contents at ${FORCE_TARGET}!"
        warn "  =========================================================="
        warn "  $DEST_DIR"
        warn ""
        warn "  Then $COMMAND a fresh copy from:"
        warn "  $SOURCE_DIR"
        warn ""
        read -rp "Type 'yes' to confirm, anything else to abort: " confirm
        if [[ "$confirm" != "yes" ]]; then
            info "Aborted by user."
            exit 0
        fi

        # For pull --force: back up .jrepoignore before wiping local
        if [[ "$COMMAND" == "pull" ]] && [[ "$ALL" != true ]] && [[ -f "$IGNORE_FILE" ]]; then
            TEMP_IGNORE=$(mktemp)
            cp "$IGNORE_FILE" "$TEMP_IGNORE"
            info "Backed up .jrepoignore."
        fi

        if [[ -d "$DEST_DIR" ]]; then
            find "$DEST_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
            ok "Destination wiped."
        else
            info "Destination does not exist yet; nothing to wipe."
        fi

        # Restore .jrepoignore after wipe
        if [[ -n "$TEMP_IGNORE" ]] && [[ -f "$TEMP_IGNORE" ]]; then
            cp "$TEMP_IGNORE" "$IGNORE_FILE"
            rm -f "$TEMP_IGNORE"
            info "Restored .jrepoignore."
            TEMP_IGNORE=""
        fi
    fi
fi

# ===================================================================
#  Pre-stats
# ===================================================================

pre_files=$(get_file_count "$DEST_DIR")
pre_bytes=$(get_dir_bytes "$DEST_DIR")
start_epoch=$(date +%s)

# ===================================================================
#  Ensure source ends with /
# ===================================================================

SOURCE_TRAIL="$SOURCE_DIR"
[[ "$SOURCE_TRAIL" != */ ]] && SOURCE_TRAIL="$SOURCE_TRAIL/"

# ===================================================================
#  Build & run rsync
# ===================================================================

# push: keep -a (perms are irrelevant to SMB/Robocopy targets).
# pull: drop -pgo and force sane modes, otherwise a CIFS/SMB mount (which
#       reports every file as 0755/0777) leaves all pulled files executable.
# No -v: the per-file listing is suppressed; the summary footer reports totals.
if [[ "$COMMAND" == "pull" ]]; then
    RSYNC_ARGS=(
        -rltD
        --delete
        --no-perms
        --chmod=D755,F644
    )
else
    RSYNC_ARGS=(
        -a
        --delete
    )
fi

if [[ "$DRY_RUN" == true ]]; then
    # Verbose on dry-run so the preview shows what would change.
    RSYNC_ARGS+=(--dry-run -v)
    warn "[DRY RUN] No files will be copied."
fi

if [[ "$ALL" == true ]]; then
    : # no exclusions
else
    if [[ -f "$IGNORE_FILE" ]]; then
        RSYNC_ARGS+=(--exclude-from="$IGNORE_FILE")
    fi
fi

info ""
info "Syncing..."
rsync "${RSYNC_ARGS[@]}" "$SOURCE_TRAIL" "$DEST_DIR/"

# ===================================================================
#  Post-stats & summary
# ===================================================================

post_files=$(get_file_count "$DEST_DIR")
post_bytes=$(get_dir_bytes "$DEST_DIR")
end_epoch=$(date +%s)
elapsed=$(( end_epoch - start_epoch ))

echo ""
rule
info "  $SUMMARY_TITLE"
rule
kv "${SOURCE_LABEL}:" "$SOURCE_DIR"
kv "${DEST_LABEL}:"   "$DEST_DIR"
kv "Files:" "$pre_files -> $post_files  ($(format_delta "$pre_files" "$post_files"))"
kv "Size:"  "$(format_bytes "$pre_bytes") -> $(format_bytes "$post_bytes")  ($(format_delta "$pre_bytes" "$post_bytes") bytes)"
kv "Time:"  "${elapsed}s"
rule

# ===================================================================
#  Line-ending fix (pull only)
# ===================================================================

if [[ "$COMMAND" == "pull" ]] && [[ "$DRY_RUN" != true ]]; then
    if [[ "$NO_EOL" == true ]]; then
        info "Skipping line-ending fix (--no-eol)."
    else
        info "Checking line endings..."
        fix_line_endings "$DEST_DIR"
    fi

    info "Restoring execute bits on scripts..."
    restore_exec_bits "$DEST_DIR"
fi

# ===================================================================
#  Done
# ===================================================================

if [[ "$DRY_RUN" == true ]]; then
    warn "[DRY RUN] Complete - no changes were made."
else
    ok "$SUMMARY_TITLE - completed successfully."
fi
