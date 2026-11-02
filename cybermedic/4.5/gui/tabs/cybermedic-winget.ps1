#Requires -Version 5.1
<#
.SYNOPSIS
    CyberMedic 3.0.1 Module - Winget & Office Deployment Engine.
.DESCRIPTION
    Gestore nativo WinForms per l'installazione di applicazioni tramite Winget
    e il deployment automatizzato di Microsoft Office Retail/ProPlus tramite Setup.exe e Basic.xml.
#>

if (Get-Command Write-PoshLog -ErrorAction SilentlyContinue) {
    Write-PoshLog -Message "Iniezione Modulo [Tab 3: Winget & Office Engine] avviata..." -Status '⚡'
}

$TabApp = $script:Tabs["WingetApp"]
if (-not $TabApp) {
    Write-Warning "Tab 'Winget & App' non trovato nella mappa globale di CyberMedic."
    return
}

$GroupOffice = New-Object System.Windows.Forms.GroupBox
$GroupOffice.Text = " Gestione Microsoft Office Suite "
$GroupOffice.Location = New-Object System.Drawing.Point(20, 20)
$GroupOffice.Size = New-Object System.Drawing.Size(480, 260)
$GroupOffice.ForeColor = $script:Theme.TextPrimary
$TabApp.Controls.Add($GroupOffice)

$BtnInstallOffice = New-Object System.Windows.Forms.Button
$BtnInstallOffice.Location = New-Object System.Drawing.Point(25, 40)
$BtnInstallOffice.Size = New-Object System.Drawing.Size(430, 45)
$BtnInstallOffice.Text = "Installa Office (Configurazione Basic.xml)"
$BtnInstallOffice.BackColor = $script:Theme.AccentBlue
$BtnInstallOffice.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$BtnInstallOffice.Font = $script:Theme.FontBold
$GroupOffice.Controls.Add($BtnInstallOffice)

$BtnRepairOffice = New-Object System.Windows.Forms.Button
$BtnRepairOffice.Location = New-Object System.Drawing.Point(25, 110)
$BtnRepairOffice.Size = New-Object System.Drawing.Size(430, 45)
$BtnRepairOffice.Text = "Ripara Installazione Office Esistente"
$BtnRepairOffice.BackColor = $script:Theme.BgMain
$BtnRepairOffice.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$GroupOffice.Controls.Add($BtnRepairOffice)

$BtnUninstallOffice = New-Object System.Windows.Forms.Button
$BtnUninstallOffice.Location = New-Object System.Drawing.Point(25, 180)
$BtnUninstallOffice.Size = New-Object System.Drawing.Size(430, 45)
$BtnUninstallOffice.Text = "Disinstalla Completamente Office (Rinfresco Pulito)"
$BtnUninstallOffice.BackColor = $script:Theme.BgMain
$BtnUninstallOffice.ForeColor = $script:Theme.AccentRed
$BtnUninstallOffice.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$GroupOffice.Controls.Add($BtnUninstallOffice)

$GroupWinget = New-Object System.Windows.Forms.GroupBox
$GroupWinget.Text = " Microsoft Winget Package Manager "
$GroupWinget.Location = New-Object System.Drawing.Point(520, 20)
$GroupWinget.Size = New-Object System.Drawing.Size(530, 260)
$GroupWinget.ForeColor = $script:Theme.TextPrimary
$TabApp.Controls.Add($GroupWinget)

$LblWingetDesc = New-Object System.Windows.Forms.Label
$LblWingetDesc.Text = "Digita l'ID del pacchetto o esegui l'aggiornamento globale del sistema."
$LblWingetDesc.Location = New-Object System.Drawing.Point(25, 40)
$LblWingetDesc.Size = New-Object System.Drawing.Size(480, 25)
$GroupWinget.Controls.Add($LblWingetDesc)

$TxtPackageId = New-Object System.Windows.Forms.TextBox
$TxtPackageId.Location = New-Object System.Drawing.Point(25, 75)
$TxtPackageId.Size = New-Object System.Drawing.Size(320, 30)
$TxtPackageId.BackColor = $script:Theme.BgMain
$TxtPackageId.ForeColor = $script:Theme.TextPrimary
$GroupWinget.Controls.Add($TxtPackageId)

$BtnInstallPkg = New-Object System.Windows.Forms.Button
$BtnInstallPkg.Location = New-Object System.Drawing.Point(360, 72)
$BtnInstallPkg.Size = New-Object System.Drawing.Size(145, 32)
$BtnInstallPkg.Text = "Installa ID"
$BtnInstallPkg.BackColor = $script:Theme.AccentGreen
$BtnInstallPkg.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$BtnInstallPkg.Font = $script:Theme.FontBold
$GroupWinget.Controls.Add($BtnInstallPkg)

