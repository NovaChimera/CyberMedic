#Requires -Version 7.0
<#
.SYNOPSIS
    CyberMedic v4.5 - Launcher unificato con grafica v4.0 e funzioni aggiuntive da v3.0.1.
.DESCRIPTION
    Avvia CyberMedic v4.5 con privilegi di Amministratore, usa il tema Fluent di v4.0,
    carica CyberMedic_GUI.ps1 di v4.0 e aggiunge le schede modulari extra di v3.0.1
    (Task Manager, Mail, Maintenance, Cybersecurity).
#>

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

try { [void][System.Windows.Forms.Application]::SetHighDpiMode([System.Windows.Forms.HighDpiMode]::SystemAware) } catch {}
try { [System.Windows.Forms.Application]::EnableVisualStyles() } catch {}
try { [System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false) } catch {}

$ScriptPath = if ($MyInvocation.MyCommand.Path) { $MyInvocation.MyCommand.Path } else { $PSCommandPath }
$CurrentDir = [System.IO.Path]::GetDirectoryName($ScriptPath)
$RootDir = $CurrentDir

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    [System.Windows.Forms.MessageBox]::Show("CyberMedic v4.5 richiede privilegi di Amministratore.`nIl programma verra' riavviato tramite PowerShell 7.", "CyberMedic Core v4.5", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
    Start-Process pwsh -Verb RunAs -WorkingDirectory $CurrentDir -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    Exit
}

$script:LogEntries = [System.Collections.Generic.List[string]]::new()
$script:Ui = @{}
$script:Tabs = @{}
$script:ChildProcesses = [System.Collections.Generic.List[System.Diagnostics.Process]]::new()

# ------------------------------------------------------------------------
# PLACEHOLDER PANEL PER $script:Tabs (necessari ai moduli diretti che
# aggiungono controlli al dot-sourcing, es. pipeline-tab e cybermedic-winget)
# ------------------------------------------------------------------------
$script:Tabs["Dashboard"]    = New-Object System.Windows.Forms.Panel
$script:Tabs["WingetApp"]    = New-Object System.Windows.Forms.Panel
$script:Tabs["GamingTweaks"] = New-Object System.Windows.Forms.Panel
$script:Tabs["StrumentiIT"]  = New-Object System.Windows.Forms.Panel
$script:Tabs["RegistroLog"]  = New-Object System.Windows.Forms.Panel
$script:Tabs["Stampanti"]    = New-Object System.Windows.Forms.Panel

function Write-LauncherLog {
    param([string]$Message)
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $line = "[$timestamp] $Message"
    if (-not $script:LogEntries) { $script:LogEntries = [System.Collections.Generic.List[string]]::new() }
    $script:LogEntries.Add($line)
    try {
        if ($script:Ui.LogRegistryListBox -and -not $script:Ui.LogRegistryListBox.IsDisposed) {
            $script:Ui.LogRegistryListBox.Invoke([Action]{
                param($lb, $txt)
                $lb.Items.Add($txt)
                if ($lb.Items.Count -gt 0) { $lb.TopIndex = $lb.Items.Count - 1 }
            }, $script:Ui.LogRegistryListBox, $line) | Out-Null
        }
    } catch {}
    $logDir = "C:\ProgramData\CyberMedic\logs"
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    $logFile = Join-Path $logDir "launcher-$(Get-Date -Format 'yyyyMMdd').log"
    try { Add-Content -Path $logFile -Value $line -Encoding UTF8 } catch {}
    Write-Host $line
}

function Register-ChildProcess {
    param([System.Diagnostics.Process]$Process)
    if ($Process) { [void]$script:ChildProcesses.Add($Process) }
}

