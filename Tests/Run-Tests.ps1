<#
.SYNOPSIS
    Runs all Pester tests for NetDeploy module.

.DESCRIPTION
    Executes all .Tests.ps1 files in the Tests directory using Pester.
    Generates both console output and optional test results file.

.EXAMPLE
    ./Run-Tests.ps1
    
    Runs all tests with default settings.

.EXAMPLE
    ./Run-Tests.ps1 -Detailed
    
    Runs tests with detailed output.

.EXAMPLE
    ./Run-Tests.ps1 -Output "TestResults.xml"
    
    Runs tests and exports results to XML file.
#>

param(
    [switch]$Detailed,
    [string]$Output
)

$ErrorActionPreference = 'Stop'

# Check if Pester is installed
$pester = Get-Module -ListAvailable -Name Pester | Sort-Object Version -Descending | Select-Object -First 1
if (-not $pester -or $pester.Version -lt [Version]"5.0.0") {
    Write-Host "Pester 5.0+ is required. Installing..." -ForegroundColor Yellow
    Install-Module -Name Pester -MinimumVersion 5.0.0 -Scope CurrentUser -Force -SkipPublisherCheck
}

Import-Module Pester -MinimumVersion 5.0.0

# Configuration
$config = New-PesterConfiguration
$config.Run.Path = $PSScriptRoot
$config.Run.Exit = $false

if ($Detailed) {
    $config.Output.Verbosity = 'Detailed'
} else {
    $config.Output.Verbosity = 'Normal'
}

if ($Output) {
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputPath = $Output
    $config.TestResult.OutputFormat = 'NUnitXml'
}

# Display header
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║              NetDeploy - Pester Test Suite                   ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Run tests
$results = Invoke-Pester -Configuration $config

# Summary
Write-Host ""
Write-Host "══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "TEST RESULTS SUMMARY" -ForegroundColor Cyan
Write-Host "══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Total:    $($results.TotalCount)" -ForegroundColor White
Write-Host "  Passed:   $($results.PassedCount)" -ForegroundColor Green
Write-Host "  Failed:   $($results.FailedCount)" -ForegroundColor $(if ($results.FailedCount -gt 0) { 'Red' } else { 'Green' })
Write-Host "  Skipped:  $($results.SkippedCount)" -ForegroundColor Yellow
Write-Host "  Duration: $([math]::Round($results.Duration.TotalSeconds, 2))s" -ForegroundColor White
Write-Host ""

if ($results.FailedCount -gt 0) {
    Write-Host "Some tests failed!" -ForegroundColor Red
    exit 1
} else {
    Write-Host "All tests passed!" -ForegroundColor Green
    exit 0
}
