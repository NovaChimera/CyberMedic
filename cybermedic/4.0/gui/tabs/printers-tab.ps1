#Requires -Version 7.0
$TabPrinters = $script:Tabs["Stampanti"]

$LvPrinters = New-Object System.Windows.Forms.ListView
$LvPrinters.View = [System.Windows.Forms.View]::Details
$LvPrinters.FullRowSelect = $true
$LvPrinters.GridLines = $true
$LvPrinters.Location = New-Object System.Drawing.Point(20, 20)
$LvPrinters.Size = New-Object System.Drawing.Size(1010, 300)
[void]$LvPrinters.Columns.Add("Nome Stampante", 220)
[void]$LvPrinters.Columns.Add("Indirizzo IP / Porta", 150)
[void]$LvPrinters.Columns.Add("Numero di Serie", 180)
[void]$LvPrinters.Columns.Add("Driver Installato", 250)
[void]$LvPrinters.Columns.Add("Stato", 150)
$TabPrinters.Controls.Add($LvPrinters)

$GroupActions = New-Object System.Windows.Forms.GroupBox
$GroupActions.Text = " Azioni Rapide Periferiche Stampa "
$GroupActions.Location = New-Object System.Drawing.Point(20, 340)
$GroupActions.Size = New-Object System.Drawing.Size(1010, 200)
$TabPrinters.Controls.Add($GroupActions)

$BtnWebPage = New-Object System.Windows.Forms.Button
$BtnWebPage.Location = New-Object System.Drawing.Point(25, 40)
$BtnWebPage.Size = New-Object System.Drawing.Size(280, 45)
$BtnWebPage.Text = "Apri Pagina Gestione Web (Interfaccia IP)"
$GroupActions.Controls.Add($BtnWebPage)

$BtnUpdateDriver = New-Object System.Windows.Forms.Button
$BtnUpdateDriver.Location = New-Object System.Drawing.Point(330, 40)
$BtnUpdateDriver.Size = New-Object System.Drawing.Size(280, 45)
$BtnUpdateDriver.Text = "Aggiorna Driver & Firmware Automatico"
$GroupActions.Controls.Add($BtnUpdateDriver)

function Discover-NetworkPrinters {
    $LvPrinters.Items.Clear()
    Write-PoshLog -Message "Interrogazione dello Spooler di stampa..." -Status 'INFO'
    $printers = Get-CimInstance Win32_Printer
    foreach ($printer in $printers) {
        $port = Get-CimInstance Win32_TCPIPPrinterPort -Filter "Name = '$($printer.PortName)'" -ErrorAction SilentlyContinue
        $ip = if ($port) { $port.HostAddress } else { $printer.PortName }
        $item = New-Object System.Windows.Forms.ListViewItem($printer.Name)
        [void]$item.SubItems.Add($ip)
        [void]$item.SubItems.Add("N/D")
        [void]$item.SubItems.Add($printer.DriverName)
        [void]$item.SubItems.Add($printer.PrinterStatus)
        [void]$LvPrinters.Items.Add($item)
    }
}

$BtnWebPage.Add_Click({
    if ($LvPrinters.SelectedItems.Count -gt 0) {
        $ip = $LvPrinters.SelectedItems[0].SubItems[1].Text
        if ($ip -match '^\d{1,3}\.') { Start-Process "http://$ip" }
    }
})

Discover-NetworkPrinters
Apply-DarkThemeToControl -Control $TabPrinters
Apply-DarkThemeToControl -Control $GroupActions
$BtnResetSpooler = New-Object System.Windows.Forms.Button
$BtnResetSpooler.Location = New-Object System.Drawing.Point(625,40)
$BtnResetSpooler.Size = New-Object System.Drawing.Size(360,45)
$BtnResetSpooler.Text = 'Sblocca Spooler di Stampa (Purge Queue)'
$BtnResetSpooler.BackColor = $script:Theme.AccentViolet
$BtnResetSpooler.ForeColor = $script:Theme.TextPrimary
$BtnResetSpooler.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$GroupActions.Controls.Add($BtnResetSpooler)
$BtnResetSpooler.Add_Click({
    Write-PoshLog -Message 'Ripristino spooler di stampa...' -Status '?'
    Stop-Service -Name 'Spooler' -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path "$env:windir\System32\spool\PRINTERS\*" -Include *.shd,*.spl -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Start-Service -Name 'Spooler' -ErrorAction SilentlyContinue
    Write-PoshLog -Message 'Spooler ripristinato.' -Status 'SUCCESS'
})
