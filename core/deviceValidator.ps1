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
    <#
    .SYNOPSIS
        Validates router configuration object.
    
    .DESCRIPTION
        Ensures router configuration has valid:
        - Interface definitions (Name, IP, Mask)
        - OSPF settings (if enabled: ProcessID, Networks, Areas)
        - DHCP pools (if enabled: Name, Network, Mask, DNS)
        - DNS configuration (if enabled: DomainName, DNSServers)
        - NAT settings (if enabled: Inside/Outside interfaces, Static rules)
        
        Throws exception if any validation fails.
    
    .PARAMETER Device
        Router device object to validate.
    
    .EXAMPLE
        Validate-Router -Device $routerConfig
        
        Validates router configuration structure and values.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
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
            # Accept entries that include Network + Area. Mask is optional in many examples.
            if (-not $net.Network -or $net.Area -eq $null) {
                throw "Router '$($Device.Hostname)': OSPF network statements must contain Network and Area."
            }

            if (-not (Test-ValidIP $net.Network)) {
                throw "Router '$($Device.Hostname)': OSPF network invalid Network IP '$($net.Network)'"
            }

            if ($net.Mask) {
                if (-not (Test-ValidIP $net.Mask)) {
                    throw "Router '$($Device.Hostname)': OSPF network invalid Mask '$($net.Mask)'"
                }
            }
        }
    }


    #
    # DHCP
    #
    if ($Device.DHCP.Enabled) {

        foreach ($pool in $Device.DHCP.Pools) {
            # Accept 'Name' (used in examples) instead of legacy 'PoolName'
            foreach ($field in @("Name","Network","Mask")) {
                Throw-IfNull $pool.$field "Router '$($Device.Hostname)': DHCP pool missing '$field'"
            }

            if (-not (Test-ValidIP $pool.Network)) {
                throw "Router '$($Device.Hostname)': DHCP pool invalid Network IP '$($pool.Network)'"
            }

            if (-not (Test-ValidIP $pool.Mask)) {
                throw "Router '$($Device.Hostname)': DHCP pool invalid subnet mask '$($pool.Mask)'"
            }

            # Accept DNSServers or DNS for backward compatibility
            $dnsList = @()
            if ($pool.DNSServers) { $dnsList = $pool.DNSServers } elseif ($pool.DNS) { $dnsList = $pool.DNS }

            if (-not $dnsList -or $dnsList.Count -eq 0) {
                throw "Router '$($Device.Hostname)': DHCP pool $($pool.Name) missing DNS servers"
            }

            foreach ($dns in $dnsList) {
                if (-not (Test-ValidIP $dns)) {
                    throw "Router '$($Device.Hostname)': DHCP pool $($pool.Name) has invalid DNS IP '$dns'"
                }
            }
        }
    }


    #
    # DNS
    #
    if ($Device.DNS.Enabled) {
        # Accept either DomainName or Domain (examples use DomainName)
        $dnsDomain = $Device.DNS.DomainName
        if (-not $dnsDomain) { $dnsDomain = $Device.DNS.Domain }

        if (-not $dnsDomain) {
            throw "Router '$($Device.Hostname)': DNS enabled but missing DomainName/Domain"
        }

        # Require list of DNS servers (DNSServers)
        $dnsServers = $Device.DNS.DNSServers
        if (-not $dnsServers -or $dnsServers.Count -eq 0) {
            throw "Router '$($Device.Hostname)': DNS enabled but missing DNSServers"
        }

        foreach ($dns in $dnsServers) {
            if (-not (Test-ValidIP $dns)) {
                throw "Router '$($Device.Hostname)': DNS has invalid server IP '$dns'"
            }
        }
    }


    #
    # NAT
    #
    if ($Device.NAT.Enabled) {

        # Accept either singular InsideInterface/OutsideInterface or arrays InsideInterfaces/OutsideInterfaces
        if (-not $Device.NAT.InsideInterfaces -and -not $Device.NAT.InsideInterface) {
            throw "Router '$($Device.Hostname)': NAT enabled but no inside interfaces defined"
        }
        if (-not $Device.NAT.OutsideInterfaces -and -not $Device.NAT.OutsideInterface) {
            throw "Router '$($Device.Hostname)': NAT enabled but no outside interfaces defined"
        }

        # Static NAT checks - accept both Inside/Outside and InsideLocal/InsideGlobal naming
        foreach ($rule in $Device.NAT.Static) {
            $inside = $null; $outside = $null
            if ($rule.InsideLocal) { $inside = $rule.InsideLocal } elseif ($rule.Inside) { $inside = $rule.Inside }
            if ($rule.InsideGlobal) { $outside = $rule.InsideGlobal } elseif ($rule.Outside) { $outside = $rule.Outside }

            if (-not (Test-ValidIP $inside)) { throw "Router '$($Device.Hostname)': Invalid static NAT inside IP '$inside'" }
            if (-not (Test-ValidIP $outside)) { throw "Router '$($Device.Hostname)': Invalid static NAT outside IP '$outside'" }
        }
    }

    Write-Log "Router '$($Device.Hostname)' validation OK" -Level INFO
}



# ------------------------------------------------------
# Validate Switch config
# ------------------------------------------------------
function Validate-Switch {
    <#
    .SYNOPSIS
        Validates switch configuration object.
    
    .DESCRIPTION
        Ensures switch configuration has valid:
        - VLAN definitions (ID range 1-4094)
        - Interface configurations (Name, Mode)
        - Access ports (VLAN assignment)
        - Trunk ports (Allowed VLANs)
        
        Throws exception if any validation fails.
    
    .PARAMETER Device
        Switch device object to validate.
    
    .EXAMPLE
        Validate-Switch -Device $switchConfig
        
        Validates switch configuration structure and values.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
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
    <#
    .SYNOPSIS
        Validates host configuration object.
    
    .DESCRIPTION
        Ensures host configuration has valid:
        - IP address
        - Subnet mask
        - Default gateway
        - DNS servers
        
        Throws exception if any validation fails.
    
    .PARAMETER Device
        Host device object to validate.
    
    .EXAMPLE
        Validate-Host -Device $hostConfig
        
        Validates host configuration structure and values.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
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
    <#
    .SYNOPSIS
        Validates a single device configuration.
    
    .DESCRIPTION
        Main validation dispatcher that:
        1. Validates common required fields (Hostname, DeviceType, ManagementIP, Credentials)
        2. Validates ManagementIP format
        3. Delegates to type-specific validator (Router/Switch/Host)
        
        Throws exception if validation fails.
    
    .PARAMETER Device
        Device object to validate.
    
    .EXAMPLE
        Validate-Device -Device $device
        
        Validates device configuration based on DeviceType.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
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
    <#
    .SYNOPSIS
        Validates multiple device configurations.
    
    .DESCRIPTION
        Iterates through device list and validates each device.
        Stops at first validation error.
    
    .PARAMETER DeviceList
        Array of device objects to validate.
    
    .EXAMPLE
        Validate-AllDevices -DeviceList $devices
        
        Validates all devices in the list.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
    param([Parameter(Mandatory)] $DeviceList)

    foreach ($device in $DeviceList) {
        Validate-Device -Device $device
    }

    Write-Log "All devices passed validation" -Level INFO
}
