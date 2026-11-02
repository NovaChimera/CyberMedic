#Requires -Version 5.1
<#
.SYNOPSIS
    CyberMedic 3.0.1 Module - Unified Log Registry & Export Engine.
.DESCRIPTION
    Interfaccia nativa WinForms per la visualizzazione e l'esportazione dei log di sistema.
#>

if (Get-Command Write-PoshLog -ErrorAction SilentlyContinue) {
    Write-PoshLog -Message "Iniezione Modulo [Tab 6: Registro & Esportazione Log] avviata..." -Status 'âš¡'
}

$TabLog = $script:Tabs["RegistroLog"]
if (-not $TabLog) {
    Write-Warning "Tab 'Registro Log' non trovato nella mappa globale di CyberMedic."
    return
}

$GroupLogViewer = New-Object System.Windows.Forms.GroupBox
$GroupLogViewer.Text = " Registro Operazioni Unificato (CyberMedic & cybermedic) "
$GroupLogViewer.Location = New-Object System.Drawing.Point(20, 20)
$GroupLogViewer.Size = New-Object System.Drawing.Size(1030, 480)
$GroupLogViewer.ForeColor = $script:Theme.TextPrimary
$TabLog.Controls.Add($GroupLogViewer)

$script:Ui.LogRegistryListBox = New-Object System.Windows.Forms.ListBox
$script:Ui.LogRegistryListBox.Location = New-Object System.Drawing.Point(25, 40)
$script:Ui.LogRegistryListBox.Size = New-Object System.Drawing.Size(980, 410)
$script:Ui.LogRegistryListBox.BackColor = $script:Theme.BgMain
$script:Ui.LogRegistryListBox.ForeColor = $script:Theme.TextPrimary
$script:Ui.LogRegistryListBox.Font = $script:Theme.FontConsole
$GroupLogViewer.Controls.Add($script:Ui.LogRegistryListBox)

$BtnExportLog = New-Object System.Windows.Forms.Button
$BtnExportLog.Location = New-Object System.Drawing.Point(20, 520)
$BtnExportLog.Size = New-Object System.Drawing.Size(350, 45)
$BtnExportLog.Text = "Esporta Log Tecnico (WinExportLog)"
$BtnExportLog.BackColor = $script:Theme.AccentBlue
$BtnExportLog.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$TabLog.Controls.Add($BtnExportLog)

$BtnClearRegistry = New-Object System.Windows.Forms.Button
$BtnClearRegistry.Location = New-Object System.Drawing.Point(390, 520)
$BtnClearRegistry.Size = New-Object System.Drawing.Size(250, 45)
$BtnClearRegistry.Text = "Svuota Cronologia Sessione"
$BtnClearRegistry.BackColor = $script:Theme.BgTabs
$BtnClearRegistry.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$TabLog.Controls.Add($BtnClearRegistry)

function Sync-LogRegistryView {
    if (-not $script:Ui.LogRegistryListBox) { return }
    try {
        $script:Ui.LogRegistryListBox.BeginUpdate()
        $script:Ui.LogRegistryListBox.Items.Clear()
        if ($script:LogEntries) {
            foreach ($Entry in $script:LogEntries) {
                $script:Ui.LogRegistryListBox.Items.Add($Entry)
            }
        }
        if ($script:Ui.LogRegistryListBox.Items.Count -gt 0) {
            $script:Ui.LogRegistryListBox.SelectedIndex = $script:Ui.LogRegistryListBox.Items.Count - 1
        }
    } catch {}
    finally {
        $script:Ui.LogRegistryListBox.EndUpdate()
    }
}

function Export-ToolkitLogFile {
    if (Get-Command Write-PoshLog -ErrorAction SilentlyContinue) { Write-PoshLog -Message "Inizializzazione procedura di esportazione log [WinExportLog]..." -Status 'INFO' }
    $dateStr = Get-Date -Format "yyyyMMdd_HHmmss"
    $exportDestination = Join-Path $env:USERPROFILE\Desktop "CyberMedic_TechnicalLog_$dateStr.log"
    try {
        if (-not $script:LogEntries -or $script:LogEntries.Count -eq 0) {
            if (Get-Command Write-PoshLog -ErrorAction SilentlyContinue) { Write-PoshLog -Message "Nessun dato presente nel registro della sessione corrente." -Status 'WARN' }
            return
        }
        $script:LogEntries | Out-File -FilePath $exportDestination -Encoding utf8 -Force
        if (Get-Command Write-PoshLog -ErrorAction SilentlyContinue) { Write-PoshLog -Message "Registro eventi esportato con successo sul Desktop: $exportDestination" -Status 'SUCCESS' }
    } catch {
        if (Get-Command Write-PoshLog -ErrorAction SilentlyContinue) { Write-PoshLog -Message "Impossibile esportare il file di log: $_" -Status 'ERROR' }
    }
}

$BtnExportLog.Add_Click({ Export-ToolkitLogFile; Sync-LogRegistryView })
$BtnClearRegistry.Add_Click({
    $confirmation = [System.Windows.Forms.MessageBox]::Show("Sei sicuro di voler svuotare il registro della sessione corrente?", "CyberMedic Domanda", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    if ($confirmation -eq [System.Windows.Forms.DialogResult]::Yes) {
        if ($script:LogEntries) { $script:LogEntries.Clear() }
        Sync-LogRegistryView
        if (Get-Command Write-PoshLog -ErrorAction SilentlyContinue) { Write-PoshLog -Message "Cronologia della sessione pulita dall'utente." -Status 'WARN' }
    }
})

if (Get-Command Write-PoshLog -ErrorAction SilentlyContinue) { Write-PoshLog -Message "Modulo [Tab 6: Registro Eventi & Esportazione] agganciato e pronto." -Status 'SUCCESS' }
Apply-DarkThemeToControl -Control $TabLog

