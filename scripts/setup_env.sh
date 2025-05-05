#!/bin/bash
# setup_env.sh - Script to attempt installation of necessary tools
#                (QEMU, Bochs, SDL, etc.) using APT for Debian/Ubuntu systems.

set -e # Exit immediately if a command exits with a non-zero status.
set -o pipefail # Ensures pipeline errors are caught

# Get the directory this script is in
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Project root is the parent directory of 'scripts/'
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source the colors script
if ! source "${SCRIPT_DIR}/colors.sh"; then
    echo "FATAL: Could not source colors.sh" >&2
    exit 1
fi

# --- Function to attempt installation of a list of packages using APT ---
install_packages_apt() {
    local update_cmd="sudo apt update"
    local install_cmd_base="sudo apt install -y"
    local packages_to_install="$@" # All arguments are packages

    if [ -z "$packages_to_install" ]; then
        warning "No packages specified for installation with apt."
        return 0
    fi

    info "Attempting to install using 'apt': $packages_to_install"

    # --- Execute Update Command ---
    info "Running package list update..."
    command_msg "${update_cmd}" # Show the command
    if ! ${update_cmd}; then   # Execute directly
       error "'apt' update command failed. Installation might fail."
       # Consider adding 'return 1' if update failure should halt the script
    fi

    # --- Execute Install Command ---
    info "Running package installation..."
    local full_install_command="${install_cmd_base} ${packages_to_install}"
    command_msg "${full_install_command}" # Show the command
    if ! ${full_install_command}; then  # Execute directly
        error "Installation command failed."
        error "Please check the output above and try installing necessary packages manually."
        return 1 # Indicate failure
    else
        info "Installation command finished for apt."
        return 0 # Indicate success
    fi
}


# --- Main Script Logic ---

cd "$PROJECT_ROOT" || { error "Failed to change directory to $PROJECT_ROOT"; exit 1; }
info "Running setup from project root: $(pwd)"

# === Step 1: Attempt Dependency Installation (APT Only) ===
step "Attempting to Install Dependencies (APT assumed)"

install_status=1 # Default to failure

# --- Define package names for APT ---
# QEMU for Happy Path, Bochs (with SDL) for Bad Path, build tools
PKGS_APT="git nasm build-essential qemu-system-i386 bochs-sdl libsdl1.2-dev gdb binutils bsdmainutils"

# --- Attempt installation using APT ---
if command -v apt &> /dev/null; then
    info "Detected 'apt' package manager."
    install_packages_apt $PKGS_APT
    install_status=$? # Capture the exit status of the installation attempt
else
    error "Package manager 'apt' not found. This script requires a Debian/Ubuntu based system."
    error "Please install the required packages manually: $PKGS_APT"
    # install_status remains 1 (failure)
fi

# --- Check installation result ---
if [ $install_status -ne 0 ]; then
    error "Dependency installation failed or 'apt' not found (exit status: $install_status). Cannot proceed."
    exit 1
else
    info "Dependency installation step finished successfully."
fi
echo

# === Step 2: Initialize/Update Submodules ===
step "Initializing/Updating Git Submodules"

if [ ! -f ".gitmodules" ]; then
    warning "'.gitmodules' file not found in project root ($(pwd)). No submodules to update."
else
    info "Updating submodules recursively..."
    run_cmd git submodule update --init --recursive
    info "Submodules initialized/updated successfully."
fi
echo

# === Completion ===
info "Environment setup attempt finished for tp3-sdc!"
info "Using QEMU for Happy Path and Bochs for Bad Path."
info "Please verify that all necessary tools (nasm, make, qemu-system-i386, bochs, gdb, etc.) are now working."
# Removed the note about editing bochsrc paths as we assume the user manages that.

exit 0
