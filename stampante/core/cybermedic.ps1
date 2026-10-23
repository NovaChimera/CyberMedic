# CyberMedic - Modulo Core: CyberMedic (integrita' di rete, diagnostica di sicurezza, nmap).
# Caricato da CyberMedic_Core.ps1 tramite dot-sourcing.

function ConvertTo-CommandArgumentArray {
    param([Parameter(Mandatory = $false)][AllowEmptyString()][string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }
    $result = New-Object System.Collections.Generic.List[string]
    foreach ($match in [regex]::Matches($Text, '"[^"]*"|\S+')) {
        $result.Add(($match.Value -replace '^"|"$', ''))
    }
    return $result.ToArray()
}

function Get-NmapPresetList {
    return @(
        @{ Name = 'Scansione porte rapide'; Arguments = @('-F', '127.0.0.1'); Label = 'nmap -F 127.0.0.1' }
        @{ Name = 'Ping sweep rete locale'; Arguments = @('-sn', '192.168.1.0/24'); Label = 'nmap -sn 192.168.1.0/24' }
        @{ Name = 'Rilevamento sistema operativo'; Arguments = @('-O', '127.0.0.1'); Label = 'nmap -O 127.0.0.1' }
        @{ Name = 'Scansione completa porte'; Arguments = @('-p-', '127.0.0.1'); Label = 'nmap -p- 127.0.0.1' }
        @{ Name = 'Scansione aggressiva'; Arguments = @('-A', '127.0.0.1'); Label = 'nmap -A 127.0.0.1' }
    )
}

function Get-NmapCommand {
    param(
        [Parameter(Mandatory = $false)][AllowEmptyString()][string]$Preset,
        [Parameter(Mandatory = $false)][AllowEmptyString()][string]$Target = '127.0.0.1',
        [Parameter(Mandatory = $false)][AllowEmptyString()][string[]]$Arguments
    )
    $exe = Get-ExternalToolPath -Name 'nmap'
    if (-not $exe) { return $null }
    $argumentList = @()
    $label = ''
    if (-not [string]::IsNullOrWhiteSpace($Preset)) {
        $preset = @(Get-NmapPresetList | Where-Object { $_.Name -eq $Preset } | Select-Object -First 1)
        if (-not $preset) { return $null }
        $argumentList = @($preset.Arguments)
        $label = $preset.Label
    } elseif ($Arguments -and $Arguments.Count -gt 0) {
        $argumentList = @($Arguments | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        $label = ('nmap {0}' -f ($argumentList -join ' '))
    } else {
        if ([string]::IsNullOrWhiteSpace($Target)) { $Target = '127.0.0.1' }
        $argumentList = @('-sT', '-Pn', '-T3', $Target)
        $label = ('nmap {0}' -f $Target)
    }
    if ($argumentList.Count -eq 0) { return $null }
    return [pscustomobject]@{
        FilePath  = $exe
        Arguments = $argumentList
        Label     = $label
    }
}

function Get-NmapPresetCommand {
    param([Parameter(Mandatory = $true)][string]$Name)
    return (Get-NmapCommand -Preset $Name)
}

function Get-NetworkRepairCatalog {
    return @(
        [pscustomobject]@{ Id = 'Winsock'; Label = 'Reset Winsock (catalogo Winsock)'; File = 'netsh.exe'; Arguments = @('winsock', 'reset'); Elevated = $true }
        [pscustomobject]@{ Id = 'TcpIp'; Label = 'Reset TCP/IP (stack Internet)'; File = 'netsh.exe'; Arguments = @('int', 'ip', 'reset'); Elevated = $true }
        [pscustomobject]@{ Id = 'DnsCache'; Label = 'Svuota cache DNS'; File = 'ipconfig.exe'; Arguments = @('/flushdns'); Elevated = $false }
        [pscustomobject]@{ Id = 'Dhcp'; Label = 'Release / Renew dell''indirizzo IP'; File = 'ipconfig.exe'; Arguments = @('/release'); Elevated = $false }
        [pscustomobject]@{ Id = 'Renew'; Label = 'Renew dell''indirizzo IP'; File = 'ipconfig.exe'; Arguments = @('/renew'); Elevated = $false }
        [pscustomobject]@{ Id = 'Arp'; Label = 'Svuota cache ARP'; File = 'arp.exe'; Arguments = @('-d', '*'); Elevated = $false }
        [pscustomobject]@{ Id = 'Interface'; Label = 'Reimposta adapter (disable/enable)'; File = 'netsh.exe'; Arguments = @('interface', 'set', 'interface', 'name=WAN', 'admin=disabled'); Elevated = $true }
    )
}

function Get-NetworkRepairCommand {
    param([Parameter(Mandatory = $true)][string]$Component)
    $catalog = @(Get-NetworkRepairCatalog | Where-Object { $_.Id -eq $Component } | Select-Object -First 1)
    if (-not $catalog) { return $null }
    $exe = Get-ExternalToolPath -Name $catalog.File
    if (-not $exe) { return $null }
    return [pscustomobject]@{
        FilePath  = $exe
        Arguments = @($catalog.Arguments)
        Label     = $catalog.Label
        Elevated  = $catalog.Elevated
        Id        = $catalog.Id
    }
}

function Get-HostsFileAnalysis {
    $hostsPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\drivers\etc\hosts'
    $result = [pscustomobject]@{
        Path      = $hostsPath
        Found     = $false
        Entries   = @()
        Suspicious = @()
        Summary   = 'File hosts non trovato'
    }
    if (-not (Test-Path -LiteralPath $hostsPath -PathType Leaf)) { return $result }
    $entries = New-Object System.Collections.Generic.List[object]
    $suspicious = New-Object System.Collections.Generic.List[object]
    $known = @(
        'microsoft.com', 'windowsupdate.com', 'defender.microsoft.com', 'security.microsoft.com',
        'office.com', 'outlook.com', 'live.com', 'msftconnecttest.com', 'microsoftonline.com'
    )
    try {
        $lineNumber = 0
        foreach ($line in @(Get-Content -LiteralPath $hostsPath -ErrorAction Stop)) {
            $lineNumber++
            $clean = ($line -split '#')[0].Trim()
            if (-not $clean) { continue }
            $parts = @($clean -split '\s+' | Where-Object { $_ })
            if ($parts.Count -lt 2) { continue }
            $address = $parts[0]
            foreach ($host in @($parts[1..($parts.Count - 1)])) {
                $entry = [pscustomobject]@{
                    Line     = $lineNumber
                    Address  = $address
                    Host     = $host
                    Suspicious = $false
                    Reason   = ''
                }
                $entries.Add($entry)
                if ($address -in @('0.0.0.0', '127.0.0.1')) {
                    foreach ($domain in $known) {
                        if ($host -like "*$domain*") {
                            $entry.Suspicious = $true
                            $entry.Reason = ("Riassegnazione di un dominio Microsoft verso {0}" -f $address)
                            $suspicious.Add($entry)
                            break
                        }
                    }
                }
            }
        }
        $result.Found = $true
        $result.Entries = @($entries.ToArray())
        $result.Suspicious = @($suspicious.ToArray())
        $result.Summary = if ($entries.Count -eq 0) {
            'File hosts presente, nessuna voce attiva'
        } else {
            ("Voci attive: {0} | sospette: {1}" -f $entries.Count, $suspicious.Count)
        }
    } catch {
        $result.Summary = ("File hosts non leggibile: {0}" -f $_.Exception.Message)
    }
    return $result
}

function Get-DefenderStatus {
    $status = [pscustomobject]@{
        Available   = $false
        Enabled     = $false
        RealTime    = $false
        SignatureAge = $null
        LastScan    = 'N/D'
        Source      = 'Microsoft Defender non disponibile'
    }
    try {
        $mp = Get-MpComputerStatus -ErrorAction Stop
        if (-not $mp) { return $status }
        $status.Available = $true
        $status.Enabled = [bool]$mp.AntivirusEnabled
        $status.RealTime = [bool]$mp.RealTimeProtectionEnabled
        if ($null -ne $mp.AntivirusSignatureAge) { $status.SignatureAge = [int]$mp.AntivirusSignatureAge }
        if ($mp.AntivirusLastScanTime) { $status.LastScan = $mp.AntivirusLastScanTime.ToString('dd/MM/yyyy HH:mm') }
        $status.Source = 'Get-MpComputerStatus'
    } catch {
        Write-Log -Message ("Stato Defender non disponibile: {0}" -f $_.Exception.Message) -Level 'DEBUG'
    }
    return $status
}

function Start-DefenderQuickScan {
    $result = [pscustomobject]@{
        Success = $false
        Message = ''
    }
    try {
        $mp = Get-MpComputerStatus -ErrorAction Stop
        if (-not $mp -or -not $mp.AntivirusEnabled) {
            $result.Message = 'Microsoft Defender non e'' attivo su questa postazione.'
            return $result
        }
        Start-MpScan -ScanType QuickScan -ErrorAction Stop
        $result.Success = $true
        $result.Message = 'Scansione rapida di Microsoft Defender avviata (durata pochi minuti).'
        Write-Log -Message $result.Message -Level 'OK'
    } catch {
        $result.Message = ("Scansione rapida non avviata: {0}" -f $_.Exception.Message)
        Write-Log -Message $result.Message -Level 'ERROR'
    }
    return $result
}

function Get-SecurityQuickScan {
    $report = New-Object System.Collections.Generic.List[string]
    $defender = Get-DefenderStatus
    $report.Add('=== DIAGNOSTICA DI SICUREZZA ===')
    $report.Add(("Antivirus          : {0}" -f $(if ($defender.Available) { 'Microsoft Defender' } else { 'non disponibile' })))
    $report.Add(("Protezione attiva  : {0}" -f $defender.RealTime))
    $report.Add(("Definiti in carico : {0} giorni" -f $(if ($null -ne $defender.SignatureAge) { $defender.SignatureAge } else { 'N/D' })))
    $report.Add(("Ultima scansione   : {0}" -f $defender.LastScan))
    try {
        $firewall = @(Get-NetFirewallProfile -ErrorAction Stop)
        foreach ($profile in $firewall) {
            $report.Add(("Firewall {0,-8} : {1}" -f $profile.Name, $profile.Enabled))
        }
    } catch {
        $report.Add('Firewall           : stato non leggibile')
    }
    $hosts = Get-HostsFileAnalysis
    $report.Add(("File hosts         : {0}" -f $hosts.Summary))
    foreach ($entry in @($hosts.Suspicious)) {
        $report.Add(("  ! riga {0}: {1} -> {2} ({3})" -f $entry.Line, $entry.Address, $entry.Host, $entry.Reason))
    }
    try {
        $listening = @(Get-NetTCPConnection -State Listen -ErrorAction Stop)
        $report.Add(("Porte in ascolto   : {0}" -f $listening.Count))
    } catch {
        $report.Add('Porte in ascolto   : non rilevate')
    }
    return ($report -join [Environment]::NewLine)
}
