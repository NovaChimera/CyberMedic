#Requires -Version 7.0
$TabDash = $script:Tabs["Dashboard"]

$GroupWmi = New-Object System.Windows.Forms.GroupBox
$GroupWmi.Text = " Informazioni Hardware & Stato Sistema "
$GroupWmi.Location = New-Object System.Drawing.Point(20, 20)
$GroupWmi.Size = New-Object System.Drawing.Size(1010, 250)
$TabDash.Controls.Add($GroupWmi)

$TxtWmiOutput = New-Object System.Windows.Forms.TextBox
$TxtWmiOutput.Multiline = $true
$TxtWmiOutput.ReadOnly = $true
$TxtWmiOutput.ScrollBars = "Vertical"
$TxtWmiOutput.Location = New-Object System.Drawing.Point(20, 30)
$TxtWmiOutput.Size = New-Object System.Drawing.Size(970, 200)
$GroupWmi.Controls.Add($TxtWmiOutput)

$GroupOfficeConfig = New-Object System.Windows.Forms.GroupBox
$GroupOfficeConfig.Text = " Configurazione e Deployment Microsoft Office "
$GroupOfficeConfig.Location = New-Object System.Drawing.Point(20, 290)
$GroupOfficeConfig.Size = New-Object System.Drawing.Size(1010, 250)
$TabDash.Controls.Add($GroupOfficeConfig)

$LblChannel = New-Object System.Windows.Forms.Label
$LblChannel.Text = "Canale di Aggiornamento:"
$LblChannel.Location = New-Object System.Drawing.Point(25, 40)
$LblChannel.Size = New-Object System.Drawing.Size(180, 25)
$GroupOfficeConfig.Controls.Add($LblChannel)

$CmbChannel = New-Object System.Windows.Forms.ComboBox
$CmbChannel.Location = New-Object System.Drawing.Point(210, 37)
$CmbChannel.Size = New-Object System.Drawing.Size(200, 30)
$CmbChannel.Items.AddRange(@("Current", "MonthlyEnterprise", "SemiAnnual"))
$CmbChannel.SelectedIndex = 0
$GroupOfficeConfig.Controls.Add($CmbChannel)

$BtnLaunchOfficeJob = New-Object System.Windows.Forms.Button
$BtnLaunchOfficeJob.Location = New-Object System.Drawing.Point(25, 90)
$BtnLaunchOfficeJob.Size = New-Object System.Drawing.Size(385, 45)
$BtnLaunchOfficeJob.Text = "Distribuisci Office con parametri selezionati"
$GroupOfficeConfig.Controls.Add($BtnLaunchOfficeJob)

function Get-CompleteTelemetry {
    $cpu = (Get-CimInstance Win32_Processor).Name
    $ram = [Math]::Round((Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1GB, 2)
    $gpu = (Get-CimInstance Win32_VideoController).Name
    $os = (Get-CimInstance Win32_OperatingSystem).Caption
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("SISTEMA OPERATIVO: $os")
    [void]$sb.AppendLine("PROCESSORE: $cpu")
    [void]$sb.AppendLine("MEMORIA RAM: $ram GB")
    [void]$sb.AppendLine("SCHEDA GRAFICA: $gpu")
    [void]$sb.AppendLine("PRIVILEGI UAC: $(if (Test-Administrator) {'Amministratore'} else {'Utente Standard'})")
    $TxtWmiOutput.Text = $sb.ToString()
}

$BtnLaunchOfficeJob.Add_Click({
    Write-PoshLog -Message "Avvio installazione Office in background (Canale: $($CmbChannel.SelectedItem))..." -Status '⚡'
})

Get-CompleteTelemetry
Apply-DarkThemeToControl -Control $GroupWmi
Apply-DarkThemeToControl -Control $GroupOfficeConfig