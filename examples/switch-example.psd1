@{
    Hostname     = "Switch1"
    DeviceType   = "Switch"
    ManagementIP = "192.168.1.11"
    SSHPort      = 22

    Credentials = @{
        Username = "admin"
        Password = "password"
    }

    VLANs = @(
        @{ ID=1; Name="Default" },
        @{ ID=10; Name="Users" }
    )

    Interfaces = @(
        @{ Name="G1/0"; Mode="access"; VLAN=10; Description="Example PC"; Status="up"; TrunkAllowed=@() },
        @{ Name="G1/1"; Mode="trunk"; VLAN=1; Description="Uplink Router"; Status="up"; TrunkAllowed=@("1","10") }
    )

    EtherChannel = @{ Enabled=$false; ID=1; Mode="active"; Interfaces=@() }
    SVIs = @()
    ACLs=@()
    STP=@{ Mode="pvst"; Priority=32768 }
    DHCPRelay=@{ Enabled=$false; RelayIPs=@() }
}
