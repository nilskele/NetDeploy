# NetDeploy

NetDeploy is a small PowerShell-based network automation project designed to load device configuration data (PSD1), validate it against simple schemas, build CLI commands for Cisco IOS devices, and deploy them over SSH. The repository is intended as a lab/demo tool for learning automation patterns and for controlled deployment to lab devices.

This README includes a research-backed References section that links to documentation and resources used while building this project — useful if you need to demonstrate the research behind the implementation.

## How it works (high level)
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
This section explains how to run and test the project safely (DryRun) and how to use the interactive TUI to perform live deployments.

Prerequisites
- PowerShell 7.x (or Windows PowerShell where appropriate).
- `Posh-SSH` for live SSH operations: `Install-Module -Name Posh-SSH -Scope CurrentUser`.

A. Testing safely with DryRun (recommended for grading)

1) Import the module and confirm exported functions
```powershell
Import-Module -Force ./NetDeploy.psd1 -Verbose
Get-Command -Module NetDeploy | Where-Object CommandType -eq 'Function'
```

2) Load device configurations and pick a device
```powershell
$devices = Load-Devices -Path ./configs/devices
$devices | Select-Object Hostname, ManagementIP, @{Name='HasCreds';Expression={$_.Credentials -ne $null}}
$d = $devices | Where-Object Hostname -eq 'R1'   # or pick another hostname
```

3) Run a DryRun (NO SSH, safe)
```powershell
Invoke-DeviceDeployment -Device $d -DryRun -Verbose
```

What DryRun does and expected output
- DryRun will simulate the workflow and print what would happen without opening SSH connections or writing backup files.
- Example DryRun output (approximate):

```
VERBOSE: Loading module from path '/full/path/NetDeploy.psd1'.
[INFO] Loading device configuration: ./configs/devices/R1.psd1
Running DRY-RUN for device: R1 (192.0.2.1)
[INFO] Backing up running-config for R1
DRY-RUN: would save backup to /full/path/logs/backups/R1-20251214-123456.cfg
DRY-RUN: Commands for R1:
configure terminal
interface GigabitEthernet0/1
 ip address 10.0.0.1 255.255.255.0
 no shutdown
exit
write memory
```

- The function will also return the command list as the function result. Use DryRun to capture and inspect commands before running them live.

Quick reproducible example (one-liner script)
- I added `examples/quickDryRun.ps1` to automate the above steps. Run it from the repository root:
```powershell
pwsh ./examples/quickDryRun.ps1
```

B. Using the TUI for live workflows (interactive)

Start the TUI (one command)
```powershell
pwsh ./tui/DeploymentUI.ps1
```

What the TUI does (interactive flow)
- Loads device PSD1 files from `./configs/devices` and displays them in a menu.
- You can select one or more devices and choose to Deploy.
- On Deploy the UI will:
  1. Attempt to backup the device's current running-config (saved to `logs/backups/`).
  2. If backup succeeds, establish an SSH session and send the generated CLI commands to the device (Posh-SSH).

Example TUI interaction (what you will see)
- Menu of devices with Hostname and IP.
- Prompt: `Select device(s)` → choose R1.
- Prompt: `Confirm deploy? (Y/N)` → choose Y to proceed.
- Logs will stream: backup step, SSH connect, commands sent, completion message.

Safety notes for TUI and live runs
- The TUI performs live deployments by default when you confirm a deploy. Use only lab/test devices and non-production credentials.
- The UI attempts a backup first; if the backup fails the deployment for that device is aborted.
- If you want to keep functions loaded into your current session, dot-source the UI:
```powershell
. ./tui/DeploymentUI.ps1
```

Important cautions
- Always run DryRun first to inspect backup paths and commands.
- `Invoke-AllDeviceDeployment -Parallel` spawns background jobs; the current implementation may not pass `-DryRun` into those jobs — avoid `-Parallel` for dry-run testing.
- Device PSD1 files in this repo may contain plaintext credentials (lab mode). For production use SecretManagement (see References).
- Running import/load/invoke in a single `pwsh -Command` string can hit PSD1 parsing issues if PSD1s contain unquoted timestamp tokens — run interactively or quote values.

## Research & References
Below are curated links to documentation and resources relevant to the code in this repository. Each link includes a short note describing why it's relevant.

### PowerShell module & script module basics
- How to write a module manifest (.psd1)
	https://learn.microsoft.com/powershell/scripting/developer/module/how-to-write-a-module-manifest?view=powershell-7.3
	(Explains `FunctionsToExport`, `FileList`, `RootModule` and other manifest fields used by `NetDeploy.psd1`.)
