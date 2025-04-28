#!/bin/bash
# check_tools.sh - Verifies required tools are installed and in PATH.
# Should be called by setup_env.sh.

# Find the directory this script resides in
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Source the colors script relative to this script's location
if ! source "${SCRIPT_DIR}/colors.sh"; then
    echo "FATAL: Could not source colors.sh from check_tools.sh" >&2
    exit 1
fi

step "Checking required tools"

# --- Define required tools ---
# Adjust this list based on your actual needs (e.g., 'as' instead of 'nasm')
REQUIRED_TOOLS=(
    git
    nasm
    ld
    qemu-system-i386 # Or qemu-system-x86_64 if you use that
    gdb
    make
    objdump
    hexdump # Standard Linux tool, 'hd' is sometimes an alias
)
# ---

_CHECKS_FAILED=0

for tool in "${REQUIRED_TOOLS[@]}"; do
    white "Checking for '$tool'..."
    if ! command -v "$tool" &> /dev/null; then
        error "Tool '$tool' not found in PATH."
        _CHECKS_FAILED=1
    else
       # Optional: Show where the tool was found
       # green " -> $(command -v "$tool")"
       : # POSIX compliant no-op if you don't want the optional line
    fi
done

if [ $_CHECKS_FAILED -ne 0 ]; then
    error "One or more required tools are missing. Please install them."
    exit 1 # Exit with failure status
else
    info "All required tools found."
    exit 0 # Explicitly exit with success status
fi
