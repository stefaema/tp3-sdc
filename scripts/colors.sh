#!/bin/bash
# colors.sh - Define functions for colored output using ANSI escape codes.
# Should be sourced by other scripts.

# Prevent re-sourcing
if [ -n "$_COLORS_LOADED" ]; then
    return 0 # Already loaded
fi
export _COLORS_LOADED=1 # Mark as loaded

# --- Color Definitions ---
C_RESET='\033[0m'
C_GREEN='\033[0;92m'    # Bright Green
C_RED='\033[0;91m'      # Bright Red
C_YELLOW='\033[0;93m'   # Bright Yellow
C_BLUE='\033[0;94m'     # Bright Blue
C_MAGENTA='\033[0;95m'  # Bright Magenta
C_CYAN='\033[0;96m'     # Bright Cyan
C_WHITE='\033[0;97m'    # Bright White

# --- Basic Color Functions ---
# Usage: green "Your text here"
green() { echo -e "${C_GREEN}$@${C_RESET}"; }
red() { echo -e "${C_RED}$@${C_RESET}"; }
yellow() { echo -e "${C_YELLOW}$@${C_RESET}"; }
blue() { echo -e "${C_BLUE}$@${C_RESET}"; }
magenta() { echo -e "${C_MAGENTA}$@${C_RESET}"; }
cyan() { echo -e "${C_CYAN}$@${C_RESET}"; }
white() { echo -e "${C_WHITE}$@${C_RESET}"; }

# --- Semantic Functions ---
info() { green "[INFO] $@"; }
error() { red "[ERROR] $@"; }
warning() { yellow "[WARN] $@"; }
command_msg() { yellow "> $@"; } # Use yellow to show commands
step() { cyan "--- $@ ---"; }

# --- Function to Execute and Display Command ---
# Usage: run_cmd ls -l
run_cmd() {
    command_msg "$@" # Display the command
    "$@"             # Execute the command
    local status=$?
    if [ $status -ne 0 ]; then
        error "Command failed with status $status: $@"
        # Decide if you want to exit immediately on failure
        # exit $status
    fi
    return $status
}

# Indicate successful loading if sourced directly for testing
#if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
#    info "Color functions loaded."
#fi
