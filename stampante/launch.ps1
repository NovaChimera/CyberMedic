<#
.SYNOPSIS
    Launcher automatico con Auto-Elevazione Administrator per la suite IT.
.DESCRIPTION
    Avvia CyberMedic_GUI.ps1 (thin client) con i privilegi di Amministratore
    necessari allo svuotamento dello spooler e al riavvio del servizio di
    stampa. Se lo script non e' gia' elevato, si rilancia con -Verb RunAs
    (prompt UAC) e termina.
    Il launcher seleziona pwsh.exe (PowerShell 7) quando disponibile, altrimenti
    ripiega su Windows PowerShell 5.1.
    Il thin client carica a sua volta il backend CyberMedic_Core.ps1.

    L'identita' del prodotto (nome, versione, edizione) e' definita in
    product.psd1, accanto a questo file: per cambiarla basta modificare quel
    file, oppure passare -ProductName / -ProductVersion che hanno la
    precedenza e valgono solo per l'avvio corrente.
.EXAMPLE
    .\launch.ps1
.EXAMPLE
    .\launch.ps1 -PrinterName "HP LaserJet"
.EXAMPLE
    .\launch.ps1 -SelfTest
.EXAMPLE
    .\launch.ps1 -ProductName "CyberMedic" -ProductVersion "3.0.0"
#>

[CmdletBinding()]
param(
    [string]$PrinterName,
    [string]$LogDirectory,
    [switch]$SelfTest,
    [switch]$Diagnose,
    [switch]$SmokeTest,
    [string]$ResolvePort,
    [string]$ResolvePrinter = '',
    [string]$ProductName = '',
    [string]$ProductVersion = ''
)

$ErrorActionPreference = 'Stop'

function Get-ShellPath {
    $pwsh = Join-Path -Path $PSHOME -ChildPath 'pwsh.exe'
    if (Test-Path -LiteralPath $pwsh) { return $pwsh }
    return (Join-Path -Path $PSHOME -ChildPath 'powershell.exe')
}

function Get-ForwardedArguments {
    param(
        [string]$InPrinterName,
        [string]$InLogDirectory,
        [switch]$InSelfTest,
        [switch]$InDiagnose,
        [switch]$InSmokeTest,
        [string]$InResolvePort,
        [string]$InResolvePrinter,
        [switch]$IncludeResolvePort,
        [string]$InProductName,
        [string]$InProductVersion
    )
    $forwarded = @()
    if ($InPrinterName) { $forwarded += @('-PrinterName', ('"{0}"' -f $InPrinterName)) }
    if ($InLogDirectory) { $forwarded += @('-LogDirectory', ('"{0}"' -f $InLogDirectory)) }
    if ($InSelfTest) { $forwarded += '-SelfTest' }
    if ($InDiagnose) { $forwarded += '-Diagnose' }
    if ($InSmokeTest) { $forwarded += '-SmokeTest' }
    if ($InProductName) { $forwarded += @('-ProductName', ('"{0}"' -f $InProductName)) }
    if ($InProductVersion) { $forwarded += @('-ProductVersion', ('"{0}"' -f $InProductVersion)) }
    if ($IncludeResolvePort) {
        $forwarded += @('-ResolvePort', ('"{0}"' -f $InResolvePort))
        if ($InResolvePrinter) { $forwarded += @('-ResolvePrinter', ('"{0}"' -f $InResolvePrinter)) }
    }
    return $forwarded
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$forwarded = Get-ForwardedArguments -InPrinterName $PrinterName -InLogDirectory $LogDirectory -InSelfTest:$SelfTest -InDiagnose:$Diagnose -InSmokeTest:$SmokeTest -InResolvePort $ResolvePort -InResolvePrinter $ResolvePrinter -IncludeResolvePort:($PSBoundParameters.ContainsKey('ResolvePort')) -InProductName $ProductName -InProductVersion $ProductVersion

if (-not $isAdmin) {
    Write-Host "Elevazione dei privilegi di Amministratore richiesta..." -ForegroundColor Yellow
    $shell = Get-ShellPath
    $argumentList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', ('"{0}"' -f $PSCommandPath)) + $forwarded
    try {
        Start-Process -FilePath $shell -ArgumentList $argumentList -Verb RunAs -WorkingDirectory $PSScriptRoot | Out-Null
        exit 0
    } catch {
        Write-Host "Elevazione non riuscita: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

$scriptPath = Join-Path -Path $PSScriptRoot -ChildPath 'CyberMedic_GUI.ps1'
if (-not (Test-Path -LiteralPath $scriptPath)) {
    Write-Host "Impossibile trovare il file CyberMedic_GUI.ps1 in $PSScriptRoot" -ForegroundColor Red
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [void][System.Windows.Forms.MessageBox]::Show("Impossibile trovare il file CyberMedic_GUI.ps1 in $PSScriptRoot", "Errore Critico", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    } catch {
        Write-Host "Errore critico: $($_.Exception.Message)" -ForegroundColor Red
    }
    exit 1
}

$shell = Get-ShellPath
$appArguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', ('"{0}"' -f $scriptPath)) + $forwarded

& $shell @appArguments
exit $LASTEXITCODE
