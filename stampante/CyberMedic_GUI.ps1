#Requires -Version 5.1
<#
.SYNOPSIS
    CyberMedic - Thin Client GUI (architettura Thin Client).
.DESCRIPTION
    Front-end di CyberMedic: carica il backend CyberMedic_Core.ps1 e ne
    pilota l'interfaccia a schede con il tema scuro Obsidian Purple
    (#0f0f13, #1e1e26, accenti viola lavanda #b388ff).

    Il thin client non contiene logica di sistema: si occupa di costruire i
    controlli, gestire gli eventi e mostrare i dati restituiti dal Core. Il
    caricamento del backend avviene all'avvio con il dot-sourcing, in modo che
    il front-end resti l'unico punto d'ingresso dell'applicazione.

    Schede: 🛡 Home / Dashboard, 🖨 Gestione Stampanti, 📡 Network & Rete,
    🛠 Manutenzione PC, ⚡ Gestione Attivita', 📧 Posta & Outlook.
.PARAMETER PrinterName
    Stampante da selezionare all'avvio.
.PARAMETER LogDirectory
    Cartella dei log. Default: <cartella script>\logs
.PARAMETER SelfTest
    Esegue il protocollo di verifica locale e termina (nessuna interfaccia).
.PARAMETER Diagnose
    Genera il report diagnostico su console e termina.
.PARAMETER NoElevation
    Non tenta l'auto-elevazione del processo.
.PARAMETER SmokeTest
    Costruisce l'interfaccia grafica senza mostrarla e verifica il popolamento
    dei controlli. Utile per validare l'installazione su una postazione.
.PARAMETER ResolvePort
    Risolve una porta di stampa indicata come argomento e ne stampa il
    risultato (host, IP, porta TCP e sorgente della risoluzione).
#>

[CmdletBinding()]
param(
    [string]$PrinterName,
    [string]$LogDirectory,
    [switch]$SelfTest,
    [switch]$Diagnose,
    [switch]$NoElevation,
    [switch]$SmokeTest,
    [string]$ResolvePort,
    [string]$ResolvePrinter = '',
    [string]$ProductName = '',
    [string]$ProductVersion = ''
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$script:CoreFileName = 'CyberMedic_Core.ps1'
$corePath = Join-Path -Path $PSScriptRoot -ChildPath $script:CoreFileName
if (-not (Test-Path -LiteralPath $corePath -PathType Leaf)) {
    Write-Error ("Backend non trovato: {0}" -f $corePath)
    exit 1
}
. $corePath

# L'identita' del prodotto (nome, versione, edizione) arriva da product.psd1;
# gli argomenti espliciti hanno la precedenza e sovrascrivono il file.
Initialize-ProductIdentity -RootPath $PSScriptRoot -ProductName $ProductName -ProductVersion $ProductVersion

# ------------------------------------------------------------------------
# MODULI GUI (splash e schede modulari)
# ------------------------------------------------------------------------
# Le schede dell'interfaccia sono codificate in moduli separati: ogni file
# espone una funzione New-XxxTab che costruisce la scheda e registra i
# controlli in $script:Ui. Il thin client resta il unico punto d'ingresso.
$script:GuiModules = @(
    'gui\theme.ps1'
    'gui\splash.ps1'
    'gui\tabs\taskmanager.ps1'
    'gui\tabs\updates.ps1'
    'gui\tabs\maintenance.ps1'
    'gui\tabs\mail.ps1'
    'gui\tabs\cybersecurity.ps1'
)
foreach ($moduleRelative in $script:GuiModules) {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath $moduleRelative
    if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
        Write-Log -Message ("Modulo GUI '{0}' non trovato in {1}" -f $moduleRelative, $PSScriptRoot) -Level 'ERROR'
        continue
    }
    try {
        . $modulePath
    } catch {
        Write-Log -Message ("Modulo GUI '{0}' non caricato: {1}" -f $moduleRelative, $_.Exception.Message) -Level 'ERROR'
    }
}

Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue

$script:ColorBgMain = [System.Drawing.ColorTranslator]::FromHtml('#0f0f13')
$script:ColorBgList = [System.Drawing.ColorTranslator]::FromHtml('#181820')
$script:ColorPanel = [System.Drawing.ColorTranslator]::FromHtml('#22222d')
$script:ColorBorder = [System.Drawing.ColorTranslator]::FromHtml('#323242')
$script:ColorAccent = [System.Drawing.ColorTranslator]::FromHtml('#b388ff')
$script:ColorTextMain = [System.Drawing.ColorTranslator]::FromHtml('#e0e0e0')
$script:ColorTextMuted = [System.Drawing.ColorTranslator]::FromHtml('#9e9e9e')
$script:ColorError = [System.Drawing.ColorTranslator]::FromHtml('#f38ba8')
$script:ColorSuccess = [System.Drawing.ColorTranslator]::FromHtml('#a6e3a1')
$script:ColorWarning = [System.Drawing.ColorTranslator]::FromHtml('#f9e2af')
$script:ColorCardBg = [System.Drawing.ColorTranslator]::FromHtml('#111116')
$script:ThemeMap = @{
    muted   = $script:ColorTextMuted
    error   = $script:ColorError
    success = $script:ColorSuccess
    accent  = $script:ColorAccent
    warning = $script:ColorWarning
    text    = $script:ColorTextMain
}

$script:Activity = @{
    Metrics    = $null
    History    = New-Object System.Collections.Generic.List[int]
    HistoryRam = New-Object System.Collections.Generic.List[int]
    HistoryDisk = New-Object System.Collections.Generic.List[int]
    LogLines   = New-Object System.Collections.Generic.List[string]
}

function Get-ThemeColor {
    param([Parameter(Mandatory = $false)][string]$Key)
    if ([string]::IsNullOrWhiteSpace($Key)) { return $script:ColorTextMain }
    if ($script:ThemeMap.ContainsKey($Key)) { return $script:ThemeMap[$Key] }
    return $script:ColorTextMain
}
function Show-Message {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [string]$Caption = '',
        [ValidateSet('Info', 'Warning', 'Error', 'Question')][string]$Kind = 'Info'
    )
    try {
        $icon = switch ($Kind) {
            'Warning' { [System.Windows.Forms.MessageBoxIcon]::Warning }
            'Error' { [System.Windows.Forms.MessageBoxIcon]::Error }
            'Question' { [System.Windows.Forms.MessageBoxIcon]::Question }
            default { [System.Windows.Forms.MessageBoxIcon]::Information }
        }
        $buttons = if ($Kind -eq 'Question') { [System.Windows.Forms.MessageBoxButtons]::YesNo } else { [System.Windows.Forms.MessageBoxButtons]::OK }
        if ([string]::IsNullOrWhiteSpace($Caption)) { $Caption = $script:AppName }
        return [System.Windows.Forms.MessageBox]::Show($Text, $Caption, $buttons, $icon)
    } catch {
        Write-Output $Text
        return [System.Windows.Forms.DialogResult]::OK
    }
}

function Invoke-Safe {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Action,
        [string]$Context = 'Operazione'
    )
    try {
        & $Action
    } catch {
        $message = $_.Exception.Message
        Write-Log -Message ("{0}: {1}" -f $Context, $message) -Level 'ERROR'
        [void](Show-Message -Text ("{0} non riuscita.`r`n`r`n{1}`r`n`r`nDettaglio nel registro." -f $Context, $message) -Caption 'CyberMedic - Errore' -Kind 'Error')
    }
}

function Set-BusyState {
    param([bool]$Busy, [string]$Message = '')
    if ($script:Ui.Form) {
        try {
            $script:Ui.Form.UseWaitCursor = $Busy
            $script:Ui.Progress.Visible = $Busy
            if ($script:Ui.StatusLabel) {
                $script:Ui.StatusLabel.Text = if ($Message) { $Message } else { 'Pronto' }
            }
            $script:Ui.Form.Refresh()
            [System.Windows.Forms.Application]::DoEvents()
        } catch {
            Write-Log -Message ("Impostazione dello stato busy non riuscita: {0}" -f $_.Exception.Message) -Level 'DEBUG'
        }
    }
}

function Update-StatusBar {
    param([string]$Message)
    if ($script:Ui.StatusLabel) {
        try { $script:Ui.StatusLabel.Text = $Message } catch { }
    }
}

function Show-PrinterList {
    $list = $script:Ui.PrinterList
    if (-not $list) { return }
    $selectedName = $script:SelectedPrinterName
    $list.BeginUpdate()
    try {
        $list.Items.Clear()
        foreach ($p in $script:Inventory) {
            $item = New-Object System.Windows.Forms.ListViewItem(("{0} {1}" -f $p.StatusBadge, $p.Name))
            [void]$item.SubItems.Add((Get-SafeText -InputObject $p -Name 'IpAddress' -Default 'N/D'))
            [void]$item.SubItems.Add((Get-SafeText -InputObject $p -Name 'SubnetMask' -Default 'N/D'))
            [void]$item.SubItems.Add((Get-SafeText -InputObject $p -Name 'Status' -Default 'N/D'))
            [void]$item.SubItems.Add($(if ($p.IsDefault) { 'SI' } else { 'NO' }))
            [void]$item.SubItems.Add([string]$p.JobCount)
            [void]$item.SubItems.Add((Get-SafeText -InputObject $p -Name 'PortName' -Default 'N/D'))
            [void]$item.SubItems.Add((Get-SafeText -InputObject $p -Name 'PortKind' -Default 'N/D'))
            $item.Tag = $p
            $item.ForeColor = Get-ThemeColor -Key $p.StatusColorKey
            [void]$list.Items.Add($item)
        }
        if ($selectedName) {
            foreach ($item in $list.Items) {
                if ($item.Tag -and $item.Tag.Name -eq $selectedName) {
                    $item.Selected = $true
                    $item.EnsureVisible()
                    break
                }
            }
        }
        if ($list.Items.Count -gt 0 -and $list.SelectedItems.Count -eq 0) {
            $list.Items[0].Selected = $true
        }
    } finally {
        $list.EndUpdate()
    }
    try { Sync-PrinterListColumnWidths } catch { }

    $target = $null
    if ($selectedName) {
        $target = $script:Inventory | Where-Object { $_.Name -eq $selectedName } | Select-Object -First 1
    }
    if (-not $target -and $script:Inventory.Count -gt 0) { $target = $script:Inventory[0] }
    if ($target) {
        $script:SelectedPrinter = $target
        $script:SelectedPrinterName = $target.Name
    }
    Update-StatusBar ("Pronto. Totale stampanti trovate: {0}" -f $script:Inventory.Count)
}

function Sync-PrinterListColumnWidths {
    $list = $script:Ui.PrinterList
    if (-not $list) { return }
    if ($list.Columns.Count -eq 0) { return }
    $available = $list.ClientSize.Width - 4
    if ($available -le 0) { return }
    $total = 0
    foreach ($definition in $script:PrinterListColumns) { $total += $definition.Width }
    if ($total -le $available) { return }
    $scale = $available / $total
    $index = 0
    foreach ($definition in $script:PrinterListColumns) {
        if ($index -ge $list.Columns.Count) { break }
        $width = [int][Math]::Floor($definition.Width * $scale)
        if ($width -lt $definition.Min) { $width = $definition.Min }
        if ($list.Columns[$index].Width -ne $width) { $list.Columns[$index].Width = $width }
        $index++
    }
}

