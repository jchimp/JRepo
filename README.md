# JRepo

**A simple, cross-platform file sync tool for a lone developer or a small team.**

**JRepo** is my personal "repo" solution for my source code and projects. I use this personally and at work as a cheap/easy trick to 'push' up code, then 'pull' it down on the server to run. It's because I am laxy and didn't want to remember `Robocopy` or `rsync` commands and fix line endings.

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
- **Folder name mismatch detection** — warns you if local and remote folder names don't match
- **Automatic CRLF → LF fix** on Linux pull (safe — only touches text files)
- **`.jrepoignore`** for excluding files and directories (like `.gitignore`)
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
| `# comment`    | Comment                   | `# ignore logs` | Ignored                                     |
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

## License

This project is licensed under the [LICENSE](LICENSE).
