# CyberMedic - Scheda modulare: Mail & PowerShell (Outlook, archivi PST/OST, assistenza).
# Caricata da CyberMedic_GUI.ps1 tramite dot-sourcing.

function New-MailTab {
    param([Parameter(Mandatory = $true)]$MainTabs)

    # SCHEDA 7 - MAIL & POWERSHELL (SCANPST E CONSOLE SICURA)
    # ------------------------------------------------------------------------
    $tabOutlook = New-Object System.Windows.Forms.TabPage('  📧  Mail & PowerShell  ')
    $tabOutlook.BackColor = $script:ColorBgMain
    $tabOutlook.ForeColor = $script:ColorAccent
    $tabOutlook.Padding = New-Object System.Windows.Forms.Padding(8)
    $mainTabs.TabPages.Add($tabOutlook)

    $outBar = New-Object System.Windows.Forms.FlowLayoutPanel
    $outBar.Dock = 'Top'
    $outBar.Height = 52
    $outBar.BackColor = $script:ColorBgMain
    $outBar.Padding = New-Object System.Windows.Forms.Padding(0, 0, 0, 6)

    $btnOutRefresh = New-ThemedButton -Text '🔄 Aggiorna archivi' -BackColor $script:ColorPanel -ForeColor $script:ColorAccent
    $btnOutRefresh.Add_Click({ Invoke-Safe -Context 'Rilevamento archivi Outlook' -Action { Show-OutlookPanel } })
    $outBar.Controls.Add($btnOutRefresh)

    $btnOutScan = New-ThemedButton -Text '🩺 Scansiona PST selezionato' -BackColor $script:ColorPanel -ForeColor $script:ColorSuccess
    $btnOutScan.Add_Click({ Invoke-OutlookScanSelected })
    $outBar.Controls.Add($btnOutScan)

    $btnOutOpen = New-ThemedButton -Text '▶ Apri SCANPST' -BackColor $script:ColorPanel -ForeColor $script:ColorTextMain
    $btnOutOpen.Add_Click({
        Invoke-Safe -Context 'Apertura SCANPST' -Action {
            $result = Invoke-OutlookScanPst
            [void](Show-Message -Text $result.Message -Caption 'CyberMedic - Outlook' -Kind $(if ($result.Success) { 'Info' } else { 'Error' }))
        }
    })
    $outBar.Controls.Add($btnOutOpen)

    $btnOutSync = New-ThemedButton -Text '🔄 Sincronizza archivio' -BackColor $script:ColorPanel -ForeColor $script:ColorAccent
    $btnOutSync.Add_Click({ Invoke-OutlookSyncSelected })
    $outBar.Controls.Add($btnOutSync)

    $btnOutCache = New-ThemedButton -Text '🧹 Ricostruisci cache' -BackColor $script:ColorPanel -ForeColor $script:ColorWarning
    $btnOutCache.Add_Click({
        Invoke-Safe -Context 'Ricostruzione della cache di Outlook' -Action {
            $answer = Show-Message -Text "La cache di Outlook verra' spostata con un backup datato e ricreata al prossimo avvio di Outlook.`r`nOutlook deve essere chiuso.`r`nProcedere?" -Caption 'CyberMedic - Cache Outlook' -Kind 'Question'
            if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
            $result = Repair-OutlookCache
            [void](Show-Message -Text $result.Message -Caption 'CyberMedic - Cache Outlook' -Kind $(if ($result.Success) { 'Info' } else { 'Warning' }))
            Show-OutlookPanel
        }
    })
    $outBar.Controls.Add($btnOutCache)

    $btnOutReport = New-ThemedButton -Text '📋 Report archivi' -BackColor $script:ColorPanel -ForeColor $script:ColorTextMain
    $btnOutReport.Add_Click({
        Invoke-Safe -Context 'Report degli archivi di posta' -Action {
            $report = Get-OutlookArchiveReport
            $script:Ui.SafePsOutput.Text = $report
            Update-StatusBar 'Report degli archivi di posta generato.'
        }
    })
    $outBar.Controls.Add($btnOutReport)

    $outStatus = New-Object System.Windows.Forms.Label
    $outStatus.Text = 'Rilevamento degli archivi Outlook in corso...'
    $outStatus.Dock = 'Top'
    $outStatus.Height = 62
    $outStatus.ForeColor = $script:ColorTextMain
    $outStatus.Font = New-Object System.Drawing.Font('Consolas', 9.5)
    $outStatus.BackColor = $script:ColorCardBg
    $outStatus.Padding = New-Object System.Windows.Forms.Padding(8, 6, 8, 6)

    $outList = New-ThemedListView -OwnerDrawHeader
    [void]$outList.Columns.Add('Tipo', 60)
    [void]$outList.Columns.Add('Nome', 190)
    [void]$outList.Columns.Add('Dimensione', 100)
    [void]$outList.Columns.Add('Modifica', 140)
    [void]$outList.Columns.Add('Percorso', 420)

    # --- CONSOLE POWERShell SICURA ----------------------------------------
    $psGroup = New-Object System.Windows.Forms.GroupBox
    $psGroup.Text = '  💻  Console PowerShell sicura  '
    $psGroup.Dock = 'Top'
    $psGroup.Height = 236
    $psGroup.BackColor = $script:ColorPanel
    $psGroup.ForeColor = $script:ColorAccent
    $psGroup.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $psInner = New-Object System.Windows.Forms.FlowLayoutPanel
    $psInner.Dock = 'Top'
    $psInner.Height = 44
    $psInner.WrapContents = $true
    $psInner.BackColor = $script:ColorPanel
    $psInner.Padding = New-Object System.Windows.Forms.Padding(10, 6, 10, 0)
    $psGroup.Controls.Add($psInner)

    $psLabel = New-Object System.Windows.Forms.Label
    $psLabel.Text = 'Comando:'
    $psLabel.ForeColor = $script:ColorTextMuted
    $psLabel.AutoSize = $true
    $psLabel.Margin = New-Object System.Windows.Forms.Padding(8, 9, 4, 0)
    $psInner.Controls.Add($psLabel)

    $psCommand = New-Object System.Windows.Forms.ComboBox
    $psCommand.DropDownStyle = 'DropDownList'
    $psCommand.FlatStyle = 'Flat'
    $psCommand.Width = 230
    $psCommand.BackColor = $script:ColorCardBg
    $psCommand.ForeColor = $script:ColorTextMain
    $psCommand.Margin = New-Object System.Windows.Forms.Padding(0, 6, 10, 0)
    try {
        foreach ($item in @(Get-SafePowerShellCatalog)) {
            [void]$psCommand.Items.Add(("{0} - {1}" -f $item.Name, $item.Description))
        }
        if ($psCommand.Items.Count -gt 0) { $psCommand.SelectedIndex = 0 }
    } catch { }
    $psInner.Controls.Add($psCommand)

    $psArgs = New-Object System.Windows.Forms.TextBox
    $psArgs.Width = 220
    $psArgs.BackColor = $script:ColorCardBg
    $psArgs.ForeColor = $script:ColorTextMain
    $psArgs.BorderStyle = 'FixedSingle'
    $psArgs.Margin = New-Object System.Windows.Forms.Padding(0, 6, 10, 0)
    $psInner.Controls.Add($psArgs)

    $btnPsRun = New-ThemedButton -Text '▶ Esegui in sola lettura' -BackColor $script:ColorPanel -ForeColor $script:ColorSuccess
    $btnPsRun.Add_Click({
        Invoke-Safe -Context 'Console PowerShell sicura' -Action {
            $selected = ''
            if ($script:Ui.SafePsCommand) { $selected = $script:Ui.SafePsCommand.Text }
            $command = ($selected -split ' - ')[0]
            $extra = ''
            if ($script:Ui.SafePsArgs) { $extra = $script:Ui.SafePsArgs.Text }
            if ($extra) { $command = '{0} {1}' -f $command, $extra }
            $result = Invoke-SafePowerShellCommand -Command $command
            $script:Ui.SafePsOutput.Text = ("{0}`r`n{1}" -f $result.Message, $result.Output)
            Update-ActivityLog
        }
    })
    $psInner.Controls.Add($btnPsRun)

    $psOutput = New-Object System.Windows.Forms.TextBox
    $psOutput.Multiline = $true
    $psOutput.ReadOnly = $true
    $psOutput.ScrollBars = 'Vertical'
    $psOutput.Dock = 'Fill'
    $psOutput.BackColor = $script:ColorCardBg
    $psOutput.ForeColor = $script:ColorSuccess
    $psOutput.Font = New-Object System.Drawing.Font('Consolas', 9)
    $psOutput.BorderStyle = 'None'
    $psGroup.Controls.Add($psOutput)

    $tabOutlook.Controls.Add($outList)
    $tabOutlook.Controls.Add($outStatus)
    $tabOutlook.Controls.Add($psGroup)
    $tabOutlook.Controls.Add($outBar)

    $script:Ui.OutlookList = $outList
    $script:Ui.OutlookStatus = $outStatus
    $script:Ui.SafePsCommand = $psCommand
    $script:Ui.SafePsArgs = $psArgs
    $script:Ui.SafePsOutput = $psOutput
    return $tabOutlook
}

