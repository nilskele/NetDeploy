# NetDeploy

**Automated network device configuration deployment for Cisco IOS routers and switches using PowerShell and SSH.**

---

## 1. What is NetDeploy?

NetDeploy is a PowerShell-based automation framework for deploying configurations to network devices in lab and production environments. It eliminates manual configuration tasks by:

- **Loading device configurations** from a centralized JSON file
- **Validating** all configurations against device-type schemas
- **Generating Cisco IOS commands** automatically from structured data
- **Backing up** existing configurations before any changes
- **Deploying via SSH** using PowerShell's Posh-SSH module
- **Providing dry-run mode** for safe testing without touching devices

### Key Benefits

- ✅ **Infrastructure as Code**: Store network configs in version control (Git)
- ✅ **Consistency**: Eliminate human typos and configuration drift
- ✅ **Safety**: Automatic backups before deployment + dry-run preview
- ✅ **Scalability**: Deploy to 1 device or 100 devices in parallel
- ✅ **Auditability**: Complete logging of all operations with job-scoped logs
- ✅ **Flexibility**: Interactive TUI or command-line automation

### What It Supports

**Device Types:**
- Cisco IOS Routers (interfaces, OSPF, BGP, NAT, DHCP, DNS, ACLs)
- Cisco IOS Switches (VLANs, trunk/access ports, SVIs, STP, EtherChannel)
- Linux/Unix Hosts (basic network configuration templates)

**Protocols & Features:**
- OSPF routing with area and wildcard mask support
- Static routes and default gateways
- DHCP server pools with excluded addresses
- NAT/PAT (inside/outside interfaces, static mappings, pools)
- DNS configuration (domain name, name servers, host entries)
- AAA local users with privilege levels
- NTP, Syslog, ACLs
- VTY line configuration for SSH access (prevents lockouts)

---

## 2. Project Structure & Capabilities

### Directory Structure

```
NetDeploy/
├── NetDeploy.psd1              # PowerShell module manifest
├── NetDeploy.psm1              # Main module file (public API)
├── README.md                   # This file
├── core/                       # Core functionality modules
│   ├── PathLoader.ps1          # Centralized path configuration
│   ├── Utils.ps1               # Logging, validation, helpers (13 functions)
│   ├── DeviceLoader.ps1        # JSON device loading (5 functions)
│   ├── deviceValidator.ps1     # Configuration validation (5 functions)
│   ├── CommandBuilder.ps1      # Cisco IOS command generation (7 functions)
│   └── SSHDeploy.ps1           # SSH operations and deployment (5 functions)
├── tui/                        # Text User Interface
│   ├── DeploymentUI.ps1        # Main TUI entry point
│   ├── Menu.ps1                # Menu display functions
│   └── DeviceSelector.ps1      # Device selection logic
├── configs/                    # Configuration files
│   ├── devices/                
│   │   └── devices.json        # Device configuration database (JSON)
│   └── base-configs/           # Manual recovery configurations
│       ├── R1-base.txt         # Router base configs (copy-paste ready)
│       ├── R2-base.txt
│       ├── R3-base.txt
│       ├── S1-base-config.txt  # Switch base configs
│       ├── S2-base-config.txt
│       └── README.md           # Instructions for manual recovery
├── examples/                   # Example device configurations
│   ├── router-example.psd1
│   ├── switch-example.psd1
│   └── host-example.psd1
└── logs/                       # Runtime logs (auto-created)
    ├── NetDeploy-YYYYMMDD.log  # Daily general log
    ├── execution.log           # Legacy execution log
    ├── jobs/                   # Per-run job logs
    │   └── <RunName>-<timestamp>-<rand>.log
    └── backups/                # Device configuration backups
        └── <hostname>-<timestamp>.cfg
```

### Core Components

#### PathLoader.ps1 (Centralized Configuration)
- Defines all directory paths used by NetDeploy
- Variables: `$script:NetDeployRoot`, `$script:NetDeployLogsDir`, `$script:NetDeployBackupsDir`, etc.
- SSH defaults: Port 22, Timeout 10s, Retries 3
- **Edit this file to change default paths globally**

