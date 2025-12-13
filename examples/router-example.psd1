@{
    Hostname     = "R1"
    DeviceType   = "Router"
    ManagementIP = "192.168.1.1"
    SSHPort      = 22

    Credentials = @{
        Username = "admin"
        Password = "cisco123"
    }

    Interfaces = @(
        @{ Name = "GigabitEthernet0/0"; Description = "LAN"; IP = "10.0.0.1"; Mask = "255.255.255.0"; Status = "up" },
        @{ Name = "GigabitEthernet0/1"; Description = "WAN"; IP = "192.168.100.1"; Mask = "255.255.255.252"; Status = "up" }
    )

    Routing = @{
        StaticRoutes = @(
            @{ Network = "172.16.0.0"; Mask = "255.255.0.0"; NextHop = "10.0.0.2" }
        )
        OSPF = @{
            Enabled   = $true
            ProcessID = 1
            RouterID  = "1.1.1.1"
            Networks  = @(
                @{ Network = "10.0.0.0"; Area = 0 },
                @{ Network = "192.168.100.0"; Area = 0 }
            )
        }
    }

    NAT = @{
        Enabled         = $true
        InsideInterface = "GigabitEthernet0/0"
        OutsideInterface = "GigabitEthernet0/1"
        PAT = @{ Enabled = $true }
        Static = @(
            @{ InsideLocal = "10.0.0.5"; InsideGlobal = "192.168.100.5" }
        )
        Pools = @()
    }

    DHCP = @{
        Enabled = $true
        Pools   = @(
            @{
                Name              = "LAN_POOL"
                Network           = "10.0.0.0"
                Mask              = "255.255.255.0"
                DefaultRouter     = "10.0.0.1"
                DNSServers        = @("8.8.8.8","8.8.4.4")
                DomainName        = "example.local"
                ExcludedAddresses = @("10.0.0.1","10.0.0.2")
            }
        )
    }

    DNS = @{
        Enabled    = $true
        DomainName = "example.local"
        DNSServers = @("8.8.8.8")
        Hosts      = @(
            @{ Name = "host1"; IP = "10.0.0.10" },
            @{ Name = "host2"; IP = "10.0.0.11" }
        )
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
