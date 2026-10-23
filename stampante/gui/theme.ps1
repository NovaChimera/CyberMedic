# CyberMedic - Modulo front-end: design system in stile WinUI 3 (Fluent).
# Caricato da CyberMedic_GUI.ps1 tramite dot-sourcing.
#
# Il toolkit resta WinForms per restare eseguibile con Windows PowerShell 5.1
# e PowerShell 7 senza installazioni: WinUI 3 richiederebbe il Windows App SDK
# e un'applicazione .NET pacchettizzata (non uno script). Qui l'aspetto
# WinUI 3 / Fluent viene ricostruito: angoli arrotondati, hover, toggle
# button, card con bordo, barra delle schede disegnata, sfondo a gradiente
# e tipografia Segoe UI Variable quando disponibile.

$script:FluentToggles = @{}
$script:FluentBaseColor = @{}
$script:FluentFontFamily = $null

function Get-FluentFontFamily {
    if ($script:FluentFontFamily) { return $script:FluentFontFamily }
    $family = 'Segoe UI'
    try {
        $installed = @((New-Object System.Drawing.Text.InstalledFontCollection).Families | ForEach-Object { $_.Name })
        foreach ($candidate in @('Segoe UI Variable Text', 'Segoe UI Variable', 'Segoe UI')) {
            if ($installed -contains $candidate) { $family = $candidate; break }
        }
    } catch { }
    $script:FluentFontFamily = $family
    return $family
}

function Get-FluentFont {
    param([double]$Size = 9, [switch]$Bold)
    $style = if ($Bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    return (New-Object System.Drawing.Font((Get-FluentFontFamily), $Size, $style))
}

function Get-FluentLighterColor {
    param(
        [Parameter(Mandatory = $true)][System.Drawing.Color]$Color,
        [int]$Amount = 22
    )
    $r = [Math]::Min(255, $Color.R + $Amount)
    $g = [Math]::Min(255, $Color.G + $Amount)
    $b = [Math]::Min(255, $Color.B + $Amount)
    return [System.Drawing.Color]::FromArgb($Color.A, $r, $g, $b)
}

function Set-FluentCorners {
    param(
        [Parameter(Mandatory = $true)]$Control,
        [int]$Radius = 6
    )
    try {
        $width = $Control.Width
        $height = $Control.Height
        if ($width -le ($Radius * 2) -or $height -le ($Radius * 2)) { return }
        $diameter = $Radius * 2
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $path.AddArc(0, 0, $diameter, $diameter, 180, 90)
        $path.AddArc($width - $diameter - 1, 0, $diameter, $diameter, 270, 90)
        $path.AddArc($width - $diameter - 1, $height - $diameter - 1, $diameter, $diameter, 0, 90)
        $path.AddArc(0, $height - $diameter - 1, $diameter, $diameter, 90, 90)
        $path.CloseAllFigures()
        $Control.Region = New-Object System.Drawing.Region($path)
        $path.Dispose()
    } catch { }
}

function Set-FluentButtonHover {
    param(
        [Parameter(Mandatory = $true)]$Button,
        [Parameter(Mandatory = $true)][bool]$Enter
    )
    try {
        $base = $script:FluentBaseColor[$Button]
        if (-not $base) { return }
        if ($Enter) {
            $Button.BackColor = Get-FluentLighterColor -Color $base -Amount 20
        } else {
            $Button.BackColor = $base
        }
    } catch { }
}

function Set-FluentBaseColor {
    param(
        [Parameter(Mandatory = $true)]$Button,
        [Parameter(Mandatory = $true)][System.Drawing.Color]$Color
    )
    $script:FluentBaseColor[$Button] = $Color
}

function New-FluentButton {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [switch]$Accent,
        [switch]$Danger,
        [int]$Width = 0,
        [int]$Height = 34
    )
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Height = $Height
    $button.FlatStyle = 'Flat'
    $button.FlatAppearance.BorderSize = 1
    $button.FlatAppearance.BorderColor = $script:ColorBorder
    $button.BackColor = $script:ColorPanel
    $button.ForeColor = $script:ColorTextMain
    $button.Font = Get-FluentFont -Size 9 -Bold
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    $button.AutoSize = $false
    $button.Width = 150
    if ($Accent) {
        $button.BackColor = $script:ColorAccent
        $button.ForeColor = $script:ColorBgMain
        $button.FlatAppearance.BorderColor = $script:ColorAccent
    } elseif ($Danger) {
        $button.ForeColor = $script:ColorError
    }
    if ($Width -gt 0) { $button.Width = $Width }
    $script:FluentBaseColor[$button] = $button.BackColor
    $button.Add_Resize({ param($sender) Set-FluentCorners -Control $sender -Radius 6 })
    $button.Add_MouseEnter({ param($sender) Set-FluentButtonHover -Button $sender -Enter $true })
    $button.Add_MouseLeave({ param($sender) Set-FluentButtonHover -Button $sender -Enter $false })
    Set-FluentCorners -Control $button -Radius 6
    return $button
}

