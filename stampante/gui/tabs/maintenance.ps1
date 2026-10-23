# CyberMedic - Scheda modulare: Maintenance (pulizia, credenziali, scansioni Nmap).
# Caricata da CyberMedic_GUI.ps1 tramite dot-sourcing.

function New-MaintenanceTab {
    param([Parameter(Mandatory = $true)]$MainTabs)

    $tabMaint = New-Object System.Windows.Forms.TabPage('  🧹  Maintenance  ')
    $tabMaint.BackColor = $script:ColorBgMain
    $tabMaint.ForeColor = $script:ColorAccent
    $tabMaint.Padding = New-Object System.Windows.Forms.Padding(8)
    $MainTabs.TabPages.Add($tabMaint)

    $maintOutput = New-Object System.Windows.Forms.TextBox
    $maintOutput.Multiline = $true
    $maintOutput.ReadOnly = $true
    $maintOutput.ScrollBars = 'Both'
    $maintOutput.WordWrap = $false
    $maintOutput.Dock = 'Fill'
    $maintOutput.BackColor = $script:ColorCardBg
    $maintOutput.ForeColor = $script:ColorSuccess
    $maintOutput.Font = New-Object System.Drawing.Font('Consolas', 9.5)
    $maintOutput.BorderStyle = 'None'
    $tabMaint.Controls.Add($maintOutput)

    # --- PULIZIA FILE TEMPORANEI ---------------------------------------
    $cleanupGroup = New-Object System.Windows.Forms.GroupBox
    $cleanupGroup.Text = '  🧹  Pulizia file temporanei  '
    $cleanupGroup.Dock = 'Top'
    $cleanupGroup.Height = 150
    $cleanupGroup.BackColor = $script:ColorPanel
    $cleanupGroup.ForeColor = $script:ColorAccent
    $cleanupGroup.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $tabMaint.Controls.Add($cleanupGroup)

    $cleanupInner = New-Object System.Windows.Forms.FlowLayoutPanel
    $cleanupInner.Dock = 'Fill'
    $cleanupInner.WrapContents = $true
    $cleanupInner.BackColor = $script:ColorPanel
    $cleanupInner.Padding = New-Object System.Windows.Forms.Padding(10, 6, 10, 6)
    $cleanupGroup.Controls.Add($cleanupInner)

    $cleanupPlan = New-Object System.Windows.Forms.Label
    $cleanupPlan.Text = 'Analisi delle cartelle temporanee in corso...'
    $cleanupPlan.ForeColor = $script:ColorTextMuted
    $cleanupPlan.AutoSize = $true
    $cleanupPlan.Margin = New-Object System.Windows.Forms.Padding(8, 9, 4, 0)
    $cleanupInner.Controls.Add($cleanupPlan)

    $chkPrefetch = New-Object System.Windows.Forms.CheckBox
    $chkPrefetch.Text = 'Includi Prefetch'
    $chkPrefetch.ForeColor = $script:ColorTextMain
    $chkPrefetch.AutoSize = $true
    $chkPrefetch.Checked = $false
    $chkPrefetch.Margin = New-Object System.Windows.Forms.Padding(8, 8, 4, 0)
    $cleanupInner.Controls.Add($chkPrefetch)

    $btnCleanupPlan = New-ThemedButton -Text '📋 Analizza cartelle' -BackColor $script:ColorPanel -ForeColor $script:ColorTextMain
    $btnCleanupPlan.Add_Click({
        Invoke-Safe -Context 'Analisi delle cartelle temporanee' -Action {
            $plan = @(Get-CleanupTarget)
            $lines = New-Object System.Collections.Generic.List[string]
            foreach ($item in $plan) {
                $lines.Add(("{0,-24} {1,10} MB  {2,6} file  {3}" -f $item.Label, $item.SizeMB, $item.FileCount, $item.Path))
            }
            $script:Ui.MaintenanceOutput.Text = (($lines -join [Environment]::NewLine))
            Update-StatusBar ("Piano di pulizia: {0} cartelle." -f $plan.Count)
        }
    })
    $cleanupInner.Controls.Add($btnCleanupPlan)

    $btnCleanupRun = New-ThemedButton -Text '🧹 Esegui pulizia' -BackColor $script:ColorPanel -ForeColor $script:ColorWarning
    $btnCleanupRun.Add_Click({
        Invoke-Safe -Context 'Pulizia file temporanei' -Action {
            $includePrefetch = [bool]$script:Ui.PrefetchCheck.Checked
            if ($includePrefetch) {
                $answer = Show-Message -Text "La pulizia di Prefetch non e' consigliata da Microsoft e rende piu' lento il primo avvio delle applicazioni.`r`nProcedere comunque?" -Caption 'CyberMedic - Prefetch' -Kind 'Question'
                if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
            }
            Set-BusyState -Busy $true -Message 'Pulizia in corso...'
            try {
                $report = Invoke-TempCleanup -IncludePrefetch:$includePrefetch
                $script:Ui.MaintenanceOutput.Text = $report
                Update-StatusBar 'Pulizia dei file temporanei completata.'
            } finally {
                Set-BusyState -Busy $false -Message 'Pronto'
            }
        }
    })
    $cleanupInner.Controls.Add($btnCleanupRun)

    # --- CREDENZIALI UTENTE ---------------------------------------------
    $passwordGroup = New-Object System.Windows.Forms.GroupBox
    $passwordGroup.Text = '  🔑  Credenziali utente  '
    $passwordGroup.Dock = 'Top'
    $passwordGroup.Height = 92
    $passwordGroup.BackColor = $script:ColorPanel
    $passwordGroup.ForeColor = $script:ColorAccent
    $passwordGroup.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $tabMaint.Controls.Add($passwordGroup)

    $passwordInner = New-Object System.Windows.Forms.FlowLayoutPanel
    $passwordInner.Dock = 'Fill'
    $passwordInner.WrapContents = $true
    $passwordInner.BackColor = $script:ColorPanel
    $passwordInner.Padding = New-Object System.Windows.Forms.Padding(10, 6, 10, 6)
    $passwordGroup.Controls.Add($passwordInner)

    $passwordHint = New-Object System.Windows.Forms.Label
    $passwordHint.Text = "La password viene impostata via API ADSI e non transita dalla riga di comando. Richiede la sessione elevata."
    $passwordHint.ForeColor = $script:ColorTextMuted
    $passwordHint.AutoSize = $true
    $passwordHint.Margin = New-Object System.Windows.Forms.Padding(8, 9, 4, 0)
    $passwordInner.Controls.Add($passwordHint)

    $btnPassword = New-ThemedButton -Text '🔑 Cambio password utente' -BackColor $script:ColorPanel -ForeColor $script:ColorAccent
    $btnPassword.Add_Click({
        Invoke-Safe -Context 'Cambio password utente' -Action {
            [void](Show-PasswordChangeDialog)
        }
    })
    $passwordInner.Controls.Add($btnPassword)

    # --- NMAP ------------------------------------------------------------
    $nmapGroup = New-Object System.Windows.Forms.GroupBox
    $nmapGroup.Text = '  🌐  Nmap - scansione di rete  '
    $nmapGroup.Dock = 'Top'
    $nmapGroup.Height = 138
    $nmapGroup.BackColor = $script:ColorPanel
    $nmapGroup.ForeColor = $script:ColorAccent
    $nmapGroup.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $tabMaint.Controls.Add($nmapGroup)

    $nmapInner = New-Object System.Windows.Forms.FlowLayoutPanel
    $nmapInner.Dock = 'Fill'
    $nmapInner.WrapContents = $true
    $nmapInner.BackColor = $script:ColorPanel
    $nmapInner.Padding = New-Object System.Windows.Forms.Padding(10, 6, 10, 6)
    $nmapGroup.Controls.Add($nmapInner)

    $nmapPresetLabel = New-Object System.Windows.Forms.Label
    $nmapPresetLabel.Text = 'Preset:'
    $nmapPresetLabel.ForeColor = $script:ColorTextMuted
    $nmapPresetLabel.AutoSize = $true
    $nmapPresetLabel.Margin = New-Object System.Windows.Forms.Padding(8, 9, 4, 0)
    $nmapInner.Controls.Add($nmapPresetLabel)

    $nmapPreset = New-Object System.Windows.Forms.ComboBox
    $nmapPreset.DropDownStyle = 'DropDownList'
    $nmapPreset.FlatStyle = 'Flat'
    $nmapPreset.Width = 250
    $nmapPreset.BackColor = $script:ColorCardBg
    $nmapPreset.ForeColor = $script:ColorTextMain
    $nmapPreset.Margin = New-Object System.Windows.Forms.Padding(0, 6, 10, 0)
    try {
        foreach ($preset in @(Get-NmapPresetList)) { [void]$nmapPreset.Items.Add($preset.Name) }
        if ($nmapPreset.Items.Count -gt 0) { $nmapPreset.SelectedIndex = 0 }
    } catch { }
    $nmapInner.Controls.Add($nmapPreset)

    $nmapCustomLabel = New-Object System.Windows.Forms.Label
    $nmapCustomLabel.Text = 'Argomenti personalizzati:'
    $nmapCustomLabel.ForeColor = $script:ColorTextMuted
    $nmapCustomLabel.AutoSize = $true
    $nmapCustomLabel.Margin = New-Object System.Windows.Forms.Padding(8, 9, 4, 0)
    $nmapInner.Controls.Add($nmapCustomLabel)

    $nmapCustom = New-Object System.Windows.Forms.TextBox
    $nmapCustom.Width = 250
    $nmapCustom.BackColor = $script:ColorCardBg
    $nmapCustom.ForeColor = $script:ColorTextMain
    $nmapCustom.BorderStyle = 'FixedSingle'
    $nmapCustom.Margin = New-Object System.Windows.Forms.Padding(0, 6, 10, 0)
    $nmapInner.Controls.Add($nmapCustom)

    $btnNmapRun = New-ThemedButton -Text '▶ Esegui scansione Nmap' -BackColor $script:ColorPanel -ForeColor $script:ColorAccent
    $btnNmapRun.Add_Click({ Invoke-Safe -Context 'Scansione Nmap' -Action { Invoke-NmapPresetScan } })
    $nmapInner.Controls.Add($btnNmapRun)

    $nmapHint = New-Object System.Windows.Forms.Label
    $nmapHint.Text = 'Esempio: -sn 192.168.1.0/24   |   gli argomenti personalizzati hanno precedenza sul preset'
    $nmapHint.ForeColor = $script:ColorTextMuted
    $nmapHint.AutoSize = $true
    $nmapHint.Margin = New-Object System.Windows.Forms.Padding(10, 9, 4, 0)
    $nmapInner.Controls.Add($nmapHint)

    $script:Ui.MaintenanceOutput = $maintOutput
    $script:Ui.PrefetchCheck = $chkPrefetch
    $script:Ui.NmapPreset = $nmapPreset
    $script:Ui.NmapCustom = $nmapCustom
    return $tabMaint
}