function Show-LiveCard {
    $box = $script:Ui.CardBox
    if (-not $box) { return }
    $p = $script:SelectedPrinter
    if (-not $p) {
        $box.Text = "Nessuna stampante selezionata."
        return
    }
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add(('Modello     : {0}' -f $p.Name))
    $lines.Add(('Indirizzo IP: {0}' -f (Get-SafeText -InputObject $p -Name 'IpAddress' -Default 'N/D')))
    $lines.Add(('Subnet Mask : {0}' -f (Get-SafeText -InputObject $p -Name 'SubnetMask' -Default 'N/D')))
    $lines.Add(('Sottorete   : {0}  [da {1}]' -f (Get-SafeText -InputObject $p -Name 'SubnetCidr' -Default 'N/D'), (Get-SafeText -InputObject $p -Name 'SubnetSource' -Default 'N/D')))
    $lines.Add(('Stato       : {0} {1}' -f $p.StatusBadge, $p.Status))
    $lines.Add(('Porta       : {0} ({1})' -f $p.PortName, $p.PortKind))
    $lines.Add(('Porta TCP   : {0}' -f $p.TcpPort))
    $lines.Add(('Host        : {0} [da {1}]' -f $p.Host, $p.ResolveSource))
    $lines.Add(('Lavori Coda : {0}' -f $p.JobCount))
    $lines.Add(('Predefinita : {0}' -f $(if ($p.IsDefault) { 'SI' } else { 'NO' })))
    $lines.Add(('Forzata Off : {0}' -f $(if ($p.IsOffline) { 'SI' } else { 'NO' })))
    $lines.Add(('Condivisa   : {0}' -f $(if ($p.Shared) { 'SI' } else { 'NO' })))
    $lines.Add(('Driver      : {0}' -f $p.DriverName))
    $lines.Add(('Posizione   : {0}' -f $(if ($p.Location) { $p.Location } else { 'N/D' })))
    $lines.Add('')
    $lines.Add('Log diagnostico recente:')
    $lines.Add(('  {0}' -f $p.LastLogError))
    foreach ($note in $p.Notes) {
        $lines.Add(('  Nota: {0}' -f $note))
    }
    $box.Text = ($lines -join [Environment]::NewLine)
}

function Show-PrinterDetails {
    $p = $script:SelectedPrinter
    $list = $script:Ui.DetailList
    if (-not $list) { return }
    $list.Items.Clear()
    if (-not $p) {
        [void]$list.Items.Add((New-Object System.Windows.Forms.ListViewItem('Nessuna stampante selezionata')))
        return
    }
    $rows = [ordered]@{
        'Nome'           = $p.Name
        'Porta'          = $p.PortName
        'Tipo porta'     = $p.PortKind
        'Host / IP'      = $p.Host
        'Indirizzo IP'   = $p.IpAddress
        'Subnet Mask'    = ('{0} [da {1}]' -f $p.SubnetMask, $p.SubnetSource)
        'Sottorete CIDR' = $p.SubnetCidr
        'Porta TCP'      = $p.TcpPort
        'Risoluzione da' = $p.ResolveSource
        'Driver'         = $p.DriverName
        'Stato'          = ('{0} {1} ({2})' -f $p.StatusBadge, $p.Status, $p.StatusSource)
        'Forzata offline'= $(if ($p.IsOffline) { 'SI' } else { 'NO' })
        'Lavori in coda' = $p.JobCount
        'Predefinita'    = $(if ($p.IsDefault) { 'SI' } else { 'NO' })
        'Tipo'           = $p.Type
        'Condivisa'      = $(if ($p.Shared) { 'SI' } else { 'NO' })
        'Posizione'      = $(if ($p.Location) { $p.Location } else { 'N/D' })
        'Commento'       = $(if ($p.Comment) { $p.Comment } else { 'N/D' })
        'Ultimo errore'  = $p.LastLogError
    }
    foreach ($key in $rows.Keys) {
        $item = New-Object System.Windows.Forms.ListViewItem($key)
        [void]$item.SubItems.Add([string]$rows[$key])
        [void]$list.Items.Add($item)
    }
    foreach ($note in $p.Notes) {
        $item = New-Object System.Windows.Forms.ListViewItem('Nota')
        [void]$item.SubItems.Add([string]$note)
        $item.ForeColor = $script:ColorWarning
        [void]$list.Items.Add($item)
    }
}

function Show-PrinterJobs {
    $p = $script:SelectedPrinter
    $list = $script:Ui.JobList
    if (-not $list) { return }
    $list.Items.Clear()
    if (-not $p) { return }
    $jobs = @(Get-PrinterJobInfo -TargetPrinter $p.Name)
    if ($jobs.Count -eq 0) {
        $item = New-Object System.Windows.Forms.ListViewItem('Nessun lavoro in coda')
        [void]$item.SubItems.Add('')
        [void]$item.SubItems.Add('')
        [void]$item.SubItems.Add('')
        [void]$item.SubItems.Add('')
        [void]$list.Items.Add($item)
        return
    }
    foreach ($job in $jobs) {
        $item = New-Object System.Windows.Forms.ListViewItem($job.Id)
        [void]$item.SubItems.Add($job.User)
        [void]$item.SubItems.Add($job.Document)
        [void]$item.SubItems.Add($job.Status)
        [void]$item.SubItems.Add($job.Size)
        [void]$item.SubItems.Add($job.Submitted)
        $item.Tag = $job
        [void]$list.Items.Add($item)
    }
}

function Show-NetworkTab {
    $p = $script:SelectedPrinter
    $box = $script:Ui.NetworkBox
    if (-not $box) { return }
    $box.Clear()
    if (-not $p) {
        $box.AppendText("Nessuna stampante selezionata.`r`n")
        return
    }
    $box.AppendText(('Stampante : {0}' -f $p.Name) + [Environment]::NewLine)
    $box.AppendText(('Porta     : {0}  ({1})' -f $p.PortName, $p.PortKind) + [Environment]::NewLine)
    $box.AppendText(('Host      : {0}  [fonte: {1}]' -f $p.Host, $p.ResolveSource) + [Environment]::NewLine)
    $box.AppendText(('IP        : {0}' -f $p.IpAddress) + [Environment]::NewLine)
    $box.AppendText(('TCP       : {0}' -f $p.TcpPort) + [Environment]::NewLine)
    foreach ($note in $p.Notes) {
        $box.AppendText(('Nota      : {0}' -f $note) + [Environment]::NewLine)
    }
    $box.AppendText('')
    $box.AppendText('Premere "Esegui test di rete" per verificare ping e porte TCP.' + [Environment]::NewLine)
}

function Invoke-NetworkTest {
    $p = $script:SelectedPrinter
    if (-not $p) {
        [void](Show-Message -Text "Selezionare una stampante dall'elenco." -Caption $script:AppName -Kind 'Warning')
        return
    }
    Set-BusyState -Busy $true -Message 'Test di rete in corso...'
    try {
        $endpoint = Resolve-PrinterEndpoint -PrinterName $p.Name -PortName $p.PortName
        $lines = @(Test-PrinterNetwork -Endpoint $endpoint)
        $box = $script:Ui.NetworkBox
        $box.Clear()
        foreach ($line in $lines) {
            $box.AppendText($line + [Environment]::NewLine)
        }
        Write-Log -Message ('Test di rete completato per {0}.' -f $p.Name) -Level 'OK'
    } catch {
        Write-Log -Message ("Test di rete non riuscito: {0}" -f $_.Exception.Message) -Level 'ERROR'
        [void](Show-Message -Text ('Test di rete non riuscito: {0}' -f $_.Exception.Message) -Caption 'CyberMedic - Errore' -Kind 'Error')
    } finally {
        Set-BusyState -Busy $false -Message 'Pronto'
    }
}

function New-MenuItem {
    param([string]$Text, [scriptblock]$Action = $null)
    $item = New-Object System.Windows.Forms.ToolStripMenuItem
    $item.Text = $Text
    if ($Action) { $item.Add_Click($Action) }
    return $item
}

function New-ToolButton {
    param([string]$Text, [scriptblock]$Action)
    $button = New-Object System.Windows.Forms.ToolStripButton
    $button.Text = $Text
    $button.DisplayStyle = 'Text'
    $button.Add_Click($Action)
    return $button
}

function Invoke-Refresh {
    Set-BusyState -Busy $true -Message 'Aggiornamento lista stampanti in corso...'
    try {
        Update-Inventory | Out-Null
        Show-PrinterList
        Show-PrinterDetails
        Show-PrinterJobs
        Show-NetworkTab
        Show-LiveCard
    } finally {
        Set-BusyState -Busy $false -Message 'Pronto'
    }
}

function Show-IpEditDialog {
    param(
        [Parameter(Mandatory = $true)]$Printer,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$CurrentIp
    )
    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = "Modifica IP - $($Printer.Name)"
    $dialog.StartPosition = 'CenterParent'
    $dialog.FormBorderStyle = 'FixedDialog'
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false
    $dialog.ClientSize = New-Object System.Drawing.Size(520, 320)
    $dialog.BackColor = $script:ColorBgMain
    $dialog.ForeColor = $script:ColorTextMain
    $dialog.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = 'Fill'
    $layout.ColumnCount = 2
    $layout.RowCount = 7
    $layout.Padding = New-Object System.Windows.Forms.Padding(14)
    $layout.BackColor = $script:ColorBgMain
    [void]$layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize)))
    [void]$layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    for ($row = 0; $row -lt 7; $row++) {
        [void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
    }
    $dialog.Controls.Add($layout)

    function Add-Row {
        param([string]$Caption, [string]$Value, [switch]$Editable, [int]$Row = 0)
        $label = New-Object System.Windows.Forms.Label
        $label.Text = $Caption
        $label.ForeColor = $script:ColorTextMuted
        $label.AutoSize = $true
        $label.Anchor = 'Left'
        $label.Margin = New-Object System.Windows.Forms.Padding(3, 6, 3, 8)
        $valueControl = New-Object System.Windows.Forms.TextBox
        $valueControl.Text = $Value
        $valueControl.BackColor = $script:ColorCardBg
        $valueControl.ForeColor = $script:ColorTextMain
        $valueControl.BorderStyle = 'FixedSingle'
        $valueControl.Dock = 'Fill'
        $valueControl.Margin = New-Object System.Windows.Forms.Padding(3, 3, 3, 8)
        if (-not $Editable) { $valueControl.ReadOnly = $true }
        [void]$layout.Controls.Add($label, 0, $Row)
        [void]$layout.Controls.Add($valueControl, 1, $Row)
        return $valueControl
    }

    [void](Add-Row -Caption 'Stampante' -Value $Printer.Name -Row 0)
    [void](Add-Row -Caption 'Porta attuale' -Value $Printer.PortName -Row 1)
    [void](Add-Row -Caption 'Tipo porta' -Value $Printer.PortKind -Row 2)
    $ipBox = Add-Row -Caption 'Nuovo indirizzo IPv4' -Value $CurrentIp -Editable -Row 3
    $maskRow = Add-Row -Caption 'Subnet mask / sottorete' -Value ("{0}  ({1})" -f $Printer.SubnetMask, $Printer.SubnetCidr) -Row 4

    $note = New-Object System.Windows.Forms.Label
    $note.Text = "La modifica aggiorna la porta TCP/IP nel sistema e riavvia lo Spooler.`r`nVerificare la raggiungibilita' del nuovo indirizzo prima di applicare."
    $note.ForeColor = $script:ColorWarning
    $note.AutoSize = $true
    $note.Dock = 'Fill'
    $note.Margin = New-Object System.Windows.Forms.Padding(3, 6, 3, 6)
    [void]$layout.Controls.Add($note, 1, 5)

    $buttons = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttons.FlowDirection = 'RightToLeft'
    $buttons.Dock = 'Fill'
    $buttons.Height = 44
    $buttons.BackColor = $script:ColorBgMain
    $cancel = New-ThemedButton -Text 'Annulla' -BackColor $script:ColorPanel -ForeColor $script:ColorTextMain
    $cancel.Add_Click({ $dialog.DialogResult = [System.Windows.Forms.DialogResult]::Cancel; $dialog.Close() })
    $buttons.Controls.Add($cancel)
    $apply = New-ThemedButton -Text 'Applica indirizzo' -BackColor $script:ColorAccent -ForeColor $script:ColorBgMain
    $buttons.Controls.Add($apply)
    [void]$layout.Controls.Add($buttons, 1, 6)

    $script:IpEditResult = $null
    $apply.Add_Click({
        $value = $ipBox.Text.Trim()
        if (-not (Test-IPv4Address -Address $value)) {
            [void](Show-Message -Text ("'{0}' non e' un indirizzo IPv4 valido.`r`nFormato atteso: 192.168.1.10" -f $value) -Caption 'Indirizzo non valido' -Kind 'Warning')
            return
        }
        if ($value -eq $CurrentIp) {
            [void](Show-Message -Text 'Il nuovo indirizzo coincide con quello corrente.' -Caption 'Nessuna modifica' -Kind 'Info')
            return
        }
        $script:IpEditResult = $value
        $dialog.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $dialog.Close()
    })

    $dialog.Add_FormClosing({ })
    $maskRow.ReadOnly = $true
    $dialog.ShowDialog()
    return $script:IpEditResult
}

