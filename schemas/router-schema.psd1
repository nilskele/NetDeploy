@{
    Hostname     = ""
    DeviceType   = "Router"
    ManagementIP = ""
    SSHPort      = 22

    Credentials = @{
        Username = ""
        Password = ""
    }

    # Interfaces
    Interfaces = @(
        @{
            Name        = ""          # e.g., GigabitEthernet0/0
            Description = ""
            IP          = ""
            Mask        = ""
            Status      = "up"        # up or down
        }
    )

    # Routing
    Routing = @{
        StaticRoutes = @(
            @{
                Network  = ""
                Mask     = ""
                NextHop  = ""
            }
        )

        OSPF = @{
            Enabled   = $false
            ProcessID = 1
            RouterID  = ""
            Networks  = @(
                @{
                    Network = ""
                    Area    = 0
                }
            )
        }

        EIGRP = @{
            Enabled = $false
            ASN     = ""
            Networks = @(
                @{
                    Network = ""
                }
            )
        }
    }

    # NAT
    NAT = @{
        Enabled         = $false
        InsideInterface = ""
        OutsideInterface = ""

        # Optional PAT (overload)
        PAT = @{
            Enabled   = $false
            ACLNumber = ""
        }

        # Optional Static NAT
        Static = @(
            @{
                InsideLocal  = ""
                InsideGlobal = ""
            }
        )

        # Optional NAT Pools
        Pools = @(
            @{
                Name      = ""
                StartIP   = ""
                EndIP     = ""
                Netmask   = ""
                ACLNumber = ""
            }
        )
    }

    # DHCP server
    DHCP = @{
        Enabled = $false
        Pools   = @(
            @{
                Name              = ""
                Network           = ""
                Mask              = ""
                DefaultRouter     = ""
                DNSServers        = @()
                DomainName        = ""
                ExcludedAddresses = @()
            }
        )
    }

    # DNS
    DNS = @{
        Enabled    = $false
        DomainName = ""
        DNSServers = @()  # forwarders
        Hosts      = @(
            @{
                Name = ""
                IP   = ""
            }
        )
    }

    # Additional Services
    Services = @{
        NTP = @{
            Enabled = $false
            Servers = @()
        }

        Syslog = @{
            Enabled   = $false
            Host      = ""
            TrapLevel = "informational"
        }

        AAA = @{
            Enabled = $false
            Users   = @(
                @{
                    Username  = ""
                    Privilege = 15
                    Password  = ""
                }
            )
        }
    }
}
