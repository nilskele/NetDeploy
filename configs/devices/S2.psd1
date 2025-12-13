@{
    Hostname="SW2"
    DeviceType="Switch"
    ManagementIP="192.168.1.12"
    SSHPort=22

    Credentials=@{ Username="admin"; Password="admin123" }

    VLANs=@(@{ ID=1; Name="Default" }, @{ ID=20; Name="Servers" })
    Interfaces=@(
        @{ Name="G1/0"; Mode="access"; VLAN=20; Description="SRV1"; Status="up"; TrunkAllowed=@() },
        @{ Name="G1/1"; Mode="trunk"; VLAN=1; Description="Uplink to R2"; Status="up"; TrunkAllowed=@("1","20") }
    )
    EtherChannel=@{ Enabled=$false; ID=1; Mode="active"; Interfaces=@() }
    SVIs=@()
    ACLs=@()
    STP=@{ Mode="pvst"; Priority=32768 }
    DHCPRelay=@{ Enabled=$false; RelayIPs=@() }
}
