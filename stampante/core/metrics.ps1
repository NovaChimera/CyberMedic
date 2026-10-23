# CyberMedic - Modulo Core: metriche di sistema (CPU, RAM, disco, termica, SMART).
# Caricato da CyberMedic_Core.ps1 tramite dot-sourcing.

# Cache temporizzata: il monitoraggio aggiorna le metriche ogni 2 secondi,
# ma termica e SMART sono query costose (WMI) e non cambiano ogni 2 secondi.
$script:ThermalCache = $null
$script:ThermalCacheAt = $null
$script:DiskCache = $null
$script:DiskCacheAt = $null

function Get-CachedThermalState {
    param([int]$TtlSeconds = 60)
    $now = Get-Date
    if ($script:ThermalCache -and $script:ThermalCacheAt -and (($now - $script:ThermalCacheAt).TotalSeconds -lt $TtlSeconds)) {
        return $script:ThermalCache
    }
    $value = Get-ThermalState
    $script:ThermalCache = $value
    $script:ThermalCacheAt = $now
    return $value
}

function Get-CachedDiskHealth {
    param([int]$TtlSeconds = 60)
    $now = Get-Date
    if ($script:DiskCache -and $script:DiskCacheAt -and (($now - $script:DiskCacheAt).TotalSeconds -lt $TtlSeconds)) {
        return $script:DiskCache
    }
    $value = Get-DiskHealth
    $script:DiskCache = $value
    $script:DiskCacheAt = $now
    return $value
}

# Contatore di carico della CPU: il PerformanceCounter e' istantaneo, mentre
# Win32_Processor richiede circa 1,5 secondi. Se il contatore non e'
# disponibile (nomi localizzati, permessi) si ripiega su WMI.
$script:CpuCounter = $null

function Get-CpuLoadPercent {
    if (-not $script:CpuCounter) {
        try {
            $counter = New-Object System.Diagnostics.PerformanceCounter('Processor', '% Processor Time', '_total')
            [void]$counter.NextValue()
            Start-Sleep -Milliseconds 200
            $script:CpuCounter = $counter
        } catch {
            $script:CpuCounter = $null
        }
    }
    if ($script:CpuCounter) {
        try { return [int][Math]::Round($script:CpuCounter.NextValue()) } catch { $script:CpuCounter = $null }
    }
    try {
        $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
        if ($cpu) { return [int]$cpu.LoadPercentage }
    } catch { }
    return 0
}

