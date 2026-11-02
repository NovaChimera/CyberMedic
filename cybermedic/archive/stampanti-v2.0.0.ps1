#Requires -Version 5.1
<#
.SYNOPSIS
    NovaChimera - IT Printer Suite per il supporto tecnico (tema Obsidian Purple).
.DESCRIPTION
    Inventario stampanti (locali, condivise, di rete, offline), diagnostica di
    risoluzione e connettivita', gestione dei lavori in coda, controllo del
    servizio Spooler, pagina di prova, ricerca driver, WebAdmin, eliminazione
    stampante, export report e chiusura volatile dell'applicazione.
    Ogni operazione e' protetta da try/catch con fallback multipli: l'interfaccia
    non deve mai terminare in modo anomalo.
.PARAMETER PrinterName
    Stampante da selezionare all'avvio.
.PARAMETER LogDirectory
    Cartella dei log. Default: <cartella script>\logs
.PARAMETER SelfTest
    Esegue il protocollo di verifica locale e termina (nessuna interfaccia).
.PARAMETER Diagnose
    Genera il report diagnostico su console e termina.
.PARAMETER NoElevation
    Non tenta l'auto-elevazione del processo.
.PARAMETER SmokeTest
    Costruisce l'interfaccia grafica senza mostrarla e verifica il popolamento
    dei controlli. Utile per validare l'installazione su una postazione.
.PARAMETER ResolvePort
    Risolve una porta di stampa indicata come argomento e ne stampa il
    risultato (host, IP, porta TCP e sorgente della risoluzione).
#>

[CmdletBinding()]
param(
    [string]$PrinterName,
    [string]$LogDirectory,
    [switch]$SelfTest,
    [switch]$Diagnose,
    [switch]$NoElevation,
    [switch]$SmokeTest,
    [string]$ResolvePort,
    [string]$ResolvePrinter = ''
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue

$script:AppName = 'NovaChimera'
$script:AppVersion = '2.0.0'
$script:Ui = @{}
$script:LogEntries = New-Object System.Collections.Generic.List[string]
$script:LogFile = $null
$script:LogDirectory = $null
$script:Inventory = @()
$script:SelectedPrinter = $null
$script:SelectedPrinterName = ''
$script:LocalIpv4Cache = $null
$script:IpEditResult = $null
$script:StatusMap = @{
    1 = 'Altro'; 2 = 'Sconosciuto'; 3 = 'Inattiva'; 4 = 'In stampa'; 5 = 'Offline'
    6 = 'In attesa'; 7 = 'Arrestata'; 8 = 'Errore'; 9 = 'Occupata'; 10 = 'Non pronta'
    11 = 'In elaborazione'; 12 = 'In attesa di ripresa'
}
$script:WellKnownPorts = @{ Raw = 9100; Lpr = 515; Ipp = 631; Wsd = 5357 }
$script:PrinterListColumns = @(
    @{ Title = 'Stampante'; Width = 195; Min = 110 }
    @{ Title = 'IP IPv4'; Width = 125; Min = 90 }
    @{ Title = 'Subnet Mask'; Width = 120; Min = 90 }
    @{ Title = 'Stato'; Width = 90; Min = 60 }
    @{ Title = 'Pref.'; Width = 48; Min = 36 }
    @{ Title = 'Coda'; Width = 48; Min = 36 }
    @{ Title = 'Porta'; Width = 120; Min = 80 }
    @{ Title = 'Tipo porta'; Width = 105; Min = 70 }
)

$script:ColorBgMain = [System.Drawing.ColorTranslator]::FromHtml('#0f0f13')
$script:ColorBgList = [System.Drawing.ColorTranslator]::FromHtml('#181820')
$script:ColorPanel = [System.Drawing.ColorTranslator]::FromHtml('#22222d')
$script:ColorBorder = [System.Drawing.ColorTranslator]::FromHtml('#323242')
$script:ColorAccent = [System.Drawing.ColorTranslator]::FromHtml('#b388ff')
$script:ColorTextMain = [System.Drawing.ColorTranslator]::FromHtml('#e0e0e0')
$script:ColorTextMuted = [System.Drawing.ColorTranslator]::FromHtml('#9e9e9e')
$script:ColorError = [System.Drawing.ColorTranslator]::FromHtml('#f38ba8')
$script:ColorSuccess = [System.Drawing.ColorTranslator]::FromHtml('#a6e3a1')
$script:ColorWarning = [System.Drawing.ColorTranslator]::FromHtml('#f9e2af')
$script:ColorCardBg = [System.Drawing.ColorTranslator]::FromHtml('#111116')

function Write-Log {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Message,
        [ValidateSet('INFO', 'OK', 'WARN', 'ERROR', 'DEBUG')][string]$Level = 'INFO'
    )
    $line = '{0} [{1,-5}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    $script:LogEntries.Add($line)
    if ($script:LogFile) {
        try { Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 -ErrorAction Stop } catch { }
    }
    $box = $script:Ui.LogBox
    if ($box) {
        try {
            $box.AppendText($line + [Environment]::NewLine)
            $box.SelectionStart = $box.TextLength
            $box.ScrollToCaret()
        } catch { }
    }
}

function Get-SafeProp {
    param(
        [Parameter(Mandatory = $false)]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $false)]$Default = $null
    )
    if ($null -eq $InputObject) { return $Default }
    if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) {
            $v = $InputObject[$Name]
            if ($null -eq $v) { return $Default }
            if ($v -is [string] -and [string]::IsNullOrWhiteSpace($v)) { return $Default }
            return $v
        }
        return $Default
    }
    $prop = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $Default }
    $value = $prop.Value
    if ($null -eq $value) { return $Default }
    if ($value -is [string] -and [string]::IsNullOrWhiteSpace($value)) { return $Default }
    return $value
}

function Get-SafeText {
    param(
        [Parameter(Mandatory = $false)]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$Default = 'N/D'
    )
    $v = Get-SafeProp -InputObject $InputObject -Name $Name -Default $Default
    if ($null -eq $v) { return $Default }
    return ([string]$v).Trim()
}

function Get-StatusText {
    param([Parameter(Mandatory = $false)]$Status, [string]$Fallback = 'N/D')
    if ($null -eq $Status) { return $Fallback }
    if ($Status -is [string]) {
        if ([string]::IsNullOrWhiteSpace($Status)) { return $Fallback }
        return $Status
    }
    try {
        $text = $Status.ToString()
        if ([string]::IsNullOrWhiteSpace($text)) { return $Fallback }
        return $text
    } catch {
        return $Fallback
    }
}

function Get-AdminState {
    $result = [ordered]@{ IsElevated = $false; Identity = 'N/D'; Host = 'N/D' }
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        $result.IsElevated = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        $result.Identity = $identity.Name
        $result.Host = $env:COMPUTERNAME
    } catch {
        Write-Log -Message ("Impossibile verificare i privilegi: {0}" -f $_.Exception.Message) -Level 'WARN'
    }
    return [pscustomobject]$result
}

function Initialize-Application {
    $script:LogDirectory = $LogDirectory
    if ([string]::IsNullOrWhiteSpace($script:LogDirectory)) {
        $script:LogDirectory = Join-Path -Path $PSScriptRoot -ChildPath 'logs'
    }
    if (-not (Test-Path -LiteralPath $script:LogDirectory -PathType Container)) {
        try {
            New-Item -ItemType Directory -Path $script:LogDirectory -Force -ErrorAction Stop | Out-Null
        } catch {
            $fallback = Join-Path -Path $env:TEMP -ChildPath 'StampantiTool\logs'
            try {
                New-Item -ItemType Directory -Path $fallback -Force -ErrorAction Stop | Out-Null
                $script:LogDirectory = $fallback
            } catch {
                $script:LogDirectory = $env:TEMP
            }
        }
    }
    $script:LogFile = Join-Path -Path $script:LogDirectory -ChildPath ("stampanti-{0}.log" -f (Get-Date -Format 'yyyyMMdd'))
    Write-Log -Message ("Avvio {0} v{1} - PowerShell {2} ({3})" -f $script:AppName, $script:AppVersion, $PSVersionTable.PSVersion, $PSVersionTable.PSEdition) -Level 'INFO'
    Write-Log -Message ("Elevazione amministratore: {0}" -f (Get-AdminState).IsElevated) -Level 'INFO'
    Write-Log -Message ("Log attivo: {0}" -f $script:LogFile) -Level 'INFO'
}

function Get-RegistryValueSafe {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $false)]$Default = $null
    )
    try {
        if (-not (Test-Path -LiteralPath $Path)) { return $Default }
        $item = Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop
        $prop = $item.PSObject.Properties[$Name]
        if ($null -eq $prop -or $null -eq $prop.Value) { return $Default }
        return $prop.Value
    } catch {
        return $Default
    }
}

function Get-PortKind {
    param([string]$PortName)
    if ([string]::IsNullOrWhiteSpace($PortName)) { return 'N/D' }
    $p = $PortName.Trim()
    if ($p -like 'IP_*') { return 'TCP/IP (RAW)' }
    if ($p -like 'WSD*') { return 'WSD' }
    if ($p -like 'USB*') { return 'USB' }
    if ($p -like 'COM*' -or $p -like 'LPT*') { return 'Locale' }
    if ($p -like 'FILE:*' -or $p -like 'nul:*' -or $p -like 'PORTPROMPT:*') { return 'Virtuale' }
    if ($p -like '\\*') { return 'Condivisa' }
    if ($p -match '^\d{1,3}(\.\d{1,3}){3}$') { return 'TCP/IP (RAW)' }
    return 'Rete / Host'
}

function Get-WsdDeviceInfo {
    param([Parameter(Mandatory = $true)][string]$PortName)
    $root = 'HKLM:\SYSTEM\CurrentControlSet\Enum\SWD\WSDPrint'
    try {
        if (-not (Test-Path -LiteralPath $root)) { return $null }
        $token = ($PortName -replace '^WSD[-_]?', '') -replace '[^0-9A-Fa-f]', ''
        if ([string]::IsNullOrWhiteSpace($token)) { return $null }
        foreach ($device in @(Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue)) {
            $deviceHex = ($device.PSChildName -replace '[^0-9A-Fa-f]', '')
            $paramsPath = Join-Path -Path $device.PSPath -ChildPath 'Device Parameters'
            $ip = Get-RegistryValueSafe -Path $paramsPath -Name 'IPAddress'
            $hostName = Get-RegistryValueSafe -Path $paramsPath -Name 'HostName'
            if (-not $ip -and -not $hostName) { continue }
            if ($token -and $deviceHex -and ($deviceHex.Contains($token) -or $token.Contains($deviceHex))) {
                $host = if ($ip) { [string]$ip } else { [string]$hostName }
                return [pscustomobject]@{ Host = $host; IpAddress = $ip; HostName = $hostName; Source = $device.PSChildName }
            }
        }
        return $null
    } catch {
        Write-Log -Message ("Lettura registro WSD non riuscita: {0}" -f $_.Exception.Message) -Level 'WARN'
        return $null
    }
}

function Resolve-DnsNameSafe {
    param([Parameter(Mandatory = $true)][string]$Name, [int]$TimeoutMs = 1500)
    try {
        $task = [System.Net.Dns]::GetHostAddressesAsync($Name)
        if (-not $task.Wait($TimeoutMs)) {
            Write-Log -Message ("Risoluzione DNS '{0}' superata ({1} ms)." -f $Name, $TimeoutMs) -Level 'WARN'
            return $null
        }
        $addresses = @($task.Result)
        if ($addresses.Count -eq 0) { return $null }
        return @($addresses | ForEach-Object { $_.IPAddressToString })
    } catch {
        Write-Log -Message ("Risoluzione DNS '{0}' non riuscita: {1}" -f $Name, $_.Exception.Message) -Level 'WARN'
        return $null
    }
}

function Resolve-PrinterEndpoint {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$PrinterName,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$PortName
    )
    $result = [ordered]@{
        PrinterName = $PrinterName
        PortName   = $PortName
        Kind       = 'N/D'
        Host       = 'N/D'
        IpAddress  = 'N/D'
        TcpPort    = 'N/D'
        Source     = 'N/D'
        Notes      = New-Object System.Collections.Generic.List[string]
    }
    if ([string]::IsNullOrWhiteSpace($PortName)) {
        $result.Notes.Add("Stampante priva di porta associata: verificare la configurazione in Proprieta' > Porte.")
        return [pscustomobject]$result
    }

    $port = $PortName.Trim()
    $result.Kind = Get-PortKind -PortName $port

    if ($result.Kind -in @('Locale', 'Virtuale', 'USB')) {
        $result.Source = 'Tipo porta locale/virtuale'
        $result.Notes.Add('Porte locali/virtuali: nessuna verifica di rete applicabile.')
        return [pscustomobject]$result
    }

    $hostAddress = $null
    $tcpPort = $null
    $source = 'N/D'

    try {
        $pmPort = Get-PrinterPort -Name $port -ErrorAction Stop
        $pmHost = Get-SafeProp -InputObject $pmPort -Name 'PrinterHostAddress'
        if ($pmHost) {
            $hostAddress = [string]$pmHost
            $source = 'Cache porte (PrintManagement)'
            $pmPortNumber = Get-SafeProp -InputObject $pmPort -Name 'PortNumber'
            if ($pmPortNumber) { $tcpPort = [int]$pmPortNumber }
        }
    } catch {
        Write-Log -Message ("Cache porta '{0}' non disponibile: {1}" -f $port, $_.Exception.Message) -Level 'DEBUG'
    }

    if (-not $hostAddress) {
        $regTargets = @(
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Monitors\Standard TCP\IP Port\Ports\{0}" -f $port; Host = 'HostName'; Port = 'PortNumber' },
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Ports\{0}" -f $port; Host = 'HostAddress'; Port = 'Port' }
        )
        foreach ($regTarget in $regTargets) {
            if ($hostAddress) { break }
            $regHost = Get-RegistryValueSafe -Path $regTarget.Path -Name $regTarget.Host
            if (-not $regHost) { $regHost = Get-RegistryValueSafe -Path $regTarget.Path -Name 'HostName' }
            if (-not $regHost) { $regHost = Get-RegistryValueSafe -Path $regTarget.Path -Name 'PrinterHostAddress' }
            if ($regHost) {
                $hostAddress = [string]$regHost
                $source = 'Registro (Control\Print\Monitors\Standard TCP\IP Port\Ports)'
                $regPortNumber = Get-RegistryValueSafe -Path $regTarget.Path -Name $regTarget.Port
                if ($regPortNumber) { $tcpPort = [int]$regPortNumber }
            }
        }
    }

    if (-not $hostAddress) {
        $printerKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Printers\{0}" -f $PrinterName
        $regPrinterPort = Get-RegistryValueSafe -Path $printerKey -Name 'Port'
        if ($regPrinterPort) {
            $first = ([string]$regPrinterPort -split ',')[0]
            if ($first -and $first -ne $port) {
                $result.Notes.Add(("Registro stampante: porta '{0}' (porta attuale '{1}')." -f $first, $port))
            }
        }
    }

    if (-not $hostAddress) {
        $stripped = $port
        if ($stripped -like 'IP_*') { $stripped = $stripped.Substring(3) }
        if ($stripped -match '^\d{1,3}(\.\d{1,3}){3}$') {
            $hostAddress = $stripped
            $source = 'Stringa porta'
        } elseif ($stripped -like 'WSD*') {
            $source = 'Stringa porta (WSD)'
            $wsd = Get-WsdDeviceInfo -PortName $port
            if ($wsd) {
                $hostAddress = $wsd.Host
                $result.Notes.Add(("WSD: endpoint trovato nel registro dispositivi ({0})." -f $wsd.Source))
            } else {
                $result.Kind = 'WSD'
                $result.Source = 'Stringa porta (WSD)'
                $result.TcpPort = $script:WellKnownPorts.Raw
                $result.Notes.Add("Porte WSD non risolvibili via DNS/IP: il nome WSD e' un identificativo locale del dispositivo.")
                $result.Notes.Add("Verificare l'IP del dispositivo dal pannello frontale e ricreare una porta TCP/IP Standard (RAW 9100).")
                return [pscustomobject]$result
            }
        } elseif ($stripped -like '\\*') {
            $parts = $stripped.TrimStart('\') -split '\\'
            if ($parts.Count -ge 1 -and $parts[0]) {
                $hostAddress = $parts[0]
                $source = 'Stringa porta (condivisione)'
            }
        } elseif ($stripped -and $stripped -notmatch '^(COM|LPT|FILE|nul|PORTPROMPT)') {
            $hostAddress = $stripped
            $source = 'Stringa porta (host)'
        }
    }

    if (-not $hostAddress) {
        $result.Source = 'N/D'
        $result.Notes.Add("Impossibile determinare l'host della porta: nessun fallback disponibile.")
        return [pscustomobject]$result
    }

    $result.Host = $hostAddress
    $result.Source = $source

    if (-not $tcpPort) { $tcpPort = $script:WellKnownPorts.Raw }
    if ($result.Kind -eq 'WSD') { $tcpPort = $script:WellKnownPorts.Raw }

    if ($hostAddress -match '^\d{1,3}(\.\d{1,3}){3}$') {
        $result.IpAddress = $hostAddress
    } else {
        $resolved = @(Resolve-DnsNameSafe -Name $hostAddress | Where-Object { $_ })
        if ($resolved.Count -gt 0) {
            $result.IpAddress = (($resolved | Select-Object -First 3) -join ', ')
        } else {
            $result.IpAddress = 'N/D'
            $result.Notes.Add(("Risoluzione DNS non riuscita per '{0}' (timeout o nome non risolvibile)." -f $hostAddress))
        }
    }

    $result.TcpPort = [int]$tcpPort
    return [pscustomobject]$result
}

function Test-HostPing {
    param([Parameter(Mandatory = $true)][string]$HostName, [int]$TimeoutMs = 1500)
    try {
        $ping = New-Object System.Net.NetworkInformation.Ping
        $reply = $ping.Send($HostName, $TimeoutMs)
        if ($reply -and $reply.Status -eq 'Success') {
            return [pscustomobject]@{ Success = $true; Latency = $reply.RoundtripTime; Status = 'OK' }
        }
        $status = 'N/D'
        if ($reply) { $status = $reply.Status.ToString() }
        return [pscustomobject]@{ Success = $false; Latency = -1; Status = $status }
    } catch {
        return [pscustomobject]@{ Success = $false; Latency = -1; Status = $_.Exception.Message }
    }
}

function Test-TcpPort {
    param(
        [Parameter(Mandatory = $true)][string]$HostName,
        [Parameter(Mandatory = $true)][int]$Port,
        [int]$TimeoutMs = 1500
    )
    $client = New-Object System.Net.Sockets.TcpClient
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $async = $client.BeginConnect($HostName, $Port, $null, $null)
        if (-not $async.AsyncWaitHandle.WaitOne($TimeoutMs)) {
            return [pscustomobject]@{ Open = $false; ElapsedMs = [int]$watch.ElapsedMilliseconds; Detail = 'Timeout' }
        }
        $client.EndConnect($async)
        return [pscustomobject]@{ Open = $true; ElapsedMs = [int]$watch.ElapsedMilliseconds; Detail = 'Connesso' }
    } catch {
        return [pscustomobject]@{ Open = $false; ElapsedMs = [int]$watch.ElapsedMilliseconds; Detail = $_.Exception.Message }
    } finally {
        $watch.Stop()
        try { $client.Close() } catch { }
    }
}

