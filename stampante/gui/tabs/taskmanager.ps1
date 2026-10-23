# CyberMedic - Scheda modulare: Task Manager (metriche, grafici on-demand, log live).
# Caricato da CyberMedic_GUI.ps1 tramite dot-sourcing.

function New-TaskManagerTab {
    param([Parameter(Mandatory = $true)]$MainTabs)

    # SCHEDA 4 - TASK MANAGER (metriche, grafici e log live)
    # ------------------------------------------------------------------------
    $tabActivity = New-Object System.Windows.Forms.TabPage('  ⚡  Task Manager  ')
    $tabActivity.BackColor = $script:ColorBgMain
    $tabActivity.ForeColor = $script:ColorAccent
    $tabActivity.Padding = New-Object System.Windows.Forms.Padding(8)
    $mainTabs.TabPages.Add($tabActivity)

    $actBar = New-Object System.Windows.Forms.FlowLayoutPanel
    $actBar.Dock = 'Top'
    $actBar.Height = 52
    $actBar.BackColor = $script:ColorBgMain
    $actBar.Padding = New-Object System.Windows.Forms.Padding(0, 0, 0, 6)

    $btnActRefresh = New-ThemedButton -Text '⚡ Aggiorna metriche' -BackColor $script:ColorAccent -ForeColor $script:ColorBgMain
    $btnActRefresh.Add_Click({ Invoke-Safe -Context 'Aggiornamento metriche' -Action { Update-ActivityMetrics } })
    $actBar.Controls.Add($btnActRefresh)

    $btnActStart = New-ThemedButton -Text '▶ Avvia monitoraggio' -BackColor $script:ColorPanel -ForeColor $script:ColorSuccess
    $btnActStart.Add_Click({
        Invoke-Safe -Context 'Monitoraggio attivita' -Action {
            if ($script:Ui.ActivityTimer) {
                $script:Ui.ActivityTimer.Start()
                Update-StatusBar 'Monitoraggio delle risorse attivo.'
            }
        }
    })
    $actBar.Controls.Add($btnActStart)

    $btnActStop = New-ThemedButton -Text '⏸ Ferma monitoraggio' -BackColor $script:ColorPanel -ForeColor $script:ColorWarning
    $btnActStop.Add_Click({
        Invoke-Safe -Context 'Monitoraggio attivita' -Action {
            if ($script:Ui.ActivityTimer) { $script:Ui.ActivityTimer.Stop() }
            Update-StatusBar 'Monitoraggio delle risorse sospeso.'
        }
    })
    $actBar.Controls.Add($btnActStop)

    $btnActClear = New-ThemedButton -Text '🧹 Pulisci log attività' -BackColor $script:ColorPanel -ForeColor $script:ColorTextMain
    $btnActClear.Add_Click({
        Invoke-Safe -Context 'Pulizia log attivita' -Action {
            if ($script:Ui.ActivityLog) { $script:Ui.ActivityLog.Clear() }
        }
    })
    $actBar.Controls.Add($btnActClear)

    # --- PULSANTI DEI GRAFICI (attivazione on demand) ---------------------
    $chartButtons = New-Object System.Collections.Hashtable
    foreach ($definition in @(
        @{ Key = 'CPU'; Text = '📈 CPU' }
        @{ Key = 'RAM'; Text = '📈 RAM' }
        @{ Key = 'DISK'; Text = '📈 Disco' }
    )) {
        $key = $definition.Key
        $button = New-FluentToggleButton -Text $definition.Text -Key ('Activity.' + $key) -Width 132
        $button.Tag = $key
        $button.Add_Click({
            param($sender, $eventArgs)
            Invoke-Safe -Context ('Grafico ' + $sender.Tag) -Action { Toggle-MetricChart -Key ([string]$sender.Tag) }
        })
        $chartButtons[$key] = $button
        $actBar.Controls.Add($button)
    }

    $actSplit = New-Object System.Windows.Forms.SplitContainer
    $actSplit.Dock = 'Fill'
    $actSplit.Orientation = 'Vertical'
    $actSplit.BackColor = $script:ColorBgMain
    $actSplit.Panel1.BackColor = $script:ColorBgMain
    $actSplit.Panel2.BackColor = $script:ColorBgMain
    try { $actSplit.Panel1MinSize = 380; $actSplit.Panel2MinSize = 380 } catch { }

    $actMetrics = New-Object System.Windows.Forms.Panel
    $actMetrics.Dock = 'Fill'
    $actMetrics.BackColor = $script:ColorBgMain
    $actMetrics.Padding = New-Object System.Windows.Forms.Padding(6)

    $gaugeDisk = New-MetricGauge -Key 'DISK' -Caption 'Disco'
    $gaugeRam = New-MetricGauge -Key 'RAM' -Caption 'Memoria RAM'
    $gaugeCpu = New-MetricGauge -Key 'CPU' -Caption 'CPU'
    $actGauges = New-Object System.Windows.Forms.Panel
    $actGauges.Dock = 'Top'
    $actGauges.Height = 182
    $actGauges.BackColor = $script:ColorCardBg
    $actGauges.Controls.Add($gaugeDisk)
    $actGauges.Controls.Add($gaugeRam)
    $actGauges.Controls.Add($gaugeCpu)

    # I grafici sono creati nascosti: si attivano solo su richiesta esplicita
    # dell'utente con i pulsanti dedicati.
    $chartCpu = New-MetricHistoryChart -Key 'CPU' -Caption 'Andamento CPU (ultimi campioni)'
    $chartRam = New-MetricHistoryChart -Key 'RAM' -Caption 'Andamento memoria RAM (ultimi campioni)'
    $chartDisk = New-MetricHistoryChart -Key 'DISK' -Caption 'Andamento disco di sistema (ultimi campioni)'
    $chartCpu.Visible = $false
    $chartRam.Visible = $false
    $chartDisk.Visible = $false

    $actDetail = New-Object System.Windows.Forms.TextBox
    $actDetail.Multiline = $true
    $actDetail.ReadOnly = $true
    $actDetail.ScrollBars = 'Vertical'
    $actDetail.Dock = 'Bottom'
    $actDetail.Height = 132
    $actDetail.BackColor = $script:ColorCardBg
    $actDetail.ForeColor = $script:ColorTextMain
    $actDetail.Font = New-Object System.Drawing.Font('Consolas', 9.5)
    $actDetail.BorderStyle = 'None'

    # --- DIAGNOSTICA HARDWARE (thermal throttling e dischi SMART) --------
    $hwGroup = New-Object System.Windows.Forms.GroupBox
    $hwGroup.Text = '  🔥  Diagnostica hardware  '
    $hwGroup.Dock = 'Bottom'
    $hwGroup.Height = 188
    $hwGroup.BackColor = $script:ColorPanel
    $hwGroup.ForeColor = $script:ColorAccent
    $hwGroup.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $hwInner = New-Object System.Windows.Forms.Panel
    $hwInner.Dock = 'Fill'
    $hwInner.BackColor = $script:ColorPanel
    $hwInner.Padding = New-Object System.Windows.Forms.Padding(8, 4, 8, 4)
    $hwGroup.Controls.Add($hwInner)

    $hwReport = New-Object System.Windows.Forms.TextBox
    $hwReport.Multiline = $true
    $hwReport.ReadOnly = $true
    $hwReport.ScrollBars = 'Vertical'
    $hwReport.Dock = 'Fill'
    $hwReport.BackColor = $script:ColorCardBg
    $hwReport.ForeColor = $script:ColorSuccess
    $hwReport.Font = New-Object System.Drawing.Font('Consolas', 8.5)
    $hwReport.BorderStyle = 'None'
    $hwInner.Controls.Add($hwReport)

    $hwButton = New-ThemedButton -Text '🔄 Aggiorna diagnostica' -BackColor $script:ColorPanel -ForeColor $script:ColorTextMain
    $hwButton.Dock = 'Top'
    $hwButton.Height = 28
    $hwButton.Add_Click({
        Invoke-Safe -Context 'Diagnostica hardware' -Action { Update-HardwareDiagnostics }
    })
    $hwInner.Controls.Add($hwButton)

    # --- RIQUADRI SEPARATI PER RISORSA (CPU, RAM, DISCO, GPU) -------------
    # Un box per ogni risorsa: valori live, indipendenti l'uno dall'altro.
    $metricGrid = New-Object System.Windows.Forms.TableLayoutPanel
    $metricGrid.Dock = 'Top'
    $metricGrid.Height = 132
    $metricGrid.ColumnCount = 4
    $metricGrid.RowCount = 1
    $metricGrid.BackColor = $script:ColorBgMain
    $metricGrid.Margin = New-Object System.Windows.Forms.Padding(0)
    for ($column = 0; $column -lt 4; $column++) {
        $style = New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 25)
        [void]$metricGrid.ColumnStyles.Add($style)
    }
    [void]$metricGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))

    $metricBoxes = @{}
    foreach ($definition in @(
        @{ Key = 'CPU'; Caption = '  🖥️  CPU (processore)  ' }
        @{ Key = 'RAM'; Caption = '  🧠  Memoria RAM  ' }
        @{ Key = 'DISK'; Caption = '  💾  Disco di sistema  ' }
        @{ Key = 'GPU'; Caption = '  🎮  Scheda grafica  ' }
    )) {
        $box = New-Object System.Windows.Forms.GroupBox
        $box.Text = $definition.Caption
        $box.Dock = 'Fill'
        $box.Margin = New-Object System.Windows.Forms.Padding(3)
        $box.BackColor = $script:ColorPanel
        $box.ForeColor = $script:ColorAccent
        $box.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

        $value = New-Object System.Windows.Forms.TextBox
        $value.Multiline = $true
        $value.ReadOnly = $true
        $value.Dock = 'Fill'
        $value.BackColor = $script:ColorCardBg
        $value.ForeColor = $script:ColorSuccess
        $value.Font = New-Object System.Drawing.Font('Consolas', 9)
        $value.BorderStyle = 'None'
        $value.Text = 'in attesa...'
        $box.Controls.Add($value)

        $metricGrid.Controls.Add($box, $metricGrid.Controls.Count, 0)
        $metricBoxes[$definition.Key] = $value
    }

    $actMetrics.Controls.Add($chartCpu)
    $actMetrics.Controls.Add($chartRam)
    $actMetrics.Controls.Add($chartDisk)
    $actMetrics.Controls.Add($actGauges)
    $actMetrics.Controls.Add($metricGrid)
    $actMetrics.Controls.Add($actDetail)
    $actMetrics.Controls.Add($hwGroup)

    $actLog = New-Object System.Windows.Forms.TextBox
    $actLog.Multiline = $true
    $actLog.ReadOnly = $true
    $actLog.ScrollBars = 'Both'
    $actLog.WordWrap = $false
    $actLog.Dock = 'Fill'
    $actLog.BackColor = $script:ColorCardBg
    $actLog.ForeColor = $script:ColorTextMain
    $actLog.Font = New-Object System.Drawing.Font('Consolas', 9)
    $actLog.BorderStyle = 'None'

    $actQueue = New-Object System.Windows.Forms.TextBox
    $actQueue.Multiline = $true
    $actQueue.ReadOnly = $true
    $actQueue.ScrollBars = 'Vertical'
    $actQueue.Dock = 'Bottom'
    $actQueue.Height = 140
    $actQueue.BackColor = $script:ColorCardBg
    $actQueue.ForeColor = $script:ColorSuccess
    $actQueue.Font = New-Object System.Drawing.Font('Consolas', 9)
    $actQueue.BorderStyle = 'None'

    $actSplit.Panel1.Controls.Add($actMetrics)
    $actSplit.Panel2.Controls.Add($actLog)
    $actSplit.Panel2.Controls.Add($actQueue)

    $tabActivity.Controls.Add($actSplit)
    $tabActivity.Controls.Add($actBar)

    # ------------------------------------------------------------------------

    $script:Ui.ActivityGauges = @($gaugeCpu, $gaugeRam, $gaugeDisk)
    $script:Ui.ActivityMetricBoxes = $metricBoxes
    $script:Ui.ActivityCharts = @{
        CPU  = $chartCpu
        RAM  = $chartRam
        DISK = $chartDisk
    }
    $script:Ui.ActivityChartButtons = $chartButtons
    $script:Ui.ActivityDetail = $actDetail
    $script:Ui.ActivityLog = $actLog
    $script:Ui.ActivityQueue = $actQueue
    $script:Ui.HardwareReport = $hwReport
    Update-MetricChartButtons
    return $tabActivity
}

