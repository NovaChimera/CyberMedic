# CyberMedic - Modulo Core: manutenzione (pulizia temporanei, credenziali).
# Caricato da CyberMedic_Core.ps1 tramite dot-sourcing.

function Get-CleanupTarget {
    $targets = New-Object System.Collections.Generic.List[object]
    $candidates = @(
        [pscustomobject]@{ Label = 'Temporaneo utente'; Path = $env:TEMP; Kind = 'Temp' }
        [pscustomobject]@{ Label = 'Temporaneo di sistema'; Path = (Join-Path -Path $env:SystemRoot -ChildPath 'Temp'); Kind = 'Temp' }
        [pscustomobject]@{ Label = 'Prefetch'; Path = (Join-Path -Path $env:SystemRoot -ChildPath 'Prefetch'); Kind = 'Prefetch' }
    )
    foreach ($candidate in $candidates) {
        if (-not $candidate.Path) { continue }
        $exists = $false
        try { $exists = Test-Path -LiteralPath $candidate.Path -PathType Container } catch { }
        if (-not $exists) { continue }
        $files = @(Get-ChildItem -LiteralPath $candidate.Path -Recurse -Force -File -ErrorAction SilentlyContinue)
        $size = ($files | Measure-Object -Property Length -Sum).Sum
        if ($null -eq $size) { $size = 0 }
        $targets.Add([pscustomobject]@{
            Label     = $candidate.Label
            Path      = $candidate.Path
            Kind      = $candidate.Kind
            FileCount = $files.Count
            SizeMB    = [Math]::Round(([double]$size / 1MB), 1)
        })
    }
    return @($targets.ToArray())
}

function Invoke-TempCleanup {
    param([switch]$IncludePrefetch)
    $plan = @(Get-CleanupTarget)
    $targets = @()
    foreach ($item in $plan) {
        if ($item.Kind -eq 'Prefetch' -and -not $IncludePrefetch) { continue }
        $targets += $item.Path
    }
    $deleted = 0
    $failed = 0
    $bytes = [int64]0
    foreach ($target in $targets) {
        $items = @(Get-ChildItem -LiteralPath $target -Force -ErrorAction SilentlyContinue)
        foreach ($item in $items) {
            $size = 0
            if ($item.PSIsContainer) {
                $size = (Get-ChildItem -LiteralPath $item.FullName -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            } else {
                $size = $item.Length
            }
            try {
                Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
                $deleted++
                $bytes += [int64]$size
            } catch {
                $failed++
            }
        }
    }
    $report = New-Object System.Collections.Generic.List[string]
    $report.Add('========================================================================')
    $report.Add(' PULIZIA FILE TEMPORANEI')
    $report.Add('========================================================================')
    $report.Add(("   Cartelle elaborate : {0}" -f (($targets) -join ', ')))
    $report.Add(("   Elementi rimossi   : {0}" -f $deleted))
    $report.Add(("   Elementi in uso    : {0} (saltati)" -f $failed))
    if ($bytes -ge 1GB) {
        $report.Add(("   Spazio liberato     : {0} GB" -f [Math]::Round($bytes / 1GB, 2)))
    } elseif ($bytes -ge 1MB) {
        $report.Add(("   Spazio liberato     : {0} MB" -f [Math]::Round($bytes / 1MB, 1)))
    } else {
        $report.Add(("   Spazio liberato     : {0} KB" -f [Math]::Round($bytes / 1KB, 1)))
    }
    $report.Add('')
    $report.Add('   Nota: i file in uso da altre applicazioni non vengono eliminati.')
    if (-not $IncludePrefetch) {
        $report.Add('   Nota: la cartella Prefetch non e'' stata elaborata (opzione dedicata).')
    }
    $report.Add('========================================================================')
    return ($report -join [Environment]::NewLine)
}

function Set-LocalUserPassword {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Username,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$NewPassword
    )
    if ([string]::IsNullOrWhiteSpace($Username) -or [string]::IsNullOrWhiteSpace($NewPassword)) {
        return $false
    }
    try {
        $identity = [ADSI]("WinNT://./{0},user" -f $Username)
        $identity.SetPassword($NewPassword)
        $identity.CommitChanges()
        Write-Log -Message ("Password aggiornata per l'utente {0}." -f $Username) -Level 'OK'
        return $true
    }     catch {
        Write-Log -Message ("Cambio password non riuscito per {0}: {1}" -f $Username, $_.Exception.Message) -Level 'ERROR'
        return $false
    }
}