function Test-PrinterNetwork {
    param([Parameter(Mandatory = $true)]$Endpoint)
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add(('Porta       : {0}   (tipo: {1})' -f $Endpoint.PortName, $Endpoint.Kind))
    $lines.Add(('Host        : {0}   [fonte: {1}]' -f $Endpoint.Host, $Endpoint.Source))
    $lines.Add(('Indirizzo IP: {0}' -f $Endpoint.IpAddress))
    $lines.Add(('Porta TCP   : {0}' -f $Endpoint.TcpPort))
    foreach ($note in $Endpoint.Notes) { $lines.Add(('Nota        : {0}' -f $note)) }

    if ($Endpoint.Kind -in @('Locale', 'Virtuale', 'USB')) {
        $lines.Add('Esito       : porta locale/virtuale, test di rete non applicabile.')
        return $lines
    }
    if ($Endpoint.Host -eq 'N/D') {
        $lines.Add('Esito       : host non determinabile, test di rete non eseguibile.')
        return $lines
    }

    $reachable = $false
    $ping = Test-HostPing -HostName $Endpoint.Host -TimeoutMs 1500
    if ($ping.Success) {
        $lines.Add(('Ping        : OK - {0} ms' -f $ping.Latency))
        $reachable = $true
    } else {
        $lines.Add(('Ping        : FALLITO - {0}' -f $ping.Status))
    }

    $ports = @([int]$Endpoint.TcpPort)
    if ($Endpoint.Kind -eq 'WSD' -and $ports -notcontains 631) { $ports += 631 }
    foreach ($port in @($ports | Select-Object -Unique)) {
        $tcp = Test-TcpPort -HostName $Endpoint.Host -Port $port -TimeoutMs 1500
        if ($tcp.Open) {
            $lines.Add(('TCP {0,-5}   : APERTO ({1} ms)' -f $port, $tcp.ElapsedMs))
            $reachable = $true
        } else {
            $lines.Add(('TCP {0,-5}   : CHIUSO/NON RAGGIUNGO ({1})' -f $port, $tcp.Detail))
        }
    }

    $profile = Get-NetConnectionProfileSafe
    if ($profile) {
        $lines.Add(('Rete        : {0} / {1} - categoria {2}' -f $profile.Name, $profile.InterfaceAlias, $profile.NetworkCategory))
    }

    if ($reachable) {
        $lines.Add('Esito       : stampante raggiungibile.')
    } else {
        $lines.Add('Esito       : stampante NON raggiungibile. Verificare alimentazione, cavo, IP e regole firewall.')
    }
    return $lines
}

function Get-NetConnectionProfileSafe {
    try {
        $profile = Get-NetConnectionProfile -ErrorAction Stop | Select-Object -First 1
        if ($profile) { return $profile }
    } catch {
        Write-Log -Message ("Profilo di rete non disponibile: {0}" -f $_.Exception.Message) -Level 'DEBUG'
    }
    return $null
}

function New-BadgeChar {
    param([Parameter(Mandatory = $true)][int]$CodePoint)
    try { return [char]::ConvertFromUtf32($CodePoint) } catch { return [char]0x26AA }
}

function Test-IPv4Address {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Address)
    $match = [regex]::Match($Address.Trim(), '^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$')
    if (-not $match.Success) { return $false }
    foreach ($group in 1..4) {
        $value = [int]$match.Groups[$group].Value
        if ($value -lt 0 -or $value -gt 255) { return $false }
    }
    return $true
}

function ConvertTo-IpUInt32 {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Address)
    if ([string]::IsNullOrWhiteSpace($Address)) { return [uint32]0 }
    try {
        $bytes = [System.Net.IPAddress]::Parse($Address.Trim()).GetAddressBytes()
        [Array]::Reverse($bytes)
        return [BitConverter]::ToUInt32($bytes, 0)
    } catch {
        return [uint32]0
    }
}

function Convert-PrefixToMask {
    param([int]$PrefixLength)
    if ($PrefixLength -lt 0 -or $PrefixLength -gt 32) { return $null }
    $bytes = New-Object byte[] 4
    for ($i = 0; $i -lt 4; $i++) {
        $remaining = $PrefixLength - ($i * 8)
        if ($remaining -ge 8) { $bytes[$i] = 255 }
        elseif ($remaining -le 0) { $bytes[$i] = 0 }
        else { $bytes[$i] = [byte]((255 -shl (8 - $remaining)) -band 255) }
    }
    return ([System.Net.IPAddress]::new($bytes)).ToString()
}

function Get-LocalIpv4Interfaces {
    if ($null -ne $script:LocalIpv4Cache) { return $script:LocalIpv4Cache }
    $list = New-Object System.Collections.Generic.List[object]
    try {
        $addresses = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop | Where-Object { $_.IPAddress -and $_.IPAddress -notlike '127.*' -and $null -ne $_.PrefixLength })
        foreach ($address in $addresses) {
            $mask = Convert-PrefixToMask -PrefixLength ([int]$address.PrefixLength)
            $list.Add([pscustomobject]@{
                IpAddress   = [string]$address.IPAddress
                Prefix      = [int]$address.PrefixLength
                Mask        = $mask
                Interface   = [string]$address.InterfaceAlias
                Scope       = [string]$address.AddressState
            })
        }
    } catch {
        Write-Log -Message ("Indirizzi IPv4 locali non disponibili: {0}" -f $_.Exception.Message) -Level 'DEBUG'
    }
    $script:LocalIpv4Cache = $list.ToArray()
    return $script:LocalIpv4Cache
}

function Get-PrinterSubnetMask {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$PortName,
        [string]$IpAddress = ''
    )
    $mask = $null
    $source = 'N/D'

    try {
        $pmPort = Get-PrinterPort -Name $PortName -ErrorAction Stop
        $pmMask = Get-SafeProp -InputObject $pmPort -Name 'SubnetMask'
        if ($pmMask) {
            $mask = [string]$pmMask
            $source = 'Cache porte (PrintManagement)'
        }
    } catch {
        Write-Log -Message ("Subnet mask dalla cache porte non disponibile: {0}" -f $_.Exception.Message) -Level 'DEBUG'
    }

    if (-not $mask) {
        $regTargets = @(
            "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Monitors\Standard TCP\IP Port\Ports\{0}" -f $PortName,
            "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Ports\{0}" -f $PortName
        )
        foreach ($regPath in $regTargets) {
            if ($mask) { break }
            $regMask = Get-RegistryValueSafe -Path $regPath -Name 'SubnetMask'
            if (-not $regMask) { $regMask = Get-RegistryValueSafe -Path $regPath -Name 'Subnet' }
            if ($regMask) {
                $mask = [string]$regMask
                $source = 'Registro (Control\Print\Ports)'
            }
        }
    }

    if (-not $mask -and $IpAddress -and (Test-IPv4Address -Address $IpAddress)) {
        $target = ConvertTo-IpUInt32 -Address $IpAddress
        foreach ($local in (Get-LocalIpv4Interfaces)) {
            if (-not $local.Mask) { continue }
            $localValue = ConvertTo-IpUInt32 -Address $local.IpAddress
            $maskValue = ConvertTo-IpUInt32 -Address $local.Mask
            if ((($localValue -band $maskValue) -eq ($target -band $maskValue))) {
                $mask = $local.Mask
                $source = ("Rete locale ({0}, /{1})" -f $local.Interface, $local.Prefix)
                break
            }
        }
    }

    if (-not $mask) { $mask = 'N/D' }
    return [pscustomobject]@{ Mask = $mask; Source = $source }
}

function Get-SubnetCidr {
    param([string]$IpAddress = '', [string]$Mask = '')
    if (-not $IpAddress -or -not $Mask) { return 'N/D' }
    if (-not (Test-IPv4Address -Address $IpAddress)) { return 'N/D' }
    if (-not (Test-IPv4Address -Address $Mask)) { return 'N/D' }
    try {
        $ipBytes = ([System.Net.IPAddress]::Parse($IpAddress.Trim())).GetAddressBytes()
        $maskBytes = ([System.Net.IPAddress]::Parse($Mask.Trim())).GetAddressBytes()
    } catch {
        return 'N/D'
    }
    if ($ipBytes.Length -ne 4 -or $maskBytes.Length -ne 4) { return 'N/D' }
    $networkBytes = New-Object byte[] 4
    for ($i = 0; $i -lt 4; $i++) {
        $networkBytes[$i] = [byte]($ipBytes[$i] -band $maskBytes[$i])
    }
    $prefix = 0
    foreach ($byte in $maskBytes) {
        for ($bit = 7; $bit -ge 0; $bit--) {
            if (($byte -band (1 -shl $bit)) -eq 0) { break }
            $prefix++
        }
    }
    return ("{0}/{1}" -f ([System.Net.IPAddress]::new($networkBytes)).ToString(), $prefix)
}

function Set-PrinterPortHostAddress {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$PortName,
        [Parameter(Mandatory = $true)][string]$NewIpAddress
    )
    $result = [ordered]@{ Success = $false; Method = 'N/D'; Details = New-Object System.Collections.Generic.List[string] }

    if ([string]::IsNullOrWhiteSpace($PortName)) {
        $result.Details.Add('Nome porta non valido.')
        return [pscustomobject]$result
    }

    $registryTargets = @(
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Monitors\Standard TCP\IP Port\Ports\{0}" -f $PortName; Values = @('HostName') },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Ports\{0}" -f $PortName; Values = @('HostAddress', 'HostName', 'PrinterHostAddress') }
    )
    $foundPath = $false
    foreach ($target in $registryTargets) {
        if (-not (Test-Path -LiteralPath $target.Path)) { continue }
        $foundPath = $true
        $hostValueFound = $false
        foreach ($valueName in $target.Values) {
            $current = Get-RegistryValueSafe -Path $target.Path -Name $valueName
            if ($null -eq $current -or [string]::IsNullOrWhiteSpace([string]$current)) { continue }
            $hostValueFound = $true
            try {
                Set-ItemProperty -LiteralPath $target.Path -Name $valueName -Value $NewIpAddress -ErrorAction Stop
                $applied = [string](Get-RegistryValueSafe -Path $target.Path -Name $valueName)
                if ($applied -eq $NewIpAddress) {
                    $result.Success = $true
                    $result.Method = 'Registro (Control\Print\Monitors\Standard TCP\IP Port\Ports)'
                    $result.Details.Add(("Registro: '{0}' -> {1} = {2}" -f $target.Path, $valueName, $NewIpAddress))
                    return [pscustomobject]$result
                }
                $result.Details.Add(("Registro: il valore '{0}' non ha confermato il nuovo indirizzo (letto: '{1}')." -f $valueName, $applied))
            } catch {
                $result.Details.Add(("Registrazione non riuscita su '{0}' ({1}): {2}" -f $target.Path, $valueName, $_.Exception.Message))
            }
        }
        if (-not $hostValueFound) {
            $result.Details.Add(("Nessun valore di host trovato in '{0}'." -f $target.Path))
        }
    }
    if (-not $foundPath) {
        $result.Details.Add(("Nessuna chiave di registro per la porta '{0}': la porta non risulta installata." -f $PortName))
    }

    try {
        $cimPort = Get-CimInstance -Namespace 'root/StandardCimv2' -ClassName MSFT_TCPIPPrinterPort -ErrorAction Stop |
            Where-Object { $_.Name -eq $PortName } | Select-Object -First 1
        if ($cimPort) {
            try {
                Set-CimInstance -InputObject $cimPort -Property @{ PrinterHostAddress = $NewIpAddress } -ErrorAction Stop
                $verify = Get-CimInstance -Namespace 'root/StandardCimv2' -ClassName MSFT_TCPIPPrinterPort -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -eq $PortName } | Select-Object -First 1
                $applied = ''
                if ($verify) { $applied = [string](Get-SafeProp -InputObject $verify -Name 'PrinterHostAddress') }
                if ($applied -eq $NewIpAddress) {
                    $result.Success = $true
                    $result.Method = 'CIM MSFT_TCPIPPrinterPort'
                    $result.Details.Add(("CIM: PrinterHostAddress di '{0}' = {1}" -f $PortName, $NewIpAddress))
                    return [pscustomobject]$result
                }
                $result.Details.Add(("CIM: la porta '{0}' non ha confermato il nuovo indirizzo (valore letto: '{1}')." -f $PortName, $applied))
            } catch {
                $result.Details.Add(("Aggiornamento CIM della porta non riuscito: {0}" -f $_.Exception.Message))
            }
        } else {
            $result.Details.Add(("Nessuna porta CIM MSFT_TCPIPPrinterPort denominata '{0}'." -f $PortName))
        }
    } catch {
        $result.Details.Add(("Interrogazione CIM delle porte non riuscita: {0}" -f $_.Exception.Message))
    }

    try {
        $wmiPort = Get-CimInstance -ClassName Win32_TCPIPPrinterPort -ErrorAction Stop |
            Where-Object { $_.Name -eq $PortName } | Select-Object -First 1
        if ($wmiPort) {
            foreach ($methodName in @('Put_', 'Put')) {
                try {
                    Invoke-CimMethod -InputObject $wmiPort -MethodName $methodName -Arguments @{ HostAddress = $NewIpAddress } -ErrorAction Stop | Out-Null
                    $result.Success = $true
                    $result.Method = 'WMI Win32_TCPIPPrinterPort'
                    $result.Details.Add(("WMI: HostAddress di '{0}' = {1}" -f $PortName, $NewIpAddress))
                    return [pscustomobject]$result
                } catch {
                    $result.Details.Add(("WMI {0}: {1}" -f $methodName, $_.Exception.Message))
                }
            }
        } else {
            $result.Details.Add(("Nessuna istanza WMI Win32_TCPIPPrinterPort denominata '{0}'." -f $PortName))
        }
    } catch {
        $result.Details.Add(("Interrogazione WMI delle porte non riuscita: {0}" -f $_.Exception.Message))
    }

    return [pscustomobject]$result
}

function Set-PrinterIpAddress {
    param(
        [Parameter(Mandatory = $true)][string]$TargetPrinter,
        [Parameter(Mandatory = $true)][string]$NewIpAddress,
        [string]$PortName = '',
        [int]$PortNumber = 9100
    )
    $result = [ordered]@{ Success = $false; Message = ''; Method = 'N/D'; OldPort = $PortName; NewPort = $PortName; Details = New-Object System.Collections.Generic.List[string] }

    if (-not (Test-IPv4Address -Address $NewIpAddress)) {
        $result.Message = ("'{0}' non e' un indirizzo IPv4 valido." -f $NewIpAddress)
        return [pscustomobject]$result
    }
    if (-not $PortName) {
        $result.Message = 'La stampante selezionata non ha una porta associata: impossibile modificarne l''IP.'
        return [pscustomobject]$result
    }

    $kind = Get-PortKind -PortName $PortName
    if ($kind -in @('Locale', 'Virtuale', 'USB')) {
        $result.Message = ("La porta '{0}' e' di tipo {1}: l'indirizzo IP non e' modificabile." -f $PortName, $kind)
        return [pscustomobject]$result
    }

    if ($kind -eq 'Condivisa') {
        $result.Message = ("La stampante '{0}' e' condivisa: l'IP va modificato sul server che ospita la coda." -f $TargetPrinter)
        return [pscustomobject]$result
    }

    if ($PortName -like 'IP_*') {
        $portUpdate = Set-PrinterPortHostAddress -PortName $PortName -NewIpAddress $NewIpAddress
        foreach ($detail in $portUpdate.Details) { $result.Details.Add($detail) }
        if ($portUpdate.Success) {
            $result.Success = $true
            $result.Method = $portUpdate.Method
            $result.Message = ("Indirizzo della porta '{0}' aggiornato a {1}." -f $PortName, $NewIpAddress)
            $result.Details.Add(("Aggiornata la porta RAW '{0}' con il nuovo indirizzo." -f $PortName))
            Write-Log -Message $result.Message -Level 'OK'
            [void](Invoke-SpoolerAction -Action Restart)
            return [pscustomobject]$result
        }

        $result.Message = ("Impossibile aggiornare la porta '{0}': la porta RAW non e' installata o non e' modificabile." -f $PortName)
        Write-Log -Message $result.Message -Level 'ERROR'
        return [pscustomobject]$result
    }

    $newPortName = $NewIpAddress
    $portCreated = $false
    try {
        Add-PrinterPort -Name $newPortName -PrinterHostAddress $NewIpAddress -PortNumber $PortNumber -ErrorAction Stop
        $portCreated = $true
        $result.Details.Add("Creata la porta TCP/IP Standard '$newPortName' (porta $PortNumber).")
    } catch {
        $result.Details.Add(("Creazione porta non riuscita (esiste gia'?): {0}" -f $_.Exception.Message))
    }

    try {
        Set-Printer -Name $TargetPrinter -PortName $newPortName -ErrorAction Stop
        $result.Success = $true
        $result.Method = 'Add-PrinterPort + Set-Printer'
        $result.NewPort = $newPortName
        $result.Message = ("Stampante '{0}' aggiornata: porta '{1}' con IP {2}." -f $TargetPrinter, $newPortName, $NewIpAddress)
        if ($kind -eq 'WSD') {
            $result.Details.Add("La porta WSD non e' modificabile in-place: la stampante e' stata spostata su una porta TCP/IP Standard.")
        }
        Write-Log -Message $result.Message -Level 'OK'
    } catch {
        $result.Details.Add(("Set-Printer non riuscito: {0}" -f $_.Exception.Message))
        $result.Message = ("Impossibile associare la nuova porta a '{0}': {1}" -f $TargetPrinter, $_.Exception.Message)
        if ($portCreated) {
            try { Remove-PrinterPort -Name $newPortName -ErrorAction SilentlyContinue } catch { }
        }
        return [pscustomobject]$result
    }

    try {
        $others = @(Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne $TargetPrinter -and $_.PortName -eq $PortName })
        if ($others.Count -eq 0) {
            Remove-PrinterPort -Name $PortName -ErrorAction SilentlyContinue
            $result.Details.Add(("Rimossa la vecchia porta '{0}' non piu' in uso." -f $PortName))
        } else {
            $result.Details.Add(("La vecchia porta '{0}' e' ancora usata da {1} stampante/i e non e' stata rimossa." -f $PortName, $others.Count))
        }
    } catch {
        $result.Details.Add(("Rimozione della vecchia porta non riuscita: {0}" -f $_.Exception.Message))
    }

    [void](Invoke-SpoolerAction -Action Restart)
    $result.Details.Add('Servizio Spooler riavviato.')
    return [pscustomobject]$result
}

function Get-PrinterStatusInfo {
    param(
        [Parameter(Mandatory = $false)]$StatusCode,
        [bool]$WorkOffline = $false,
        [int]$PrinterState = 0
    )
    $badgeOffline = New-BadgeChar -CodePoint 0x26AA
    $badgeError = New-BadgeChar -CodePoint 0x1F534
    $badgeReady = New-BadgeChar -CodePoint 0x1F7E2
    $badgePrinting = New-BadgeChar -CodePoint 0x1F7E3
    $badgeWaiting = New-BadgeChar -CodePoint 0x1F7E1
    if ($WorkOffline -or ($PrinterState -band 128)) {
        return [pscustomobject]@{ Text = 'Offline'; Color = $script:ColorTextMuted; Badge = $badgeOffline }
    }
    $code = -1
    if ($null -ne $StatusCode) { try { $code = [int]$StatusCode } catch { $code = -1 } }
    switch ($code) {
        1 { return [pscustomobject]@{ Text = 'Errore'; Color = $script:ColorError; Badge = $badgeError } }
        2 { return [pscustomobject]@{ Text = 'Sconosciuto'; Color = $script:ColorTextMuted; Badge = $badgeOffline } }
        3 { return [pscustomobject]@{ Text = 'Pronta'; Color = $script:ColorSuccess; Badge = $badgeReady } }
        4 { return [pscustomobject]@{ Text = 'In stampa'; Color = $script:ColorAccent; Badge = $badgePrinting } }
        5 { return [pscustomobject]@{ Text = 'Offline'; Color = $script:ColorTextMuted; Badge = $badgeOffline } }
        6 { return [pscustomobject]@{ Text = 'In attesa'; Color = $script:ColorWarning; Badge = $badgeWaiting } }
        7 { return [pscustomobject]@{ Text = 'In pausa'; Color = $script:ColorWarning; Badge = $badgeWaiting } }
        8 { return [pscustomobject]@{ Text = 'Errore'; Color = $script:ColorError; Badge = $badgeError } }
        9 { return [pscustomobject]@{ Text = 'Occupata'; Color = $script:ColorAccent; Badge = $badgePrinting } }
        10 { return [pscustomobject]@{ Text = 'Non pronta'; Color = $script:ColorWarning; Badge = $badgeWaiting } }
        11 { return [pscustomobject]@{ Text = 'In elaborazione'; Color = $script:ColorAccent; Badge = $badgePrinting } }
        12 { return [pscustomobject]@{ Text = 'In attesa'; Color = $script:ColorWarning; Badge = $badgeWaiting } }
        default {
            if ($PrinterState -band 4) { return [pscustomobject]@{ Text = 'Errore'; Color = $script:ColorError; Badge = $badgeError } }
            if ($PrinterState -band 16) { return [pscustomobject]@{ Text = 'In pausa'; Color = $script:ColorWarning; Badge = $badgeWaiting } }
            return [pscustomobject]@{ Text = 'Inattiva'; Color = $script:ColorTextMuted; Badge = $badgeOffline }
        }
    }
}