function New-MetricGauge {
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [Parameter(Mandatory = $true)][string]$Caption
    )
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = 'Top'
    $panel.Height = 58
    $panel.BackColor = $script:ColorCardBg
    $panel.Tag = $Key
    $panel.Add_Paint({
        param($sender, $e)
        $key = [string]$sender.Tag
        $value = 0.0
        $caption = $key
        if ($script:Activity -and $script:Activity.Metrics) {
            $m = $script:Activity.Metrics
            switch ($key) {
                'CPU' { $value = [double]$m.CPUUsage; $caption = 'CPU' }
                'RAM' { $value = [double]$m.RAMUsagePct; $caption = 'Memoria RAM' }
                'DISK' { $value = [double]$m.DiskUsagePct; $caption = 'Disco di sistema C:' }
            }
        }
        $g = $e.Graphics
        $g.Clear($script:ColorCardBg)
        $font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
        $brush = New-Object System.Drawing.SolidBrush($script:ColorTextMain)
        $g.DrawString(("{0}   {1}%" -f $caption, [int][Math]::Round($value)), $font, $brush, 8, 6)
        $font.Dispose()
        $brush.Dispose()
        $trackX = 8
        $trackY = 30
        $trackW = [Math]::Max(20, $sender.Width - 16)
        $trackH = 14
        $back = New-Object System.Drawing.SolidBrush($script:ColorBorder)
        $g.FillRectangle($back, $trackX, $trackY, $trackW, $trackH)
        $back.Dispose()
        $color = $script:ColorSuccess
        if ($value -ge 85) { $color = $script:ColorError }
        elseif ($value -ge 70) { $color = $script:ColorWarning }
        $fill = New-Object System.Drawing.SolidBrush($color)
        $fillW = [int]($trackW * [Math]::Min(100.0, [Math]::Max(0.0, $value)) / 100.0)
        $g.FillRectangle($fill, $trackX, $trackY, $fillW, $trackH)
        $fill.Dispose()
    })
    return $panel
}

