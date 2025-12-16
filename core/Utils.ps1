<#
.SYNOPSIS
    Utility functions used across the NetDeploy project.

.DESCRIPTION
    Provides common shared functions such as logging, safe error throwing,
    user confirmation prompts, validation helpers, IP/mask converters,
    secure credential builders, and file handling utilities.
#>

# -------------------------------------
#  GLOBALS: Logging Folder + Log File
# -------------------------------------

# Compute default script dir and default logs folder only if not already set by caller
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not (Get-Variable -Name NetDeployLogDir -Scope Global -ErrorAction SilentlyContinue)) {
    $Global:NetDeployLogDir = Join-Path $ScriptDir "..\logs"
}

if (-not (Test-Path $Global:NetDeployLogDir)) {
    New-Item -ItemType Directory -Path $Global:NetDeployLogDir | Out-Null
}

# Main log file (default) — allow override by setting $Global:NetDeployLogFile before loading
if (-not (Get-Variable -Name NetDeployLogFile -Scope Global -ErrorAction SilentlyContinue)) {
    $Global:NetDeployLogFile = Join-Path $Global:NetDeployLogDir "NetDeploy-$(Get-Date -Format yyyyMMdd).log"
}

# Directory for per-run/job logs
if (-not (Get-Variable -Name NetDeployJobsDir -Scope Global -ErrorAction SilentlyContinue)) {
    $Global:NetDeployJobsDir = Join-Path $Global:NetDeployLogDir 'jobs'
}
if (-not (Test-Path $Global:NetDeployJobsDir)) {
    New-Item -ItemType Directory -Path $Global:NetDeployJobsDir | Out-Null
}

# Global variable to hold current job id and its log file when a run is active
if (-not (Get-Variable -Name NetDeployJobId -Scope Global -ErrorAction SilentlyContinue)) {
    $Global:NetDeployJobId = $null
}
if (-not (Get-Variable -Name NetDeployJobLogFile -Scope Global -ErrorAction SilentlyContinue)) {
    $Global:NetDeployJobLogFile = $null
}

# -------------------------------------
# Logging Function (Console + File)
# -------------------------------------
function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("INFO","WARN","ERROR","DEBUG")]
        [string]$Level = "INFO",

        [switch]$NoColor
    )

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    # If there's an active job id, include it in the message and prepare job log file
    if ($Global:NetDeployJobId) {
        $jobPrefix = "[Job:$Global:NetDeployJobId]"
    } else {
        $jobPrefix = ""
    }

    $formatted = "[$timestamp][$Level] $jobPrefix $Message"

    # Always write to the main log file
    try {
        $formatted | Out-File -Append -FilePath $Global:NetDeployLogFile -Encoding UTF8
    } catch {}

    # If a job log file is configured, write there as well
    if ($Global:NetDeployJobLogFile) {
        try { $formatted | Out-File -Append -FilePath $Global:NetDeployJobLogFile -Encoding UTF8 } catch {}
    }

    # Console output
    if ($NoColor) {
        Write-Host $formatted
        return
    }

    switch ($Level) {
        "INFO"  { Write-Host $formatted -ForegroundColor Cyan }
        "WARN"  { Write-Host $formatted -ForegroundColor Yellow }
        "ERROR" { Write-Host $formatted -ForegroundColor Red }
        "DEBUG" { Write-Host $formatted -ForegroundColor DarkGray }
    }
}