function Get-LastPrintErrorEvent {
    try {
        $event = Get-WinEvent -LogName 'Microsoft-Windows-PrintService/Operational' -MaxEvents 15 -ErrorAction SilentlyContinue |
            Where-Object { $_.Id -in @(372, 215, 216, 808) } |
            Select-Object -First 1
        if ($event) {
            $message = Get-SafeText -InputObject $event -Name 'Message' -Default ''
            if ($message.Length -gt 160) { $message = $message.Substring(0, 160) + '...' }
            return ("[{0:HH:mm:ss}] Evento ID {1}: {2}" -f $event.TimeCreated, $event.Id, $message)
        }
    } catch {
        Write-Log -Message ("Lettura eventi di stampa non riuscita: {0}" -f $_.Exception.Message) -Level 'DEBUG'
    }
    return 'Nessun errore recente nel registro di stampa'
}

function Get-PrinterDriverSearchUrl {
    param([Parameter(Mandatory = $true)][string]$PrinterName, [Parameter(Mandatory = $true)][string]$DriverName)
    $model = ($PrinterName -replace '\s+', ' ').Trim()
    $query = [System.Uri]::EscapeDataString($model)
    $vendors = @(
        @{ Pattern = 'Brother'; Url = "https://support.brother.com/g/s/driver/choose?language=it" },
        @{ Pattern = 'HP|Hewlett'; Url = "https://support.hp.com/it-it/drivers/$query" },
        @{ Pattern = 'Canon'; Url = "https://www.canon.it/support/consumer/product-search?search=$query" },
        @{ Pattern = 'Epson'; Url = "https://epson.com/Support/wa/section1?s=EPSON%20$query" },
        @{ Pattern = 'Kyocera'; Url = "https://kyoceradocsupport.com/en/products/printer/download" },
        @{ Pattern = 'Ricoh'; Url = "https://www.ricoh-imaging.it/software-download/" },
        @{ Pattern = 'Samsung'; Url = "https://www.samsung.com/it/support/model/$query" },
        @{ Pattern = 'Xerox'; Url = "https://www.support.xerox.com/eu/it/?query=$query" },
        @{ Pattern = 'Lexmark'; Url = "https://support.lexmark.com/it_it/download-printers" }
    )
    foreach ($vendor in $vendors) {
        if ($PrinterName -match $vendor.Pattern) { return $vendor.Url }
    }
    return "https://www.google.com/search?q=driver+stampante+$query"
}

function New-PrinterRecord {
    param(
        [Parameter(Mandatory = $false)]$Wmi,
        [Parameter(Mandatory = $false)]$Pm,
        [string]$DefaultName = ''
    )
    $name = Get-SafeText -InputObject $Wmi -Name 'Name' -Default (Get-SafeText -InputObject $Pm -Name 'Name' -Default '')
    $port = Get-SafeText -InputObject $Wmi -Name 'PortName' -Default (Get-SafeText -InputObject $Pm -Name 'PortName' -Default 'N/D')
    $driver = Get-SafeText -InputObject $Wmi -Name 'DriverName' -Default (Get-SafeText -InputObject $Pm -Name 'DriverName' -Default 'N/D')
    $location = Get-SafeText -InputObject $Wmi -Name 'Location' -Default (Get-SafeText -InputObject $Pm -Name 'Location' -Default '')
    $comment = Get-SafeText -InputObject $Wmi -Name 'Comment' -Default (Get-SafeText -InputObject $Pm -Name 'Comment' -Default '')

    $status = 'N/D'
    $statusSource = 'N/D'
    $statusInfo = $null
    $pmStatus = Get-SafeProp -InputObject $Pm -Name 'PrinterStatus'
    if ($pmStatus) {
        $status = Get-StatusText -Status $pmStatus
        $statusSource = 'PrintManagement'
    } else {
        $code = Get-SafeProp -InputObject $Wmi -Name 'PrinterStatus'
        if ($null -ne $code) {
            $key = [int]$code
            if ($script:StatusMap.ContainsKey($key)) { $status = $script:StatusMap[$key] } else { $status = "Codice $key" }
            $statusSource = 'Win32_Printer'
        }
    }

    $workOffline = $false
    $offlineValue = Get-SafeProp -InputObject $Wmi -Name 'WorkOffline'
    if ($offlineValue -is [bool]) { $workOffline = $offlineValue }
    $printerState = 0
    $stateValue = Get-SafeProp -InputObject $Wmi -Name 'PrinterState'
    if ($null -ne $stateValue) { try { $printerState = [int]$stateValue } catch { $printerState = 0 } }
    $statusInfo = Get-PrinterStatusInfo -StatusCode (Get-SafeProp -InputObject $Wmi -Name 'PrinterStatus') -WorkOffline $workOffline -PrinterState $printerState
    if ($statusSource -eq 'Win32_Printer' -and $statusInfo) { $status = $statusInfo.Text }

    $jobs = 0
    $jobValue = Get-SafeProp -InputObject $Wmi -Name 'JobCountSinceLastReset'
    if ($null -ne $jobValue) {
        $jobs = [int]$jobValue
    } else {
        $pmJobs = Get-SafeProp -InputObject $Pm -Name 'JobCount'
        if ($null -ne $pmJobs) { $jobs = [int]$pmJobs }
    }

    $isDefault = $false
    if ($DefaultName -and $name -and $DefaultName -eq $name) { $isDefault = $true }
    if (-not $isDefault) {
        $wmiDefault = Get-SafeProp -InputObject $Wmi -Name 'Default'
        if ($wmiDefault -is [bool]) { $isDefault = $wmiDefault }
    }

    $type = 'N/D'
    $pmType = Get-SafeProp -InputObject $Pm -Name 'Type'
    if ($pmType) {
        $type = Get-StatusText -Status $pmType
    } else {
        $wmiType = Get-SafeProp -InputObject $Wmi -Name 'Type'
        if ($null -ne $wmiType) {
            switch ([int]$wmiType) {
                1 { $type = 'Locale' }
                2 { $type = 'Condivisa' }
                4 { $type = 'Rete' }
                default { $type = 'Altro' }
            }
        }
    }

    $shared = $false
    $sharedValue = Get-SafeProp -InputObject $Wmi -Name 'Shared'
    if ($sharedValue -is [bool]) {
        $shared = $sharedValue
    } else {
        $pmShared = Get-SafeProp -InputObject $Pm -Name 'Shared'
        if ($pmShared -is [bool]) { $shared = $pmShared }
    }

    $network = $false
    $networkValue = Get-SafeProp -InputObject $Wmi -Name 'Network'
    if ($networkValue -is [bool]) { $network = $networkValue }

    $endpoint = Resolve-PrinterEndpoint -PrinterName $name -PortName $port
    $subnet = Get-PrinterSubnetMask -PortName $port -IpAddress $endpoint.IpAddress
    $cidr = Get-SubnetCidr -IpAddress $endpoint.IpAddress -Mask $subnet.Mask

    $badge = New-BadgeChar -CodePoint 0x26AA
    $statusColor = $script:ColorTextMuted
    if ($statusInfo) {
        $badge = $statusInfo.Badge
        $statusColor = $statusInfo.Color
    }

    return [pscustomobject]@{
        Name          = $name
        PortName      = $port
        DriverName    = $driver
        Location      = $location
        Comment       = $comment
        Status        = $status
        StatusSource  = $statusSource
        StatusBadge   = $badge
        StatusColor   = $statusColor
        IsOffline     = $workOffline
        PrinterState  = $printerState
        JobCount      = $jobs
        IsDefault     = $isDefault
        Type          = $type
        Shared        = $shared
        IsNetwork     = $network
        PortKind      = $endpoint.Kind
        Host          = $endpoint.Host
        IpAddress     = $endpoint.IpAddress
        SubnetMask    = $subnet.Mask
        SubnetSource  = $subnet.Source
        SubnetCidr    = $cidr
        TcpPort       = $endpoint.TcpPort
        ResolveSource = $endpoint.Source
        Notes         = $endpoint.Notes
        LastLogError  = ''
        RawWmi        = $Wmi
        RawPm         = $Pm
    }
}

function Get-PrinterInventory {
    $inventory = New-Object System.Collections.Generic.List[object]
    $wmiPrinters = @()
    $pmPrinters = @()

    try {
        $wmiPrinters = @(Get-CimInstance -ClassName Win32_Printer -ErrorAction Stop)
        Write-Log -Message ("Win32_Printer: {0} stampanti rilevate" -f $wmiPrinters.Count) -Level 'INFO'
    } catch {
        Write-Log -Message ("Query Win32_Printer non riuscita: {0}" -f $_.Exception.Message) -Level 'ERROR'
    }

    try {
        $pmPrinters = @(Get-Printer -ErrorAction Stop)
        Write-Log -Message ("PrintManagement: {0} stampanti rilevate" -f $pmPrinters.Count) -Level 'INFO'
    } catch {
        Write-Log -Message ("Get-Printer non riuscito: {0}" -f $_.Exception.Message) -Level 'WARN'
    }

    $defaultName = $null
    try {
        $wsn = New-Object -ComObject WScript.Network
        $defaultName = [string]$wsn.DefaultPrinter
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($wsn)
    } catch {
        Write-Log -Message ("Rilevamento stampante predefinita via WScript non riuscito: {0}" -f $_.Exception.Message) -Level 'WARN'
    }
    if ([string]::IsNullOrWhiteSpace($defaultName)) {
        try {
            foreach ($candidate in $wmiPrinters) {
                $isDefaultCandidate = Get-SafeProp -InputObject $candidate -Name 'Default'
                if ($isDefaultCandidate -is [bool] -and $isDefaultCandidate) {
                    $defaultName = [string](Get-SafeText -InputObject $candidate -Name 'Name' -Default '')
                    break
                }
            }
        } catch {
            Write-Log -Message ("Rilevamento stampante predefinita via CIM non riuscito: {0}" -f $_.Exception.Message) -Level 'WARN'
        }
    }

    $pmIndex = @{}
    foreach ($pm in $pmPrinters) {
        $pmName = Get-SafeText -InputObject $pm -Name 'Name' -Default ''
        if ($pmName) { $pmIndex[$pmName.ToLowerInvariant()] = $pm }
    }

    $seen = New-Object System.Collections.Generic.HashSet[string]
    $script:LocalIpv4Cache = $null
    $lastError = Get-LastPrintErrorEvent
    foreach ($wmi in $wmiPrinters) {
        $name = Get-SafeText -InputObject $wmi -Name 'Name' -Default ''
        if (-not $name) { continue }
        [void]$seen.Add($name.ToLowerInvariant())
        $pm = $null
        $key = $name.ToLowerInvariant()
        if ($pmIndex.ContainsKey($key)) { $pm = $pmIndex[$key] }
        $record = New-PrinterRecord -Wmi $wmi -Pm $pm -DefaultName $defaultName
        $record.LastLogError = $lastError
        $inventory.Add($record)
    }

    foreach ($pm in $pmPrinters) {
        $name = Get-SafeText -InputObject $pm -Name 'Name' -Default ''
        if (-not $name) { continue }
        $key = $name.ToLowerInvariant()
        if ($seen.Contains($key)) { continue }
        $record = New-PrinterRecord -Wmi $null -Pm $pm -DefaultName $defaultName
        $record.LastLogError = $lastError
        $inventory.Add($record)
    }

    return $inventory
}

function Get-PrinterJobInfo {
    param([Parameter(Mandatory = $true)][string]$TargetPrinter)
    $jobs = New-Object System.Collections.Generic.List[object]
    $raw = @()
    try {
        $raw = @(Get-PrintJob -PrinterName $TargetPrinter -ErrorAction Stop)
    } catch {
        Write-Log -Message ("Get-PrintJob non riuscito per '{0}': {1}" -f $TargetPrinter, $_.Exception.Message) -Level 'WARN'
        try {
            $raw = @(Get-CimInstance -ClassName Win32_PrintJob -ErrorAction Stop | Where-Object { $_.Name -like ($TargetPrinter + '*') })
        } catch {
            Write-Log -Message ("Win32_PrintJob non disponibile: {0}" -f $_.Exception.Message) -Level 'ERROR'
            $raw = @()
        }
    }
    foreach ($job in $raw) {
        $id = Get-SafeProp -InputObject $job -Name 'ID'
        if ($null -eq $id) { $id = Get-SafeProp -InputObject $job -Name 'JobId' }
        $jobs.Add([pscustomobject]@{
            Id        = Get-SafeText -InputObject $job -Name 'ID' -Default '0'
            RawId     = $id
            User      = Get-SafeText -InputObject $job -Name 'UserName' -Default 'N/D'
            Document  = Get-SafeText -InputObject $job -Name 'DocumentName' -Default 'N/D'
            Status    = Get-StatusText -Status (Get-SafeProp -InputObject $job -Name 'JobStatus') -Fallback 'N/D'
            Size      = Get-SafeText -InputObject $job -Name 'Size' -Default '0'
            Submitted = Get-SafeText -InputObject $job -Name 'SubmittedTime' -Default 'N/D'
            Path      = Get-SafeText -InputObject $job -Name 'Path' -Default ''
            Raw       = $job
        })
    }
    return $jobs
}

function Get-SpoolerHealth {
    $health = [ordered]@{
        ServiceName    = 'Spooler'
        Status         = 'N/D'
        StartType      = 'N/D'
        PendingJobs    = 0
        QueueFiles     = 0
        QueueSizeBytes = 0
        QueuePath      = 'N/D'
        DriversPresent = $false
        Errors         = New-Object System.Collections.Generic.List[string]
    }
    try {
        $svc = Get-Service -Name Spooler -ErrorAction Stop
        $health.Status = $svc.Status.ToString()
    } catch {
        $health.Errors.Add("Servizio Spooler non interrogabile: $($_.Exception.Message)")
    }
    try {
        $svcCim = Get-CimInstance -ClassName Win32_Service -Filter "Name='Spooler'" -ErrorAction Stop
        $health.StartType = Get-SafeText -InputObject $svcCim -Name 'StartMode' -Default 'N/D'
    } catch { }
    $queuePath = Join-Path -Path $env:WINDIR -ChildPath 'System32\spool\PRINTERS'
    $health.QueuePath = $queuePath
    try {
        if (Test-Path -LiteralPath $queuePath) {
            $files = @(Get-ChildItem -LiteralPath $queuePath -Force -File -ErrorAction SilentlyContinue)
            $health.QueueFiles = $files.Count
            $size = 0
            foreach ($f in $files) { try { $size += $f.Length } catch { } }
            $health.QueueSizeBytes = $size
        }
    } catch {
        $health.Errors.Add("Cartella spool non leggibile: $($_.Exception.Message)")
    }
    $health.DriversPresent = (Test-Path -LiteralPath (Join-Path -Path $env:WINDIR -ChildPath 'System32\spool\DRIVERS'))
    try {
        $health.PendingJobs = @(Get-CimInstance -ClassName Win32_PrintJob -ErrorAction Stop).Count
    } catch {
        $health.Errors.Add("Win32_PrintJob non leggibile: $($_.Exception.Message)")
    }
    return [pscustomobject]$health
}

function Get-SpoolerEventErrors {
    param([int]$MaxEvents = 15, [int]$HoursBack = 24)
    $events = New-Object System.Collections.Generic.List[string]
    $since = (Get-Date).AddHours(-1 * $HoursBack)
    foreach ($log in @('Microsoft-Windows-PrintService/Admin', 'Microsoft-Windows-PrintService/Operational')) {
        try {
            $records = @(Get-WinEvent -FilterHashtable @{ LogName = $log; StartTime = $since; Level = 1, 2, 3 } -MaxEvents $MaxEvents -ErrorAction Stop)
            foreach ($rec in $records) {
                $msg = Get-SafeText -InputObject $rec -Name 'Message' -Default ''
                if ($msg.Length -gt 220) { $msg = $msg.Substring(0, 220) + '...' }
                $events.Add(("{0:yyyy-MM-dd HH:mm:ss} [{1}] {2} :: {3}" -f $rec.TimeCreated, $log, (Get-SafeText -InputObject $rec -Name 'LevelDisplayName' -Default '?'), $msg))
            }
        } catch {
            Write-Log -Message ("Lettura eventi '{0}' non riuscita: {1}" -f $log, $_.Exception.Message) -Level 'WARN'
        }
    }
    return $events
}

function Invoke-SpoolerAction {
    param(
        [ValidateSet('Start', 'Stop', 'Restart')][string]$Action = 'Restart',
        [int]$TimeoutSeconds = 30
    )
    $result = [ordered]@{ Success = $false; PreviousStatus = 'N/D'; CurrentStatus = 'N/D'; Message = '' }
    try {
        $svc = Get-Service -Name Spooler -ErrorAction Stop
        $result.PreviousStatus = $svc.Status.ToString()
    } catch { }
    try {
        switch ($Action) {
            'Stop' {
                Stop-Service -Name Spooler -Force -ErrorAction Stop
            }
            'Start' {
                Start-Service -Name Spooler -ErrorAction Stop
            }
            'Restart' {
                Stop-Service -Name Spooler -Force -ErrorAction SilentlyContinue
                $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
                while ((Get-Date) -lt $deadline) {
                    $state = (Get-Service -Name Spooler -ErrorAction SilentlyContinue).Status
                    if ($state -eq 'Stopped') { break }
                    Start-Sleep -Milliseconds 300
                }
                Start-Service -Name Spooler -ErrorAction Stop
            }
        }
        $svcNow = Get-Service -Name Spooler -ErrorAction Stop
        $result.CurrentStatus = $svcNow.Status.ToString()
        $result.Success = $true
        $result.Message = ("Servizio Spooler: {0} completata, stato attuale {1}." -f $Action, $result.CurrentStatus)
        Write-Log -Message $result.Message -Level 'OK'
    } catch {
        $current = (Get-Service -Name Spooler -ErrorAction SilentlyContinue).Status
        if ($current) { $result.CurrentStatus = $current.ToString() }
        $result.Message = ("Operazione '{0}' sul servizio Spooler non riuscita: {1}" -f $Action, $_.Exception.Message)
        Write-Log -Message $result.Message -Level 'ERROR'
    }
    return [pscustomobject]$result
}

function Set-SpoolerQueueOwnership {
    param([Parameter(Mandatory = $true)][string]$QueuePath)
    $adminSid = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
    try {
        $acl = Get-Acl -LiteralPath $QueuePath -ErrorAction Stop
        $acl.SetOwner($adminSid)
        Set-Acl -LiteralPath $QueuePath -AclObject $acl -ErrorAction Stop
        Write-Log -Message 'Proprieta'' della cartella spool impostata sul gruppo Administrators.' -Level 'INFO'
    } catch {
        Write-Log -Message ("Impostazione della proprieta'' tramite .NET non riuscita: {0}" -f $_.Exception.Message) -Level 'DEBUG'
    }
    try {
        & icacls.exe $QueuePath /grant '*S-1-5-32-544:(OI)(CI)F' /T /C 2>&1 | Out-Null
    } catch {
        Write-Log -Message ("Assegnazione dei permessi tramite icacls non riuscita: {0}" -f $_.Exception.Message) -Level 'DEBUG'
    }
    try {
        & takeown.exe /F $QueuePath /R /A 2>&1 | Out-Null
    } catch {
        Write-Log -Message ("Acquisto della proprieta'' tramite takeown non riuscito: {0}" -f $_.Exception.Message) -Level 'DEBUG'
    }
}

function Clear-SpoolerQueue {
    $queuePath = Join-Path -Path $env:WINDIR -ChildPath 'System32\spool\PRINTERS'
    $result = [ordered]@{ Success = $false; Removed = 0; Message = ''; QueuePath = $queuePath }
    if (-not (Test-Path -LiteralPath $queuePath)) {
        $result.Message = ("Cartella spool non trovata: {0}" -f $queuePath)
        Write-Log -Message $result.Message -Level 'ERROR'
        return [pscustomobject]$result
    }
    $stop = Invoke-SpoolerAction -Action 'Stop'
    if (-not $stop.Success) {
        $result.Message = "Impossibile fermare il servizio Spooler: $($stop.Message)"
        return [pscustomobject]$result
    }
    try {
        $removed = 0
        $attempt = 0
        while ($attempt -lt 2) {
            try {
                $files = @(Get-ChildItem -LiteralPath $queuePath -Force -File -ErrorAction Stop)
                foreach ($file in $files) {
                    try {
                        Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                        $removed++
                    } catch {
                        Write-Log -Message ("Rimozione non riuscita di '{0}': {1}" -f $file.Name, $_.Exception.Message) -Level 'WARN'
                    }
                }
                $remaining = @(Get-ChildItem -LiteralPath $queuePath -Force -File -ErrorAction SilentlyContinue)
                if ($remaining.Count -eq 0) { break }
                Set-SpoolerQueueOwnership -QueuePath $queuePath
                $attempt++
            } catch {
                Write-Log -Message ("Svuotamento coda non riuscito: {0}" -f $_.Exception.Message) -Level 'ERROR'
                break
            }
        }
        $result.Removed = $removed
        $remainingFiles = @(Get-ChildItem -LiteralPath $queuePath -Force -File -ErrorAction SilentlyContinue)
        if ($remainingFiles.Count -eq 0) {
            $result.Success = $true
            $result.Message = ("Coda spool svuotata: {0} file rimossi." -f $removed)
            Write-Log -Message $result.Message -Level 'OK'
        } else {
            $result.Message = ("Rimossi {0} file, {1} file ancora presenti (file bloccati dal driver o permessi insufficienti)." -f $removed, $remainingFiles.Count)
            Write-Log -Message $result.Message -Level 'ERROR'
        }
    } finally {
        [void](Invoke-SpoolerAction -Action 'Start')
    }
    return [pscustomobject]$result
}

