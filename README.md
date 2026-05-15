# JRepo

**A dead-simple, cross-platform file sync tool for a lone developer or a small team.**

**JRepo** is my personal "repo" solution for my source code and projects. I use this personally and at work as a cheap/easy trick to 'push' up code, then 'pull' it down on the server to run in Docker.

[https://img.shields.io/badge/License-MIT-yellow.svg](LICENSE)

---

## What is JRepo?

JRepo pushes and pulls project directories to and from network shares — no git server, no config files, no dependencies beyond what's already on your OS.

Point it at a UNC path (Windows) or mount point (Linux), and it mirrors your current directory there. That's it.

Built for the part time dev who:
- Deploy code to servers via NAS / SMB shares
- Sync projects between machines without setting up git remotes
- Need a quick "push up, pull down" workflow for Docker hosts
- Want something simpler than rsync flags and robocopy switches to remember

---

## Features

- **Cross-platform** — Windows (Robocopy) and Linux (rsync), same workflow on both
- **Push** from any directory to a network share or mount point
- **Pull** from a network share or mount point into any directory
- **`.jrepoignore`** for excluding files and directories (like `.gitignore`)
- **`--all`** flag to sync everything, ignoring `.jrepoignore` exclusions
- **`--force`** flag to wipe the destination and sync a clean copy (with confirmation prompt)
- **`--dry-run`** flag to preview what would happen without touching anything
- **Folder name mismatch detection** — warns you if local and remote folder names don't match
- **Automatic CRLF → LF fix** on Linux pull (safe — only touches text files)
- **`jrepo init`** to create a default `.jrepoignore` with defaults

---

## Installation

### Windows

Run `install.bat` **as Administrator** (right-click → Run as administrator):

```
install.bat
````

This will:
- Copy all scripts to `C:\Tools\JRepo\`
- Add `C:\Tools\JRepo\` to your system PATH
- Open a **new terminal** afterward for PATH changes to take effect

### Linux

```bash
sudo ./install.sh
````

This will:
*   Copy scripts to `/usr/local/bin/` (with `.sh` extension removed)
*   Copy docs to `/usr/local/share/jrepo/`
*   Verify all commands are in PATH

### Manual Installation

Just copy the scripts to any directory in your PATH:

- **Windows:** Copy all `.cmd` and `.ps1` files to a folder, then add that folder to your PATH.
- **Linux:** Copy the `.sh` files, drop the extension, and `chmod +x`:

***

## Quick Start

Develop on Windows:
```cmd
cd C:\Projects\myapp
jrepo init
notepad .jrepoignore
jrepo push \\nas01\repos\myapp --dry-run
jrepo push \\nas01\repos\myapp
```

Pull Down on Linux Host:
```
mkdir /opt/myapp
cd /opt/myapp
jrepo init
jrepo pull /mnt/nas/repos/myapp

# Setup variables and start application
cp example.env .env
nano .env
docker compose up -d
```


## Example Workflows

### Dev machine → NAS → Docker host
```
    ┌──────────────┐      jrepo push       ┌──────────┐      jrepo pull       ┌──────────────┐
    │  Windows PC  │  ──────────────────>  │   NAS    │   ──────────────────> │ Docker Host  │
    │  (develop)   │   \\nas\repos\myapp   │  (repo)  │  /mnt/nas/repos/myapp │  (deploy)    │
    └──────────────┘                       └──────────┘                       └──────────────┘
```

```cmd
REM On your dev machine (Windows):
cd C:\Projects\myapp
jrepo push \\nas01\repos\myapp
```

```bash
# On the Docker host (Linux):
cd /opt/myapp
jrepo pull /mnt/nas01/repos/myapp
docker compose up -d
```

### Safekeeping push (all files, including secrets and data)

```bash
# Push everything — ignores .jrepoignore
jrepo push /mnt/nas/backups/myapp --all
```

### Clean deploy (wipe remote, push fresh)

```bash
# Nuke the remote copy and push a clean version
jrepo push /mnt/nas/repos/myapp --force
```

### Pull down a fresh copy to start working

```bash
# Wipe local and pull everything fresh
mkdir ~/projects/myapp && cd ~/projects/myapp
jrepo pull /mnt/nas/repos/myapp --all --force
```

***

## How It Works

### Push

Mirrors your **local directory → remote path** using:

*   **Windows:** `robocopy /MIR` (Mirror mode — makes the destination identical to the source)
*   **Linux:** `rsync -av --delete` (Archive + verbose + delete extraneous files at destination)

### Pull

Mirrors a **remote path → local directory** using the same tools, with source and destination swapped.

### What `/MIR` and `--delete` mean

The destination becomes an **exact copy** of the source (minus any exclusions from `.jrepoignore`). Files that exist at the destination but not in the source **will be deleted**. This is intentional — it keeps the remote in sync.

### Force mode

When `--force` is used:

1.  A prominent warning is displayed showing both paths
2.  You must type the word **`yes`** to confirm (not just `y`)
3.  The destination is completely wiped
4.  A fresh sync is performed

### Line ending fix (Linux pull only)

After pulling on Linux, `jrepo pull` automatically scans all text files and converts `CRLF` → `LF`. This is safe because:

*   Only files identified as `text/*` by the `file` command are checked
*   Only files that actually contain `\r\n` are modified
*   Binary files are never touched
*   Use `--no-eol` to skip this step

***


## Usage

### `jrepo push`

Mirrors the current directory **to** a remote path.

    jrepo push <PATH> [--all] [--force] [--dry-run]

| Flag        | Description                                                                   |
| ----------- | ----------------------------------------------------------------------------- |
| `--all`     | Push all files, ignoring `.jrepoignore` exclusions                            |
| `--force`   | Wipe the destination first, then push a clean copy (prompts for confirmation) |
| `--dry-run` | Preview only — no files are copied or deleted                                 |

**Examples:**

```bash
# Standard deploy push (respects .jrepoignore)
jrepo push /mnt/nas/repos/myapp

# Push everything for safekeeping
jrepo push /mnt/nas/repos/myapp --all

# Nuke remote and push fresh
jrepo push /mnt/nas/repos/myapp --force

# Preview a force push
jrepo push /mnt/nas/repos/myapp --force --dry-run
```

***

### `jrepo pull`

Mirrors a remote path **into** the current directory.

    jrepo pull <PATH> [--all] [--force] [--dry-run] [--no-eol]

| Flag        | Description                                                                       |
| ----------- | --------------------------------------------------------------------------------- |
| `--all`     | Pull all files, ignoring `.jrepoignore` exclusions                                |
| `--force`   | Wipe the local directory first, then pull a clean copy (prompts for confirmation) |
| `--dry-run` | Preview only — no files are copied or deleted                                     |
| `--no-eol`  | Skip the automatic CRLF → LF line-ending fix (Linux only)                         |

> **Note:** The `--no-eol` flag is only available in the Linux (bash) version of `jrepo pull`. The Windows version does not perform line-ending conversion.

**Examples:**

```bash
# Standard deploy pull (respects .jrepoignore, fixes line endings)
jrepo pull /mnt/nas/repos/myapp

# Pull everything to work on it
jrepo pull /mnt/nas/repos/myapp --all

# Nuke local and pull fresh
jrepo pull /mnt/nas/repos/myapp --force

# Pull without fixing line endings
jrepo pull /mnt/nas/repos/myapp --no-eol
```

***

### `jrepo init`

Creates a default `.jrepoignore` file in the current directory.

    jrepo init

If a `.jrepoignore` already exists, it will prompt before overwriting.

The generated file includes sensible defaults for Python, Node, environment files, logs, temp files, OS junk, version control directories, and common build directories.

***

## `.jrepoignore` Pattern Guide

Place a `.jrepoignore` file in your project root. The syntax is simple:

| Pattern        | Type                      | Example         | What it excludes                            |
| -------------- | ------------------------- | --------------- | ------------------------------------------- |
| `/dirname`     | Directory (leading `/`)   | `/data`         | The `data/` directory                       |
| `dirname/`     | Directory (trailing `/`)  | `logs/`         | The `logs/` directory                       |
| `*.ext`        | Extension / wildcard      | `*.pyc`         | All `.pyc` files                            |
| `name.ext`     | Specific file (has a `.`) | `config.local`  | That exact file                             |
| `name`         | Ambiguous (no `.` or `/`) | `__pycache__`   | Excluded as **both** a directory and a file |
| `# comment`    | Comment                   | `# ignore logs` | Ignored by the parser                       |
| *(blank line)* | —                         |                 | Ignored                                     |

**Example `.jrepoignore`:**

```gitignore
# Python
*.pyc
__pycache__

# Environment / secrets
*.env
.env

# Directories
/data
/.git
/node_modules

# OS junk
Thumbs.db
.DS_Store

# Temp files
*.tmp
*~
```

> **Important:** If `--all` is not used and no `.jrepoignore` file is found, the script will exit with an error. This prevents accidentally syncing everything (including secrets, data directories, etc.). Use `jrepo init` to create one, or pass `--all` if you intentionally want to sync everything.

***

## Files

| File                 | Description                                                  |
| -------------------- | ------------------------------------------------------------ |
| `install.bat`        | Windows installer — copies to `C:\Tools\JRepo`, updates PATH |
| `install.sh`         | Linux installer — copies to `/usr/local/bin`                 |
| `jrepo.cmd`          | Windows wrapper for `jrepo.ps1`                              |
| `jrepo.ps1`          | Push/Pull current directory to a UNC path (Robocopy)         |
| `jrepo.sh`           | Push/Pull current directory to a mount path (rsync)          |
| `sample.jrepoignore` | Example `.jrepoignore` with sensible defaults                |
| `LICENSE`            | MIT License                                                  |

***

## Requirements

*   **Windows:** PowerShell 5.1+ and Robocopy (both included with Windows 10/11 and Server 2016+)
*   **Linux:** bash, rsync, coreutils (`file`, `find`, `sed`, `grep`, `du`, `bc`)

No external dependencies. No packages to install. No runtimes to configure.

***

## License

This project is licensed under the LICENSE.
