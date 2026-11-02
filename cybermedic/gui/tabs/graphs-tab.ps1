# gui\tabs\graphs-tab.ps1
# Grafici CPU / RAM / Disco C: disegnati con System.Drawing (il controllo Chart non esiste in PS7).

if (-not $script: TabControl) { throw 'TabControl del tema non trovato.' }

function New-CmLiveGraph {
    param(
        [string]$Title,
        [System.Drawing.Color]$LineColor,
        [int]$Points = 60,
        [int]$Width = 430,
        [int]$Height = 150
    )
    $p = [System.Windows.Forms.Panel]::new()
    $p.Size = [System.Drawing.Size]::new($Width, $Height)
    $p.BackColor = $script: BgTerminal
    $p.Margin = [System.Windows.Forms.Padding]::new(8)
    [System.Windows.Forms.Panel].GetProperty('DoubleBuffered',
        [System.Reflection.BindingFlags]'Instance,NonPublic').SetValue($p, $true)
    $p.Tag = @{ Title = $Title; Color = $LineColor; Max = $Points
            Values = [System.Collections.Generic.List[double]]::new() }

    $p.Add_Paint({
        param($s, $e)
        $g = $e.Graphics
        $t = $s.Tag
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $w = $s.ClientSize.Width
        $h = $s.ClientSize.Height

        $gridPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(40, 255, 255, 255))
        foreach ($f in 0.25, 0.5, 0.75) {
            $y = [single]($h * $f)
            $g.DrawLine($gridPen, [single]0, $y, [single]$w, $y)
        }
        $gridPen.Dispose()

        $vals = $t.Values
        if ($vals.Count -ge 2) {
            $step = $w / [double]($t.Max - 1)
            $pts = [System.Collections.Generic.List[System.Drawing.PointF]]::new()
            for ($i = 0; $i -lt $vals.Count; $i++) {
                $x = [single]($w - ($vals.Count - 1 - $i) * $step)
                $y = [single]($h - ($vals[$i] / 100.0) * ($h - 26) - 2)
                $pts.Add([System.Drawing.PointF]::new($x, $y))
            }
            $pen = [System.Drawing.Pen]::new($t.Color, 2)
            $g.DrawLines($pen, $pts.ToArray())
            $pen.Dispose()
        }

        $last = if ($vals.Count) { $vals[$vals.Count - 1] } else { 0 }
        $font = [System.Drawing.Font]::new('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
        $brush = [System.Drawing.SolidBrush]::new($t.Color)
        $g.DrawString(('{0}   {1:N0}%' -f $t.Title, $last), $font, $brush, [single]6, [single]4)
        $font.Dispose(); $brush.Dispose()
    })
    return $p
}

function Add-CmGraphValue {
    param($Panel, [double]$Value)
    $v = $Panel.Tag.Values
    $v.Add([Math]::Max(0, [Math]::Min(100, $Value)))
    while ($v.Count -gt $Panel.Tag.Max) { $v.RemoveAt(0) }
    $Panel.Invalidate()
}

function Get-CmCpuPercent {
    [double](Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'").PercentProcessorTime
}
function Get-CmRamPercent {
    $o = Get-CimInstance Win32_OperatingSystem
    100 - ($o.FreePhysicalMemory / $o.TotalVisibleMemorySize * 100)
}
function Get-CmDiskPercent {
    $d = [System.IO.DriveInfo]::new($env:SystemDrive.Substring(0, 1))
    100 - ($d.AvailableFreeSpace / $d.TotalSize * 100)
}

# --- Costruzione del tab ---
$script: TabGraphs = [System.Windows.Forms.TabPage]::new('📈 Grafici')
$script: TabGraphs.BackColor = $script: BgTabs

$flow = [System.Windows.Forms.FlowLayoutPanel]::new()
$flow.Dock = 'Fill'
$flow.BackColor = $script: BgTabs
$flow.Padding = [System.Windows.Forms.Padding]::new(10)

$script: GraphCpu  = New-CmLiveGraph -Title 'CPU'    -LineColor $script: AccentViolet
$script: GraphRam  = New-CmLiveGraph -Title 'RAM'    -LineColor $script: AccentCyan
$script: GraphDisk = New-CmLiveGraph -Title 'Disco C:' -LineColor $script: AccentGreen
[void]$flow.Controls.Add($script: GraphCpu)
[void]$flow.Controls.Add($script: GraphRam)
[void]$flow.Controls.Add($script: GraphDisk)
[void]$script: TabGraphs.Controls.Add($flow)

$script: GraphTimer = [System.Windows.Forms.Timer]::new()
$script: GraphTimer.Interval = 2000
$script: GraphTimer.Add_Tick({
    try {
        Add-CmGraphValue $script: GraphCpu  (Get-CmCpuPercent)
        Add-CmGraphValue $script: GraphRam  (Get-CmRamPercent)
        Add-CmGraphValue $script: GraphDisk (Get-CmDiskPercent)
    } catch { }
})
$script: GraphTimer.Start()
$script: MainForm.Add_FormClosed({ try { $script: GraphTimer.Stop() } catch {} })

[void]$script: TabControl.TabPages.Add($script: TabGraphs)