function Clear-PrinterQueue {
    param([Parameter(Mandatory = $true)][string]$TargetPrinter)
    $result = [ordered]@{ Success = $false; Removed = 0; Message = '' }
    $removed = 0
    try {
        $jobs = @(Get-PrintJob -PrinterName $TargetPrinter -ErrorAction Stop)
    } catch {
        Write-Log -Message ("Impossibile leggere i lavori di '{0}': {1}" -f $TargetPrinter, $_.Exception.Message) -Level 'WARN'
        $jobs = @()
    }
    foreach ($job in $jobs) {
        try {
            Remove-PrintJob -PrinterName $TargetPrinter -ID $job.ID -ErrorAction Stop
            $removed++
        } catch {
            Write-Log -Message ("Rimozione lavoro {0} non riuscita: {1}" -f $job.ID, $_.Exception.Message) -Level 'WARN'
        }
    }
    if ($removed -eq 0 -and $jobs.Count -gt 0) {
        try {
            $cimJobs = @(Get-CimInstance -ClassName Win32_PrintJob -ErrorAction Stop | Where-Object { $_.Name -like ($TargetPrinter + '*') })
            foreach ($cimJob in $cimJobs) {
                Invoke-CimMethod -InputObject $cimJob -MethodName Delete -ErrorAction Stop | Out-Null
                $removed++
            }
        } catch {
            Write-Log -Message ("Rimozione lavori via WMI non riuscita: {0}" -f $_.Exception.Message) -Level 'WARN'
        }
    }
    $result.Success = $true
    if ($removed -gt 0) {
        $result.Removed = $removed
        $result.Message = ("{0} lavori rimossi dalla coda di '{1}'." -f $removed, $TargetPrinter)
    } else {
        $result.Message = ("Nessun lavoro in coda per '{0}'." -f $TargetPrinter)
    }
    Write-Log -Message $result.Message -Level 'INFO'
    return [pscustomobject]$result
}

function Set-DefaultPrinterSafe {
    param([Parameter(Mandatory = $true)][string]$TargetPrinter)
    try {
        $wsn = New-Object -ComObject WScript.Network
        $wsn.SetDefaultPrinter($TargetPrinter)
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($wsn)
        Write-Log -Message ("Stampante predefinita impostata su '{0}'." -f $TargetPrinter) -Level 'OK'
        return [pscustomobject]@{ Success = $true; Message = ("Stampante predefinita: '{0}'" -f $TargetPrinter) }
    } catch {
        Write-Log -Message ("Impostazione predefinita (COM) non riuscita: {0}" -f $_.Exception.Message) -Level 'WARN'
    }
    try {
        $wmi = Get-CimInstance -ClassName Win32_Printer -Filter ("Name='{0}'" -f $TargetPrinter.Replace("'", "''")) -ErrorAction Stop
        if ($wmi) {
            Invoke-CimMethod -InputObject $wmi -MethodName SetDefaultPrinter -ErrorAction Stop | Out-Null
            Write-Log -Message ("Stampante predefinita impostata via CIM su '{0}'." -f $TargetPrinter) -Level 'OK'
            return [pscustomobject]@{ Success = $true; Message = ("Stampante predefinita: '{0}'" -f $TargetPrinter) }
        }
    } catch {
        Write-Log -Message ("Impostazione predefinita (CIM) non riuscita: {0}" -f $_.Exception.Message) -Level 'ERROR'
    }
    return [pscustomobject]@{ Success = $false; Message = 'Impossibile impostare la stampante predefinita.' }
}

function Send-PrinterTestPage {
    param([Parameter(Mandatory = $true)][string]$TargetPrinter)
    try {
        $wmi = Get-CimInstance -ClassName Win32_Printer -Filter ("Name='{0}'" -f $TargetPrinter.Replace("'", "''")) -ErrorAction Stop
        if ($wmi) {
            $response = Invoke-CimMethod -InputObject $wmi -MethodName PrintTestPage -ErrorAction Stop
            $code = Get-SafeProp -InputObject $response -Name 'ReturnValue' -Default 0
            if ([int]$code -eq 0) {
                Write-Log -Message ("Pagina di prova inviata a '{0}'." -f $TargetPrinter) -Level 'OK'
                return [pscustomobject]@{ Success = $true; Message = ("Pagina di prova inviata a '{0}'." -f $TargetPrinter) }
            }
            Write-Log -Message ("PrintTestPage ha restituito il codice {0}." -f $code) -Level 'WARN'
        }
    } catch {
        Write-Log -Message ("Stampa pagina di prova non riuscita: {0}" -f $_.Exception.Message) -Level 'WARN'
    }
    try {
        Start-Process -FilePath 'rundll32.exe' -ArgumentList @('printui.dll,PrintUIEntry', '/k', '/n', ('"{0}"' -f $TargetPrinter)) -ErrorAction Stop
        return [pscustomobject]@{ Success = $true; Message = ("Aperta la finestra di stampa di prova per '{0}'." -f $TargetPrinter) }
    } catch {
        return [pscustomobject]@{ Success = $false; Message = ('Impossibile inviare la pagina di prova: {0}' -f $_.Exception.Message) }
    }
}

function Open-PrinterQueueWindow {
    param([Parameter(Mandatory = $true)][string]$TargetPrinter)
    try {
        Start-Process -FilePath 'rundll32.exe' -ArgumentList @('printui.dll,PrintUIEntry', '/m', '/n', ('"{0}"' -f $TargetPrinter)) -ErrorAction Stop
        return $true
    } catch {
        Write-Log -Message ("Apertura coda non riuscita: {0}" -f $_.Exception.Message) -Level 'ERROR'
        return $false
    }
}

function Remove-PrinterSafe {
    param([Parameter(Mandatory = $true)][string]$TargetPrinter)
    try {
        Remove-Printer -Name $TargetPrinter -ErrorAction Stop
        Write-Log -Message ("Stampante '{0}' eliminata." -f $TargetPrinter) -Level 'OK'
        return [pscustomobject]@{ Success = $true; Message = ("Stampante '{0}' eliminata dal sistema." -f $TargetPrinter) }
    } catch {
        Write-Log -Message ("Remove-Printer non riuscito: {0}" -f $_.Exception.Message) -Level 'WARN'
    }
    try {
        $wmi = Get-CimInstance -ClassName Win32_Printer -Filter ("Name='{0}'" -f $TargetPrinter.Replace("'", "''")) -ErrorAction Stop
        if ($wmi) {
            Remove-CimInstance -InputObject $wmi -ErrorAction Stop
            Write-Log -Message ("Stampante '{0}' eliminata tramite WMI." -f $TargetPrinter) -Level 'OK'
            return [pscustomobject]@{ Success = $true; Message = ("Stampante '{0}' eliminata dal sistema." -f $TargetPrinter) }
        }
    } catch {
        Write-Log -Message ("Remove-CimInstance non riuscito: {0}" -f $_.Exception.Message) -Level 'ERROR'
    }
    return [pscustomobject]@{ Success = $false; Message = ("Impossibile eliminare '{0}': verificare i privilegi di amministratore." -f $TargetPrinter) }
}

function Open-PrinterWebAdmin {
    param([Parameter(Mandatory = $true)][string]$TargetPrinter)
    $ip = 'N/D'
    try {
        $wmi = Get-CimInstance -ClassName Win32_Printer -Filter ("Name='{0}'" -f $TargetPrinter.Replace("'", "''")) -ErrorAction Stop
        if ($wmi) { $ip = Get-SafeText -InputObject $wmi -Name 'PortName' -Default 'N/D' }
    } catch { }
    $match = [regex]::Match($ip, '\b(?:\d{1,3}\.){3}\d{1,3}\b')
    if (-not $match.Success) {
        return [pscustomobject]@{ Success = $false; Message = ("Indirizzo IP non disponibile per il WebAdmin di '{0}' (porta '{1}')." -f $TargetPrinter, $ip) }
    }
    $address = $match.Value
    $url = "http://$address"
    try {
        Start-Process -FilePath $url -ErrorAction Stop
        Write-Log -Message ("WebAdmin aperto su {0} per '{1}'." -f $url, $TargetPrinter) -Level 'OK'
        return [pscustomobject]@{ Success = $true; Message = ("WebAdmin aperto su {0}" -f $url) }
    } catch {
        return [pscustomobject]@{ Success = $false; Message = ("Apertura di {0} non riuscita: {1}" -f $url, $_.Exception.Message) }
    }
}

function Open-PrinterDriverPage {
    param([Parameter(Mandatory = $true)][string]$TargetPrinter, [string]$DriverName = '')
    $url = Get-PrinterDriverSearchUrl -PrinterName $TargetPrinter -DriverName $DriverName
    try {
        Start-Process -FilePath $url -ErrorAction Stop
        Write-Log -Message ("Pagina driver aperta per '{0}': {1}" -f $TargetPrinter, $url) -Level 'OK'
        return [pscustomobject]@{ Success = $true; Message = ("Pagina driver aperta: {0}" -f $url) }
    } catch {
        return [pscustomobject]@{ Success = $false; Message = ("Apertura della pagina driver non riuscita: {0}" -f $_.Exception.Message) }
    }
}

function Export-InventoryCsv {
    param([switch]$ToDesktop)
    $target = $null
    if ($ToDesktop) {
        $target = Join-Path -Path ([Environment]::GetFolderPath('Desktop')) -ChildPath ("Report_Stampanti_NovaChimera_{0}.csv" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    } else {
        $target = Join-Path -Path $script:LogDirectory -ChildPath ("report-stampanti-{0}.csv" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    }
    try {
        $rows = New-Object System.Collections.Generic.List[object]
        foreach ($p in $script:Inventory) {
            $rows.Add([pscustomobject]@{
                Nome            = $p.Name
                Porta           = $p.PortName
                TipoPorta       = $p.PortKind
                IndirizzoIP     = $p.IpAddress
                Host            = $p.Host
                PortaTCP        = $p.TcpPort
                RisoluzioneDa   = $p.ResolveSource
                Stato           = $p.Status
                Offline         = $(if ($p.IsOffline) { 'SI' } else { 'NO' })
                Predefinita     = $(if ($p.IsDefault) { 'SI' } else { 'NO' })
                LavoriInCoda    = $p.JobCount
                Tipo            = $p.Type
                Condivisa       = $(if ($p.Shared) { 'SI' } else { 'NO' })
                Driver          = $p.DriverName
                Posizione       = $p.Location
                Commento        = $p.Comment
            })
        }
        $rows | Export-Csv -Path $target -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
        Write-Log -Message ("Report CSV esportato in '{0}'." -f $target) -Level 'OK'
        return [pscustomobject]@{ Success = $true; Path = $target; Message = ("Report CSV esportato in {0}" -f $target) }
    } catch {
        Write-Log -Message ("Esportazione CSV non riuscita: {0}" -f $_.Exception.Message) -Level 'ERROR'
        return [pscustomobject]@{ Success = $false; Path = $target; Message = ('Esportazione CSV non riuscita: {0}' -f $_.Exception.Message) }
    }
}

function Get-DiagnosticReport {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine(('=' * 78))
    [void]$sb.AppendLine(('{0} - report diagnostico' -f $script:AppName))
    [void]$sb.AppendLine(('Generato il {0:yyyy-MM-dd HH:mm:ss} su {1}' -f (Get-Date), $env:COMPUTERNAME))
    [void]$sb.AppendLine(('=' * 78))
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('--- AMBIENTE ---')
    [void]$sb.AppendLine(('Sistema     : {0}' -f [System.Environment]::OSVersion.VersionString))
    [void]$sb.AppendLine(('PowerShell  : {0} ({1})' -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition))
    $admin = Get-AdminState
    [void]$sb.AppendLine(('Elevazione  : {0} ({1})' -f $admin.IsElevated, $admin.Identity))
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('--- SPOOLER ---')
    $health = Get-SpoolerHealth
    [void]$sb.AppendLine(('Stato       : {0} (avvio: {1})' -f $health.Status, $health.StartType))
    [void]$sb.AppendLine(('Coda        : {0} file, {1} byte' -f $health.QueueFiles, $health.QueueSizeBytes))
    [void]$sb.AppendLine(('Lavori      : {0}' -f $health.PendingJobs))
    [void]$sb.AppendLine(('Cartella    : {0}' -f $health.QueuePath))
    [void]$sb.AppendLine(('Driver      : {0}' -f $health.DriversPresent))
    foreach ($err in $health.Errors) { [void]$sb.AppendLine(('Errore      : {0}' -f $err)) }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('--- STAMPANTE SELEZIONATA ---')
    if ($script:SelectedPrinter) {
        $sp = $script:SelectedPrinter
        [void]$sb.AppendLine(('Nome        : {0}' -f $sp.Name))
        [void]$sb.AppendLine(('Porta       : {0} ({1})' -f $sp.PortName, $sp.PortKind))
        [void]$sb.AppendLine(('Host / IP   : {0} / {1} [fonte: {2}]' -f $sp.Host, $sp.IpAddress, $sp.ResolveSource))
        [void]$sb.AppendLine(('Porta TCP   : {0}' -f $sp.TcpPort))
        [void]$sb.AppendLine(('Driver      : {0}' -f $sp.DriverName))
        [void]$sb.AppendLine(('Stato       : {0} {1} ({2})' -f $sp.StatusBadge, $sp.Status, $sp.StatusSource))
        [void]$sb.AppendLine(('Offline     : {0}' -f $(if ($sp.IsOffline) { 'SI' } else { 'NO' })))
        [void]$sb.AppendLine(('Lavori      : {0}' -f $sp.JobCount))
        [void]$sb.AppendLine(('Predefinita : {0}' -f $sp.IsDefault))
        [void]$sb.AppendLine(('Ultimo errore: {0}' -f $sp.LastLogError))
        foreach ($note in $sp.Notes) { [void]$sb.AppendLine(('Nota        : {0}' -f $note)) }
    } else {
        [void]$sb.AppendLine('Nessuna stampante selezionata.')
    }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('--- INVENTARIO COMPLETO ---')
    foreach ($p in $script:Inventory) {
        [void]$sb.AppendLine(('  {0,-38} | {1,-18} | {2,-12} | lavori: {3,-3} | predef: {4}' -f $p.Name, $p.PortName, $p.Status, $p.JobCount, $p.IsDefault))
    }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('--- EVENTI PRINT SERVICE (ultime 24h) ---')
    $events = @(Get-SpoolerEventErrors -MaxEvents 15)
    if ($events.Count -eq 0) {
        [void]$sb.AppendLine('  Nessun evento anomalo rilevato.')
    } else {
        foreach ($e in $events) { [void]$sb.AppendLine(('  {0}' -f $e)) }
    }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('--- REGISTRO SESSIONE ---')
    foreach ($line in $script:LogEntries) { [void]$sb.AppendLine(('  {0}' -f $line)) }
    return $sb.ToString()
}

function Export-DiagnosticReport {
    $target = Join-Path -Path $script:LogDirectory -ChildPath ("diagnostica-stampanti-{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    try {
        $report = Get-DiagnosticReport
        Set-Content -LiteralPath $target -Value $report -Encoding UTF8 -ErrorAction Stop
        Write-Log -Message ("Report esportato in '{0}'." -f $target) -Level 'OK'
        return [pscustomobject]@{ Success = $true; Path = $target; Message = ("Report salvato in {0}" -f $target) }
    } catch {
        Write-Log -Message ("Esportazione report non riuscita: {0}" -f $_.Exception.Message) -Level 'ERROR'
        return [pscustomobject]@{ Success = $false; Path = $target; Message = ('Esportazione report non riuscita: {0}' -f $_.Exception.Message) }
    }
}

function Get-SelfTestResult {
    $results = New-Object System.Collections.Generic.List[object]
    function Add-Result {
        param([string]$Name, [bool]$Ok, [string]$Detail = '', [switch]$Warning)
        $results.Add([pscustomobject]@{ Name = $Name; Ok = $Ok; Detail = $Detail; Warning = [bool]$Warning })
    }

    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        Add-Result 'Windows Forms caricato' $true 'System.Windows.Forms disponibile'
    } catch {
        Add-Result 'Windows Forms caricato' $false $_.Exception.Message
    }

    try {
        $printers = @(Get-CimInstance -ClassName Win32_Printer -ErrorAction Stop)
        Add-Result 'Get-CimInstance Win32_Printer' $true ("{0} stampanti" -f $printers.Count)
    } catch {
        Add-Result 'Get-CimInstance Win32_Printer' $false $_.Exception.Message
    }

    try {
        $pm = @(Get-Printer -ErrorAction Stop)
        Add-Result 'Get-Printer (PrintManagement)' $true ("{0} stampanti" -f $pm.Count)
    } catch {
        Add-Result 'Get-Printer (PrintManagement)' $false $_.Exception.Message
    }

    try {
        $spooler = Get-Service -Name Spooler -ErrorAction Stop
        Add-Result 'Servizio Spooler raggiungibile' $true $spooler.Status.ToString()
    } catch {
        Add-Result 'Servizio Spooler raggiungibile' $false $_.Exception.Message
    }

    $inventory = @()
    try {
        $inventory = @(Get-PrinterInventory)
        Add-Result 'Inventario stampanti' $true ("{0} record" -f $inventory.Count)
    } catch {
        Add-Result 'Inventario stampanti' $false $_.Exception.Message
    }

    $probePrinter = $inventory | Select-Object -First 1
    if ($probePrinter) {
        try {
            $jobs = @(Get-PrinterJobInfo -TargetPrinter $probePrinter.Name)
            Add-Result ("Get-PrintJob '{0}'" -f $probePrinter.Name) $true ("{0} lavori" -f $jobs.Count)
        } catch {
            Add-Result ("Get-PrintJob '{0}'" -f $probePrinter.Name) $false $_.Exception.Message
        }
        try {
            $endpoint = Resolve-PrinterEndpoint -PrinterName $probePrinter.Name -PortName $probePrinter.PortName
            Add-Result ("Risoluzione endpoint '{0}'" -f $probePrinter.Name) $true ("{0} -> {1} [{2}]" -f $endpoint.PortName, $endpoint.Host, $endpoint.Source)
        } catch {
            Add-Result ("Risoluzione endpoint '{0}'" -f $probePrinter.Name) $false $_.Exception.Message
        }
        try {
            $subnet = Get-PrinterSubnetMask -PortName $probePrinter.PortName -IpAddress $probePrinter.IpAddress
            Add-Result ("Subnet mask '{0}'" -f $probePrinter.Name) $true ("{0} [{1}]" -f $subnet.Mask, $subnet.Source)
        } catch {
            Add-Result ("Subnet mask '{0}'" -f $probePrinter.Name) $false $_.Exception.Message
        }
    } else {
        Add-Result 'Stampante di prova' $false 'Nessuna stampante disponibile per il test'
    }

    try {
        $networkOk = $true
        foreach ($check in @(
            @{ Prefix = 24; Expected = '255.255.255.0' },
            @{ Prefix = 16; Expected = '255.255.0.0' },
            @{ Prefix = 30; Expected = '255.255.255.252' }
        )) {
            if ((Convert-PrefixToMask -PrefixLength $check.Prefix) -ne $check.Expected) { $networkOk = $false }
        }
        $cidr = Get-SubnetCidr -IpAddress '192.168.1.10' -Mask '255.255.255.0'
        if ($cidr -ne '192.168.1.0/24') { $networkOk = $false }
        if (-not (Test-IPv4Address -Address '192.168.1.10')) { $networkOk = $false }
        if (Test-IPv4Address -Address '256.1.1.1') { $networkOk = $false }
        if (Test-IPv4Address -Address '') { $networkOk = $false }
        Add-Result 'Subnet mask e CIDR' $networkOk ("/24 -> {0}, CIDR {1}, validazione IPv4 attiva" -f (Convert-PrefixToMask -PrefixLength 24), $cidr)
    } catch {
        Add-Result 'Subnet mask e CIDR' $false $_.Exception.Message
    }

    try {
        $health = Get-SpoolerHealth
        Add-Result 'Controllo coda spool' $true ("{0} file, {1} lavori" -f $health.QueueFiles, $health.PendingJobs)
    } catch {
        Add-Result 'Controllo coda spool' $false $_.Exception.Message
    }

    try {
        $security = Get-SecurityStatus
        $securityOk = -not [string]::IsNullOrWhiteSpace($security.Antivirus) -and -not [string]::IsNullOrWhiteSpace($security.Firewall)
        Add-Result 'Stato sicurezza' $securityOk ("AV: {0} | Firewall: {1}" -f $security.Antivirus, $security.Firewall)
    } catch {
        Add-Result 'Stato sicurezza' $false $_.Exception.Message
    }

    try {
        $dashboard = Get-HomeDashboardReport
        $dashboardOk = ($dashboard -split "`r?`n").Count -gt 10
        Add-Result 'Dashboard di sistema' $dashboardOk ("{0} righe di report" -f ($dashboard -split "`r?`n").Count)
    } catch {
        Add-Result 'Dashboard di sistema' $false $_.Exception.Message
    }

    try {
        $winget = Get-Command -Name 'winget' -ErrorAction SilentlyContinue
        Add-Result 'Winget (aggiornamenti)' ($null -ne $winget) $(if ($winget) { $winget.Source } else { 'Non installato: controllo aggiornamenti non disponibile' })
    } catch {
        Add-Result 'Winget (aggiornamenti)' $false $_.Exception.Message
    }

    $admin = Get-AdminState
    Add-Result 'Privilegi Administrator' $admin.IsElevated ("Elevato: {0} - svuotamento spooler e riavvio servizio non disponibili" -f $admin.IsElevated) -Warning:(-not $admin.IsElevated)

    return $results
}

function Invoke-SelfTest {
    Write-Log -Message 'Avvio protocollo di verifica locale (SelfTest).' -Level 'INFO'
    $results = @(Get-SelfTestResult)
    $failed = 0
    Write-Output ''
    Write-Output ('--- {0} {1} - SelfTest ---' -f $script:AppName, $script:AppVersion)
    Write-Output ('PS {0} ({1}) | elevato: {2}' -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition, (Get-AdminState).IsElevated)
    Write-Output ''
    foreach ($r in $results) {
        $mark = 'OK  '
        if (-not $r.Ok) {
            $mark = 'WARN'
            if (-not $r.Warning) { $failed++ }
        }
        Write-Output ('[{0}] {1,-45} {2}' -f $mark, $r.Name, $r.Detail)
    }
    Write-Output ''
    Write-Output ('Totale: {0} controlli, {1} falliti.' -f $results.Count, $failed)
    if ($failed -gt 0) { exit 1 }
    exit 0
}

function Show-Message {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [string]$Caption = 'NovaChimera',
        [ValidateSet('Info', 'Warning', 'Error', 'Question')][string]$Kind = 'Info'
    )
    try {
        $icon = switch ($Kind) {
            'Warning' { [System.Windows.Forms.MessageBoxIcon]::Warning }
            'Error' { [System.Windows.Forms.MessageBoxIcon]::Error }
            'Question' { [System.Windows.Forms.MessageBoxIcon]::Question }
            default { [System.Windows.Forms.MessageBoxIcon]::Information }
        }
        $buttons = if ($Kind -eq 'Question') { [System.Windows.Forms.MessageBoxButtons]::YesNo } else { [System.Windows.Forms.MessageBoxButtons]::OK }
        return [System.Windows.Forms.MessageBox]::Show($Text, $Caption, $buttons, $icon)
    } catch {
        Write-Output $Text
        return [System.Windows.Forms.DialogResult]::OK
    }
}

