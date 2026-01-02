# NetDeploy

**Automated Network Device Configuration Deployment Tool**


---

## Doel van het Project

NetDeploy is een PowerShell-gebaseerde automatiseringstool ontwikkeld voor het deployen en valideren van configuraties op netwerkapparaten zoals switches, routers en servers.

Het stelt netwerkbeheerders in staat om:
- **Configuratietemplates** te laden vanuit JSON-formaat
- **Automatisch verbinding** te maken met apparaten via SSH
- **Configuraties te deployen** op Cisco IOS devices
- **Backups te maken** vóór elke deployment
- **Validatie uit te voeren** na deployment (connectivity checks)
- **Real-time feedback** te krijgen via een interactieve TUI

### MVP (Minimum Viable Product)

Dit project bevat **alle MVP functionaliteiten** zoals gedefinieerd in het projectvoorstel:

**1. Configuration Deployment via SSH**  
Automatisch verbinden met Cisco devices via PowerShell + Posh-SSH en configuraties pushen.

**2. Template Management**  
JSON templates laden en correct parsen voor elk device type (Router, Switch, Host).

**3. Connectivity Validation**  
Geautomatiseerde reachability checks (Test-Connection) na deployment.

**4. Text-Based User Interface (TUI)**  
Intuïtieve interface voor device selectie, progress monitoring en real-time resultaten.

**5. Logging and Reporting**  
Gestructureerde logs van alle deployment acties in CSV/text formaat voor auditing.

### Bonus Features (Beyond MVP)

**Backup and Rollback Mechanism** - Automatische backups vóór deployment, wel geen automatische rollback 
**Parallel Deployments** - Simultane deployment naar meerdere devices met aanpasbare throttle 
**Enhanced TUI Visual Feedback** - Color-coded status indicators  
**Native SSH Fallback** - Ondersteuning voor legacy Cisco devices met oude KEX algorithms  

### Ontwikkeld Voor

Dit project is ontwikkeld als onderdeel van een academische opdracht voor system automation en scripting met PowerShell. Het is volledig getest in een virtuele GNS3-omgeving op macOS met Cisco IOSv routers en IOU switches.

---

## Quick Start voor Testing


### Optie A: Testen met Voorbeelddata (Zonder Netwerk)

```powershell
# 1. Open PowerShell 7
pwsh

# 2. Navigeer naar project directory
cd /pad/naar/NetDeploy

# 3. Installeer Posh-SSH (eenmalig)
Install-Module -Name Posh-SSH -Scope CurrentUser -Force

# 4. Importeer NetDeploy module
Import-Module ./NetDeploy.psd1 -Force

# 5. Test met DRY-RUN (geen echte deployment)
$devices = Load-Devices -Path "./configs/devices/devices.json"
Invoke-DeviceDeployment -Device $devices[0] -DryRun

# Output: Toont gegenereerde Cisco IOS commando's zonder te deployen
```

**Verwacht resultaat:** Je ziet alle Cisco IOS commando's die gegenereerd zijn voor Router R1, inclusief interface configuratie, OSPF routing, etc.

### Optie B: Testen met TUI (Interactive)

```powershell
# 1. Start de TUI
Start-NetDeployUI

# 2. Selecteer optie 1: Deploy devices
# 3. Kies dry-run mode (Y/N): Y
# 4. Selecteer devices: 'all' of specifiek nummer
# 5. Bekijk gegenereerde commando's
```

**Verwacht resultaat:** Interactief menu met device selectie en real-time feedback.

### Optie C: Testen met Echte Devices (GNS3/Fysiek Lab)

**Let op:** Vereist toegang tot Cisco IOS devices via SSH.

```powershell
# 1. Pas device credentials aan in configs/devices/devices.json
# 2. Zorg dat devices bereikbaar zijn via SSH (Test-NetConnection)
# 3. Importeer module
Import-Module ./NetDeploy.psd1 -Force

# 4. Test connectie
$devices = Load-Devices -Path "./configs/devices/devices.json"
Test-NetConnection -ComputerName $devices[0].ManagementIP -Port 22

# 5. Deploy naar 1 device
Invoke-DeviceDeployment -Device $devices[0] -CommandDelay 1

# 6. Bekijk logs
Get-Content ./logs/NetDeploy-*.log -Tail 50

# 7. Bekijk backup
Get-ChildItem ./logs/backups/
```

**Verwacht resultaat:** 
- Pre-deployment backup in `logs/backups/`
- Configuratie deployed naar device
- Success melding in console
- Gedetailleerde logs in `logs/` directory

---

## Requirements

### Software Requirements

