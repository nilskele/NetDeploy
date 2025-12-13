<#
.SYNOPSIS
    Loads device configuration files for NetDeploy.

.DESCRIPTION
    Imports .psd1 device files, normalizes missing fields,
    attaches metadata, and outputs ready-to-validate device objects.

    Does NOT validate correctness — DeviceValidator.ps1 handles that.
#>

. "$PSScriptRoot/Utils.ps1"


# -------------------------------------------------------
# Default field templates for devices
# -------------------------------------------------------
$Global:DefaultRouterSchema = @{
    Hostname     = ""
    DeviceType   = "Router"
    ManagementIP = ""
    SSHPort      = 22

    Credentials = @{
        Username = ""
        Password = ""
    }

    Interfaces = @()

    Routing = @{
        OSPF = @{
            Enabled   = $false
            ProcessID = 1
            Networks  = @()
            PassiveInterfaces = @()
        }
    }

    NAT = @{
        Enabled = $false
        InsideInterfaces = @()
        OutsideInterfaces = @()
        Static = @()
        DynamicPools = @()
    }

    DHCP = @{
        Enabled = $false
        Pools = @()
    }

    DNS = @{
        Enabled = $false
        Domain = ""
        Records = @()
    }

    ACLs = @()
}


$Global:DefaultSwitchSchema = @{
    Hostname     = ""
    DeviceType   = "Switch"
    ManagementIP = ""
    SSHPort      = 22

    Credentials = @{
        Username = ""
        Password = ""
    }

    VLANs = @()
    Interfaces = @()
    EtherChannel = @{
        Enabled = $false
        ID = 1
        Mode = "active"
        Interfaces = @()
    }

    SVIs = @()

    ACLs = @()
    STP = @{ Mode = "pvst"; Priority = 32768 }
    DHCPRelay = @{ Enabled = $false; RelayIPs = @() }
    Logging = @{ Enabled = $false; Host = "" }
}


$Global:DefaultHostSchema = @{
    Hostname = ""
    DeviceType = "Host"

    IP = ""
    Mask = ""
    Gateway = ""
    DNS = @()
}



# -------------------------------------------------------
# Merge user PSD1 data with defaults
# -------------------------------------------------------
function Merge-ConfigWithSchema {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Data,

        [Parameter(Mandatory)]
        [hashtable]$Schema
    )

    $output = @{}

    foreach ($key in $Schema.Keys) {

        if ($Data.ContainsKey($key)) {
            # Recursively merge nested hashes
            if ($Schema[$key] -is [hashtable]) {
                $output[$key] = Merge-ConfigWithSchema -Data $Data[$key] -Schema $Schema[$key]
            }
            else {
                $output[$key] = $Data[$key]
            }
        }
        else {
            # Use default
            $output[$key] = $Schema[$key]
        }
    }

    return $output
}


# -------------------------------------------------------
# Load a single PSD1 device file
# -------------------------------------------------------
function Load-DeviceConfig {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $absPath = Resolve-AbsolutePath $Path

    if (-not (Test-Path $absPath)) {
        Write-Log -Message "Device config not found: $absPath" -Level ERROR
        throw "Missing device config: $absPath"
    }

    Write-Log "Loading device configuration: $absPath"

    $raw = Import-SafePSData -Path $absPath
    if (-not $raw) {
        throw "Device config failed to load: $absPath"
    }

    if (-not $raw.DeviceType) {
        throw "Device config missing DeviceType: $absPath"
    }

    # Merge based on device type
    switch ($raw.DeviceType) {
        "Router" {
            $final = Merge-ConfigWithSchema -Data $raw -Schema $Global:DefaultRouterSchema
        }
        "Switch" {
            $final = Merge-ConfigWithSchema -Data $raw -Schema $Global:DefaultSwitchSchema
        }
        "Host" {
            $final = Merge-ConfigWithSchema -Data $raw -Schema $Global:DefaultHostSchema
        }
        default {
            throw "Unknown DeviceType '$($raw.DeviceType)' in file: $absPath"
        }
    }

    # Convert to PSCustomObject
    $obj = [PSCustomObject]$final

    # Add metadata
    $obj | Add-Member -NotePropertyName SourcePath -NotePropertyValue $absPath
    $obj | Add-Member -NotePropertyName ImportTimestamp -NotePropertyValue (Get-Date)

    return $obj
}



# -------------------------------------------------------
# Load all devices in a folder
# -------------------------------------------------------
function Load-AllDevices {
    param(
        [Parameter(Mandatory)]
        [string]$Folder
    )

    $absFolder = Resolve-AbsolutePath $Folder

    if (-not (Test-Path $absFolder)) {
        throw "Invalid device folder: $absFolder"
    }

    Write-Log "Loading device files from $absFolder"

    $files = Get-ChildItem -Path $absFolder -Filter *.psd1

    if ($files.Count -eq 0) {
        Write-Log -Message "No .psd1 files found in $absFolder" -Level WARN
        return @()
    }

    $list = @()
    $index = 1

    foreach ($file in $files) {
        $d = Load-DeviceConfig -Path $file.FullName
        $d | Add-Member DeviceIndex $index
        $index++
        $list += $d
    }

    # Sort Routers → Switches → Hosts
    $sorted = Sort-DevicesForDeployment -Devices $list

    Write-Log "Loaded $($sorted.Count) device configurations"
    return $sorted
}



# -------------------------------------------------------
# Load a specific device by hostname
# -------------------------------------------------------
function Load-DeviceByName {
    param(
        [Parameter(Mandatory)]
        [string]$Folder,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $devices = Load-AllDevices -Folder $Folder
    $match = $devices | Where-Object { $_.Hostname -eq $Name }

    if (-not $match) {
        throw "No device named '$Name' found in folder: $Folder"
    }

    return $match
}
