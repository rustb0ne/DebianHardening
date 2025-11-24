#!/bin/bash

# Load utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"
source "$LIB_DIR/utils.sh"

log_module "03" "SSH and Firewall"
echo ""

# Harden SSH config
SSH_CONFIG="/etc/ssh/sshd_config"

# Check if SSH is installed
if [ ! -f "$SSH_CONFIG" ]; then
    log_warn "SSH config file not found at $SSH_CONFIG"
    log_info "Install openssh-server"
    apt install -y openssh-server
    
    if [ ! -f "$SSH_CONFIG" ]; then
        log_error "Failed to install SSH server or config file still missing"
        log_warn "Skipping SSH hardening"
        # Skip to firewall section
        echo ""
    else
        log_success "SSH server installed"
    fi
fi

if [ -f "$SSH_CONFIG" ] && confirm_action "Harden SSH configuration? (Disable root login, enforce key auth)" "y"; then
    
    log_info "Config SSH hardening"
    
    # Set protocol 2
    echo "  - Setting Protocol 2"
    if grep -q "^Protocol" "$SSH_CONFIG"; then
        sed -i 's/^Protocol.*/Protocol 2/' "$SSH_CONFIG"
    else
        echo "Protocol 2" >> "$SSH_CONFIG"
    fi
    
    # Disable root login
    echo "  - Disabling root login (PermitRootLogin no)"
    if grep -q "^PermitRootLogin" "$SSH_CONFIG"; then
        sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' "$SSH_CONFIG"
    else
        echo "PermitRootLogin no" >> "$SSH_CONFIG"
    fi
    
    # Enable pubkey auth
    echo "  - Enabling public key authentication"
    if grep -q "^PubkeyAuthentication" "$SSH_CONFIG"; then
        sed -i 's/^PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSH_CONFIG"
    else
        echo "PubkeyAuthentication yes" >> "$SSH_CONFIG"
    fi
    
    # Additional SSH hardening
    echo "  - Additional SSH hardening options"
    
    # Disable empty passwords
    if grep -q "^PermitEmptyPasswords" "$SSH_CONFIG"; then
        sed -i 's/^PermitEmptyPasswords.*/PermitEmptyPasswords no/' "$SSH_CONFIG"
    else
        echo "PermitEmptyPasswords no" >> "$SSH_CONFIG"
    fi
    
    # Disable X11 forwarding
    if grep -q "^X11Forwarding" "$SSH_CONFIG"; then
        sed -i 's/^X11Forwarding.*/X11Forwarding no/' "$SSH_CONFIG"
    else
        echo "X11Forwarding no" >> "$SSH_CONFIG"
    fi
    
    # Set max auth tries
    if grep -q "^MaxAuthTries" "$SSH_CONFIG"; then
        sed -i 's/^MaxAuthTries.*/MaxAuthTries 3/' "$SSH_CONFIG"
    else
        echo "MaxAuthTries 3" >> "$SSH_CONFIG"
    fi
    
    # Set login grace time
    if grep -q "^LoginGraceTime" "$SSH_CONFIG"; then
        sed -i 's/^LoginGraceTime.*/LoginGraceTime 60/' "$SSH_CONFIG"
    else
        echo "LoginGraceTime 60" >> "$SSH_CONFIG"
    fi
    
    # Disable host-based authentication
    if grep -q "^HostbasedAuthentication" "$SSH_CONFIG"; then
        sed -i 's/^HostbasedAuthentication.*/HostbasedAuthentication no/' "$SSH_CONFIG"
    else
        echo "HostbasedAuthentication no" >> "$SSH_CONFIG"
    fi
    
    # Use privilege separation
    if grep -q "^UsePrivilegeSeparation" "$SSH_CONFIG"; then
        sed -i 's/^UsePrivilegeSeparation.*/UsePrivilegeSeparation sandbox/' "$SSH_CONFIG"
    fi
    
    # Strong ciphers only
    if ! grep -q "^Ciphers" "$SSH_CONFIG"; then
        echo "Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr" >> "$SSH_CONFIG"
    fi
    
    # Strong MACs only
    if ! grep -q "^MACs" "$SSH_CONFIG"; then
        echo "MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256" >> "$SSH_CONFIG"
    fi
    
    # Strong key exchange algorithms
    if ! grep -q "^KexAlgorithms" "$SSH_CONFIG"; then
        echo "KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256" >> "$SSH_CONFIG"
    fi
    
    # Keep password authentication enabled (easier for learning)
    echo "  - Keeping PasswordAuthentication yes (easier for beginners)"
    if grep -q "^PasswordAuthentication" "$SSH_CONFIG"; then
        sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' "$SSH_CONFIG"
    else
        echo "PasswordAuthentication yes" >> "$SSH_CONFIG"
    fi
    
    log_warn "NOTE: For production, disable password auth and use SSH keys only"
    
    log_success "SSH configuration hardened."
else
    log_warn "Skipped: SSH hardening"
fi
echo ""

# Restart SSH service
if [ -f "$SSH_CONFIG" ]; then
    if confirm_action "Restart SSH service to apply changes?" "y"; then
        log_info "Running: systemctl restart sshd"
        log_warn "Existing SSH connections should remain active."
        
        # Try different service names
        if systemctl restart sshd 2>/dev/null; then
            log_success "SSH service restarted successfully."
            log_warn "Test new SSH connection in another terminal before closing this one!"
        elif systemctl restart ssh 2>/dev/null; then
            log_success "SSH service restarted successfully."
            log_warn "Test new SSH connection in another terminal before closing this one!"
        else
            log_error "Failed to restart SSH! Service may not be running."
            log_warn "Try manually: sudo systemctl restart sshd"
        fi
    else
        log_warn "Skipped: SSH restart (manual restart required)"
    fi
else
    log_warn "SSH not configured, skipping restart"
fi
echo ""

# Setup firewall
if confirm_action "Configure UFW firewall? (Will allow SSH, deny all other incoming)" "y"; then
    log_info "Installing UFW..."
    apt install -y ufw
    
    log_warn "This will reset existing UFW rules!"
    if confirm_action "Reset UFW and configure new rules?" "y"; then
        log_info "Resetting UFW to defaults"
        ufw --force reset
        
        log_info "Setting default policies:"
        echo "  - Deny incoming"
        echo "  - Allow outgoing"
        ufw default deny incoming
        ufw default allow outgoing
        
        log_info "Allowing SSH (port 22)"
        ufw allow ssh
        
        log_info "Enabling UFW..."
        echo "y" | ufw enable
        
        log_success "UFW configured and enabled."
        echo ""
        log_info "UFW Status:"
        ufw status info
    else
        log_warn "Skipped: UFW reset and configuration"
    fi
else
    log_warn "Skipped: UFW configuration"
fi

log_complete "Module 03 finished."