- **PowerShell 7.0+** (cross-platform: Windows, macOS, Linux)
- **Posh-SSH module** (v3.0+) - Voor SSH connectiviteit
- **Git** (optioneel, voor versiebeheer)

### Netwerk Requirements

Voor gebruik in een lab/test omgeving:
- **Cisco IOS devices** toegankelijk via SSH (IOSv, fysieke devices, of GNS3 virtualisatie)
- **SSH credentials** (username + password of SSH keys)
- **IP connectivity** tussen de PowerShell host en de netwerkapparaten
- **Port 22** open voor SSH verkeer


### Ondersteunde Device Types

- Cisco IOS Routers (interfaces, OSPF, static routes, NAT, DHCP, DNS, ACLs)
- Cisco IOS Switches (VLANs, trunk/access ports, SVIs, STP, EtherChannel)
- Linux/Unix Hosts (basis netwerk configuratie)

---

## Installatie

### Stap 1: PowerShell 7 Installeren

**macOS (via Homebrew):**
```bash
brew install --cask powershell
```

**Ubuntu/Debian Linux:**
```bash
wget -q https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install -y powershell
```

**Windows:**
```powershell
winget install Microsoft.PowerShell
```

### Stap 2: Posh-SSH Module Installeren

```powershell
Install-Module -Name Posh-SSH -Scope CurrentUser -Force
```

**Verificatie:**
```powershell
Get-Module -ListAvailable Posh-SSH
```

### Stap 3: NetDeploy Downloaden

**Via Git:**
```bash
git clone https://github.com/nilskele/NetDeploy.git
cd NetDeploy
```

**Of download als ZIP:**
Download van GitHub en pak uit naar een lokale map.

### Stap 4: Module Importeren

```powershell
# Navigeer naar de NetDeploy directory
cd /pad/naar/NetDeploy

# Importeer de module
Import-Module ./NetDeploy.psd1 -Force

# Controleer beschikbare commando's
Get-Command -Module NetDeploy
```

**Verwachte output:**
```
Invoke-DeviceDeployment
Invoke-AllDeviceDeployment
Load-Devices
Start-NetDeployUI
```

### Stap 5: Verificatie

Test of de module correct werkt:
```powershell
# Test met dry-run
$devices = Load-Devices -Path "./configs/devices/devices.json"
Invoke-DeviceDeployment -Device $devices[0] -DryRun
```

---

## Configuratie

### Device Configuratie

Devices worden geconfigureerd in `configs/devices/devices.json`:

```json
[
  {
    "Hostname": "R1",
    "DeviceType": "Router",
    "ManagementIP": "192.168.122.254",
    "SSHPort": 22,
    "Credentials": {
      "Username": "admin",
      "Password": "cisco"
    },
    "Interfaces": [
      {
        "Name": "GigabitEthernet0/0",
        "Description": "LAN_Internet",
        "IP": "192.168.122.254",
        "Mask": "255.255.255.0",
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
            "Network": "10.0.12.0",
            "Mask": "255.255.255.252",
            "Area": 0
          }
        ]
      }
    },
    "Services": {
      "AAA": {
        "Enabled": true,
        "Users": [
          { "Username": "admin", "Privilege": 15, "Password": "cisco" }
        ]
      }
    }
  }
]
```

### Configuratie Opties per Device Type

**Router Features:**
- Interfaces (IP, subnet mask, description)
- OSPF (process ID, router ID, networks, areas)
- Static routes
- NAT/PAT
- DHCP pools
- DNS configuration
- AAA local users

**Switch Features:**
- VLANs
- Trunk/access ports
- SVIs (Switch Virtual Interfaces)
- EtherChannel

Zie `examples/` directory voor volledige voorbeelden.

---

## Gebruik

### Methode 1: Interactive TUI

```powershell
Import-Module ./NetDeploy.psd1
Start-NetDeployUI
```

**TUI Features:**
- Device selectie
- Deploy modus (sequential/parallel)
- Real-time feedback
- Backup viewer

### Methode 2: Command-Line

```powershell
# Devices laden
$devices = Load-Devices -Path "./configs/devices/devices.json"

# Enkel device
Invoke-DeviceDeployment -Device $devices[0]

# Meerdere devices
Invoke-AllDeviceDeployment -Devices $devices -Parallel

# Dry-run (test mode)
Invoke-DeviceDeployment -Device $devices[0] -DryRun
```

---

## Technische Structuur

### Project Overzicht - Waar Vind Ik Wat?

**Voor de leerkracht:** Hier is een complete gids van de projectstructuur zodat je weet waar alles te vinden is.

