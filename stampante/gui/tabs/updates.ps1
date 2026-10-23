# CyberMedic - Scheda modulare: Updates (pacchetti Winget e driver di sistema).
# Caricata da CyberMedic_GUI.ps1 tramite dot-sourcing.

# Momento dell'ultimo caricamento dell'elenco aggiornamenti: usato come cache
# per non interrogare winget piu' volte al minuto.
$script:UpdatesLoadedAt = $null

function New-UpdatesTab {
    param([Parameter(Mandatory = $true)]$MainTabs)

    # SCHEDA 5 - UPDATES (WINGET E DRIVER)
    # ------------------------------------------------------------------------
    $tabMaint = New-Object System.Windows.Forms.TabPage('  📦  Updates  ')
    $tabMaint.BackColor = $script:ColorBgMain
    $tabMaint.ForeColor = $script:ColorAccent
    $tabMaint.Padding = New-Object System.Windows.Forms.Padding(8)
    $mainTabs.TabPages.Add($tabMaint)

    # BOX 1 - aggiornamenti delle applicazioni (pacchetti Winget)
    $appsGroup = New-Object System.Windows.Forms.GroupBox
    $appsGroup.Text = '  📦  Aggiornamenti applicazioni (Winget)  '
    $appsGroup.Dock = 'Fill'
    $appsGroup.BackColor = $script:ColorPanel
    $appsGroup.ForeColor = $script:ColorAccent
    $appsGroup.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $appsInner = New-Object System.Windows.Forms.Panel
    $appsInner.Dock = 'Fill'
    $appsInner.BackColor = $script:ColorPanel
    $appsInner.Padding = New-Object System.Windows.Forms.Padding(8, 4, 8, 4)
    $appsGroup.Controls.Add($appsInner)

    $maintList = New-Object System.Windows.Forms.CheckedListBox
    $maintList.Dock = 'Fill'
    $maintList.CheckOnClick = $true
    $maintList.BackColor = $script:ColorBgList
    $maintList.ForeColor = $script:ColorTextMain
    $maintList.Font = New-Object System.Drawing.Font('Consolas', 9.5)
    $maintList.BorderStyle = 'None'
    $appsInner.Controls.Add($maintList)
    $tabMaint.Controls.Add($appsGroup)

    # BOX 2 - driver di sistema
    $driverGroup = New-Object System.Windows.Forms.GroupBox
    $driverGroup.Text = '  🎮  Driver di sistema  '
    $driverGroup.Dock = 'Bottom'
    $driverGroup.Height = 230
    $driverGroup.BackColor = $script:ColorPanel
    $driverGroup.ForeColor = $script:ColorAccent
    $driverGroup.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $tabMaint.Controls.Add($driverGroup)

    $driverInner = New-Object System.Windows.Forms.Panel
    $driverInner.Dock = 'Fill'
    $driverInner.BackColor = $script:ColorPanel
    $driverInner.Padding = New-Object System.Windows.Forms.Padding(8, 4, 8, 4)
    $driverGroup.Controls.Add($driverInner)

    $driverSummary = New-Object System.Windows.Forms.Label
    $driverSummary.Text = 'Analisi dei driver in corso...'
    $driverSummary.Dock = 'Top'
    $driverSummary.Height = 22
    $driverSummary.ForeColor = $script:ColorTextMuted
    $driverSummary.TextAlign = 'MiddleLeft'

    $driverList = New-Object System.Windows.Forms.CheckedListBox
    $driverList.Dock = 'Fill'
    $driverList.CheckOnClick = $true
    $driverList.BackColor = $script:ColorBgList
    $driverList.ForeColor = $script:ColorTextMain
    $driverList.Font = New-Object System.Drawing.Font('Consolas', 9.5)
    $driverList.BorderStyle = 'None'
    $driverInner.Controls.Add($driverList)
    $driverInner.Controls.Add($driverSummary)

    $maintConsole = New-Object System.Windows.Forms.TextBox
    $maintConsole.Multiline = $true
    $maintConsole.ReadOnly = $true
    $maintConsole.ScrollBars = 'Vertical'
    $maintConsole.Dock = 'Bottom'
    $maintConsole.Height = 150
    $maintConsole.BackColor = $script:ColorCardBg
    $maintConsole.ForeColor = $script:ColorSuccess
    $maintConsole.Font = New-Object System.Drawing.Font('Consolas', 9.5)
    $maintConsole.BorderStyle = 'None'
    $tabMaint.Controls.Add($maintConsole)

    $maintBar = New-Object System.Windows.Forms.FlowLayoutPanel
    $maintBar.Dock = 'Top'
    $maintBar.Height = 92
    $maintBar.WrapContents = $true
    $maintBar.BackColor = $script:ColorBgMain
    $maintBar.Padding = New-Object System.Windows.Forms.Padding(0, 0, 0, 6)
    $tabMaint.Controls.Add($maintBar)

    $btnTemp = New-ThemedButton -Text '🧹 Pulisci file temporanei' -BackColor $script:ColorPanel -ForeColor $script:ColorWarning
    $btnTemp.Add_Click({
        Invoke-Safe -Context 'Pulizia file temporanei' -Action {
            $answer = Show-Message -Text "Eliminare i file temporanei di utente e di sistema?`r`nI file in uso da altre applicazioni verranno saltati." -Caption 'CyberMedic - Pulizia' -Kind 'Question'
            if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
            Set-BusyState -Busy $true -Message 'Pulizia in corso...'
            try {
                [void](Show-Message -Text (Invoke-TempCleanup) -Caption 'CyberMedic - Pulizia completata' -Kind 'Info')
                Update-StatusBar 'Pulizia dei file temporanei completata.'
            } finally {
                Set-BusyState -Busy $false -Message 'Pronto'
            }
        }
    })
    $maintBar.Controls.Add($btnTemp)

    $btnRefreshDrivers = New-ThemedButton -Text '🔄 Aggiorna driver' -BackColor $script:ColorPanel -ForeColor $script:ColorAccent
    $btnRefreshDrivers.Add_Click({
        Invoke-Safe -Context 'Aggiornamento elenco driver' -Action {
            Set-BusyState -Busy $true -Message 'Analisi dei driver in corso...'
            try {
                Show-DriverList
                Update-StatusBar ($script:Ui.DriverSummary.Text)
            } finally {
                Set-BusyState -Busy $false -Message 'Pronto'
            }
        }
    })
    $maintBar.Controls.Add($btnRefreshDrivers)

    $btnSelAll = New-ThemedButton -Text '☑️ Seleziona tutti' -BackColor $script:ColorPanel -ForeColor $script:ColorTextMain
    $btnSelAll.Add_Click({
        for ($i = 0; $i -lt $script:Ui.MaintList.Items.Count; $i++) { $script:Ui.MaintList.SetItemChecked($i, $true) }
        Update-StatusBar ("Selezionati {0} pacchetti." -f $script:Ui.MaintList.Items.Count)
    })
    $maintBar.Controls.Add($btnSelAll)

    $btnDeselAll = New-ThemedButton -Text '🔲 Deseleziona tutti' -BackColor $script:ColorPanel -ForeColor $script:ColorTextMain
    $btnDeselAll.Add_Click({
        for ($i = 0; $i -lt $script:Ui.MaintList.Items.Count; $i++) { $script:Ui.MaintList.SetItemChecked($i, $false) }
        Update-StatusBar 'Selezione azzerata.'
    })
    $maintBar.Controls.Add($btnDeselAll)

    $btnApplySel = New-ThemedButton -Text '📥 Applica in sequenza (app + driver)' -BackColor $script:ColorPanel -ForeColor $script:ColorSuccess
    $btnApplySel.Add_Click({
        Invoke-Safe -Context 'Aggiornamento sequenziale' -Action {
            Invoke-SequentialMaintenance
        }
    })
    $maintBar.Controls.Add($btnApplySel)

    $btnApplyAll = New-ThemedButton -Text '🚀 Scarica e installa tutto' -BackColor $script:ColorPanel -ForeColor $script:ColorWarning
    $btnApplyAll.Add_Click({
        Invoke-Safe -Context 'Aggiornamento globale' -Action {
            $command = Get-WingetUpgradeAllCommand
            if (-not $command) {
                [void](Show-Message -Text 'Winget non e'' installato su questa postazione.' -Caption 'CyberMedic - Winget' -Kind 'Warning')
                return
            }
            $answer = Show-Message -Text "Scaricare e installare TUTTI gli aggiornamenti disponibili?`r`n`r`nL'operazione puo' richiedere diversi minuti e riavviare il PC se un pacchetto lo richiede." -Caption 'CyberMedic - Aggiornamento globale' -Kind 'Question'
            if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
            Update-StatusBar 'Aggiornamento globale in corso (winget upgrade --all)...'
            [void](Start-BackgroundCommand -FilePath $command.FilePath -Arguments $command.Arguments -OnComplete {
                param($text, $exitCode, $cmdArgs)
                Update-StatusBar ("Aggiornamento globale completato (exit {0})." -f $exitCode)
                Show-ScrollableResultDialog -Title 'Aggiornamento globale (winget upgrade --all)' -Text ("exit code {0}`r`n`r`n{1}" -f $exitCode, $text)
            })
        }
    })
    $maintBar.Controls.Add($btnApplyAll)

    $btnChangePass = New-ThemedButton -Text '🔑 Cambio password utente' -BackColor $script:ColorPanel -ForeColor $script:ColorTextMain
    $btnChangePass.Add_Click({ Show-PasswordChangeDialog })
    $maintBar.Controls.Add($btnChangePass)

    # ------------------------------------------------------------------------

    # --- CARD GRAFICI PRESTAZIONE (toggle in stile WinUI 3) ---------------
    $chartHost = New-Object System.Windows.Forms.Panel
    $chartHost.Dock = 'Fill'
    $chartHost.BackColor = $script:ColorCardBg

    $updateCharts = @{
        CPU  = (New-MetricHistoryChart -Key 'CPU' -Caption 'Andamento CPU (ultimi campioni)')
        RAM  = (New-MetricHistoryChart -Key 'RAM' -Caption 'Andamento memoria RAM (ultimi campioni)')
        DISK = (New-MetricHistoryChart -Key 'DISK' -Caption 'Andamento disco di sistema (ultimi campioni)')
    }
    foreach ($chartKey in @('CPU', 'RAM', 'DISK')) {
        $chart = $updateCharts[$chartKey]
        $chart.Dock = 'Top'
        $chart.Height = 176
        $chart.Visible = $false
        $chartHost.Controls.Add($chart)
    }

    $chartToggleBar = New-Object System.Windows.Forms.FlowLayoutPanel
    $chartToggleBar.Dock = 'Top'
    $chartToggleBar.Height = 44
    $chartToggleBar.WrapContents = $false
    $chartToggleBar.BackColor = $script:ColorCardBg
    $chartToggleBar.Padding = New-Object System.Windows.Forms.Padding(0, 0, 0, 6)
    $chartHost.Controls.Add($chartToggleBar)

    $chartHint = New-Object System.Windows.Forms.Label
    $chartHint.Text = 'Attiva o disattiva ogni grafico con i pulsanti: lo stato del pulsante segue la visibilita''.'
    $chartHint.ForeColor = $script:ColorTextMuted
    $chartHint.Font = Get-FluentFont -Size 9
    $chartHint.AutoSize = $false
    $chartHint.Size = New-Object System.Drawing.Size(520, 24)
    $chartHint.Margin = New-Object System.Windows.Forms.Padding(0, 8, 12, 0)
    $chartToggleBar.Controls.Add($chartHint)

    foreach ($definition in @(
        @{ Key = 'CPU'; Text = '📈 CPU' }
        @{ Key = 'RAM'; Text = '📈 RAM' }
        @{ Key = 'DISK'; Text = '📈 Disco' }
    )) {
        $chartKey = $definition.Key
        $toggle = New-FluentToggleButton -Text $definition.Text -Key ('Updates.' + $chartKey) -Width 132
        $toggle.Tag = $chartKey
        $toggle.Add_Click({
            param($sender, $eventArgs)
            Invoke-Safe -Context ('Grafico ' + $sender.Tag) -Action {
                $key = [string]$sender.Tag
                $state = -not (Get-FluentToggleState -Key ('Updates.' + $key))
                [void](Set-FluentToggleState -Key ('Updates.' + $key) -On $state)
                $chart = $script:Ui.UpdateCharts[$key]
                if ($chart) {
                    try { $chart.Visible = $state; $chart.Invalidate() } catch { }
                }
                Update-StatusBar ("Grafico {0}: {1}" -f $key, $(if ($state) { 'visibile' } else { 'nascosto' }))
            }
        })
        $chartToggleBar.Controls.Add($toggle)
    }

    $chartCard = New-FluentCard -Title '  📈  Grafici prestazione (CPU, RAM, disco)  ' -Content $chartHost -Height 316
    $tabMaint.Controls.Add($chartCard)

    $script:Ui.MaintList = $maintList
    $script:Ui.MaintPackageIds = New-Object System.Collections.Generic.List[string]
    $script:Ui.MaintResults = New-Object System.Collections.Generic.List[string]
    $script:Ui.MaintPending = 0
    $script:Ui.DriverList = $driverList
    $script:Ui.DriverIds = New-Object System.Collections.Generic.List[string]
    $script:Ui.DriverSummary = $driverSummary
    $script:Ui.MaintenanceConsole = $maintConsole
    $script:Ui.UpdateCharts = $updateCharts
    $script:Ui.UpdatesTab = $tabMaint

    # L'elenco degli aggiornamenti si popola da solo: al primo accesso alla
    # scheda (e all'avvio) l'interrogazione di winget parte in background.
    $MainTabs.Add_SelectedIndexChanged({
        try {
            if (-not $script:Ui.UpdatesTab) { return }
            if ($script:Ui.MainTabs -and ($script:Ui.MainTabs.SelectedTab -ne $script:Ui.UpdatesTab)) { return }
            Load-UpdatePackages
        } catch { }
    })

    return $tabMaint
}

