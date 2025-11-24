#!/bin/bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
MODULES_DIR="$SCRIPT_DIR/modules"

# Check if user wants to skip confirmations
export FORCE_MODE="false"
if [ "$1" = "--force" ] || [ "$1" = "-f" ]; then
    FORCE_MODE="true"
    echo "Force mode enabled - skipping confirmations"
fi

# Load helper functions
source "$LIB_DIR/utils.sh"

# Print header
echo "=================================================="
echo "      DEBIAN/UBUNTU HARDENING SCRIPT"
echo "=================================================="
log_info "Starting hardening process..."
echo ""

# Make sure we're root
check_root

# Show warning
log_error "WARNING: This script will modify critical system configurations."
echo "  - SSH settings will be hardened"
echo "  - Firewall will be configured"
echo "  - Root account will be locked"
echo "  - Password policies will be enforced"
echo ""
log_warn "Recommendation: Take a VM snapshot before proceeding!"
echo ""

# Ask user if they want to continue
if ! confirm_action "Do you want to proceed with system hardening?" "n"; then
    echo "Hardening cancelled."
    exit 0
fi

echo ""

# Run all modules
if [ -d "$MODULES_DIR" ]; then
    for module in "$MODULES_DIR"/*.sh; do
        if [ -f "$module" ]; then
            module_name=$(basename "$module")
            echo "--------------------------------------------------"
            log_info "Running module: $module_name"
            echo "--------------------------------------------------"
            
            # Execute the module
            bash "$module"
            
            # Check if it succeeded
            if [ $? -eq 0 ]; then
                log_success "Module $module_name completed successfully."
            else
                log_error "Module $module_name failed!"
                echo ""
                # Ask if user wants to continue
                if ! confirm_action "Module failed. Continue with next module?" "n"; then
                    log_error "Hardening process aborted."
                    exit 1
                fi
            fi
            echo ""
        fi
    done
else
    log_error "Modules directory not found at $MODULES_DIR"
    exit 1
fi

# Print summary
echo "=================================================="
log_complete "Hardening process finished."
echo "=================================================="
echo ""
log_info "Next steps:"
echo "  1. Verify SSH access with new admin user before logging out"
echo "  2. Check firewall status: sudo ufw status"
echo "  3. Review audit logs: sudo auditctl -l"
echo "  4. Test login with new password policy"
echo "=================================================="
