#Requires -Version 7.0
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

$script:Theme = @{
    BgMain        = [System.Drawing.Color]::FromArgb(15, 15, 20)
    BgTabs        = [System.Drawing.Color]::FromArgb(24, 24, 32)
    BgTerminal    = [System.Drawing.Color]::FromArgb(10, 10, 14)
    BgSidebar     = [System.Drawing.Color]::FromArgb(10, 10, 14)
    ColorPanel    = [System.Drawing.Color]::FromArgb(30, 30, 40)
    ColorBorder   = [System.Drawing.Color]::FromArgb(60, 60, 80)
    ColorAccent   = [System.Drawing.Color]::FromArgb(179, 136, 255)
    ColorTextMain = [System.Drawing.Color]::FromArgb(240, 240, 250)
    ColorTextMuted= [System.Drawing.Color]::FromArgb(160, 160, 180)
    ColorCardBg   = [System.Drawing.Color]::FromArgb(20, 20, 28)
    ColorError    = [System.Drawing.Color]::FromArgb(220, 60, 60)
    ColorSuccess  = [System.Drawing.Color]::FromArgb(50, 205, 50)
    ColorWarning  = [System.Drawing.Color]::FromArgb(240, 180, 60)
    TextPrimary   = [System.Drawing.Color]::FromArgb(240, 240, 250)
    TextSecondary = [System.Drawing.Color]::FromArgb(160, 160, 180)
    AccentViolet  = [System.Drawing.Color]::FromArgb(138, 43, 226)
    AccentBlue    = [System.Drawing.Color]::FromArgb(0, 120, 215)
    AccentCyan    = [System.Drawing.Color]::FromArgb(0, 191, 255)
    AccentGreen   = [System.Drawing.Color]::FromArgb(50, 205, 50)
    AccentRed     = [System.Drawing.Color]::FromArgb(220, 60, 60)
    FontMain      = New-Object System.Drawing.Font("Segoe UI", 9.5)
    FontBold      = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
    FontConsole   = New-Object System.Drawing.Font("Consolas", 9.5, [System.Drawing.FontStyle]::Bold)
}

$script:Colors = $script:Theme

# Backward compatibility aliases (variabili usate direttamente dal GUI)
$script:BgTabs = $script:Theme.BgTabs
$script:BgMain = $script:Theme.BgMain
$script:BgTerminal = $script:Theme.BgTerminal
$script:BgSidebar = $script:Theme.BgSidebar
$script:ColorPanel = $script:Theme.ColorPanel
$script:ColorBorder = $script:Theme.ColorBorder
$script:ColorAccent = $script:Theme.ColorAccent
$script:ColorTextMain = $script:Theme.ColorTextMain
$script:ColorTextMuted = $script:Theme.ColorTextMuted
$script:ColorCardBg = $script:Theme.ColorCardBg
$script:ColorError = $script:Theme.ColorError
$script:ColorSuccess = $script:Theme.ColorSuccess
$script:ColorWarning = $script:Theme.ColorWarning
$script:TextPrimary = $script:Theme.TextPrimary
$script:TextSecondary = $script:Theme.TextSecondary
$script:AccentViolet = $script:Theme.AccentViolet
$script:AccentBlue = $script:Theme.AccentBlue
$script:AccentCyan = $script:Theme.AccentCyan
$script:AccentGreen = $script:Theme.AccentGreen
$script:AccentRed = $script:Theme.AccentRed

function Get-FluentFont {
    param(
        [int]$Size = 9,
        [switch]$Bold
    )
    $fontName = 'Segoe UI'
    $style = [System.Drawing.FontStyle]::Regular
    if ($Bold) { $style = [System.Drawing.FontStyle]::Bold }
    if ($script:Theme -and $script:Theme.ContainsKey('FontMain')) {
        $fontName = $script:Theme.FontMain.FontFamily.Name
    }
    return New-Object System.Drawing.Font($fontName, [float]$Size, $style)
}
$script:AccentBlue = $script:Theme.AccentBlue
$script:AccentCyan = $script:Theme.AccentCyan
$script:AccentGreen = $script:Theme.AccentGreen
$script:AccentRed = $script:Theme.AccentRed
$script:TextPrimary = $script:Theme.TextPrimary
$script:TextSecondary = $script:Theme.TextSecondary