```
NetDeploy/                              # Root directory
│
├── NetDeploy.psd1                   # Module manifest (metadata, versie, geëxporteerde functies)
├── NetDeploy.psm1                   # Module loader (laadt automatisch alle Public/Private functies)
├── README.md                        # Deze documentatie
├── LICENSE                          # MIT licentie
│
├── Public/                          # - PUBLIEKE API (4 functies geëxporteerd)
│   ├── Invoke-DeviceDeployment.ps1         # Deploy naar 1 device
│   ├── Invoke-AllDeviceDeployment.ps1      # Deploy naar meerdere devices (sequential/parallel)
│   ├── Load-Devices.ps1                    # Laad devices vanuit JSON
│   └── Start-NetDeployUI.ps1               # Start de interactieve TUI
│
├── Private/                         # - INTERNE FUNCTIES (niet geëxporteerd)
│   ├── Utils.ps1                           # Logging, validatie, helpers (13 functies)
│   │                                       #   → Write-Log, New-LogJob, Convert-MaskToWildcard, etc.
│   ├── DeviceLoader.ps1                    # JSON/PSD1 parsing (5 functies)
│   │                                       #   → Load-AllDevicesFromJson, Merge-ConfigWithSchema
│   ├── deviceValidator.ps1                 # Schema validatie (5 functies)
│   │                                       #   → Validate-Router, Validate-Switch, Validate-Device
│   ├── CommandBuilder.ps1                  # Cisco IOS command generation (7 functies)
│   │                                       #   → Build-RouterCommands, Build-SwitchCommands
│   └── SSHDeploy.ps1                       # SSH operaties (8 functies)
│                                           #   → Connect-SSH, Backup-DeviceConfig, Deploy-Device
│                                           #   → Native SSH fallback functies voor legacy devices
│
├── tui/                             # - TEXT USER INTERFACE (TUI)
│   ├── DeploymentUI.ps1                    # Main TUI logic en workflow
│   ├── Menu.ps1                            # Menu rendering en backup viewer
│   └── DeviceSelector.ps1                  # Device selectie logic
│
├── configs/                         # - CONFIGURATIE BESTANDEN
│   ├── devices/
│   │   └── devices.json                    # - HOOFDBESTAND: Alle devices configuratie (JSON)
│   └── base-configs/                       # Manual backup configs (voor disaster recovery)
│       ├── R1-base.txt
│       ├── R2-base.txt
│       └── S1-base-config.txt
│
├── examples/                        # - VOORBEELD CONFIGURATIES (voor referentie)
│   ├── router-example.psd1                 # Volledig voorbeeld: Router met OSPF, NAT, DHCP
│   ├── switch-example.psd1                 # Volledig voorbeeld: Switch met VLANs, trunking
│   └── host-example.psd1                   # Volledig voorbeeld: Linux host configuratie
│
├── logs/                            # - RUNTIME LOGS (automatisch aangemaakt)
│   ├── NetDeploy-YYYYMMDD.log             # Dagelijkse algemene log
│   ├── execution.log                       # Legacy execution log
│   ├── jobs/                               # Per-deployment logs met timestamp
│   │   └── <RunName>-<timestamp>.log
│   └── backups/                            # - DEVICE BACKUPS (automatisch bij deployment)
│       └── <hostname>-<timestamp>.cfg      # Bijv: R1-20260101-143022.cfg
│
└── docs/                            # - EXTRA DOCUMENTATIE
    └── PROJECT_REVIEW.md                   # Gedetailleerde code review en verbeteringen

├── Tests/                           # - UNIT TESTS (Pester 5)
│   ├── Run-Tests.ps1                       # Test runner script
│   ├── CommandBuilder.Tests.ps1            # 17 tests: wildcard/CIDR, router commands
│   ├── DeviceLoader.Tests.ps1              # 18 tests: JSON parsing, device loading
│   └── Validator.Tests.ps1                 # 29 tests: IP validatie, device validatie
```


### Hoe Bestanden Samen Werken

**Deployment Flow:**
```
1. Gebruiker roept aan:
   Invoke-DeviceDeployment -Device $device

2. NetDeploy.psm1:
   → Laadt automatisch alle Public/ en Private/ functies

3. Public/Invoke-DeviceDeployment.ps1:
   → Valideert device (Private/deviceValidator.ps1)
   → Bouwt commando's (Private/CommandBuilder.ps1)
   → Maakt backup (Private/SSHDeploy.ps1 → Backup-DeviceConfig)
   → Deployt config (Private/SSHDeploy.ps1 → Deploy-Device)
   → Logt alles (Private/Utils.ps1 → Write-Log)

4. Output:
   → Console feedback
   → Logs in logs/NetDeploy-YYYYMMDD.log
   → Backup in logs/backups/hostname-timestamp.cfg
```

