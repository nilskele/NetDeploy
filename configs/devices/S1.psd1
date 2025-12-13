@{
    Hostname     = "S1"
    DeviceType   = "Switch"
    ManagementIP = "192.168.1.11"
    SSHPort      = 22

    Credentials = @{
        Username = "admin"
        Password = "cisco123"
    }

    VLANs = @(
        @{ ID = 1; Name = "Default" },
        @{ ID = 10; Name = "LAN1" },
        @{ ID = 20; Name = "LAN2" }
    )

    Interfaces = @(
        @{ Name = "GigabitEthernet0/1"; Mode = "access"; VLAN = 10; TrunkAllowed = @(); Description = "H1"; Status = "up" },
        @{ Name = "GigabitEthernet0/2"; Mode = "access"; VLAN = 10; TrunkAllowed = @(); Description = "H2"; Status = "up" },
        @{ Name = "GigabitEthernet0/24"; Mode = "trunk"; VLAN = 0; TrunkAllowed = @(10,20); Description = "Uplink to R1"; Status = "up" }
    )

    EtherChannel = @{
        Enabled    = $false
        ID         = 1
        Mode       = "active"
        Interfaces = @()
    }

    SVIs = @(
        @{ VLAN = 10; IP = "10.0.0.254"; Mask = "255.255.255.0" },
        @{ VLAN = 20; IP = "10.0.1.254"; Mask = "255.255.255.0" }
    )

    ACLs = @()
    STP  = @{ Mode = "pvst"; Priority = 32768 }
    DHCPRelay = @{ Enabled = $true; RelayIPs = @("10.0.0.1") }  # R1 is DHCP server
    Logging   = @{ Enabled = $true; Host = "192.168.100.20" }
}
