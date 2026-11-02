# CyberMedic - Modulo Core: reti wireless (interfacce e profili Wi-Fi).
# Caricato da CyberMedic_Core.ps1 tramite dot-sourcing.
#
# Il modulo raccoglie l'inventario delle interfacce Wi-Fi e dei profili
# salvati (nome e tipo di protezione). Non estrae mai il materiale chiave
# dei profili: la diagnostica si ferma al livello dell'inventario.

function ConvertFrom-WifiField {
    param(
        [Parameter(Mandatory = $false)][AllowNull()]$Lines,
        [Parameter(Mandatory = $true)][string[]]$Candidates
    )
    if (-not $Lines) { return '' }
    $map = @{}
    foreach ($line in $Lines) {
        if ($line -match '^\s*(?<key>[^:]+?)\s*:\s*(?<value>.*)$') {
            $key = $matches['key'].Trim().ToLower()
            if (-not $map.ContainsKey($key)) { $map[$key] = $matches['value'].Trim() }
        }
    }
    foreach ($candidate in $Candidates) {
        $needle = $candidate.ToLower()
        if ($map.ContainsKey($needle)) { return $map[$needle] }
    }
    return ''
}

function Get-WifiInterfaceDetails {
    $raw = ''
    try {
        $raw = (& netsh.exe wlan show interfaces 2>&1 | Out-String)
    } catch {
        return [pscustomobject]@{
            Success  = $false
            Message  = ("Lettura delle interfacce Wi-Fi non riuscita: {0}" -f $_.Exception.Message)
            Raw      = ''
            Detail   = ''
            Profiles = @()
        }
    }

    if ($raw -match '(?i)nessun|not present|no wireless|wireless interface') {
        return [pscustomobject]@{
            Success  = $true
            Message  = 'Nessuna interfaccia Wi-Fi attiva su questa postazione.'
            Raw      = $raw.Trim()
            Detail   = $raw.Trim()
            Profiles = @()
        }
    }

    $lines = @($raw -split "`r?`n")
    $name = ConvertFrom-WifiField -Lines $lines -Candidates @('Nome', 'Name', 'Nome interfaccia')
    $ssid = ConvertFrom-WifiField -Lines $lines -Candidates @('SSID')
    $state = ConvertFrom-WifiField -Lines $lines -Candidates @('Stato', 'State')
    $signal = ConvertFrom-WifiField -Lines $lines -Candidates @('Segnale', 'Signal')
    $radio = ConvertFrom-WifiField -Lines $lines -Candidates @('Tipo radio', 'Radio type')
    $auth = ConvertFrom-WifiField -Lines $lines -Candidates @('Autenticazione', 'Authentication')
    $cipher = ConvertFrom-WifiField -Lines $lines -Candidates @('Crittografia', 'Cipher')
    $channel = ConvertFrom-WifiField -Lines $lines -Candidates @('Canale', 'Channel')
    $rxRate = ConvertFrom-WifiField -Lines $lines -Candidates @('Velocita'' di ricezione', 'Receive rate (Mbps)')
    $txRate = ConvertFrom-WifiField -Lines $lines -Candidates @('Velocita'' di trasmissione', 'Transmit rate (Mbps)')
    $bssid = ConvertFrom-WifiField -Lines $lines -Candidates @('BSSID')

    $detail = @(
        '============ INTERFACCIA WI-FI ============'
        ("  Nome interfaccia : {0}" -f $name)
        ("  SSID             : {0}" -f $ssid)
        ("  BSSID            : {0}" -f $bssid)
        ("  Stato            : {0}" -f $state)
        ("  Tipo radio       : {0}" -f $radio)
        ("  Autenticazione   : {0}" -f $auth)
        ("  Crittografia     : {0}" -f $cipher)
        ("  Canale           : {0}" -f $channel)
        ("  Segnale          : {0}" -f $signal)
        ("  Ricezione        : {0}" -f $rxRate)
        ("  Trasmissione     : {0}" -f $txRate)
    ) -join [Environment]::NewLine

    return [pscustomobject]@{
        Success  = $true
        Message  = 'Interfaccia Wi-Fi rilevata.'
        Raw      = $raw.Trim()
        Detail   = $detail
        Profiles = @()
    }
}

function Get-WifiProfileInventory {
    $profiles = New-Object System.Collections.Generic.List[object]
    $raw = ''
    try {
        $raw = (& netsh.exe wlan show profiles 2>&1 | Out-String)
    } catch {
        return $profiles
    }
    foreach ($line in ($raw -split "`r?`n")) {
        if ($line -match '(?i)^\s*(?:Nome profilo|Profile name)\s*:\s*(?<profile>.+?)\s*$') {
            $name = $matches['profile'].Trim()
            if ($name) { $profiles.Add([pscustomobject]@{ Name = $name; Authentication = ''; Cipher = '' }) }
        }
    }
    return @($profiles.ToArray())
}

function Get-WifiDetails {
    $interfaces = Get-WifiInterfaceDetails
    $profiles = Get-WifiProfileInventory
    $lines = @()
    $lines += $interfaces.Detail
    $lines += ''
    $lines += '============ PROFILI SALVATI ============'
    if ($profiles.Count -eq 0) {
        $lines += '  Nessun profilo Wi-Fi salvato.'
    } else {
        foreach ($profile in $profiles) {
            $lines += ("  - {0}" -f $profile.Name)
        }
    }
    return [pscustomobject]@{
        Success  = $interfaces.Success
        Message  = $interfaces.Message
        Detail   = ($lines -join [Environment]::NewLine)
        Raw      = $interfaces.Raw
        Profiles = @($profiles)
    }
}