**TUI Flow:**
```
1. Gebruiker roept aan:
   Start-NetDeployUI

2. Public/Start-NetDeployUI.ps1:
   → Laadt tui/*.ps1 scripts
   → Start tui/DeploymentUI.ps1

3. TUI toont menu:
   → Device selectie (tui/DeviceSelector.ps1)
   → Deploy opties (sequential/parallel)
   → Real-time feedback via tui/Menu.ps1

4. Bij deployment:
   → Roept Invoke-DeviceDeployment aan (zie flow hierboven)
```


---

## Testing Instructies

### Module Importeren en Verificatie

```powershell
# Navigeer naar NetDeploy directory
cd /pad/naar/NetDeploy

# Importeer module
Import-Module ./NetDeploy.psd1 -Force

# Controleer geëxporteerde functies (moet exact 4 functies tonen)
Get-Command -Module NetDeploy
```

**Verwachte output:**
```
Invoke-AllDeviceDeployment    Function
Invoke-DeviceDeployment       Function
Load-Devices                  Function
Start-NetDeployUI             Function
```

### Devices Laden

```powershell
# Laad devices vanuit de meegeleverde JSON configuratie
$devices = Load-Devices -Path "./configs/devices/devices.json"

# Bekijk geladen devices
$devices | Select-Object Hostname, DeviceType, ManagementIP
```

### Command-Line Usage (zonder TUI)

