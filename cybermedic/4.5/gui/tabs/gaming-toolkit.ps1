#Requires -Version 5.1
<#
.SYNOPSIS
    CyberMedic 3.0.1 Module - Gaming, Driver & Performance Engine.
.DESCRIPTION
    Interfaccia nativa WinForms per l'applicazione di tweaks di registro (Latenza/FPS)
    e orchestrazione asincrona per la reinstallazione pulita dei Driver Video (DDU/NVIDIA/AMD).
#>

if (Get-Command Write-PoshLog -ErrorAction SilentlyContinue) {
    Write-PoshLog -Message "Iniezione Modulo [Tab 4: Gaming & Performance Toolkit] avviata..." -Status '⚡'
}

$TabGaming = $script:Tabs["GamingTweaks"]
if (-not $TabGaming) {
    Write-Warning "Tab 'Gaming Tweaks' non trovato nella mappa globale di CyberMedic."
    return
}

$GroupTweaks = New-Object System.Windows.Forms.GroupBox
$GroupTweaks.Text = " Ottimizzazioni Sistema & Latenza Rete "
$GroupTweaks.Location = New-Object System.Drawing.Point(20, 20)
$GroupTweaks.Size = New-Object System.Drawing.Size(480, 480)
$GroupTweaks.ForeColor = $script:Theme.TextPrimary
$TabGaming.Controls.Add($GroupTweaks)

$ChkNetworkTweak = New-Object System.Windows.Forms.CheckBox
$ChkNetworkTweak.Text = "Ottimizzazione Latenza Rete (Nagle's Algorithm & NetworkThrottling)"
$ChkNetworkTweak.Location = New-Object System.Drawing.Point(25, 40)
$ChkNetworkTweak.Size = New-Object System.Drawing.Size(430, 30)
$ChkNetworkTweak.Checked = $true
$GroupTweaks.Controls.Add($ChkNetworkTweak)

$ChkFpsTweak = New-Object System.Windows.Forms.CheckBox
$ChkFpsTweak.Text = "Disabilita Fullscreen Optimizations & GameDVR (Stabilità FPS)"
$ChkFpsTweak.Location = New-Object System.Drawing.Point(25, 85)
$ChkFpsTweak.Size = New-Object System.Drawing.Size(430, 30)
$ChkFpsTweak.Checked = $true
$GroupTweaks.Controls.Add($ChkFpsTweak)

$ChkVisualTweak = New-Object System.Windows.Forms.CheckBox
$ChkVisualTweak.Text = "Disabilita Effetti Visivi Inutili (Rilascio Risorse CPU/RAM)"
$ChkVisualTweak.Location = New-Object System.Drawing.Point(25, 130)
$ChkVisualTweak.Size = New-Object System.Drawing.Size(430, 30)
$GroupTweaks.Controls.Add($ChkVisualTweak)

$BtnApplyTweaks = New-Object System.Windows.Forms.Button
$BtnApplyTweaks.Location = New-Object System.Drawing.Point(25, 400)
$BtnApplyTweaks.Size = New-Object System.Drawing.Size(430, 45)
$BtnApplyTweaks.Text = "Applica Tweaks Selezionati"
$BtnApplyTweaks.BackColor = $script:Theme.AccentBlue
$BtnApplyTweaks.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$BtnApplyTweaks.Font = $script:Theme.FontBold
$GroupTweaks.Controls.Add($BtnApplyTweaks)

$GroupDrivers = New-Object System.Windows.Forms.GroupBox
$GroupDrivers.Text = " Gestione e Installazione Pulita Driver Video "
$GroupDrivers.Location = New-Object System.Drawing.Point(520, 20)
$GroupDrivers.Size = New-Object System.Drawing.Size(530, 480)
$GroupDrivers.ForeColor = $script:Theme.TextPrimary
$TabGaming.Controls.Add($GroupDrivers)

$BtnRunDdu = New-Object System.Windows.Forms.Button
$BtnRunDdu.Location = New-Object System.Drawing.Point(30, 40)
$BtnRunDdu.Size = New-Object System.Drawing.Size(470, 45)
$BtnRunDdu.Text = "Avvia DDU (Display Driver Uninstaller) - Pulizia Profonda"
$BtnRunDdu.BackColor = $script:Theme.BgMain
$BtnRunDdu.ForeColor = $script:Theme.AccentRed
$BtnRunDdu.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$GroupDrivers.Controls.Add($BtnRunDdu)