function Get-ActiveNetworkAdapter {
    try {
        foreach ($adapter in [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
            if ($adapter.OperationalStatus -eq [System.Net.NetworkInformation.OperationalStatus]::Up) {
                return [string]$adapter.Name
            }
        }
    } catch { }
    return $null
}

function Get-ResourceMetrics {
    $m = [pscustomobject]@{
        CPUUsage       = 0
        CPUDanger      = $false
        CpuCores       = 0
        RAMTotalGB     = 0
        RAMUsedGB      = 0
        RAMUsagePct    = 0
        RAMDanger      = $false
        DiskTotalGB    = 0
        DiskFreeGB     = 0
        DiskUsagePct   = 0
        DiskDanger     = $false
        GPUInfo        = 'N/D'
        NetStatus      = 'Connesso'
        NetAdapter     = 'N/D'
        NetDanger      = $false
        TemperatureC   = $null
        ThermalState   = 'N/D'
        ThermalThrottling = $false
        DiskHealth     = 'N/D'
        DiskHealthText = ''
        Timestamp      = Get-Date
    }
    try {
        $m.CPUUsage = Get-CpuLoadPercent
        $m.CpuCores = [int][Environment]::ProcessorCount
        if ($m.CPUUsage -gt 85) { $m.CPUDanger = $true }
    } catch { }
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        if ($os) {
            $tot = [Math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
            $fre = [Math]::Round($os.FreePhysicalMemory / 1MB, 2)
            $usd = [Math]::Round($tot - $fre, 2)
            $m.RAMTotalGB = $tot
            $m.RAMUsedGB = $usd
            $m.RAMUsagePct = [Math]::Round(($usd / $tot) * 100, 1)
            if ($m.RAMUsagePct -gt 90) { $m.RAMDanger = $true }
        }
    } catch { }
    try {
        $dsk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
        if ($dsk) {
            $dtot = [Math]::Round($dsk.Size / 1GB, 2)
            $dfre = [Math]::Round($dsk.FreeSpace / 1GB, 2)
            $duse = [Math]::Round((($dtot - $dfre) / $dtot) * 100, 1)
            $m.DiskTotalGB = $dtot
            $m.DiskFreeGB = $dfre
            $m.DiskUsagePct = $duse
            if ($duse -gt 90) { $m.DiskDanger = $true }
        }
    } catch { }
    try {
        $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1 -ErrorAction Stop
        if ($gpu) { $m.GPUInfo = $gpu.Name }
    } catch { }
    try {
        $adapter = Get-ActiveNetworkAdapter
        if (-not $adapter) {
            $m.NetStatus = 'Disconnesso'
            $m.NetDanger = $true
        } else {
            $m.NetAdapter = $adapter
        }
    } catch { }
    try {
        $thermal = Get-CachedThermalState
        if ($thermal.Available) {
            $m.TemperatureC = $thermal.TemperatureC
            $m.ThermalState = $thermal.Severity
            $m.ThermalThrottling = $thermal.Throttling
        }
    } catch { }
    try {
        $disks = Get-CachedDiskHealth
        if ($disks -and $disks.Disks.Count -gt 0) {
            $m.DiskHealth = $disks.OverallHealth
            $m.DiskHealthText = $disks.Summary
        }
    } catch { }
    return $m
}

function Get-ThermalState {
    $result = [pscustomobject]@{
        Available    = $false
        Zone         = 'N/D'
        TemperatureC = $null
        CriticalC    = $null
        Throttling   = $false
        Severity     = 'N/D'
        Source       = 'Sensore termico ACPI non disponibile su questa postazione'
    }
    try {
        $zones = @(Get-CimInstance -Namespace 'root/wmi' -ClassName 'MSAcpi_ThermalZoneTemperature' -ErrorAction Stop)
        if ($zones.Count -eq 0) { return $result }
        $zone = $zones | Sort-Object -Property CurrentTemperature -Descending | Select-Object -First 1
        if (-not $zone) { return $result }
        $temperature = [double]($zone.CurrentTemperature / 10.0) - 273.15
        $critical = $null
        foreach ($trip in $zones) {
            if ($null -ne $trip.CriticalTripPoint -and $trip.CriticalTripPoint -ne 0) {
                $critical = [double]($trip.CriticalTripPoint / 10.0) - 273.15
                break
            }
        }
        $result.Available = $true
        $result.Zone = [string]$zone.InstanceName
        $result.TemperatureC = [Math]::Round($temperature, 1)
        if ($null -ne $critical) { $result.CriticalC = [Math]::Round($critical, 1) }
        $result.Source = 'ACPI thermal zone (root/wmi)'
        if ($null -ne $critical -and $critical -gt 0) {
            $ratio = $temperature / $critical
            $result.Throttling = ($ratio -ge 0.9)
            $result.Severity = if ($ratio -ge 0.95) { 'Critica' } elseif ($ratio -ge 0.85) { 'Alta' } elseif ($ratio -ge 0.7) { 'Media' } else { 'Normale' }
        } else {
            $result.Severity = if ($temperature -ge 80) { 'Alta' } elseif ($temperature -ge 65) { 'Media' } else { 'Normale' }
            $result.Throttling = ($temperature -ge 85)
        }
    } catch {
        Write-Log -Message ("Rilevamento termico non riuscito: {0}" -f $_.Exception.Message) -Level 'DEBUG'
    }
    return $result
}

function Get-DiskHealth {
    $diskList = New-Object System.Collections.Generic.List[object]
    $source = 'N/D'
    try {
        $physical = @(Get-PhysicalDisk -ErrorAction Stop)
        foreach ($disk in $physical) {
            $reliability = $null
            try { $reliability = Get-StorageReliabilityCounter -PhysicalDisk $disk -ErrorAction Stop } catch { }
            $temperature = $null
            $wear = $null
            $powerOn = $null
            $readErrors = $null
            if ($reliability) {
                if ($null -ne $reliability.Temperature) { $temperature = [int]$reliability.Temperature }
                if ($null -ne $reliability.Wear) { $wear = [int]$reliability.Wear }
                if ($null -ne $reliability.PowerOnHours) { $powerOn = [int]$reliability.PowerOnHours }
                if ($null -ne $reliability.ReadErrorsTotal) { $readErrors = [int64]$reliability.ReadErrorsTotal }
            }
            $diskList.Add([pscustomobject]@{
                Name            = [string]$disk.FriendlyName
                Serial          = [string]$disk.SerialNumber
                MediaType       = [string]$disk.MediaType
                SizeGB          = [Math]::Round(([double]$disk.Size / 1GB), 1)
                Health          = [string]$disk.HealthStatus
                Operational     = (@($disk.OperationalStatus) -join ', ')
                TemperatureC    = $temperature
                WearPercent     = $wear
                PowerOnHours    = $powerOn
                ReadErrorsTotal = $readErrors
                Source          = 'Get-PhysicalDisk / Storage'
            })
        }
        if ($diskList.Count -gt 0) { $source = 'Get-PhysicalDisk / Storage' }
    } catch {
        Write-Log -Message ("Stato SMART via Storage non disponibile: {0}" -f $_.Exception.Message) -Level 'DEBUG'
    }
    if ($diskList.Count -eq 0) {
        try {
            foreach ($drive in @(Get-CimInstance Win32_DiskDrive -ErrorAction Stop)) {
                $diskList.Add([pscustomobject]@{
                    Name            = [string]$drive.Model
                    Serial          = ([string]$drive.SerialNumber).Trim()
                    MediaType       = 'N/D'
                    SizeGB          = [Math]::Round(([double]$drive.Size / 1GB), 1)
                    Health          = [string]$drive.Status
                    Operational     = [string]$drive.Status
                    TemperatureC    = $null
                    WearPercent     = $null
                    PowerOnHours    = $null
                    ReadErrorsTotal = $null
                    Source          = 'Win32_DiskDrive (fallback)'
                })
            }
            $source = 'Win32_DiskDrive (fallback)'
        } catch { }
    }
    $healthy = 0
    $problems = 0
    foreach ($disk in $diskList) {
        if ($disk.Health -match 'Healthy|OK|N/D' -or -not $disk.Health) { $healthy++ } else { $problems++ }
    }
    $overall = if ($diskList.Count -eq 0) { 'N/D' } elseif ($problems -eq 0) { 'Sano' } else { 'Attenzione' }
    $summary = if ($diskList.Count -eq 0) {
        'Nessun disco rilevato'
    } else {
        ("Dischi: {0} | sani: {1} | con anomalia: {2} | sorgente: {3}" -f $diskList.Count, $healthy, $problems, $source)
    }
    return [pscustomobject]@{
        Disks         = @($diskList.ToArray())
        Count         = $diskList.Count
        HealthyCount  = $healthy
        ProblemCount  = $problems
        OverallHealth = $overall
        Summary       = $summary
        Source        = $source
    }
}
