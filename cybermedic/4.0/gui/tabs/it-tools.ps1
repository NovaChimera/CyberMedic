#Requires -Version 5.1
<#
.SYNOPSIS
    CyberMedic 3.0.1 Module - IT Tools & Advanced Repair Engine.
.DESCRIPTION
    Interfaccia nativa WinForms per operazioni di riparazione avanzate:
    Ripristino del Microsoft Store, gestione dello stato di BitLocker e backup dei driver di terze parti.
#>

if (Get-Command Write-PoshLog -ErrorAction SilentlyContinue) {
    Write-PoshLog -Message "Iniezione Modulo [Tab 5: Strumenti IT & Riparazione Avanzata] avviata..." -Status '⚡'
}

$TabIT = $script:Tabs["StrumentiIT"]
if (-not $TabIT) {
    Write-Warning "Tab 'Strumenti IT' non trovato nella mappa globale di CyberMedic."
    return
}

$GroupRepair = New-Object System.Windows.Forms.GroupBox
$GroupRepair.Text = " Riparazioni di Sistema & Backup "
$GroupRepair.Location = New-Object System.Drawing.Point(20, 20)
$GroupRepair.Size = New-Object System.Drawing.Size(480, 480)
$GroupRepair.ForeColor = $script:Theme.TextPrimary
$TabIT.Controls.Add($GroupRepair)

$BtnFixStore = New-Object System.Windows.Forms.Button
$BtnFixStore.Location = New-Object System.Drawing.Point(25, 40)
$BtnFixStore.Size = New-Object System.Drawing.Size(430, 45)
$BtnFixStore.Text = "Ripristina & Reinstalla Microsoft Store"
$BtnFixStore.BackColor = $script:Theme.AccentBlue
$BtnFixStore.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$BtnFixStore.Font = $script:Theme.FontBold
$GroupRepair.Controls.Add($BtnFixStore)

$BtnBackupDrivers = New-Object System.Windows.Forms.Button
$BtnBackupDrivers.Location = New-Object System.Drawing.Point(25, 110)
$BtnBackupDrivers.Size = New-Object System.Drawing.Size(430, 45)
$BtnBackupDrivers.Text = "Esegui Backup Completo Driver di Terze Parti"
$BtnBackupDrivers.BackColor = $script:Theme.BgMain
$BtnBackupDrivers.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$GroupRepair.Controls.Add($BtnBackupDrivers)

$GroupBitLocker = New-Object System.Windows.Forms.GroupBox
$GroupBitLocker.Text = " Gestione Sospensione BitLocker (Manutenzione) "
$GroupBitLocker.Location = New-Object System.Drawing.Point(520, 20)
$GroupBitLocker.Size = New-Object System.Drawing.Size(530, 480)
$GroupBitLocker.ForeColor = $script:Theme.TextPrimary
$TabIT.Controls.Add($GroupBitLocker)

$LblBLDesc = New-Object System.Windows.Forms.Label
$LblBLDesc.Text = "Sospendi la cifratura per evitare blocchi durante gli aggiornamenti del firmware o del BIOS."
$LblBLDesc.Location = New-Object System.Drawing.Point(30, 40)
$LblBLDesc.Size = New-Object System.Drawing.Size(470, 40)
$LblBLDesc.ForeColor = $script:Theme.TextSecondary
$GroupBitLocker.Controls.Add($LblBLDesc)

$BtnSuspendBL = New-Object System.Windows.Forms.Button
$BtnSuspendBL.Location = New-Object System.Drawing.Point(30, 100)
$BtnSuspendBL.Size = New-Object System.Drawing.Size(470, 45)
$BtnSuspendBL.Text = "Sospendi Protezione BitLocker (C:)"
$BtnSuspendBL.BackColor = $script:Theme.BgMain
$BtnSuspendBL.ForeColor = $script:Theme.AccentCyan
$BtnSuspendBL.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$GroupBitLocker.Controls.Add($BtnSuspendBL)

$BtnResumeBL = New-Object System.Windows.Forms.Button
$BtnResumeBL.Location = New-Object System.Drawing.Point(30, 170)
$BtnResumeBL.Size = New-Object System.Drawing.Size(470, 45)
$BtnResumeBL.Text = "Riattiva Protezione BitLocker (C:)"
$BtnResumeBL.BackColor = $script:Theme.BgMain
$BtnResumeBL.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$GroupBitLocker.Controls.Add($BtnResumeBL)

$lblStatusIT = New-Object System.Windows.Forms.Label
$lblStatusIT.Text = "Selezionare uno strumento di manutenzione avanzata."
$lblStatusIT.Location = New-Object System.Drawing.Point(20, 520)
$lblStatusIT.Size = New-Object System.Drawing.Size(1030, 25)
$lblStatusIT.Font = $script:Theme.FontBold
$lblStatusIT.ForeColor = $script:Theme.TextSecondary
$TabIT.Controls.Add($lblStatusIT)

