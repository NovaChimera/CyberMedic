# CyberMedic - Modulo Core: posta e Outlook (SCANPST, archivi PST/OST).
# Caricato da CyberMedic_Core.ps1 tramite dot-sourcing.

function Get-OutlookInstallation {
    $scanpstPaths = @(
        (Join-Path -Path $env:ProgramFiles -ChildPath 'Microsoft Office\root\Office16\SCANPST.EXE'),
        (Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'Microsoft Office\root\Office16\SCANPST.EXE'),
        (Join-Path -Path $env:ProgramFiles -ChildPath 'Microsoft Office\Office16\SCANPST.EXE'),
        (Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'Microsoft Office\Office16\SCANPST.EXE')
    )
    $scanpst = $null
    foreach ($p in $scanpstPaths) {
        if ($p -and (Test-Path -LiteralPath $p -PathType Leaf)) { $scanpst = $p; break }
    }
    $outlookPaths = @(
        (Join-Path -Path $env:ProgramFiles -ChildPath 'Microsoft Office\root\Office16\OUTLOOK.EXE'),
        (Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'Microsoft Office\root\Office16\OUTLOOK.EXE')
    )
    $outlook = $null
    foreach ($p in $outlookPaths) {
        if ($p -and (Test-Path -LiteralPath $p -PathType Leaf)) { $outlook = $p; break }
    }
    $pstFiles = New-Object System.Collections.Generic.List[string]
    $pstRoots = @(
        (Join-Path -Path $env:APPDATA -ChildPath 'Microsoft\Outlook'),
        (Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Microsoft\Outlook')
    )
    foreach ($root in $pstRoots) {
        if (-not $root) { continue }
        try {
            if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
            foreach ($file in @(Get-ChildItem -LiteralPath $root -Filter '*.pst' -File -ErrorAction SilentlyContinue)) {
                $pstFiles.Add($file.FullName)
            }
        } catch { }
    }
    $ostFiles = New-Object System.Collections.Generic.List[string]
    $ostRoots = @(
        (Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Microsoft\Outlook\RoamCache')
    )
    foreach ($root in $ostRoots) {
        if (-not $root) { continue }
        try {
            if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
            foreach ($file in @(Get-ChildItem -LiteralPath $root -Filter '*.ost' -File -ErrorAction SilentlyContinue)) {
                $ostFiles.Add($file.FullName)
            }
        } catch { }
    }
    return [pscustomobject]@{
        Found       = [bool]$scanpst
        Path        = $scanpst
        Name        = 'SCANPST.EXE'
        OutlookFound = [bool]$outlook
        OutlookPath  = $outlook
        PstFiles     = @($pstFiles.ToArray())
        PstCount     = $pstFiles.Count
        OstFiles     = @($ostFiles.ToArray())
        OstCount     = $ostFiles.Count
    }
}

function Invoke-OutlookScanPst {
    param([Parameter(Mandatory = $false)][AllowEmptyString()][string]$PstPath)
    $installation = Get-OutlookInstallation
    if (-not $installation.Found) {
        return [pscustomobject]@{
            Success = $false
            Message = 'SCANPST non installato su questa postazione.'
            Path    = $null
        }
    }
    $arguments = @()
    if (-not [string]::IsNullOrWhiteSpace($PstPath)) {
        if (-not (Test-Path -LiteralPath $PstPath -PathType Leaf)) {
            return [pscustomobject]@{
                Success = $false
                Message = ("File PST non trovato: {0}" -f $PstPath)
                Path    = $PstPath
            }
        }
        $arguments = @(('"{0}"' -f $PstPath))
    }
    try {
        if ($arguments.Count -gt 0) {
            Start-Process -FilePath $installation.Path -ArgumentList $arguments -ErrorAction Stop | Out-Null
        } else {
            Start-Process -FilePath $installation.Path -ErrorAction Stop | Out-Null
        }
        $message = if ($arguments.Count -gt 0) {
            ("SCANPST avviato su {0}" -f $PstPath)
        } else {
            ("SCANPST avviato: {0}" -f $installation.Path)
        }
        Write-Log -Message $message -Level 'OK'
        return [pscustomobject]@{
            Success = $true
            Message = $message
            Path    = $installation.Path
        }
    } catch {
        Write-Log -Message ("Avvio SCANPST non riuscito: {0}" -f $_.Exception.Message) -Level 'ERROR'
        return [pscustomobject]@{
            Success = $false
            Message = ("Avvio SCANPST non riuscito: {0}" -f $_.Exception.Message)
            Path    = $installation.Path
        }
    }
}

function Sync-OutlookArchive {
    param([Parameter(Mandatory = $false)][AllowEmptyString()][string]$PstPath)
    $installation = Get-OutlookInstallation
    if (-not $installation.OutlookFound) {
        return [pscustomobject]@{
            Success = $false
            Message = 'Outlook non installato su questa postazione.'
        }
    }
    if ([string]::IsNullOrWhiteSpace($PstPath)) {
        try {
            Start-Process -FilePath $installation.OutlookPath -ErrorAction Stop | Out-Null
            $message = 'Outlook avviato.'
            Write-Log -Message $message -Level 'OK'
            return [pscustomobject]@{ Success = $true; Message = $message }
        } catch {
            return [pscustomobject]@{ Success = $false; Message = ("Avvio di Outlook non riuscito: {0}" -f $_.Exception.Message) }
        }
    }
    if (-not (Test-Path -LiteralPath $PstPath -PathType Leaf)) {
        return [pscustomobject]@{
            Success = $false
            Message = ("Archivio non trovato: {0}" -f $PstPath)
        }
    }
    try {
        Start-Process -FilePath $installation.OutlookPath -ArgumentList @(('"{0}"' -f $PstPath)) -ErrorAction Stop | Out-Null
        $message = ("Sincronizzazione avviata su {0}" -f (Split-Path -Path $PstPath -Leaf))
        Write-Log -Message $message -Level 'OK'
        return [pscustomobject]@{ Success = $true; Message = $message }
    } catch {
        return [pscustomobject]@{
            Success = $false
            Message = ("Sincronizzazione non riuscita: {0}" -f $_.Exception.Message)
        }
    }
}

function Repair-OutlookCache {
    $cachePath = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Microsoft\Outlook\RoamCache'
    if (-not (Test-Path -LiteralPath $cachePath -PathType Container)) {
        return [pscustomobject]@{
            Success = $false
            Message = ("Cache di Outlook non presente: {0}" -f $cachePath)
        }
    }
    $running = @(Get-Process -Name 'OUTLOOK' -ErrorAction SilentlyContinue)
    if ($running.Count -gt 0) {
        return [pscustomobject]@{
            Success = $false
            Message = 'Chiudere Outlook prima di ricostruire la cache.'
        }
    }
    $stamp = (Get-Date -Format 'yyyyMMdd-HHmmss')
    $backupPath = ("{0}.bak-{1}" -f $cachePath, $stamp)
    try {
        Rename-Item -LiteralPath $cachePath -NewName (Split-Path -Path $backupPath -Leaf) -ErrorAction Stop
        $message = ("Cache di Outlook spostata in {0}" -f (Split-Path -Path $backupPath -Leaf))
        Write-Log -Message $message -Level 'OK'
        return [pscustomobject]@{
            Success = $true
            Message = $message
            Backup  = $backupPath
        }
    } catch {
        return [pscustomobject]@{
            Success = $false
            Message = ("Ricostruzione della cache non riuscita: {0}" -f $_.Exception.Message)
        }
    }
}

function Get-OutlookArchiveReport {
    $installation = Get-OutlookInstallation
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('=== ARCHIVI DI POSTA ===')
    $lines.Add(("SCANPST     : {0}" -f $(if ($installation.Found) { $installation.Path } else { 'non installato' })))
    $lines.Add(("Outlook     : {0}" -f $(if ($installation.OutlookFound) { $installation.OutlookPath } else { 'non rilevato' })))
    $lines.Add(("Archivi PST : {0}" -f $installation.PstCount))
    $lines.Add(("Archivi OST : {0}" -f $installation.OstCount))
    foreach ($file in @($installation.PstFiles)) {
        $info = Get-Item -LiteralPath $file -ErrorAction SilentlyContinue
        $size = 'N/D'
        $stamp = 'N/D'
        if ($info) {
            $size = ('{0:N1} MB' -f ($info.Length / 1MB))
            $stamp = $info.LastWriteTime.ToString('dd/MM/yyyy HH:mm')
        }
        $lines.Add(("  PST  {0,-32} {1,10}  {2}" -f (Split-Path -Path $file -Leaf), $size, $stamp))
    }
    foreach ($file in @($installation.OstFiles)) {
        $info = Get-Item -LiteralPath $file -ErrorAction SilentlyContinue
        $size = 'N/D'
        $stamp = 'N/D'
        if ($info) {
            $size = ('{0:N1} MB' -f ($info.Length / 1MB))
            $stamp = $info.LastWriteTime.ToString('dd/MM/yyyy HH:mm')
        }
        $lines.Add(("  OST  {0,-32} {1,10}  {2}" -f (Split-Path -Path $file -Leaf), $size, $stamp))
    }
    return ($lines -join [Environment]::NewLine)
}