function Load-UpdatePackages {
    param([switch]$Force)
    if (-not $script:Ui.MaintList) { return }
    if (-not $Force -and $script:UpdatesLoadedAt) {
        $age = (Get-Date) - $script:UpdatesLoadedAt
        if ($age.TotalMinutes -lt 5) { return }
    }
    $command = Get-WingetUpgradeListCommand
    if (-not $command) {
        Update-StatusBar 'Winget non installato: elenco aggiornamenti non disponibile.'
        return
    }
    Update-StatusBar 'Ricerca degli aggiornamenti disponibili in corso...'
    [void](Start-BackgroundCommand -FilePath $command.FilePath -Arguments $command.Arguments -OnComplete {
        param($text, $exitCode, $cmdArgs)
        $items = @(ConvertTo-WingetUpgradeList -Text $text)
        $script:Ui.MaintList.Items.Clear()
        $script:Ui.MaintPackageIds.Clear()
        foreach ($item in $items) {
            $label = "{0}  [{1}]  {2} -> {3}" -f $item.Name, $item.Id, $item.Version, $item.Available
            [void]$script:Ui.MaintList.Items.Add($label, $true)
            $script:Ui.MaintPackageIds.Add($item.Id)
        }
        $script:UpdatesLoadedAt = Get-Date
        Update-StatusBar ("Aggiornamenti disponibili: {0}." -f $items.Count)
    })
}