- Writing a PowerShell script module (.psm1) and dot-sourcing internals
	https://learn.microsoft.com/powershell/scripting/developer/module/writing-a-windows-powershell-script-module?view=powershell-7.3
	(Guidance on organizing code into a `.psm1` and dot-sourcing helper scripts in `core/`.)
- Export-ModuleMember
	https://learn.microsoft.com/powershell/module/microsoft.powershell.core/export-modulemember?view=powershell-7.3
	(Used to expose public functions such as `Invoke-DeviceDeployment` and `Backup-DeviceConfig`.)

### PowerShell data files (PSD1) and configuration patterns
- PSD1 data file format and usage
	https://learn.microsoft.com/powershell/scripting/dev-cross-plat/about/about_data_files?view=powershell-7.3
	(Reference for the PSD1 format used for device config files in `configs/devices/`.)
- Parsing PSD1 configuration examples
	https://learn.microsoft.com/powershell/scripting/samples/parsing-powershell-data-files?view=powershell-7.3
	(Examples for safely loading and inspecting PSD1 files.)

### SSH / Posh-SSH and remote command execution
- Posh-SSH (GitHub)
	https://github.com/darkoperator/Posh-SSH
	(The repo for the Posh-SSH module; functions used include `New-SSHSession`, `Invoke-SSHCommand`, `Remove-SSHSession`.)
- Posh-SSH (PowerShell Gallery)
	https://www.powershellgallery.com/packages/Posh-SSH
	(Package install instructions and version info.)

### Credential management & secure strings
- Everything about credentials (PSCredential / SecureString)
	https://learn.microsoft.com/powershell/scripting/learn/deep-dives/everything-about-credentials?view=powershell-7.3
	(Guidance on `PSCredential` objects and why storing plaintext in PSD1 is discouraged.)
- ConvertTo-SecureString / PSCredential
	https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/convertto-securestring?view=powershell-7.3
	(API docs used when creating credentials for SSH connections.)

### SecretManagement (recommended for production)
- SecretManagement overview
	https://learn.microsoft.com/powershell/scripting/learn/deep-dives/secret-management?view=powershell-7.3
	(Recommended approach to store credentials/keys securely instead of plaintext PSD1.)
- SecretManagement (PowerShell Gallery)
	https://www.powershellgallery.com/packages/Microsoft.PowerShell.SecretManagement

### Testing, CI, and module quality
- Pester — PowerShell testing framework
	https://pester.dev/
	(Use to add unit/integration tests for loader, validator, and DryRun behavior.)
- CI for PowerShell modules (GitHub Actions guidance)
	https://learn.microsoft.com/powershell/scripting/dev-cross-platform/ci-cd/github?view=powershell-7.3
	(How to run Pester tests and linting in CI.)
- PlatyPS — generate markdown help from comment-based help
	https://github.com/platyPS/PlatyPS
	(Useful for generating module documentation from in-code comment help.)

### Concurrency and background jobs
- Start-Job / passing args into ScriptBlock
	https://learn.microsoft.com/powershell/module/microsoft.powershell.core/start-job?view=powershell-7.3
	(Guidance relevant to the `-Parallel` branch in `Deploy-AllDevices`.)

### I/O, path handling, logging
- Join-Path / Resolve-Path (path handling)
	https://learn.microsoft.com/powershell/module/microsoft.powershell.management/join-path?view=powershell-7.3
- Out-File (writing backups)
	https://learn.microsoft.com/powershell/module/microsoft.powershell.core/out-file?view=powershell-7.3
- Logging guidance
	https://learn.microsoft.com/powershell/scripting/learn/deep-dives/advanced-logging?view=powershell-7.3

### PowerShell best practices & security
- PowerShell security best-practices
	https://learn.microsoft.com/powershell/scripting/learn/ps101/04-powershell-security?view=powershell-7.3
- Effective PowerShell patterns
	https://learn.microsoft.com/powershell/scripting/learn/deep-dives/effective-powershell?view=powershell-7.3

### Cisco / network automation references
- Cisco DevNet (automation & APIs)
	https://developer.cisco.com/
	(Vendor resources for network automation, sample code, and APIs.)
- Cisco product & IOS documentation
	https://www.cisco.com/c/en/us/support/index.html
	(Authoritative product documentation for IOS commands such as `show running-config`.)

## Notes 
- This project was built as a learning/lab tool. Key research sources are linked above and were used to inform module structure, PSD1 usage, SSH/Posh-SSH usage, and recommendations to use SecretManagement for credentials.
- For safety, the module includes a `-DryRun` option that previews backup paths and command lists without opening SSH connections.

