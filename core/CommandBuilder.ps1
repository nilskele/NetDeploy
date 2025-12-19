<#
.SYNOPSIS
    CommandBuilder.ps1 - Build Cisco IOS CLI commands from PSD1 device objects.

.DESCRIPTION
    Generates ordered arrays of Cisco IOS CLI command strings from device objects
    loaded by DeviceLoader. Supports Routers (incl. DHCP/DNS/NAT/OSPF/etc.),
    Switches (VLANs, access/trunk/routed ports, SVIs, EtherChannel) and Hosts (templates).

USAGE:
    $cmds = Build-Commands -Device $deviceObject
    $cmds | ForEach-Object { Write-Host $_ }
#>

. "$PSScriptRoot/Utils.ps1"

# -------------------------
# Helpers
# -------------------------
function Convert-ToWildcard {
    <#
    .SYNOPSIS
        Converts a subnet mask to wildcard mask format.
    
    .DESCRIPTION
        Helper function that converts standard subnet masks to Cisco wildcard format.
        Falls back to manual conversion if Convert-MaskToWildcard is not available.
    
    .PARAMETER Mask
        The subnet mask to convert (e.g., "255.255.255.252").
    
    .EXAMPLE
        $wildcard = Convert-ToWildcard -Mask "255.255.255.252"
        # Returns: "0.0.0.3"
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
    param([Parameter(Mandatory)][string]$Mask)
    if (Get-Command -Name Convert-MaskToWildcard -ErrorAction SilentlyContinue) {
        return Convert-MaskToWildcard -Mask $Mask
    }

    $parts = $Mask.Split('.') | ForEach-Object { [int]$_ }
    $wild = $parts | ForEach-Object { (255 - $_) } -join "."
    return $wild
}

function Prefix-FromMask {
    <#
    .SYNOPSIS
        Converts a subnet mask to CIDR prefix notation.
    
    .DESCRIPTION
        Helper function that converts subnet masks like 255.255.255.0 to prefix length (e.g., 24).
        Falls back to manual bit counting if MaskToPrefix is not available.
    
    .PARAMETER Mask
        The subnet mask to convert (e.g., "255.255.255.0").
    
    .EXAMPLE
        $prefix = Prefix-FromMask -Mask "255.255.255.0"
        # Returns: 24
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
    param([Parameter(Mandatory)][string]$Mask)
    if (Get-Command -Name MaskToPrefix -ErrorAction SilentlyContinue) {
        return MaskToPrefix -Mask $Mask
    }

    $bytes = [System.Net.IPAddress]::Parse($Mask).GetAddressBytes()
    $count = 0
    foreach ($b in $bytes) {
        $count += ([Convert]::ToString($b,2) -split '1').Length - 1
    }
    return $count
}

function Safe-Append {
    <#
    .SYNOPSIS
        Safely appends an item to an array passed by reference.
    
    .DESCRIPTION
        Helper function for building command arrays. Appends items to an array
        passed by reference to avoid PowerShell's array modification issues.
    
    .PARAMETER ArrayRef
        Reference to the array to append to (use [ref]$array).
    
    .PARAMETER Item
        The item to append to the array.
    
    .EXAMPLE
        $cmds = @()
        Safe-Append -ArrayRef ([ref]$cmds) -Item "enable"
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
    param(
        [Parameter(Mandatory)][ref]$ArrayRef,
        [Parameter(Mandatory)][object]$Item
    )
    $array = $ArrayRef.Value
    $array += $Item
    $ArrayRef.Value = $array
}

