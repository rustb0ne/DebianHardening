#!/bin/bash

# Load utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"
source "$LIB_DIR/utils.sh"

log_module "04" "Logging and Auditing"
echo ""

# Install auditd
log_info "Installing auditd and plugins"
apt install -y auditd audispd-plugins
if [ $? -eq 0 ]; then
    log_success "Auditd installed successfully"
else
    log_error "Failed to install auditd"
    exit 1
fi
echo ""

# Setup audit rules
AUDIT_RULES="/etc/audit/rules.d/hardening.rules"
if confirm_action "Configure audit rules? (Time, users, files, deletions)" "y"; then
    log_info "Writing audit rules to $AUDIT_RULES"
    echo "  - Time modification tracking"
    echo "  - Sudoers file monitoring"
    echo "  - User/Group modification tracking"
    echo "  - File deletion auditing"
    
    cat > "$AUDIT_RULES" <<EOF
# Time modification
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time-change

# System scope (Sudoers)
-w /etc/sudoers -p wa -k scope

# User/Group modification
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/gshadow -p wa -k identity

# File deletion
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k delete
EOF
    
    log_success "Audit rules configured"
else
    log_warn "Skipped Audit rules configuration"
    exit 0
fi
echo ""

# Load the rules
log_info "Loading audit rules with augenrules..."
augenrules --load
if [ $? -eq 0 ]; then
    log_success "Audit rules loaded"
else
    log_warn "Failed to load audit rules with augenrules"
fi

# Restart auditd
log_info "Restarting auditd service..."
service auditd restart
if [ $? -eq 0 ]; then
    log_success "Auditd restarted successfully."
else
    log_warn "Failed to restart auditd (may not be available in containers)"
fi
echo ""

# Show current rules
log_info "Current Audit Rules:"
auditctl -l 2>/dev/null || echo "(auditctl not available)"
echo ""
log_info "Audit logs location: /var/log/audit/audit.log"

# Additional logging hardening
log_info "Configuring additional logging settings"

# Ensure rsyslog is installed and running
if ! systemctl is-active --quiet rsyslog 2>/dev/null; then
    log_info "Installing and enabling rsyslog"
    apt install -y rsyslog >/dev/null 2>&1
    systemctl enable rsyslog >/dev/null 2>&1
    systemctl start rsyslog >/dev/null 2>&1
fi

# Secure log files permissions
if [ -d "/var/log" ]; then
    log_info "Securing log file permissions"
    find /var/log -type f -exec chmod g-wx,o-rwx {} + 2>/dev/null
    log_success "Log file permissions secured"
fi
echo ""

# Secure cron permissions (CIS 5.1.x)
if confirm_action "Secure cron/at permissions?" "y"; then
    log_info "Setting secure permissions for cron files"
    
    # Set permissions on crontab
    if [ -f /etc/crontab ]; then
        chown root:root /etc/crontab
        chmod 600 /etc/crontab
        log_success "Secured /etc/crontab (600)"
    fi
    
    # Set permissions on cron directories
    for dir in /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly /etc/cron.d; do
        if [ -d "$dir" ]; then
            chown root:root "$dir"
            chmod 700 "$dir"
            log_success "Secured $dir (700)"
        fi
    done
    
    # Restrict at/cron to authorized users
    echo "root" > /etc/cron.allow
    echo "root" > /etc/at.allow
    chmod 600 /etc/cron.allow /etc/at.allow
    rm -f /etc/cron.deny /etc/at.deny 2>/dev/null
    
    log_success "Cron/at restricted to authorized users only"
else
    log_warn "Skipped cron permissions"
fi
echo ""

log_complete "Module 04 finished."
