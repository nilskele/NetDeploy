@{
    Hostname     = "S2"
    DeviceType   = "Switch"
    ManagementIP = "192.168.1.12"
    SSHPort      = 22

    Credentials = @{
        Username = "admin"
        Password = "cisco123"
    }

    VLANs = @(
        @{ ID = 1; Name = "Default" },
        @{ ID = 10; Name = "LAN1" }
    )

    Interfaces = @(
        @{ Name = "GigabitEthernet0/1"; Mode = "access"; VLAN = 10; TrunkAllowed = @(); Description = "H3"; Status = "up" },
        @{ Name = "GigabitEthernet0/24"; Mode = "trunk"; VLAN = 0; TrunkAllowed = @(10); Description = "Uplink to S1"; Status = "up" }
    )

    EtherChannel = @{ Enabled = $false; ID = 1; Mode = "active"; Interfaces = @() }

    SVIs = @(
        @{ VLAN = 10; IP = "10.0.0.253"; Mask = "255.255.255.0" }
    )

    ACLs = @()
    STP  = @{ Mode = "pvst"; Priority = 32768 }
    DHCPRelay = @{ Enabled = $true; RelayIPs = @("10.0.0.1") }
    Logging   = @{ Enabled = $true; Host = "192.168.100.20" }
}