function Show-DriverList {
    if (-not $script:Ui.DriverList) { return }
    try {
        $drivers = Get-SystemDriversList
        $script:Ui.DriverList.Items.Clear()
        $script:Ui.DriverIds.Clear()
        foreach ($driver in @($drivers.Devices)) {
            $label = ("{0}  [{1}]" -f $driver.Name, $driver.Status)
            $index = $script:Ui.DriverList.Items.Add($label)
            $script:Ui.DriverList.SetItemChecked($index, [bool]$driver.Problem)
            $script:Ui.DriverIds.Add([string]$driver.Name)
        }
        if ($script:Ui.DriverSummary) { $script:Ui.DriverSummary.Text = $drivers.Summary }
    } catch {
        Write-Log -Message ("Lettura dei driver di sistema non riuscita: {0}" -f $_.Exception.Message) -Level 'WARN'
    }
}

function Invoke-SequentialMaintenance {
    Invoke-Safe -Context 'Aggiornamento sequenziale' -Action {
        $console = $script:Ui.MaintenanceConsole
        $ids = @()
        for ($i = 0; $i -lt $script:Ui.MaintList.Items.Count; $i++) {
            if ($script:Ui.MaintList.GetItemChecked($i) -and $script:Ui.MaintPackageIds[$i]) {
                $ids += $script:Ui.MaintPackageIds[$i]
            }
        }
        $drivers = @()
        for ($i = 0; $i -lt $script:Ui.DriverList.Items.Count; $i++) {
            if ($script:Ui.DriverList.GetItemChecked($i) -and $script:Ui.DriverIds[$i]) {
                $drivers += $script:Ui.DriverIds[$i]
            }
        }
        if ($ids.Count -eq 0 -and $drivers.Count -eq 0) {
            [void](Show-Message -Text 'Selezionare almeno un''applicazione o un driver da processare.' -Caption 'CyberMedic - Manutenzione' -Kind 'Warning')
            return
        }
        Clear-QueuedTask
        $console.Clear()
        $total = $ids.Count + $drivers.Count
        $index = 0
        foreach ($id in $ids) {
            $index++
            $command = Get-WingetUpgradeIdCommand -Id $id
            if (-not $command) {
                $console.AppendText(("winget non installato: impossibile aggiornare {0}" -f $id) + [Environment]::NewLine)
                continue
            }
            $console.AppendText(("[{0}/{1}] in coda: aggiornamento {2}" -f $index, $total, $id) + [Environment]::NewLine)
            $arguments = @($command.Arguments)
            [void](Add-QueuedTask -Label ("Aggiornamento {0}" -f $id) -Tag $id -FilePath $command.FilePath -Arguments $arguments -OnComplete {
                param($text, $exitCode, $cmdArgs, $task)
                $head = (($text -split "`r?`n" | Where-Object { $_ }) | Select-Object -First 3) -join ' | '
                $script:Ui.MaintenanceConsole.AppendText(("  -> [{0}] exit {1}: {2}" -f $task.Tag, $exitCode, $head) + [Environment]::NewLine)
                Update-ActivityQueue
                Update-StatusBar ("Aggiornamento completato: {0}" -f $task.Tag)
            })
        }
        $pnputil = Get-ExternalToolPath -Name 'pnputil.exe'
        foreach ($driver in $drivers) {
            $index++
            if (-not $pnputil) {
                $console.AppendText(('pnputil non disponibile: verifica driver saltata') + [Environment]::NewLine)
                continue
            }
            $console.AppendText(("[{0}/{1}] in coda: verifica driver {2}" -f $index, $total, $driver) + [Environment]::NewLine)
            [void](Add-QueuedTask -Label ("Verifica driver {0}" -f $driver) -Tag $driver -FilePath $pnputil -Arguments @('/scan-devices') -OnComplete {
                param($text, $exitCode, $cmdArgs, $task)
                $script:Ui.MaintenanceConsole.AppendText(("  -> verifica driver {0} completata (exit {1})" -f $task.Tag, $exitCode) + [Environment]::NewLine)
                Show-DriverList
                Update-ActivityQueue
            })
        }
        Update-ActivityQueue
        Update-StatusBar ("Coda avviata: {0} operazioni in sequenza." -f $total)
    }
}
