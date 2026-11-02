#Requires -Version 7.0
# Tab 2: Pipeline - Riparazione Sistemica
$TabPipeline = $script:Tabs["WingetApp"]
if (-not $TabPipeline) { return }

$BtnRepair = New-Object System.Windows.Forms.Button
$BtnRepair.Location = New-Object System.Drawing.Point(20, 20)
$BtnRepair.Size = New-Object System.Drawing.Size(300, 45)
$BtnRepair.Text = "Repair Component Store (DISM)"
$BtnRepair.BackColor = $script:Theme.AccentBlue
$BtnRepair.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$TabPipeline.Controls.Add($BtnRepair)

$BtnRepair.Add_Click({
    Write-PoshLog -Message "Avvio DISM /RestoreHealth..." -Status '⚡'
    Start-Process -FilePath "dism.exe" -ArgumentList "/Online /Cleanup-Image /RestoreHealth" -Wait -NoNewWindow
    Write-PoshLog -Message "DISM completato." -Status 'SUCCESS'
})

$BtnResetWU = New-Object System.Windows.Forms.Button
$BtnResetWU.Location = New-Object System.Drawing.Point(20, 75)
$BtnResetWU.Size = New-Object System.Drawing.Size(300, 45)
$BtnResetWU.Text = "Reset Windows Update"
$BtnResetWU.BackColor = $script:Theme.AccentViolet
$BtnResetWU.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$TabPipeline.Controls.Add($BtnResetWU)

$BtnResetWU.Add_Click({
    Write-PoshLog -Message "Arresto servizi WU..." -Status 'INFO'
    Stop-Service wuauserv, bits, cryptsvc -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:windir\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service wuauserv, bits, cryptsvc -ErrorAction SilentlyContinue
    Write-PoshLog -Message "Windows Update resettato." -Status 'SUCCESS'
})

$BtnCleanup = New-Object System.Windows.Forms.Button
$BtnCleanup.Location = New-Object System.Drawing.Point(20, 130)
$BtnCleanup.Size = New-Object System.Drawing.Size(300, 45)
$BtnCleanup.Text = "Pulizia Sistema"
$BtnCleanup.BackColor = $script:Theme.BgMain
$BtnCleanup.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$TabPipeline.Controls.Add($BtnCleanup)

$BtnCleanup.Add_Click({
    Write-PoshLog -Message "Pulizia file temporanei..." -Status 'INFO'
    Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:windir\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-PoshLog -Message "Pulizia completata." -Status 'SUCCESS'
})

Apply-DarkThemeToControl -Control $TabPipeline