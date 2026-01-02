<#
.SYNOPSIS
    Pester tests for deviceValidator.ps1

.DESCRIPTION
    Unit tests for device validation functions:
    - Test-ValidIP
    - Validate-Router
    - Validate-Switch
    - Validate-Device
    - Validate-AllDevices
#>

BeforeAll {
    # Import the module
    $modulePath = Join-Path $PSScriptRoot '..' 'NetDeploy.psd1'
    Import-Module $modulePath -Force
    
    # Dot-source private functions for direct testing
    . (Join-Path $PSScriptRoot '..' 'Private' 'Utils.ps1')
    . (Join-Path $PSScriptRoot '..' 'Private' 'deviceValidator.ps1')
}

Describe "Test-ValidIP" {
    Context "Geldige IP adressen" {
        It "Accepteert 192.168.1.1" {
            Test-ValidIP -IP "192.168.1.1" | Should -BeTrue
        }

        It "Accepteert 10.0.0.1" {
            Test-ValidIP -IP "10.0.0.1" | Should -BeTrue
        }

        It "Accepteert 255.255.255.0" {
            Test-ValidIP -IP "255.255.255.0" | Should -BeTrue
        }

        It "Accepteert 0.0.0.0" {
            Test-ValidIP -IP "0.0.0.0" | Should -BeTrue
        }

        It "Accepteert 255.255.255.255" {
            Test-ValidIP -IP "255.255.255.255" | Should -BeTrue
        }
    }

    Context "Ongeldige IP adressen" {
        It "Weigert lege string" {
            Test-ValidIP -IP "" | Should -BeFalse
        }

        It "Weigert tekst" {
            Test-ValidIP -IP "invalid" | Should -BeFalse
        }

        It "Weigert 256.1.1.1 (octet > 255)" {
            Test-ValidIP -IP "256.1.1.1" | Should -BeFalse
        }

        It "Weigert 1.1.1.1.1 (te veel octets)" {
            Test-ValidIP -IP "1.1.1.1.1" | Should -BeFalse
        }

        It "Weigert negatieve getallen" {
            Test-ValidIP -IP "-1.0.0.1" | Should -BeFalse
        }
    }
}

