#!/bin/bash
# setup_env.sh - Main script to prepare the TP3 project environment
#                (Assumes it runs inside the tp3-sdc repo which uses submodules)

set -e
set -o pipefail

# Get the directory this script is in
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Project root is the parent directory of 'scripts/'
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source the colors script
if ! source "${SCRIPT_DIR}/colors.sh"; then
    echo "FATAL: Could not source colors.sh" >&2
    exit 1
fi

# Change to project root to ensure commands run from the correct place
cd "$PROJECT_ROOT"
info "Running setup from project root: $(pwd)"

# === Step 1: Check Tools ===
step "Running Tool Checks"
# Execute the check script; it will exit if checks fail
"${SCRIPT_DIR}/check_tools.sh"
info "Tool check successful."
echo

# === Step 2: Initialize/Update Submodules ===
step "Initializing/Updating Git Submodules"

if [ ! -f ".gitmodules" ]; then
    warning "'.gitmodules' file not found in project root ($(pwd))."
    warning "No submodules to update. If you expected submodules, add them first using:"
    yellow "  git submodule add <repo_url> <path>"
else
    info "Updating submodules recursively..."
    # Run the submodule update command from the project root
    run_cmd git submodule update --init --recursive
    info "Submodules initialized/updated successfully."
fi
echo

# === Completion ===
info "Environment setup/check finished for tp3-sdc!"

exit 0
