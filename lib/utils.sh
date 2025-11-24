#!/bin/bash

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print info message
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Print success message  
log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Print warning
log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Print error
log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_module() {
    echo -e "${GREEN}[MODULE $1]${NC} $2"
}

log_complete() {
    echo -e "${GREEN}[COMPLETE]${NC} $1"
}

# Make sure running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run as root"
        exit 1
    fi
}

# Ask user to confirm
confirm_action() {
    local message="$1"
    local default="${2:-n}"
    
    # Skip confirmation if force mode is on
    if [ "$FORCE_MODE" = "true" ]; then
        return 0
    fi
    
    echo -e "${YELLOW}[CONFIRM]${NC} $message"
    if [ "$default" = "y" ]; then
        read -p "Continue? [Y/n]: " response
        response=${response:-y}
    else
        read -p "Continue? [y/N]: " response
        response=${response:-n}
    fi
    
    case "$response" in
        [yY]|[yY][eE][sS])
            return 0
            ;;
        *)
            log_warn "Action cancelled by user"
            return 1
            ;;
    esac
}


