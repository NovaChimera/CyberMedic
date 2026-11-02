# core\cm-security.ps1
# Funzioni di sicurezza difensiva. Richiede core\cm-runner.ps1 caricato prima.

function Confirm-CmAuthorizedScan {
    $r = [System.Windows.Forms.MessageBox]::Show(
        "Stai per scansionare le porte della rete locale.`nProcedi solo se sei autorizzato ad amministrare questa rete.`n`nConfermi?",
        'CyberMedic – Autorizzazione scansione',
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning)
    return ($r -eq [System.Windows.Forms.DialogResult]::Yes)
}

function Get-CmLocalSubnet {
    $cfg = Get-NetIPConfiguration |
        Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } |
        Select-Object -First 1
    if (-not $cfg) { return $null }
    $ip = $cfg.IPv4Address.IPAddress
    [pscustomobject]@{
        IP     = $ip
        Prefix = $cfg.IPv4Address.PrefixLength
        Base   = ($ip -replace '\.\d+$', '')     # es. 192.168.1  (si scansiona solo il /24 locale)
    }
}

function Get-CmSecurityAudit {
    $r = [System.Collections.Generic.List[object]]::new()
    $add = {
        param($Check, $Ok, $Detail)
        $r.Add([pscustomobject]@{ Check = $Check; Status = $(if ($Ok) { 'OK' } else { 'ATTENZIONE' }); Detail = $Detail })
    }

    try {
        $mp = Get-MpComputerStatus
        & $add 'Defender: protezione in tempo reale' $mp.RealTimeProtectionEnabled "Attiva: $($mp.RealTimeProtectionEnabled)"
        & $add 'Defender: firme aggiornate' ($mp.AntivirusSignatureAge -le 3) "Età firme: $($mp.AntivirusSignatureAge) giorni"
    } catch { & $add 'Defender' $false "Non leggibile: $($_.Exception.Message)" }

    try {
        $off = @(Get-NetFirewallProfile | Where-Object { -not $_.Enabled }).Name
        & $add 'Firewall (tutti i profili)' ($off.Count -eq 0) $(if ($off.Count) { "Disattivo: $($off -join ', ')" } else { 'Attivo' })
    } catch { & $add 'Firewall' $false $_.Exception.Message }

    try {
        $smb1 = (Get-SmbServerConfiguration).EnableSMB1Protocol
        & $add 'SMB1 disattivato' (-not $smb1) "SMB1 attivo: $smb1"
    } catch { & $add 'SMB1' $false $_.Exception.Message }

    try {
        $bl = Get-BitLockerVolume -MountPoint $env:SystemDrive
        & $add "BitLocker $($env:SystemDrive)" ($bl.ProtectionStatus -eq 'On') "Stato: $($bl.ProtectionStatus), cifrato al $($bl.EncryptionPercentage)%"
    } catch { & $add 'BitLocker' $false 'Non disponibile o permessi insufficienti' }

    try {
        $tpm = Get-Tpm
        & $add 'TPM presente e pronto' ($tpm.TpmPresent -and $tpm.TpmReady) "Presente: $($tpm.TpmPresent), pronto: $($tpm.TpmReady)"
    } catch { & $add 'TPM' $false 'Non leggibile' }

    try {
        $sb = Confirm-SecureBootUEFI
        & $add 'Secure Boot' $sb "Attivo: $sb"
    } catch { & $add 'Secure Boot' $false 'Non supportato (BIOS legacy?)' }

    try {
        $rdp = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server').fDenyTSConnections
        & $add 'Desktop remoto (RDP) disattivato' ($rdp -eq 1) $(if ($rdp -eq 1) { 'Disattivato' } else { 'RDP attivo: verifica che sia necessario' })
    } catch { & $add 'RDP' $false $_.Exception.Message }

    try {
        $uac = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System').EnableLUA
        & $add 'UAC attivo' ($uac -eq 1) "EnableLUA = $uac"
    } catch { & $add 'UAC' $false $_.Exception.Message }

    try {
        $admins = @(Get-LocalGroupMember -Group 'Administrators')
        & $add 'Amministratori locali' ($admins.Count -le 3) "$($admins.Count): $(($admins.Name) -join ', ')"
    } catch { & $add 'Amministratori locali' $false $_.Exception.Message }

    try {
        $guest = Get-LocalUser -Name 'Guest' -ErrorAction Stop
        & $add 'Account Guest disattivato' (-not $guest.Enabled) "Attivo: $($guest.Enabled)"
    } catch { & $add 'Account Guest' $true 'Non presente' }

    try {
        $last = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1
        $days = if ($last.InstalledOn) { [int]((Get-Date) - $last.InstalledOn).TotalDays } else { 9999 }
        & $add 'Aggiornamenti recenti (ultimi 45 giorni)' ($days -le 45) "Ultimo: $($last.HotFixID), $days giorni fa"
    } catch { & $add 'Aggiornamenti' $false $_.Exception.Message }

    return $r
}