function Show-OutlookPanel {
    if (-not $script:Ui.OutlookList) { return }
    try {
        $installation = Get-OutlookInstallation
        $status = New-Object System.Collections.Generic.List[string]
        $status.Add(('SCANPST    : {0}' -f $(if ($installation.Found) { $installation.Path } else { 'non installato' })))
        $status.Add(('Outlook    : {0}' -f $(if ($installation.OutlookFound) { $installation.OutlookPath } else { 'non rilevato' })))
        $status.Add(('Archivi PST: {0}   Archivi OST: {1}' -f $installation.PstCount, $installation.OstCount))
        if ($script:Ui.OutlookStatus) { $script:Ui.OutlookStatus.Text = ($status -join [Environment]::NewLine) }
        $script:Ui.OutlookList.Items.Clear()
        $archiveFiles = New-Object System.Collections.Generic.List[object]
        foreach ($file in @($installation.PstFiles)) { $archiveFiles.Add([pscustomobject]@{ Kind = 'PST'; Path = $file }) }
        foreach ($file in @($installation.OstFiles)) { $archiveFiles.Add([pscustomobject]@{ Kind = 'OST'; Path = $file }) }
        foreach ($archive in $archiveFiles) {
            $info = Get-Item -LiteralPath $archive.Path -ErrorAction SilentlyContinue
            $size = 'N/D'
            $stamp = 'N/D'
            if ($info) {
                $size = ('{0:N1} MB' -f ($info.Length / 1MB))
                $stamp = $info.LastWriteTime.ToString('dd/MM/yyyy HH:mm')
            }
            $item = New-Object System.Windows.Forms.ListViewItem($archive.Kind)
            [void]$item.SubItems.Add((Split-Path -Path $archive.Path -Leaf))
            [void]$item.SubItems.Add($size)
            [void]$item.SubItems.Add($stamp)
            [void]$item.SubItems.Add($archive.Path)
            $item.Tag = $archive.Path
            [void]$script:Ui.OutlookList.Items.Add($item)
        }
        if ($installation.PstCount -eq 0 -and $installation.OstCount -eq 0) {
            $item = New-Object System.Windows.Forms.ListViewItem('Nessun archivio PST/OST trovato nel profilo Outlook')
            [void]$item.SubItems.Add('')
            [void]$item.SubItems.Add('')
            [void]$item.SubItems.Add('')
            [void]$script:Ui.OutlookList.Items.Add($item)
        }
    } catch {
        Write-Log -Message ("Rilevamento degli archivi Outlook non riuscito: {0}" -f $_.Exception.Message) -Level 'WARN'
    }
}

