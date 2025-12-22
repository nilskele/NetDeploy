# Base Configuration Files

These are **safe base configuration files** that guarantee SSH access remains functional.

## Purpose

Use these files when:
- You've lost SSH access after a deployment
- You want to manually reset a router to a known-good state
- You're testing and need a quick way to restore connectivity

## Files

### R1-base.txt
- **Management IP:** 192.168.122.254
- **Username:** admin
- **Password:** cisco
- **Interfaces:** Gi0/0 (Management), Gi0/1 (to R3), Gi0/2 (to R2)
- **OSPF:** Enabled, Router ID 1.1.1.1, Area 0

### R2-base.txt
- **Management IP:** 10.0.2.2 (accessible via R1)
- **Username:** admin
- **Password:** cisco
- **Interfaces:** Gi0/0 (to R1), Gi0/1 (LAN Switch)
- **OSPF:** Enabled, Router ID 2.2.2.2, Area 0

### R3-base.txt
- **Management IP:** 10.0.1.2 (accessible via R1)
- **Username:** admin
- **Password:** cisco
- **Interfaces:** Gi0/0 (to R1), Gi0/1 (LAN Switch)
- **OSPF:** Enabled, Router ID 3.3.3.3, Area 0

## How to Apply

### Option 1: Copy-Paste via Console (Recommended)
1. Open GNS3 console for the router
2. Enter privileged mode: `enable`
3. Copy entire configuration file
4. Paste into console
5. Wait for all commands to execute
6. Verify with `show run` and `show ip interface brief`

### Option 2: Copy-Paste Line by Line
If bulk paste causes issues:
1. Open configuration file
2. Copy commands in small sections (5-10 lines)
3. Paste and wait for prompt
4. Continue until complete

### Option 3: TFTP (If Available)
```bash
# On router
copy tftp://192.168.122.73/R1-base.txt running-config
```

## What Makes These "Safe"

These configurations include:
1. **VTY lines** configured for SSH with `login local`
2. **Local user account** (admin/cisco) with privilege 15
3. **Enable secret** set to cisco
4. **SSH keys** generated with `crypto key generate rsa`
5. **Proper interface configurations** that maintain connectivity
6. **OSPF** configured correctly without breaking access

## After Applying

Test SSH access:
```bash
ssh admin@192.168.122.254  # For R1
ssh admin@10.0.2.2         # For R2 (via R1)
ssh admin@10.0.1.2         # For R3 (via R1)
```

## The SSH Lockout Issue

**What was happening:**
Our NetDeploy CommandBuilder was missing VTY line configuration, so after deployment:
- SSH users/passwords were set
- But VTY lines weren't configured to use them
- Result: SSH connections rejected

**Fixed in latest version:**
The CommandBuilder now includes:
```
line vty 0 4
 login local
 transport input ssh
 exec-timeout 30 0
```

This ensures SSH access is always maintained after deployment.
