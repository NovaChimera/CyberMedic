# CyberMedic - Modulo Core: aggiornamenti (Winget, driver, coda sequenziale).
# Caricato da CyberMedic_Core.ps1 tramite dot-sourcing.

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

function ConvertTo-WingetUpgradeItem {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Line)
    $text = $Line.Trim()
    if (-not $text) { return $null }
    $matches = [regex]::Matches($text, '(?<![A-Za-z0-9])(?<id>[A-Za-z0-9][A-Za-z0-9+._-]*\.[A-Za-z0-9][A-Za-z0-9+._-]*)')
    $id = ''
    $idIndex = -1
    foreach ($match in $matches) {
        $candidate = $match.Groups['id'].Value
        $segments = @($candidate.Split('.'))
        $hasLetter = @($segments | Where-Object { $_ -match '[A-Za-z]' }).Count -gt 0
        if ($hasLetter -and $segments.Count -ge 2) {
            $id = $candidate
            $idIndex = $match.Index
            break
        }
    }
    if (-not $id) { return $null }
    $name = $text.Substring(0, $idIndex).Trim()
    if (-not $name) { $name = $id }
    $tail = $text.Substring($idIndex + $id.Length).Trim()
    $tokens = @($tail -split '\s+' | Where-Object { $_.Trim() })
    $source = ''
    if ($tokens.Count -gt 0 -and $tokens[-1] -match '^(winget|msstore|store)$') {
        $source = $tokens[-1]
        $tokens = @($tokens[0..($tokens.Count - 2)])
    }
    $version = ''
    $available = ''
    if ($tokens.Count -eq 1) {
        $version = $tokens[0]
    } elseif ($tokens.Count -gt 1) {
        $available = $tokens[-1]
        $version = ($tokens[0..($tokens.Count - 2)] -join ' ').Trim()
    }
    return [pscustomobject]@{
        Name      = $name
        Id        = $id
        Version   = $version
        Available = $available
        Source    = $source
    }
}

function ConvertTo-WingetUpgradeList {
    param([Parameter(Mandatory = $false)][AllowEmptyString()][string]$Text)
    $items = New-Object System.Collections.Generic.List[object]
    if ([string]::IsNullOrWhiteSpace($Text)) { return $items }
    $inTable = $false
    foreach ($line in ($Text -split "`r?`n")) {
        $trimmed = $line.Trim()
        if (-not $trimmed) { continue }
        if (-not $inTable) {
            if ($trimmed -match '^-{10,}$') { $inTable = $true }
            continue
        }
        if ($trimmed -match '^-{10,}$') { continue }
        $item = ConvertTo-WingetUpgradeItem -Line $trimmed
        if ($item) { $items.Add($item) }
    }
    return $items
}

function Get-WingetUpgradeListCommand {
    $winget = Get-Command -Name 'winget' -ErrorAction SilentlyContinue
    if (-not $winget) { return $null }
    return [pscustomobject]@{
        FilePath  = $winget.Source
        Arguments = @('upgrade', '--accept-source-agreements')
        Label     = 'winget upgrade'
    }
}

function Get-WingetUpgradeAllCommand {
    $winget = Get-Command -Name 'winget' -ErrorAction SilentlyContinue
    if (-not $winget) { return $null }
    return [pscustomobject]@{
        FilePath  = $winget.Source
        Arguments = @('upgrade', '--all', '--accept-source-agreements', '--accept-package-agreements')
        Label     = 'winget upgrade --all'
    }
}

function Get-WingetUpgradeIdCommand {
    param([Parameter(Mandatory = $true)][string]$Id)
    $winget = Get-Command -Name 'winget' -ErrorAction SilentlyContinue
    if (-not $winget) { return $null }
    return [pscustomobject]@{
        FilePath  = $winget.Source
        Arguments = @('upgrade', '--id', ('"{0}"' -f $Id), '--accept-source-agreements', '--accept-package-agreements')
        Label     = ('winget upgrade --id {0}' -f $Id)
    }
}

function Get-WingetUpgradeList {
    $command = Get-WingetUpgradeListCommand
    if (-not $command) { return @() }
    try {
        $output = & $command.FilePath @($command.Arguments) 2>&1 | Out-String
        return (ConvertTo-WingetUpgradeList -Text $output)
    } catch {
        Write-Log -Message ("Elenco aggiornamenti winget non riuscito: {0}" -f $_.Exception.Message) -Level 'ERROR'
        return @()
    }
}

function Update-WingetAllPackages {
    $command = Get-WingetUpgradeAllCommand
    if (-not $command) { return 'Errore durante l''aggiornamento globale con Winget: winget non installato su questa postazione.' }
    try {
        $output = & $command.FilePath @($command.Arguments) 2>&1 | Out-String
        return $output
    } catch {
        return ("Errore durante l'aggiornamento globale con Winget: {0}" -f $_.Exception.Message)
    }
}

function Update-WingetSelectedIds {
    param([Parameter(Mandatory = $true)][string[]]$Ids)
    $results = New-Object System.Collections.Generic.List[string]
    if (-not $Ids -or $Ids.Count -eq 0) { return $results }
    foreach ($id in $Ids) {
        $command = Get-WingetUpgradeIdCommand -Id $id
        if (-not $command) {
            $results.Add(("[{0}] winget non installato." -f $id))
            continue
        }
        try {
            $output = & $command.FilePath @($command.Arguments) 2>&1 | Out-String
            $results.Add(("[{0}]`r`n{1}" -f $id, $output.TrimEnd()))
        } catch {
            $results.Add(("[{0}] Errore: {1}" -f $id, $_.Exception.Message))
        }
    }
    return $results
}

function Get-WingetList {
    return @(Get-WingetUpgradeList)
}

