
# NetDeploy

NetDeploy is a simple, friendly PowerShell module for automating network device configuration in labs and demos. It loads device data, builds the commands your devices need, and can safely show you what it will do (dry-run) or actually apply changes over SSH.

This README explains what NetDeploy can do, how to install and use it, and how to make it work on your computer (change paths). The writing is easy to follow — even a beginner or a 10-year-old can get started.

## What NetDeploy does (in plain words)
- Load device descriptions (IP addresses, usernames, interfaces, routing) from a single JSON file.
- Check that each device description looks right (validation).
- Create the list of commands needed to configure each device (the command builder).
- Back up each device's current running configuration before changing anything.
- Apply the commands over SSH (when you want to do the real thing).
- Support safe DryRun mode that only shows what would happen (no network activity).
- Run many device deployments in parallel, but grouped into named "runs" so logs are easy to find.

## Key features (quick list)
- Single-file device data (JSON) loader and validator.
- Build-only DryRun mode for safe previews.
- Backup-before-deploy behavior.
- Parallel deployments with throttling (limit concurrent jobs).
- Per-run job logs: every run gets a named log file in `logs/jobs/` so you can find everything about a run quickly.
- TUI (simple console UI) to select devices and start runs.
- Easy path configuration so you can put logs/devices anywhere on your computer.

## How to get it and use it (step-by-step, copy/paste)

1) Download the project

- Option A — clone with Git (recommended if you know Git):

```powershell
git clone https://github.com/nilskele/NetDeploy.git
cd NetDeploy
```

- Option B — download the ZIP from GitHub and unzip it somewhere you like.

2) Import the module into PowerShell

Open PowerShell (pwsh) and run:

```powershell
# From the repository root
Import-Module -Force ./NetDeploy.psd1 -Verbose
```

3) Try a safe DryRun (no devices changed)

```powershell
# Load devices (module uses the configured devices path or repo default)
$devices = Load-Devices

# See the first device and run a dry-run
$devices[0] | Select-Object Hostname, DeviceType, ManagementIP
Invoke-DeviceDeployment -Device $devices[0] -DryRun -RunName 'my-first-dryrun'
```

4) Try the interactive UI

```powershell
# Start the simple menu-driven UI
pwsh -NoProfile -File ./tui/DeploymentUI.ps1
```

The UI will ask which devices to deploy, whether to run in parallel, and an optional run name. If you pick DryRun the tool will only show what it would do.

## Logs and how runs are grouped

Every run (single-device or multi-device) gets a run name and a unique timestamp. NetDeploy writes:

- A main log: `logs/NetDeploy-YYYYMMDD.log` where general events and START/END markers are written.
- A per-run job log: `logs/jobs/<RunName>-<timestamp>-<rand>.log` that contains all messages for that run (very handy for instructors and debugging).

Example: if you run `Invoke-AllDeviceDeployment -RunName 'lab1'` you'll see a job log like `logs/jobs/lab1-20251216-171348-2318.log` that contains everything the run did.

You can inspect logs with simple commands:

```powershell
Get-ChildItem -Path ./logs/jobs -File | Sort-Object LastWriteTime -Descending
Get-Content -Path ./logs/jobs/<that-file>.log -Tail 200
```

## Make NetDeploy use folders on your own computer

You don't have to keep device files or logs inside the project. To tell NetDeploy where to look and where to write, use these helpers:

```powershell
# After importing the module
Set-NetDeployPaths -DevicesPath 'C:\my-labs\devices' -LogsPath 'C:\my-labs\logs' -JobsPath 'C:\my-labs\logs\jobs' -BackupsPath 'C:\my-labs\logs\backups'

# Check what is configured
Get-NetDeployPaths | Format-List
```

If you prefer, you can set the globals before importing the module so they are applied immediately:

```powershell
$Global:NetDeployDevicesPath = 'C:\my-labs\devices'
$Global:NetDeployLogDir = 'C:\my-labs\logs'
$Global:NetDeployJobsDir = 'C:\my-labs\logs\jobs'
Import-Module -Force ./NetDeploy.psd1
```

NetDeploy will create the folders if they don't exist.

## Parallel runs and throttling (keeping things safe)

NetDeploy can deploy to many devices at once. To avoid using too many resources, it runs devices in batches. You can control how many devices run at the same time with the `-Throttle` parameter (default 10).

Example: run up to 5 devices at once in a dry-run:

```powershell
$sel = $devices[0..9]
Invoke-AllDeviceDeployment -Devices $sel -Parallel -Throttle 5 -DryRun -RunName 'parallel-test'
```

Each batch will start jobs, wait for them to finish, and then continue with the next batch. All jobs in the same run write to the same per-run job log.

## Simple explanations (for beginners / kids)

- "Device file" = a small file that says what a router or switch has (IP, name, interfaces).
- "DryRun" = a preview button — shows what will happen but doesn't touch anything.
- "Run name" = a label you give a group of changes so you can find them later in the logs.
- "Throttle" = how many devices to work on at the same time (smaller numbers = safer for tiny computers).

## Commands you will use most often

- Load devices: `Load-Devices` (optionally `-Path` to a folder or single JSON file)
- Run single-device dry-run: `Invoke-DeviceDeployment -Device <obj> -DryRun -RunName 'name'`
- Run many devices (parallel): `Invoke-AllDeviceDeployment -Devices <array> -Parallel -Throttle 10 -RunName 'name'`
- Change paths: `Set-NetDeployPaths -DevicesPath <path> -LogsPath <path> -JobsPath <path> -BackupsPath <path>`
- Show paths: `Get-NetDeployPaths`

## Next steps and extras you might like

- Add a tiny config file so `Set-NetDeployPaths` is remembered between sessions (I can add this).
- Add a small TUI menu to list recent job logs and open one (I can add this too).
- Switch from Start-Job to a runspace pool if you need extreme performance for hundreds of devices.

---

## Sources



Prerequisites
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

### Custom paths

You can override the default log, job, backup and device folder locations at runtime using the exported helpers:

```powershell
# Set custom directories (relative or absolute)
Set-NetDeployPaths -LogsPath './my-logs' -JobsPath './my-logs/jobs' -BackupsPath './my-logs/backups' -DevicesPath './configs/devices'

# Verify
Get-NetDeployPaths | Format-List
```

After calling `Set-NetDeployPaths` future runs (including background jobs) will write logs into your configured directories.

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



