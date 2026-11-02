# CyberMedic - Splash di avvio (tema Obsidian Purple, stile WinUI 3).
# Caricato da CyberMedic_GUI.ps1 tramite dot-sourcing.
#
# Lo splash e' non bloccante: viene mostrato all'avvio e chiuso solo quando
# il processo di inizializzazione e' realmente completato (100%). La barra
# di avanzamento e' determinata e viene aggiornata passo dopo passo.
# Non prevede pulsanti manuali: l'utente non puo' saltare l'avvio.
#
# L'identita' mostrata (nome, versione, edizione, build) arriva dal Core e
# quindi da product.psd1: non ci sono stringhe hardcoded in questo file.
# I colori sono gli stessi dell'interfaccia (Obsidian Purple): lo splash non
# introduce palette diverse.

$script:Splash = $null

function Get-SplashPalette {
    # Lo splash usa gli stessi colori dell'interfaccia (tema Obsidian Purple):
    # niente palette separata, cosi' l'avvio non risulta estraneo all'app.
    $palette = @{
        Background = [System.Drawing.ColorTranslator]::FromHtml('#0f0f13')
        Band       = [System.Drawing.ColorTranslator]::FromHtml('#1b1b24')
        Card       = [System.Drawing.ColorTranslator]::FromHtml('#111116')
        Accent     = [System.Drawing.ColorTranslator]::FromHtml('#b388ff')
        Text       = [System.Drawing.ColorTranslator]::FromHtml('#e0e0e0')
        Muted      = [System.Drawing.ColorTranslator]::FromHtml('#9e9e9e')
        Track      = [System.Drawing.ColorTranslator]::FromHtml('#323242')
        Success    = [System.Drawing.ColorTranslator]::FromHtml('#a6e3a1')
    }
    try {
        if ($script:ColorBgMain) { $palette.Background = $script:ColorBgMain }
        if ($script:ColorCardBg) { $palette.Card = $script:ColorCardBg }
        if ($script:ColorPanel) { $palette.Band = $script:ColorPanel }
        if ($script:ColorAccent) { $palette.Accent = $script:ColorAccent }
        if ($script:ColorTextMain) { $palette.Text = $script:ColorTextMain }
        if ($script:ColorTextMuted) { $palette.Muted = $script:ColorTextMuted }
        if ($script:ColorBorder) { $palette.Track = $script:ColorBorder }
        if ($script:ColorSuccess) { $palette.Success = $script:ColorSuccess }
        if ($script:AppAccent) {
            $palette.Accent = [System.Drawing.ColorTranslator]::FromHtml($script:AppAccent)
        }
    } catch { }
    return $palette
}