# -------------------------
# Router builder
# -------------------------
function Build-RouterCommands {
    <#
    .SYNOPSIS
        Builds Cisco IOS router configuration commands from a device object.
    
    .DESCRIPTION
        Generates a complete ordered list of Cisco IOS CLI commands for router configuration.
        Includes: hostname, AAA, interfaces, static routes, OSPF, NAT, DHCP, DNS, NTP, syslog, ACLs.
        
        All commands are returned as a single array ready for sequential execution.
    
    .PARAMETER Config
        The router configuration object containing all settings.
    
    .EXAMPLE
        $commands = Build-RouterCommands -Config $routerConfig
        
        Generates command array for router configuration.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
    param([Parameter(Mandatory)] $Config)

    Write-Log "Building router commands for $($Config.Hostname)" -Level DEBUG

    $cmds = @()
    $a = [ref]$cmds

    # enter enable & config mode
    Safe-Append -ArrayRef $a -Item "enable"
    Safe-Append -ArrayRef $a -Item "configure terminal"

    # basic housekeeping
    Safe-Append -ArrayRef $a -Item "no ip domain-lookup"
    Safe-Append -ArrayRef $a -Item "hostname $($Config.Hostname)"

    # AAA users
    if ($Config.Services -and $Config.Services.AAA -and $Config.Services.AAA.Enabled) {
        Safe-Append -ArrayRef $a -Item "aaa new-model"
        foreach ($u in $Config.Services.AAA.Users) {
            if ($u.Username -and $u.Password) {
                Safe-Append -ArrayRef $a -Item "username $($u.Username) privilege $($u.Privilege) secret $($u.Password)"
            }
        }
    }

    # Interfaces
    foreach ($intf in $Config.Interfaces) {
        if (-not $intf.Name) { continue }
        Safe-Append -ArrayRef $a -Item "interface $($intf.Name)"
        if ($intf.Description) { Safe-Append -ArrayRef $a -Item " description $($intf.Description)" }
        if ($intf.IP -and $intf.Mask) { Safe-Append -ArrayRef $a -Item " ip address $($intf.IP) $($intf.Mask)" }
        if ($intf.Status -and $intf.Status -ieq "down") { Safe-Append -ArrayRef $a -Item " shutdown" } else { Safe-Append -ArrayRef $a -Item " no shutdown" }
        Safe-Append -ArrayRef $a -Item " exit"
    }

    # Static routes
    if ($Config.Routing -and $Config.Routing.StaticRoutes) {
        foreach ($r in $Config.Routing.StaticRoutes) {
            if ($r.Network -and $r.Mask -and $r.NextHop) {
                Safe-Append -ArrayRef $a -Item " ip route $($r.Network) $($r.Mask) $($r.NextHop)"
            }
        }
    }

    # OSPF
    if ($Config.Routing -and $Config.Routing.OSPF -and $Config.Routing.OSPF.Enabled) {
        $ospfID = $Config.Routing.OSPF.ProcessID
        if (-not $ospfID) { $ospfID = 1 }
        Safe-Append -ArrayRef $a -Item "router ospf $ospfID"
        if ($Config.Routing.OSPF.RouterID) { Safe-Append -ArrayRef $a -Item "router-id $($Config.Routing.OSPF.RouterID)" }

        foreach ($net in $Config.Routing.OSPF.Networks) {
            if ($net.Network -and $net.Mask -and $net.Area -ne $null) {
                $wild = Convert-ToWildcard -Mask $net.Mask
                Safe-Append -ArrayRef $a -Item "network $($net.Network) $wild area $($net.Area)"
            } else {
                Write-Log "OSPF network entry missing fields on $($Config.Hostname): $($net | Out-String)" -Level WARN
            }
        }
        Safe-Append -ArrayRef $a -Item "exit"
    }

    # NAT
    if ($Config.NAT -and $Config.NAT.Enabled) {
        # Inside
        if ($Config.NAT.InsideInterface) {
            Safe-Append -ArrayRef $a -Item "interface $($Config.NAT.InsideInterface)"
            Safe-Append -ArrayRef $a -Item " ip nat inside"
            Safe-Append -ArrayRef $a -Item " exit"
        } elseif ($Config.NAT.InsideInterfaces) {
            foreach ($ii in $Config.NAT.InsideInterfaces) {
                Safe-Append -ArrayRef $a -Item "interface $ii"
                Safe-Append -ArrayRef $a -Item " ip nat inside"
                Safe-Append -ArrayRef $a -Item " exit"
            }
        }

        # Outside
        if ($Config.NAT.OutsideInterface) {
            Safe-Append -ArrayRef $a -Item "interface $($Config.NAT.OutsideInterface)"
            Safe-Append -ArrayRef $a -Item " ip nat outside"
            Safe-Append -ArrayRef $a -Item " exit"
        } elseif ($Config.NAT.OutsideInterfaces) {
            foreach ($oi in $Config.NAT.OutsideInterfaces) {
                Safe-Append -ArrayRef $a -Item "interface $oi"
                Safe-Append -ArrayRef $a -Item " ip nat outside"
                Safe-Append -ArrayRef $a -Item " exit"
            }
        }

        # Static NAT
        if ($Config.NAT.Static) {
            foreach ($s in $Config.NAT.Static) {
                if ($s.InsideLocal -and $s.InsideGlobal) {
                    Safe-Append -ArrayRef $a -Item " ip nat inside source static $($s.InsideLocal) $($s.InsideGlobal)"
                }
            }
        }

        # PAT
        if ($Config.NAT.PAT -and $Config.NAT.PAT.Enabled) {
            $acl = if ($Config.NAT.PAT.ACLNumber) { $Config.NAT.PAT.ACLNumber } else { 10 }
            if ($Config.NAT.OutsideInterface) {
                Safe-Append -ArrayRef $a -Item " ip nat inside source list $acl interface $($Config.NAT.OutsideInterface) overload"
            } elseif ($Config.NAT.OutsideInterfaces) {
                Safe-Append -ArrayRef $a -Item " ip nat inside source list $acl interface $($Config.NAT.OutsideInterfaces[0]) overload"
            } else {
                Write-Log "PAT configured but no outside interface set on $($Config.Hostname)" -Level WARN
            }
        }

        # NAT pools
        if ($Config.NAT.Pools) {
            foreach ($p in $Config.NAT.Pools) {
                if ($p.Name -and $p.StartIP -and $p.EndIP -and $p.Netmask) {
                    Safe-Append -ArrayRef $a -Item " ip nat pool $($p.Name) $($p.StartIP) $($p.EndIP) netmask $($p.Netmask)"
                    if ($p.ACLNumber) { Safe-Append -ArrayRef $a -Item " ip nat inside source list $($p.ACLNumber) pool $($p.Name)" }
                }
            }
        }
    }

    # DHCP
    if ($Config.DHCP -and $Config.DHCP.Enabled) {
        foreach ($pool in $Config.DHCP.Pools) {
            if ($pool.ExcludedAddresses) {
                $excl = $pool.ExcludedAddresses -join " "
                Safe-Append -ArrayRef $a -Item "ip dhcp excluded-address $excl"
            }
            $poolName = if ($pool.Name) { $pool.Name } else { "POOL-$([System.Guid]::NewGuid().ToString().Substring(0,4))" }
            Safe-Append -ArrayRef $a -Item "ip dhcp pool $poolName"
            if ($pool.Network -and $pool.Mask) { Safe-Append -ArrayRef $a -Item " network $($pool.Network) $($pool.Mask)" } 
            if ($pool.DefaultRouter) { Safe-Append -ArrayRef $a -Item " default-router $($pool.DefaultRouter)" }
            if ($pool.DNSServers) { Safe-Append -ArrayRef $a -Item " dns-server $($pool.DNSServers -join ' ')" }
            if ($pool.DomainName) { Safe-Append -ArrayRef $a -Item " domain-name $($pool.DomainName)" }
            Safe-Append -ArrayRef $a -Item " exit"
        }
    }

    # DNS
    if ($Config.DNS -and $Config.DNS.Enabled) {
        if ($Config.DNS.DomainName) { Safe-Append -ArrayRef $a -Item "ip domain-name $($Config.DNS.DomainName)" }
        if ($Config.DNS.DNSServers) { Safe-Append -ArrayRef $a -Item "ip name-server $($Config.DNS.DNSServers -join ' ')" }
        foreach ($h in $Config.DNS.Hosts) {
            if ($h.Name -and $h.IP) { Safe-Append -ArrayRef $a -Item "ip host $($h.Name) $($h.IP)" }
        }
    }

    # NTP
    if ($Config.Services -and $Config.Services.NTP -and $Config.Services.NTP.Enabled) {
        foreach ($s in $Config.Services.NTP.Servers) { Safe-Append -ArrayRef $a -Item "ntp server $s" }
    }

    # Syslog
    if ($Config.Services -and $Config.Services.Syslog -and $Config.Services.Syslog.Enabled) {
        if ($Config.Services.Syslog.Host) {
            Safe-Append -ArrayRef $a -Item "logging $($Config.Services.Syslog.Host)"
            if ($Config.Services.Syslog.TrapLevel) { Safe-Append -ArrayRef $a -Item "logging trap $($Config.Services.Syslog.TrapLevel)" }
        }
    }

    # ACLs
    if ($Config.ACLs) {
        foreach ($acl in $Config.ACLs) {
            if (-not $acl.Name) { continue }
            Safe-Append -ArrayRef $a -Item "ip access-list extended $($acl.Name)"
            foreach ($entry in $acl.Entries) {
                $action = $entry.Action ? $entry.Action : "permit"
                $proto  = $entry.Protocol ? $entry.Protocol : "ip"
                $src    = $entry.Source ? $entry.Source : "any"
                $dst    = $entry.Dest ? $entry.Dest : "any"
                Safe-Append -ArrayRef $a -Item " $action $proto $src $dst"
            }
            Safe-Append -ArrayRef $a -Item " exit"
        }
    }

    # End
    Safe-Append -ArrayRef $a -Item "end"
    Safe-Append -ArrayRef $a -Item "write memory"

    return $cmds
}