Describe "Validate-Router" {
    Context "Geldige router configuratie" {
        BeforeAll {
            $script:validRouter = @{
                Hostname = "TestRouter"
                DeviceType = "Router"
                ManagementIP = "192.168.1.1"
                SSHPort = 22
                Credentials = @{
                    Username = "admin"
                    Password = "cisco"
                }
                Interfaces = @(
                    @{
                        Name = "GigabitEthernet0/0"
                        Description = "LAN"
                        IP = "192.168.1.1"
                        Mask = "255.255.255.0"
                        Status = "up"
                    }
                )
                Routing = @{
                    OSPF = @{ Enabled = $false }
                }
                DHCP = @{ Enabled = $false }
                DNS = @{ Enabled = $false }
                NAT = @{ Enabled = $false }
            }
        }

        It "Valideert zonder errors" {
            { Validate-Router -Device $validRouter } | Should -Not -Throw
        }
    }

    Context "Ongeldige router - geen interfaces" {
        BeforeAll {
            $script:noInterfaces = @{
                Hostname = "BadRouter"
                DeviceType = "Router"
                Interfaces = @()
                Routing = @{ OSPF = @{ Enabled = $false } }
            }
        }

        It "Gooit error bij geen interfaces" {
            { Validate-Router -Device $noInterfaces } | Should -Throw "*Must have at least one interface*"
        }
    }

    Context "Ongeldige router - interface zonder IP" {
        BeforeAll {
            $script:noIP = @{
                Hostname = "BadRouter"
                DeviceType = "Router"
                Interfaces = @(
                    @{
                        Name = "GigabitEthernet0/0"
                        Mask = "255.255.255.0"
                        Status = "up"
                    }
                )
                Routing = @{ OSPF = @{ Enabled = $false } }
            }
        }

        It "Gooit error bij ontbrekende IP" {
            { Validate-Router -Device $noIP } | Should -Throw
        }
    }

    Context "Ongeldige router - ongeldige IP" {
        BeforeAll {
            $script:invalidIP = @{
                Hostname = "BadRouter"
                DeviceType = "Router"
                Interfaces = @(
                    @{
                        Name = "GigabitEthernet0/0"
                        IP = "999.999.999.999"
                        Mask = "255.255.255.0"
                        Status = "up"
                    }
                )
                Routing = @{ OSPF = @{ Enabled = $false } }
            }
        }

        It "Gooit error bij ongeldige IP" {
            { Validate-Router -Device $invalidIP } | Should -Throw "*invalid IP*"
        }
    }

    Context "Router met OSPF validatie" {
        BeforeAll {
            $script:ospfRouter = @{
                Hostname = "OSPFRouter"
                DeviceType = "Router"
                Interfaces = @(
                    @{ Name = "Gi0/0"; IP = "10.0.0.1"; Mask = "255.255.255.0"; Status = "up" }
                )
                Routing = @{
                    OSPF = @{
                        Enabled = $true
                        ProcessID = 1
                        Networks = @(
                            @{ Network = "10.0.0.0"; Mask = "255.255.255.0"; Area = 0 }
                        )
                    }
                }
                DHCP = @{ Enabled = $false }
                DNS = @{ Enabled = $false }
                NAT = @{ Enabled = $false }
            }
        }

        It "Valideert OSPF configuratie" {
            { Validate-Router -Device $ospfRouter } | Should -Not -Throw
        }
    }

    Context "Router met ongeldige OSPF" {
        BeforeAll {
            $script:badOSPF = @{
                Hostname = "BadOSPF"
                DeviceType = "Router"
                Interfaces = @(
                    @{ Name = "Gi0/0"; IP = "10.0.0.1"; Mask = "255.255.255.0"; Status = "up" }
                )
                Routing = @{
                    OSPF = @{
                        Enabled = $true
                        # Missing ProcessID
                        Networks = @()
                    }
                }
            }
        }

        It "Gooit error bij ontbrekende ProcessID" {
            { Validate-Router -Device $badOSPF } | Should -Throw
        }
    }
}

Describe "Validate-Switch" {
    Context "Geldige switch configuratie" {
        BeforeAll {
            $script:validSwitch = @{
                Hostname = "TestSwitch"
                DeviceType = "Switch"
                ManagementIP = "192.168.1.10"
                SSHPort = 22
                Credentials = @{
                    Username = "admin"
                    Password = "cisco"
                }
                VLANs = @(
                    @{ ID = 10; Name = "DATA" }
                    @{ ID = 20; Name = "VOICE" }
                )
                Ports = @(
                    @{
                        Name = "GigabitEthernet0/1"
                        Mode = "access"
                        VLAN = 10
                        Status = "up"
                    }
                )
                SVIs = @()
                Services = @{
                    AAA = @{ Enabled = $false }
                }
            }
        }

        It "Valideert zonder errors" {
            { Validate-Switch -Device $validSwitch } | Should -Not -Throw
        }
    }

    Context "Switch met trunk port" {
        BeforeAll {
            $script:trunkSwitch = @{
                Hostname = "TrunkSwitch"
                DeviceType = "Switch"
                VLANs = @(
                    @{ ID = 10; Name = "DATA" }
                )
                Ports = @(
                    @{
                        Name = "GigabitEthernet0/1"
                        Mode = "trunk"
                        AllowedVLANs = "10,20,30"
                        NativeVLAN = 1
                        Status = "up"
                    }
                )
                SVIs = @()
                Services = @{ AAA = @{ Enabled = $false } }
            }
        }

        It "Valideert trunk port configuratie" {
            { Validate-Switch -Device $trunkSwitch } | Should -Not -Throw
        }
    }
}