#### Utils.ps1 (13 utility functions)
- `Write-Log` - Console and file logging with job context
- `New-LogJob` / `Close-LogJob` - Job-scoped logging sessions
- `Convert-MaskToWildcard` - Subnet to wildcard conversion for OSPF
- `Test-ValidIP` - IP address validation
- `Sort-DevicesForDeployment` - Orders devices (Routers → Switches → Hosts)
- Additional helpers for validation, timing, credential creation

#### DeviceLoader.ps1 (5 functions)
- `Load-AllDevices` - Loads devices from JSON file or directory
- `Load-DeviceByName` - Loads single device by hostname
- `Merge-ConfigWithSchema` - Fills in defaults from inline schema templates
- Supports both JSON array and `{devices: [...]}` format
- Default schemas defined inline: `$Global:DefaultRouterSchema`, `$Global:DefaultSwitchSchema`, `$Global:DefaultHostSchema`

#### deviceValidator.ps1 (5 functions)
- `Validate-Device` - Main validation dispatcher
- `Validate-Router` - Router-specific validation (interfaces, OSPF, NAT, DHCP, DNS)
- `Validate-Switch` - Switch-specific validation (VLANs, interfaces, SVIs)
- `Validate-Host` - Host-specific validation (IP, gateway, DNS)
- `Validate-AllDevices` - Batch validation
- **Note:** Validation rules are defined inline in this file, not loaded from schemas/ folder

#### CommandBuilder.ps1 (7 functions)
- `Build-Commands` - Main dispatcher by device type
- `Build-RouterCommands` - Generates complete router CLI commands
  - Hostname, AAA users, interfaces, static routes, OSPF, NAT, DHCP, DNS
  - NTP, Syslog, ACLs, **VTY lines for SSH**, console configuration
- `Build-SwitchCommands` - Generates complete switch CLI commands
  - VLANs, interfaces (access/trunk/routed), SVIs, default gateway
  - Static routes, STP, DHCP relay, EtherChannel
- `Build-HostCommands` - Linux/Unix host configuration templates

#### SSHDeploy.ps1 (5 functions)
- `Connect-SSH` - SSH connection with retry logic and auto-accept keys
- `Backup-DeviceConfig` - Shell stream-based backup (5-second wait for complete output)
- `Deploy-Device` - Single device deployment (backup → connect → deploy → cleanup)
- `Deploy-AllDevices` - Multi-device orchestration (sequential or parallel)
- **Uses SSH shell streams exclusively** (Invoke-SSHCommand incompatible with Cisco IOS)

### Public API Functions (NetDeploy.psm1)

| Function | Purpose |
|----------|---------|
| `Invoke-DeviceDeployment` | Deploy configuration to single device |
| `Invoke-AllDeviceDeployment` | Deploy to multiple devices (sequential or parallel) |
| `Load-Devices` | Load device configurations from JSON |
| `Test-AllDevices` | Validate all device configurations |
| `Set-NetDeployPaths` | Configure custom paths for logs/backups/devices |
| `Get-NetDeployPaths` | Retrieve current path configuration |

### What You Can Do With NetDeploy

1. **Single Device Deployment**
   - Deploy to one router/switch with full backup and logging
   - Dry-run preview before actual deployment
   - Custom command delays between commands

2. **Multi-Device Deployment**
   - Deploy to multiple devices sequentially or in parallel
   - Throttle concurrent jobs (default: 10 max)
   - Single job log for entire deployment run
   - Named runs for easy log identification

3. **Interactive TUI**
   - Menu-driven device selection
   - Visual device list with filtering options
   - Deployment mode selection (sequential/parallel)
   - View recent backups and job logs
   - Dry-run confirmation prompts

4. **Configuration Management**
   - Store all device configs in version control (Git)
   - JSON-based device definitions
   - Schema validation before deployment
   - Automatic backup before changes