function New-MetricHistoryChart {
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [Parameter(Mandatory = $true)][string]$Caption
    )
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = 'Fill'
    $panel.BackColor = $script:ColorCardBg
    $panel.Tag = $Key
    $panel.Add_Paint({
        param($sender, $e)
        $g = $e.Graphics
        $g.Clear($script:ColorCardBg)
        $key = [string]$sender.Tag
        $caption = $key
        $color = $script:ColorAccent
        switch ($key) {
            'CPU' { $caption = 'Andamento CPU (ultimi campioni)'; $color = $script:ColorAccent }
            'RAM' { $caption = 'Andamento memoria RAM (ultimi campioni)'; $color = $script:ColorSuccess }
            'DISK' { $caption = 'Andamento disco di sistema (ultimi campioni)'; $color = $script:ColorWarning }
        }
        $font = New-Object System.Drawing.Font('Segoe UI', 8.5)
        $brush = New-Object System.Drawing.SolidBrush($script:ColorTextMuted)
        $g.DrawString($caption, $font, $brush, 6, 4)
        $font.Dispose()
        $brush.Dispose()
        $history = @()
        if ($script:Activity) {
            $series = $null
            switch ($key) {
                'CPU' { $series = $script:Activity.History }
                'RAM' { $series = $script:Activity.HistoryRam }
                'DISK' { $series = $script:Activity.HistoryDisk }
            }
            if ($series) { $history = @($series.ToArray()) }
        }
        $w = $sender.Width
        $h = $sender.Height
        $axisY = $h - 12
        $axisPen = New-Object System.Drawing.Pen($script:ColorBorder, 1)
        $g.DrawLine($axisPen, 6, $axisY, $w - 6, $axisY)
        $axisPen.Dispose()
        if ($history.Count -lt 2) {
            $emptyFont = New-Object System.Drawing.Font('Segoe UI', 8.5)
            $emptyBrush = New-Object System.Drawing.SolidBrush($script:ColorTextMuted)
            $g.DrawString('In raccolta dati...', $emptyFont, $emptyBrush, 8, 22)
            $emptyFont.Dispose()
            $emptyBrush.Dispose()
            return
        }
        $step = [double]($w - 18) / ($history.Count - 1)
        $points = New-Object System.Collections.Generic.List[System.Drawing.PointF]
        for ($i = 0; $i -lt $history.Count; $i++) {
            $x = 9 + ($i * $step)
            $y = $axisY - (([double]$history[$i] / 100.0) * ($axisY - 24))
            [void]$points.Add((New-Object System.Drawing.PointF([float]$x, [float]$y)))
        }
        $pen = New-Object System.Drawing.Pen($color, 2)
        $g.DrawLines($pen, $points.ToArray())
        $pen.Dispose()
    })
    return $panel
}