function Repair-MicrosoftStore {
    if (Get-Command Write-PoshLog -ErrorAction SilentlyContinue) { Write-PoshLog -Message "Avvio procedura di ripristino forzato Microsoft Store..." -Status 'INFO' }
    $lblStatusIT.Text = "Stato: Ripristino Microsoft Store in corso..."
    try {
        Start-Process -FilePath "wsreset.exe" -Wait -ErrorAction SilentlyContinue
        Get-AppXPackage -AllUsers -Name "Microsoft.WindowsStore" | Foreach {
            Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction Stop
        }
        if (Get-Command Write-PoshLog -ErrorAction SilentlyContinue) { Write-PoshLog -Message "Microsoft Store ripristinato con successo." -Status 'SUCCESS' }
        $lblStatusIT.Text = "Stato: Microsoft Store ripristinato."
    } catch {
        if (Get-Command Write-PoshLog -ErrorAction SilentlyContinue) { Write-PoshLog -Message "Errore durante la registrazione dello Store: $_" -Status 'ERROR' }
        $lblStatusIT.Text = "Stato: Errore ripristino Store."
    }
}

function Export-SystemDrivers {
    $backupPath = Join-Path $env:TEMP "DriverBackup_$(Get-Date -Format 'yyyyMMdd')"
    if (Get-Command Write-PoshLog -ErrorAction SilentlyContinue) { Write-PoshLog -Message "Avvio esportazione e backup dei driver di terze parti..." -Status 'INFO' }
    $lblStatusIT.Text = "Stato: Esportazione driver in corso..."
    if (-not (Test-Path $backupPath)) { New-Item -ItemType Directory -Path $backupPath -Force | Out-Null }
    Start-Process -FilePath "$env:windir\System32\dism.exe" -ArgumentList "/Online", "/Export-Driver", "/Destination:`"$backupPath`"" -Wait
    $lblStatusIT.Text = "Stato: Backup driver completato."
}

function Manage-BitLockerState {
    param([ValidateSet('Suspend', 'Resume')][string]$Action)
    if (Get-Command Write-PoshLog -ErrorAction SilentlyContinue) { Write-PoshLog -Message "Richiesta operazione BitLocker: [$Action] sull'unità C:" -Status 'INFO' }
    $lblStatusIT.Text = "Stato: Comunicazione con il sottosistema BitLocker..."
    try {
        if ($Action -eq 'Suspend') {
            Suspend-BitLocker -MountPoint "C:" -RebootCount 1 -ErrorAction Stop
            if (Get-Command Write-PoshLog -ErrorAction SilentlyContinue) { Write-PoshLog -Message "Protezione BitLocker sospesa temporaneamente per C:." -Status 'WARN' }
            $lblStatusIT.Text = "Stato: BitLocker Sospeso (C:)."
        } else {
            Resume-BitLocker -MountPoint "C:" -ErrorAction Stop
            if (Get-Command Write-PoshLog -ErrorAction SilentlyContinue) { Write-PoshLog -Message "Protezione BitLocker riattivata per C:." -Status 'SUCCESS' }
            $lblStatusIT.Text = "Stato: BitLocker Attivo (C:)."
        }
    } catch {
        if (Get-Command Write-PoshLog -ErrorAction SilentlyContinue) { Write-PoshLog -Message "Operazione BitLocker fallita: $_" -Status 'ERROR' }
        $lblStatusIT.Text = "Stato: Errore BitLocker."
    }
}

$BtnFixStore.Add_Click({ Repair-MicrosoftStore })
$BtnBackupDrivers.Add_Click({ Export-SystemDrivers })
$BtnSuspendBL.Add_Click({ Manage-BitLockerState -Action 'Suspend' })
$BtnResumeBL.Add_Click({ Manage-BitLockerState -Action 'Resume' })

$BtnSFC = New-Object System.Windows.Forms.Button
$BtnSFC.Location = New-Object System.Drawing.Point(25, 180)
$BtnSFC.Size = New-Object System.Drawing.Size(430, 45)
$BtnSFC.Text = "Esegui SFC /scannow"
$BtnSFC.BackColor = $script:Theme.BgMain
$BtnSFC.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$GroupRepair.Controls.Add($BtnSFC)

$BtnSFC.Add_Click({
    Write-PoshLog -Message "Avvio SFC /scannow..." -Status '⚡'
    Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -Wait -NoNewWindow
    Write-PoshLog -Message "SFC completato." -Status 'SUCCESS'
})

Apply-DarkThemeToControl -Control $TabIT

if (Get-Command Write-PoshLog -ErrorAction SilentlyContinue) { Write-PoshLog -Message "Modulo [Tab 5: Strumenti IT & Riparazione Avanzata] agganciato e pronto." -Status 'SUCCESS' }