function Get-SafePowerShellCatalog {
    $commands = @(
        [pscustomobject]@{ Name = 'Get-Date'; Description = 'Data e ora della postazione' }
        [pscustomobject]@{ Name = 'Get-Process'; Description = 'Processi attivi con CPU e memoria' }
        [pscustomobject]@{ Name = 'Get-Service'; Description = 'Stato dei servizi Windows' }
        [pscustomobject]@{ Name = 'Get-NetAdapter'; Description = 'Schede di rete e stato del collegamento' }
        [pscustomobject]@{ Name = 'Get-NetIPConfiguration'; Description = 'Configurazione IP della postazione' }
        [pscustomobject]@{ Name = 'Get-NetTCPConnection'; Description = 'Connessioni TCP attive' }
        [pscustomobject]@{ Name = 'Get-NetFirewallProfile'; Description = 'Stato dei profili del firewall' }
        [pscustomobject]@{ Name = 'Get-NetFirewallRule'; Description = 'Regole del firewall' }
        [pscustomobject]@{ Name = 'Get-Printer'; Description = 'Stampanti installate' }
        [pscustomobject]@{ Name = 'Get-Disk'; Description = 'Dischi e partizioni' }
        [pscustomobject]@{ Name = 'Get-Volume'; Description = 'Volumi e spazio disponibile' }
        [pscustomobject]@{ Name = 'Get-PhysicalDisk'; Description = 'Stato fisico dei dischi (SMART)' }
        [pscustomobject]@{ Name = 'Get-MpComputerStatus'; Description = 'Stato di Microsoft Defender' }
        [pscustomobject]@{ Name = 'Get-MpThreatDetection'; Description = 'Rilevamenti recenti di Defender' }
        [pscustomobject]@{ Name = 'Get-HotFix'; Description = 'Ultimi aggiornamenti installati' }
        [pscustomobject]@{ Name = 'Get-WinEvent'; Description = 'Registro eventi di Windows' }
        [pscustomobject]@{ Name = 'Get-EventLog'; Description = 'Registro eventi di Windows (Windows PowerShell)' }
        [pscustomobject]@{ Name = 'Get-ScheduledTask'; Description = 'Attivita pianificate' }
        [pscustomobject]@{ Name = 'Get-LocalUser'; Description = 'Utenti locali della postazione' }
        [pscustomobject]@{ Name = 'Get-ComputerInfo'; Description = 'Informazioni di sistema' }
        [pscustomobject]@{ Name = 'Get-TimeZone'; Description = 'Fuso orario della postazione' }
    )
    return @($commands)
}

function Invoke-SafePowerShellCommand {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Command
    )
    $result = [pscustomobject]@{
        Success = $false
        Message = ''
        Output  = ''
    }
    if ([string]::IsNullOrWhiteSpace($Command)) {
        $result.Message = 'Nessun comando da eseguire.'
        return $result
    }
    $allowed = @((Get-SafePowerShellCatalog | ForEach-Object { $_.Name }))
    $match = $null
    foreach ($name in $allowed) {
        if ($Command -match ("^(?i){0}(\s|$)" -f [regex]::Escape($name))) { $match = $name; break }
    }
    if (-not $match) {
        $result.Message = ("Comando non consentito. Utilizzare solo: {0}" -f (($allowed | Select-Object -First 6) -join ', '))
        Write-Log -Message ("Comando PowerShell non consentito: {0}" -f $Command) -Level 'WARN'
        return $result
    }
    $forbidden = @('Remove-', 'Set-', 'New-', 'Start-', 'Stop-', 'Restart-', 'Invoke-Expression', 'iex', 'rm ', 'del ', 'rd ', 'format-', 'Invoke-Command', 'Out-File', 'Set-Content', 'Add-Content', 'Stop-Process')
    foreach ($token in $forbidden) {
        if ($Command -match [regex]::Escape($token)) {
            $result.Message = ("Comando contenente l'operazione '{0}' non consentito: la console e' in sola lettura." -f $token.Trim())
            Write-Log -Message ("Comando PowerShell bloccato: {0}" -f $Command) -Level 'WARN'
            return $result
        }
    }
    try {
        $output = & ([scriptblock]::Create($Command)) 2>&1 | Out-String
        $result.Success = $true
        $result.Output = $output
        $result.Message = ("Comando '{0}' eseguito." -f $match)
        Write-Log -Message ("Console PowerShell: eseguito '{0}'." -f $match) -Level 'DEBUG'
    } catch {
        $result.Message = ("Comando non riuscito: {0}" -f $_.Exception.Message)
        Write-Log -Message ("Console PowerShell: {0}" -f $_.Exception.Message) -Level 'WARN'
    }
    return $result
}
