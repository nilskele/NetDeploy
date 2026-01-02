<#
.SYNOPSIS
    Pester tests for DeviceLoader.ps1

.DESCRIPTION
    Unit tests for device loading functions:
    - Load-AllDevicesFromJson
    - Load-Devices (public API)
    - Convert-PSObjectToHashtable
#>

BeforeAll {
    # Import the module
    $modulePath = Join-Path $PSScriptRoot '..' 'NetDeploy.psd1'
    Import-Module $modulePath -Force
    
    # Create test data directory
    $script:testDataDir = Join-Path $PSScriptRoot 'TestData'
    if (-not (Test-Path $testDataDir)) {
        New-Item -ItemType Directory -Path $testDataDir -Force | Out-Null
    }
}

AfterAll {
    # Cleanup test data
    if (Test-Path $script:testDataDir) {
        Remove-Item $script:testDataDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "Load-Devices" {
    Context "JSON bestand laden" {
        BeforeAll {
            # Create test JSON file
            $testJson = @"
[
    {
        "Hostname": "TestRouter1",
        "DeviceType": "Router",
        "ManagementIP": "192.168.1.1",
        "SSHPort": 22,
        "Credentials": {
            "Username": "admin",
            "Password": "cisco"
        },
        "Interfaces": [
            {
                "Name": "GigabitEthernet0/0",
                "IP": "10.0.0.1",
                "Mask": "255.255.255.0",
                "Status": "up"
            }
        ],
        "Routing": {
            "OSPF": { "Enabled": false }
        }
    },
    {
        "Hostname": "TestSwitch1",
        "DeviceType": "Switch",
        "ManagementIP": "192.168.1.2",
        "SSHPort": 22,
        "Credentials": {
            "Username": "admin",
            "Password": "cisco"
        },
        "VLANs": [
            { "ID": 10, "Name": "DATA" }
        ],
        "Ports": [],
        "SVIs": []
    }
]
"@
            $script:testJsonPath = Join-Path $script:testDataDir 'devices.json'
            $testJson | Out-File -FilePath $testJsonPath -Encoding UTF8
        }

        It "Laadt devices uit JSON bestand" {
            $devices = Load-Devices -Path $testJsonPath
            $devices | Should -Not -BeNullOrEmpty
        }

        It "Retourneert correct aantal devices" {
            $devices = Load-Devices -Path $testJsonPath
            $devices.Count | Should -Be 2
        }

        It "Parsed hostname correct" {
            $devices = Load-Devices -Path $testJsonPath
            $devices[0].Hostname | Should -Be "TestRouter1"
            $devices[1].Hostname | Should -Be "TestSwitch1"
        }

        It "Parsed DeviceType correct" {
            $devices = Load-Devices -Path $testJsonPath
            $devices[0].DeviceType | Should -Be "Router"
            $devices[1].DeviceType | Should -Be "Switch"
        }

        It "Parsed ManagementIP correct" {
            $devices = Load-Devices -Path $testJsonPath
            $devices[0].ManagementIP | Should -Be "192.168.1.1"
        }

        It "Parsed Credentials correct" {
            $devices = Load-Devices -Path $testJsonPath
            $devices[0].Credentials.Username | Should -Be "admin"
            $devices[0].Credentials.Password | Should -Be "cisco"
        }

        It "Parsed Interfaces correct" {
            $devices = Load-Devices -Path $testJsonPath
            $devices[0].Interfaces.Count | Should -Be 1
            $devices[0].Interfaces[0].Name | Should -Be "GigabitEthernet0/0"
        }
    }

    Context "Directory met devices.json" {
        BeforeAll {
            # devices.json already created in previous context
            $script:testDir = $script:testDataDir
        }

        It "Vindt devices.json in directory" {
            $devices = Load-Devices -Path $testDir
            $devices | Should -Not -BeNullOrEmpty
        }

        It "Laadt alle devices uit directory" {
            $devices = Load-Devices -Path $testDir
            $devices.Count | Should -BeGreaterOrEqual 1
        }
    }

    Context "Error handling" {
        It "Geeft error bij niet-bestaand pad" {
            { Load-Devices -Path "/nonexistent/path/devices.json" } | Should -Throw
        }

        It "Geeft error bij ongeldig JSON" {
            $invalidJson = "{ invalid json }"
            $invalidPath = Join-Path $script:testDataDir 'invalid.json'
            $invalidJson | Out-File -FilePath $invalidPath -Encoding UTF8
            
            { Load-Devices -Path $invalidPath } | Should -Throw
        }
    }
}

Describe "Device object structuur" {
    Context "Router object eigenschappen" {
        BeforeAll {
            $testJson = @"
[
    {
        "Hostname": "R1",
        "DeviceType": "Router",
        "ManagementIP": "10.0.0.1",
        "SSHPort": 22,
        "Credentials": { "Username": "admin", "Password": "pass" },
        "Interfaces": [{ "Name": "Gi0/0", "IP": "10.0.0.1", "Mask": "255.255.255.0", "Status": "up" }],
        "Routing": { "OSPF": { "Enabled": true, "ProcessID": 1, "Networks": [] } }
    }
]
"@
            $jsonPath = Join-Path $script:testDataDir 'router.json'
            $testJson | Out-File -FilePath $jsonPath -Encoding UTF8
            $script:testRouters = Load-Devices -Path $jsonPath
        }

        It "Heeft Hostname property" {
            $testRouters[0].Hostname | Should -Not -BeNullOrEmpty
        }

        It "Heeft DeviceType property" {
            $testRouters[0].DeviceType | Should -Be "Router"
        }

        It "Heeft ManagementIP property" {
            $testRouters[0].ManagementIP | Should -Not -BeNullOrEmpty
        }

        It "Heeft SSHPort property" {
            $testRouters[0].SSHPort | Should -Be 22
        }

        It "Heeft Credentials object" {
            $testRouters[0].Credentials | Should -Not -BeNullOrEmpty
            $testRouters[0].Credentials.Username | Should -Not -BeNullOrEmpty
        }

        It "Heeft Interfaces collectie" {
            $testRouters[0].Interfaces | Should -Not -BeNullOrEmpty
            $testRouters[0].Interfaces.Count | Should -BeGreaterOrEqual 1
        }

        It "Heeft Routing object" {
            $testRouters[0].Routing | Should -Not -BeNullOrEmpty
        }
    }
}
