#Requires -Version 7.0
$TabCrypto = $script:Tabs["Cybersecurity"]

$GroupNetworkSec = New-Object System.Windows.Forms.GroupBox
$GroupNetworkSec.Text = " Analisi Vulnerabilità Rete Locale & Porte Aperte "
$GroupNetworkSec.Location = New-Object System.Drawing.Point(20, 20)
$GroupNetworkSec.Size = New-Object System.Drawing.Size(1010, 520)
$TabCrypto.Controls.Add($GroupNetworkSec)

$BtnScanPorts = New-Object System.Windows.Forms.Button
$BtnScanPorts.Location = New-Object System.Drawing.Point(25, 40)
$BtnScanPorts.Size = New-Object System.Drawing.Size(300, 45)
$BtnScanPorts.Text = "Scansiona Porte Aperte"
$GroupNetworkSec.Controls.Add($BtnScanPorts)

$BtnLaunchWireshark = New-Object System.Windows.Forms.Button
$BtnLaunchWireshark.Location = New-Object System.Drawing.Point(340, 40)
$BtnLaunchWireshark.Size = New-Object System.Drawing.Size(300, 45)
$BtnLaunchWireshark.Text = "Avvia Ispezione Pacchetti (Wireshark)"
$GroupNetworkSec.Controls.Add($BtnLaunchWireshark)

$TxtSecConsole = New-Object System.Windows.Forms.TextBox
$TxtSecConsole.Multiline = $true
$TxtSecConsole.ReadOnly = $true
$TxtSecConsole.ScrollBars = "Vertical"
$TxtSecConsole.Location = New-Object System.Drawing.Point(25, 110)
$TxtSecConsole.Size = New-Object System.Drawing.Size(960, 380)
$GroupNetworkSec.Controls.Add($TxtSecConsole)

$BtnScanPorts.Add_Click({
    $TxtSecConsole.Clear()
    Write-PoshLog -Message "Scansione porte avviata..." -Status '⚡'
})

$BtnDefenderScan = New-Object System.Windows.Forms.Button
$BtnDefenderScan.Location = New-Object System.Drawing.Point(655, 40)
$BtnDefenderScan.Size = New-Object System.Drawing.Size(330, 45)
$BtnDefenderScan.Text = "Avvia Scansione Rapida Windows Defender"
$GroupNetworkSec.Controls.Add($BtnDefenderScan)

$BtnDefenderScan.Add_Click({
    Write-PoshLog -Message "Avvio scansione rapida Defender..." -Status 'INFO'
    try {
        Start-MpScan -ScanType QuickScan -ErrorAction SilentlyContinue
        Write-PoshLog -Message "Scansione Defender avviata." -Status 'SUCCESS'
    } catch {
        Write-PoshLog -Message "Errore avvio scansione Defender: $_" -Status 'ERROR'
    }
})

$BtnNetRepair = New-Object System.Windows.Forms.Button
$BtnNetRepair.Location = New-Object System.Drawing.Point(25, 90)
$BtnNetRepair.Size = New-Object System.Drawing.Size(300, 45)
$BtnNetRepair.Text = "Ripristino Rete (Winsock/IP/DNS)"
$GroupNetworkSec.Controls.Add($BtnNetRepair)

$BtnNetRepair.Add_Click({
    Write-PoshLog -Message "Avvio ripristino rete..." -Status '⚡'
    netsh winsock reset | Out-Null
    netsh int ip reset | Out-Null
    ipconfig /flushdns | Out-Null
    ipconfig /release | Out-Null
    ipconfig /renew | Out-Null
    Write-PoshLog -Message "Ripristino rete completato." -Status 'SUCCESS'
})

Apply-DarkThemeToControl -Control $TabCrypto

$BtnLaunchWireshark.Add_Click({
    if (Test-Path "C:\Program Files\Wireshark\Wireshark.exe") {
        Start-Process "C:\Program Files\Wireshark\Wireshark.exe"
    } else {
        Write-PoshLog -Message "Wireshark non rilevato." -Status 'WARN'
    }
})

Apply-DarkThemeToControl -Control $TabCrypto