function Invoke-ActionEditIp {
    $p = Get-SelectedPrinterOrWarn
    if (-not $p) { return }
    $currentIp = $p.IpAddress
    if ($currentIp -eq 'N/D' -or -not (Test-IPv4Address -Address $currentIp)) {
        $answer = Show-Message -Text ("La stampante '{0}' non ha un indirizzo IP risolvibile (porta '{1}').`r`n`r`nSi puo' comunque impostare un nuovo IP, che verra' applicato come porta TCP/IP Standard." -f $p.Name, $p.PortName) -Caption 'Indirizzo non disponibile' -Kind 'Question'
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        $currentIp = ''
    }
    $newIp = Show-IpEditDialog -Printer $p -CurrentIp $currentIp
    if (-not $newIp) { return }
    $portNumber = 9100
    if ($p.TcpPort) {
        $parsed = 0
        if ([int]::TryParse([string]$p.TcpPort, [ref]$parsed) -and $parsed -gt 0) { $portNumber = $parsed }
    }
    Set-BusyState -Busy $true -Message ("Aggiornamento IP a {0}..." -f $newIp)
    try {
        $r = Set-PrinterIpAddress -TargetPrinter $p.Name -NewIpAddress $newIp -PortName $p.PortName -PortNumber $portNumber
    } finally {
        Set-BusyState -Busy $false -Message 'Pronto'
    }
    $message = $r.Message
    if ($r.Details.Count -gt 0) {
        $message = $message + "`r`n`r`n" + (($r.Details | ForEach-Object { "  - $_" }) -join "`r`n")
    }
    [void](Show-Message -Text $message -Caption 'CyberMedic - Modifica IP' -Kind $(if ($r.Success) { 'Info' } else { 'Error' }))
    Invoke-Refresh
}

function Get-SelectedPrinterOrWarn {
    if (-not $script:SelectedPrinter) {
        [void](Show-Message -Text "Selezionare una stampante dall'elenco." -Caption $script:AppName -Kind 'Warning')
        return $null
    }
    return $script:SelectedPrinter
}

function Invoke-ActionSetDefault {
    $p = Get-SelectedPrinterOrWarn
    if (-not $p) { return }
    $r = Set-DefaultPrinterSafe -TargetPrinter $p.Name
    [void](Show-Message -Text $r.Message -Caption $script:AppName -Kind $(if ($r.Success) { 'Info' } else { 'Error' }))
    Invoke-Refresh
}

function Invoke-ActionClearQueue {
    $p = Get-SelectedPrinterOrWarn
    if (-not $p) { return }
    $r = Clear-PrinterQueue -TargetPrinter $p.Name
    [void](Show-Message -Text $r.Message -Caption $script:AppName -Kind 'Info')
    Invoke-Refresh
}

function Invoke-ActionPurgeSpooler {
    $answer = Show-Message -Text "Svuotare la coda di TUTTE le stampanti?`r`nIl servizio Spooler verra' fermato e riavviato." -Caption $script:AppName -Kind 'Question'
    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    Set-BusyState -Busy $true -Message 'Svuotamento spooler in corso...'
    try {
        $r = Clear-SpoolerQueue
    } finally {
        Set-BusyState -Busy $false -Message 'Pronto'
    }
    [void](Show-Message -Text $r.Message -Caption $script:AppName -Kind $(if ($r.Success) { 'Info' } else { 'Error' }))
    Invoke-Refresh
}

function Invoke-ActionTestPage {
    $p = Get-SelectedPrinterOrWarn
    if (-not $p) { return }
    $r = Send-PrinterTestPage -TargetPrinter $p.Name
    [void](Show-Message -Text $r.Message -Caption $script:AppName -Kind $(if ($r.Success) { 'Info' } else { 'Error' }))
}

function Invoke-ActionFindDriver {
    $p = Get-SelectedPrinterOrWarn
    if (-not $p) { return }
    $r = Open-PrinterDriverPage -TargetPrinter $p.Name -DriverName $p.DriverName
    [void](Show-Message -Text $r.Message -Caption $script:AppName -Kind $(if ($r.Success) { 'Info' } else { 'Error' }))
}

function Invoke-ActionWebAdmin {
    $p = Get-SelectedPrinterOrWarn
    if (-not $p) { return }
    $r = Open-PrinterWebAdmin -TargetPrinter $p.Name
    [void](Show-Message -Text $r.Message -Caption $script:AppName -Kind $(if ($r.Success) { 'Info' } else { 'Error' }))
}

function Invoke-ActionExportReport {
    $answer = Show-Message -Text "Esportare il report CSV sul Desktop?`r`nScegliendo NO il file viene salvato nella cartella dei log del tool." -Caption $script:AppName -Kind 'Question'
    $toDesktop = ($answer -eq [System.Windows.Forms.DialogResult]::Yes)
    $r = Export-InventoryCsv -ToDesktop:$toDesktop
    if (-not $r.Success) {
        [void](Show-Message -Text $r.Message -Caption 'CyberMedic - Errore' -Kind 'Error')
        return
    }
    [void](Show-Message -Text $r.Message -Caption $script:AppName -Kind 'Info')
    try { Start-Process -FilePath 'explorer.exe' -ArgumentList ('/select,"{0}"' -f $r.Path) -ErrorAction Stop } catch { }
}

function Invoke-ActionExportDiagnostic {
    $r = Export-DiagnosticReport
    [void](Show-Message -Text $r.Message -Caption $script:AppName -Kind $(if ($r.Success) { 'Info' } else { 'Error' }))
}

function Invoke-ActionRemovePrinter {
    $p = Get-SelectedPrinterOrWarn
    if (-not $p) { return }
    $answer = Show-Message -Text ("Vuoi eliminare DEFINITIVAMENTE la stampante '{0}' dal sistema?`r`nL'operazione non e' reversibile e richiede i privilegi di amministratore." -f $p.Name) -Caption 'Conferma Eliminazione' -Kind 'Question'
    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    $r = Remove-PrinterSafe -TargetPrinter $p.Name
    [void](Show-Message -Text $r.Message -Caption $script:AppName -Kind $(if ($r.Success) { 'Info' } else { 'Error' }))
    $script:SelectedPrinter = $null
    $script:SelectedPrinterName = ''
    Invoke-Refresh
    if ($script:Ui.CardBox) { $script:Ui.CardBox.Clear() }
}

function Invoke-ActionExit {
    Write-Log -Message "Chiusura richiesta dall'operatore: terminazione volatile dell'applicazione." -Level 'INFO'
    try {
        if ($script:Ui.Form) { $script:Ui.Form.Close() }
        [System.Windows.Forms.Application]::Exit()
    } catch {
        Write-Log -Message ("Chiusura non ordinata: {0}" -f $_.Exception.Message) -Level 'ERROR'
        try { Stop-Process -Id $PID -Force -ErrorAction Stop } catch { }
    }
}

function New-ThemedButton {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [System.Drawing.Color]$BackColor = $script:ColorPanel,
        [System.Drawing.Color]$ForeColor = $script:ColorTextMain,
        [int]$FixedWidth = 0
    )
    # Pulsante in stile WinUI 3 / Fluent: angoli arrotondati, bordo sottile,
    # hover luminoso e tipografia Segoe UI Variable.
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Height = 36
    $button.FlatStyle = 'Flat'
    $button.FlatAppearance.BorderSize = 1
    $button.FlatAppearance.BorderColor = $script:ColorBorder
    $button.BackColor = $BackColor
    $button.ForeColor = $ForeColor
    $button.Font = Get-FluentFont -Size 9 -Bold
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    $button.AutoSize = $true
    $button.AutoSizeMode = 'GrowAndShrink'
    if ($FixedWidth -gt 0) {
        $button.AutoSize = $false
        $button.Width = $FixedWidth
    }
    if (Get-Command -Name 'Set-FluentBaseColor' -ErrorAction SilentlyContinue) {
        Set-FluentBaseColor -Button $button -Color $BackColor
        $button.Add_Resize({ param($sender) Set-FluentCorners -Control $sender -Radius 6 })
        $button.Add_MouseEnter({ param($sender) Set-FluentButtonHover -Button $sender -Enter $true })
        $button.Add_MouseLeave({ param($sender) Set-FluentButtonHover -Button $sender -Enter $false })
        Set-FluentCorners -Control $button -Radius 6
    }
    return $button
}

function New-ThemedListView {
    param([switch]$OwnerDrawHeader)
    $view = New-Object System.Windows.Forms.ListView
    $view.View = 'Details'
    $view.FullRowSelect = $true
    $view.GridLines = $true
    $view.BackColor = $script:ColorBgList
    $view.ForeColor = $script:ColorTextMain
    $view.BorderStyle = 'None'
    $view.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
    $view.Dock = 'Fill'
    if ($OwnerDrawHeader) {
        try {
            $view.OwnerDraw = $true
            $view.Add_DrawColumnHeader({
                param($sender, $e)
                try {
                    $e.DrawDefault = $false
                    $background = New-Object System.Drawing.SolidBrush($script:ColorPanel)
                    $foreground = New-Object System.Drawing.SolidBrush($script:ColorAccent)
                    $e.Graphics.FillRectangle($background, $e.Bounds)
                    $e.Graphics.DrawString($sender.Columns[$e.ColumnIndex].Text, $e.Font, $foreground, $e.Bounds)
                    $background.Dispose()
                    $foreground.Dispose()
                } catch {
                    $e.DrawDefault = $true
                }
            })
            $view.Add_DrawItem({ param($sender, $e) $e.DrawDefault = $true })
            $view.Add_DrawSubItem({ param($sender, $e) $e.DrawDefault = $true })
        } catch { }
    }
    return $view
}

function Show-ScrollableResultDialog {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $false)][AllowEmptyString()][string]$Text = ''
    )
    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = $Title
    $dialog.Size = New-Object System.Drawing.Size(680, 420)
    $dialog.StartPosition = 'CenterParent'
    $dialog.BackColor = $script:ColorBgMain
    $dialog.ForeColor = $script:ColorTextMain
    $dialog.MinimizeBox = $false
    $dialog.MaximizeBox = $true

    $box = New-Object System.Windows.Forms.TextBox
    $box.Multiline = $true
    $box.ReadOnly = $true
    $box.ScrollBars = 'Both'
    $box.WordWrap = $false
    $box.BackColor = $script:ColorCardBg
    $box.ForeColor = $script:ColorSuccess
    $box.Font = New-Object System.Drawing.Font('Consolas', 9.5)
    $box.Dock = 'Fill'
    $box.BorderStyle = 'None'
    $box.Text = $Text
    $dialog.Controls.Add($box)

    $close = New-ThemedButton -Text 'Chiudi' -BackColor $script:ColorPanel -ForeColor $script:ColorTextMain
    $close.Dock = 'Bottom'
    $close.Height = 34
    $close.Add_Click({ $dialog.Close() })
    $dialog.Controls.Add($close)

    [void]$dialog.ShowDialog()
    $dialog.Dispose()
}