function Invoke-Safe {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Action,
        [string]$Context = 'Operazione'
    )
    try {
        & $Action
    } catch {
        $message = $_.Exception.Message
        Write-Log -Message ("{0}: {1}" -f $Context, $message) -Level 'ERROR'
        [void](Show-Message -Text ("{0} non riuscita.`r`n`r`n{1}`r`n`r`nDettaglio nel registro." -f $Context, $message) -Caption 'NovaChimera - Errore' -Kind 'Error')
    }
}

function Set-BusyState {
    param([bool]$Busy, [string]$Message = '')
    if ($script:Ui.Form) {
        try {
            $script:Ui.Form.UseWaitCursor = $Busy
            $script:Ui.Progress.Visible = $Busy
            if ($script:Ui.StatusLabel) {
                $script:Ui.StatusLabel.Text = if ($Message) { $Message } else { 'Pronto' }
            }
            $script:Ui.Form.Refresh()
            [System.Windows.Forms.Application]::DoEvents()
        } catch {
            Write-Log -Message ("Impostazione dello stato busy non riuscita: {0}" -f $_.Exception.Message) -Level 'DEBUG'
        }
    }
}

function Update-StatusBar {
    param([string]$Message)
    if ($script:Ui.StatusLabel) {
        try { $script:Ui.StatusLabel.Text = $Message } catch { }
    }
}

function Update-Inventory {
    $inventory = @(Get-PrinterInventory)
    $script:Inventory = $inventory
    return $inventory
}

function Select-PrinterByName {
    param([string]$Name)
    if (-not $Name) { return }
    $match = $script:Inventory | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    if ($match) {
        $script:SelectedPrinter = $match
        $script:SelectedPrinterName = $match.Name
    }
}

function Show-PrinterList {
    $list = $script:Ui.PrinterList
    if (-not $list) { return }
    $selectedName = $script:SelectedPrinterName
    $list.BeginUpdate()
    try {
        $list.Items.Clear()
        foreach ($p in $script:Inventory) {
            $item = New-Object System.Windows.Forms.ListViewItem(("{0} {1}" -f $p.StatusBadge, $p.Name))
            [void]$item.SubItems.Add((Get-SafeText -InputObject $p -Name 'IpAddress' -Default 'N/D'))
            [void]$item.SubItems.Add((Get-SafeText -InputObject $p -Name 'SubnetMask' -Default 'N/D'))
            [void]$item.SubItems.Add((Get-SafeText -InputObject $p -Name 'Status' -Default 'N/D'))
            [void]$item.SubItems.Add($(if ($p.IsDefault) { 'SI' } else { 'NO' }))
            [void]$item.SubItems.Add([string]$p.JobCount)
            [void]$item.SubItems.Add((Get-SafeText -InputObject $p -Name 'PortName' -Default 'N/D'))
            [void]$item.SubItems.Add((Get-SafeText -InputObject $p -Name 'PortKind' -Default 'N/D'))
            $item.Tag = $p
            $item.ForeColor = $p.StatusColor
            [void]$list.Items.Add($item)
        }
        if ($selectedName) {
            foreach ($item in $list.Items) {
                if ($item.Tag -and $item.Tag.Name -eq $selectedName) {
                    $item.Selected = $true
                    $item.EnsureVisible()
                    break
                }
            }
        }
        if ($list.Items.Count -gt 0 -and $list.SelectedItems.Count -eq 0) {
            $list.Items[0].Selected = $true
        }
    } finally {
        $list.EndUpdate()
    }
    try { Sync-PrinterListColumnWidths } catch { }

    $target = $null
    if ($selectedName) {
        $target = $script:Inventory | Where-Object { $_.Name -eq $selectedName } | Select-Object -First 1
    }
    if (-not $target -and $script:Inventory.Count -gt 0) { $target = $script:Inventory[0] }
    if ($target) {
        $script:SelectedPrinter = $target
        $script:SelectedPrinterName = $target.Name
    }
    Update-StatusBar ("Pronto. Totale stampanti trovate: {0}" -f $script:Inventory.Count)
}

function Sync-PrinterListColumnWidths {
    $list = $script:Ui.PrinterList
    if (-not $list) { return }
    if ($list.Columns.Count -eq 0) { return }
    $available = $list.ClientSize.Width - 4
    if ($available -le 0) { return }
    $total = 0
    foreach ($definition in $script:PrinterListColumns) { $total += $definition.Width }
    if ($total -le $available) { return }
    $scale = $available / $total
    $index = 0
    foreach ($definition in $script:PrinterListColumns) {
        if ($index -ge $list.Columns.Count) { break }
        $width = [int][Math]::Floor($definition.Width * $scale)
        if ($width -lt $definition.Min) { $width = $definition.Min }
        if ($list.Columns[$index].Width -ne $width) { $list.Columns[$index].Width = $width }
        $index++
    }
}

function Show-LiveCard {
    $box = $script:Ui.CardBox
    if (-not $box) { return }
    $p = $script:SelectedPrinter
    if (-not $p) {
        $box.Text = "Nessuna stampante selezionata."
        return
    }
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add(('Modello     : {0}' -f $p.Name))
    $lines.Add(('Indirizzo IP: {0}' -f (Get-SafeText -InputObject $p -Name 'IpAddress' -Default 'N/D')))
    $lines.Add(('Subnet Mask : {0}' -f (Get-SafeText -InputObject $p -Name 'SubnetMask' -Default 'N/D')))
    $lines.Add(('Sottorete   : {0}  [da {1}]' -f (Get-SafeText -InputObject $p -Name 'SubnetCidr' -Default 'N/D'), (Get-SafeText -InputObject $p -Name 'SubnetSource' -Default 'N/D')))
    $lines.Add(('Stato       : {0} {1}' -f $p.StatusBadge, $p.Status))
    $lines.Add(('Porta       : {0} ({1})' -f $p.PortName, $p.PortKind))
    $lines.Add(('Porta TCP   : {0}' -f $p.TcpPort))
    $lines.Add(('Host        : {0} [da {1}]' -f $p.Host, $p.ResolveSource))
    $lines.Add(('Lavori Coda : {0}' -f $p.JobCount))
    $lines.Add(('Predefinita : {0}' -f $(if ($p.IsDefault) { 'SI' } else { 'NO' })))
    $lines.Add(('Forzata Off : {0}' -f $(if ($p.IsOffline) { 'SI' } else { 'NO' })))
    $lines.Add(('Condivisa   : {0}' -f $(if ($p.Shared) { 'SI' } else { 'NO' })))
    $lines.Add(('Driver      : {0}' -f $p.DriverName))
    $lines.Add(('Posizione   : {0}' -f $(if ($p.Location) { $p.Location } else { 'N/D' })))
    $lines.Add('')
    $lines.Add('Log diagnostico recente:')
    $lines.Add(('  {0}' -f $p.LastLogError))
    foreach ($note in $p.Notes) {
        $lines.Add(('  Nota: {0}' -f $note))
    }
    $box.Text = ($lines -join [Environment]::NewLine)
}

function Show-PrinterDetails {
    $p = $script:SelectedPrinter
    $list = $script:Ui.DetailList
    if (-not $list) { return }
    $list.Items.Clear()
    if (-not $p) {
        [void]$list.Items.Add((New-Object System.Windows.Forms.ListViewItem('Nessuna stampante selezionata')))
        return
    }
    $rows = [ordered]@{
        'Nome'           = $p.Name
        'Porta'          = $p.PortName
        'Tipo porta'     = $p.PortKind
        'Host / IP'      = $p.Host
        'Indirizzo IP'   = $p.IpAddress
        'Subnet Mask'    = ('{0} [da {1}]' -f $p.SubnetMask, $p.SubnetSource)
        'Sottorete CIDR' = $p.SubnetCidr
        'Porta TCP'      = $p.TcpPort
        'Risoluzione da' = $p.ResolveSource
        'Driver'         = $p.DriverName
        'Stato'          = ('{0} {1} ({2})' -f $p.StatusBadge, $p.Status, $p.StatusSource)
        'Forzata offline'= $(if ($p.IsOffline) { 'SI' } else { 'NO' })
        'Lavori in coda' = $p.JobCount
        'Predefinita'    = $(if ($p.IsDefault) { 'SI' } else { 'NO' })
        'Tipo'           = $p.Type
        'Condivisa'      = $(if ($p.Shared) { 'SI' } else { 'NO' })
        'Posizione'      = $(if ($p.Location) { $p.Location } else { 'N/D' })
        'Commento'       = $(if ($p.Comment) { $p.Comment } else { 'N/D' })
        'Ultimo errore'  = $p.LastLogError
    }
    foreach ($key in $rows.Keys) {
        $item = New-Object System.Windows.Forms.ListViewItem($key)
        [void]$item.SubItems.Add([string]$rows[$key])
        [void]$list.Items.Add($item)
    }
    foreach ($note in $p.Notes) {
        $item = New-Object System.Windows.Forms.ListViewItem('Nota')
        [void]$item.SubItems.Add([string]$note)
        $item.ForeColor = $script:ColorWarning
        [void]$list.Items.Add($item)
    }
}

function Show-PrinterJobs {
    $p = $script:SelectedPrinter
    $list = $script:Ui.JobList
    if (-not $list) { return }
    $list.Items.Clear()
    if (-not $p) { return }
    $jobs = @(Get-PrinterJobInfo -TargetPrinter $p.Name)
    if ($jobs.Count -eq 0) {
        $item = New-Object System.Windows.Forms.ListViewItem('Nessun lavoro in coda')
        [void]$item.SubItems.Add('')
        [void]$item.SubItems.Add('')
        [void]$item.SubItems.Add('')
        [void]$item.SubItems.Add('')
        [void]$list.Items.Add($item)
        return
    }
    foreach ($job in $jobs) {
        $item = New-Object System.Windows.Forms.ListViewItem($job.Id)
        [void]$item.SubItems.Add($job.User)
        [void]$item.SubItems.Add($job.Document)
        [void]$item.SubItems.Add($job.Status)
        [void]$item.SubItems.Add($job.Size)
        [void]$item.SubItems.Add($job.Submitted)
        $item.Tag = $job
        [void]$list.Items.Add($item)
    }
}

function Show-NetworkTab {
    $p = $script:SelectedPrinter
    $box = $script:Ui.NetworkBox
    if (-not $box) { return }
    $box.Clear()
    if (-not $p) {
        $box.AppendText("Nessuna stampante selezionata.`r`n")
        return
    }
    $box.AppendText(('Stampante : {0}' -f $p.Name) + [Environment]::NewLine)
    $box.AppendText(('Porta     : {0}  ({1})' -f $p.PortName, $p.PortKind) + [Environment]::NewLine)
    $box.AppendText(('Host      : {0}  [fonte: {1}]' -f $p.Host, $p.ResolveSource) + [Environment]::NewLine)
    $box.AppendText(('IP        : {0}' -f $p.IpAddress) + [Environment]::NewLine)
    $box.AppendText(('TCP       : {0}' -f $p.TcpPort) + [Environment]::NewLine)
    foreach ($note in $p.Notes) {
        $box.AppendText(('Nota      : {0}' -f $note) + [Environment]::NewLine)
    }
    $box.AppendText('')
    $box.AppendText('Premere "Esegui test di rete" per verificare ping e porte TCP.' + [Environment]::NewLine)
}

function Invoke-NetworkTest {
    $p = $script:SelectedPrinter
    if (-not $p) {
        [void](Show-Message -Text "Selezionare una stampante dall'elenco." -Caption 'NovaChimera' -Kind 'Warning')
        return
    }
    Set-BusyState -Busy $true -Message 'Test di rete in corso...'
    try {
        $endpoint = Resolve-PrinterEndpoint -PrinterName $p.Name -PortName $p.PortName
        $lines = @(Test-PrinterNetwork -Endpoint $endpoint)
        $box = $script:Ui.NetworkBox
        $box.Clear()
        foreach ($line in $lines) {
            $box.AppendText($line + [Environment]::NewLine)
        }
        Write-Log -Message ('Test di rete completato per {0}.' -f $p.Name) -Level 'OK'
    } catch {
        Write-Log -Message ("Test di rete non riuscito: {0}" -f $_.Exception.Message) -Level 'ERROR'
        [void](Show-Message -Text ('Test di rete non riuscito: {0}' -f $_.Exception.Message) -Caption 'NovaChimera - Errore' -Kind 'Error')
    } finally {
        Set-BusyState -Busy $false -Message 'Pronto'
    }
}

function New-MenuItem {
    param([string]$Text, [scriptblock]$Action = $null)
    $item = New-Object System.Windows.Forms.ToolStripMenuItem
    $item.Text = $Text
    if ($Action) { $item.Add_Click($Action) }
    return $item
}

function New-ToolButton {
    param([string]$Text, [scriptblock]$Action)
    $button = New-Object System.Windows.Forms.ToolStripButton
    $button.Text = $Text
    $button.DisplayStyle = 'Text'
    $button.Add_Click($Action)
    return $button
}

function Request-Elevation {
    $scriptRoot = $PSScriptRoot
    if (-not $scriptRoot) { return $false }
    $scriptFile = Join-Path -Path $scriptRoot -ChildPath 'stampanti.ps1'
    if (-not (Test-Path -LiteralPath $scriptFile)) { return $false }
    $shell = Join-Path -Path $PSHOME -ChildPath 'pwsh.exe'
    if (-not (Test-Path -LiteralPath $shell)) { $shell = Join-Path -Path $PSHOME -ChildPath 'powershell.exe' }
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', ('"{0}"' -f $scriptFile))
    if ($script:SelectedPrinter -and $script:SelectedPrinter.Name) {
        $arguments += @('-PrinterName', ('"{0}"' -f $script:SelectedPrinter.Name))
    }
    try {
        Start-Process -FilePath $shell -ArgumentList $arguments -Verb RunAs -WorkingDirectory $scriptRoot -ErrorAction Stop
        return $true
    } catch {
        Write-Log -Message ("Elevazione non riuscita: {0}" -f $_.Exception.Message) -Level 'ERROR'
        return $false
    }
}

function Invoke-Refresh {
    Set-BusyState -Busy $true -Message 'Aggiornamento lista stampanti in corso...'
    try {
        Update-Inventory | Out-Null
        Show-PrinterList
        Show-PrinterDetails
        Show-PrinterJobs
        Show-NetworkTab
        Show-LiveCard
    } finally {
        Set-BusyState -Busy $false -Message 'Pronto'
    }
}

function Show-IpEditDialog {
    param(
        [Parameter(Mandatory = $true)]$Printer,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$CurrentIp
    )
    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = "Modifica IP - $($Printer.Name)"
    $dialog.StartPosition = 'CenterParent'
    $dialog.FormBorderStyle = 'FixedDialog'
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false
    $dialog.ClientSize = New-Object System.Drawing.Size(520, 320)
    $dialog.BackColor = $script:ColorBgMain
    $dialog.ForeColor = $script:ColorTextMain
    $dialog.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = 'Fill'
    $layout.ColumnCount = 2
    $layout.RowCount = 7
    $layout.Padding = New-Object System.Windows.Forms.Padding(14)
    $layout.BackColor = $script:ColorBgMain
    [void]$layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize)))
    [void]$layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    for ($row = 0; $row -lt 7; $row++) {
        [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
    }
    $dialog.Controls.Add($layout)

    function Add-Row {
        param([string]$Caption, [string]$Value, [switch]$Editable, [int]$Row = 0)
        $label = New-Object System.Windows.Forms.Label
        $label.Text = $Caption
        $label.ForeColor = $script:ColorTextMuted
        $label.AutoSize = $true
        $label.Anchor = 'Left'
        $label.Margin = New-Object System.Windows.Forms.Padding(3, 6, 3, 8)
        $valueControl = New-Object System.Windows.Forms.TextBox
        $valueControl.Text = $Value
        $valueControl.BackColor = $script:ColorCardBg
        $valueControl.ForeColor = $script:ColorTextMain
        $valueControl.BorderStyle = 'FixedSingle'
        $valueControl.Dock = 'Fill'
        $valueControl.Margin = New-Object System.Windows.Forms.Padding(3, 3, 3, 8)
        if (-not $Editable) { $valueControl.ReadOnly = $true }
        [void]$layout.Controls.Add($label, 0, $Row)
        [void]$layout.Controls.Add($valueControl, 1, $Row)
        return $valueControl
    }

    [void](Add-Row -Caption 'Stampante' -Value $Printer.Name -Row 0)
    [void](Add-Row -Caption 'Porta attuale' -Value $Printer.PortName -Row 1)
    [void](Add-Row -Caption 'Tipo porta' -Value $Printer.PortKind -Row 2)
    $ipBox = Add-Row -Caption 'Nuovo indirizzo IPv4' -Value $CurrentIp -Editable -Row 3
    $maskRow = Add-Row -Caption 'Subnet mask / sottorete' -Value ("{0}  ({1})" -f $Printer.SubnetMask, $Printer.SubnetCidr) -Row 4

    $note = New-Object System.Windows.Forms.Label
    $note.Text = "La modifica aggiorna la porta TCP/IP nel sistema e riavvia lo Spooler.`r`nVerificare la raggiungibilita' del nuovo indirizzo prima di applicare."
    $note.ForeColor = $script:ColorWarning
    $note.AutoSize = $true
    $note.Dock = 'Fill'
    $note.Margin = New-Object System.Windows.Forms.Padding(3, 6, 3, 6)
    [void]$layout.Controls.Add($note, 1, 5)

    $buttons = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttons.FlowDirection = 'RightToLeft'
    $buttons.Dock = 'Fill'
    $buttons.Height = 44
    $buttons.BackColor = $script:ColorBgMain
    $cancel = New-ThemedButton -Text 'Annulla' -BackColor $script:ColorPanel -ForeColor $script:ColorTextMain
    $cancel.Add_Click({ $dialog.DialogResult = [System.Windows.Forms.DialogResult]::Cancel; $dialog.Close() })
    $buttons.Controls.Add($cancel)
    $apply = New-ThemedButton -Text 'Applica indirizzo' -BackColor $script:ColorAccent -ForeColor $script:ColorBgMain
    $buttons.Controls.Add($apply)
    [void]$layout.Controls.Add($buttons, 1, 6)

    $script:IpEditResult = $null
    $apply.Add_Click({
        $value = $ipBox.Text.Trim()
        if (-not (Test-IPv4Address -Address $value)) {
            [void](Show-Message -Text ("'{0}' non e' un indirizzo IPv4 valido.`r`nFormato atteso: 192.168.1.10" -f $value) -Caption 'Indirizzo non valido' -Kind 'Warning')
            return
        }
        if ($value -eq $CurrentIp) {
            [void](Show-Message -Text 'Il nuovo indirizzo coincide con quello corrente.' -Caption 'Nessuna modifica' -Kind 'Info')
            return
        }
        $script:IpEditResult = $value
        $dialog.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $dialog.Close()
    })

    $dialog.Add_FormClosing({ })
    $maskRow.ReadOnly = $true
    $dialog.ShowDialog()
    return $script:IpEditResult
}