function Toggle-MetricChart {
    param([Parameter(Mandatory = $true)][string]$Key)
    $charts = $script:Ui.ActivityCharts
    if (-not $charts) { return }
    $chart = $charts[$Key]
    if (-not $chart) { return }
    $wasVisible = $false
    try { $wasVisible = [bool]$chart.Visible } catch { }
    $newState = -not $wasVisible
    try {
        $chart.Visible = $newState
        $chart.Invalidate()
    } catch { }
    [void](Set-FluentToggleState -Key ('Activity.' + $Key) -On $newState)
    Update-MetricChartButtons
    Update-StatusBar ("Grafico {0} {1}." -f $Key, $(if ($newState) { 'attivato' } else { 'nascosto' }))
}

function Update-MetricChartButtons {
    $buttons = $script:Ui.ActivityChartButtons
    $charts = $script:Ui.ActivityCharts
    if (-not $buttons -or -not $charts) { return }
    foreach ($key in @($buttons.Keys)) {
        $button = $buttons[$key]
        $chart = $charts[$key]
        if (-not $button -or -not $chart) { continue }
        try {
            $visible = [bool]$chart.Visible
            [void](Set-FluentToggleState -Key ('Activity.' + $key) -On $visible)
            $button.Text = ("{0} {1}" -f $(if ($visible) { '📉' } else { '📈' }), $key)
        } catch { }
    }
}