function Show-PasswordChangeDialog {
    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = 'Cambio password utente locale'
    $dialog.Size = New-Object System.Drawing.Size(440, 250)
    $dialog.StartPosition = 'CenterParent'
    $dialog.BackColor = $script:ColorBgMain
    $dialog.ForeColor = $script:ColorTextMain
    $dialog.FormBorderStyle = 'FixedDialog'
    $dialog.MaximizeBox = $false

    $labelUser = New-Object System.Windows.Forms.Label
    $labelUser.Text = 'Nome utente:'
    $labelUser.Location = New-Object System.Drawing.Point(18, 18)
    $labelUser.ForeColor = $script:ColorTextMuted
    $dialog.Controls.Add($labelUser)

    $textUser = New-Object System.Windows.Forms.TextBox
    $textUser.Text = $env:USERNAME
    $textUser.Location = New-Object System.Drawing.Point(18, 40)
    $textUser.Size = New-Object System.Drawing.Size(390, 24)
    $textUser.BackColor = $script:ColorBgList
    $textUser.ForeColor = $script:ColorTextMain
    $textUser.BorderStyle = 'FixedSingle'
    $dialog.Controls.Add($textUser)

    $labelPass = New-Object System.Windows.Forms.Label
    $labelPass.Text = 'Nuova password:'
    $labelPass.Location = New-Object System.Drawing.Point(18, 74)
    $labelPass.ForeColor = $script:ColorTextMuted
    $dialog.Controls.Add($labelPass)

    $textPass = New-Object System.Windows.Forms.TextBox
    $textPass.UseSystemPasswordChar = $true
    $textPass.Location = New-Object System.Drawing.Point(18, 96)
    $textPass.Size = New-Object System.Drawing.Size(390, 24)
    $textPass.BackColor = $script:ColorBgList
    $textPass.ForeColor = $script:ColorTextMain
    $textPass.BorderStyle = 'FixedSingle'
    $dialog.Controls.Add($textPass)

    $labelHint = New-Object System.Windows.Forms.Label
    $labelHint.Text = 'Operazione riservata agli amministratori del PC.'
    $labelHint.Location = New-Object System.Drawing.Point(18, 128)
    $labelHint.ForeColor = $script:ColorTextMuted
    $dialog.Controls.Add($labelHint)

    $ok = New-ThemedButton -Text 'Applica password' -BackColor $script:ColorAccent -ForeColor $script:ColorBgMain
    $ok.Location = New-Object System.Drawing.Point(18, 158)
    $ok.Size = New-Object System.Drawing.Size(190, 32)
    $ok.Add_Click({
        if (Set-LocalUserPassword -Username $textUser.Text -NewPassword $textPass.Text) {
            [void](Show-Message -Text 'Password aggiornata con successo.' -Caption 'CyberMedic - Cambio password' -Kind 'Info')
            $dialog.Close()
        } else {
            [void](Show-Message -Text 'Cambio password non riuscito.`r`nVerificare che la sessione sia elevata e che il nome utente sia corretto.' -Caption 'CyberMedic - Cambio password' -Kind 'Error')
        }
    })
    $dialog.Controls.Add($ok)

    $cancel = New-ThemedButton -Text 'Annulla' -BackColor $script:ColorPanel -ForeColor $script:ColorTextMain
    $cancel.Location = New-Object System.Drawing.Point(218, 158)
    $cancel.Size = New-Object System.Drawing.Size(190, 32)
    $cancel.Add_Click({ $dialog.Close() })
    $dialog.Controls.Add($cancel)

    [void]$dialog.ShowDialog()
    $dialog.Dispose()
}