Describe "Validate-Device" {
    Context "Device type routing" {
        It "Roept Validate-Router aan voor Router type" {
            $router = @{
                Hostname = "R1"
                DeviceType = "Router"
                ManagementIP = "10.0.0.1"
                SSHPort = 22
                Credentials = @{ Username = "admin"; Password = "cisco" }
                Interfaces = @(@{ Name = "Gi0/0"; IP = "10.0.0.1"; Mask = "255.255.255.0"; Status = "up" })
                Routing = @{ OSPF = @{ Enabled = $false } }
                DHCP = @{ Enabled = $false }
                DNS = @{ Enabled = $false }
                NAT = @{ Enabled = $false }
            }
            
            { Validate-Device -Device $router } | Should -Not -Throw
        }

        It "Roept Validate-Switch aan voor Switch type" {
            $switch = @{
                Hostname = "S1"
                DeviceType = "Switch"
                ManagementIP = "10.0.0.2"
                SSHPort = 22
                Credentials = @{ Username = "admin"; Password = "cisco" }
                VLANs = @(@{ ID = 10; Name = "DATA" })
                Ports = @()
                SVIs = @()
                Services = @{ AAA = @{ Enabled = $false } }
            }
            
            { Validate-Device -Device $switch } | Should -Not -Throw
        }

        It "Gooit error voor onbekend device type" {
            $unknown = @{
                Hostname = "Unknown"
                DeviceType = "Firewall"
            }
            
            { Validate-Device -Device $unknown } | Should -Throw
        }
    }
}

Describe "Validate-AllDevices" {
    Context "Meerdere devices valideren" {
        BeforeAll {
            $script:deviceList = @(
                @{
                    Hostname = "R1"
                    DeviceType = "Router"
                    ManagementIP = "10.0.0.1"
                    SSHPort = 22
                    Credentials = @{ Username = "admin"; Password = "cisco" }
                    Interfaces = @(@{ Name = "Gi0/0"; IP = "10.0.0.1"; Mask = "255.255.255.0"; Status = "up" })
                    Routing = @{ OSPF = @{ Enabled = $false } }
                    DHCP = @{ Enabled = $false }
                    DNS = @{ Enabled = $false }
                    NAT = @{ Enabled = $false }
                },
                @{
                    Hostname = "S1"
                    DeviceType = "Switch"
                    ManagementIP = "10.0.0.2"
                    SSHPort = 22
                    Credentials = @{ Username = "admin"; Password = "cisco" }
                    VLANs = @(@{ ID = 10; Name = "DATA" })
                    Ports = @()
                    SVIs = @()
                    Services = @{ AAA = @{ Enabled = $false } }
                }
            )
        }

        It "Valideert alle devices zonder error" {
            { Validate-AllDevices -DeviceList $deviceList } | Should -Not -Throw
        }
    }

    Context "Stopt bij eerste fout" {
        BeforeAll {
            $script:mixedList = @(
                @{
                    Hostname = "R1"
                    DeviceType = "Router"
                    ManagementIP = "10.0.0.1"
                    SSHPort = 22
                    Credentials = @{ Username = "admin"; Password = "cisco" }
                    Interfaces = @(@{ Name = "Gi0/0"; IP = "10.0.0.1"; Mask = "255.255.255.0"; Status = "up" })
                    Routing = @{ OSPF = @{ Enabled = $false } }
                    DHCP = @{ Enabled = $false }
                    DNS = @{ Enabled = $false }
                    NAT = @{ Enabled = $false }
                },
                @{
                    Hostname = "BadRouter"
                    DeviceType = "Router"
                    ManagementIP = "10.0.0.99"
                    SSHPort = 22
                    Credentials = @{ Username = "admin"; Password = "cisco" }
                    Interfaces = @()  # Invalid - no interfaces
                    Routing = @{ OSPF = @{ Enabled = $false } }
                }
            )
        }

        It "Gooit error bij eerste ongeldige device" {
            { Validate-AllDevices -DeviceList $mixedList } | Should -Throw
        }
    }
}
