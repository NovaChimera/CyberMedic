# CyberMedic - Modulo Core: gestione Office (informazioni, licenze, disinstallazione).
# Caricato da CyberMedic_Core.ps1 tramite dot-sourcing.
#
# Nota di sicurezza: il modulo NON cancella mai i file di Office a mano.
# La rimozione avviene tramite il disinstallatore ufficiale di Microsoft
# (stringa di disinstallazione del registro), che gestisce registri, servizi
# e licenze in modo coerente. La chiave di licenza deve essere fornita
# dall'utente: se manca o e' vuota il comando si ferma con un messaggio
# esplicito e non esegue nulla.

function Get-OfficeCandidateRoot {
    $candidates = @(
        (Join-Path -Path $env:ProgramFiles -ChildPath 'Microsoft Office')
        (Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'Microsoft Office')
        (Join-Path -Path $env:ProgramFiles -ChildPath 'Microsoft Office 15')
        (Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'Microsoft Office 15')
        (Join-Path -Path $env:ProgramFiles -ChildPath 'Microsoft Office 16')
        (Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'Microsoft Office 16')
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Container)) { return $candidate }
    }
    return $null
}

function Get-OfficeProductInfo {
    $products = New-Object System.Collections.Generic.List[object]
    $uninstallRoots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach ($root in $uninstallRoots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        try {
            $keys = @(Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue)
            foreach ($key in $keys) {
                $props = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction SilentlyContinue
                if (-not $props) { continue }
                $name = [string]$props.DisplayName
                if (-not $name) { continue }
                if ($name -notmatch '(?i)Microsoft (Office|365|Visio|Project)') { continue }
                $products.Add([pscustomobject]@{
                    Name           = $name
                    Version        = [string]$props.DisplayVersion
                    Publisher      = [string]$props.Publisher
                    InstallDate    = [string]$props.InstallDate
                    UninstallString = [string]$props.UninstallString
                    QuietUninstall = [string]$props.QuietUninstallString
                    Key            = $key.PSChildName
                })
            }
        } catch { }
    }

    $osppPath = $null
    foreach ($osppCandidate in @(
        (Join-Path -Path $env:ProgramFiles -ChildPath 'Microsoft Office\Office16\OSPP.VBS')
        (Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'Microsoft Office\Office16\OSPP.VBS')
        (Join-Path -Path $env:ProgramFiles -ChildPath 'Microsoft Office\root\Office16\OSPP.VBS')
        (Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'Microsoft Office\root\Office16\OSPP.VBS')
    )) {
        if ($osppCandidate -and (Test-Path -LiteralPath $osppCandidate -PathType Leaf)) { $osppPath = $osppCandidate; break }
    }

    $scanPath = $null
    foreach ($scanCandidate in @(
        (Join-Path -Path $env:ProgramFiles -ChildPath 'Microsoft Office\root\Office16\SCANPST.EXE')
        (Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'Microsoft Office\root\Office16\SCANPST.EXE')
        (Join-Path -Path $env:ProgramFiles -ChildPath 'Microsoft Office\Office16\SCANPST.EXE')
        (Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'Microsoft Office\Office16\SCANPST.EXE')
    )) {
        if ($scanCandidate -and (Test-Path -LiteralPath $scanCandidate -PathType Leaf)) { $scanPath = $scanCandidate; break }
    }

    $root = Get-OfficeCandidateRoot
    return [pscustomobject]@{
        Installed   = ($products.Count -gt 0 -or $null -ne $root)
        Products    = @($products.ToArray())
        ProductCount = $products.Count
        Root        = $root
        OsppPath    = $osppPath
        ScanPstPath = $scanPath
        Summary     = ("Office installato: {0} | prodotti: {1} | OSPP.VBS: {2} | SCANPST: {3}" -f `
            $(if ($products.Count -gt 0 -or $root) { 'si' } else { 'no' }), $products.Count, `
            $(if ($osppPath) { 'presente' } else { 'assente' }), $(if ($scanPath) { 'presente' } else { 'assente' }))
    }
}

function Get-OfficeLicenseStatus {
    $info = Get-OfficeProductInfo
    if (-not $info.OsppPath) {
        return [pscustomobject]@{
            Success = $false
            Message = 'OSPP.VBS non trovato: licenze Office non gestibili su questa postazione.'
            Output  = ''
        }
    }
    try {
        $output = & cscript.exe //nologo $info.OsppPath /dstatus 2>&1 | Out-String
        return [pscustomobject]@{
            Success = $true
            Message = 'Stato delle licenze Office letto.'
            Output  = $output.Trim()
        }
    } catch {
        return [pscustomobject]@{
            Success = $false
            Message = ("Lettura dello stato licenze non riuscita: {0}" -f $_.Exception.Message)
            Output  = ''
        }
    }
}

