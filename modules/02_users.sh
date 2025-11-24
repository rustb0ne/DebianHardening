#!/bin/bash

# Load utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"
source "$LIB_DIR/utils.sh"

log_module "02" "User & Password Security"
echo ""

# Install password quality library
log_info "Installing libpam-pwquality"
apt install -y libpam-pwquality
if [ $? -eq 0 ]; then
    log_success "libpam-pwquality installed."
else
    log_error "Failed to install libpam-pwquality"
    exit 1
fi
echo ""

# Setup password policy
PAM_PW="/etc/pam.d/common-password"
if confirm_action "Configure strict password policy? (minlen=14, complexity requirements)" "y"; then
    
    PARAMS="minlen=14 dcredit=-1 ucredit=-1 ocredit=-1 lcredit=-1"
    log_info "Setting password parameters: $PARAMS"
    
    if grep -q "pam_pwquality.so" "$PAM_PW"; then
        sed -i "s/pam_pwquality.so.*/pam_pwquality.so retry=3 $PARAMS/" "$PAM_PW"
    else
        log_warn "pam_pwquality.so not found in $PAM_PW. Appending it, but verify order"
        echo "password requisite pam_pwquality.so retry=3 $PARAMS" >> "$PAM_PW"
    fi
    log_success "Password policy configured"
else
    log_warn "Skipped Password policy configuration"
fi
echo ""

# Setup account lockout
PAM_AUTH="/etc/pam.d/common-auth"
if confirm_action "Configure account lockout policy? (5 failed attempts = 15 min lock)" "y"; then
    
    if ! grep -q "pam_faillock.so" "$PAM_AUTH"; then
        log_info "Adding pam_faillock.so: deny=5 unlock_time=900"
        sed -i "1s/^/auth required pam_faillock.so preauth silent audit deny=5 unlock_time=900\n/" "$PAM_AUTH"
        log_success "Lockout policy configured."
    else
        log_info "pam_faillock.so already present in $PAM_AUTH"
    fi
else
    log_warn "Skipped Lockout policy configuration"
fi
echo ""

# Create admin user
ADMIN_USER=${NEW_ADMIN_USER:-"sysadmin"}

if id "$ADMIN_USER" &>/dev/null; then
    log_info "User $ADMIN_USER already exists"
else
    if confirm_action "Create new admin user '$ADMIN_USER' with sudo privileges?" "y"; then
        log_info "Creating user: $ADMIN_USER"
        useradd -m -s /bin/bash "$ADMIN_USER"
        
        # Generate random password
        RAND_PASS=$(openssl rand -base64 16)
        echo "$ADMIN_USER:$RAND_PASS" | chpasswd
        
        log_success "User $ADMIN_USER created."
        log_warn "IMPORTANT: Password: $RAND_PASS"
        echo "Please save this password and change it after first login"
    else
        log_warn "Skipped Admin user creation"
    fi
fi

if id "$ADMIN_USER" &>/dev/null; then
    log_info "Add $ADMIN_USER to sudo group"
    usermod -aG sudo "$ADMIN_USER"
    log_success "User added to sudo group"
fi
echo ""

# Lock root account
if confirm_action "Lock root account? (You must have sudo user access!)" "y"; then
    log_error "WARNING: Ensure you can login with $ADMIN_USER before proceeding"
    if confirm_action "FINAL WARNING: Lock root account now?" "n"; then
        log_info "Running passwd -l root"
        passwd -l root
        log_success "Root account locked"
    else
        log_warn "Skipped Root account lock"
    fi
else
    log_warn "Skipped Root account lock"
fi
echo ""

# Set default umask for users
if confirm_action "Set secure default UMASK (027) for all users?" "y"; then
    log_info "Configuring default UMASK in /etc/profile"
    if ! grep -q "^umask 027" /etc/profile; then
        echo "umask 027" >> /etc/profile
        log_success "UMASK 027 configured in /etc/profile"
    fi
    
    if ! grep -q "^umask 027" /etc/bash.bashrc; then
        echo "umask 027" >> /etc/bash.bashrc
        log_success "UMASK 027 configured in /etc/bash.bashrc"
    fi
else
    log_warn "Skipped UMASK configuration"
fi
echo ""

# Password aging policy
if confirm_action "Configure password aging policy? (max 90 days, min 7 days, warn 14 days)" "y"; then
    LOGIN_DEFS="/etc/login.defs"
    
    log_info "Setting password aging policy"
    sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/' "$LOGIN_DEFS"
    sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   7/' "$LOGIN_DEFS"
    sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   14/' "$LOGIN_DEFS"
    
    # Set umask
    sed -i 's/^UMASK.*/UMASK           027/' "$LOGIN_DEFS"
    
    log_success "Password aging configured"
    echo "  - Max password age: 90 days"
    echo "  - Min password age: 7 days"
    echo "  - Warning period: 14 days"
    echo "  - UMASK: 027"
else
    log_warn "Skipped Password aging policy"
fi
echo ""

# Disable unused accounts
if confirm_action "Disable unused system accounts?" "y"; then
    log_info "Checking for unused system accounts to disable"
    
    # List of accounts to potentially disable
    DISABLE_USERS="games news uucp proxy www-data backup list irc gnats"
    
    for user in $DISABLE_USERS; do
        if id "$user" >/dev/null 2>&1; then
            usermod -L -s /usr/sbin/nologin "$user" 2>/dev/null
            log_success "Disabled account: $user"
        fi
    done
else
    log_warn "Skipped Disabling unused accounts"
fi
echo ""

# Set shell timeout (CIS 5.4.5)
if confirm_action "Set shell timeout (15 minutes of inactivity)?" "y"; then
    log_info "Setting TMOUT=900 (15 minutes)"
    
    if ! grep -q "^TMOUT=" /etc/profile.d/tmout.sh 2>/dev/null; then
        echo "TMOUT=900" > /etc/profile.d/tmout.sh
        echo "readonly TMOUT" >> /etc/profile.d/tmout.sh
        echo "export TMOUT" >> /etc/profile.d/tmout.sh
        chmod 644 /etc/profile.d/tmout.sh
        log_success "Shell timeout configured (15 minutes)"
    else
        log_info "TMOUT already configured"
    fi
else
    log_warn "Skipped shell timeout"
fi
echo ""

log_complete "Module 02 finished"