# ------------------------------------------------------------------------
# CARICAMENTO TEMA FLuent (da v4.0 - grafica di riferimento)
# ------------------------------------------------------------------------
$ThemePath = [System.IO.Path]::Combine($RootDir, "gui", "CyberMedic_Theme.ps1")
if (Test-Path $ThemePath) {
    try {
        . $ThemePath
        Write-LauncherLog "Tema Fluent caricato: $ThemePath"
        $colorKeys = @()
        if ($script:Theme) {
            foreach ($k in $script:Theme.Keys) { $colorKeys += $k }
        }
        Write-LauncherLog "Colori definiti dal tema: $($colorKeys -join ', ')"
    } catch {
        $msg = $_.Exception.Message
        Write-LauncherLog "ERRORE caricamento tema: $msg"
        [System.Windows.Forms.MessageBox]::Show("Errore Critico: Impossibile caricare il tema.`n$msg", "CyberMedic Crash v4.5", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        Exit
    }
} else {
    [System.Windows.Forms.MessageBox]::Show("Errore Critico: Impossibile trovare il tema.`nPercorso cercato: $ThemePath", "CyberMedic Crash v4.5", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    Exit
}

# ------------------------------------------------------------------------
# CARICAMENTO CORE E GUI (da v4.0 - base di riferimento)
# ------------------------------------------------------------------------
$CorePath = [System.IO.Path]::Combine($RootDir, "CyberMedic_Core.ps1")
if (Test-Path $CorePath) {
    try {
        . $CorePath
        Write-LauncherLog "Core caricato: $CorePath"
    } catch {
        $msg = $_.Exception.Message
        Write-LauncherLog "ERRORE caricamento core: $msg"
        [System.Windows.Forms.MessageBox]::Show("Errore Critico: Impossibile caricare il core.`n$msg", "CyberMedic Crash v4.5", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        Exit
    }
} else {
    [System.Windows.Forms.MessageBox]::Show("Errore Critico: Impossibile trovare CyberMedic_Core.ps1.", "CyberMedic Crash v4.5", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    Exit
}

$GuiPath = [System.IO.Path]::Combine($RootDir, "CyberMedic_GUI.ps1")
if (Test-Path $GuiPath) {
    try {
        . $GuiPath
        Write-LauncherLog "GUI caricato: $GuiPath"
    } catch {
        $msg = $_.Exception.Message
        Write-LauncherLog "ERRORE caricamento GUI: $msg"
        [System.Windows.Forms.MessageBox]::Show("Errore Critico: Impossibile caricare la GUI.`n$msg", "CyberMedic Crash v4.5", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        Exit
    }
} else {
    [System.Windows.Forms.MessageBox]::Show("Errore Critico: Impossibile trovare CyberMedic_GUI.ps1.", "CyberMedic Crash v4.5", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    Exit
}

# ------------------------------------------------------------------------
# IPC (da v4.0)
# ------------------------------------------------------------------------
$IpcPath = [System.IO.Path]::Combine($RootDir, "core", "cybermedic-ipc.ps1")
if (Test-Path $IpcPath) {
    try { . $IpcPath; Write-LauncherLog "IPC caricato: $IpcPath" } catch { Write-LauncherLog "WARN IPC: $_" }
} else {
    Write-LauncherLog "WARN: cybermedic-ipc.ps1 non trovato (continuo)"
}

# ------------------------------------------------------------------------
# MODULI TAB v4.0 (aggiungono controlli ai placeholder $script:Tabs[...])
# ------------------------------------------------------------------------
$TabsDirectoryV40 = [System.IO.Path]::Combine($RootDir, "gui", "tabs")
$V40Modules = @(
    "dashboard.ps1",
    "pipeline-tab.ps1",
    "cybermedic-winget.ps1",
    "gaming-toolkit.ps1",
    "it-tools.ps1",
    "printers-tab.ps1",
    "log-registry.ps1"
)

$v40Loaded = 0
$v40Failed = 0
foreach ($Module in $V40Modules) {
    $FullPath = [System.IO.Path]::Combine($TabsDirectoryV40, $Module)
    if (Test-Path $FullPath) {
        try {
            . $FullPath
            $v40Loaded++
            Write-LauncherLog "OK modulo v4.0: $Module"
        } catch {
            $v40Failed++
            $err = $_.Exception
            $lineNum = if ($_.InvocationInfo) { $_.InvocationInfo.ScriptLineNumber } else { 0 }
            $line = if ($_.InvocationInfo -and $_.InvocationInfo.Line) { $_.InvocationInfo.Line.Trim() } else { "" }
            $msg = "${Module} [${Module}:${lineNum}] $($err.Message)"
            Write-LauncherLog "ERR modulo v4.0: $msg"
            Write-LauncherLog "  >> $line"
        }
    } else {
        Write-LauncherLog "SKIP modulo v4.0: $Module (non trovato)"
    }
}
Write-LauncherLog "Riepilogo moduli v4.0: caricati=$v40Loaded, con problemi/ignorati=$v40Failed"

# ------------------------------------------------------------------------
# MODULI TAB EXTRA da v3.0.1 (taskmanager, mail, cybersecurity, updates, maintenance)
# ------------------------------------------------------------------------
$TabsDirectoryV301 = [System.IO.Path]::Combine($RootDir, "gui", "tabs")
$CoreDirectory = [System.IO.Path]::Combine($RootDir, "core")
$ExtraModules = @(
    @{ File = "taskmanager.ps1"; Path = $TabsDirectoryV301 }
    @{ File = "updates.ps1"; Path = $TabsDirectoryV301 }
    @{ File = "mail.ps1"; Path = $TabsDirectoryV301 }
    @{ File = "cybersecurity.ps1"; Path = $TabsDirectoryV301 }
    @{ File = "maintenance.ps1"; Path = $CoreDirectory }
)

$extraLoaded = 0
$extraFailed = 0
foreach ($Mod in $ExtraModules) {
    $FullPath = [System.IO.Path]::Combine($Mod.Path, $Mod.File)
    if (Test-Path $FullPath) {
        try {
            . $FullPath
            $extraLoaded++
            Write-LauncherLog "OK modulo extra v3.0.1: $($Mod.File)"
        } catch {
            $extraFailed++
            $err = $_.Exception
            $lineNum = if ($_.InvocationInfo) { $_.InvocationInfo.ScriptLineNumber } else { 0 }
            $line = if ($_.InvocationInfo -and $_.InvocationInfo.Line) { $_.InvocationInfo.Line.Trim() } else { "" }
            $msg = "$($Mod.File) [$($Mod.File):${lineNum}] $($err.Message)"
            Write-LauncherLog "ERR modulo extra v3.0.1: $msg"
            Write-LauncherLog "  >> $line"
        }
    } else {
        Write-LauncherLog "SKIP modulo extra v3.0.1: $($Mod.File) (non trovato in $($Mod.Path))"
    }
}
Write-LauncherLog "Riepilogo moduli extra v3.0.1: caricati=$extraLoaded, con problemi/ignorati=$extraFailed"

# ------------------------------------------------------------------------
# CREAZIONE FINESTRA PRINCIPALE (New-DashboardForm da v4.0 GUI)
# ------------------------------------------------------------------------
if (-not $script:MainForm) {
    try {
        $script:MainForm = New-DashboardForm
        Write-LauncherLog "MainForm creato da New-DashboardForm (v4.5)."
    } catch {
        $msg = $_.Exception.Message
        $stack = $_.ScriptStackTrace
        Write-LauncherLog "ERRORE creazione MainForm: $msg`n$stack"
        [System.Windows.Forms.MessageBox]::Show("Errore Critico: MainForm non inizializzato.`n$msg", "CyberMedic Crash v4.5", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        Exit
    }
}

Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
[System.Windows.Forms.Application]::EnableVisualStyles()
try { [System.Windows.Forms.Application]::SetHighDpiMode([System.Windows.Forms.HighDpiMode]::PerMonitorV2) } catch {}

[System.Windows.Forms.Application]::add_ThreadException({
    param($sender, $e)
    Write-LauncherLog "ThreadException: $($e.Exception.Message)"
})

$script:MainForm.Add_FormClosing({
    param($sender, $e)
    $busy = $false
    if ($script:cybermedicProcess -and -not $script:cybermedicProcess.HasExited) { $busy = $true }
    if ($script:ChildProcesses | Where-Object { -not $_.HasExited }) { $busy = $true }
    if ($busy) {
        $res = [System.Windows.Forms.MessageBox]::Show("Ci sono operazioni in corso. Chiudere comunque?", "CyberMedic v4.5", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($res -eq [System.Windows.Forms.DialogResult]::No) {
            $e.Cancel = $true
            return
        }
    }
})

try {
    [void]$script:MainForm.ShowDialog()
} catch {
    Write-LauncherLog "Finestra interrotta o eccezione grafica: $_"
} finally {
    foreach ($p in $script:ChildProcesses) {
        if ($p -and -not $p.HasExited) {
            try { $p.Kill($true); $p.WaitForExit(2000) } catch {}
        }
    }
    if ($script:cybermedicProcess -and -not $script:cybermedicProcess.HasExited) {
        try { $script:cybermedicProcess.Kill($true); $script:cybermedicProcess.WaitForExit(2000) } catch {}
    }
    Write-LauncherLog "[CM] Sessione CyberMedic v4.5 terminata."
}