function Update-HardwareDiagnostics {
    if (-not $script:Ui.HardwareReport) { return }
    try {
        $lines = New-Object System.Collections.Generic.List[string]
        $thermal = Get-CachedThermalState
        $lines.Add('--- THERMAL THROTTLING CPU ---')
        if ($thermal.Available) {
            $lines.Add(("Temperatura  : {0} C" -f $thermal.TemperatureC))
            $lines.Add(("Soglia crit. : {0}" -f $(if ($null -ne $thermal.CriticalC) { ("{0} C" -f $thermal.CriticalC) } else { 'N/D' })))
            $lines.Add(("Stato        : {0}" -f $thermal.Severity))
            $lines.Add(("Throttling   : {0}" -f $(if ($thermal.Throttling) { 'ATTIVO - riduzione delle prestazioni' } else { 'assente' })))
            $lines.Add(("Zona         : {0}" -f $thermal.Zone))
        } else {
            $lines.Add(("Sensore termico non disponibile: {0}" -f $thermal.Source))
            $lines.Add('La postazione non espone zone termiche ACPI interrogabili.')
        }
        $lines.Add('')
        $lines.Add('--- SALUTE DISCHI (SMART) ---')
        $disks = Get-CachedDiskHealth
        $lines.Add($disks.Summary)
        foreach ($disk in @($disks.Disks)) {
            $lines.Add(("  {0,-28} {1,7} GB  {2,-9} {3}" -f $disk.Name, $disk.SizeGB, $disk.Health, $disk.Operational))
            $extra = New-Object System.Collections.Generic.List[string]
            if ($null -ne $disk.TemperatureC) { $extra.Add(("temp {0} C" -f $disk.TemperatureC)) }
            if ($null -ne $disk.WearPercent) { $extra.Add(("usura {0}%" -f $disk.WearPercent)) }
            if ($null -ne $disk.PowerOnHours) { $extra.Add(("ore accese {0}" -f $disk.PowerOnHours)) }
            if ($null -ne $disk.ReadErrorsTotal) { $extra.Add(("errori lettura {0}" -f $disk.ReadErrorsTotal)) }
            if ($extra.Count -gt 0) { $lines.Add(("      {0}" -f ($extra -join ' | '))) }
        }
        $script:Ui.HardwareReport.Text = ($lines -join [Environment]::NewLine)
        Update-StatusBar ("Diagnostica hardware aggiornata: {0} dischi." -f $disks.Count)
    } catch {
        Write-Log -Message ("Diagnostica hardware non riuscita: {0}" -f $_.Exception.Message) -Level 'WARN'
    }
}