function Invoke-ActionEditIp {
    $p = Get-SelectedPrinterOrWarn
    if (-not $p) { return }
    $currentIp = $p.IpAddress
    if ($currentIp -eq 'N/D' -or -not (Test-IPv4Address -Address $currentIp)) {
        $answer = Show-Message -Text ("La stampante '{0}' non ha un indirizzo IP risolvibile (porta '{1}').`r`n`r`nSi puo' comunque impostare un nuovo IP, che verra' applicato come porta TCP/IP Standard." -f $p.Name, $p.PortName) -Caption 'Indirizzo non disponibile' -Kind 'Question'
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        $currentIp = ''
    }
    $newIp = Show-IpEditDialog -Printer $p -CurrentIp $currentIp
    if (-not $newIp) { return }
    $portNumber = 9100
    if ($p.TcpPort) {
        $parsed = 0
        if ([int]::TryParse([string]$p.TcpPort, [ref]$parsed) -and $parsed -gt 0) { $portNumber = $parsed }
    }
    Set-BusyState -Busy $true -Message ("Aggiornamento IP a {0}..." -f $newIp)
    try {
        $r = Set-PrinterIpAddress -TargetPrinter $p.Name -NewIpAddress $newIp -PortName $p.PortName -PortNumber $portNumber
    } finally {
        Set-BusyState -Busy $false -Message 'Pronto'
    }
    $message = $r.Message
    if ($r.Details.Count -gt 0) {
        $message = $message + "`r`n`r`n" + (($r.Details | ForEach-Object { "  - $_" }) -join "`r`n")
    }
    [void](Show-Message -Text $message -Caption 'NovaChimera - Modifica IP' -Kind $(if ($r.Success) { 'Info' } else { 'Error' }))
    Invoke-Refresh
}

function Get-SelectedPrinterOrWarn {
    if (-not $script:SelectedPrinter) {
        [void](Show-Message -Text "Selezionare una stampante dall'elenco." -Caption 'NovaChimera' -Kind 'Warning')
        return $null
    }
    return $script:SelectedPrinter
}

function Invoke-ActionSetDefault {
    $p = Get-SelectedPrinterOrWarn
    if (-not $p) { return }
    $r = Set-DefaultPrinterSafe -TargetPrinter $p.Name
    [void](Show-Message -Text $r.Message -Caption 'NovaChimera' -Kind $(if ($r.Success) { 'Info' } else { 'Error' }))
    Invoke-Refresh
}

function Invoke-ActionClearQueue {
    $p = Get-SelectedPrinterOrWarn
    if (-not $p) { return }
    $r = Clear-PrinterQueue -TargetPrinter $p.Name
    [void](Show-Message -Text $r.Message -Caption 'NovaChimera' -Kind 'Info')
    Invoke-Refresh
}

function Invoke-ActionPurgeSpooler {
    $answer = Show-Message -Text "Svuotare la coda di TUTTE le stampanti?`r`nIl servizio Spooler verra' fermato e riavviato." -Caption 'NovaChimera' -Kind 'Question'
    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    Set-BusyState -Busy $true -Message 'Svuotamento spooler in corso...'
    try {
        $r = Clear-SpoolerQueue
    } finally {
        Set-BusyState -Busy $false -Message 'Pronto'
    }
    [void](Show-Message -Text $r.Message -Caption 'NovaChimera' -Kind $(if ($r.Success) { 'Info' } else { 'Error' }))
    Invoke-Refresh
}

function Invoke-ActionTestPage {
    $p = Get-SelectedPrinterOrWarn
    if (-not $p) { return }
    $r = Send-PrinterTestPage -TargetPrinter $p.Name
    [void](Show-Message -Text $r.Message -Caption 'NovaChimera' -Kind $(if ($r.Success) { 'Info' } else { 'Error' }))
}

function Invoke-ActionFindDriver {
    $p = Get-SelectedPrinterOrWarn
    if (-not $p) { return }
    $r = Open-PrinterDriverPage -TargetPrinter $p.Name -DriverName $p.DriverName
    [void](Show-Message -Text $r.Message -Caption 'NovaChimera' -Kind $(if ($r.Success) { 'Info' } else { 'Error' }))
}

function Invoke-ActionWebAdmin {
    $p = Get-SelectedPrinterOrWarn
    if (-not $p) { return }
    $r = Open-PrinterWebAdmin -TargetPrinter $p.Name
    [void](Show-Message -Text $r.Message -Caption 'NovaChimera' -Kind $(if ($r.Success) { 'Info' } else { 'Error' }))
}

function Invoke-ActionExportReport {
    $answer = Show-Message -Text "Esportare il report CSV sul Desktop?`r`nScegliendo NO il file viene salvato nella cartella dei log del tool." -Caption 'NovaChimera' -Kind 'Question'
    $toDesktop = ($answer -eq [System.Windows.Forms.DialogResult]::Yes)
    $r = Export-InventoryCsv -ToDesktop:$toDesktop
    if (-not $r.Success) {
        [void](Show-Message -Text $r.Message -Caption 'NovaChimera - Errore' -Kind 'Error')
        return
    }
    [void](Show-Message -Text $r.Message -Caption 'NovaChimera' -Kind 'Info')
    try { Start-Process -FilePath 'explorer.exe' -ArgumentList ('/select,"{0}"' -f $r.Path) -ErrorAction Stop } catch { }
}

function Invoke-ActionExportDiagnostic {
    $r = Export-DiagnosticReport
    [void](Show-Message -Text $r.Message -Caption 'NovaChimera' -Kind $(if ($r.Success) { 'Info' } else { 'Error' }))
}

function Invoke-ActionRemovePrinter {
    $p = Get-SelectedPrinterOrWarn
    if (-not $p) { return }
    $answer = Show-Message -Text ("Vuoi eliminare DEFINITIVAMENTE la stampante '{0}' dal sistema?`r`nL'operazione non e' reversibile e richiede i privilegi di amministratore." -f $p.Name) -Caption 'Conferma Eliminazione' -Kind 'Question'
    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    $r = Remove-PrinterSafe -TargetPrinter $p.Name
    [void](Show-Message -Text $r.Message -Caption 'NovaChimera' -Kind $(if ($r.Success) { 'Info' } else { 'Error' }))
    $script:SelectedPrinter = $null
    $script:SelectedPrinterName = ''
    Invoke-Refresh
    if ($script:Ui.CardBox) { $script:Ui.CardBox.Clear() }
}

function Invoke-ActionExit {
    Write-Log -Message "Chiusura richiesta dall'operatore: terminazione volatile dell'applicazione." -Level 'INFO'
    try {
        if ($script:Ui.Form) { $script:Ui.Form.Close() }
        [System.Windows.Forms.Application]::Exit()
    } catch {
        Write-Log -Message ("Chiusura non ordinata: {0}" -f $_.Exception.Message) -Level 'ERROR'
        try { Stop-Process -Id $PID -Force -ErrorAction Stop } catch { }
    }
}

function New-ThemedButton {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [System.Drawing.Color]$BackColor = $script:ColorPanel,
        [System.Drawing.Color]$ForeColor = $script:ColorTextMain,
        [int]$FixedWidth = 0
    )
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Height = 36
    $button.FlatStyle = 'Flat'
    $button.FlatAppearance.BorderSize = 1
    $button.FlatAppearance.BorderColor = $script:ColorBorder
    $button.BackColor = $BackColor
    $button.ForeColor = $ForeColor
    $button.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    $button.AutoSize = $true
    $button.AutoSizeMode = 'GrowAndShrink'
    if ($FixedWidth -gt 0) {
        $button.AutoSize = $false
        $button.Width = $FixedWidth
    }
    return $button
}

function New-ThemedListView {
    param([switch]$OwnerDrawHeader)
    $view = New-Object System.Windows.Forms.ListView
    $view.View = 'Details'
    $view.FullRowSelect = $true
    $view.GridLines = $true
    $view.BackColor = $script:ColorBgList
    $view.ForeColor = $script:ColorTextMain
    $view.BorderStyle = 'None'
    $view.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
    $view.Dock = 'Fill'
    if ($OwnerDrawHeader) {
        try {
            $view.OwnerDraw = $true
            $view.Add_DrawColumnHeader({
                param($sender, $e)
                try {
                    $e.DrawDefault = $false
                    $background = New-Object System.Drawing.SolidBrush($script:ColorPanel)
                    $foreground = New-Object System.Drawing.SolidBrush($script:ColorAccent)
                    $e.Graphics.FillRectangle($background, $e.Bounds)
                    $e.Graphics.DrawString($sender.Columns[$e.ColumnIndex].Text, $e.Font, $foreground, $e.Bounds)
                    $background.Dispose()
                    $foreground.Dispose()
                } catch {
                    $e.DrawDefault = $true
                }
            })
            $view.Add_DrawItem({ param($sender, $e) $e.DrawDefault = $true })
            $view.Add_DrawSubItem({ param($sender, $e) $e.DrawDefault = $true })
        } catch { }
    }
    return $view
}

function Get-SecurityStatus {
    $result = [ordered]@{
        Antivirus     = 'N/D'
        Firewall      = 'N/D'
        VPN           = 'Non rilevata'
        Uac           = 'N/D'
        PendingReboot = 'No'
    }
    try {
        $av = @(Get-CimInstance -Namespace 'Root\SecurityCenter2' -ClassName AntivirusProduct -ErrorAction Stop)
        $names = @($av | ForEach-Object { [string]$_.displayName } | Where-Object { $_ })
        if ($names.Count -gt 0) {
            $result.Antivirus = ($names -join ', ')
        } else {
            $result.Antivirus = 'Windows Defender (integrato, nessun prodotto registrato)'
        }
    } catch {
        $result.Antivirus = 'Non interrogabile (criteri di dominio o provider assente)'
    }

    try {
        $profiles = @(Get-NetFirewallProfile -ErrorAction Stop)
        $enabled = @($profiles | Where-Object { $_.Enabled -eq 'True' })
        if ($profiles.Count -eq 0) {
            $result.Firewall = 'N/D'
        } elseif ($enabled.Count -eq $profiles.Count) {
            $result.Firewall = ('Attivo su tutti i profili ({0})' -f (($profiles | ForEach-Object { $_.Name }) -join ', '))
        } else {
            $result.Firewall = ('Parziale: attivo su {0}/{1} profili' -f $enabled.Count, $profiles.Count)
        }
    } catch {
        $result.Firewall = 'Non interrogabile'
    }

    $vpnProcesses = @('openvpn', 'wireguard', 'gpclient', 'vpnui', 'forticlient', 'vpnagent', 'anyconnect', 'cisco vpn', 'globalprotect', 'zscaler', 'openvpnconnect')
    try {
        $active = @(Get-VpnConnection -ErrorAction Stop | Where-Object { $_.ConnectionStatus -eq 'Connected' })
        if ($active.Count -gt 0) {
            $result.VPN = ('Connessa ({0})' -f (($active | ForEach-Object { $_.Name }) -join ', '))
        }
    } catch { }
    if ($result.VPN -eq 'Non rilevata') {
        try {
            $running = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $vpnProcesses -contains $_.ProcessName })
            if ($running.Count -gt 0) {
                $result.VPN = ('Processo attivo: {0}' -f (($running | ForEach-Object { $_.ProcessName } | Select-Object -Unique) -join ', '))
            }
        } catch { }
    }

    try {
        $uac = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'EnableLUA' -ErrorAction Stop
        $result.Uac = $(if ([int]$uac.EnableLUA -eq 1) { 'Attivo (User Account Control)' } else { 'Disattivato' })
    } catch {
        $result.Uac = 'N/D'
    }

    try {
        $pending = (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
                   (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
        $result.PendingReboot = $(if ($pending) { 'Riavvio pendente' } else { 'No' })
    } catch { }

    return [pscustomobject]$result
}

function Get-HomeDashboardReport {
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('========================================================================')
    $lines.Add(' NOVACHIMERA ENTERPRISE - DASHBOARD DI STATO E SICUREZZA')
    $lines.Add('========================================================================')
    $lines.Add('')
    $lines.Add(' [ STATO SICUREZZA ]')
    $security = Get-SecurityStatus
    $lines.Add(("   Antivirus       : {0}" -f $security.Antivirus))
    $lines.Add(("   Firewall        : {0}" -f $security.Firewall))
    $lines.Add(("   VPN             : {0}" -f $security.VPN))
    $lines.Add(("   UAC             : {0}" -f $security.Uac))
    $lines.Add(("   Riavvio pendente: {0}" -f $security.PendingReboot))
    $lines.Add('')
    $lines.Add(' [ POSTAZIONE ]')
    try {
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        $lines.Add(("   Produttore      : {0}" -f (Get-SafeText -InputObject $cs -Name 'Manufacturer' -Default 'N/D')))
        $lines.Add(("   Modello         : {0}" -f (Get-SafeText -InputObject $cs -Name 'Model' -Default 'N/D')))
        $lines.Add(("   Nome computer   : {0}" -f $env:COMPUTERNAME))
        $lines.Add(("   Utente          : {0}" -f $env:USERNAME))
        $ram = [int64](Get-SafeProp -InputObject $cs -Name 'TotalPhysicalMemory')
        if ($ram -gt 0) { $lines.Add(("   RAM installata  : {0} GB" -f [Math]::Round($ram / 1GB, 1))) }
    } catch {
        $lines.Add('   Informazioni postazione non disponibili.')
    }
    try {
        $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop
        $lines.Add(("   Numero di serie : {0}" -f (Get-SafeText -InputObject $bios -Name 'SerialNumber' -Default 'N/D')))
    } catch { }
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $lines.Add(("   Sistema         : {0} ({1})" -f (Get-SafeText -InputObject $os -Name 'Caption' -Default 'N/D'), (Get-SafeText -InputObject $os -Name 'OSArchitecture' -Default 'N/D')))
        $lines.Add(("   Versione build  : {0}" -f (Get-SafeText -InputObject $os -Name 'Version' -Default 'N/D')))
        $lines.Add(("   Ultimo avvio   : {0}" -f (Get-SafeText -InputObject $os -Name 'LastBootUpTime' -Default 'N/D')))
    } catch { }
    try {
        $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cpu) {
            $lines.Add(("   Processore      : {0}" -f (Get-SafeText -InputObject $cpu -Name 'Name' -Default 'N/D').Trim()))
            $lines.Add(("   Core / logici   : {0} / {1}" -f (Get-SafeText -InputObject $cpu -Name 'NumberOfCores' -Default 'N/D'), (Get-SafeText -InputObject $cpu -Name 'NumberOfLogicalProcessors' -Default 'N/D')))
        }
    } catch { }
    try {
        $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
        if ($disk) {
            $free = [int64](Get-SafeProp -InputObject $disk -Name 'FreeSpace')
            $size = [int64](Get-SafeProp -InputObject $disk -Name 'Size')
            if ($size -gt 0) {
                $lines.Add(("   Disco C:        : {0} GB liberi su {1} GB ({2}%)" -f [Math]::Round($free / 1GB, 1), [Math]::Round($size / 1GB, 1), [Math]::Round(100 * $free / $size, 1)))
            }
        }
    } catch { }
    $lines.Add('')
    $lines.Add(' [ RETE LOCALE ]')
    try {
        $addresses = @(Get-LocalIpv4Interfaces)
        $usable = @($addresses | Where-Object { $_.Scope -ne 'Tentative' })
        if ($usable.Count -eq 0) { $usable = $addresses }
        foreach ($address in $usable) {
            $lines.Add(("   {0,-16} /{1,-3} {2,-16} su {3}" -f $address.IpAddress, $address.Prefix, $address.Mask, $address.Interface))
        }
        if ($usable.Count -eq 0) { $lines.Add('   Nessun indirizzo IPv4 attivo.') }
    } catch {
        $lines.Add('   Interfacce di rete non disponibili.')
    }
    try {
        $gateway = @(Get-NetRoute -AddressFamily IPv4 -ErrorAction Stop | Where-Object { $_.DestinationPrefix -eq '0.0.0.0/0' -and $_.NextHop -ne '0.0.0.0' } | Select-Object -First 1)
        if ($gateway.Count -gt 0) { $lines.Add(("   Gateway         : {0}" -f $gateway[0].NextHop)) }
    } catch { }
    try {
        $dns = @(Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction Stop | Where-Object { $_.ServerAddresses } | Select-Object -First 1)
        if ($dns.Count -gt 0) { $lines.Add(("   DNS             : {0}" -f (($dns[0].ServerAddresses) -join ', '))) }
    } catch { }
    $lines.Add('')
    $lines.Add(' [ SERVIZIO SPOOLER ]')
    try {
        $spooler = Get-Service -Name Spooler -ErrorAction Stop
        $lines.Add(("   Spooler         : {0}" -f $spooler.Status))
    } catch {
        $lines.Add('   Spooler non raggiungibile.')
    }
    $lines.Add('')
    $lines.Add('========================================================================')
    return ($lines -join [Environment]::NewLine)
}

function ConvertTo-TextFromBytes {
    param([byte[]]$Bytes)
    if (-not $Bytes -or $Bytes.Length -eq 0) { return '' }
    $hasNull = $false
    for ($i = 1; $i -lt $Bytes.Length; $i += 2) {
        if ($Bytes[$i] -eq 0) { $hasNull = $true; break }
    }
    if ($hasNull) { return [System.Text.Encoding]::Unicode.GetString($Bytes) }
    return [System.Text.Encoding]::UTF8.GetString($Bytes)
}

function Start-BackgroundCommand {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [Parameter(Mandatory = $true)][scriptblock]$OnComplete
    )
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $process.StartInfo.FileName = $FilePath
    $process.StartInfo.Arguments = ($Arguments -join ' ')
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    $outStream = New-Object System.IO.MemoryStream
    $errStream = New-Object System.IO.MemoryStream
    $process.Start() | Out-Null
    $outTask = $null
    $errTask = $null
    try {
        $outTask = $process.StandardOutput.BaseStream.CopyToAsync($outStream)
        $errTask = $process.StandardError.BaseStream.CopyToAsync($errStream)
    } catch {
        Write-Log -Message ("Lettura dell'output del comando non riuscita: {0}" -f $_.Exception.Message) -Level 'DEBUG'
    }
    $pending = [pscustomobject]@{
        Process   = $process
        OutStream = $outStream
        ErrStream = $errStream
        OutTask   = $outTask
        ErrTask   = $errTask
        Callback  = $OnComplete
        Arguments = @($Arguments)
        Started   = Get-Date
    }
    $script:Ui.PendingCommand = $pending
    if (-not $script:Ui.CommandTimer.Enabled) { $script:Ui.CommandTimer.Start() }
    return $pending
}