**1. Dry-Run (test mode - genereert commando's zonder deployment):**
```powershell
# Test met 1 device - toont gegenereerde Cisco IOS commando's
Invoke-DeviceDeployment -Device $devices[0] -DryRun

# Dry-run voor alle devices
Invoke-AllDeviceDeployment -Devices $devices -DryRun
```

**2. Commando's Opslaan:**
```powershell
# Save gegenereerde commando's naar bestand voor review
$result = Invoke-DeviceDeployment -Device $devices[0] -DryRun
$result.Commands | Out-File "./generated-commands.txt"
```

**3. Parallel vs Sequential (dry-run):**
```powershell
# Sequential (één voor één)
Invoke-AllDeviceDeployment -Devices $devices -DryRun

# Parallel (tegelijkertijd - sneller)
Invoke-AllDeviceDeployment -Devices $devices -Parallel -DryRun
```

**4. Specifieke Devices Filteren:**
```powershell
# Alleen routers
$routers = $devices | Where-Object { $_.DeviceType -eq "Router" }
Invoke-AllDeviceDeployment -Devices $routers -DryRun

# Specifiek device op hostname
$r1 = $devices | Where-Object { $_.Hostname -eq "R1" }
Invoke-DeviceDeployment -Device $r1 -DryRun
```

### TUI Usage (met interactieve interface)

```powershell
# Start de Text User Interface
Start-NetDeployUI
```

**TUI Navigatie:**
1. Kies "Deploy devices" (optie 1)
2. Selecteer dry-run mode (Y/N)
3. Selecteer devices:
   - Nummer invoeren (bijv. `1` voor eerste device)
   - Range (bijv. `1-3`)
   - `all` voor alle devices
4. Kies deployment mode:
   - Sequential (1) - één voor één
   - Parallel (2) - tegelijkertijd
5. Bevestig en bekijk output

**Andere TUI opties:**
- "Show loaded devices" (optie 2) - Toon device lijst
- "List recent backups" (optie 3) - Backup overzicht
- "View a backup" (optie 4) - Backup inhoud bekijken

### Logging Verificatie

```powershell
# Dagelijkse logs
Get-ChildItem ./logs/NetDeploy-*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1

# Bekijk laatste log entries
Get-Content ./logs/NetDeploy-*.log -Tail 20

# Job-specific logs (per deployment run)
Get-ChildItem ./logs/jobs/ | Sort-Object LastWriteTime -Descending | Select-Object -First 5

# Backups (indien deployment naar echt device uitgevoerd)
Get-ChildItem ./logs/backups/
```

### Voorbeelden Testen

```powershell
# Laad voorbeeld configuratie (PSD1 format)
$exampleRouter = Import-PowerShellDataFile "./examples/router-example.psd1"

# Genereer commando's vanuit example
Invoke-DeviceDeployment -Device $exampleRouter -DryRun

# Save naar bestand
$result = Invoke-DeviceDeployment -Device $exampleRouter -DryRun
$result.Commands | Out-File "./example-commands.txt"
```

### Deployment naar Echt Device (optioneel)

**Let op:** Vereist toegang tot Cisco device via SSH.

```powershell
# Zorg dat device bereikbaar is
Test-Connection -ComputerName 192.168.122.254 -Count 2

# Deploy (maakt automatisch backup)
Invoke-DeviceDeployment -Device $devices[0] -CommandDelay 1

# Check backup
Get-ChildItem ./logs/backups/ | Sort-Object LastWriteTime -Descending | Select-Object -First 1
```

---

## Unit Tests (Pester)

Dit project bevat **64 unit tests** geschreven met [Pester 5](https://pester.dev/) voor de belangrijkste functies.

### Vereisten

```powershell
# Installeer Pester (indien nog niet geïnstalleerd)
Install-Module -Name Pester -MinimumVersion 5.0 -Force -Scope CurrentUser
```

### Tests Uitvoeren

```powershell
# Navigeer naar Tests folder
cd Tests

# Run alle tests
./Run-Tests.ps1

# Gedetailleerde output (toont alle individuele tests)
./Run-Tests.ps1 -Detailed
```

### Test Coverage

| Test File | Tests | Wat wordt getest |
|-----------|-------|------------------|
| `CommandBuilder.Tests.ps1` | 17 | Wildcard/CIDR conversie, Router commands, OSPF, AAA |
| `DeviceLoader.Tests.ps1` | 18 | JSON laden, device parsing, error handling |
| `Validator.Tests.ps1` | 29 | IP validatie, Router/Switch/Host validatie |
| **Totaal** | **64** | |

### Voorbeeld Output

```
Running discovery in 3 files.
Discovery found 64 tests in 1.23s.
Running tests.
Tests completed in 2.45s
Tests Passed: 64, Failed: 0, Skipped: 0
```

---

## Design Patterns

1. **Module Pattern** - Public/Private scheiding
2. **Template Method** - Device-specific builders
3. **Strategy Pattern** - SSH met Posh-SSH of Native fallback
4. **Observer Pattern** - Logging met verschillende levels

---

## Gebruikte Bronnen

### Officiële Documentatie

- **PowerShell:** https://docs.microsoft.com/powershell
- **Posh-SSH:** https://github.com/darkoperator/Posh-SSH
- **Cisco IOS:** https://www.cisco.com/c/en/us/support/ios-nx-os-software

### Tutorials & Blogs

- Adam the Automator: https://adamtheautomator.com
- Jeff Hicks: https://jdhitsolutions.com
- PowerShell.org: https://powershell.org
- Network to Code: https://networktocode.com
- https://app.pluralsight.com/paths/skill/windows-powershell-essentials
- https://app.pluralsight.com/library/courses/automation-powershell-scripts
- https://app.pluralsight.com/library/courses/windows-powershell-extending/table-of-contents
- https://app.pluralsight.com/paths/skill/powershell-hands-on-practice-and-use-cases

### Video Resources

- David Bombal: https://www.youtube.com/c/DavidBombal
- NetworkChuck: https://www.youtube.com/c/NetworkChuck
- PowerShell.org Channel: https://www.youtube.com/PowerShellOrg

### Community

- r/PowerShell: https://www.reddit.com/r/PowerShell/
- r/networking: https://www.reddit.com/r/networking/
- r/Cisco: https://www.reddit.com/r/Cisco/
- Stack Overflow: PowerShell & SSH tags

### AI Assistentie

**AI Chat Logs:**
- https://chatgpt.com/share/69529a83-f8b8-800a-ab6e-6d1378294100
- https://chatgpt.com/share/69529ba8-843c-800a-9f34-44294c856d52
- https://chatgpt.com/share/6952a365-9878-800a-86b7-5680f996de62
- https://chatgpt.com/share/6952a39e-ea04-800a-98d6-3e81ca7a8f26
- https://chatgpt.com/share/6952a816-5128-800a-880f-27c8f5fc70f9
- https://chatgpt.com/share/6952e3bc-3e44-800a-8a40-d8963f86d7dc
#### copilot is gebruikt geweest voor het debugging en verfijnen van sommige functionaliteiten, onder andere voor de SHH fallback op KEX, de parallel deployment met throttle, en bij het vertalen van plain text naar cisco commandos in de commandbuilder.
- Copilot Used: GPT-4.1, Claude Opus 4.5, Claud Sonnet 4.5, GPT-5, GPT-4


## Auteur

**Nils Kelecom**  
Student Toegepaste Informatica - Erasmushogeschool Brussel  
Academiejaar 2025-2026

**Versie:** 1.0.0  
**Laatste Update:** 1 januari 2026  
**Status:** MVP Compleet