function Set-OfficeProductKey {
    param([Parameter(Mandatory = $false)][AllowEmptyString()][string]$LicenseKey = '')

    # Guardia sulla chiave vuota: evita il binding a parametro obbligatorio
    # e restituisce un esito leggibile all'interfaccia.
    if ([string]::IsNullOrWhiteSpace($LicenseKey)) {
        Write-Log -Message 'Chiave di licenza Office vuota: nessuna operazione eseguita.' -Level 'WARN'
        return [pscustomobject]@{
            Success = $false
            Message = 'Inserire una chiave di licenza Office valida (formato XXXXX-XXXXX-XXXXX-XXXXX-XXXXX).'
            Output  = ''
        }
    }

    $key = $LicenseKey.Trim()
    if ($key -notmatch '^[0-9A-Za-z]{5}-[0-9A-Za-z]{5}-[0-9A-Za-z]{5}-[0-9A-Za-z]{5}-[0-9A-Za-z]{5}$') {
        Write-Log -Message ("Formato della chiave di licenza Office non valido: {0}" -f $key) -Level 'WARN'
        return [pscustomobject]@{
            Success = $false
            Message = 'Formato della chiave non valido: atteso XXXXX-XXXXX-XXXXX-XXXXX-XXXXX.'
            Output  = ''
        }
    }

    $info = Get-OfficeProductInfo
    if (-not $info.OsppPath) {
        return [pscustomobject]@{
            Success = $false
            Message = 'OSPP.VBS non trovato: installazione di Office non riconosciuta su questa postazione.'
            Output  = ''
        }
    }

    try {
        $input = & cscript.exe //nologo $info.OsppPath ("/inpkey:{0}" -f $key) 2>&1 | Out-String
        $activate = & cscript.exe //nologo $info.OsppPath /act 2>&1 | Out-String
        $combined = ($input.Trim() + "`r`n" + $activate.Trim()).Trim()
        Write-Log -Message ("Chiave di licenza Office applicata tramite OSPP.VBS." -f $key) -Level 'INFO'
        return [pscustomobject]@{
            Success = ($combined -notmatch '(?i)error|non riuscito|failed')
            Message = 'Chiave applicata. Verificare lo stato con "Stato licenze Office".'
            Output  = $combined
        }
    } catch {
        Write-Log -Message ("Inserimento della chiave di licenza Office non riuscito: {0}" -f $_.Exception.Message) -Level 'ERROR'
        return [pscustomobject]@{
            Success = $false
            Message = ("Inserimento della chiave non riuscito: {0}" -f $_.Exception.Message)
            Output  = ''
        }
    }
}

function Remove-OfficeCompletely {
    param([switch]$Execute)

    $info = Get-OfficeProductInfo
    if (-not $info.Installed) {
        return [pscustomobject]@{
            Success = $true
            Message = 'Nessuna installazione di Office rilevata: nulla da rimuovere.'
            Details = @()
        }
    }

    $details = New-Object System.Collections.Generic.List[string]
    $removed = 0
    foreach ($product in $info.Products) {
        if (-not $product.UninstallString) {
            $details.Add(("[SKIP] {0}: nessuna stringa di disinstallazione disponibile." -f $product.Name))
            continue
        }
        if (-not $Execute) {
            $details.Add(("[PIANO] {0} {1} -> {2}" -f $product.Name, $product.Version, $product.UninstallString))
            continue
        }
        $command = $product.UninstallString
        $arguments = ''
        if ($command -match '^(.*\.exe)["\s]+(.*)$') {
            $command = $matches[1].Trim('"')
            $arguments = $matches[2]
        }
        try {
            $startArgs = @{}
            if ($arguments) { $startArgs['ArgumentList'] = $arguments }
            $process = Start-Process -FilePath $command -PassThru -ErrorAction Stop @startArgs
            $process.WaitForExit(120000) | Out-Null
            $removed++
            $details.Add(("[OK] {0}: disinstallatore ufficiale eseguito (exit {1})." -f $product.Name, $process.ExitCode))
        } catch {
            $details.Add(("[ERRORE] {0}: {1}" -f $product.Name, $_.Exception.Message))
        }
    }

    if (-not $Execute) {
        return [pscustomobject]@{
            Success = $true
            Message = ("Piano di rimozione Office pronto: {0} prodotti rilevati. Eseguire con -Execute per lanciare i disinstallatori ufficiali." -f $info.ProductCount)
            Details = @($details.ToArray())
        }
    }

    Write-Log -Message ("Rimozione Office eseguita su {0} prodotti." -f $removed) -Level 'INFO'
    return [pscustomobject]@{
        Success = ($removed -gt 0)
        Message = ("Rimozione Office completata su {0} prodotti con il disinstallatore ufficiale." -f $removed)
        Details = @($details.ToArray())
    }
}
