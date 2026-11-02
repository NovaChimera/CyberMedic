#Requires -Version 7.0
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:Theme = @{
    BgMain        = [System.Drawing.Color]::FromArgb(15, 15, 20)
    BgTabs        = [System.Drawing.Color]::FromArgb(24, 24, 32)
    BgTerminal    = [System.Drawing.Color]::FromArgb(10, 10, 14)
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

# Backward compatibility aliases
$script:BgTabs = $script:Theme.BgTabs
$script:BgMain = $script:Theme.BgMain
$script:BgTerminal = $script:Theme.BgTerminal
$script:AccentViolet = $script:Theme.AccentViolet
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

