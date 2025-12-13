@{
    Hostname     = "R2"
    DeviceType   = "Router"
    ManagementIP = "192.168.1.2"
    SSHPort      = 22

    Credentials = @{
        Username = "admin"
        Password = "cisco123"
    }

    Interfaces = @(
        @{ Name = "GigabitEthernet0/0"; Description = "LAN"; IP = "10.0.1.1"; Mask = "255.255.255.0"; Status = "up" },
        @{ Name = "GigabitEthernet0/1"; Description = "WAN"; IP = "192.168.100.2"; Mask = "255.255.255.252"; Status = "up" }
    )

    Routing = @{
        OSPF = @{
            Enabled   = $true
            ProcessID = 1
            RouterID  = "2.2.2.2"
            Networks  = @(
                @{ Network = "10.0.1.0"; Area = 0 },
                @{ Network = "192.168.100.0"; Area = 0 }
            )
        }
        StaticRoutes = @()
    }

    NAT = @{
        Enabled         = $false
        InsideInterface = ""
        OutsideInterface = ""
        PAT = @{ Enabled = $false }
        Static = @()
        Pools = @()
    }

    DHCP = @{
        Enabled = $false
        Pools   = @()
    }

    DNS = @{
        Enabled    = $false
        DomainName = ""
        DNSServers = @()
        Hosts      = @()
    }

    Services = @{
        NTP = @{
            Enabled = $true
            Servers = @("192.168.100.10")
        }
        Syslog = @{
            Enabled = $true
            Host = "192.168.100.20"
        }
        AAA = @{
            Enabled = $true
            Users   = @(
                @{ Username = "admin"; Privilege = 15; Password = "cisco123" }
            )
        }
    }
}