function New-DashboardForm {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = Get-ProductTitle -Long
    $form.StartPosition = 'CenterScreen'
    $form.MinimumSize = New-Object System.Drawing.Size(1050, 680)
    $form.Size = New-Object System.Drawing.Size(1320, 860)
    $form.Font = Get-FluentFont -Size 9
    $form.BackColor = $script:ColorBgMain
    $form.ForeColor = $script:ColorTextMain
    try {
        # Sfondo a gradiente (effetto mica) in stile WinUI 3.
        $form.BackgroundImage = New-FluentBackgroundImage
        $form.BackgroundImageLayout = [System.Windows.Forms.ImageLayout]::Tile
    } catch { }

    $split = New-Object System.Windows.Forms.SplitContainer
    $split.Dock = 'Fill'
    $split.Orientation = 'Vertical'
    $split.BackColor = $script:ColorBgMain
    $split.Panel1.BackColor = $script:ColorBgMain
    $split.Panel2.BackColor = $script:ColorBgMain
    try { $split.Panel1MinSize = 420; $split.Panel2MinSize = 420 } catch { }

    $mainTabs = New-Object System.Windows.Forms.TabControl
    $mainTabs.Dock = 'Fill'
    $mainTabs.BackColor = $script:ColorBgMain
    $mainTabs.ForeColor = $script:ColorTextMain
    $mainTabs.Padding = New-Object System.Drawing.Point(16, 6)
    $mainTabs.Font = Get-FluentFont -Size 9.5 -Bold
    Enable-FluentTabs -TabControl $mainTabs
    $form.Controls.Add($mainTabs)

    $bottomPanel = New-Object System.Windows.Forms.Panel
    $bottomPanel.Dock = 'Bottom'
    $bottomPanel.Height = 48
    $bottomPanel.BackColor = $script:ColorPanel
    $bottomPanel.Padding = New-Object System.Windows.Forms.Padding(6, 6, 6, 6)
    $form.Controls.Add($bottomPanel)

    $toolbar = New-Object System.Windows.Forms.FlowLayoutPanel
    $toolbar.Dock = 'Top'
    $toolbar.Height = 92
    $toolbar.BackColor = $script:ColorBgMain
    $toolbar.ForeColor = $script:ColorTextMain
    $toolbar.WrapContents = $true
    $toolbar.AutoScroll = $true
    $toolbar.Padding = New-Object System.Windows.Forms.Padding(6, 6, 6, 4)

    $menu = New-Object System.Windows.Forms.MenuStrip
    $menu.Dock = 'Top'
    $menu.BackColor = $script:ColorPanel
    $menu.ForeColor = $script:ColorTextMain
    $menu.RenderMode = 'Professional'
    $form.Controls.Add($menu)

    # --- COMMAND BAR (intestazione in stile WinUI 3) ----------------------
    $commandBar = New-Object System.Windows.Forms.Panel
    $commandBar.Dock = 'Top'
    $commandBar.Height = 56
    $commandBar.BackColor = $script:ColorBgMain
    $form.Controls.Add($commandBar)

    $header = New-Object System.Windows.Forms.Label
    $header.Text = ("  {0}" -f (Get-ProductTitle -Long))
    $header.Font = Get-FluentFont -Size 13 -Bold
    $header.ForeColor = $script:ColorAccent
    $header.BackColor = $script:ColorBgMain
    $header.Dock = 'Top'
    $header.Height = 30
    $header.TextAlign = 'MiddleLeft'
    $commandBar.Controls.Add($header)

    $headerSubtitle = New-Object System.Windows.Forms.Label
    $headerSubtitle.Text = ("  {0}" -f $script:AppSlogan)
    $headerSubtitle.Font = Get-FluentFont -Size 9
    $headerSubtitle.ForeColor = $script:ColorTextMuted
    $headerSubtitle.BackColor = $script:ColorBgMain
    $headerSubtitle.Dock = 'Top'
    $headerSubtitle.Height = 20
    $headerSubtitle.TextAlign = 'MiddleLeft'
    $commandBar.Controls.Add($headerSubtitle)

    $accentLine = New-Object System.Windows.Forms.Panel
    $accentLine.Dock = 'Bottom'
    $accentLine.Height = 2
    $accentLine.BackColor = $script:ColorAccent
    $commandBar.Controls.Add($accentLine)

    $fileMenu = New-Object System.Windows.Forms.ToolStripMenuItem('&File')
    [void]$fileMenu.DropDownItems.Add((New-MenuItem 'Esporta report CSV' { Invoke-Safe -Context 'Esportazione CSV' -Action { Invoke-ActionExportReport } }))
    [void]$fileMenu.DropDownItems.Add((New-MenuItem 'Esporta report diagnostico completo' { Invoke-Safe -Context 'Esportazione report' -Action { Invoke-ActionExportDiagnostic } }))
    [void]$fileMenu.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    [void]$fileMenu.DropDownItems.Add((New-MenuItem 'Apri cartella log' {
        Start-Process -FilePath 'explorer.exe' -ArgumentList ('"{0}"' -f (Split-Path -Path $script:LogFile -Parent)) -ErrorAction Stop
    }))
    [void]$fileMenu.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    [void]$fileMenu.DropDownItems.Add((New-MenuItem 'Esci' { Invoke-ActionExit }))
    [void]$menu.Items.Add($fileMenu)

    $actionMenu = New-Object System.Windows.Forms.ToolStripMenuItem('&Azioni')
    [void]$actionMenu.DropDownItems.Add((New-MenuItem 'Aggiorna elenco' { Invoke-Safe -Context 'Aggiornamento elenco' -Action { Invoke-Refresh } }))
    [void]$actionMenu.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    [void]$actionMenu.DropDownItems.Add((New-MenuItem 'Imposta come predefinita' { Invoke-Safe -Context 'Impostazione predefinita' -Action { Invoke-ActionSetDefault } }))
    [void]$actionMenu.DropDownItems.Add((New-MenuItem 'Pulisci coda stampante' { Invoke-Safe -Context 'Pulizia coda' -Action { Invoke-ActionClearQueue } }))
    [void]$actionMenu.DropDownItems.Add((New-MenuItem 'Svuota spooler (tutte le code)' { Invoke-Safe -Context 'Svuotamento spooler' -Action { Invoke-ActionPurgeSpooler } }))
    [void]$actionMenu.DropDownItems.Add((New-MenuItem 'Riavvia servizio Spooler' {
        Invoke-Safe -Context 'Riavvio Spooler' -Action {
            Set-BusyState -Busy $true -Message 'Riavvio spooler in corso...'
            try { $r = Invoke-SpoolerAction -Action Restart } finally { Set-BusyState -Busy $false -Message 'Pronto' }
            [void](Show-Message -Text $r.Message -Caption $script:AppName -Kind $(if ($r.Success) { 'Info' } else { 'Error' }))
        }
    }))
    [void]$actionMenu.DropDownItems.Add((New-MenuItem 'Pagina di prova' { Invoke-Safe -Context 'Pagina di prova' -Action { Invoke-ActionTestPage } }))
    [void]$actionMenu.DropDownItems.Add((New-MenuItem 'Modifica indirizzo IP' { Invoke-Safe -Context 'Modifica IP' -Action { Invoke-ActionEditIp } }))
    [void]$actionMenu.DropDownItems.Add((New-MenuItem 'Apri coda di stampa (GUI Windows)' {
        Invoke-Safe -Context 'Apertura coda' -Action {
            $p = Get-SelectedPrinterOrWarn
            if (-not $p) { return }
            [void](Open-PrinterQueueWindow -TargetPrinter $p.Name)
        }
    }))
    [void]$actionMenu.DropDownItems.Add((New-MenuItem 'Elimina stampante' { Invoke-Safe -Context 'Eliminazione stampante' -Action { Invoke-ActionRemovePrinter } }))
    [void]$menu.Items.Add($actionMenu)

    $toolsMenu = New-Object System.Windows.Forms.ToolStripMenuItem('&Strumenti')
    [void]$toolsMenu.DropDownItems.Add((New-MenuItem 'Esegui test di rete' { Invoke-Safe -Context 'Test di rete' -Action { Invoke-NetworkTest } }))
    [void]$toolsMenu.DropDownItems.Add((New-MenuItem 'Cerca driver del modello' { Invoke-Safe -Context 'Ricerca driver' -Action { Invoke-ActionFindDriver } }))
    [void]$toolsMenu.DropDownItems.Add((New-MenuItem 'Apri WebAdmin della stampante' { Invoke-Safe -Context 'WebAdmin' -Action { Invoke-ActionWebAdmin } }))
    [void]$toolsMenu.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    [void]$toolsMenu.DropDownItems.Add((New-MenuItem 'Esegui elevazione amministratore' {
        Invoke-Safe -Context 'Elevazione' -Action {
            if ((Get-AdminState).IsElevated) { throw "La sessione e' gia' elevata." }
            if (-not (Request-Elevation)) { throw 'Elevazione non riuscita: eseguire launch.ps1 come amministratore.' }
            Invoke-ActionExit
        }
    }))
    [void]$menu.Items.Add($toolsMenu)

    $helpMenu = New-Object System.Windows.Forms.ToolStripMenuItem('&Aiuto')
    [void]$helpMenu.DropDownItems.Add((New-MenuItem 'Informazioni' {
        [void](Show-Message -Text ("{0}`r`nBuild {1}`r`nPowerShell {2}`r`nLog: {3}" -f (Get-ProductTitle -Long), $script:AppBuild, $PSVersionTable.PSVersion, $script:LogFile) -Caption $script:AppName -Kind 'Info')
    }))
    [void]$menu.Items.Add($helpMenu)

    $buttons = @(
        @{ Text = '🔄 Aggiorna'; Action = { Invoke-Safe -Context 'Aggiornamento elenco' -Action { Invoke-Refresh } } },
        @{ Text = '⭐ Predefinita'; Action = { Invoke-Safe -Context 'Impostazione predefinita' -Action { Invoke-ActionSetDefault } } },
        @{ Text = '🧹 Pulisci Coda'; Action = { Invoke-Safe -Context 'Pulizia coda' -Action { Invoke-ActionClearQueue } } },
        @{ Text = '⚙️ Svuota Spooler'; Action = { Invoke-Safe -Context 'Svuotamento spooler' -Action { Invoke-ActionPurgeSpooler } } },
        @{ Text = '📡 Test di Rete'; Action = { Invoke-Safe -Context 'Test di rete' -Action { Invoke-NetworkTest } } },
        @{ Text = '✏️ Modifica IP'; Action = { Invoke-Safe -Context 'Modifica IP' -Action { Invoke-ActionEditIp } } },
        @{ Text = '📄 Pagina di Prova'; Action = { Invoke-Safe -Context 'Pagina di prova' -Action { Invoke-ActionTestPage } } },
        @{ Text = '🔍 Cerca Driver'; Action = { Invoke-Safe -Context 'Ricerca driver' -Action { Invoke-ActionFindDriver } } },
        @{ Text = '🌐 WebAdmin'; Action = { Invoke-Safe -Context 'WebAdmin' -Action { Invoke-ActionWebAdmin } } },
        @{ Text = '📊 Esporta Report'; Action = { Invoke-Safe -Context 'Esportazione report' -Action { Invoke-ActionExportReport } } },
@{ Text = '🗑️ Elimina'; Action = { Invoke-Safe -Context 'Eliminazione stampante' -Action { Invoke-ActionRemovePrinter } } },
@{ Text = '🔀 Cambia Modalità'; Action = { Invoke-Safe -Context 'Cambio modalità' -Action { $launcher = Join-Path $PSScriptRoot "launch-v3.5.ps1"; if (Test-Path $launcher) { Start-Process "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$launcher`""; Invoke-ActionExit } else { Show-Message -Text "Launcher non trovato in $launcher" -Kind Error } } } }
)
    foreach ($definition in $buttons) {
        $button = New-ThemedButton -Text $definition.Text -BackColor $script:ColorPanel -ForeColor $script:ColorTextMain
        if ($definition.Text -like '🗑️*') { $button.ForeColor = $script:ColorError }
        if ($definition.Text -like '🔄*' -or $definition.Text -like '📡*') { $button.ForeColor = $script:ColorAccent }
        $button.Add_Click($definition.Action)
        $toolbar.Controls.Add($button)
    }

    $list = New-ThemedListView -OwnerDrawHeader
    foreach ($definition in $script:PrinterListColumns) {
        [void]$list.Columns.Add($definition.Title, $definition.Width)
    }
    $list.Add_SizeChanged({ Sync-PrinterListColumnWidths })
    $list.Add_SelectedIndexChanged({
        if ($script:Ui.PrinterList.SelectedItems.Count -eq 0) { return }
        $item = $script:Ui.PrinterList.SelectedItems[0]
        if ($item.Tag) {
            $script:SelectedPrinter = $item.Tag
            $script:SelectedPrinterName = $item.Tag.Name
        } else {
            $script:SelectedPrinterName = $item.Text
        }
        Show-PrinterDetails
        Show-PrinterJobs
        Show-NetworkTab
        Show-LiveCard
    })
    $split.Panel1.Controls.Add($list)

    $tabs = New-Object System.Windows.Forms.TabControl
    $tabs.Dock = 'Fill'
    $tabs.BackColor = $script:ColorBgMain
    $tabs.ForeColor = $script:ColorTextMain
    $tabs.Padding = New-Object System.Drawing.Point(14, 6)

    $tabCard = New-Object System.Windows.Forms.TabPage('📊 Card')
    $tabCard.BackColor = $script:ColorPanel
    $tabCard.ForeColor = $script:ColorAccent
    $cardBox = New-Object System.Windows.Forms.TextBox
    $cardBox.Multiline = $true
    $cardBox.ReadOnly = $true
    $cardBox.ScrollBars = 'Vertical'
    $cardBox.BackColor = $script:ColorCardBg
    $cardBox.ForeColor = $script:ColorSuccess
    $cardBox.Font = New-Object System.Drawing.Font('Consolas', 9.5)
    $cardBox.Dock = 'Fill'
    $cardBox.BorderStyle = 'None'
    $tabCard.Controls.Add($cardBox)

    $tabDetails = New-Object System.Windows.Forms.TabPage('🔍 Dettagli')
    $tabDetails.BackColor = $script:ColorPanel
    $tabDetails.ForeColor = $script:ColorAccent
    $detailList = New-ThemedListView
    [void]$detailList.Columns.Add('Campo', 170)
    [void]$detailList.Columns.Add('Valore', 360)
    $tabDetails.Controls.Add($detailList)

    $tabNetwork = New-Object System.Windows.Forms.TabPage('📡 Rete')
    $tabNetwork.BackColor = $script:ColorPanel
    $tabNetwork.ForeColor = $script:ColorAccent
    $netPanel = New-Object System.Windows.Forms.Panel
    $netPanel.Dock = 'Fill'
    $netPanel.BackColor = $script:ColorPanel
    $netBox = New-Object System.Windows.Forms.TextBox
    $netBox.Multiline = $true
    $netBox.ReadOnly = $true
    $netBox.ScrollBars = 'Vertical'
    $netBox.Dock = 'Fill'
    $netBox.BackColor = $script:ColorCardBg
    $netBox.ForeColor = $script:ColorSuccess
    $netBox.Font = New-Object System.Drawing.Font('Consolas', 9.5)
    $netBox.BorderStyle = 'None'
    $netPanel.Controls.Add($netBox)
    $netButton = New-ThemedButton -Text '📡 Esegui test di rete' -BackColor $script:ColorPanel -ForeColor $script:ColorAccent
    $netButton.Dock = 'Top'
    $netButton.Add_Click({ Invoke-Safe -Context 'Test di rete' -Action { Invoke-NetworkTest } })
    $netPanel.Controls.Add($netButton)
    $tabNetwork.Controls.Add($netPanel)

    $tabJobs = New-Object System.Windows.Forms.TabPage('🧾 Lavori')
    $tabJobs.BackColor = $script:ColorPanel
    $tabJobs.ForeColor = $script:ColorAccent
    $jobList = New-ThemedListView
    [void]$jobList.Columns.Add('ID', 50)
    [void]$jobList.Columns.Add('Utente', 120)
    [void]$jobList.Columns.Add('Documento', 230)
    [void]$jobList.Columns.Add('Stato', 100)
    [void]$jobList.Columns.Add('Dimensione', 90)
    [void]$jobList.Columns.Add('Inviato', 155)
    $tabJobs.Controls.Add($jobList)

    $tabLog = New-Object System.Windows.Forms.TabPage('📜 Registro')
    $tabLog.BackColor = $script:ColorPanel
    $tabLog.ForeColor = $script:ColorAccent
    $logPanel = New-Object System.Windows.Forms.Panel
    $logPanel.Dock = 'Fill'
    $logPanel.BackColor = $script:ColorPanel
    $logBox = New-Object System.Windows.Forms.TextBox
    $logBox.Multiline = $true
    $logBox.ReadOnly = $true
    $logBox.ScrollBars = 'Both'
    $logBox.WordWrap = $false
    $logBox.Dock = 'Fill'
    $logBox.BackColor = $script:ColorCardBg
    $logBox.ForeColor = $script:ColorTextMain
    $logBox.Font = New-Object System.Drawing.Font('Consolas', 9)
    $logBox.BorderStyle = 'None'
    $logPanel.Controls.Add($logBox)
    $logButtons = New-Object System.Windows.Forms.FlowLayoutPanel
    $logButtons.Dock = 'Top'
    $logButtons.Height = 40
    $logButtons.BackColor = $script:ColorPanel
    $btnCopy = New-ThemedButton -Text 'Copia registro' -BackColor $script:ColorPanel -ForeColor $script:ColorTextMain
    $btnCopy.Add_Click({
        Invoke-Safe -Context 'Copia registro' -Action {
            [System.Windows.Forms.Clipboard]::SetText($script:Ui.LogBox.Text)
            [void](Show-Message -Text 'Registro copiato negli appunti.' -Caption $script:AppName -Kind 'Info')
        }
    })
    $logButtons.Controls.Add($btnCopy)
    $btnSaveLog = New-ThemedButton -Text 'Salva registro' -BackColor $script:ColorPanel -ForeColor $script:ColorTextMain
    $btnSaveLog.Add_Click({
        Invoke-Safe -Context 'Salva registro' -Action {
            $path = Join-Path -Path $script:LogDirectory -ChildPath ("registro-{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
            Set-Content -LiteralPath $path -Value $script:Ui.LogBox.Text -Encoding UTF8 -ErrorAction Stop
            [void](Show-Message -Text ("Registro salvato in {0}" -f $path) -Caption $script:AppName -Kind 'Info')
        }
    })
    $logButtons.Controls.Add($btnSaveLog)
    $btnClearLog = New-ThemedButton -Text 'Pulisci registro' -BackColor $script:ColorPanel -ForeColor $script:ColorTextMain
    $btnClearLog.Add_Click({ $script:Ui.LogBox.Clear() })
    $logButtons.Controls.Add($btnClearLog)
    $logPanel.Controls.Add($logButtons)
    $tabLog.Controls.Add($logPanel)

    [void]$tabs.TabPages.Add($tabCard)
    [void]$tabs.TabPages.Add($tabDetails)
    [void]$tabs.TabPages.Add($tabNetwork)
    [void]$tabs.TabPages.Add($tabJobs)
    [void]$tabs.TabPages.Add($tabLog)
    $split.Panel2.Controls.Add($tabs)

    # ------------------------------------------------------------------------
    # SCHEDA 1 - HOME / DASHBOARD DI SICUREZZA
    # ------------------------------------------------------------------------
    $tabHome = New-Object System.Windows.Forms.TabPage('  🛡️  Home / Dashboard  ')
    $tabHome.BackColor = $script:ColorBgMain
    $tabHome.ForeColor = $script:ColorAccent
    $tabHome.Padding = New-Object System.Windows.Forms.Padding(8)
    $mainTabs.TabPages.Add($tabHome)

    $homeBox = New-Object System.Windows.Forms.TextBox
    $homeBox.Multiline = $true
    $homeBox.ReadOnly = $true
    $homeBox.ScrollBars = 'Vertical'
    $homeBox.BackColor = $script:ColorCardBg
    $homeBox.ForeColor = $script:ColorTextMain
    $homeBox.Font = New-Object System.Drawing.Font('Consolas', 10)
    $homeBox.Dock = 'Fill'
    $homeBox.BorderStyle = 'None'
    $tabHome.Controls.Add($homeBox)

    $homeBar = New-Object System.Windows.Forms.FlowLayoutPanel
    $homeBar.Dock = 'Top'
    $homeBar.Height = 48
    $homeBar.BackColor = $script:ColorBgMain
    $homeBar.Padding = New-Object System.Windows.Forms.Padding(0, 0, 0, 6)
    $btnRefreshHome = New-ThemedButton -Text '🛡️ Aggiorna Dashboard' -BackColor $script:ColorAccent -ForeColor $script:ColorBgMain
    $btnRefreshHome.Add_Click({
        Invoke-Safe -Context 'Aggiornamento dashboard' -Action {
            Set-BusyState -Busy $true -Message 'Raccolta dati di sistema...'
            try {
                $script:Ui.HomeBox.Text = Get-HomeDashboardReport
                Update-StatusBar 'Dashboard di sicurezza aggiornata.'
            } finally {
                Set-BusyState -Busy $false -Message 'Pronto'
            }
        }
    })
    $homeBar.Controls.Add($btnRefreshHome)
    $tabHome.Controls.Add($homeBar)

    # --- RIQUADRO OFFICE E LICENZE (v3.0) ----------------------------------
    $officeGroup = New-Object System.Windows.Forms.GroupBox
    $officeGroup.Text = '  🔑  Office e licenze  '
    $officeGroup.Dock = 'Right'
    $officeGroup.Width = 440
    $officeGroup.BackColor = $script:ColorPanel
    $officeGroup.ForeColor = $script:ColorAccent
    $officeGroup.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

    $officeInner = New-Object System.Windows.Forms.FlowLayoutPanel
    $officeInner.Dock = 'Fill'
    $officeInner.FlowDirection = 'TopDown'
    $officeInner.WrapContents = $false
    $officeInner.AutoScroll = $true
    $officeInner.BackColor = $script:ColorPanel
    $officeInner.Padding = New-Object System.Windows.Forms.Padding(12, 10, 12, 10)
    $officeGroup.Controls.Add($officeInner)

    $officeHint = New-Object System.Windows.Forms.Label
    $officeHint.Text = 'Product key Office (XXXXX-XXXXX-XXXXX-XXXXX-XXXXX):'
    $officeHint.ForeColor = $script:ColorTextMain
    $officeHint.Size = New-Object System.Drawing.Size(400, 22)
    $officeInner.Controls.Add($officeHint)

    $officeKey = New-Object System.Windows.Forms.TextBox
    $officeKey.Width = 380
    $officeKey.BackColor = $script:ColorCardBg
    $officeKey.ForeColor = $script:ColorSuccess
    $officeKey.Font = New-Object System.Drawing.Font('Consolas', 10)
    $officeKey.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 8)
    $officeInner.Controls.Add($officeKey)

    $btnOfficeKey = New-ThemedButton -Text '🔑 Installa e attiva chiave' -BackColor $script:ColorSuccess -ForeColor $script:ColorBgMain
    $btnOfficeKey.Width = 250
    $btnOfficeKey.Add_Click({
        Invoke-Safe -Context 'Licenza Office' -Action {
            $key = ''
            if ($script:Ui.OfficeKey) { $key = $script:Ui.OfficeKey.Text }
            $result = Set-OfficeProductKey -LicenseKey $key
            if ($script:Ui.OfficeOutput) {
                $script:Ui.OfficeOutput.Text = ($result.Message + [Environment]::NewLine + $result.Output)
            }
            if ($result.Success) {
                Update-StatusBar $result.Message
            } else {
                [void](Show-Message -Text $result.Message -Caption $script:AppName -Kind 'Warning')
            }
        }
    })
    $officeInner.Controls.Add($btnOfficeKey)

    $btnOfficeLicense = New-ThemedButton -Text '📜 Stato licenze Office' -BackColor $script:ColorPanel -ForeColor $script:ColorTextMain
    $btnOfficeLicense.Width = 250
    $btnOfficeLicense.Add_Click({
        Invoke-Safe -Context 'Stato licenze Office' -Action {
            $result = Get-OfficeLicenseStatus
            if ($script:Ui.OfficeOutput) {
                $script:Ui.OfficeOutput.Text = ($result.Message + [Environment]::NewLine + $result.Output)
            }
            Update-StatusBar $result.Message
        }
    })
    $officeInner.Controls.Add($btnOfficeLicense)

    $btnOfficeRemove = New-ThemedButton -Text '🧹 Rimuovi Office' -BackColor $script:ColorPanel -ForeColor $script:ColorError
    $btnOfficeRemove.Width = 250
    $btnOfficeRemove.Add_Click({
        Invoke-Safe -Context 'Rimozione Office' -Action {
            $plan = Remove-OfficeCompletely
            $planText = (@($plan.Details) -join [Environment]::NewLine)
            if ($script:Ui.OfficeOutput) {
                $script:Ui.OfficeOutput.Text = ($plan.Message + [Environment]::NewLine + $planText)
            }
            if (@($plan.Details).Count -eq 0) {
                Update-StatusBar $plan.Message
                return
            }
            $answer = Show-Message -Text ("{0}`r`n`r`n{1}`r`n`r`nAvviare i disinstallatori ufficiali Microsoft?" -f $plan.Message, $planText) -Caption $script:AppName -Kind 'Question'
            if ($answer -eq [System.Windows.Forms.DialogResult]::Yes) {
                $executed = Remove-OfficeCompletely -Execute
                if ($script:Ui.OfficeOutput) {
                    $script:Ui.OfficeOutput.Text = ($executed.Message + [Environment]::NewLine + (@($executed.Details) -join [Environment]::NewLine))
                }
                Update-StatusBar $executed.Message
            }
        }
    })
    $officeInner.Controls.Add($btnOfficeRemove)

    $officeOutput = New-Object System.Windows.Forms.TextBox
    $officeOutput.Multiline = $true
    $officeOutput.ReadOnly = $true
    $officeOutput.ScrollBars = 'Vertical'
    $officeOutput.Width = 390
    $officeOutput.Height = 190
    $officeOutput.Margin = New-Object System.Windows.Forms.Padding(0, 10, 0, 0)
    $officeOutput.BackColor = $script:ColorCardBg
    $officeOutput.ForeColor = $script:ColorSuccess
    $officeOutput.Font = New-Object System.Drawing.Font('Consolas', 8.5)
    $officeOutput.BorderStyle = 'None'
    $officeInner.Controls.Add($officeOutput)

    $tabHome.Controls.Add($officeGroup)

    # ------------------------------------------------------------------------
    # SCHEDA 2 - GESTIONE STAMPANTI (suite v1.4)
    # ------------------------------------------------------------------------
    $tabPrinters = New-Object System.Windows.Forms.TabPage('  🖨️  Gestione Stampanti  ')
    $tabPrinters.BackColor = $script:ColorBgMain
    $tabPrinters.ForeColor = $script:ColorAccent
    $tabPrinters.Padding = New-Object System.Windows.Forms.Padding(6)
    $mainTabs.TabPages.Add($tabPrinters)
    $tabPrinters.Controls.Add($split)
    $tabPrinters.Controls.Add($toolbar)

    # ------------------------------------------------------------------------
    # SCHEDA 3 - NETWORK & RETE
    # ------------------------------------------------------------------------
    $tabNet = New-Object System.Windows.Forms.TabPage('  📡  Network & Rete  ')
    $tabNet.BackColor = $script:ColorBgMain
    $tabNet.ForeColor = $script:ColorAccent
    $tabNet.Padding = New-Object System.Windows.Forms.Padding(8)
    $mainTabs.TabPages.Add($tabNet)

    $netOutput = New-Object System.Windows.Forms.TextBox
    $netOutput.Multiline = $true
    $netOutput.ReadOnly = $true
    $netOutput.ScrollBars = 'Both'
    $netOutput.WordWrap = $false
    $netOutput.BackColor = $script:ColorCardBg
    $netOutput.ForeColor = $script:ColorSuccess
    $netOutput.Font = New-Object System.Drawing.Font('Consolas', 9.5)
    $netOutput.Dock = 'Fill'
    $netOutput.BorderStyle = 'None'
    $tabNet.Controls.Add($netOutput)

    # --- SOTTOSEZIONE DEDICATA AI SERVIZI E GESTIONE DNS ---
    $dnsGroup = New-Object System.Windows.Forms.GroupBox
    $dnsGroup.Text = '  🌐  Servizi e gestione DNS  '
    $dnsGroup.Dock = 'Top'
    $dnsGroup.Height = 104
    $dnsGroup.BackColor = $script:ColorPanel
    $dnsGroup.ForeColor = $script:ColorAccent
    $dnsGroup.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $tabNet.Controls.Add($dnsGroup)

    $dnsInner = New-Object System.Windows.Forms.FlowLayoutPanel
    $dnsInner.Dock = 'Fill'
    $dnsInner.WrapContents = $true
    $dnsInner.BackColor = $script:ColorPanel
    $dnsInner.Padding = New-Object System.Windows.Forms.Padding(10, 6, 10, 6)
    $dnsGroup.Controls.Add($dnsInner)

    $dnsLabel = New-Object System.Windows.Forms.Label
    $dnsLabel.Text = 'Dominio:'
    $dnsLabel.ForeColor = $script:ColorTextMuted
    $dnsLabel.AutoSize = $true
    $dnsLabel.Margin = New-Object System.Windows.Forms.Padding(8, 9, 4, 0)
    $dnsInner.Controls.Add($dnsLabel)

    $dnsDomain = New-Object System.Windows.Forms.TextBox
    $dnsDomain.Text = 'google.com'
    $dnsDomain.Width = 210
    $dnsDomain.BackColor = $script:ColorCardBg
    $dnsDomain.ForeColor = $script:ColorTextMain
    $dnsDomain.BorderStyle = 'FixedSingle'
    $dnsDomain.Margin = New-Object System.Windows.Forms.Padding(0, 6, 8, 0)
    $dnsInner.Controls.Add($dnsDomain)

    $btnDisplayDns = New-ThemedButton -Text '🔎 Cache DNS (/displaydns)' -BackColor $script:ColorPanel -ForeColor $script:ColorTextMain
    $btnDisplayDns.Add_Click({
        Invoke-Safe -Context 'Cache DNS' -Action {
            $script:Ui.NetBox.Text = 'Lettura della cache del resolver DNS (ipconfig /displaydns)...'
            [void](Start-BackgroundCommand -FilePath 'ipconfig.exe' -Arguments @('/displaydns') -OnComplete {
                param($text, $exitCode, $cmdArgs)
                $script:Ui.NetBox.Text = ("ipconfig /displaydns (exit code {0})`r`n{1}" -f $exitCode, $text)
                Update-StatusBar ("Cache DNS letta (exit {0})." -f $exitCode)
            })
            Update-StatusBar 'Lettura cache DNS in esecuzione...'
        }
    })
    $dnsInner.Controls.Add($btnDisplayDns)

    $btnFlushDns = New-ThemedButton -Text '🧹 Pulisci cache DNS (/flushdns)' -BackColor $script:ColorPanel -ForeColor $script:ColorWarning
    $btnFlushDns.Add_Click({
        Invoke-Safe -Context 'Pulizia cache DNS' -Action {
            $script:Ui.NetBox.Text = 'Pulizia della cache del resolver DNS (ipconfig /flushdns)...'
            [void](Start-BackgroundCommand -FilePath 'ipconfig.exe' -Arguments @('/flushdns') -OnComplete {
                param($text, $exitCode, $cmdArgs)
                $script:Ui.NetBox.Text = ("ipconfig /flushdns (exit code {0})`r`n{1}" -f $exitCode, $text)
                Update-StatusBar ("Cache DNS ripulita (exit {0})." -f $exitCode)
            })
            Update-StatusBar 'Pulizia cache DNS in esecuzione...'
        }
    })
    $dnsInner.Controls.Add($btnFlushDns)

    $btnTestDns = New-ThemedButton -Text '🌐 Test risoluzione (nslookup)' -BackColor $script:ColorPanel -ForeColor $script:ColorSuccess
    $btnTestDns.Add_Click({
        Invoke-Safe -Context 'Test risoluzione DNS' -Action {
            $domain = $script:Ui.DnsDomain.Text
            if ([string]::IsNullOrWhiteSpace($domain)) { $domain = 'google.com' }
            $script:Ui.NetBox.Text = ("Test di risoluzione DNS in corso: {0} ..." -f $domain)
            $lookup = Get-DnsLookupCommand -Domain $domain
            [void](Start-BackgroundCommand -FilePath $lookup.FilePath -Arguments $lookup.Arguments -OnComplete {
                param($text, $exitCode, $cmdArgs)
                $script:Ui.NetBox.Text = ("{0} (exit code {1})`r`n{2}" -f ($cmdArgs -join ' '), $exitCode, $text)
                Update-StatusBar ("Risoluzione {0} completata (exit {1})." -f ($cmdArgs -join ' '), $exitCode)
            })
            Update-StatusBar ("Risoluzione DNS in esecuzione: {0}" -f $domain)
        }
    })
    $dnsInner.Controls.Add($btnTestDns)

    # Gli strumenti di rete (ipconfig, Wi-Fi, Wireshark, Nmap) sono passati
    # nella scheda Cybersecurity, dentro la card "Strumenti di rete".
    $netBar = New-Object System.Windows.Forms.FlowLayoutPanel
    $netBar.Dock = 'Top'
    $netBar.Height = 48
    $netBar.BackColor = $script:ColorBgMain
    $netBar.Padding = New-Object System.Windows.Forms.Padding(0, 0, 0, 6)
    $tabNet.Controls.Add($netBar)

    $netHint = New-Object System.Windows.Forms.Label
    $netHint.Text = 'Diagnostica DNS e cache del resolver. Gli strumenti di rete (Wi-Fi, ipconfig, Wireshark, Nmap) si trovano nella scheda Cybersecurity.'
    $netHint.ForeColor = $script:ColorTextMuted
    $netHint.Font = Get-FluentFont -Size 9
    $netHint.AutoSize = $false
    $netHint.Height = 26
    $netHint.Width = 900
    $netBar.Controls.Add($netHint)

    $btnClearNet = New-ThemedButton -Text '🧹 Clear Output' -BackColor $script:ColorPanel -ForeColor $script:ColorError
    $btnClearNet.Add_Click({ $script:Ui.NetBox.Clear() })
    $netBar.Controls.Add($btnClearNet)

    # ------------------------------------------------------------------------
    # SCHEDE MODULARI (Task Manager, Updates, Maintenance, Mail, CyberMedic)
    # ------------------------------------------------------------------------
    [void](New-TaskManagerTab -MainTabs $mainTabs)
    [void](New-UpdatesTab -MainTabs $mainTabs)
    [void](New-MaintenanceTab -MainTabs $mainTabs)
    [void](New-MailTab -MainTabs $mainTabs)
    [void](New-CybersecurityTab -MainTabs $mainTabs)
    # ------------------------------------------------------------------------

    $bottomLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $bottomLayout.Dock = 'Fill'
    $bottomLayout.ColumnCount = 2
    $bottomLayout.RowCount = 1
    $bottomLayout.BackColor = $script:ColorPanel
    [void]$bottomLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    [void]$bottomLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize)))
    [void]$bottomLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $bottomPanel.Controls.Add($bottomLayout)

    $status = New-Object System.Windows.Forms.StatusStrip
    $status.BackColor = $script:ColorPanel
    $status.ForeColor = $script:ColorTextMuted
    $status.SizingGrip = $false
    $statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel('Inizializzazione...')
    $statusLabel.Spring = $true
    $statusLabel.TextAlign = 'MiddleLeft'
    [void]$status.Items.Add($statusLabel)
    $spoolerLabel = New-Object System.Windows.Forms.ToolStripStatusLabel('Spooler: N/D')
    [void]$status.Items.Add($spoolerLabel)
    $elevLabel = New-Object System.Windows.Forms.ToolStripStatusLabel('Elevato: no')
    [void]$status.Items.Add($elevLabel)
    $bottomLayout.Controls.Add($status, 0, 0)

    $btnExitApp = New-ThemedButton -Text '🛑 Termina Applicazione' -BackColor $script:ColorError -ForeColor $script:ColorBgMain
    $btnExitApp.Margin = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
    $btnExitApp.Add_Click({ Invoke-ActionExit })
    $bottomLayout.Controls.Add($btnExitApp, 1, 0)

    $progress = New-Object System.Windows.Forms.ProgressBar
    $progress.Dock = 'Bottom'
    $progress.Height = 10
    $progress.Style = 'Marquee'
    $progress.Visible = $false
    $form.Controls.Add($progress)

    $script:Ui.Form = $form
    $script:Ui.PrinterList = $list
    $script:Ui.DetailList = $detailList
    $script:Ui.CardBox = $cardBox
    $script:Ui.NetworkBox = $netBox
    $script:Ui.JobList = $jobList
    $script:Ui.LogBox = $logBox
    $script:Ui.StatusLabel = $statusLabel
    $script:Ui.SpoolerLabel = $spoolerLabel
    $script:Ui.ElevLabel = $elevLabel
    $script:Ui.Progress = $progress
    $script:Ui.Tabs = $tabs
    $script:Ui.Split = $split
    $script:Ui.Toolbar = $toolbar
    $script:Ui.ExitButton = $btnExitApp
    $script:Ui.MainTabs = $mainTabs
    $script:Ui.HomeBox = $homeBox
    $script:Ui.NetBox = $netOutput
    $script:Ui.DnsDomain = $dnsDomain
    $script:Ui.OfficeKey = $officeKey
    $script:Ui.OfficeOutput = $officeOutput
    $script:Ui.CommandTimer = New-Object System.Windows.Forms.Timer
    $script:Ui.CommandTimer.Interval = 400
    $script:Ui.CommandTimer.Add_Tick({
        $guard = 0
        while ($script:PendingCommands.Count -gt 0 -and $guard -lt 8) {
            $guard++
            $head = $script:PendingCommands[0]
            try {
                if (-not $head.Process.HasExited) {
                    if (((Get-Date) - $head.Started).TotalSeconds -gt 180) {
                        Write-Log -Message 'Comando in background interrotto: superato il tempo massimo di attesa.' -Level 'WARN'
                        try { $head.Process.Kill() } catch { }
                    }
                    break
                }
            } catch {
                $script:PendingCommands.RemoveAt(0)
                continue
            }
            if (-not (Complete-BackgroundCommand)) { break }
        }
    })
    $script:Ui.CommandTimer.Start()

    $script:Ui.ActivityTimer = New-Object System.Windows.Forms.Timer
    $script:Ui.ActivityTimer.Interval = 2000
    $script:Ui.ActivityTimer.Add_Tick({
        Update-ActivityMetrics
        Update-ActivityLog
        Update-ActivityQueue
    })

    foreach ($entry in $script:LogEntries) {
        try { $logBox.AppendText($entry + [Environment]::NewLine) } catch { }
    }

    $form.Add_Shown({ Initialize-DashboardState })

    $form.Add_FormClosing({
        try { if ($script:Ui.ActivityTimer) { $script:Ui.ActivityTimer.Stop() } } catch { }
        try { if ($script:Ui.CommandTimer) { $script:Ui.CommandTimer.Stop() } } catch { }
    })

    return $form
}

function Initialize-DashboardState {
    try {
        $script:Ui.Split.Panel1MinSize = 420
        $script:Ui.Split.Panel2MinSize = 420
        $script:Ui.Split.SplitterDistance = 760
    } catch {
        Write-Log -Message ("Layout del pannello laterale non ottimizzabile: {0}" -f $_.Exception.Message) -Level 'DEBUG'
    }
    try { Sync-PrinterListColumnWidths } catch { }
    try {
        Invoke-Refresh
        $health = Get-SpoolerHealth
        $script:Ui.SpoolerLabel.Text = ('Spooler: {0} - file in coda: {1}' -f $health.Status, $health.QueueFiles)
        $elevated = (Get-AdminState).IsElevated
        $script:Ui.ElevLabel.Text = ('Elevato: {0}' -f $(if ($elevated) { 'si' } else { 'no' }))
        if (-not $elevated) {
            $script:Ui.StatusLabel.Text = "Sessione NON elevata: svuotamento spooler e riavvio servizio non disponibili."
        }
        if ($script:SelectedPrinter) {
            foreach ($item in $script:Ui.PrinterList.Items) {
                if ($item.Tag -and $item.Tag.Name -eq $script:SelectedPrinter.Name) { $item.Selected = $true; break }
            }
        }
    } catch {
        Write-Log -Message ("Inizializzazione interfaccia non riuscita: {0}" -f $_.Exception.Message) -Level 'ERROR'
    }
    try {
        $script:Ui.HomeBox.Text = Get-HomeDashboardReport
    } catch {
        Write-Log -Message ("Dashboard di sicurezza non disponibile: {0}" -f $_.Exception.Message) -Level 'WARN'
    }
    try {
        Update-ActivityMetrics
        Update-ActivityLog
        Update-ActivityQueue
        if ($script:Ui.ActivityTimer) { $script:Ui.ActivityTimer.Start() }
    } catch {
        Write-Log -Message ("Monitoraggio delle risorse non avviato: {0}" -f $_.Exception.Message) -Level 'WARN'
    }
    try { Show-DriverList } catch { }
    try { Show-OutlookPanel } catch { }
    try { Update-HardwareDiagnostics } catch { }
    # L'elenco degli aggiornamenti parte in background gia' all'avvio: l'utente
    # non deve attendere l'apertura della scheda Updates per vederlo popolato.
    try { Load-UpdatePackages } catch { }
}

function Show-Dashboard {
    try {
        $form = $script:Ui.Form
        if (-not $form) {
            $form = New-DashboardForm
        }
    } catch {
        Write-Log -Message ("Interfaccia non inizializzabile: {0}" -f $_.Exception.Message) -Level 'ERROR'
        [void](Show-Message -Text ("Interfaccia grafica non inizializzabile: {0}" -f $_.Exception.Message) -Caption 'CyberMedic - Errore' -Kind 'Error')
        return
    }
    try {
        [System.Windows.Forms.Application]::Run($form)
    } catch {
        Write-Log -Message ("Errore durante l'esecuzione della GUI: {0}" -f $_.Exception.Message) -Level 'ERROR'
    } finally {
        Write-Log -Message 'Chiusura dell''applicazione.' -Level 'INFO'
    }
}
# ------------------------------------------------------------------------
# DISPATCH DELLA SESSIONE
# ------------------------------------------------------------------------

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
    Write-Error "CyberMedic e' supportato solo su sistemi Windows."
    exit 1
}