# -------------------------
# Switch builder
# -------------------------
function Build-SwitchCommands {
    <#
    .SYNOPSIS
        Builds Cisco IOS switch configuration commands from a device object.
    
    .DESCRIPTION
        Generates a complete ordered list of Cisco IOS CLI commands for switch configuration.
        Includes: hostname, VLANs, interfaces (access/trunk/routed), SVIs, default gateway,
        static routes, STP, DHCP relay, logging, AAA users.
    
    .PARAMETER Config
        The switch configuration object containing all settings.
    
    .EXAMPLE
        $commands = Build-SwitchCommands -Config $switchConfig
        
        Generates command array for switch configuration.
    
    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    
    param([Parameter(Mandatory)] $Config)

    Write-Log "Building switch commands for $($Config.Hostname)" -Level DEBUG

    $cmds = @()
    $a = [ref]$cmds

    Safe-Append -ArrayRef $a -Item "enable"
    Safe-Append -ArrayRef $a -Item "configure terminal"
    Safe-Append -ArrayRef $a -Item "no ip domain-lookup"
    Safe-Append -ArrayRef $a -Item "hostname $($Config.Hostname)"

    # VLANs
    if ($Config.VLANs) {
        foreach ($v in $Config.VLANs) {
            if (-not $v.ID) { continue }
            Safe-Append -ArrayRef $a -Item "vlan $($v.ID)"
            if ($v.Name) { Safe-Append -ArrayRef $a -Item " name $($v.Name)" }
            Safe-Append -ArrayRef $a -Item " exit"
        }
    }

    # Interfaces
    if ($Config.Interfaces) {
        foreach ($intf in $Config.Interfaces) {
            if (-not $intf.Name) { continue }
            Safe-Append -ArrayRef $a -Item "interface $($intf.Name)"

            switch ($intf.Mode) {
                "access" {
                    Safe-Append -ArrayRef $a -Item " switchport mode access"
                    if ($intf.VLAN) { Safe-Append -ArrayRef $a -Item " switchport access vlan $($intf.VLAN)" }
                }
                "trunk" {
                    Safe-Append -ArrayRef $a -Item " switchport trunk encapsulation dot1q"
                    Safe-Append -ArrayRef $a -Item " switchport mode trunk"
                    if ($intf.TrunkAllowed) { Safe-Append -ArrayRef $a -Item " switchport trunk allowed vlan $($intf.TrunkAllowed -join ',')" }
                    if ($intf.TrunkNativeVLAN) { Safe-Append -ArrayRef $a -Item " switchport trunk native vlan $($intf.TrunkNativeVLAN)" }
                }
                "routed" {
                    Safe-Append -ArrayRef $a -Item " no switchport"
                    if ($intf.IP -and $intf.Mask) { Safe-Append -ArrayRef $a -Item " ip address $($intf.IP) $($intf.Mask)" }
                }
                default { if ($intf.Description) { Safe-Append -ArrayRef $a -Item " description $($intf.Description)" } }
            }

            if ($intf.Status -and $intf.Status -ieq "down") { Safe-Append -ArrayRef $a -Item " shutdown" } else { Safe-Append -ArrayRef $a -Item " no shutdown" }

            # EtherChannel
            if ($intf.EtherChannel -and $intf.EtherChannel.Enabled -and $intf.EtherChannel.Group) {
                $mode = $intf.EtherChannel.Mode ? $intf.EtherChannel.Mode : "active"
                Safe-Append -ArrayRef $a -Item " channel-group $($intf.EtherChannel.Group) mode $mode"
            }

            Safe-Append -ArrayRef $a -Item " exit"
        }
    }

    # Global EtherChannel
    if ($Config.EtherChannel -and $Config.EtherChannel.Enabled) {
        $id = $Config.EtherChannel.ID
        Safe-Append -ArrayRef $a -Item "interface Port-channel$id"
        if ($Config.EtherChannel.SVI -and $Config.EtherChannel.SVI.IP -and $Config.EtherChannel.SVI.Mask) {
            Safe-Append -ArrayRef $a -Item " ip address $($Config.EtherChannel.SVI.IP) $($Config.EtherChannel.SVI.Mask)"
        }
        Safe-Append -ArrayRef $a -Item " no shutdown"
        Safe-Append -ArrayRef $a -Item " exit"
    }

    # SVIs
    if ($Config.SVIs) {
        foreach ($svi in $Config.SVIs) {
            if (-not $svi.VLAN) { continue }
            Safe-Append -ArrayRef $a -Item "interface Vlan$($svi.VLAN)"
            if ($svi.IP -and $svi.Mask) { Safe-Append -ArrayRef $a -Item " ip address $($svi.IP) $($svi.Mask)" }
            Safe-Append -ArrayRef $a -Item " no shutdown"
            Safe-Append -ArrayRef $a -Item " exit"
        }
    }

    # Default Gateway (for L2 switches)
    if ($Config.DefaultGateway) {
        Safe-Append -ArrayRef $a -Item "ip default-gateway $($Config.DefaultGateway)"
    }

    # L3 static routes
    if ($Config.L3 -and $Config.L3.StaticRoutes) {
        foreach ($r in $Config.L3.StaticRoutes) {
            if ($r.Network -and $r.Mask -and $r.NextHop) {
                Safe-Append -ArrayRef $a -Item " ip route $($r.Network) $($r.Mask) $($r.NextHop)"
            }
        }
    }

    # STP
    if ($Config.STP -and $Config.STP.Mode) {
        switch ($Config.STP.Mode) {
            "pvst" { Safe-Append -ArrayRef $a -Item "spanning-tree mode pvst" }
            "rstp" { Safe-Append -ArrayRef $a -Item "spanning-tree mode rapid-pvst" }
            "mst"  { Safe-Append -ArrayRef $a -Item "spanning-tree mode mst" }
        }
        if ($Config.STP.Priority) { Safe-Append -ArrayRef $a -Item "spanning-tree vlan 1 priority $($Config.STP.Priority)" }
    }

    # DHCP Relay
    if ($Config.DHCPRelay -and $Config.DHCPRelay.Enabled -and $Config.DHCPRelay.RelayIPs) {
        foreach ($ip in $Config.DHCPRelay.RelayIPs) { Safe-Append -ArrayRef $a -Item "ip dhcp relay address $ip" }
    }

    Safe-Append -ArrayRef $a -Item "end"
    Safe-Append -ArrayRef $a -Item "write memory"

    return $cmds
}