# -------------------------------------
# Job-scoped logging helpers
# -------------------------------------
function New-LogJob {
    param(
        [string]$Name = $null
    )

    $id = (Get-Date).ToString('yyyyMMdd-HHmmss') + '-' + (New-RandomID -Digits 4)
    if ($Name) { $safeName = ($Name -replace '[^a-zA-Z0-9_-]', '_') } else { $safeName = 'run' }

    $Global:NetDeployJobId = $id
    $Global:NetDeployJobLogFile = Join-Path $Global:NetDeployJobsDir ("{0}-{1}.log" -f $safeName, $id)

    # Add header to main log and job log
    $hdr = ("[{0}][INFO] [Job:{1}] START {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Global:NetDeployJobId, ($Name -or 'run'))
    try { $hdr | Out-File -Append -FilePath $Global:NetDeployLogFile -Encoding UTF8 } catch {}
    try { $hdr | Out-File -Append -FilePath $Global:NetDeployJobLogFile -Encoding UTF8 } catch {}

    return $Global:NetDeployJobId
}

function Close-LogJob {
    param(
        [string]$Reason = $null
    )

    if (-not $Global:NetDeployJobId) { return }

    $msg = ("[{0}][INFO] [Job:{1}] END {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Global:NetDeployJobId, ($Reason -or 'complete'))
    try { $msg | Out-File -Append -FilePath $Global:NetDeployLogFile -Encoding UTF8 } catch {}
    try { $msg | Out-File -Append -FilePath $Global:NetDeployJobLogFile -Encoding UTF8 } catch {}

    # Clear globals
    $Global:NetDeployJobId = $null
    $Global:NetDeployJobLogFile = $null
}


# -------------------------------------
# Null Check Exception Helper
# -------------------------------------
function Throw-IfNull {
    param(
        [Parameter(Mandatory)]
        $Value,

        [Parameter(Mandatory)]
        [string]$Message
    )

    if (-not $Value) {
        Write-Log -Message $Message -Level ERROR
        throw $Message
    }
}


# -------------------------------------
# Yes/No Confirmation Helper
# -------------------------------------
function Confirm-YesNo {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    do {
        $input = Read-Host "$Message (y/n)"
    } while ($input -notin @("y","n","Y","N"))

    return $input.ToLower() -eq "y"
}


# -------------------------------------
# Action Timing Helper
# -------------------------------------
function Measure-Action {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Action,

        [string]$Name = "Action"
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $result = & $Action
    $sw.Stop()

    Write-Log "$Name completed in $([math]::Round($sw.Elapsed.TotalSeconds,2)) seconds" -Level DEBUG
    return $result
}


# -------------------------------------
# Absolute Path Resolver
# -------------------------------------
function Resolve-AbsolutePath {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    try {
        return (Resolve-Path -Path $Path -ErrorAction Stop).Path
    } catch {
        return (Join-Path -Path (Get-Location) -ChildPath $Path)
    }
}


# -------------------------------------
# Safe File Import Wrapper
# -------------------------------------
function Import-SafePSData {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    try {
        return Import-PowerShellDataFile -Path $Path -ErrorAction Stop
    } catch {
        Write-Log "Failed to import file '$Path': $_" -Level ERROR
        return $null
    }
}


# -------------------------------------
# Secure Credential Builder
# -------------------------------------
function New-SecureCredential {
    param(
        [Parameter(Mandatory)]
        [string]$Username,

        [Parameter(Mandatory)]
        [string]$Password
    )

    $sec = ConvertTo-SecureString $Password -AsPlainText -Force
    return New-Object System.Management.Automation.PSCredential($Username, $sec)
}


# -------------------------------------
# IP Validation Helper
# -------------------------------------
function Test-ValidIP {
    param([Parameter(Mandatory)][string]$IP)
    return [System.Net.IPAddress]::TryParse($IP, [ref]0)
}


# -------------------------------------
# Mask → Wildcard Converter (pure IOS)
# -------------------------------------
function Convert-MaskToWildcard {
    param([Parameter(Mandatory)][string]$Mask)

    $octets = $Mask.Split(".") | ForEach-Object { 255 - [int]$_ }
    return ($octets -join ".")
}


# -------------------------------------
# Simple Random ID Generator (ACL, Pools)
# -------------------------------------
function New-RandomID {
    param([int]$Digits = 4)
    return -join ((0..9) | Get-Random -Count $Digits)
}


# -------------------------------------
# Device Sorter (Routers first → Switches → Hosts)
# -------------------------------------
function Sort-DevicesForDeployment {
    param(
        [Parameter(Mandatory)]
        [array]$Devices
    )

    return $Devices | Sort-Object -Property @{
        Expression = {
            switch ($_.DeviceType) {
                "Router" { 1 }
                "Switch" { 2 }
                "Host"   { 3 }
                default  { 9 }
            }
        }
    }
}