5. **Logging & Auditing**
   - Daily general logs (`NetDeploy-YYYYMMDD.log`)
   - Per-run job logs with timestamps
   - Device configuration backups with timestamps
   - Complete command execution traces

6. **Recovery & Safety**
   - Base configuration files for manual recovery
   - SSH lockout prevention (VTY line auto-config)
   - Dry-run mode for testing
   - Backup-before-deploy workflow

---

## 3. How to Use NetDeploy (Complete Walkthrough)

### Prerequisites

**Required:**
- PowerShell 7+ (pwsh) - [Download here](https://github.com/PowerShell/PowerShell/releases)
- Posh-SSH module for SSH connectivity
- **Network connectivity from your deployment machine to all target devices**

**Install Posh-SSH:**
```powershell
Install-Module -Name Posh-SSH -Scope CurrentUser -Force
```

**Verify installation:**
```powershell
Get-Module -ListAvailable Posh-SSH
```

**Network Connectivity Requirements:**

NetDeploy requires IP reachability from the machine running the script to every device's management IP. This is critical - SSH cannot connect without proper routing.

**Common scenarios:**

1. **Direct Management Network Access:**
   - Your deployment machine is on the same management network as all devices
   - Example: All devices on 192.168.1.0/24, your machine is 192.168.1.100

2. **Multi-Network Lab with Static Routes (Recommended):**
   - Devices spread across multiple networks
   - Add static routes on your deployment machine to reach all networks
   
   **Example Setup:**
   ```bash
   # Deployment machine: Ubuntu at 192.168.122.73
   # Router R1: 192.168.122.254 (gateway to other networks)
   # Router R2: 10.0.2.2 (accessible via R1)
   # Router R3: 10.0.1.2 (accessible via R1)
   # Switch S1: 10.2.0.10 (on R2's LAN)
   # Switch S2: 10.3.0.10 (on R3's LAN)
   
   # Add static routes to reach all device networks
   sudo ip route add 10.0.1.0/30 via 192.168.122.254  # R1-R3 link
   sudo ip route add 10.0.2.0/30 via 192.168.122.254  # R1-R2 link
   sudo ip route add 10.2.0.0/24 via 192.168.122.254  # R2 LAN
   sudo ip route add 10.3.0.0/24 via 192.168.122.254  # R3 LAN
   
   # Verify connectivity
   ping 192.168.122.254  # R1
   ping 10.0.2.2         # R2
   ping 10.0.1.2         # R3
   ping 10.2.0.10        # S1
   ping 10.3.0.10        # S2
   ```


---

### Step 1: Download NetDeploy

**Option A: Git Clone (Recommended)**
```powershell
git clone https://github.com/nilskele/NetDeploy.git
cd NetDeploy
```

**Option B: Download ZIP**
1. Download from GitHub: `Code` → `Download ZIP`
2. Extract to desired location
3. Open PowerShell in extracted directory

---

### Step 2: Import the Module

From the NetDeploy directory:

```powershell
# Import module manifest (recommended)
Import-Module -Force ./NetDeploy.psd1 -Verbose

# Verify module loaded
Get-Module NetDeploy

# List available commands
Get-Command -Module NetDeploy
```

**Output:**
```
CommandType     Name                           Version    Source
-----------     ----                           -------    ------
Function        Get-NetDeployPaths            1.0        NetDeploy
Function        Invoke-AllDeviceDeployment    1.0        NetDeploy
Function        Invoke-DeviceDeployment       1.0        NetDeploy
Function        Load-Devices                  1.0        NetDeploy
Function        Set-NetDeployPaths            1.0        NetDeploy
Function        Test-AllDevices               1.0        NetDeploy
```

---

### Step 3: Configure Paths (Optional but Recommended)

**Default Paths:**
NetDeploy uses these paths relative to the module root by default:
- Devices: `configs/devices/`
- Logs: `logs/`
- Backups: `logs/backups/`
- Jobs: `logs/jobs/`

**To customize paths:**

```powershell
# Set custom directories (absolute or relative paths)
Set-NetDeployPaths `
    -DevicesPath "C:\NetworkLab\devices" `
    -LogsPath "C:\NetworkLab\logs" `
    -BackupsPath "C:\NetworkLab\logs\backups" `
    -JobsPath "C:\NetworkLab\logs\jobs"

# Verify configuration
Get-NetDeployPaths | Format-List
```

**Where to find path configuration:**
- Paths are defined in: `core/PathLoader.ps1`
- Edit this file to change default paths permanently
- Variables: `$script:NetDeployDevicesDir`, `$script:NetDeployLogsDir`, etc.

**Path configuration is loaded automatically** when you import the module.

---

### Step 4: Prepare Device Configurations

**Device configuration file:** `configs/devices/devices.json`

This JSON file contains all your network devices. Example structure:

```json
[
  {
    "Hostname": "R1",
    "DeviceType": "Router",
    "ManagementIP": "192.168.1.1",
    "SSHPort": 22,
    "Credentials": {
      "Username": "admin",
      "Password": "cisco"
    },
    "Interfaces": [
      {
        "Name": "GigabitEthernet0/0",
        "IP": "192.168.1.1",
        "Mask": "255.255.255.0",
        "Description": "Management",
        "Status": "up"
      }
    ],
    "Routing": {
      "OSPF": {
        "Enabled": true,
        "ProcessID": 1,
        "RouterID": "1.1.1.1",
        "Networks": [
          {
            "Network": "192.168.1.0",
            "Mask": "255.255.255.0",
            "Area": 0
          }
        ]
      }
    }
  }
]
```

**See example files:**
- `examples/router-example.psd1`
- `examples/switch-example.psd1`
- `examples/host-example.psd1`

---

### Step 5A: Use the Interactive TUI (Easiest)

**Launch the TUI:**
```powershell
pwsh -NoProfile -File ./tui/DeploymentUI.ps1
```

**TUI Workflow:**

1. **Main Menu** appears with options:
   - `[1] Deploy devices`
   - `[2] Show loaded devices`
   - `[3] List recent backups`
   - `[4] View a backup`
   - `[5] Exit`

2. **Select option 1** to deploy

3. **Device Selection Screen**:
   ```
   Select devices to operate on:
   [1] R1 [Router] (192.168.1.1)
   [2] R2 [Router] (10.0.2.2)
   [3] S1 [Switch] (10.2.0.10)
   
   Selection: 1,3        # Deploy to R1 and S1
   Selection: all        # Deploy to all devices
   Selection: 2-3        # Deploy to R2 and S1 (range)
   ```

4. **Deployment Mode**:
   ```
   [1] Sequential (one-by-one)
   [2] Parallel (start a job per device)
   Select mode: 2
   ```

5. **Parallel Settings** (if parallel selected):
   ```
   Enter throttle (max concurrent jobs) [default 10]: 5
   ```

6. **Dry-Run Confirmation**:
   ```
   Perform dry-run only? [Y/n] (default Y): Y
   ```
   - `Y` = Preview only (safe, no devices touched)
   - `n` = Live deployment (backs up and applies changes)

7. **Run Name** (optional):
   ```
   Enter a name for this run: lab-deployment-01
   ```

8. **Final Confirmation**:
   ```
   About to deploy 2 device(s). Mode: Parallel
   Concurrency (throttle): 5
   DryRun: True
   Continue? [y/N]: y
   ```

9. **Deployment executes** - watch progress in real-time

10. **Check logs:**
    ```
    logs/jobs/lab-deployment-01-20251222-143052-8472.log
    ```

---

### Step 5B: Use Command-Line API (Advanced)

**Load Devices:**
```powershell
# Load all devices from default location
$devices = Load-Devices

# Or specify custom path
$devices = Load-Devices -Path "./configs/devices/devices.json"

# View loaded devices
$devices | Select-Object Hostname, DeviceType, ManagementIP | Format-Table
```

**Single Device Dry-Run:**
```powershell
# Get first device
$device = $devices[0]

# Preview deployment (no changes made)
Invoke-DeviceDeployment -Device $device -DryRun -RunName "test-dryrun"
```

**Single Device Live Deployment:**
```powershell
# Deploy with backup and 1-second command delay
Invoke-DeviceDeployment `
    -Device $device `
    -CommandDelay 1 `
    -RunName "router-r1-deploy"
```

**Multi-Device Sequential Deployment:**
```powershell
# Deploy to multiple devices one at a time
$selectedDevices = $devices | Where-Object { $_.DeviceType -eq "Router" }

Invoke-AllDeviceDeployment `
    -Devices $selectedDevices `
    -CommandDelay 1 `
    -RunName "all-routers-deploy"
```

**Multi-Device Parallel Deployment:**
```powershell
# Deploy to all devices in parallel (max 5 concurrent)
Invoke-AllDeviceDeployment `
    -Devices $devices `
    -Parallel `
    -Throttle 5 `
    -RunName "full-network-deploy"
```

**Validate Configurations Before Deployment:**
```powershell
# Validate all device configs
Test-AllDevices -Folder "./configs/devices"

# Validation checks:
# - Required fields present
# - Valid IP addresses
# - OSPF configuration correctness
# - VLAN IDs in valid range
# - Interface configurations
```

---

### Step 6: Understanding Logs

**Log Files:**

1. **Daily General Log:**
   - Location: `logs/NetDeploy-YYYYMMDD.log`
   - Contains: All general events, START/END markers

2. **Per-Run Job Logs:**
   - Location: `logs/jobs/<RunName>-<timestamp>-<rand>.log`
   - Contains: All operations for that specific deployment run
   - Example: `logs/jobs/lab-deploy-20251222-143052-8472.log`

3. **Device Backups:**
   - Location: `logs/backups/<hostname>-<timestamp>.cfg`
   - Contains: Running-config backup before deployment
   - Example: `logs/backups/R1-20251222-143105.cfg`

**View Recent Logs:**
```powershell
# List job logs (newest first)
Get-ChildItem -Path ./logs/jobs -File | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 10 Name, LastWriteTime

# View specific log
Get-Content -Path ./logs/jobs/lab-deploy-20251222-143052-8472.log

# Tail last 50 lines
Get-Content -Path ./logs/jobs/lab-deploy-20251222-143052-8472.log -Tail 50

# Search logs for errors
Get-Content -Path ./logs/jobs/*.log | Select-String -Pattern "ERROR|WARN"
```

---

### Step 7: Recovery & Manual Configuration

**If SSH access is lost after deployment:**

1. **Use base configuration files:**
   - Location: `configs/base-configs/`
   - Files: `R1-base.txt`, `R2-base.txt`, `R3-base.txt`, etc.

2. **Apply via console:**
   - Open GNS3 console for device
   - Enter privileged mode: `enable`
   - Copy entire base config file
   - Paste into console
   - Wait for execution
   - Verify: `show run | include vty`

3. **Base configs include:**
   - VTY line configuration (SSH access)
   - Local user accounts
   - Interface configurations
   - OSPF routing
   - All necessary for connectivity

**See:** `configs/base-configs/README.md` for detailed recovery instructions.

---

### Common Parameters Reference

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `-Device` | Object | Single device object to deploy | Required |
| `-Devices` | Array | Multiple device objects to deploy | Required |
| `-DryRun` | Switch | Preview only, no actual deployment | False (live) |
| `-Parallel` | Switch | Deploy devices concurrently | False (sequential) |
| `-Throttle` | Int | Max concurrent jobs in parallel mode | 10 |
| `-CommandDelay` | Int | Seconds between commands | 0 |
| `-RunName` | String | Custom name for job log | Auto-generated |
| `-Path` | String | Custom path to devices file/folder | Default path |

---

### Advanced Usage Examples

**Filter and deploy specific device types:**
```powershell
# Deploy only routers
$routers = $devices | Where-Object { $_.DeviceType -eq "Router" }
Invoke-AllDeviceDeployment -Devices $routers -RunName "routers-only"

# Deploy devices by hostname pattern
$borderRouters = $devices | Where-Object { $_.Hostname -like "BR*" }
Invoke-AllDeviceDeployment -Devices $borderRouters -Parallel
```

**Dry-run with detailed output:**
```powershell
Invoke-DeviceDeployment -Device $devices[0] -DryRun -Verbose | 
    ConvertTo-Json -Depth 10 | 
    Out-File -FilePath "./preview.json"
```

---
## 4. Sources & References

### PowerShell & SSH

- **Posh-SSH** - PowerShell SSH module used for all SSH operations  
  GitHub: [https://github.com/darkoperator/Posh-SSH](https://github.com/darkoperator/Posh-SSH)  
  Documentation: [https://www.powershellgallery.com/packages/Posh-SSH](https://www.powershellgallery.com/packages/Posh-SSH)

- **PowerShell 7+ Official Documentation**  
  [https://docs.microsoft.com/powershell](https://docs.microsoft.com/powershell)

### PowerShell Learning Resources

- **Adam the Automator** - Practical PowerShell tutorials and module authoring  
  [https://adamtheautomator.com](https://adamtheautomator.com)

- **Jeff Hicks** - In-depth PowerShell articles and real-world examples  
  [https://jdhitsolutions.com](https://jdhitsolutions.com)

- **PowerShell.org** - Community articles, blog posts, and advanced scripting tutorials  
  [https://powershell.org](https://powershell.org)

### Network Automation

- **Network to Code** - Network automation patterns, examples, and best practices  
  [https://networktocode.com](https://networktocode.com)

- **Cisco IOS Command Reference**  
  [https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/fundamentals/command/cf_command_ref.html](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/fundamentals/command/cf_command_ref.html)

### Video Tutorials & Labs

- **David Bombal (YouTube)** - Network lab videos, Cisco IOS, and automation demos  
  [https://www.youtube.com/c/DavidBombal](https://www.youtube.com/c/DavidBombal)

- **NetworkChuck (YouTube)** - Network automation and lab setup tutorials  
  [https://www.youtube.com/c/NetworkChuck](https://www.youtube.com/c/NetworkChuck)

### Community & Forums

- **r/PowerShell** - PowerShell community discussion  
  [https://www.reddit.com/r/PowerShell/](https://www.reddit.com/r/PowerShell/)

- **r/networking** - Networking professionals and automation discussions  
  [https://www.reddit.com/r/networking/](https://www.reddit.com/r/networking/)

- **r/Cisco** - Cisco-specific configuration and troubleshooting  
  [https://www.reddit.com/r/Cisco/](https://www.reddit.com/r/Cisco/)

### Development Resources

- **Dev.to (PowerShell tag)** - PowerShell articles and tutorials  
  [https://dev.to/t/powershell](https://dev.to/t/powershell)

- **Medium (PowerShell topic)** - Long-form PowerShell content  
  [https://medium.com/tag/powershell](https://medium.com/tag/powershell)

### GitHub Examples

- **Network Automation with Posh-SSH** - Example repositories  
  [https://github.com/search?q=posh-ssh+network+automation](https://github.com/search?q=posh-ssh+network+automation)

- **Cisco IOS Automation Examples**  
  [https://github.com/search?q=cisco+ios+automation](https://github.com/search?q=cisco+ios+automation)

### AI Chats

- https://chatgpt.com/share/69529a83-f8b8-800a-ab6e-6d1378294100
- https://chatgpt.com/share/69529ba8-843c-800a-9f34-44294c856d52
- https://chatgpt.com/share/6952a365-9878-800a-86b7-5680f996de62
- https://chatgpt.com/share/6952a39e-ea04-800a-98d6-3e81ca7a8f26
- https://chatgpt.com/share/6952a816-5128-800a-880f-27c8f5fc70f9
- https://chatgpt.com/share/6952e3bc-3e44-800a-8a40-d8963f86d7dc
##### a lot of copilot was used for debugging and for refining functions like the logging, commandbuildin, parallel throttle, ssh deployement etc...
- AI used: GPT-4.1, claude opus 4.5, Claud sonnet 4.5, GPT-5 and GPT-4
---