if (-not $NoElevation) {
    if (-not (Get-AdminState).IsElevated) {
        Write-Log -Message "Sessione non elevata: il tool continua in modalita' ridotta, con proposta di elevazione." -Level 'WARN'
    }
}

Initialize-Application -LogPath $LogDirectory

if ($SelfTest) {
    Invoke-SelfTest
    exit 0
}

if ($Diagnose) {
    Update-Inventory | Out-Null
    Select-PrinterByName -Name $PrinterName
    if (-not $script:SelectedPrinter -and $script:Inventory.Count -gt 0) {
        $script:SelectedPrinter = $script:Inventory[0]
    }
    Write-Output (Get-DiagnosticReport)
    exit 0
}

if ($PSBoundParameters.ContainsKey('ResolvePort')) {
    $targetPrinter = if ($ResolvePrinter) { $ResolvePrinter } else { 'N/D' }
    $endpoint = Resolve-PrinterEndpoint -PrinterName $targetPrinter -PortName $ResolvePort
    Write-Output ("Porta      : {0}" -f $endpoint.PortName)
    Write-Output ("Tipo       : {0}" -f $endpoint.Kind)
    Write-Output ("Host       : {0}" -f $endpoint.Host)
    Write-Output ("IP         : {0}" -f $endpoint.IpAddress)
    Write-Output ("TCP        : {0}" -f $endpoint.TcpPort)
    Write-Output ("Sorgente   : {0}" -f $endpoint.Source)
    foreach ($note in $endpoint.Notes) { Write-Output ("Nota       : {0}" -f $note) }
    exit 0
}