function Update-CmDefenderSignatures {
    $mp = Join-Path $env:ProgramFiles 'Windows Defender\MpCmdRun.exe'
    if (-not (Test-Path $mp)) { Write-CmLog 'MpCmdRun.exe non trovato.' 'ERROR'; return }
    Start-CmTask -Title 'Defender: aggiornamento firme' -FilePath $mp -Arguments '-SignatureUpdate'
}

function Start-CmDefenderQuickScan {
    $mp = Join-Path $env:ProgramFiles 'Windows Defender\MpCmdRun.exe'
    if (-not (Test-Path $mp)) { Write-CmLog 'MpCmdRun.exe non trovato.' 'ERROR'; return }
    Start-CmTask -Title 'Defender: scansione rapida' -FilePath $mp -Arguments '-Scan -ScanType 1'
}

function Start-CmPortScan {
    param(
        [Parameter(Mandatory)][string]$BaseNet,                 # es. 192.168.1  (solo /24)
        [int[]]$Ports = @(21, 22, 23, 80, 135, 139, 443, 445, 3389, 5900, 9100),
        [int]$TimeoutMs = 500,
        [scriptblock]$OnDone                                     # riceve la lista dei risultati
    )

    if ($BaseNet -notmatch '^\d{1,3}\.\d{1,3}\.\d{1,3}$') { Write-CmLog "Rete non valida: $BaseNet" 'ERROR'; return }
    if (-not (Confirm-CmAuthorizedScan)) { Write-CmLog 'Scansione annullata dall''utente.' 'WARN'; return }

    $ips = 1..254 | ForEach-Object { "$BaseNet.$_" }
    Write-CmLog "Scansione di $BaseNet.1-254 su $($Ports.Count) porte..." 'INFO'

    $job = Start-ThreadJob -ArgumentList $ips, $Ports, $TimeoutMs -ScriptBlock {
        param($ips, $ports, $to)
        for ($i = 0; $i -lt $ips.Count; $i += 24) {
            $chunk = $ips[$i..([Math]::Min($i + 23, $ips.Count - 1))]
            $items = foreach ($ip in $chunk) {
                foreach ($p in $ports) {
                    $c = [System.Net.Sockets.TcpClient]::new()
                    [pscustomobject]@{ IP = $ip; Port = $p; Client = $c; Task = $c.ConnectAsync($ip, $p) }
                }
            }
            try { [void][System.Threading.Tasks.Task]::WaitAll([System.Threading.Tasks.Task[]]@($items.Task), $to) } catch {}
            foreach ($it in $items) {
                if ($it.Client.Connected) { [pscustomobject]@{ IP = $it.IP; Port = $it.Port; State = 'Aperta' } }
                $it.Client.Dispose()
            }
        }
    }

    $timer = [System.Windows.Forms.Timer]::new()
    $timer.Interval = 500
    $timer.Tag = @{ Job = $job; OnDone = $OnDone; Found = [System.Collections.Generic.List[object]]::new() }
    $timer.Add_Tick({
        param($s, $e)
        $st = $s.Tag
        $done = $st.Job.State -in 'Completed', 'Failed', 'Stopped'
        foreach ($r in @(Receive-Job -Job $st.Job)) {
            [void]$st.Found.Add($r)
            Write-CmLog ("{0}:{1} aperta" -f $r.IP, $r.Port) 'WARN'
        }
        if ($done) {
            $s.Stop(); $s.Dispose()
            Remove-Job -Job $st.Job -Force
            Write-CmLog ("Scansione terminata: {0} porte aperte" -f $st.Found.Count) 'SUCCESS'
            if ($st.OnDone) { try { & $st.OnDone $st.Found } catch { Write-CmLog $_.Exception.Message 'ERROR' } }
        }
    })
    $timer.Start()
}

function Clear-CmPrintQueue {
    try {
        Stop-Service -Name Spooler -Force -ErrorAction Stop
        Remove-Item -Path "$env:SystemRoot\System32\spool\PRINTERS\*" -Include *.SPL, *.SHD -Force -ErrorAction SilentlyContinue
        Write-CmLog 'Coda di stampa svuotata.' 'SUCCESS'
    }
    catch { Write-CmLog "Sblocco coda fallito: $($_.Exception.Message)" 'ERROR' }
    finally { Start-Service -Name Spooler -ErrorAction SilentlyContinue }
}

function Export-CmResults {
    param([Parameter(Mandatory)]$Data, [string]$Name = 'risultati')
    $dir = Join-Path $env:ProgramData 'CyberMedic\export'
    if (-not (Test-Path $dir)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
    $file = Join-Path $dir ("{0}-{1:yyyyMMdd-HHmmss}.csv" -f $Name, (Get-Date))
    $Data | Export-Csv -Path $file -NoTypeInformation -Encoding UTF8
    Write-CmLog "Esportato: $file" 'SUCCESS'
    return $file
}