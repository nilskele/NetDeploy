<#
.SYNOPSIS
    Validates device configuration objects for NetDeploy.

.DESCRIPTION
    Ensures device configurations meet required structure,
    contain mandatory fields, and follow valid formatting rules.

    This prevents broken configurations from being deployed.
#>

. "$PSScriptRoot/Utils.ps1"


# ------------------------------------------------------
# Helper: Validate an IP address
# ------------------------------------------------------
function Test-ValidIP {
    param([string]$IP)
    return [System.Net.IPAddress]::TryParse($IP, [ref]0)
}


# ------------------------------------------------------
# Validate Router config
# ------------------------------------------------------
function Validate-Router {
    param($Device)

    Write-Log "Validating router: $($Device.Hostname)" -Level DEBUG

    #
    # Interfaces
    #
    if (-not $Device.Interfaces -or $Device.Interfaces.Count -eq 0) {
        throw "Router '$($Device.Hostname)': Must have at least one interface defined."
    }

    foreach ($iface in $Device.Interfaces) {

        Throw-IfNull $iface.Name "Router '$($Device.Hostname)': Interface missing Name"
        Throw-IfNull $iface.IP   "Router '$($Device.Hostname)': Interface $($iface.Name) missing IP"
        Throw-IfNull $iface.Mask "Router '$($Device.Hostname)': Interface $($iface.Name) missing Mask"

        if (-not (Test-ValidIP $iface.IP)) {
            throw "Router '$($Device.Hostname)': Interface $($iface.Name) has invalid IP '$($iface.IP)'"
        }

        if (-not (Test-ValidIP $iface.Mask)) {
            throw "Router '$($Device.Hostname)': Interface $($iface.Name) has invalid subnet mask '$($iface.Mask)'"
        }
    }


    #
    # OSPF
    #
    if ($Device.Routing.OSPF.Enabled) {

        Throw-IfNull $Device.Routing.OSPF.ProcessID "Router '$($Device.Hostname)': OSPF enabled but missing ProcessID"

        foreach ($net in $Device.Routing.OSPF.Networks) {
            if (-not $net.Network -or -not $net.Mask -or -not $net.Area) {
                throw "Router '$($Device.Hostname)': OSPF network statements must contain Network, Mask, Area."
            }

            if (-not (Test-ValidIP $net.Network)) {
                throw "Router '$($Device.Hostname)': OSPF network invalid Network IP '$($net.Network)'"
            }

            if (-not (Test-ValidIP $net.Mask)) {
                throw "Router '$($Device.Hostname)': OSPF network invalid Mask '$($net.Mask)'"
            }
        }
    }


    #
    # DHCP
    #
    if ($Device.DHCP.Enabled) {

        foreach ($pool in $Device.DHCP.Pools) {

            foreach ($field in @("PoolName","Network","Mask")) {
                Throw-IfNull $pool.$field "Router '$($Device.Hostname)': DHCP pool missing '$field'"
            }

            if (-not (Test-ValidIP $pool.Network)) {
                throw "Router '$($Device.Hostname)': DHCP pool invalid Network IP '$($pool.Network)'"
            }

            if (-not (Test-ValidIP $pool.Mask)) {
                throw "Router '$($Device.Hostname)': DHCP pool invalid subnet mask '$($pool.Mask)'"
            }

            if (-not $pool.DNS -or $pool.DNS.Count -eq 0) {
                throw "Router '$($Device.Hostname)': DHCP pool $($pool.PoolName) missing DNS servers"
            }

            foreach ($dns in $pool.DNS) {
                if (-not (Test-ValidIP $dns)) {
                    throw "Router '$($Device.Hostname)': DHCP pool $($pool.PoolName) has invalid DNS IP '$dns'"
                }
            }
        }
    }


    #
    # DNS
    #
    if ($Device.DNS.Enabled) {
        if (-not $Device.DNS.Domain) {
            throw "Router '$($Device.Hostname)': DNS enabled but missing Domain"
        }
    }


    #
    # NAT
    #
    if ($Device.NAT.Enabled) {

        if (-not $Device.NAT.InsideInterfaces) {
            throw "Router '$($Device.Hostname)': NAT enabled but no inside interfaces defined"
        }
        if (-not $Device.NAT.OutsideInterfaces) {
            throw "Router '$($Device.Hostname)': NAT enabled but no outside interfaces defined"
        }

        # Static NAT checks
        foreach ($rule in $Device.NAT.Static) {
            if (-not (Test-ValidIP $rule.Inside)) { throw "Router '$($Device.Hostname)': Invalid static NAT inside IP '$($rule.Inside)'" }
            if (-not (Test-ValidIP $rule.Outside)) { throw "Router '$($Device.Hostname)': Invalid static NAT outside IP '$($rule.Outside)'" }
        }
    }

    Write-Log "Router '$($Device.Hostname)' validation OK" -Level INFO
}



