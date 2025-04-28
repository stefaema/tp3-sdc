#!/bin/bash
# setup_env.sh - Simplified script to attempt installation of necessary tools
#                and update submodules for the TP3 project environment.

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

# --- Function to attempt installation of a list of packages ---
# Executes commands directly for robustness with sudo/pipelines
install_packages() {
    local manager=$1
    local update_cmd=$2 # Separate update command (can be empty)
    local install_cmd_base=$3 # Install command base
    shift 3 # Remove manager and commands from arguments
    local packages_to_install="$@"

    if [ -z "$packages_to_install" ]; then
        warning "No packages specified for installation with $manager."
        return 0
    fi

    info "Attempting to install using '$manager': $packages_to_install"

    # --- Execute Update Command (if provided) ---
    if [ -n "$update_cmd" ]; then
        info "Running package list update..."
        command_msg "${update_cmd}" # Show the command
        if ! ${update_cmd}; then   # Execute directly
           error "'$manager' update command failed. Installation might fail."
           # return 1 # Optional: Exit if update fails
        fi
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
        info "Installation command finished for $manager."
        return 0 # Indicate success
    fi
}

# --- Main Script Logic ---

cd "$PROJECT_ROOT" || { error "Failed to change directory to $PROJECT_ROOT"; exit 1; }
info "Running setup from project root: $(pwd)"

# === Step 1: Attempt Dependency Installation ===
step "Attempting to Install Dependencies"

manager_found=0
install_status=0 # Variable para guardar el estado de la instalación (0=éxito)

# --- Define package names per manager ---
PKGS_APT="git nasm build-essential qemu-system-x86 gdb binutils bsdmainutils"
PKGS_DNF="git nasm make gcc binutils qemu-system-x86-core gdb util-linux"
PKGS_YUM="git nasm make gcc binutils qemu-system-x86-core gdb util-linux"
PKGS_PACMAN="git nasm base-devel qemu-system-i386 gdb binutils util-linux"
PKGS_BREW="git nasm make qemu gdb binutils util-linux"

# --- Attempt installation based on detected manager ---
if command -v apt &> /dev/null; then
    manager_found=1
    install_packages "apt" "sudo apt update" "sudo apt install -y" $PKGS_APT
    install_status=$? # Captura el estado de esta llamada
elif command -v dnf &> /dev/null; then
    manager_found=1
    install_packages "dnf" "" "sudo dnf install -y" $PKGS_DNF
    install_status=$? # Captura el estado de esta llamada
elif command -v yum &> /dev/null; then
    manager_found=1
    install_packages "yum" "" "sudo yum install -y" $PKGS_YUM
    install_status=$? # Captura el estado de esta llamada
elif command -v pacman &> /dev/null; then
    manager_found=1
    install_packages "pacman" "sudo pacman -Syu --noconfirm" "sudo pacman -S --noconfirm --needed" $PKGS_PACMAN
    install_status=$? # Captura el estado de esta llamada
elif command -v brew &> /dev/null; then
    manager_found=1
    install_packages "brew" "brew update" "brew install" $PKGS_BREW
    install_status=$? # Captura el estado de esta llamada
fi

# --- Verificar resultado de la instalación ---
if [ $manager_found -eq 0 ]; then
    warning "Could not detect a supported package manager."
    warning "Skipping automatic dependency installation. Please ensure required tools are installed."
elif [ $install_status -ne 0 ]; then # Verifica la variable de estado capturada
    error "Dependency installation failed (exit status: $install_status). Cannot proceed."
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
    # Use run_cmd here as git commands are usually safe
    run_cmd git submodule update --init --recursive
    info "Submodules initialized/updated successfully."
fi
echo

# === Completion ===
info "Environment setup attempt finished for tp3-sdc!"
info "Please verify that all necessary tools (nasm, qemu, make, etc.) are now working."

exit 0