$script:MainForm = New-Object System.Windows.Forms.Form
$script:MainForm.Text = "CyberMedic - cybermedic Engine"
$script:MainForm.Size = New-Object System.Drawing.Size(1080, 720)
$script:MainForm.StartPosition = "CenterScreen"
$script:MainForm.BackColor = $script:Theme.BgMain

$script:TabControl = New-Object System.Windows.Forms.TabControl
$script:TabControl.Dock = "Fill"
$script:TabControl.DrawMode = [System.Windows.Forms.TabDrawMode]::OwnerDrawFixed
$script:TabControl.SizeMode = [System.Windows.Forms.TabSizeMode]::Fixed
$script:TabControl.ItemSize = New-Object System.Drawing.Size(140, 32)
$script:MainForm.Controls.Add($script:TabControl)

$script:TabControl.Add_DrawItem({
    param($sender, $e)
    if ($e.Index -lt 0) { return }
    $tabPage = $sender.TabPages[$e.Index]
    $isSelected = ($e.State -band [System.Windows.Forms.DrawItemState]::Selected)
    $backColor = if ($isSelected) { $script:Theme.BgTabs } else { $script:Theme.BgMain }
    $textColor = if ($isSelected) { $script:Theme.AccentViolet } else { $script:Theme.TextSecondary }
    $backBrush = New-Object System.Drawing.SolidBrush($backColor)
    $foreBrush = New-Object System.Drawing.SolidBrush($textColor)
    $e.Graphics.FillRectangle($backBrush, $e.Bounds)
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $e.Graphics.DrawString($tabPage.Text, $sender.Font, $foreBrush, [System.Drawing.RectangleF]::op_Implicit($e.Bounds), $sf)
    $backBrush.Dispose(); $foreBrush.Dispose(); $sf.Dispose()
})

function Apply-DarkThemeToControl {
    param([System.Windows.Forms.Control]$Control)
    $Control.BackColor = $script:Theme.BgTabs
    $Control.ForeColor = $script:Theme.TextPrimary
    $Control.Font = $script:Theme.FontMain
    foreach ($Child in $Control.Controls) {
        if ($Child -is [System.Windows.Forms.GroupBox]) {
            $Child.ForeColor = $script:Theme.AccentViolet
            $Child.Font = $script:Theme.FontBold
            Apply-DarkThemeToControl -Control $Child
        }
        elseif ($Child -is [System.Windows.Forms.TextBox] -or $Child -is [System.Windows.Forms.ListBox] -or $Child -is [System.Windows.Forms.ListView]) {
            $Child.BackColor = $script:Theme.BgTerminal
            $Child.ForeColor = $script:Theme.TextPrimary
            $Child.Font = $script:Theme.FontConsole
        }
        elseif ($Child -is [System.Windows.Forms.Button]) {
            $Child.BackColor = $script:Theme.BgMain
            $Child.ForeColor = $script:Theme.TextPrimary
            $Child.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
            $Child.FlatAppearance.BorderSize = 1
            $Child.FlatAppearance.BorderColor = $script:Theme.AccentViolet
        }
        else {
            $Child.ForeColor = $script:Theme.TextPrimary
            $Child.Font = $script:Theme.FontMain
        }
    }
}

$script:Tabs = @{}
$tabNames = @("Dashboard", "WingetApp", "GamingTweaks", "StrumentiIT", "Stampanti", "Cybersecurity", "Maintenance", "RegistroLog")
$tabLabels = @("Dashboard", "Winget & App", "Gaming", "Strumenti IT", "Stampanti", "Cybersecurity", "Manutenzione", "Registro Log")
for ($i = 0; $i -lt $tabNames.Count; $i++) {
    $tp = New-Object System.Windows.Forms.TabPage
    $tp.Text = $tabLabels[$i]
    $tp.BackColor = $script:Theme.BgMain
    $script:TabControl.TabPages.Add($tp)
    $script:Tabs[$tabNames[$i]] = $tp
}