$BtnUpgradeAll = New-Object System.Windows.Forms.Button
$BtnUpgradeAll.Location = New-Object System.Drawing.Point(25, 130)
$BtnUpgradeAll.Size = New-Object System.Drawing.Size(480, 45)
$BtnUpgradeAll.Text = "Esegui Aggiornamento Globale (winget upgrade --all)"
$BtnUpgradeAll.BackColor = $script:Theme.BgMain
$BtnUpgradeAll.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$GroupWinget.Controls.Add($BtnUpgradeAll)

$lblStatusTab = New-Object System.Windows.Forms.Label
$lblStatusTab.Text = "Pronto per l'orchestrazione software."
$lblStatusTab.Location = New-Object System.Drawing.Point(20, 295)
$lblStatusTab.Size = New-Object System.Drawing.Size(1030, 25)
$lblStatusTab.Font = $script:Theme.FontBold
$lblStatusTab.ForeColor = $script:Theme.TextSecondary
$TabApp.Controls.Add($lblStatusTab)

function Invoke-OfficeDeployment {
    param([ValidateSet('install', 'configure', 'remove')][string]$Mode)
    $officePath = if ($script:AppConfig -and $script:AppConfig.Paths) { $script:AppConfig.Paths.OfficeTemp } else { Join-Path $env:TEMP "CyberMedic\Office" }
    if (-not (Test-Path $officePath)) { New-Item -ItemType Directory -Path $officePath -Force | Out-Null }
    $setupExe = Join-Path $officePath "setup.exe"
    $configFile = Join-Path $officePath "Basic.xml"
    if (Get-Command Write-PoshLog -ErrorAction SilentlyContinue) { Write-PoshLog -Message "Preparazione file per il deployment di Microsoft Office..." -Status 'INFO' }
    $lblStatusTab.Text = "Stato: Download componenti Office in corso..."
    try {
        if ($script:AppConfig -and $script:AppConfig.URLs -and $script:AppConfig.URLs.OfficeSetup) {
            Invoke-WebRequest -Uri $script:AppConfig.URLs.OfficeSetup -OutFile $setupExe -TimeoutSec 30
        }
        if ($script:AppConfig -and $script:AppConfig.URLs -and $script:AppConfig.URLs.OfficeBasicConfig) {
            Invoke-WebRequest -Uri $script:AppConfig.URLs.OfficeBasicConfig -OutFile $configFile -TimeoutSec 30
        }
    } catch {
        if (Get-Command Write-PoshLog -ErrorAction SilentlyContinue) { Write-PoshLog -Message "Impossibile scaricare gli asset di Office (Verificare connessione o URL)." -Status 'ERROR' }
        $lblStatusTab.Text = "Stato: Errore download Office."
        return
    }
    $argument = if ($Mode -eq 'remove') { "/configure `"$configFile`"" } else { "/configure `"$configFile`"" }
    if (Get-Command Write-PoshLog -ErrorAction SilentlyContinue) { Write-PoshLog -Message "Esecuzione di Setup.exe in modalità silenziosa (/configure)..." -Status '⚡' }
    $lblStatusTab.Text = "Stato: Installazione Office in esecuzione in background..."
    Start-Process -FilePath $setupExe -ArgumentList $argument -Wait
    $lblStatusTab.Text = "Stato: Deployment Office completato."
}

$BtnInstallOffice.Add_Click({ Invoke-OfficeDeployment -Mode 'install' })
$BtnUninstallOffice.Add_Click({ Invoke-OfficeDeployment -Mode 'remove' })

$BtnInstallPkg.Add_Click({
    $pkgId = $TxtPackageId.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($pkgId)) {
        [System.Windows.Forms.MessageBox]::Show("Inserire un ID pacchetto Winget valido.", "CyberMedic Errore", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    $lblStatusTab.Text = "Stato: Installazione pacchetto $pkgId via Winget..."
    Start-Process -FilePath "winget" -ArgumentList "install --id $pkgId --silent --accept-package-agreements --accept-source-agreements" -NoNewWindow -Wait
    $lblStatusTab.Text = "Stato: Operazione Winget conclusa."
})

$BtnUpgradeAll.Add_Click({
    $lblStatusTab.Text = "Stato: Controllo e aggiornamento globale dei software di sistema..."
    Start-Process -FilePath "winget" -ArgumentList "upgrade --all --silent --accept-package-agreements --accept-source-agreements" -NoNewWindow -Wait
    $lblStatusTab.Text = "Stato: Aggiornamento completato."
})

if (Get-Command Write-PoshLog -ErrorAction SilentlyContinue) { Write-PoshLog -Message "Modulo [Tab 3: Winget & Office Engine] agganciato e pronto." -Status 'SUCCESS' }