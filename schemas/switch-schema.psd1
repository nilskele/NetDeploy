@{
    Hostname     = ""
    DeviceType   = "Switch"
    ManagementIP = ""
    SSHPort      = 22

    Credentials = @{
        Username = ""
        Password = ""
    }

    # VLANs
    VLANs = @(
        @{ ID = 1; Name = "Default" }
    )

    # Interfaces
    Interfaces = @(
        @{
            Name = ""
            Mode = "access"      # access | trunk | routed
            VLAN = 1
            TrunkAllowed = @()   # Only for trunk ports
            Description = ""
            Status = "up"
        }
    )

    # EtherChannel
    EtherChannel = @{
        Enabled    = $false
        ID         = 1
        Mode       = "active"     # active | passive | on
        Interfaces = @()
    }

    # Layer 3 SVIs
    SVIs = @(
        @{
            VLAN = 1
            IP   = ""
            Mask = ""
        }
    )

    # Optional extras
    ACLs = @()
    STP  = @{ Mode = "pvst"; Priority = 32768 }
    DHCPRelay = @{ Enabled = $false; RelayIPs = @() }
    Logging   = @{ Enabled = $false; Host = "" }
}
