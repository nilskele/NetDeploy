<#
.SYNOPSIS
    Pester tests for CommandBuilder.ps1

.DESCRIPTION
    Unit tests for command generation functions:
    - Convert-ToWildcard
    - Prefix-FromMask
    - Build-RouterCommands
    - Build-SwitchCommands
    - Build-Commands
#>

BeforeAll {
    # Import the module
    $modulePath = Join-Path $PSScriptRoot '..' 'NetDeploy.psd1'
    Import-Module $modulePath -Force
    
    # Also dot-source the private functions for direct testing
    . (Join-Path $PSScriptRoot '..' 'Private' 'Utils.ps1')
    . (Join-Path $PSScriptRoot '..' 'Private' 'CommandBuilder.ps1')
}

Describe "Convert-ToWildcard" {
    Context "Standaard subnet masks" {
        It "Converteert /24 mask (255.255.255.0) naar 0.0.0.255" {
            $result = Convert-ToWildcard -Mask "255.255.255.0"
            $result | Should -Be "0.0.0.255"
        }

        It "Converteert /30 mask (255.255.255.252) naar 0.0.0.3" {
            $result = Convert-ToWildcard -Mask "255.255.255.252"
            $result | Should -Be "0.0.0.3"
        }

        It "Converteert /16 mask (255.255.0.0) naar 0.0.255.255" {
            $result = Convert-ToWildcard -Mask "255.255.0.0"
            $result | Should -Be "0.0.255.255"
        }

        It "Converteert /32 mask (255.255.255.255) naar 0.0.0.0" {
            $result = Convert-ToWildcard -Mask "255.255.255.255"
            $result | Should -Be "0.0.0.0"
        }

        It "Converteert /0 mask (0.0.0.0) naar 255.255.255.255" {
            $result = Convert-ToWildcard -Mask "0.0.0.0"
            $result | Should -Be "255.255.255.255"
        }

        It "Converteert /25 mask (255.255.255.128) naar 0.0.0.127" {
            $result = Convert-ToWildcard -Mask "255.255.255.128"
            $result | Should -Be "0.0.0.127"
        }
    }
}

Describe "Prefix-FromMask" {
    Context "CIDR prefix berekening" {
        It "Berekent /24 van 255.255.255.0" {
            $result = Prefix-FromMask -Mask "255.255.255.0"
            $result | Should -Be 24
        }

        It "Berekent /30 van 255.255.255.252" {
            $result = Prefix-FromMask -Mask "255.255.255.252"
            $result | Should -Be 30
        }

        It "Berekent /16 van 255.255.0.0" {
            $result = Prefix-FromMask -Mask "255.255.0.0"
            $result | Should -Be 16
        }

        It "Berekent /8 van 255.0.0.0" {
            $result = Prefix-FromMask -Mask "255.0.0.0"
            $result | Should -Be 8
        }

        It "Berekent /32 van 255.255.255.255" {
            $result = Prefix-FromMask -Mask "255.255.255.255"
            $result | Should -Be 32
        }
    }
}

Describe "Build-RouterCommands" {
    Context "Basis router configuratie" {
        BeforeAll {
            $testRouter = @{
                Hostname = "TestRouter"
                DeviceType = "Router"
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
                Services = @{
                    AAA = @{ Enabled = $false }
                }
            }
        }

        It "Genereert enable command" {
            $commands = Build-RouterCommands -Config $testRouter
            $commands | Should -Contain "enable"
        }

        It "Genereert configure terminal command" {
            $commands = Build-RouterCommands -Config $testRouter
            $commands | Should -Contain "configure terminal"
        }

        It "Genereert hostname command" {
            $commands = Build-RouterCommands -Config $testRouter
            $commands | Should -Contain "hostname TestRouter"
        }

        It "Genereert interface commands" {
            $commands = Build-RouterCommands -Config $testRouter
            $commands | Should -Contain "interface GigabitEthernet0/0"
            $commands | Should -Contain " ip address 192.168.1.1 255.255.255.0"
            $commands | Should -Contain " no shutdown"
        }

        It "Eindigt met write memory" {
            $commands = Build-RouterCommands -Config $testRouter
            $commands[-1] | Should -Be "write memory"
        }
    }

    Context "Router met OSPF" {
        BeforeAll {
            $testRouterOSPF = @{
                Hostname = "OSPFRouter"
                DeviceType = "Router"
                Interfaces = @(
                    @{
                        Name = "GigabitEthernet0/0"
                        IP = "10.0.0.1"
                        Mask = "255.255.255.252"
                        Status = "up"
                    }
                )
                Routing = @{
                    OSPF = @{
                        Enabled = $true
                        ProcessID = 1
                        RouterID = "1.1.1.1"
                        Networks = @(
                            @{
                                Network = "10.0.0.0"
                                Mask = "255.255.255.252"
                                Area = 0
                            }
                        )
                    }
                }
                Services = @{
                    AAA = @{ Enabled = $false }
                }
            }
        }

        It "Genereert router ospf command" {
            $commands = Build-RouterCommands -Config $testRouterOSPF
            $commands | Should -Contain "router ospf 1"
        }

        It "Genereert OSPF network met wildcard mask" {
            $commands = Build-RouterCommands -Config $testRouterOSPF
            # 255.255.255.252 -> wildcard 0.0.0.3
            $commands | Should -Contain "network 10.0.0.0 0.0.0.3 area 0"
        }

        It "Genereert router-id als opgegeven" {
            $commands = Build-RouterCommands -Config $testRouterOSPF
            $commands | Should -Contain "router-id 1.1.1.1"
        }
    }

    Context "Router met AAA users" {
        BeforeAll {
            $testRouterAAA = @{
                Hostname = "AAARouter"
                DeviceType = "Router"
                Interfaces = @(
                    @{ Name = "Gi0/0"; IP = "10.0.0.1"; Mask = "255.255.255.0"; Status = "up" }
                )
                Routing = @{ OSPF = @{ Enabled = $false } }
                Services = @{
                    AAA = @{
                        Enabled = $true
                        Users = @(
                            @{ Username = "admin"; Password = "cisco"; Privilege = 15 }
                        )
                    }
                }
            }
        }

        It "Genereert aaa new-model" {
            $commands = Build-RouterCommands -Config $testRouterAAA
            $commands | Should -Contain "aaa new-model"
        }

        It "Genereert username command met privilege" {
            $commands = Build-RouterCommands -Config $testRouterAAA
            $commands | Should -Contain "username admin privilege 15 secret cisco"
        }
    }
}

Describe "Build-Commands" {
    Context "Device type routing" {
        It "Roept Build-RouterCommands aan voor Router type" {
            $router = @{
                Hostname = "R1"
                DeviceType = "Router"
                Interfaces = @(@{ Name = "Gi0/0"; IP = "10.0.0.1"; Mask = "255.255.255.0"; Status = "up" })
                Routing = @{ OSPF = @{ Enabled = $false } }
                Services = @{ AAA = @{ Enabled = $false } }
            }
            
            $commands = Build-Commands -Device $router
            $commands | Should -Contain "hostname R1"
        }

        It "Roept Build-SwitchCommands aan voor Switch type" {
            $switch = @{
                Hostname = "S1"
                DeviceType = "Switch"
                VLANs = @(@{ ID = 10; Name = "DATA" })
                Ports = @()
                SVIs = @()
                Services = @{ AAA = @{ Enabled = $false } }
            }
            
            $commands = Build-Commands -Device $switch
            $commands | Should -Contain "hostname S1"
        }
    }
}