function Get-SplashFont {
    param([double]$Size = 9, [switch]$Bold)
    try {
        if (Get-Command -Name 'Get-FluentFont' -ErrorAction SilentlyContinue) {
            return (Get-FluentFont -Size $Size -Bold:$Bold)
        }
    } catch { }
    $style = if ($Bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    return (New-Object System.Drawing.Font('Segoe UI', $Size, $style))
}

function Show-SplashScreen {
    param([int]$AutoCloseMs = 0)
    try {
        $palette = Get-SplashPalette

        $splash = New-Object System.Windows.Forms.Form
        $splash.FormBorderStyle = 'None'
        $splash.StartPosition = 'CenterScreen'
        $splash.Size = New-Object System.Drawing.Size(620, 340)
        $splash.BackColor = $palette.Background
        $splash.ForeColor = $palette.Text
        $splash.TopMost = $true
        $splash.ShowInTaskbar = $false
        $splash.Text = Get-ProductTitle -Long

        $band = New-Object System.Windows.Forms.Panel
        $band.Dock = 'Top'
        $band.Height = 104
        $band.BackColor = $palette.Band
        $splash.Controls.Add($band)

        $title = New-Object System.Windows.Forms.Label
        $title.Text = $script:AppName
        $title.Font = Get-SplashFont -Size 30 -Bold
        $title.ForeColor = $palette.Text
        $title.TextAlign = 'MiddleCenter'
        $title.Dock = 'Top'
        $title.Height = 58
        $band.Controls.Add($title)

        $edition = New-Object System.Windows.Forms.Label
        $edition.Text = $script:AppEdition
        $edition.Font = Get-SplashFont -Size 12
        $edition.ForeColor = $palette.Accent
        $edition.TextAlign = 'MiddleCenter'
        $edition.Dock = 'Top'
        $edition.Height = 26
        $band.Controls.Add($edition)

        $version = New-Object System.Windows.Forms.Label
        $version.Text = ("Versione {0}   |   Build {1}" -f $script:AppVersion, $script:AppBuild)
        $version.Font = Get-SplashFont -Size 10
        $version.ForeColor = $palette.Muted
        $version.TextAlign = 'MiddleCenter'
        $version.Dock = 'Top'
        $version.Height = 22
        $splash.Controls.Add($version)

        $slogan = New-Object System.Windows.Forms.Label
        $slogan.Text = $script:AppSlogan
        $slogan.Font = Get-SplashFont -Size 9
        $slogan.ForeColor = $palette.Muted
        $slogan.TextAlign = 'MiddleCenter'
        $slogan.Dock = 'Top'
        $slogan.Height = 22
        $splash.Controls.Add($slogan)

        # --- CARD DELLA CHECKLIST (angoli arrotondati, bordo accentato) -----
        $stepsCard = New-Object System.Windows.Forms.Panel
        $stepsCard.Dock = 'Top'
        $stepsCard.Height = 96
        $stepsCard.BackColor = $palette.Card
        $stepsCard.Padding = New-Object System.Windows.Forms.Padding(14, 8, 14, 8)
        $splash.Controls.Add($stepsCard)

        $steps = New-Object System.Windows.Forms.ListBox
        $steps.Dock = 'Fill'
        $steps.BackColor = $palette.Card
        $steps.ForeColor = $palette.Text
        $steps.BorderStyle = 'None'
        $steps.Font = Get-SplashFont -Size 9
        $steps.IntegralHeight = $false
        $steps.ItemHeight = 18
        $steps.DrawMode = 'OwnerDrawFixed'
        $steps.Add_DrawItem({
            param($sender, $e)
            try {
                $text = [string]$sender.Items[$e.Index]
                $palette = $script:Splash.Palette
                $color = $palette.Text
                if ($text -match '^\[ OK \]') { $color = $palette.Success }
                elseif ($text -match '^\[ \.\. \]') { $color = $palette.Accent }
                else { $color = $palette.Muted }
                $font = Get-SplashFont -Size 9
                $e.DrawText($text, $font, $color, $palette.Card, $e.Bounds)
                $font.Dispose()
            } catch { }
        })
        $stepsCard.Controls.Add($steps)

        $status = New-Object System.Windows.Forms.Label
        $status.Text = 'Inizializzazione del modulo...'
        $status.Font = Get-SplashFont -Size 9.5
        $status.ForeColor = $palette.Text
        $status.TextAlign = 'MiddleCenter'
        $status.Dock = 'Bottom'
        $status.Height = 30
        $splash.Controls.Add($status)

        $bar = New-Object System.Windows.Forms.ProgressBar
        $bar.Dock = 'Bottom'
        $bar.Height = 10
        $bar.Minimum = 0
        $bar.Maximum = 100
        $bar.Style = 'Continuous'
        $bar.Value = 0
        $splash.Controls.Add($bar)

        $script:Splash = [pscustomobject]@{
            Form    = $splash
            Bar     = $bar
            Status  = $status
            Steps   = $steps
            Items   = @()
            Value   = 0
            Step    = 0
            Timer   = $null
            Palette = $palette
        }

        # Angoli arrotondati della finestra (stile Fluent), se disponibile.
        try {
            if (Get-Command -Name 'Set-FluentCorners' -ErrorAction SilentlyContinue) {
                Set-FluentCorners -Control $splash -Radius 10
            }
        } catch { }

        # Animazione di attesa: porta la barra al 90% massimo finche' i passi
        # reali di avvio non hanno raggiunto il 100%.
        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = 120
        $timer.Add_Tick({
            try {
                if (-not $script:Splash) { return }
                if ($script:Splash.Value -lt 90) {
                    $script:Splash.Value = [Math]::Min(90, $script:Splash.Value + 1)
                    $script:Splash.Bar.Value = $script:Splash.Value
                }
            } catch { }
        })
        $script:Splash.Timer = $timer
        $splash.Add_Shown({
            try { $script:Splash.Timer.Start() } catch { }
        })
        [void]$splash.Show()

        if ($AutoCloseMs -gt 0) {
            $closer = New-Object System.Windows.Forms.Timer
            $closer.Interval = $AutoCloseMs
            $closer.Add_Tick({
                try { $closer.Stop() } catch { }
                try { Complete-Splash } catch { }
            })
            $splash.Add_Shown({ $closer.Start() })
        }
    } catch {
        Write-Log -Message ("Splash non mostrato: {0}" -f $_.Exception.Message) -Level 'DEBUG'
        $script:Splash = $null
    }
}

function Set-SplashStep {
    param(
        [Parameter(Mandatory = $true)][int]$Index,
        [Parameter(Mandatory = $false)][string]$Label = '',
        [Parameter(Mandatory = $false)][ValidateSet('pending', 'active', 'done')][string]$State = 'active'
    )
    try {
        if (-not $script:Splash) { return }
        $items = @($script:Splash.Items)
        if ($Index -lt 1 -or $Index -gt $items.Count) { return }
        $names = @($items | ForEach-Object { $_.Name })
        $states = @($items | ForEach-Object { $_.State })
        if ($Label) { $names[$Index - 1] = $Label }
        $states[$Index - 1] = $State
        $script:Splash.Items = @()
        for ($i = 0; $i -lt $names.Count; $i++) {
            $script:Splash.Items += [pscustomobject]@{ Name = $names[$i]; State = $states[$i] }
        }
        $rendered = @()
        for ($i = 0; $i -lt $names.Count; $i++) {
            $marker = switch ($states[$i]) {
                'done' { '[ OK ]' }
                'active' { '[ .. ]' }
                default { '[    ]' }
            }
            $rendered += ('{0} {1}' -f $marker, $names[$i])
        }
        $script:Splash.Steps.BeginUpdate()
        $script:Splash.Steps.Items.Clear()
        foreach ($line in $rendered) { [void]$script:Splash.Steps.Items.Add($line) }
        $script:Splash.Steps.EndUpdate()
    } catch { }
}

function Set-SplashSteps {
    param([Parameter(Mandatory = $true)][string[]]$Labels)
    try {
        if (-not $script:Splash) { return }
        $script:Splash.Items = @()
        foreach ($label in $Labels) {
            $script:Splash.Items += [pscustomobject]@{ Name = $label; State = 'pending' }
        }
        Set-SplashStep -Index 1 -State 'active'
    } catch { }
}

function Set-SplashProgress {
    param(
        [Parameter(Mandatory = $true)][int]$Percent,
        [Parameter(Mandatory = $false)][AllowEmptyString()][string]$Message = '',
        [Parameter(Mandatory = $false)][int]$Step = 0
    )
    try {
        if (-not $script:Splash) { return }
        $value = [Math]::Max(0, [Math]::Min(100, $Percent))
        $script:Splash.Value = $value
        $script:Splash.Bar.Value = $value
        if ($Message) { $script:Splash.Status.Text = $Message }
        if ($Step -gt 0) {
            for ($i = 1; $i -lt $Step; $i++) { Set-SplashStep -Index $i -State 'done' }
            Set-SplashStep -Index $Step -State 'active'
        }
        $script:Splash.Form.Refresh()
    } catch { }
}

function Complete-Splash {
    try {
        if (-not $script:Splash) { return }
        Set-SplashProgress -Percent 100 -Message 'Modulo pronto.'
        $count = @($script:Splash.Items).Count
        for ($i = 1; $i -le $count; $i++) { Set-SplashStep -Index $i -State 'done' }
        try { $script:Splash.Timer.Stop() } catch { }
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 320
        try { $script:Splash.Form.Close() } catch { }
        try { $script:Splash.Form.Dispose() } catch { }
        try { $script:Splash.Timer.Dispose() } catch { }
        $script:Splash = $null
    } catch {
        Write-Log -Message ("Chiusura dello splash non riuscita: {0}" -f $_.Exception.Message) -Level 'DEBUG'
        $script:Splash = $null
    }
}
