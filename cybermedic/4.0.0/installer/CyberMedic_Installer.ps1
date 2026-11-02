#Requires -Version 5.1
<#
.SYNOPSIS
    CyberMedic - Installer (portable o installata).
.DESCRIPTION
    Offre la scelta tra due modalita' di distribuzione:
      - Portabile: copia i file in una cartella scelta dall'utente, nessuna
        modifica al sistema, nessuna voce nel registro. Avvio tramite
        launch.ps1 o CyberMedic_GUI.ps1.
      - Installata: copia in %ProgramFiles%\CyberMedic, crea collegamenti nel
        menu Start e registra una voce di disinstallazione in
        HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall.
    Nessuna dipendenza esterna: e' uno script PowerShell, come il prodotto.
.PARAMETER Mode
    'Portable' o 'Installed'. Se omesso viene chiesto interattivamente.
.PARAMETER Destination
    Cartella di destinazione (portable) o di installazione (installed).
.PARAMETER Source
    Cartella sorgente con i file di CyberMedic. Default: cartella dello script.
#>
[CmdletBinding()]
param(
    [ValidateSet('Portable','Installed','')]
    [string]$Mode = '',
    [string]$Destination = '',
    [string]$Source = ''
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Source)) {
    # Default: la cartella padre dell'installer (root della repository/app)
    $Source = Split-Path -Path $PSScriptRoot -Parent
    if ([string]::IsNullOrWhiteSpace($Source) -or -not (Test-Path -LiteralPath (Join-Path $Source 'CyberMedic_GUI.ps1'))) {
        $Source = (Get-Location).Path
    }
}

$AppName = 'CyberMedic'
$AppVersion = '3.0.1'

function Write-Info($m) { Write-Host $m -ForegroundColor Cyan }
function Write-Ok($m) { Write-Host $m -ForegroundColor Green }
function Write-Warn($m) { Write-Host $m -ForegroundColor Yellow }
function Write-Err($m) { Write-Host $m -ForegroundColor Red }

function Test-Source {
    $required = @('CyberMedic_GUI.ps1','CyberMedic_Core.ps1','launch.ps1','product.psd1','core','gui')
    foreach ($item in $required) {
        $p = Join-Path -Path $Source -ChildPath $item
        if (-not (Test-Path -LiteralPath $p)) {
            Write-Err "Sorgente non valida: manca '$item' in '$Source'."
            return $false
        }
    }
    return $true
}

function Copy-AppFiles {
    param([string]$Dst)
    New-Item -ItemType Directory -Path $Dst -Force | Out-Null
    $items = @('CyberMedic_GUI.ps1','CyberMedic_Core.ps1','launch.ps1','product.psd1','README.md','RELEASE_NOTES.md','core','gui')
    foreach ($item in $items) {
        $src = Join-Path -Path $Source -ChildPath $item
        $dest = Join-Path -Path $Dst -ChildPath $item
        if (Test-Path -LiteralPath $src -PathType Container) {
            if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
            Copy-Item -LiteralPath $src -Destination $dest -Recurse -Force
        } else {
            Copy-Item -LiteralPath $src -Destination $dest -Force
        }
    }
    # Rimuove il file orfano della vecchia scheda, se presente.
    $orphan = Join-Path -Path $Dst -ChildPath 'gui\tabs\cybermedic.ps1'
    if (Test-Path -LiteralPath $orphan) { Remove-Item -LiteralPath $orphan -Force }
    Write-Ok "File copiati in '$Dst'."
}

function Install-Portable {
    param([string]$Dst)
    Write-Info "Modalita' portabile: copia dei file senza modifiche al sistema."
    Copy-AppFiles -Dst $Dst
    $launcher = Join-Path -Path $Dst -ChildPath 'launch.ps1'
    Write-Ok "Installazione portabile completata."
    Write-Info "Avvio: & '$launcher'"
    Write-Info "Oppure: & (Join-Path '$Dst' 'CyberMedic_GUI.ps1') -SelfTest"
}