function Write-PoshLog {
    param([string]$Message, [string]$Status = 'INFO')
    $line = "[$Status] $Message"
    if (-not $script:LogEntries) { $script:LogEntries = [System.Collections.Generic.List[string]]::new() }
    $script:LogEntries.Add($line)
    Write-Output $line
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function New-FluentToggleButton {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [string]$Key = '',
        [int]$Width = 132,
        [int]$Height = 38,
        [System.Drawing.Color]$BackColor = $script:ColorPanel,
        [System.Drawing.Color]$ForeColor = $script:ColorTextMain
    )
    $button = New-ThemedButton -Text $Text -BackColor $BackColor -ForeColor $ForeColor -FixedWidth $Width -Height $Height
    $button.Tag = $Key
    Add-Member -InputObject $button -MemberType NoteProperty -Name IsToggled -Value $false -Force
    $button.Add_Click({
        $button.IsToggled = -not $button.IsToggled
        if ($button.IsToggled) {
            $button.BackColor = $script:ColorAccent
            $button.ForeColor = $script:ColorBgMain
        } else {
            $button.BackColor = $BackColor
            $button.ForeColor = $ForeColor
        }
    })
    return $button
}

function Set-FluentCorners {
    param($Control, [int]$Radius = 8)
    try {
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $path.AddArc(0, 0, $Radius, $Radius, 180, 90)
        $path.AddArc($Control.Width - $Radius - 1, 0, $Radius, $Radius, 270, 90)
        $path.AddArc($Control.Width - $Radius - 1, $Control.Height - $Radius - 1, $Radius, $Radius, 0, 90)
        $path.AddArc(0, $Control.Height - $Radius - 1, $Radius, $Radius, 90, 90)
        $path.CloseAllFigures()
        $Control.Region = New-Object System.Drawing.Region($path)
    } catch { }
}

function New-FluentCard {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)]$Content,
        [int]$Height = 0,
        [switch]$AccentBorder
    )
    $card = New-Object System.Windows.Forms.Panel
    $card.BackColor = $script:ColorCardBg
    $card.Padding = New-Object System.Windows.Forms.Padding(16, 32, 16, 14)
    if ($Height -gt 0) { $card.Height = $Height }

    if ($Content) { $card.Controls.Add($Content) }

    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = $Title
    $titleLabel.Dock = 'Top'
    $titleLabel.Height = 28
    $titleLabel.ForeColor = $script:ColorAccent
    $titleLabel.Font = Get-FluentFont -Size 10 -Bold
    $titleLabel.BackColor = [System.Drawing.Color]::Transparent
    $titleLabel.TextAlign = 'MiddleLeft'
    $card.Controls.Add($titleLabel)

    $card.Add_Resize({ param($sender) Set-FluentCorners -Control $sender -Radius 8 })
    $card.Add_Paint({
        param($sender, $e)
        try {
            $g = $e.Graphics
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $diameter = 16
            $path = New-Object System.Drawing.Drawing2D.GraphicsPath
            $path.AddArc(0, 0, $diameter, $diameter, 180, 90)
            $path.AddArc($sender.Width - $diameter - 1, 0, $diameter, $diameter, 270, 90)
            $path.AddArc($sender.Width - $diameter - 1, $sender.Height - $diameter - 1, $diameter, $diameter, 0, 90)
            $path.AddArc(0, $sender.Height - $diameter - 1, $diameter, $diameter, 90, 90)
            $path.CloseAllFigures()
            $borderColor = if ($AccentBorder) { $script:ColorAccent } else { $script:ColorBorder }
            $pen = New-Object System.Drawing.Pen($borderColor, 1.2)
            $g.DrawPath($pen, $path)
            $pen.Dispose()
            $path.Dispose()
        } catch { }
    })
    Set-FluentCorners -Control $card -Radius 8
    return $card
}

