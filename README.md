# NetDeploy

NetDeploy is a small PowerShell-based network automation project designed to load device configuration data (PSD1), validate it against simple schemas, build CLI commands for Cisco IOS devices, and deploy them over SSH. The repository is intended as a lab/demo tool for learning automation patterns and for controlled deployment to lab devices.

This README includes a research-backed References section that links to documentation and resources used while building this project — useful if you need to demonstrate the research behind the implementation.

## How it works 
- Device configs are stored as PSD1 files under `configs/devices/`.
- `core/DeviceLoader.ps1` loads and normalizes PSD1 content into PowerShell objects.
- `core/deviceValidator.ps1` validates device objects before deployment.
- `core/CommandBuilder.ps1` generates Cisco IOS command lists for each device type.
- `core/SSHDeploy.ps1` uses Posh-SSH to connect, backup running-config, and apply commands.
- A small TUI in `tui/` exposes an interactive menu to pick devices and run deployments.

## Key files
- `NetDeploy.psm1` / `NetDeploy.psd1` — module bootstrap and exports.
- `core/DeviceLoader.ps1` — loads PSD1 configs and merges defaults.
- `core/deviceValidator.ps1` — validation rules per device type.
- `core/CommandBuilder.ps1` — builds CLI command sequences.
- `core/SSHDeploy.ps1` — backup and deployment over SSH (Posh-SSH).
- `tui/` — simple console UI to select and deploy devices.

## Usage
This section gives two step-by-step workflows: a safe non-interactive DryRun flow (recommended for testing/grading) and the interactive TUI flow for live deployments.

Prerequisites
- PowerShell 7.x (cross-platform `pwsh`) or Windows PowerShell where appropriate.
- `Posh-SSH` for live SSH operations (only required for actual deployments):
	```powershell
	Install-Module -Name Posh-SSH -Scope CurrentUser
	```

A. Non-interactive DryRun (safe and recommended)

This flow mirrors what the TUI does but runs step-by-step in your shell. DryRun will build the command list and show the intended backup path without opening SSH connections or writing files.

1) Import the module (from the repo root)
```powershell
# Option A: import the manifest (loads the module as-packaged)
Import-Module -Force ./NetDeploy.psd1 -Verbose

# Option B: import the module file directly while developing
# Import-Module -Force ./NetDeploy.psm1 -Verbose

# Verify exported functions (optional)
Get-Command -Module NetDeploy -CommandType Function
```

2) Load device configurations
```powershell
# Load all device PSD1 files (returns an array of PSCustomObject devices)
$devices = Load-Devices -Path ./configs/devices

# Quick summary view
$devices | Select-Object Hostname, DeviceType, ManagementIP, @{Name='HasCreds';Expression={$_.Credentials -ne $null}}

# Pick a device by hostname (or use index from the list)
$d = $devices | Where-Object Hostname -eq 'R1'
```

3) Run a DryRun for a single device
```powershell
# DryRun previews backup path and commands; it does NOT perform SSH or write backup files.
Invoke-DeviceDeployment -Device $d -DryRun -Verbose
```

4) DryRun all devices at once (non-interactive)
```powershell
$results = Deploy-AllDevices -Devices $devices -DryRun
# Inspect per-host previews (backup path + commands)
$results.GetEnumerator() | ForEach-Object {
	$host = $_.Key; $obj = $_.Value
	"=== $host ==="
	"Backup: $($obj.BackupPath)"
	($obj.Commands -join "`n")
}
```

Notes about DryRun
- DryRun returns intended backup paths (typically under `logs/backups/`) and the full command list, but it does not modify devices or write files.
- Use `ConvertTo-Json` if you want machine-readable output: `Invoke-DeviceDeployment -Device $d -DryRun | ConvertTo-Json -Depth 6`.

B. Interactive TUI (live deployments)

The TUI provides a simple console-driven flow to select devices and run deployments. The TUI calls the module's public APIs and will perform backups and SSH commands during deployments.

1) Start the TUI from the repository root
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File ./tui/DeploymentUI.ps1
```

2) What to expect in the TUI
- On start the TUI will load `.psd1` files from `./configs/devices`.
- The main menu shows two options: `Deploy devices` and `Exit`.
- Choose `Deploy devices` to open the device selector. The selector lists `ALL DEVICES` followed by each device (Hostname + DeviceType). Select a device or ALL to continue.

3) Deploy flow inside the TUI (live)
- After selecting devices the TUI calls `Invoke-AllDeviceDeployment -Devices <selection>`.
- For each selected device the live flow attempts to:
	1. Backup running-config to `logs/backups/<hostname>-<timestamp>.cfg` (if backup fails the device is skipped).
	2. Open an SSH session using `Posh-SSH` and send the generated CLI commands.

## Sources

- Posh-SSH (GitHub):
	https://github.com/darkoperator/Posh-SSH

- Adam the Automator — practical PowerShell tutorials and module authoring guides.:
	https://adamtheautomator.com

- Jeff Hicks — in-depth PowerShell articles and real-world examples:
	https://jdhitsolutions.com

- PowerShell.org - community articles, blog posts and long-form tutorials about advanced scripting and module design:
	https://powershell.org

- Network to Code — network automation patterns, examples, and tutorials:
	https://networktocode.com

- David Bombal (YouTube) hands-on network lab videos including Cisco IOS examples and automation demos:
	https://www.youtube.com/c/DavidBombal

- NetworkChuck (YouTube) network automation and lab tutorials that show building topologies and automating tasks:
	https://www.youtube.com/c/NetworkChuck

- Reddit communities:
	r/PowerShell: https://www.reddit.com/r/PowerShell/
	r/networking: https://www.reddit.com/r/networking/

- GitHub automation repos combining PowerShell with Posh-SSH:
	https://github.com/search?q=posh-ssh+network+automation

- Developer/blog:
	Dev.to (PowerShell tag): https://dev.to/t/powershell
	Medium (PowerShell topic): https://medium.com/tag/powershell



