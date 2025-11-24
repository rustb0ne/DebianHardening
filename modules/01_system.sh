#!/bin/bash

# Load utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"
source "$LIB_DIR/utils.sh"

log_module "01" "System Updates & Cleanup"
echo ""

# Update the system
if confirm_action "Update system packages? (apt update && apt upgrade)" "y"; then
    apt update && apt upgrade -y
    if [ $? -eq 0 ]; then
        log_success "System updated successfully"
    else
        log_warn "System update encountered issues"
    fi
else
    log_warn "Skipped System update"
fi
echo ""

# Fix file permissions
log_info "Set secure permissions for critical files"
echo "  - /etc/shadow -> 640 (root:shadow)"
echo "  - /etc/passwd -> 644 (root:root)"
chmod 640 /etc/shadow
chown root:shadow /etc/shadow
chmod 644 /etc/passwd
chown root:root /etc/passwd
log_success "File permissions secured"
echo ""

# Remove unnecessary services
SERVICES="xinetd nis ypserv tftp-server bind9 vsftpd avahi-daemon cups-daemon"
if confirm_action "Remove potentially unnecessary services ? ($SERVICES)" "y"; then
    apt purge -y $SERVICES 2>/dev/null
    apt autoremove -y
    log_success "Unnecessary services removed"
else
    log_warn "Skipped Service removal"
fi
echo ""

# Disable HTTP Proxy
if [ -f "/etc/environment" ]; then
    log_info "Clearing HTTP proxy settings in /etc/environment"
    echo 'http_proxy=""' >> /etc/environment
    echo 'https_proxy=""' >> /etc/environment
    log_success "HTTP proxy disabled"
fi
echo ""

# Kernel hardening 
if confirm_action "Apply kernel hardening parameters? (sysctl)" "y"; then
    SYSCTL_CONF="/etc/sysctl.d/99-hardening.conf"
    
    log_info "Writing kernel hardening parameters to $SYSCTL_CONF"
    cat > "$SYSCTL_CONF" <<EOF
# IP Forwarding
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# SYN cookies protection
net.ipv4.tcp_syncookies = 1

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Log Martians
net.ipv4.conf.all.log_martians = 1

# Ignore ICMP 
net.ipv4.icmp_echo_ignore_all = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Ignore Directed pings
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Enable bad error message protection
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Enable reverse path filtering
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Disable IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1

# Kernel hardening
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
EOF
    # Apply settings
    sysctl -p "$SYSCTL_CONF" >/dev/null 2>&1
    log_success "Kernel parameters hardened"
else
    log_warn "Skipped Kernel hardening"
fi
echo ""

# Disable unused filesystems
if confirm_action "Disable unused filesystems? (cramfs, freevxfs, jffs2, hfs, hfsplus, udf)" "y"; then
    MODPROBE_CONF="/etc/modprobe.d/hardening.conf"
    
    log_info "Disabling unused filesystems"
    cat > "$MODPROBE_CONF" <<EOF
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install udf /bin/true
install vfat /bin/true
install dccp /bin/true
install sctp /bin/true
install rds /bin/true
install tipc /bin/true
install usb-storage /bin/true
EOF
    log_success "Unused filesystems and USB storage disabled"
else
    log_warn "Skipped Filesystem restrictions"
fi
echo ""

# Secure /tmp and /var/tmp
if confirm_action "Secure /tmp with noexec,nodev,nosuid mount options?" "y"; then
    log_info "Adding secure mount options for /tmp"
    
    # Check if /tmp is already in fstab
    if ! grep -q "^tmpfs.*/tmp" /etc/fstab; then
        echo "tmpfs /tmp tmpfs defaults,noexec,nodev,nosuid,mode=1777 0 0" >> /etc/fstab
        log_success "Added /tmp to fstab with secure options"
        log_warn "Reboot required to apply /tmp mount options"
    else
        log_info "/tmp already configured in fstab"
    fi
else
    log_warn "Skipped /tmp hardening"
fi
echo ""

# Set core dump restrictions
log_info "Restricting core dumps"
if [ -f "/etc/security/limits.conf" ]; then
    if ! grep -q "^\* hard core" /etc/security/limits.conf; then
        echo "* hard core 0" >> /etc/security/limits.conf
        log_success "Core dumps restricted"
    fi
fi

if [ -f "/etc/sysctl.conf" ]; then
    if ! grep -q "fs.suid_dumpable" /etc/sysctl.conf; then
        echo "fs.suid_dumpable = 0" >> /etc/sysctl.conf
        sysctl -w fs.suid_dumpable=0 >/dev/null 2>&1
    fi
fi

log_complete "Module 01 finished"
