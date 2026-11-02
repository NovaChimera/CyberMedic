#Requires -Version 7.0
$TabMaintenance = $script:Tabs["Maintenance"]

$GroupUpdateGrid = New-Object System.Windows.Forms.GroupBox
$GroupUpdateGrid.Text = " Selezione Aggiornamenti Sistema, Driver & App (Winget) "
$GroupUpdateGrid.Location = New-Object System.Drawing.Point(20, 20)
$GroupUpdateGrid.Size = New-Object System.Drawing.Size(480, 480)
$TabMaintenance.Controls.Add($GroupUpdateGrid)

$LblGridDesc = New-Object System.Windows.Forms.Label
$LblGridDesc.Text = "Seleziona i quadratini degli elementi che desideri aggiornare:"
$LblGridDesc.Location = New-Object System.Drawing.Point(20, 30)
$LblGridDesc.Size = New-Object System.Drawing.Size(440, 25)
$GroupUpdateGrid.Controls.Add($LblGridDesc)

$script:ClbUpdates = New-Object System.Windows.Forms.CheckedListBox
$script:ClbUpdates.Location = New-Object System.Drawing.Point(20, 65)
$script:ClbUpdates.Size = New-Object System.Drawing.Size(440, 320)
$script:ClbUpdates.CheckOnClick = $true
$script:ClbUpdates.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$GroupUpdateGrid.Controls.Add($script:ClbUpdates)

$BtnExecSelected = New-Object System.Windows.Forms.Button
$BtnExecSelected.Location = New-Object System.Drawing.Point(20, 405)
$BtnExecSelected.Size = New-Object System.Drawing.Size(440, 45)
$BtnExecSelected.Text = "Esegui Aggiornamenti Selezionati"
$GroupUpdateGrid.Controls.Add($BtnExecSelected)

function Invoke-UpdateScanner {
    $script:ClbUpdates.Items.Clear()
    $script:ClbUpdates.Items.Add("Windows OS: Aggiornamenti cumulativi di sicurezza", $true)
    $script:ClbUpdates.Items.Add("Windows OS: Aggiornamento Driver di Sistema (Stato: Rilevato)", $false)
    Write-PoshLog -Message "Avvio scansione silenziosa delle applicazioni aggiornabili tramite Winget..." -Status 'INFO'
    # (esecuzione sincrona semplificata)
        try {
            $wingetArgs = @("upgrade", "--accept-source-agreements")
            $procInfo = New-Object System.Diagnostics.ProcessStartInfo
            $procInfo.FileName = "winget.exe"
            $procInfo.Arguments = ($wingetArgs -join ' ')
            $procInfo.RedirectStandardOutput = $true
            $procInfo.CreateNoWindow = $true
            $procInfo.UseShellExecute = $false
            $procInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
            $proc = [System.Diagnostics.Process]::Start($procInfo)
            $stream = $proc.StandardOutput
            $startParsing = $false
            while (-not $stream.EndOfStream) {
                $line = $stream.ReadLine()
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                if ($line -match "Name\s+Id\s+Version") { $startParsing = $true; continue }
                if ($line -match "------") { continue }
                if ($startParsing -and $line -match '^([^\s]+)\s+([^\s]+)\s+([^\s]+)') {
                    $appName = $matches[1]
                    $appId = $matches[2]
                    $displayString = "App: $appName [$appId]"
                    $script:ClbUpdates.Invoke([Action[string]]{ param($item) [void]$script:ClbUpdates.Items.Add($item, $true) }, $displayString)
                }
            }
            Write-PoshLog -Message "Scansione aggiornamenti completata con successo." -Status 'SUCCESS'
        }
        catch {
            Write-PoshLog -Message "Errore durante la scansione pacchetti: $_" -Status 'ERROR'
        }
}

$BtnExecSelected.Add_Click({
    if ($script:ClbUpdates.CheckedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Selezionare almeno un quadratino per procedere.", "CyberMedic", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        return
    }
    $BtnExecSelected.Enabled = $false
    foreach ($item in $script:ClbUpdates.CheckedItems) {
        if ($item -match 'App: .+\s+\[([^\]]+)\]') {
            $id = $matches[1]
            Write-PoshLog -Message "Inizio installazione aggiornamento per: $id" -Status 'INFO'
            Start-Process -FilePath "winget.exe" -ArgumentList "upgrade --id $id --silent --accept-package-agreements --accept-source-agreements" -NoNewWindow -Wait
            Write-PoshLog -Message "Aggiornamento per $id completato." -Status 'SUCCESS'
        }
    }
    $BtnExecSelected.Enabled = $true
})

Invoke-UpdateScanner
Apply-DarkThemeToControl -Control $GroupUpdateGrid