function New-FluentToggleButton {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Key,
        [int]$Width = 0
    )
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Height = 30
    $button.FlatStyle = 'Flat'
    $button.FlatAppearance.BorderSize = 1
    $button.FlatAppearance.BorderColor = $script:ColorBorder
    $button.BackColor = $script:ColorPanel
    $button.ForeColor = $script:ColorTextMuted
    $button.Font = Get-FluentFont -Size 9 -Bold
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    $button.AutoSize = $false
    $button.Width = 150
    if ($Width -gt 0) { $button.Width = $Width }
    $script:FluentToggles[$Key] = $button
    $script:FluentBaseColor[$button] = $button.BackColor
    $button.Add_Resize({ param($sender) Set-FluentCorners -Control $sender -Radius 6 })
    Set-FluentCorners -Control $button -Radius 6
    [void](Set-FluentToggleState -Key $Key -On $false)
    return $button
}

function Set-FluentToggleState {
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [Parameter(Mandatory = $true)][bool]$On
    )
    $button = $script:FluentToggles[$Key]
    if (-not $button) { return $false }
    if ($On) {
        $button.BackColor = $script:ColorAccent
        $button.ForeColor = $script:ColorBgMain
        $button.FlatAppearance.BorderColor = $script:ColorAccent
    } else {
        $button.BackColor = $script:ColorPanel
        $button.ForeColor = $script:ColorTextMuted
        $button.FlatAppearance.BorderColor = $script:ColorBorder
    }
    $script:FluentBaseColor[$button] = $button.BackColor
    try { $button.Invalidate() } catch { }
    return $true
}

function Get-FluentToggleState {
    param([Parameter(Mandatory = $true)][string]$Key)
    $button = $script:FluentToggles[$Key]
    if (-not $button) { return $false }
    try { return [bool]($button.BackColor.ToArgb() -eq $script:ColorAccent.ToArgb()) } catch { return $false }
}

function New-FluentCard {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $false)]$Content = $null,
        [int]$Height = 0
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
            $pen = New-Object System.Drawing.Pen($script:ColorBorder, 1)
            $g.DrawPath($pen, $path)
            $pen.Dispose()
            $path.Dispose()
        } catch { }
    })
    Set-FluentCorners -Control $card -Radius 8
    return $card
}

function New-FluentBackgroundImage {
    $bitmap = New-Object System.Drawing.Bitmap(16, 256)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $top = [System.Drawing.ColorTranslator]::FromHtml('#171720')
        $bottom = [System.Drawing.ColorTranslator]::FromHtml('#0a0a0e')
        $rect = New-Object System.Drawing.Rectangle(0, 0, 16, 256)
        $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $top, $bottom, 90.0)
        $graphics.FillRectangle($brush, $rect)
        $brush.Dispose()
    } catch { }
    $graphics.Dispose()
    return $bitmap
}

function Enable-FluentTabs {
    param([Parameter(Mandatory = $true)]$TabControl)
    try {
        $TabControl.Font = Get-FluentFont -Size 9.5 -Bold
        $TabControl.Padding = New-Object System.Drawing.Point(16, 6)
        $TabControl.DrawMode = [System.Windows.Forms.TabDrawMode]::OwnerDrawFixed
        $TabControl.Add_DrawItem({
            param($sender, $e)
            try {
                $g = $e.Graphics
                $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
                $page = $sender.TabPages[$e.Index]
                $selected = ($sender.SelectedIndex -eq $e.Index)
                $rect = $e.Bounds
                if ($selected) {
                    $background = New-Object System.Drawing.SolidBrush($script:ColorCardBg)
                    $g.FillRectangle($background, $rect)
                    $background.Dispose()
                    $underline = New-Object System.Drawing.SolidBrush($script:ColorAccent)
                    $g.FillRectangle($underline, $rect.Left + 6, $rect.Bottom - 3, $rect.Width - 12, 3)
                    $underline.Dispose()
                }
                $color = if ($selected) { $script:ColorAccent } else { $script:ColorTextMuted }
                $brush = New-Object System.Drawing.SolidBrush($color)
                $font = Get-FluentFont -Size 9.5 -Bold
                $format = New-Object System.Drawing.StringFormat
                $format.Alignment = [System.Drawing.StringAlignment]::Center
                $format.LineAlignment = [System.Drawing.StringAlignment]::Center
                $textRect = New-Object System.Drawing.RectangleF([float]$rect.Left, [float]$rect.Top, [float]$rect.Width, [float]($rect.Height - 2))
                $g.DrawString($page.Text, $font, $brush, $textRect, $format)
                $format.Dispose()
                $brush.Dispose()
                $font.Dispose()
            } catch { }
        })
    } catch {
        Write-Log -Message ("Stile Fluent delle schede non applicato: {0}" -f $_.Exception.Message) -Level 'DEBUG'
    }
}
