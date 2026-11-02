#Requires -Version 7.0
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
    [System.Windows.Forms.MessageBox]::Show("CyberMedic richiede privilegi di Amministratore.`nIl programma verrà riavviato tramite PowerShell 7.", "CyberMedic Core", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
    Start-Process pwsh -Verb RunAs -WorkingDirectory $CurrentDir -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    Exit
}

$script:LogEntries = [System.Collections.Generic.List[string]]::new()
$script:Ui = @{}
$script:ChildProcesses = [System.Collections.Generic.List[System.Diagnostics.Process]]::new()

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

$ThemePath = [System.IO.Path]::Combine($RootDir, "gui", "CyberMedic_Theme.ps1")
if (Test-Path $ThemePath) {
    try {
        . $ThemePath
        Write-LauncherLog "Tema caricato: $ThemePath"
        $colorKeys = @()
        if ($script:Theme) {
            foreach ($k in $script:Theme.Keys) { $colorKeys += $k }
        }
        Write-LauncherLog "Colori definiti dal tema: $($colorKeys -join ', ')"
    } catch {
        $msg = $_.Exception.Message
        Write-LauncherLog "ERRORE caricamento tema: $msg"
        [System.Windows.Forms.MessageBox]::Show("Errore Critico: Impossibile caricare il tema.`n$msg", "CyberMedic Crash", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        Exit
    }
} else {
    [System.Windows.Forms.MessageBox]::Show("Errore Critico: Impossibile trovare il tema.`nPercorso cercato: $ThemePath", "CyberMedic Crash", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    Exit
}

if (-not $script:MainForm) {
    Write-LauncherLog "ERRORE: $script:MainForm non creato dal tema."
    [System.Windows.Forms.MessageBox]::Show("Errore Critico: MainForm non inizializzato.", "CyberMedic Crash", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    Exit
}

$IpcPath = [System.IO.Path]::Combine($RootDir, "core", "cybermedic-ipc.ps1")
if (Test-Path $IpcPath) {
    try { . $IpcPath; Write-LauncherLog "IPC caricato: $IpcPath" } catch { Write-LauncherLog "WARN IPC: $_" }
} else {
    Write-LauncherLog "WARN: cybermedic-ipc.ps1 non trovato (continuo)"
}

$TabsDirectory = [System.IO.Path]::Combine($RootDir, "gui", "tabs")
$ModulesToLoad = @(
    "dashboard.ps1",
    "pipeline-tab.ps1",
    "cybermedic-winget.ps1",
    "gaming-toolkit.ps1",
    "it-tools.ps1",
    "printers-tab.ps1",
    "cybersecurity-tab.ps1",
    "maintenance-tab.ps1",
    "log-registry.ps1"
)

$loaded = 0
$failed = 0
foreach ($Module in $ModulesToLoad) {
    $FullPath = [System.IO.Path]::Combine($TabsDirectory, $Module)
    if (Test-Path $FullPath) {
        try {
            . $FullPath
            $loaded++
            if (Get-Command Write-PoshLog -ErrorAction SilentlyContinue) {
                Write-PoshLog -Message "Agganciato con successo modulo: $Module" -Status 'SUCCESS'
            } else {
                Write-LauncherLog "OK modulo: $Module"
            }
        } catch {
            $failed++
            $err = $_.Exception
            $lineNum = if ($_.InvocationInfo) { $_.InvocationInfo.ScriptLineNumber } else { 0 }
            $line = if ($_.InvocationInfo -and $_.InvocationInfo.Line) { $_.InvocationInfo.Line.Trim() } else { "" }
            $msg = "${Module} [${Module}:${lineNum}] $($err.Message)"
            if (Get-Command Write-PoshLog -ErrorAction SilentlyContinue) {
                Write-PoshLog -Message "Errore durante l'inizializzazione del modulo $msg" -Status 'ERROR'
            } else {
                Write-LauncherLog "ERR modulo: $msg"
            }
            Write-LauncherLog "  >> $line"
        }
    } else {
        if (Get-Command Write-PoshLog -ErrorAction SilentlyContinue) {
            Write-PoshLog -Message "Modulo non trovato sul disco: $Module (Salto lo step)" -Status 'WARN'
        } else {
            Write-LauncherLog "SKIP modulo: $Module (non trovato)"
        }
    }
}
Write-LauncherLog "Riepilogo moduli: caricati=$loaded, con problemi/ignorati=$failed"

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
        $res = [System.Windows.Forms.MessageBox]::Show("Ci sono operazioni in corso. Chiudere comunque?", "CyberMedic", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
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
    Write-LauncherLog "[CM] Sessione CyberMedic terminata."
}