function Update-ActivityMetrics {
    try {
        $metrics = Get-ResourceMetrics
        $script:Activity.Metrics = $metrics
        if (-not $script:Activity.ContainsKey('HistoryRam')) { $script:Activity.HistoryRam = New-Object System.Collections.Generic.List[int] }
        if (-not $script:Activity.ContainsKey('HistoryDisk')) { $script:Activity.HistoryDisk = New-Object System.Collections.Generic.List[int] }
        [void]$script:Activity.History.Add([int]$metrics.CPUUsage)
        [void]$script:Activity.HistoryRam.Add([int]$metrics.RAMUsagePct)
        [void]$script:Activity.HistoryDisk.Add([int]$metrics.DiskUsagePct)
        while ($script:Activity.History.Count -gt 60) { $script:Activity.History.RemoveAt(0) }
        while ($script:Activity.HistoryRam.Count -gt 60) { $script:Activity.HistoryRam.RemoveAt(0) }
        while ($script:Activity.HistoryDisk.Count -gt 60) { $script:Activity.HistoryDisk.RemoveAt(0) }
        if ($script:Ui.ActivityDetail) {
            $lines = New-Object System.Collections.Generic.List[string]
            $lines.Add(('CPU          : {0}%  ({1} core logici)' -f $metrics.CPUUsage, $metrics.CpuCores))
            $lines.Add(('Memoria RAM  : {0} GB usati su {1} GB ({2}%)' -f $metrics.RAMUsedGB, $metrics.RAMTotalGB, $metrics.RAMUsagePct))
            $lines.Add(('Disco C:     : {0} GB liberi su {1} GB ({2}%)' -f $metrics.DiskFreeGB, $metrics.DiskTotalGB, $metrics.DiskUsagePct))
            $lines.Add(('GPU          : {0}' -f $metrics.GPUInfo))
            $lines.Add(('Rete         : {0} [{1}]' -f $metrics.NetStatus, $metrics.NetAdapter))
            $lines.Add(('Aggiornato   : {0}' -f $metrics.Timestamp))
            $script:Ui.ActivityDetail.Text = ($lines -join [Environment]::NewLine)
        }
        foreach ($gauge in @($script:Ui.ActivityGauges)) {
            try { $gauge.Invalidate() } catch { }
        }
        $boxes = $script:Ui.ActivityMetricBoxes
        if ($boxes) {
            try {
                $boxes['CPU'].Text = ("Utilizzo : {0}%`r`nCore    : {1}`r`nStato   : {2}" -f $metrics.CPUUsage, $metrics.CpuCores, $(if ($metrics.CPUDanger) { 'critico' } else { 'normale' }))
                $boxes['RAM'].Text = ("Totale   : {0} GB`r`nUsati    : {1} GB`r`nPercentuale: {2}%" -f $metrics.RAMTotalGB, $metrics.RAMUsedGB, $metrics.RAMUsagePct)
                $boxes['DISK'].Text = ("Totale   : {0} GB`r`nLiberi   : {1} GB`r`nUso     : {2}%" -f $metrics.DiskTotalGB, $metrics.DiskFreeGB, $metrics.DiskUsagePct)
                $boxes['GPU'].Text = ("Controller:`r`n{0}`r`n`r`nRete    : {1}" -f $metrics.GPUInfo, $metrics.NetStatus)
            } catch { }
        }
        $charts = $script:Ui.ActivityCharts
        if ($charts) {
            foreach ($name in @($charts.Keys)) {
                try { if ($charts[$name].Visible) { $charts[$name].Invalidate() } } catch { }
            }
        }
        # I grafici prestazione della scheda Updates usano la stessa serie di
        # campioni: vanno ridisegnati insieme alle metriche per non restare
        # fermi sull'ultimo valore noto.
        $updateCharts = $script:Ui.UpdateCharts
        if ($updateCharts) {
            foreach ($name in @($updateCharts.Keys)) {
                try { if ($updateCharts[$name].Visible) { $updateCharts[$name].Invalidate() } } catch { }
            }
        }
    } catch {
        Write-Log -Message ("Lettura delle metriche non riuscita: {0}" -f $_.Exception.Message) -Level 'WARN'
    }
}

function Update-ActivityLog {
    if (-not $script:Ui.ActivityLog) { return }
    try {
        $entries = @($script:LogEntries.ToArray())
        $take = 400
        if ($entries.Count -gt $take) { $entries = @($entries[($entries.Count - $take)..($entries.Count - 1)]) }
        $script:Ui.ActivityLog.Text = ($entries -join [Environment]::NewLine)
        $script:Ui.ActivityLog.SelectionStart = $script:Ui.ActivityLog.TextLength
        $script:Ui.ActivityLog.ScrollToCaret()
    } catch { }
}

function Update-ActivityQueue {
    if (-not $script:Ui.ActivityQueue) { return }
    try {
        $tasks = @(Get-QueuedTask)
        $lines = New-Object System.Collections.Generic.List[string]
        $lines.Add(('Coda operazioni: {0} attivita in attesa' -f $tasks.Count))
        foreach ($task in $tasks) {
            $detail = if ($null -ne $task.ExitCode) { "exit $($task.ExitCode)" } else { '' }
            $lines.Add(('  [{0}] {1} {2}' -f $task.State, $task.Label, $detail))
        }
        $script:Ui.ActivityQueue.Text = ($lines -join [Environment]::NewLine)
    } catch { }
}