function Complete-BackgroundCommand {
    $pending = $script:Ui.PendingCommand
    if (-not $pending) { return }
    $script:Ui.PendingCommand = $null
    try {
        if ($pending.OutTask) { [void]$pending.OutTask.Wait(3000) }
        if ($pending.ErrTask) { [void]$pending.ErrTask.Wait(3000) }
    } catch { }
    $text = ''
    try { $text = ConvertTo-TextFromBytes -Bytes $pending.OutStream.ToArray() } catch { }
    $errors = ''
    try { $errors = ConvertTo-TextFromBytes -Bytes $pending.ErrStream.ToArray() } catch { }
    $exitCode = -1
    try { $exitCode = $pending.Process.ExitCode } catch { }
    try { $pending.Process.Dispose() } catch { }
    if ($errors) { $text = $text + [Environment]::NewLine + $errors }
    Write-Log -Message ("Comando in background completato: exit code {0}, {1} caratteri." -f $exitCode, $text.Length) -Level 'DEBUG'
    try { & $pending.Callback $text $exitCode $pending.Arguments } catch { Write-Log -Message ("Callback comando non riuscito: {0}" -f $_.Exception.Message) -Level 'WARN' }
}

function Invoke-TempCleanup {
    $targets = @()
    foreach ($path in @($env:TEMP, (Join-Path -Path $env:SystemRoot -ChildPath 'Temp'))) {
        if ($path -and (Test-Path -LiteralPath $path)) { $targets += $path }
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
    $report.Add('========================================================================')
    return ($report -join [Environment]::NewLine)
}

function Get-WingetUpgradeReport {
    $report = New-Object System.Collections.Generic.List[string]
    $report.Add('========================================================================')
    $report.Add(' AGGIORNAMENTI DISPONIBILI (Winget)')
    $report.Add('========================================================================')
    $report.Add('')
    $winget = Get-Command -Name 'winget' -ErrorAction SilentlyContinue
    if (-not $winget) {
        $report.Add('   Winget non disponibile su questa postazione.')
        $report.Add('   Installare App Installer da Microsoft Store o aggiornare Windows.')
    } else {
        $report.Add(("   Eseguendo: {0} upgrade" -f $winget.Source))
        $report.Add('   (il comando viene eseguito in background, attendere)')
        $report.Add('')
    }
    $report.Add('========================================================================')
    return ($report -join [Environment]::NewLine)
}

function New-DashboardForm {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "$script:AppName v$script:AppVersion - IT Enterprise Suite"
    $form.StartPosition = 'CenterScreen'
    $form.MinimumSize = New-Object System.Drawing.Size(1050, 680)
    $form.Size = New-Object System.Drawing.Size(1320, 860)
    $form.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $form.BackColor = $script:ColorBgMain
    $form.ForeColor = $script:ColorTextMain

    $split = New-Object System.Windows.Forms.SplitContainer
    $split.Dock = 'Fill'
    $split.Orientation = 'Vertical'
    $split.BackColor = $script:ColorBgMain
    $split.Panel1.BackColor = $script:ColorBgMain
    $split.Panel2.BackColor = $script:ColorBgMain
    try { $split.Panel1MinSize = 420; $split.Panel2MinSize = 420 } catch { }

    $mainTabs = New-Object System.Windows.Forms.TabControl
    $mainTabs.Dock = 'Fill'
    $mainTabs.BackColor = $script:ColorBgMain
    $mainTabs.ForeColor = $script:ColorTextMain
    $mainTabs.Padding = New-Object System.Drawing.Point(16, 6)
    $mainTabs.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($mainTabs)

    $bottomPanel = New-Object System.Windows.Forms.Panel
    $bottomPanel.Dock = 'Bottom'
    $bottomPanel.Height = 48
    $bottomPanel.BackColor = $script:ColorPanel
    $bottomPanel.Padding = New-Object System.Windows.Forms.Padding(6, 6, 6, 6)
    $form.Controls.Add($bottomPanel)

    $toolbar = New-Object System.Windows.Forms.FlowLayoutPanel
    $toolbar.Dock = 'Top'
    $toolbar.Height = 92
    $toolbar.BackColor = $script:ColorBgMain
    $toolbar.ForeColor = $script:ColorTextMain
    $toolbar.WrapContents = $true
    $toolbar.AutoScroll = $true
    $toolbar.Padding = New-Object System.Windows.Forms.Padding(6, 6, 6, 4)

    $menu = New-Object System.Windows.Forms.MenuStrip
    $menu.Dock = 'Top'
    $menu.BackColor = $script:ColorPanel
    $menu.ForeColor = $script:ColorTextMain
    $menu.RenderMode = 'Professional'
    $form.Controls.Add($menu)

    $header = New-Object System.Windows.Forms.Label
    $header.Text = "  $($script:AppName) v$($script:AppVersion) - IT Enterprise Suite  |  Supporto Helpdesk & Ticket"
    $header.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
    $header.ForeColor = $script:ColorAccent
    $header.BackColor = $script:ColorBgMain
    $header.Dock = 'Top'
    $header.Height = 36
    $header.TextAlign = 'MiddleLeft'
    $form.Controls.Add($header)

    $fileMenu = New-Object System.Windows.Forms.ToolStripMenuItem('&File')
    [void]$fileMenu.DropDownItems.Add((New-MenuItem 'Esporta report CSV' { Invoke-Safe -Context 'Esportazione CSV' -Action { Invoke-ActionExportReport } }))
    [void]$fileMenu.DropDownItems.Add((New-MenuItem 'Esporta report diagnostico completo' { Invoke-Safe -Context 'Esportazione report' -Action { Invoke-ActionExportDiagnostic } }))
    [void]$fileMenu.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    [void]$fileMenu.DropDownItems.Add((New-MenuItem 'Apri cartella log' {
        Start-Process -FilePath 'explorer.exe' -ArgumentList ('"{0}"' -f (Split-Path -Path $script:LogFile -Parent)) -ErrorAction Stop
    }))
    [void]$fileMenu.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    [void]$fileMenu.DropDownItems.Add((New-MenuItem 'Esci' { Invoke-ActionExit }))
    [void]$menu.Items.Add($fileMenu)

    $actionMenu = New-Object System.Windows.Forms.ToolStripMenuItem('&Azioni')
    [void]$actionMenu.DropDownItems.Add((New-MenuItem 'Aggiorna elenco' { Invoke-Safe -Context 'Aggiornamento elenco' -Action { Invoke-Refresh } }))
    [void]$actionMenu.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    [void]$actionMenu.DropDownItems.Add((New-MenuItem 'Imposta come predefinita' { Invoke-Safe -Context 'Impostazione predefinita' -Action { Invoke-ActionSetDefault } }))
    [void]$actionMenu.DropDownItems.Add((New-MenuItem 'Pulisci coda stampante' { Invoke-Safe -Context 'Pulizia coda' -Action { Invoke-ActionClearQueue } }))
    [void]$actionMenu.DropDownItems.Add((New-MenuItem 'Svuota spooler (tutte le code)' { Invoke-Safe -Context 'Svuotamento spooler' -Action { Invoke-ActionPurgeSpooler } }))
    [void]$actionMenu.DropDownItems.Add((New-MenuItem 'Riavvia servizio Spooler' {
        Invoke-Safe -Context 'Riavvio Spooler' -Action {
            Set-BusyState -Busy $true -Message 'Riavvio spooler in corso...'
            try { $r = Invoke-SpoolerAction -Action Restart } finally { Set-BusyState -Busy $false -Message 'Pronto' }
            [void](Show-Message -Text $r.Message -Caption 'NovaChimera' -Kind $(if ($r.Success) { 'Info' } else { 'Error' }))
        }
    }))
    [void]$actionMenu.DropDownItems.Add((New-MenuItem 'Pagina di prova' { Invoke-Safe -Context 'Pagina di prova' -Action { Invoke-ActionTestPage } }))
    [void]$actionMenu.DropDownItems.Add((New-MenuItem 'Modifica indirizzo IP' { Invoke-Safe -Context 'Modifica IP' -Action { Invoke-ActionEditIp } }))
    [void]$actionMenu.DropDownItems.Add((New-MenuItem 'Apri coda di stampa (GUI Windows)' {
        Invoke-Safe -Context 'Apertura coda' -Action {
            $p = Get-SelectedPrinterOrWarn
            if (-not $p) { return }
            [void](Open-PrinterQueueWindow -TargetPrinter $p.Name)
        }
    }))
    [void]$actionMenu.DropDownItems.Add((New-MenuItem 'Elimina stampante' { Invoke-Safe -Context 'Eliminazione stampante' -Action { Invoke-ActionRemovePrinter } }))
    [void]$menu.Items.Add($actionMenu)

    $toolsMenu = New-Object System.Windows.Forms.ToolStripMenuItem('&Strumenti')
    [void]$toolsMenu.DropDownItems.Add((New-MenuItem 'Esegui test di rete' { Invoke-Safe -Context 'Test di rete' -Action { Invoke-NetworkTest } }))
    [void]$toolsMenu.DropDownItems.Add((New-MenuItem 'Cerca driver del modello' { Invoke-Safe -Context 'Ricerca driver' -Action { Invoke-ActionFindDriver } }))
    [void]$toolsMenu.DropDownItems.Add((New-MenuItem 'Apri WebAdmin della stampante' { Invoke-Safe -Context 'WebAdmin' -Action { Invoke-ActionWebAdmin } }))
    [void]$toolsMenu.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    [void]$toolsMenu.DropDownItems.Add((New-MenuItem 'Esegui elevazione amministratore' {
        Invoke-Safe -Context 'Elevazione' -Action {
            if ((Get-AdminState).IsElevated) { throw "La sessione e' gia' elevata." }
            if (-not (Request-Elevation)) { throw 'Elevazione non riuscita: eseguire launch.ps1 come amministratore.' }
            Invoke-ActionExit
        }
    }))
    [void]$menu.Items.Add($toolsMenu)

    $helpMenu = New-Object System.Windows.Forms.ToolStripMenuItem('&Aiuto')
    [void]$helpMenu.DropDownItems.Add((New-MenuItem 'Informazioni' {
        [void](Show-Message -Text ("{0} v{1} - IT Printer Suite`r`nPowerShell {2}`r`nLog: {3}" -f $script:AppName, $script:AppVersion, $PSVersionTable.PSVersion, $script:LogFile) -Caption 'NovaChimera' -Kind 'Info')
    }))
    [void]$menu.Items.Add($helpMenu)

    $buttons = @(
        @{ Text = '🔄 Aggiorna'; Action = { Invoke-Safe -Context 'Aggiornamento elenco' -Action { Invoke-Refresh } } },
        @{ Text = '⭐ Predefinita'; Action = { Invoke-Safe -Context 'Impostazione predefinita' -Action { Invoke-ActionSetDefault } } },
        @{ Text = '🧹 Pulisci Coda'; Action = { Invoke-Safe -Context 'Pulizia coda' -Action { Invoke-ActionClearQueue } } },
        @{ Text = '⚙️ Svuota Spooler'; Action = { Invoke-Safe -Context 'Svuotamento spooler' -Action { Invoke-ActionPurgeSpooler } } },
        @{ Text = '📡 Test di Rete'; Action = { Invoke-Safe -Context 'Test di rete' -Action { Invoke-NetworkTest } } },
        @{ Text = '✏️ Modifica IP'; Action = { Invoke-Safe -Context 'Modifica IP' -Action { Invoke-ActionEditIp } } },
        @{ Text = '📄 Pagina di Prova'; Action = { Invoke-Safe -Context 'Pagina di prova' -Action { Invoke-ActionTestPage } } },
        @{ Text = '🔍 Cerca Driver'; Action = { Invoke-Safe -Context 'Ricerca driver' -Action { Invoke-ActionFindDriver } } },
        @{ Text = '🌐 WebAdmin'; Action = { Invoke-Safe -Context 'WebAdmin' -Action { Invoke-ActionWebAdmin } } },
        @{ Text = '📊 Esporta Report'; Action = { Invoke-Safe -Context 'Esportazione report' -Action { Invoke-ActionExportReport } } },
        @{ Text = '🗑️ Elimina'; Action = { Invoke-Safe -Context 'Eliminazione stampante' -Action { Invoke-ActionRemovePrinter } } }
    )
    foreach ($definition in $buttons) {
        $button = New-ThemedButton -Text $definition.Text -BackColor $script:ColorPanel -ForeColor $script:ColorTextMain
        if ($definition.Text -like '🗑️*') { $button.ForeColor = $script:ColorError }
        if ($definition.Text -like '🔄*' -or $definition.Text -like '📡*') { $button.ForeColor = $script:ColorAccent }
        $button.Add_Click($definition.Action)
        $toolbar.Controls.Add($button)
    }

    $list = New-ThemedListView -OwnerDrawHeader
    foreach ($definition in $script:PrinterListColumns) {
        [void]$list.Columns.Add($definition.Title, $definition.Width)
    }
    $list.Add_SizeChanged({ Sync-PrinterListColumnWidths })
    $list.Add_SelectedIndexChanged({
        if ($script:Ui.PrinterList.SelectedItems.Count -eq 0) { return }
        $item = $script:Ui.PrinterList.SelectedItems[0]
        if ($item.Tag) {
            $script:SelectedPrinter = $item.Tag
            $script:SelectedPrinterName = $item.Tag.Name
        } else {
            $script:SelectedPrinterName = $item.Text
        }
        Show-PrinterDetails
        Show-PrinterJobs
        Show-NetworkTab
        Show-LiveCard
    })
    $split.Panel1.Controls.Add($list)

    $tabs = New-Object System.Windows.Forms.TabControl
    $tabs.Dock = 'Fill'
    $tabs.BackColor = $script:ColorBgMain
    $tabs.ForeColor = $script:ColorTextMain
    $tabs.Padding = New-Object System.Drawing.Point(14, 6)

    $tabCard = New-Object System.Windows.Forms.TabPage('📊 Card')
    $tabCard.BackColor = $script:ColorPanel
    $tabCard.ForeColor = $script:ColorAccent
    $cardBox = New-Object System.Windows.Forms.TextBox
    $cardBox.Multiline = $true
    $cardBox.ReadOnly = $true
    $cardBox.ScrollBars = 'Vertical'
    $cardBox.BackColor = $script:ColorCardBg
    $cardBox.ForeColor = $script:ColorSuccess
    $cardBox.Font = New-Object System.Drawing.Font('Consolas', 9.5)
    $cardBox.Dock = 'Fill'
    $cardBox.BorderStyle = 'None'
    $tabCard.Controls.Add($cardBox)

    $tabDetails = New-Object System.Windows.Forms.TabPage('🔍 Dettagli')
    $tabDetails.BackColor = $script:ColorPanel
    $tabDetails.ForeColor = $script:ColorAccent
    $detailList = New-ThemedListView
    [void]$detailList.Columns.Add('Campo', 170)
    [void]$detailList.Columns.Add('Valore', 360)
    $tabDetails.Controls.Add($detailList)

    $tabNetwork = New-Object System.Windows.Forms.TabPage('📡 Rete')
    $tabNetwork.BackColor = $script:ColorPanel
    $tabNetwork.ForeColor = $script:ColorAccent
    $netPanel = New-Object System.Windows.Forms.Panel
    $netPanel.Dock = 'Fill'
    $netPanel.BackColor = $script:ColorPanel
    $netBox = New-Object System.Windows.Forms.TextBox
    $netBox.Multiline = $true
    $netBox.ReadOnly = $true
    $netBox.ScrollBars = 'Vertical'
    $netBox.Dock = 'Fill'
    $netBox.BackColor = $script:ColorCardBg
    $netBox.ForeColor = $script:ColorSuccess
    $netBox.Font = New-Object System.Drawing.Font('Consolas', 9.5)
    $netBox.BorderStyle = 'None'
    $netPanel.Controls.Add($netBox)
    $netButton = New-ThemedButton -Text '📡 Esegui test di rete' -BackColor $script:ColorPanel -ForeColor $script:ColorAccent
    $netButton.Dock = 'Top'
    $netButton.Add_Click({ Invoke-Safe -Context 'Test di rete' -Action { Invoke-NetworkTest } })
    $netPanel.Controls.Add($netButton)
    $tabNetwork.Controls.Add($netPanel)

    $tabJobs = New-Object System.Windows.Forms.TabPage('🧾 Lavori')
    $tabJobs.BackColor = $script:ColorPanel
    $tabJobs.ForeColor = $script:ColorAccent
    $jobList = New-ThemedListView
    [void]$jobList.Columns.Add('ID', 50)
    [void]$jobList.Columns.Add('Utente', 120)
    [void]$jobList.Columns.Add('Documento', 230)
    [void]$jobList.Columns.Add('Stato', 100)
    [void]$jobList.Columns.Add('Dimensione', 90)
    [void]$jobList.Columns.Add('Inviato', 155)
    $tabJobs.Controls.Add($jobList)

    $tabLog = New-Object System.Windows.Forms.TabPage('📜 Registro')
    $tabLog.BackColor = $script:ColorPanel
    $tabLog.ForeColor = $script:ColorAccent
    $logPanel = New-Object System.Windows.Forms.Panel
    $logPanel.Dock = 'Fill'
    $logPanel.BackColor = $script:ColorPanel
    $logBox = New-Object System.Windows.Forms.TextBox
    $logBox.Multiline = $true
    $logBox.ReadOnly = $true
    $logBox.ScrollBars = 'Both'
    $logBox.WordWrap = $false
    $logBox.Dock = 'Fill'
    $logBox.BackColor = $script:ColorCardBg
    $logBox.ForeColor = $script:ColorTextMain
    $logBox.Font = New-Object System.Drawing.Font('Consolas', 9)
    $logBox.BorderStyle = 'None'
    $logPanel.Controls.Add($logBox)
    $logButtons = New-Object System.Windows.Forms.FlowLayoutPanel
    $logButtons.Dock = 'Top'
    $logButtons.Height = 40
    $logButtons.BackColor = $script:ColorPanel
    $btnCopy = New-ThemedButton -Text 'Copia registro' -BackColor $script:ColorPanel -ForeColor $script:ColorTextMain
    $btnCopy.Add_Click({
        Invoke-Safe -Context 'Copia registro' -Action {
            [System.Windows.Forms.Clipboard]::SetText($script:Ui.LogBox.Text)
            [void](Show-Message -Text 'Registro copiato negli appunti.' -Caption 'NovaChimera' -Kind 'Info')
        }
    })
    $logButtons.Controls.Add($btnCopy)
    $btnSaveLog = New-ThemedButton -Text 'Salva registro' -BackColor $script:ColorPanel -ForeColor $script:ColorTextMain
    $btnSaveLog.Add_Click({
        Invoke-Safe -Context 'Salva registro' -Action {
            $path = Join-Path -Path $script:LogDirectory -ChildPath ("registro-{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
            Set-Content -LiteralPath $path -Value $script:Ui.LogBox.Text -Encoding UTF8 -ErrorAction Stop
            [void](Show-Message -Text ("Registro salvato in {0}" -f $path) -Caption 'NovaChimera' -Kind 'Info')
        }
    })
    $logButtons.Controls.Add($btnSaveLog)
    $btnClearLog = New-ThemedButton -Text 'Pulisci registro' -BackColor $script:ColorPanel -ForeColor $script:ColorTextMain
    $btnClearLog.Add_Click({ $script:Ui.LogBox.Clear() })
    $logButtons.Controls.Add($btnClearLog)
    $logPanel.Controls.Add($logButtons)
    $tabLog.Controls.Add($logPanel)

    [void]$tabs.TabPages.Add($tabCard)
    [void]$tabs.TabPages.Add($tabDetails)
    [void]$tabs.TabPages.Add($tabNetwork)
    [void]$tabs.TabPages.Add($tabJobs)
    [void]$tabs.TabPages.Add($tabLog)
    $split.Panel2.Controls.Add($tabs)

    # ------------------------------------------------------------------------
    # SCHEDA 1 - HOME / DASHBOARD DI SICUREZZA
    # ------------------------------------------------------------------------
    $tabHome = New-Object System.Windows.Forms.TabPage('  🛡️  Home / Dashboard  ')
    $tabHome.BackColor = $script:ColorBgMain
    $tabHome.ForeColor = $script:ColorAccent
    $tabHome.Padding = New-Object System.Windows.Forms.Padding(8)
    $mainTabs.TabPages.Add($tabHome)

    $homeBox = New-Object System.Windows.Forms.TextBox
    $homeBox.Multiline = $true
    $homeBox.ReadOnly = $true
    $homeBox.ScrollBars = 'Vertical'
    $homeBox.BackColor = $script:ColorCardBg
    $homeBox.ForeColor = $script:ColorTextMain
    $homeBox.Font = New-Object System.Drawing.Font('Consolas', 10)
    $homeBox.Dock = 'Fill'
    $homeBox.BorderStyle = 'None'
    $tabHome.Controls.Add($homeBox)

    $homeBar = New-Object System.Windows.Forms.FlowLayoutPanel
    $homeBar.Dock = 'Top'
    $homeBar.Height = 48
    $homeBar.BackColor = $script:ColorBgMain
    $homeBar.Padding = New-Object System.Windows.Forms.Padding(0, 0, 0, 6)
    $btnRefreshHome = New-ThemedButton -Text '🛡️ Aggiorna Dashboard' -BackColor $script:ColorAccent -ForeColor $script:ColorBgMain
    $btnRefreshHome.Add_Click({
        Invoke-Safe -Context 'Aggiornamento dashboard' -Action {
            Set-BusyState -Busy $true -Message 'Raccolta dati di sistema...'
            try {
                $script:Ui.HomeBox.Text = Get-HomeDashboardReport
                Update-StatusBar 'Dashboard di sicurezza aggiornata.'
            } finally {
                Set-BusyState -Busy $false -Message 'Pronto'
            }
        }
    })
    $homeBar.Controls.Add($btnRefreshHome)
    $tabHome.Controls.Add($homeBar)

    # ------------------------------------------------------------------------
    # SCHEDA 2 - GESTIONE STAMPANTI (suite v1.4)
    # ------------------------------------------------------------------------
    $tabPrinters = New-Object System.Windows.Forms.TabPage('  🖨️  Gestione Stampanti  ')
    $tabPrinters.BackColor = $script:ColorBgMain
    $tabPrinters.ForeColor = $script:ColorAccent
    $tabPrinters.Padding = New-Object System.Windows.Forms.Padding(6)
    $mainTabs.TabPages.Add($tabPrinters)
    $tabPrinters.Controls.Add($split)
    $tabPrinters.Controls.Add($toolbar)

    # ------------------------------------------------------------------------
    # SCHEDA 3 - NETWORK & RETE
    # ------------------------------------------------------------------------
    $tabNet = New-Object System.Windows.Forms.TabPage('  📡  Network & Rete  ')
    $tabNet.BackColor = $script:ColorBgMain
    $tabNet.ForeColor = $script:ColorAccent
    $tabNet.Padding = New-Object System.Windows.Forms.Padding(8)
    $mainTabs.TabPages.Add($tabNet)

    $netOutput = New-Object System.Windows.Forms.TextBox
    $netOutput.Multiline = $true
    $netOutput.ReadOnly = $true
    $netOutput.ScrollBars = 'Both'
    $netOutput.WordWrap = $false
    $netOutput.BackColor = $script:ColorCardBg
    $netOutput.ForeColor = $script:ColorSuccess
    $netOutput.Font = New-Object System.Drawing.Font('Consolas', 9.5)
    $netOutput.Dock = 'Fill'
    $netOutput.BorderStyle = 'None'
    $tabNet.Controls.Add($netOutput)

    $netBar = New-Object System.Windows.Forms.FlowLayoutPanel
    $netBar.Dock = 'Top'
    $netBar.Height = 48
    $netBar.BackColor = $script:ColorBgMain
    $netBar.Padding = New-Object System.Windows.Forms.Padding(0, 0, 0, 6)
    $tabNet.Controls.Add($netBar)

    $netCommands = @(
        @{ Text = '📋 Info complete (/all)'; Args = @('/all') },
        @{ Text = '🔎 Cache DNS (/displaydns)'; Args = @('/displaydns') },
        @{ Text = '🧹 Pulisci cache DNS (/flushdns)'; Args = @('/flushdns') },
        @{ Text = '🔄 Rinnova IP (/renew)'; Args = @('/renew') }
    )
    $netCommandHandler = {
        $ipconfigArgs = @($this.Tag)
        Invoke-Safe -Context 'Comando di rete' -Action {
            $script:Ui.NetBox.Text = ("Esecuzione in corso: ipconfig {0} ..." -f ($ipconfigArgs -join ' '))
            [void](Start-BackgroundCommand -FilePath 'ipconfig.exe' -Arguments $ipconfigArgs -OnComplete {
                param($text, $exitCode, $cmdArgs)
                $label = ($cmdArgs -join ' ')
                $script:Ui.NetBox.Text = ("ipconfig {0} (exit code {1})`r`n{2}" -f $label, $exitCode, $text)
                Update-StatusBar ("ipconfig {0} completato (exit {1})." -f $label, $exitCode)
            })
            Update-StatusBar ("ipconfig {0} in esecuzione..." -f ($ipconfigArgs -join ' '))
        }
    }
    foreach ($command in $netCommands) {
        $button = New-ThemedButton -Text $command.Text -BackColor $script:ColorPanel -ForeColor $script:ColorTextMain
        $button.Tag = @($command.Args)
        $button.Add_Click($netCommandHandler)
        $netBar.Controls.Add($button)
    }

    # ------------------------------------------------------------------------
    # SCHEDA 4 - MANUTENZIONE & OTTIMIZZAZIONE PC
    # ------------------------------------------------------------------------
    $tabMaint = New-Object System.Windows.Forms.TabPage('  🛠️  Manutenzione PC  ')
    $tabMaint.BackColor = $script:ColorBgMain
    $tabMaint.ForeColor = $script:ColorAccent
    $tabMaint.Padding = New-Object System.Windows.Forms.Padding(8)
    $mainTabs.TabPages.Add($tabMaint)

    $maintOutput = New-Object System.Windows.Forms.TextBox
    $maintOutput.Multiline = $true
    $maintOutput.ReadOnly = $true
    $maintOutput.ScrollBars = 'Both'
    $maintOutput.WordWrap = $false
    $maintOutput.BackColor = $script:ColorCardBg
    $maintOutput.ForeColor = $script:ColorSuccess
    $maintOutput.Font = New-Object System.Drawing.Font('Consolas', 9.5)
    $maintOutput.Dock = 'Fill'
    $maintOutput.BorderStyle = 'None'
    $tabMaint.Controls.Add($maintOutput)

    $maintBar = New-Object System.Windows.Forms.FlowLayoutPanel
    $maintBar.Dock = 'Top'
    $maintBar.Height = 48
    $maintBar.BackColor = $script:ColorBgMain
    $maintBar.Padding = New-Object System.Windows.Forms.Padding(0, 0, 0, 6)
    $tabMaint.Controls.Add($maintBar)

    $btnTemp = New-ThemedButton -Text '🧹 Pulisci file temporanei' -BackColor $script:ColorPanel -ForeColor $script:ColorWarning
    $btnTemp.Add_Click({
        Invoke-Safe -Context 'Pulizia file temporanei' -Action {
            $answer = Show-Message -Text "Eliminare i file temporanei di utente e di sistema?`r`nI file in uso da altre applicazioni verranno saltati." -Caption 'NovaChimera - Pulizia' -Kind 'Question'
            if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
            Set-BusyState -Busy $true -Message 'Pulizia in corso...'
            try {
                $script:Ui.MaintBox.Text = Invoke-TempCleanup
                Update-StatusBar 'Pulizia dei file temporanei completata.'
            } finally {
                Set-BusyState -Busy $false -Message 'Pronto'
            }
        }
    })
    $maintBar.Controls.Add($btnTemp)

    $btnWinget = New-ThemedButton -Text '📦 Aggiornamenti (Winget)' -BackColor $script:ColorPanel -ForeColor $script:ColorAccent
    $btnWinget.Add_Click({
        Invoke-Safe -Context 'Controllo aggiornamenti' -Action {
            $script:Ui.MaintBox.Text = Get-WingetUpgradeReport
            $winget = Get-Command -Name 'winget' -ErrorAction SilentlyContinue
            if (-not $winget) {
                Update-StatusBar 'Winget non disponibile.'
                return
            }
            [void](Start-BackgroundCommand -FilePath $winget.Source -Arguments @('upgrade', '--accept-source-agreements') -OnComplete {
                param($text, $exitCode, $cmdArgs)
                $script:Ui.MaintBox.Text = ("winget upgrade (exit code {0})`r`n{1}" -f $exitCode, $text)
                Update-StatusBar ("Winget completato (exit {0})." -f $exitCode)
            })
            Update-StatusBar 'Controllo aggiornamenti in esecuzione...'
        }
    })
    $maintBar.Controls.Add($btnWinget)

    $bottomLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $bottomLayout.Dock = 'Fill'
    $bottomLayout.ColumnCount = 2
    $bottomLayout.RowCount = 1
    $bottomLayout.BackColor = $script:ColorPanel
    [void]$bottomLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    [void]$bottomLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize)))
    [void]$bottomLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $bottomPanel.Controls.Add($bottomLayout)

    $status = New-Object System.Windows.Forms.StatusStrip
    $status.BackColor = $script:ColorPanel
    $status.ForeColor = $script:ColorTextMuted
    $status.SizingGrip = $false
    $statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel('Inizializzazione...')
    $statusLabel.Spring = $true
    $statusLabel.TextAlign = 'MiddleLeft'
    [void]$status.Items.Add($statusLabel)
    $spoolerLabel = New-Object System.Windows.Forms.ToolStripStatusLabel('Spooler: N/D')
    [void]$status.Items.Add($spoolerLabel)
    $elevLabel = New-Object System.Windows.Forms.ToolStripStatusLabel('Elevato: no')
    [void]$status.Items.Add($elevLabel)
    $bottomLayout.Controls.Add($status, 0, 0)

    $btnExitApp = New-ThemedButton -Text '🛑 Termina Applicazione' -BackColor $script:ColorError -ForeColor $script:ColorBgMain
    $btnExitApp.Margin = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
    $btnExitApp.Add_Click({ Invoke-ActionExit })
    $bottomLayout.Controls.Add($btnExitApp, 1, 0)

    $progress = New-Object System.Windows.Forms.ProgressBar
    $progress.Dock = 'Bottom'
    $progress.Height = 10
    $progress.Style = 'Marquee'
    $progress.Visible = $false
    $form.Controls.Add($progress)

    $script:Ui.Form = $form
    $script:Ui.PrinterList = $list
    $script:Ui.DetailList = $detailList
    $script:Ui.CardBox = $cardBox
    $script:Ui.NetworkBox = $netBox
    $script:Ui.JobList = $jobList
    $script:Ui.LogBox = $logBox
    $script:Ui.StatusLabel = $statusLabel
    $script:Ui.SpoolerLabel = $spoolerLabel
    $script:Ui.ElevLabel = $elevLabel
    $script:Ui.Progress = $progress
    $script:Ui.Tabs = $tabs
    $script:Ui.Split = $split
    $script:Ui.Toolbar = $toolbar
    $script:Ui.ExitButton = $btnExitApp
    $script:Ui.MainTabs = $mainTabs
    $script:Ui.HomeBox = $homeBox
    $script:Ui.NetBox = $netOutput
    $script:Ui.MaintBox = $maintOutput
    $script:Ui.PendingCommand = $null
    $script:Ui.CommandTimer = New-Object System.Windows.Forms.Timer
    $script:Ui.CommandTimer.Interval = 400
    $script:Ui.CommandTimer.Add_Tick({
        $pending = $script:Ui.PendingCommand
        if (-not $pending) {
            $script:Ui.CommandTimer.Stop()
            return
        }
        try {
            if (-not $pending.Process.HasExited) {
                if (((Get-Date) - $pending.Started).TotalSeconds -gt 180) {
                    Write-Log -Message 'Comando in background interrotto: superato il tempo massimo di attesa.' -Level 'WARN'
                    try { $pending.Process.Kill() } catch { }
                }
                return
            }
        } catch {
            $script:Ui.CommandTimer.Stop()
            $script:Ui.PendingCommand = $null
            return
        }
        $script:Ui.CommandTimer.Stop()
        Complete-BackgroundCommand
    })

    foreach ($entry in $script:LogEntries) {
        try { $logBox.AppendText($entry + [Environment]::NewLine) } catch { }
    }

    $form.Add_Shown({ Initialize-DashboardState })

    return $form
}
function Initialize-DashboardState {
    try {
        $script:Ui.Split.Panel1MinSize = 420
        $script:Ui.Split.Panel2MinSize = 420
        $script:Ui.Split.SplitterDistance = 760
    } catch {
        Write-Log -Message ("Layout del pannello laterale non ottimizzabile: {0}" -f $_.Exception.Message) -Level 'DEBUG'
    }
    try { Sync-PrinterListColumnWidths } catch { }
    try {
        Invoke-Refresh
        $health = Get-SpoolerHealth
        $script:Ui.SpoolerLabel.Text = ('Spooler: {0} - file in coda: {1}' -f $health.Status, $health.QueueFiles)
        $elevated = (Get-AdminState).IsElevated
        $script:Ui.ElevLabel.Text = ('Elevato: {0}' -f $(if ($elevated) { 'si' } else { 'no' }))
        if (-not $elevated) {
            $script:Ui.StatusLabel.Text = "Sessione NON elevata: svuotamento spooler e riavvio servizio non disponibili."
        }
        if ($script:SelectedPrinter) {
            foreach ($item in $script:Ui.PrinterList.Items) {
                if ($item.Tag -and $item.Tag.Name -eq $script:SelectedPrinter.Name) { $item.Selected = $true; break }
            }
        }
    } catch {
        Write-Log -Message ("Inizializzazione interfaccia non riuscita: {0}" -f $_.Exception.Message) -Level 'ERROR'
    }
    try {
        $script:Ui.HomeBox.Text = Get-HomeDashboardReport
    } catch {
        Write-Log -Message ("Dashboard di sicurezza non disponibile: {0}" -f $_.Exception.Message) -Level 'WARN'
    }
}