function Get-SelectedOutlookPath {
    $list = $script:Ui.OutlookList
    if (-not $list -or $list.SelectedItems.Count -eq 0) { return $null }
    $item = $list.SelectedItems[0]
    $candidate = $null
    if ($item.Tag) { $candidate = [string]$item.Tag }
    if (-not $candidate -and $item.SubItems.Count -ge 4) { $candidate = [string]$item.SubItems[4].Text }
    if (-not $candidate) { return $null }
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    return $null
}

function Invoke-OutlookScanSelected {
    Invoke-Safe -Context 'Scansione Outlook' -Action {
        $target = Get-SelectedOutlookPath
        $result = Invoke-OutlookScanPst -PstPath $target
        [void](Show-Message -Text $result.Message -Caption 'CyberMedic - Outlook' -Kind $(if ($result.Success) { 'Info' } else { 'Error' }))
        Update-ActivityLog
    }
}

function Invoke-OutlookSyncSelected {
    Invoke-Safe -Context 'Sincronizzazione archivio Outlook' -Action {
        $target = Get-SelectedOutlookPath
        $result = Sync-OutlookArchive -PstPath $target
        [void](Show-Message -Text $result.Message -Caption 'CyberMedic - Outlook' -Kind $(if ($result.Success) { 'Info' } else { 'Warning' }))
        Update-ActivityLog
    }
}