# ------------------------------------------------------
# Validate Switch config
# ------------------------------------------------------
function Validate-Switch {
    param($Device)

    Write-Log "Validating switch: $($Device.Hostname)" -Level DEBUG

    #
    # VLANs
    #
    foreach ($vlan in $Device.VLANs) {
        if (-not $vlan.ID -or $vlan.ID -lt 1 -or $vlan.ID -gt 4094) {
            throw "Switch '$($Device.Hostname)': VLAN ID '$($vlan.ID)' invalid (1–4094)"
        }
    }

    #
    # Interfaces
    #
    foreach ($iface in $Device.Interfaces) {

        Throw-IfNull $iface.Name "Switch '$($Device.Hostname)': Interface missing Name"

        switch ($iface.Mode) {
            "access" {
                if (-not $iface.VLAN) {
                    throw "Switch '$($Device.Hostname)': Access port '$($iface.Name)' missing VLAN"
                }
            }

            "trunk" {
                if (-not $iface.TrunkAllowed) {
                    throw "Switch '$($Device.Hostname)': Trunk port '$($iface.Name)' missing allowed VLANs"
                }
            }

            default {
                throw "Switch '$($Device.Hostname)': Interface $($iface.Name) mode '$($iface.Mode)' invalid"
            }
        }
    }

    Write-Log "Switch '$($Device.Hostname)' validation OK" -Level INFO
}



# ------------------------------------------------------
# Validate Host config
# ------------------------------------------------------
function Validate-Host {
    param($Device)

    Write-Log "Validating host: $($Device.Hostname)" -Level DEBUG

    foreach ($field in @("IP","Mask","Gateway")) {
        if (-not (Test-ValidIP $Device.$field)) {
            throw "Host '$($Device.Hostname)': Invalid $field '$($Device.$field)'"
        }
    }

    foreach ($dns in $Device.DNS) {
        if (-not (Test-ValidIP $dns)) {
            throw "Host '$($Device.Hostname)': Invalid DNS server '$dns'"
        }
    }

    Write-Log "Host '$($Device.Hostname)' validation OK" -Level INFO
}



# ------------------------------------------------------
# Validation Dispatcher
# ------------------------------------------------------
function Validate-Device {
    param([Parameter(Mandatory)] $Device)

    Write-Log "Validating device: $($Device.Hostname)"

    # Required for all devices
    foreach ($field in @("Hostname","DeviceType","ManagementIP","Credentials")) {
        if (-not $Device.$field) {
            throw "Device '$($Device.Hostname)': Missing required field '$field'"
        }
    }

    if (-not (Test-ValidIP $Device.ManagementIP)) {
        throw "Device '$($Device.Hostname)': Invalid ManagementIP '$($Device.ManagementIP)'"
    }

    # Type-specific validation
    switch ($Device.DeviceType.ToLower()) {
        "router" { Validate-Router $Device }
        "switch" { Validate-Switch $Device }
        "host"   { Validate-Host   $Device }
        default  { throw "Unknown DeviceType '$($Device.DeviceType)' in file $($Device.SourcePath)" }
    }

    Write-Log "Validation complete: $($Device.Hostname)" -Level DEBUG
}



# ------------------------------------------------------
# Validate list of devices
# ------------------------------------------------------
function Validate-AllDevices {
    param([Parameter(Mandatory)] $DeviceList)

    foreach ($device in $DeviceList) {
        Validate-Device -Device $device
    }

    Write-Log "All devices passed validation" -Level INFO
}