function Show-Dashboard {
    try {
        $form = New-DashboardForm
    } catch {
        Write-Log -Message ("Interfaccia non inizializzabile: {0}" -f $_.Exception.Message) -Level 'ERROR'
        [void](Show-Message -Text ("Interfaccia grafica non inizializzabile: {0}" -f $_.Exception.Message) -Caption 'NovaChimera - Errore' -Kind 'Error')
        return
    }
    try {
        [System.Windows.Forms.Application]::Run($form)
    } catch {
        Write-Log -Message ("Errore durante l'esecuzione della GUI: {0}" -f $_.Exception.Message) -Level 'ERROR'
    } finally {
        Write-Log -Message 'Chiusura dell''applicazione.' -Level 'INFO'
    }
}

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
    Write-Error "NovaChimera e' supportato solo su sistemi Windows."
    exit 1
}

if (-not $NoElevation) {
    if (-not (Get-AdminState).IsElevated) {
        Write-Log -Message "Sessione non elevata: il tool continua in modalita' ridotta, con proposta di elevazione." -Level 'WARN'
    }
}

Initialize-Application

if ($SelfTest) {
    Invoke-SelfTest
    exit 0
}

if ($Diagnose) {
    Update-Inventory | Out-Null
    Select-PrinterByName -Name $PrinterName
    if (-not $script:SelectedPrinter -and $script:Inventory.Count -gt 0) {
        $script:SelectedPrinter = $script:Inventory[0]
    }
    Write-Output (Get-DiagnosticReport)
    exit 0
}

if ($PSBoundParameters.ContainsKey('ResolvePort')) {
    $targetPrinter = if ($ResolvePrinter) { $ResolvePrinter } else { 'N/D' }
    $endpoint = Resolve-PrinterEndpoint -PrinterName $targetPrinter -PortName $ResolvePort
    Write-Output ("Porta      : {0}" -f $endpoint.PortName)
    Write-Output ("Tipo       : {0}" -f $endpoint.Kind)
    Write-Output ("Host       : {0}" -f $endpoint.Host)
    Write-Output ("IP         : {0}" -f $endpoint.IpAddress)
    Write-Output ("TCP        : {0}" -f $endpoint.TcpPort)
    Write-Output ("Sorgente   : {0}" -f $endpoint.Source)
    foreach ($note in $endpoint.Notes) { Write-Output ("Nota       : {0}" -f $note) }
    exit 0
}

if ($SmokeTest) {
    try {
        $form = New-DashboardForm
        Initialize-DashboardState
        $tabLabels = @($script:Ui.MainTabs.TabPages | ForEach-Object { $_.Text.Trim() })
        $checks = @(
            @{ Name = 'Schede principali'; Ok = ($script:Ui.MainTabs.TabPages.Count -eq 4); Detail = ($tabLabels -join ' | ') }
            @{ Name = 'Dashboard Home'; Ok = (-not [string]::IsNullOrWhiteSpace($script:Ui.HomeBox.Text)); Detail = ("{0} caratteri" -f $script:Ui.HomeBox.Text.Length) }
            @{ Name = 'Elenco stampanti'; Ok = ($script:Ui.PrinterList.Items.Count -ge 0); Detail = ("{0} righe" -f $script:Ui.PrinterList.Items.Count) }
            @{ Name = 'Colonne elenco'; Ok = ($script:Ui.PrinterList.Columns.Count -eq 8); Detail = ("{0} colonne" -f $script:Ui.PrinterList.Columns.Count) }
            @{ Name = 'Dettagli stampante'; Ok = ($script:Ui.DetailList.Items.Count -gt 0); Detail = ("{0} campi" -f $script:Ui.DetailList.Items.Count) }
            @{ Name = 'Schede interne'; Ok = ($script:Ui.Tabs.TabPages.Count -eq 5); Detail = ("{0} schede" -f $script:Ui.Tabs.TabPages.Count) }
            @{ Name = 'Output rete'; Ok = ($null -ne $script:Ui.NetBox); Detail = 'casella di uscita presente' }
            @{ Name = 'Output manutenzione'; Ok = ($null -ne $script:Ui.MaintBox); Detail = 'casella di uscita presente' }
            @{ Name = 'Pulsanti operativi'; Ok = ($script:Ui.Toolbar.Controls.Count -eq 11); Detail = ("{0} pulsanti" -f $script:Ui.Toolbar.Controls.Count) }
        )
        $failed = 0
        foreach ($check in $checks) {
            if (-not $check.Ok) { $failed++ }
            Write-Output ("  [{0}] {1,-22} {2}" -f $(if ($check.Ok) { 'OK  ' } else { 'FAIL' }), $check.Name, $check.Detail)
        }
        Write-Output ("GUI smoke test superato: {0} controlli, {1} falliti, {2} stampante in elenco, dettagli: {3}, log: {4} righe." -f `
            $checks.Count, $failed, $script:Ui.PrinterList.Items.Count, $script:Ui.DetailList.Items.Count, $script:LogEntries.Count)
        $form.Dispose()
        if ($failed -gt 0) { exit 1 }
        exit 0
    } catch {
        Write-Output ("GUI smoke test FALLITO: {0}" -f $_.Exception.Message)
        Write-Log -Message ("GUI smoke test fallito: {0}" -f $_.Exception.Message) -Level 'ERROR'
        exit 1
    }
}

$apartment = [System.Threading.Thread]::CurrentThread.ApartmentState
if ($apartment -ne [System.Threading.ApartmentState]::STA) {
    Write-Log -Message ("ApartmentState {0}: rilancio del processo in STA." -f $apartment) -Level 'WARN'
    $shell = Join-Path -Path $PSHOME -ChildPath 'pwsh.exe'
    if (-not (Test-Path -LiteralPath $shell)) { $shell = Join-Path -Path $PSHOME -ChildPath 'powershell.exe' }
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', ('"{0}"' -f $PSCommandPath))
    if ($PrinterName) { $argList += @('-PrinterName', ('"{0}"' -f $PrinterName)) }
    try {
        Start-Process -FilePath $shell -ArgumentList $argList -WorkingDirectory $PSScriptRoot -ErrorAction Stop | Out-Null
    } catch {
        Write-Log -Message ("Rilancio in STA non riuscito: {0}" -f $_.Exception.Message) -Level 'ERROR'
    }
    exit 0
}

try {
    Update-Inventory | Out-Null
    Select-PrinterByName -Name $PrinterName
} catch {
    Write-Log -Message ("Inventario iniziale non riuscito: {0}" -f $_.Exception.Message) -Level 'ERROR'
}

Show-Dashboard
