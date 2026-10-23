# CyberMedic - Scheda modulare: Cybersecurity (strumenti di rete, ripristino
# rete e diagnostica di sicurezza).
# Caricata da CyberMedic_GUI.ps1 tramite dot-sourcing.

function New-CybersecurityTab {
    param([Parameter(Mandatory = $true)]$MainTabs)

    $tabCyber = New-Object System.Windows.Forms.TabPage('  🛡️  Cybersecurity  ')
    $tabCyber.BackColor = $script:ColorBgMain
    $tabCyber.ForeColor = $script:ColorAccent
    $tabCyber.Padding = New-Object System.Windows.Forms.Padding(8)
    $MainTabs.TabPages.Add($tabCyber)

    $cyberOutput = New-Object System.Windows.Forms.TextBox
    $cyberOutput.Multiline = $true
    $cyberOutput.ReadOnly = $true
    $cyberOutput.ScrollBars = 'Both'
    $cyberOutput.WordWrap = $false
    $cyberOutput.Dock = 'Fill'
    $cyberOutput.BackColor = $script:ColorCardBg
    $cyberOutput.ForeColor = $script:ColorSuccess
    $cyberOutput.Font = New-Object System.Drawing.Font('Consolas', 9.5)
    $cyberOutput.BorderStyle = 'None'
    $tabCyber.Controls.Add($cyberOutput)

    # --- CARD STRUMENTI DI RETE (spostati da Network & Rete) ---------------
    $netToolsInner = New-Object System.Windows.Forms.FlowLayoutPanel
    $netToolsInner.Dock = 'Fill'
    $netToolsInner.WrapContents = $true
    $netToolsInner.BackColor = $script:ColorCardBg
    $netToolsInner.Padding = New-Object System.Windows.Forms.Padding(14, 12, 14, 12)

    $netToolsCard = New-FluentCard -Title '  🌐  Strumenti di rete  ' -Content $netToolsInner -Height 150
    $tabCyber.Controls.Add($netToolsCard)

    $netToolsHint = New-Object System.Windows.Forms.Label
    $netToolsHint.Text = 'Diagnostica della postazione: configurazione IP, radio Wi-Fi, acquisizione del traffico e scansione di rete.'
    $netToolsHint.ForeColor = $script:ColorTextMuted
    $netToolsHint.Font = Get-FluentFont -Size 9
    $netToolsHint.AutoSize = $false
    $netToolsHint.Size = New-Object System.Drawing.Size(560, 22)
    $netToolsHint.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 8)
    $netToolsInner.Controls.Add($netToolsHint)

    $btnNetAll = New-ThemedButton -Text '📋 Info complete (/all)' -BackColor $script:ColorPanel -ForeColor $script:ColorTextMain
    $btnNetAll.Add_Click({
        Invoke-Safe -Context 'Info di rete complete' -Action {
            $script:Ui.CyberOutput.Text = 'Esecuzione in corso: ipconfig /all ...'
            [void](Start-BackgroundCommand -FilePath 'ipconfig.exe' -Arguments @('/all') -OnComplete {
                param($text, $exitCode, $cmdArgs)
                $script:Ui.CyberOutput.Text = ("ipconfig /all (exit code {0})`r`n{1}" -f $exitCode, $text)
                Update-StatusBar ("ipconfig /all completato (exit {0})." -f $exitCode)
            })
            Update-StatusBar 'ipconfig /all in esecuzione...'
        }
    })
    $netToolsInner.Controls.Add($btnNetAll)

    $btnNetRenew = New-ThemedButton -Text '🔄 Rinnova IP (/renew)' -BackColor $script:ColorPanel -ForeColor $script:ColorTextMain
    $btnNetRenew.Add_Click({
        Invoke-Safe -Context 'Rinnovo IP' -Action {
            $script:Ui.CyberOutput.Text = 'Esecuzione in corso: ipconfig /renew ...'
            [void](Start-BackgroundCommand -FilePath 'ipconfig.exe' -Arguments @('/renew') -OnComplete {
                param($text, $exitCode, $cmdArgs)
                $script:Ui.CyberOutput.Text = ("ipconfig /renew (exit code {0})`r`n{1}" -f $exitCode, $text)
                Update-StatusBar ("ipconfig /renew completato (exit {0})." -f $exitCode)
            })
            Update-StatusBar 'ipconfig /renew in esecuzione...'
        }
    })
    $netToolsInner.Controls.Add($btnNetRenew)

    $btnWifi = New-ThemedButton -Text '📶 Info Wi-Fi avanzate' -BackColor $script:ColorPanel -ForeColor $script:ColorSuccess
    $btnWifi.Add_Click({
        Invoke-Safe -Context 'Inventario Wi-Fi' -Action {
            $result = Get-WifiDetails
            $script:Ui.CyberOutput.Text = $result.Detail
            Update-StatusBar $result.Message
        }
    })
    $netToolsInner.Controls.Add($btnWifi)

    $btnWireshark = New-ThemedButton -Text '🦈 Wireshark' -BackColor $script:ColorPanel -ForeColor $script:ColorTextMain
    $btnWireshark.Add_Click({
        Invoke-Safe -Context 'Avvio Wireshark' -Action {
            if (-not (Start-WiresharkTool)) {
                [void](Show-Message -Text "Wireshark non e' installato su questa postazione.`r`nInstallarlo per procedere con l'acquisizione del traffico." -Caption 'CyberMedic - Wireshark' -Kind 'Warning')
            }
        }
    })
    $netToolsInner.Controls.Add($btnWireshark)

    $btnNmap = New-ThemedButton -Text '🌐 Nmap Scan (localhost)' -BackColor $script:ColorPanel -ForeColor $script:ColorTextMain
    $btnNmap.Add_Click({
        Invoke-Safe -Context 'Scansione Nmap' -Action {
            $scan = Get-NmapScanCommand -Target '127.0.0.1'
            if (-not $scan) {
                [void](Show-Message -Text "Nmap non e' installato su questa postazione.`r`nLa scansione viene eseguita solo sul localhost, per non esporre la postazione." -Caption 'CyberMedic - Nmap' -Kind 'Warning')
                return
            }
            $script:Ui.CyberOutput.Text = ("Scansione in corso: {0} ..." -f $scan.Label)
            [void](Start-BackgroundCommand -FilePath $scan.FilePath -Arguments $scan.Arguments -OnComplete {
                param($text, $exitCode, $cmdArgs)
                $script:Ui.CyberOutput.Text = ("{0} (exit code {1})`r`n{2}" -f ($cmdArgs -join ' '), $exitCode, $text)
                Update-StatusBar ("Scansione completata (exit {0})." -f $exitCode)
            })
            Update-StatusBar ("Nmap in esecuzione: {0}" -f $scan.Label)
        }
    })
    $netToolsInner.Controls.Add($btnNmap)

    # --- RIPARAZIONE DELLA RETE -----------------------------------------
    $repairGroup = New-Object System.Windows.Forms.GroupBox
    $repairGroup.Text = '  🛠️  Ripristino e riparazione rete  '
    $repairGroup.Dock = 'Top'
    $repairGroup.Height = 168
    $repairGroup.BackColor = $script:ColorPanel
    $repairGroup.ForeColor = $script:ColorAccent
    $repairGroup.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $tabCyber.Controls.Add($repairGroup)

    $repairInner = New-Object System.Windows.Forms.FlowLayoutPanel
    $repairInner.Dock = 'Fill'
    $repairInner.WrapContents = $true
    $repairInner.BackColor = $script:ColorPanel
    $repairInner.Padding = New-Object System.Windows.Forms.Padding(10, 6, 10, 6)
    $repairGroup.Controls.Add($repairInner)

    $repairHint = New-Object System.Windows.Forms.Label
    $repairHint.Text = 'I comandi che richiedono elevazione riavviano CyberMedic come amministratore. Alcune riparazioni richiedono un riavvio del PC.'
    $repairHint.ForeColor = $script:ColorTextMuted
    $repairHint.AutoSize = $true
    $repairHint.Margin = New-Object System.Windows.Forms.Padding(8, 9, 4, 0)
    $repairInner.Controls.Add($repairHint)

    try {
        $catalog = @(Get-NetworkRepairCatalog)
    } catch {
        $catalog = @()
    }
    foreach ($item in $catalog) {
        $entry = $item
        $caption = $entry.Label
        if ($entry.Elevated) { $caption = $caption + '  ⬆' }
        $button = New-ThemedButton -Text $caption -BackColor $script:ColorPanel -ForeColor $script:ColorTextMain
        $button.Tag = $entry.Id
        $button.Add_Click({
            param($sender, $eventArgs)
            Invoke-Safe -Context 'Riparazione rete' -Action {
                $id = [string]$sender.Tag
                $command = Get-NetworkRepairCommand -Component $id
                if (-not $command) {
                    [void](Show-Message -Text ("Comando non disponibile per '{0}'." -f $id) -Caption 'CyberMedic - Cybersecurity' -Kind 'Warning')
                    return
                }
                if ($command.Elevated -and -not (Test-AdminState)) {
                    $answer = Show-Message -Text ("{0}`r`nrichiede una sessione elevata. Riavviare CyberMedic come amministratore?" -f $command.Label) -Caption 'CyberMedic - Cybersecurity' -Kind 'Question'
                    if ($answer -eq [System.Windows.Forms.DialogResult]::Yes) {
                        [void](Request-Elevation)
                        return
                    }
                }
                $script:Ui.CyberOutput.Text = ("{0} in corso..." -f $command.Label)
                [void](Start-BackgroundCommand -FilePath $command.FilePath -Arguments $command.Arguments -OnComplete {
                    param($text, $exitCode, $cmdArgs)
                    $script:Ui.CyberOutput.Text = ("{0} (exit code {1})`r`n{2}" -f $command.Label, $exitCode, $text)
                    Update-StatusBar ("{0}: exit {1}" -f $command.Label, $exitCode)
                })
                Update-StatusBar ("{0} in esecuzione..." -f $command.Label)
            }
        })
        $repairInner.Controls.Add($button)
    }

    # --- DIAGNOSTICA DI SICUREZZA ----------------------------------------
    $securityGroup = New-Object System.Windows.Forms.GroupBox
    $securityGroup.Text = '  🔍  Diagnostica di sicurezza  '
    $securityGroup.Dock = 'Top'
    $securityGroup.Height = 122
    $securityGroup.BackColor = $script:ColorPanel
    $securityGroup.ForeColor = $script:ColorAccent
    $securityGroup.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $tabCyber.Controls.Add($securityGroup)

    $securityInner = New-Object System.Windows.Forms.FlowLayoutPanel
    $securityInner.Dock = 'Fill'
    $securityInner.WrapContents = $true
    $securityInner.BackColor = $script:ColorPanel
    $securityInner.Padding = New-Object System.Windows.Forms.Padding(10, 6, 10, 6)
    $securityGroup.Controls.Add($securityInner)

    $defenderLabel = New-Object System.Windows.Forms.Label
    $defenderLabel.Text = 'Stato Defender: in valutazione...'
    $defenderLabel.ForeColor = $script:ColorTextMuted
    $defenderLabel.AutoSize = $true
    $defenderLabel.Margin = New-Object System.Windows.Forms.Padding(8, 9, 4, 0)
    $securityInner.Controls.Add($defenderLabel)

    $btnSecurityReport = New-ThemedButton -Text '🔍 Report sicurezza' -BackColor $script:ColorPanel -ForeColor $script:ColorAccent
    $btnSecurityReport.Add_Click({
        Invoke-Safe -Context 'Report di sicurezza' -Action {
            $report = @(Get-SecurityQuickScan)
            $script:Ui.CyberOutput.Text = ($report -join [Environment]::NewLine)
            Update-StatusBar ('Report di sicurezza generato ({0} righe).' -f $report.Count)
        }
    })
    $securityInner.Controls.Add($btnSecurityReport)

    $btnHostsAnalysis = New-ThemedButton -Text '📄 Analisi file hosts' -BackColor $script:ColorPanel -ForeColor $script:ColorTextMain
    $btnHostsAnalysis.Add_Click({
        Invoke-Safe -Context 'Analisi del file hosts' -Action {
            $hosts = Get-HostsFileAnalysis
            $lines = New-Object System.Collections.Generic.List[string]
            $lines.Add(("File hosts : {0}" -f $hosts.Path))
            $lines.Add(("Rilevato   : {0}" -f $hosts.Found))
            $lines.Add(("Riepilogo  : {0}" -f $hosts.Summary))
            $lines.Add('')
            foreach ($entry in @($hosts.Entries)) {
                $lines.Add(("{0,5}  {1,-16}  {2}" -f $entry.Line, $entry.Address, $entry.Host))
            }
            if (@($hosts.Suspicious).Count -gt 0) {
                $lines.Add('')
                $lines.Add('--- Voci sospette ---')
                foreach ($entry in @($hosts.Suspicious)) {
                    $lines.Add(("riga {0}: {1} -> {2} ({3})" -f $entry.Line, $entry.Address, $entry.Host, $entry.Reason))
                }
            }
            $script:Ui.CyberOutput.Text = ($lines -join [Environment]::NewLine)
            Update-StatusBar ("Analisi file hosts completata: {0} voci." -f @($hosts.Entries).Count)
        }
    })
    $securityInner.Controls.Add($btnHostsAnalysis)

    $btnDefenderScan = New-ThemedButton -Text '🛡️ Scansione rapida Defender' -BackColor $script:ColorPanel -ForeColor $script:ColorSuccess
    $btnDefenderScan.Add_Click({
        Invoke-Safe -Context 'Scansione rapida Defender' -Action {
            $result = Start-DefenderQuickScan
            $script:Ui.CyberOutput.Text = $result.Message
            [void](Show-Message -Text $result.Message -Caption 'CyberMedic - Defender' -Kind $(if ($result.Success) { 'Info' } else { 'Warning' }))
            Update-StatusBar 'Scansione rapida richiesta a Microsoft Defender.'
        }
    })
    $securityInner.Controls.Add($btnDefenderScan)

    $btnDefenderRefresh = New-ThemedButton -Text '🔄 Aggiorna stato' -BackColor $script:ColorPanel -ForeColor $script:ColorTextMain
    $btnDefenderRefresh.Add_Click({
        Invoke-Safe -Context 'Aggiornamento stato Defender' -Action { Update-CyberDefenderLabel }
    })
    $securityInner.Controls.Add($btnDefenderRefresh)

    $script:Ui.CyberOutput = $cyberOutput
    $script:Ui.DefenderLabel = $defenderLabel

    Update-CyberDefenderLabel
    return $tabCyber
}

function Update-CyberDefenderLabel {
    if (-not $script:Ui.DefenderLabel) { return }
    try {
        $defender = Get-DefenderStatus
        $script:Ui.DefenderLabel.Text = ("Antivirus: {0} | Protezione in tempo reale: {1} | Definizioni: {2} giorni | Ultima scansione: {3}" -f
            $(if ($defender.Available) { 'Microsoft Defender' } else { 'non disponibile' }),
            $defender.RealTime,
            $(if ($null -ne $defender.SignatureAge) { $defender.SignatureAge } else { 'N/D' }),
            $defender.LastScan)
    } catch {
        $script:Ui.DefenderLabel.Text = 'Stato Defender non leggibile.'
    }
}