# -------------------------
# Host builder
# -------------------------
function Build-HostCommands {
    <#
    .SYNOPSIS
        Builds configuration commands for host devices from templates.
    
    .DESCRIPTION\n        Generates Linux/Unix host configuration commands including static IP setup,\n        gateway configuration, and DNS settings. Returns shell commands for host provisioning.\n    \n    .PARAMETER Config\n        The host configuration object containing IP, mask, gateway, DNS settings.\n    \n    .EXAMPLE\n        $commands = Build-HostCommands -Config $hostConfig\n        \n        Returns shell commands for host network configuration.\n    \n    .NOTES\n        18/12/2025 - v1.0 - Initial version - NetDeploy Project\n    #>\n    \n    param([Parameter(Mandatory)] $Config)

    Write-Log "Building host provisioning template for $($Config.Hostname)" -Level DEBUG

    $cmds = @()
    if ($Config.IP -and $Config.Mask) {
        $prefix = Prefix-FromMask -Mask $Config.Mask
        $dev = if ($Config.Interface) { $Config.Interface } else { "eth0" }
        $cmds += "# Set static IP on host"
        $cmds += "sudo ip addr add $($Config.IP)/$prefix dev $dev"
        if ($Config.Gateway) { $cmds += "sudo ip route add default via $($Config.Gateway)" }
        if ($Config.DNSServers) {
            $cmds += "# Add DNS servers to /etc/resolv.conf"
            foreach ($d in $Config.DNSServers) { $cmds += "echo 'nameserver $d' | sudo tee -a /etc/resolv.conf" }
        }
    } else {
        $cmds += "# Host $($Config.Hostname) set for DHCP"
        $cmds += "sudo dhclient -v || true"
    }

    return $cmds
}

# -------------------------
# Dispatcher
# -------------------------
function Build-Commands {
    <#
    .SYNOPSIS
        Main entry point for building device configuration commands.
    
    .DESCRIPTION
        Delegates to device-type specific builders (router, switch, host) based on DeviceType property.
        This is the primary function called by deployment scripts to generate command lists.
    \n    .PARAMETER Device
        The device object containing DeviceType and configuration settings.
    \n    .EXAMPLE
        $commands = Build-Commands -Device $deviceObject
        \n        Generates appropriate command array based on device type.
    \n    .NOTES
        18/12/2025 - v1.0 - Initial version - NetDeploy Project
    #>
    \n    param([Parameter(Mandatory)] $Device)

    switch ($Device.DeviceType.ToLower()) {
        "router" { return Build-RouterCommands -Config $Device }
        "switch" { return Build-SwitchCommands -Config $Device }
        "host"   { return Build-HostCommands -Config $Device }
        default  { throw "Unsupported DeviceType: $($Device.DeviceType) for $($Device.Hostname)" }
    }
}
