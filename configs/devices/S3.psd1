@{
    Hostname     = "S3"
    DeviceType   = "Switch"
    ManagementIP = "192.168.1.13"
    SSHPort      = 22

    Credentials = @{
        Username = "admin"
        Password = "cisco123"
    }

    VLANs = @(
        @{ ID = 1; Name = "Default" },
        @{ ID = 20; Name = "LAN2" }
    )

    Interfaces = @(
        @{ Name = "GigabitEthernet0/1"; Mode = "access"; VLAN = 20; TrunkAllowed = @(); Description = "H4"; Status = "up" },
        @{ Name = "GigabitEthernet0/2"; Mode = "access"; VLAN = 20; TrunkAllowed = @(); Description = "H5"; Status = "up" },
        @{ Name = "GigabitEthernet0/24"; Mode = "trunk"; VLAN = 0; TrunkAllowed = @(20); Description = "Uplink to R2"; Status = "up" }
    )

    EtherChannel = @{ Enabled = $false; ID = 1; Mode = "active"; Interfaces = @() }

    SVIs = @(
        @{ VLAN = 20; IP = "10.0.1.253"; Mask = "255.255.255.0" }
    )

    ACLs = @()
    STP  = @{ Mode = "pvst"; Priority = 32768 }
    DHCPRelay = @{ Enabled = $true; RelayIPs = @("10.0.0.1") }  # still relay to R1 DHCP
    Logging   = @{ Enabled = $true; Host = "192.168.100.20" }
}
