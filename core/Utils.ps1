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
    <#
    .SYNOPSIS
        Writes log messages to console and log files.
    
    .DESCRIPTION
        Centralized logging function that writes timestamped messages to both console and log files.
        Supports different log levels (INFO, WARN, ERROR, DEBUG) with color coding.
        Automatically includes job context when a job is active.
    
    .PARAMETER Message
        The message to log.
    
    .PARAMETER Level
        The log level. Valid values: INFO, WARN, ERROR, DEBUG. Default is INFO.
    
    .PARAMETER NoColor
        If specified, console output will not be color-coded.
    
    .EXAMPLE
        Write-Log "Starting deployment" -Level INFO
        
        Logs an informational message.
    
    .EXAMPLE
        Write-Log "Configuration error detected" -Level ERROR
        
        Logs an error message in red.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
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
    <#
    .SYNOPSIS
        Creates a new job-scoped logging session.
    
    .DESCRIPTION
        Initializes a new logging job with a unique ID and dedicated log file.
        All subsequent Write-Log calls will include the job ID and write to both
        the main log and the job-specific log file.
    
    .PARAMETER Name
        Optional name for the job. Used in the log file name. Defaults to 'run'.
    
    .EXAMPLE
        $jobId = New-LogJob -Name "deployment"
        
        Creates a new job log session named "deployment".
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
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
    <#
    .SYNOPSIS
        Closes the current job-scoped logging session.
    
    .DESCRIPTION
        Ends the current logging job and writes a completion message to the log files.
        Clears the global job ID and job log file variables.
    
    .PARAMETER Reason
        Optional reason for closing the job (e.g., 'complete', 'dryrun', 'error').
    
    .EXAMPLE
        Close-LogJob -Reason "complete"
        
        Closes the current job log session with reason "complete".
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
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
    <#
    .SYNOPSIS
        Validates that a value is not null and throws an exception if it is.
    
    .DESCRIPTION
        Helper function for parameter validation. Checks if a value is null or empty
        and throws an exception with the provided message if validation fails.
    
    .PARAMETER Value
        The value to check for null.
    
    .PARAMETER Message
        The error message to log and throw if the value is null.
    
    .EXAMPLE
        Throw-IfNull -Value $deviceConfig -Message "Device configuration is required"
        
        Throws an exception if $deviceConfig is null.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
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
    <#
    .SYNOPSIS
        Prompts user for yes/no confirmation.
    
    .DESCRIPTION
        Displays a confirmation prompt and waits for user to enter y/n.
        Loops until valid input is received.
    
    .PARAMETER Message
        The confirmation message to display to the user.
    
    .EXAMPLE
        if (Confirm-YesNo "Delete all backups?") {
            Remove-Item $backups
        }
        
        Prompts for confirmation before deleting backups.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
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
    <#
    .SYNOPSIS
        Measures and logs the execution time of a script block.
    
    .DESCRIPTION
        Executes a script block and logs how long it took to complete.
        Useful for performance monitoring and debugging.
    
    .PARAMETER Action
        The script block to execute and measure.
    
    .PARAMETER Name
        Optional name for the action to include in the log message. Defaults to 'Action'.
    
    .EXAMPLE
        Measure-Action -Action { Deploy-AllDevices $devices } -Name "Full Deployment"
        
        Measures deployment time and logs "Full Deployment completed in X seconds".
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
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
    <#
    .SYNOPSIS
        Resolves a relative or absolute path to an absolute path.
    
    .DESCRIPTION
        Converts relative paths to absolute paths based on current location.
        If the path already exists, uses Resolve-Path. Otherwise, joins with current location.
    
    .PARAMETER Path
        The path to resolve (can be relative or absolute).
    
    .EXAMPLE
        $fullPath = Resolve-AbsolutePath -Path "configs/devices"
        
        Returns the absolute path to the configs/devices directory.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
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
    <#
    .SYNOPSIS
        Safely imports a PowerShell data file with error handling.
    
    .DESCRIPTION
        Wrapper around Import-PowerShellDataFile that catches errors and logs them.
        Returns null if import fails instead of throwing an exception.
    
    .PARAMETER Path
        The path to the .psd1 file to import.
    
    .EXAMPLE
        $config = Import-SafePSData -Path "device-config.psd1"
        if ($config) { Process-Config $config }
        
        Safely imports a configuration file.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
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
    <#
    .SYNOPSIS
        Creates a PSCredential object from username and password strings.
    
    .DESCRIPTION
        Converts plain text credentials to a secure PSCredential object.
        Used for SSH connections and authenticated operations.
    
    .PARAMETER Username
        The username for the credential.
    
    .PARAMETER Password
        The password for the credential (plain text).
    
    .EXAMPLE
        $cred = New-SecureCredential -Username "admin" -Password "cisco"
        
        Creates a credential object for admin user.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
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
    <#
    .SYNOPSIS
        Validates if a string is a valid IP address.
    
    .DESCRIPTION
        Uses .NET IPAddress parsing to validate IP address format.
        Supports both IPv4 and IPv6 addresses.
    
    .PARAMETER IP
        The IP address string to validate.
    
    .EXAMPLE
        if (Test-ValidIP "192.168.1.1") {
            Write-Host "Valid IP"
        }
        
        Returns $true if valid IP address.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
    param([Parameter(Mandatory)][string]$IP)
    return [System.Net.IPAddress]::TryParse($IP, [ref]0)
}


# -------------------------------------
# Mask → Wildcard Converter (pure IOS)
# -------------------------------------
function Convert-MaskToWildcard {
    <#
    .SYNOPSIS
        Converts a subnet mask to Cisco IOS wildcard mask format.
    
    .DESCRIPTION
        Takes a standard subnet mask (e.g., 255.255.255.0) and converts it to
        wildcard mask format (e.g., 0.0.0.255) used in Cisco IOS OSPF and ACL configurations.
    
    .PARAMETER Mask
        The subnet mask to convert (e.g., "255.255.255.252").
    
    .EXAMPLE
        $wildcard = Convert-MaskToWildcard -Mask "255.255.255.252"
        # Returns: "0.0.0.3"
        
        Converts /30 subnet mask to wildcard for OSPF network command.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
    param([Parameter(Mandatory)][string]$Mask)

    $octets = $Mask.Split(".") | ForEach-Object { 255 - [int]$_ }
    return ($octets -join ".")
}


# -------------------------------------
# Simple Random ID Generator (ACL, Pools)
# -------------------------------------
function New-RandomID {
    <#
    .SYNOPSIS
        Generates a random numeric ID.
    
    .DESCRIPTION
        Creates a random number string of specified length.
        Used for generating unique IDs for log jobs, ACLs, and NAT pools.
    
    .PARAMETER Digits
        Number of digits in the ID. Defaults to 4.
    
    .EXAMPLE
        $id = New-RandomID -Digits 6
        # Returns something like: "482739"
        
        Generates a 6-digit random ID.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
    param([int]$Digits = 4)
    return -join ((0..9) | Get-Random -Count $Digits)
}


# -------------------------------------
# Device Sorter (Routers first → Switches → Hosts)
# -------------------------------------
function Sort-DevicesForDeployment {
    <#
    .SYNOPSIS
        Sorts devices in optimal deployment order.
    
    .DESCRIPTION
        Orders devices by type for deployment: Routers first, then Switches, then Hosts.
        This ensures infrastructure devices are configured before endpoints.
    
    .PARAMETER Devices
        Array of device objects to sort.
    
    .EXAMPLE
        $orderedDevices = Sort-DevicesForDeployment -Devices $allDevices
        
        Returns devices sorted with routers first.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
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