function Get-WingetUpgradePackageCommand {
    param([Parameter(Mandatory = $true)][string]$Id)
    return (Get-WingetUpgradeIdCommand -Id $Id)
}

function Update-SingleWingetPackageSilently {
    param([Parameter(Mandatory = $true)][string]$Id)
    $command = Get-WingetUpgradeIdCommand -Id $Id
    if (-not $command) {
        return [pscustomobject]@{
            Success = $false
            Id      = $Id
            Message = 'winget non installato su questa postazione.'
            Output  = ''
        }
    }
    $arguments = @($command.Arguments) + @('--silent', '--disable-interactivity')
    try {
        $output = & $command.FilePath @arguments 2>&1 | Out-String
        $success = ($LASTEXITCODE -eq 0)
        return [pscustomobject]@{
            Success = $success
            Id      = $Id
            Message = $(if ($success) { ("Pacchetto {0} aggiornato." -f $Id) } else { ("Aggiornamento di {0} terminato con codice {1}." -f $Id, $LASTEXITCODE) })
            Output  = $output
        }
    } catch {
        Write-Log -Message ("Aggiornamento silenzioso di {0} non riuscito: {1}" -f $Id, $_.Exception.Message) -Level 'ERROR'
        return [pscustomobject]@{
            Success = $false
            Id      = $Id
            Message = ("Aggiornamento di {0} non riuscito: {1}" -f $Id, $_.Exception.Message)
            Output  = ''
        }
    }
}

function Update-WingetPackageSilently {
    param([Parameter(Mandatory = $true)][string]$Id)
    return (Update-SingleWingetPackageSilently -Id $Id)
}

function Get-SystemDriversList {
    $driverList = New-Object System.Collections.Generic.List[object]
    $problemCount = 0
    $scanned = 0
    try {
        $entities = @(Get-CimInstance Win32_PnPEntity -ErrorAction Stop)
        $scanned = $entities.Count
        $problems = @($entities | Where-Object { $_.ConfigManagerErrorCode -ne 0 } | Select-Object -First 25)
        $problemCount = $problems.Count
        foreach ($dev in $problems) {
            $driverList.Add([pscustomobject]@{
                Name     = $dev.Name
                Id       = $dev.DeviceID
                Status   = 'Problema riscontrato'
                ErrorCode = $dev.ConfigManagerErrorCode
                Problem  = $true
            })
        }
        if ($driverList.Count -eq 0) {
            $driverList.Add([pscustomobject]@{
                Name      = 'Driver di sistema (verificati)'
                Id        = 'System.Drivers.General'
                Status    = 'OK'
                ErrorCode = 0
                Problem   = $false
            })
        }
    } catch {
        Write-Log -Message ("Lettura dei driver di sistema non riuscita: {0}" -f $_.Exception.Message) -Level 'ERROR'
    }
    $summary = ("Dispositivi analizzati: {0} | problemi rilevati: {1} | driver in elenco: {2}" -f $scanned, $problemCount, $driverList.Count)
    return [pscustomobject]@{
        Devices      = @($driverList.ToArray())
        TotalCount   = $scanned
        ProblemCount = $problemCount
        ListedCount  = $driverList.Count
        Summary      = $summary
    }
}

function Add-QueuedTask {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [string]$Tag = '',
        [Parameter(Mandatory = $true)][scriptblock]$OnComplete
    )
    $task = [pscustomobject]@{
        Id        = ([guid]::NewGuid().ToString('N').Substring(0, 8))
        Label     = $Label
        Tag       = $Tag
        FilePath  = $FilePath
        Arguments = @($Arguments)
        OnComplete = $OnComplete
        State     = 'In coda'
        ExitCode  = $null
        Output    = ''
        Started   = $null
        Finished  = $null
    }
    $script:TaskQueue.Add($task)
    try { [void](Start-NextQueuedTask) } catch { }
    return $task
}

function Get-QueuedTask {
    return @($script:TaskQueue.ToArray())
}

function Clear-QueuedTask {
    foreach ($task in @($script:TaskQueue.ToArray())) {
        if ($task.State -eq 'In esecuzione') { continue }
        $script:TaskQueue.Remove($task)
    }
}

function Start-NextQueuedTask {
    if ($script:PendingCommands.Count -gt 0) { return $false }
    if ($script:TaskQueue.Count -eq 0) { return $false }
    $task = $script:TaskQueue[0]
    if (-not $task -or $task.State -eq 'In esecuzione') { return $false }
    $task.State = 'In esecuzione'
    $task.Started = Get-Date
    try {
        [void](Start-BackgroundCommand -FilePath $task.FilePath -Arguments $task.Arguments -OnComplete {
            param($text, $exitCode, $cmdArgs)
            $current = $null
            if ($script:TaskQueue.Count -gt 0) { $current = $script:TaskQueue[0] }
            if ($current) {
                $current.State = 'Completato'
                $current.ExitCode = $exitCode
                $current.Output = $text
                $current.Finished = Get-Date
                try { & $current.OnComplete $text $exitCode $cmdArgs $current } catch {
                    Write-Log -Message ("Callback del task '{0}' non riuscito: {1}" -f $current.Label, $_.Exception.Message) -Level 'WARN'
                }
                $script:TaskQueue.RemoveAt(0)
            }
            try { [void](Start-NextQueuedTask) } catch { }
        })
    } catch {
        $task.State = 'Errore'
        $task.Finished = Get-Date
        Write-Log -Message ("Task '{0}' non avviabile: {1}" -f $task.Label, $_.Exception.Message) -Level 'ERROR'
        if ($script:TaskQueue.Count -gt 0 -and $script:TaskQueue[0] -eq $task) { $script:TaskQueue.RemoveAt(0) }
        return (Start-NextQueuedTask)
    }
    return $true
}