if ($SmokeTest) {
    try {
        $form = New-DashboardForm
        Initialize-DashboardState
        $tabLabels = @($script:Ui.MainTabs.TabPages | ForEach-Object { $_.Text.Trim() })
        $checks = @(
            @{ Name = 'Schede principali'; Ok = ($script:Ui.MainTabs.TabPages.Count -eq 8); Detail = ($tabLabels -join ' | ') }
            @{ Name = 'Identita in title'; Ok = ($script:Ui.Form.Text -like ("*{0}*" -f $script:AppName) -and $script:Ui.Form.Text -like ("*v{0}*" -f $script:AppVersion)); Detail = $script:Ui.Form.Text }
            @{ Name = 'Dashboard Home'; Ok = (-not [string]::IsNullOrWhiteSpace($script:Ui.HomeBox.Text)); Detail = ("{0} caratteri" -f $script:Ui.HomeBox.Text.Length) }
            @{ Name = 'Elenco stampanti'; Ok = ($script:Ui.PrinterList.Items.Count -ge 0); Detail = ("{0} righe" -f $script:Ui.PrinterList.Items.Count) }
            @{ Name = 'Colonne elenco'; Ok = ($script:Ui.PrinterList.Columns.Count -eq 8); Detail = ("{0} colonne" -f $script:Ui.PrinterList.Columns.Count) }
            @{ Name = 'Dettagli stampante'; Ok = ($script:Ui.DetailList.Items.Count -gt 0); Detail = ("{0} campi" -f $script:Ui.DetailList.Items.Count) }
            @{ Name = 'Schede interne'; Ok = ($script:Ui.Tabs.TabPages.Count -eq 5); Detail = ("{0} schede" -f $script:Ui.Tabs.TabPages.Count) }
            @{ Name = 'Output rete'; Ok = ($null -ne $script:Ui.NetBox); Detail = 'casella di uscita presente' }
            @{ Name = 'Output manutenzione'; Ok = ($null -ne $script:Ui.MaintList); Detail = 'elenco aggiornamenti presente' }
            @{ Name = 'Console manutenzione'; Ok = ($null -ne $script:Ui.MaintenanceConsole); Detail = 'console live presente' }
            @{ Name = 'Elenco driver'; Ok = ($null -ne $script:Ui.DriverList); Detail = ("{0} driver" -f $script:Ui.DriverList.Items.Count) }
            @{ Name = 'Metriche attivita'; Ok = (-not [string]::IsNullOrWhiteSpace($script:Ui.ActivityDetail.Text)); Detail = ("{0} caratteri" -f $script:Ui.ActivityDetail.Text.Length) }
            @{ Name = 'Grafici on demand'; Ok = ($null -ne $script:Ui.ActivityCharts -and $script:Ui.ActivityCharts.Count -eq 3); Detail = ("{0} grafici (CPU, RAM, disco)" -f $script:Ui.ActivityCharts.Count) }
            @{ Name = 'Pulsanti grafici'; Ok = ($null -ne $script:Ui.ActivityChartButtons -and $script:Ui.ActivityChartButtons.Count -eq 3); Detail = ("{0} pulsanti" -f $script:Ui.ActivityChartButtons.Count) }
            @{ Name = 'Toggle in stile WinUI'; Ok = ($null -ne $script:FluentToggles -and $script:FluentToggles.Count -ge 6); Detail = ("{0} toggle attivi" -f $script:FluentToggles.Count) }
            @{ Name = 'Grafico non attivo'; Ok = (-not $script:Ui.ActivityCharts['CPU'].Visible); Detail = 'il grafico CPU parte spento' }
            @{ Name = 'Diagnostica hardware'; Ok = ($null -ne $script:Ui.HardwareReport -and -not [string]::IsNullOrWhiteSpace($script:Ui.HardwareReport.Text)); Detail = ("{0} caratteri" -f $script:Ui.HardwareReport.Text.Length) }
            @{ Name = 'Log attivita'; Ok = ($null -ne $script:Ui.ActivityLog); Detail = 'registro live presente' }
            @{ Name = 'Preset Nmap'; Ok = ($script:Ui.NmapPreset.Items.Count -ge 5); Detail = ("{0} preset" -f $script:Ui.NmapPreset.Items.Count) }
            @{ Name = 'Console Maintenance'; Ok = ($null -ne $script:Ui.MaintenanceOutput); Detail = 'console della scheda Maintenance presente' }
            @{ Name = 'Cestino temporaneo'; Ok = ($null -ne $script:Ui.PrefetchCheck); Detail = 'opzione Prefetch presente' }
            @{ Name = 'Archivi Outlook'; Ok = ($null -ne $script:Ui.OutlookList); Detail = ("{0} righe" -f $script:Ui.OutlookList.Items.Count) }
            @{ Name = 'Console PowerShell'; Ok = ($null -ne $script:Ui.SafePsCommand -and $script:Ui.SafePsCommand.Items.Count -ge 10); Detail = ("{0} comandi consentiti" -f $script:Ui.SafePsCommand.Items.Count) }
            @{ Name = 'Output CyberMedic'; Ok = ($null -ne $script:Ui.CyberOutput); Detail = 'console CyberMedic presente' }
            @{ Name = 'Moduli schede'; Ok = ($script:GuiModules.Count -eq 7); Detail = ($script:GuiModules -join ', ') }
            @{ Name = 'Riquadro Office'; Ok = ($null -ne $script:Ui.OfficeKey -and $null -ne $script:Ui.OfficeOutput); Detail = 'licenza e output Office presenti' }
            @{ Name = 'Riquadri metriche'; Ok = ($null -ne $script:Ui.ActivityMetricBoxes -and $script:Ui.ActivityMetricBoxes.Count -eq 4); Detail = ("{0} box (CPU, RAM, disco, GPU)" -f $script:Ui.ActivityMetricBoxes.Count) }
            @{ Name = 'Box App e Driver'; Ok = ($null -ne $script:Ui.MaintList -and $null -ne $script:Ui.DriverList); Detail = 'aggiornamenti e driver in box separati' }
            @{ Name = 'Pulsanti operativi'; Ok = ($script:Ui.Toolbar.Controls.Count -eq 11); Detail = ("{0} pulsanti" -f $script:Ui.Toolbar.Controls.Count) }
        )
        $failed = 0
        foreach ($check in $checks) {
            if (-not $check.Ok) { $failed++ }
            Write-Output ("  [{0}] {1,-22} {2}" -f $(if ($check.Ok) { 'OK  ' } else { 'FAIL' }), $check.Name, $check.Detail)
        }
        Write-Output ("GUI smoke test superato: {0} controlli, {1} falliti, {2} stampante in elenco, dettagli: {3}, log: {4} righe." -f `
            $checks.Count, $failed, $script:Ui.PrinterList.Items.Count, $script:Ui.DetailList.Items.Count, $script:LogEntries.Count)
        $form.Dispose()
        if ($failed -gt 0) { exit 1 }
        exit 0
    } catch {
        Write-Output ("GUI smoke test FALLITO: {0}" -f $_.Exception.Message)
        Write-Output ("Stack: {0}" -f $_.ScriptStackTrace)
        Write-Log -Message ("GUI smoke test fallito: {0} | {1}" -f $_.Exception.Message, $_.ScriptStackTrace) -Level 'ERROR'
        exit 1
    }
}

$apartment = [System.Threading.Thread]::CurrentThread.ApartmentState
if ($apartment -ne [System.Threading.ApartmentState]::STA) {
    Write-Log -Message ("ApartmentState {0}: rilancio del processo in STA." -f $apartment) -Level 'WARN'
    $shell = Join-Path -Path $PSHOME -ChildPath 'pwsh.exe'
    if (-not (Test-Path -LiteralPath $shell)) { $shell = Join-Path -Path $PSHOME -ChildPath 'powershell.exe' }
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', ('"{0}"' -f $PSCommandPath))
    if ($PrinterName) { $argList += @('-PrinterName', ('"{0}"' -f $PrinterName)) }
    try {
        Start-Process -FilePath $shell -ArgumentList $argList -WorkingDirectory $PSScriptRoot -ErrorAction Stop | Out-Null
    } catch {
        Write-Log -Message ("Rilancio in STA non riuscito: {0}" -f $_.Exception.Message) -Level 'ERROR'
    }
    exit 0
}

Show-SplashScreen

# La dashboard viene mostrata solo a inizializzazione completata: ogni passo
# aggiorna la barra di avanzamento e la checklist dello splash, che si chiude
# al 100%.
try {
    Set-SplashSteps -Labels @(
        'Backend core (CyberMedic_Core.ps1)'
        'Moduli core (7)'
        'Schede GUI modulari (7)'
        'Inventario stampanti e porte'
        'Dashboard e 8 schede'
        'Metriche e diagnostica hardware'
        'Layout, log e stato iniziale'
    )
    Set-SplashProgress -Percent 40 -Message 'Backend e moduli caricati.' -Step 3
    Set-SplashStep -Index 3 -State 'done'

    Set-SplashProgress -Percent 55 -Message 'Rilevamento delle stampanti installate...' -Step 4
    Update-Inventory | Out-Null
    Select-PrinterByName -Name $PrinterName

    Set-SplashProgress -Percent 75 -Message 'Preparazione dell''interfaccia...' -Step 5
    $script:Ui.Form = New-DashboardForm
    Initialize-DashboardState

    Set-SplashProgress -Percent 88 -Message 'Primo aggiornamento dei dati di sistema...' -Step 6
    try { Update-ActivityMetrics } catch { }

    Set-SplashProgress -Percent 96 -Message 'Layout, log e stato iniziale...' -Step 7
    try { Show-PrinterList } catch { }
    try { Show-PrinterDetails } catch { }

    Set-SplashProgress -Percent 100 -Message 'Modulo pronto.'
    Write-Log -Message 'Inizializzazione completata: dashboard pronta.' -Level 'INFO'
} catch {
    Write-Log -Message ("Inizializzazione non riuscita: {0}" -f $_.Exception.Message) -Level 'ERROR'
}

Complete-Splash

Show-Dashboard