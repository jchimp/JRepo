#!/usr/bin/env bash
# -----------------------------------------------------------
#  JRepo Installer for Linux
#  Copies JRepo script to /usr/local/bin (requires root/sudo).
#  Usage:  sudo ./install.sh
# -----------------------------------------------------------
set -euo pipefail

INSTALL_DIR="/usr/local/bin"
DOCS_DIR="/usr/local/share/jrepo"

_c_reset="\033[0m"
_c_cyan="\033[36m"
_c_green="\033[32m"
_c_yellow="\033[33m"
_c_red="\033[31m"
_c_gray="\033[90m"

info()  { echo -e "${_c_cyan}$*${_c_reset}"; }
ok()    { echo -e "${_c_green}$*${_c_reset}"; }
warn()  { echo -e "${_c_yellow}$*${_c_reset}"; }
err()   { echo -e "${_c_red}$*${_c_reset}" >&2; }

echo ""
info "=================================================="
info " JRepo Installer - Linux"
info "=================================================="
echo ""

# -- Check for root/sudo
if [[ $EUID -ne 0 ]]; then
    err "This installer requires root privileges."
    err "Re-run with:  sudo ./install.sh"
    exit 1
fi

info "Running as root."

# -- Install main script
info "Installing to $INSTALL_DIR..."

if [[ -f "jrepo.sh" ]]; then
    cp "jrepo.sh" "$INSTALL_DIR/jrepo"
    chmod +x "$INSTALL_DIR/jrepo"
    ok "  Installed: jrepo"
else
    err "  jrepo.sh not found in current directory!"
    exit 1
fi

# -- Copy docs to share directory
info "Installing docs to $DOCS_DIR..."
mkdir -p "$DOCS_DIR"

for doc in README.md sample.jrepoignore LICENSE; do
    if [[ -f "$doc" ]]; then
        cp "$doc" "$DOCS_DIR/$doc"
        ok "  Installed: $doc"
    fi
done

# -- Copy Windows scripts for reference
for winscript in jrepo.cmd jrepo.ps1; do
    if [[ -f "$winscript" ]]; then
        cp "$winscript" "$DOCS_DIR/$winscript"
    fi
done
if ls "$DOCS_DIR"/*.ps1 >/dev/null 2>&1; then
    info "  Windows scripts copied to $DOCS_DIR for reference."
fi

# -- Verify installation
echo ""
if command -v jrepo >/dev/null 2>&1; then
    ok "  Verified: $(command -v jrepo)"
else
    warn "  'jrepo' not found in PATH."
    warn "  Ensure $INSTALL_DIR is in your PATH."
fi

# -- Summary
echo ""
info "=================================================="
info " Installation complete!"
info "=================================================="
info " Script:  $INSTALL_DIR/jrepo"
info " Docs:    $DOCS_DIR"
info ""
info " Commands available:"
info "   jrepo init              Create a default .jrepoignore"
info "   jrepo push <PATH>       Push current dir to mount path"
info "   jrepo pull <PATH>       Pull from mount path to current dir"
info "   jrepo help              Show usage and flags"
info ""
ok " Ready to use."
info "=================================================="
echo ""
