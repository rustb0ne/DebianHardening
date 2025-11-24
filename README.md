# Debian Hardening Script

A hardening script for Debian 13 Trixie, designed for personal learning.  tailored for personal learning and practice. Adheres to **CIS_Debian_Linux_12_Benchmark_v1.1.0** standards to enhance system security.

## What This Script Does

This script automatically applies security hardening based on **CIS_Debian_Linux_12_Benchmark_v1.1.0** standards:

### System Hardening (Module 01)
-  System updates (apt update && upgrade)
-  File permissions (/etc/shadow: 640, /etc/passwd: 644)
-  Remove unnecessary services (xinetd, nis, bind9, vsftpd, etc.)
- Kernel hardening** via sysctl 
  - Disable IP forwarding (prevent routing attacks)
  - Enable SYN cookies (DDoS protection)
  - Block ICMP redirects (prevent MITM)
  - Disable source routing (prevent IP spoofing)
  - Enable reverse path filtering
- Disable unused filesystems + USB storage
- Secure /tmp with noexec, nodev, nosuid 
- Disable core dumps 

### User & Password Security (Module 02)
-  Password complexity (14 chars min, mixed case, digits, special)
- Account lockout (5 fails = 15 min lock) 
- Password aging (90/7/14 days) 
- **UMASK 027** for all users
- Create secure admin user with random password
- Shell timeout (15 minutes)
- Disable unused accounts (games, news, proxy, etc.)
- Lock root account

### Network Security (Module 03)
- **SSH Hardening**
  - Protocol 2 only
  - No root login
  - Password auth enabled
  - No empty passwords
  - X11 forwarding disabled
  - MaxAuthTries: 3
  - Strong ciphers (ChaCha20, AES256-GCM)
  - Strong MACs (HMAC-SHA2-512/256)
  - Strong KEX (Curve25519, DH-GEX-SHA256)
- **UFW Firewall**
  - Deny all incoming by default
  - Allow SSH only

### Logging & Auditing (Module 04)
- Auditd with comprehensive rules
  - Time modification tracking
  - Sudoers monitoring
  - User/group changes
  - File deletion auditing
- Rsyslog enabled 
- Secure log permissions
- Cron/at hardening

## Prerequisites

- Debian or Debian-based system
- Root privileges `sudo`
- **CRITICAL**: System snapshot/backup before running
- 
## Important Notes

- **IMPORTANT**: Create Timeshift snapshot before running (see above)
- **SSH**: Verify admin user login works before closing your session
- **Root Lock**: Root will be locked - ensure admin user has sudo

### Recommended: Create System Snapshot with Timeshift

```bash
# Install Timeshift
sudo apt update
sudo apt install timeshift -y

# Create snapshot (CLI)
sudo timeshift --create --comments "Before security hardening $(date +%Y-%m-%d)"
```

**To restore if something goes wrong:**
```bash
# List available snapshots
sudo timeshift --list

# Restore from latest snapshot
sudo timeshift --restore
```

## Usage

### Installation

```bash
# Clone or download the repository
git clone https://github.com/rustb0ne/DebianHardening.git
cd DebianHardening

# Make scripts executable
chmod +x main.sh modules/*.sh
```

### Running the Script

```bash
# Interactive mode
sudo ./main.sh

# Force mode (skip all confirmations)
sudo ./main.sh --force
```

### Setting Custom Admin Username

```bash
# Set custom admin username (default: sysadmin)
sudo NEW_ADMIN_USER="myuser" ./main.sh
```

### After Running

1. Save the new admin password
2. Test SSH login with new admin user before logging out
3. Verify firewall allows SSH

## Project Structure

```
DebianHardening/
├── main.sh                     # Main orchestrator script
├── README.md                   # Documentation
├── lib/
│   └── utils.sh               # Helper functions
│       ├── log_info()         
│       ├── log_success()      
│       ├── log_warn()         
│       ├── log_error()        
│       ├── log_module()       
│       ├── log_complete() 
│       ├── check_root()       # Root privilege check
│       └── confirm_action()   # User confirmation prompt
└── modules/
    ├── 01_system.sh           # System updates & kernel hardening
    ├── 02_users.sh            # User & password policies
    ├── 03_network.sh          # SSH & Firewall configuration
    └── 04_logging.sh          # Auditd & logging setup
```

## Testing & Verification

After running the script, verify the hardening:

```bash
# Check SSH configuration
sudo sshd -t

# Check firewall status
sudo ufw status verbose

# Check audit rules
sudo auditctl -l

# Check password policy
sudo pwscore <<< "TestPass123!"

# Check failed login attempts
sudo faillock --user username

# Run Lynis security audit
sudo lynis audit system
```
Lynis score before

![alt text](<img2.png>)

Lynis score after

![alt text](<img1.png>)