function Invoke-NmapPresetScan {
    Invoke-Safe -Context 'Scansione Nmap' -Action {
        $command = $null
        $custom = ''
        if ($script:Ui.NmapCustom) { $custom = $script:Ui.NmapCustom.Text }
        $preset = ''
        if ($script:Ui.NmapPreset) { $preset = $script:Ui.NmapPreset.Text }
        if (-not [string]::IsNullOrWhiteSpace($custom)) {
            $command = Get-NmapCommand -Arguments @(ConvertTo-CommandArgumentArray -Text $custom)
        } elseif ($preset) {
            $command = Get-NmapCommand -Preset $preset
        } else {
            $command = Get-NmapCommand
        }
        if (-not $command) {
            [void](Show-Message -Text "Nmap non e' installato su questa postazione.`r`nInstallare Nmap per abilitare le scansioni di rete." -Caption 'CyberMedic - Nmap' -Kind 'Warning')
            return
        }
        $script:Ui.NetBox.Text = ("Scansione in corso: {0} ..." -f $command.Label)
        [void](Start-BackgroundCommand -FilePath $command.FilePath -Arguments $command.Arguments -OnComplete {
            param($text, $exitCode, $cmdArgs)
            $script:Ui.NetBox.Text = ("{0} (exit code {1})`r`n{2}" -f ($cmdArgs -join ' '), $exitCode, $text)
            Update-StatusBar ("Scansione Nmap completata (exit {0})." -f $exitCode)
        })
        Update-StatusBar ("Nmap in esecuzione: {0}" -f $command.Label)
    }
}