function Install-Installed {
    param([string]$Dst)
    Write-Info "Modalita' installata: copia in '$Dst' con collegamenti e disinstallazione."
    if (-not (Test-Path -LiteralPath $Dst)) { New-Item -ItemType Directory -Path $Dst -Force | Out-Null }
    Copy-AppFiles -Dst $Dst

    # Collegamento nel menu Start
    $startMenu = Join-Path -Path $env:APPDATA -ChildPath 'Microsoft\Windows\Start Menu\Programs'
    $shortcutPath = Join-Path -Path $startMenu -ChildPath "$AppName.lnk"
    try {
        $wsh = New-Object -ComObject WScript.Shell
        $sc = $wsh.CreateShortcut($shortcutPath)
        $sc.TargetPath = (Join-Path -Path $Dst -ChildPath 'launch.ps1')
        $sc.WorkingDirectory = $Dst
        $sc.Description = "$AppName v$AppVersion - Enterprise IT Helpdesk Suite"
        $sc.IconLocation = (Join-Path -Path $Dst -ChildPath 'CyberMedic_GUI.ps1') + ',0'
        $sc.Save()
        Write-Ok "Collegamento creato in '$shortcutPath'."
    } catch {
        Write-Warn "Collegamento nel menu Start non creato: $($_.Exception.Message)"
    }

    # Voce di disinstallazione nel registro
    $uninstallKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$AppName"
    try {
        if (-not (Test-Path -LiteralPath $uninstallKey)) {
            New-Item -Path $uninstallKey -Force | Out-Null
        }
        $uninstallCmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$Dst\uninstall.ps1`""
        Set-ItemProperty -Path $uninstallKey -Name 'DisplayName' -Value "$AppName v$AppVersion"
        Set-ItemProperty -Path $uninstallKey -Name 'DisplayVersion' -Value $AppVersion
        Set-ItemProperty -Path $uninstallKey -Name 'Publisher' -Value 'CyberMedic'
        Set-ItemProperty -Path $uninstallKey -Name 'InstallLocation' -Value $Dst
        Set-ItemProperty -Path $uninstallKey -Name 'UninstallString' -Value $uninstallCmd
        Write-Ok "Voce di disinstallazione registrata."
    } catch {
        Write-Warn "Voce di disinstallazione non registrata (richiede privilegi elevati): $($_.Exception.Message)"
    }

    # Genera uninstall.ps1
    $uninstallScript = @'
# CyberMedic - Disinstallazione
$ErrorActionPreference = 'Continue'
$target = '__DST__'
$startMenu = Join-Path -Path $env:APPDATA -ChildPath 'Microsoft\Windows\Start Menu\Programs'
$shortcut = Join-Path -Path $startMenu -ChildPath '__APPNAME__.lnk'
if (Test-Path -LiteralPath $shortcut) { Remove-Item -LiteralPath $shortcut -Force }
$uninstallKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\__APPNAME__"
if (Test-Path -LiteralPath $uninstallKey) { Remove-Item -LiteralPath $uninstallKey -Recurse -Force }
if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
Write-Host '__APPNAME__ disinstallato.'
'@
    $uninstallScript = $uninstallScript.Replace('__DST__', $Dst).Replace('__APPNAME__', $AppName)
    $uninstallPath = Join-Path -Path $Dst -ChildPath 'uninstall.ps1'
    Set-Content -LiteralPath $uninstallPath -Value $uninstallScript -Encoding UTF8
    Write-Ok "Script di disinstallazione creato: $uninstallPath"
    Write-Ok "Installazione completata."
    Write-Info "Avvio: menu Start -> $AppName, oppure & (Join-Path '$Dst' 'launch.ps1')"
}

# ---- Main ----

if (-not (Test-Source)) { exit 1 }

Write-Host ''
Write-Host "CyberMedic $AppVersion - Installer" -ForegroundColor Magenta
Write-Host ''

if ([string]::IsNullOrWhiteSpace($Mode)) {
    Write-Host 'Scegli la modalita di installazione:' -ForegroundColor White
    Write-Host '  [P] Portabile  - copia i file in una cartella, nessuna modifica al sistema'
    Write-Host '  [I] Installata - installazione in Program Files, menu Start, disinstallazione'
    Write-Host '  [Q] Annulla'
    $choice = Read-Host 'Scelta (P/I/Q)'
    switch ($choice.ToUpper()) {
        'P' { $Mode = 'Portable' }
        'I' { $Mode = 'Installed' }
        default { Write-Warn 'Annullato.'; exit 0 }
    }
}

if ([string]::IsNullOrWhiteSpace($Destination)) {
    if ($Mode -eq 'Portable') {
        $default = Join-Path -Path $env:USERPROFILE -ChildPath 'Desktop\CyberMedic-Portable'
        $Destination = Read-Host "Cartella di destinazione [default: $default]"
        if ([string]::IsNullOrWhiteSpace($Destination)) { $Destination = $default }
    } else {
        $default = Join-Path -Path $env:ProgramFiles -ChildPath $AppName
        $Destination = Read-Host "Cartella di installazione [default: $default]"
        if ([string]::IsNullOrWhiteSpace($Destination)) { $Destination = $default }
    }
}

switch ($Mode) {
    'Portable' { Install-Portable -Dst $Destination }
    'Installed' { Install-Installed -Dst $Destination }
    default { Write-Err "Modalita' non riconosciuta: $Mode"; exit 1 }
}
