## Toolkit Overview

| File                 | OS      | Direction     | Engine           |
| -------------------- | ------- | ------------- | ---------------- | 
| `jrepo-push.cmd`     | Windows | —             | Batch wrapper    |
| `jrepo-push.ps1`     | Windows | Local → UNC   | Robocopy `/MIR`  |
| `jrepo-pull.cmd`     | Windows | —             | Batch wrapper    |
| `jrepo-pull.ps1`     | Windows | UNC → Local   | Robocopy `/MIR`  |
| `jrepo-push.sh`      | Linux   | Local → Mount | rsync `--delete` |
| `jrepo-pull.sh`      | Linux   | Mount → Local | rsync `--delete` |
| `sample.jrepoignore` | Both    | —             | —                | 

## What's New in v0.0.2

| Feature                | Push (`.ps1`)                           | Pull (`.sh`)                                                       |
| ---------------------- | --------------------------------------- | ------------------------------------------------------------------ |
| **No config file**     | `jrepo-push \\server\share\app`         | `jrepo-pull /mnt/server/app`                                       |
| **`--all`**            | Skips `.jrepoignore`, pushes everything | Skips `.jrepoignore`, pulls everything                             |
| **`--force`**          | Prompts → wipes target → pushes clean   | Prompts → wipes local dir → pulls clean                            |
| **`--force` + ignore** | `.jrepoignore` is in source, no issue   | `.jrepoignore` backed up to `/tmp` before wipe, restored for rsync |
| **`--dry-run`**        | Robocopy `/L` + skips prompts           | rsync `--dry-run` + skips prompts                                  |
| **Folder name check**  | Warns if `myapp` ≠ `myapp-old`          | Same — prompts to confirm                                          |
| **Stats summary**      | Files/size before→after with delta      | Same, plus elapsed time                                            |
| **Line ending fix**    | N/A (pushing from Windows)              | Auto CRLF→LF on all text files (skip with `--no-eol`)              |

### Safety Features Across All Scripts

| Safety Check                 | What Happens                                                                                               |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------- |
| **`--force` confirmation**   | Draws a `╔══╗` warning box in yellow, shows both paths, requires typing the word **`yes`** (not just `y`)  |
| **Folder name mismatch**     | Warns if local folder name ≠ remote folder name, shows both full paths, prompts `y/N`                      |
| **`.jrepoignore` backup**    | Pull scripts back up `.jrepoignore` to temp before a force-wipe, restore it after so exclusions still work |
| **`--dry-run`**              | Suppresses all prompts (nothing destructive happens), shows `[DRY RUN]` boxes instead                      |
| **EOL fix** (`pull.sh` only) | Only scans `text/*` mime types, only modifies files with actual `\r\n`, skippable with `--no-eol`          |


### Workflow

```bash
# Start a new project:
cd myproject
jrepo-init                    # generates .jrepoignore
nano .jrepoignore             # tweak for your project

# Push it:
jrepo-push \\nas\repos\myproject --dry-run
jrepo-push \\nas\repos\myproject
```

### Quick reference

```bash
# ── Windows ────────────────────────────────────────
jrepo-push \\nas\repos\myapp              # deploy push (respects .jrepoignore)
jrepo-push \\nas\repos\myapp --all        # safekeeping push (everything)
jrepo-push \\nas\repos\myapp --force      # nuke remote + push clean

jrepo-pull \\nas\repos\myapp              # deploy pull
jrepo-pull \\nas\repos\myapp --all        # dev pull (everything)
jrepo-pull \\nas\repos\myapp --force      # nuke local + pull clean

# ── Linux ──────────────────────────────────────────
jrepo-push /mnt/nas/repos/myapp           # deploy push
jrepo-push /mnt/nas/repos/myapp --all     # safekeeping push

jrepo-pull /mnt/nas/repos/myapp           # deploy pull (auto-fixes CRLF)
jrepo-pull /mnt/nas/repos/myapp --all     # dev pull (auto-fixes CRLF)
jrepo-pull /mnt/nas/repos/myapp --no-eol  # pull without EOL fix

# ── Always preview first ───────────────────────────
jrepo-push \\nas\repos\myapp --force --dry-run
jrepo-pull /mnt/nas/repos/myapp --force --dry-run
```

### Line ending safety
The fix_line_endings function is safe because it's a two-gate check:

- **file -b --mime-type** — only processes files identified as text/* (skips binaries, images, zips, etc.)
- **grep -cP '\r$'** — only modifies files that actually contain \r\n
- **sed -i 's/\r$//'** — only strips \r at the end of a line, never mid-line

So your .pyc, .png, .zip files are never touched. And text files that already have LF endings are scanned but never modified. Completely safe to run every pull. 