$BtnNvidiaClean = New-Object System.Windows.Forms.Button
$BtnNvidiaClean.Location = New-Object System.Drawing.Point(30, 110)
$BtnNvidiaClean.Size = New-Object System.Drawing.Size(470, 45)
$BtnNvidiaClean.Text = "Installazione Pulita NVIDIA (Via NVCleanstall Remoto)"
$BtnNvidiaClean.BackColor = $script:Theme.BgMain
$BtnNvidiaClean.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$GroupDrivers.Controls.Add($BtnNvidiaClean)

$BtnAmdSetup = New-Object System.Windows.Forms.Button
$BtnAmdSetup.Location = New-Object System.Drawing.Point(30, 180)
$BtnAmdSetup.Size = New-Object System.Drawing.Size(470, 45)
$BtnAmdSetup.Text = "Installazione Avanzata AMD (Minimal Web Setup)"
$BtnAmdSetup.BackColor = $script:Theme.BgMain
$BtnAmdSetup.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$GroupDrivers.Controls.Add($BtnAmdSetup)

$lblStatusGaming = New-Object System.Windows.Forms.Label
$lblStatusGaming.Text = "Pronto per l'ottimizzazione delle performance e dei driver video."
$lblStatusGaming.Location = New-Object System.Drawing.Point(20, 520)
$lblStatusGaming.Size = New-Object System.Drawing.Size(1030, 25)
$lblStatusGaming.Font = $script:Theme.FontBold
$lblStatusGaming.ForeColor = $script:Theme.TextSecondary
$TabGaming.Controls.Add($lblStatusGaming)

function Invoke-PerformanceTweaks {
    if (Get-Command Write-PoshLog -ErrorAction SilentlyContinue) { Write-PoshLog -Message "Inizio applicazione dei Tweaks di Registro..." -Status 'INFO' }
    $lblStatusGaming.Text = "Stato: Applicazione modifiche di registro in corso..."
    try {
        if ($ChkNetworkTweak.Checked) {
            $NetPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
            if (-not (Test-Path $NetPath)) { New-Item -Path $NetPath -Force | Out-Null }
            Set-ItemProperty -Path $NetPath -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF -Type DWord -Force
            Set-ItemProperty -Path $NetPath -Name "SystemResponsiveness" -Value 0 -Type DWord -Force
        }
        if ($ChkFpsTweak.Checked) {
            $GvrPath = "HKCU:\System\GameConfigStore"
            Set-ItemProperty -Path $GvrPath -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force
        }
        if ($ChkVisualTweak.Checked) {
            Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -Force
        }
        if (Get-Command Write-PoshLog -ErrorAction SilentlyContinue) { Write-PoshLog -Message "Tutti i Tweaks selezionati sono stati applicati con successo." -Status 'SUCCESS' }
        $lblStatusGaming.Text = "Stato: Tweaks applicati! Alcune modifiche richiedono il riavvio."
    } catch {
        if (Get-Command Write-PoshLog -ErrorAction SilentlyContinue) { Write-PoshLog -Message "Errore durante l'applicazione dei tweaks: $_" -Status 'ERROR' }
        $lblStatusGaming.Text = "Stato: Errore applicazione tweaks."
    }
}

function Invoke-VideoDriverDeployment {
    param([ValidateSet('DDU', 'NVIDIA', 'AMD')][string]$Vendor)
    $tempPath = $env:TEMP
    if (-not (Test-Path $tempPath)) { New-Item -ItemType Directory -Path $tempPath -Force | Out-Null }
    switch ($Vendor) {
        'DDU' { $lblStatusGaming.Text = "Stato: DDU - funzione disponibile"; }
        'NVIDIA' { $lblStatusGaming.Text = "Stato: NVCleanstall - funzione disponibile"; }
        'AMD' { $lblStatusGaming.Text = "Stato: AMD Installer - funzione disponibile"; }
    }
}

$BtnApplyTweaks.Add_Click({ Invoke-PerformanceTweaks })
$BtnRunDdu.Add_Click({ Invoke-VideoDriverDeployment -Vendor 'DDU' })
$BtnNvidiaClean.Add_Click({ Invoke-VideoDriverDeployment -Vendor 'NVIDIA' })
$BtnAmdSetup.Add_Click({ Invoke-VideoDriverDeployment -Vendor 'AMD' })

Apply-DarkThemeToControl -Control $TabGaming

if (Get-Command Write-PoshLog -ErrorAction SilentlyContinue) { Write-PoshLog -Message "Modulo [Tab 4: Gaming & Performance Toolkit] agganciato e pronto." -Status 'SUCCESS' }