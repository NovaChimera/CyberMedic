# gui\tabs\cybersecurity-tab.ps1
if (-not $script: TabControl) { throw 'TabControl del tema non trovato.' }

$script: TabSec = [System.Windows.Forms.TabPage]::new('🛡️ Cybersecurity')
$script: TabSec.BackColor = $script: BgTabs

function New-CmButton {
    param([string]$Text, [int]$X, [int]$Y, [int]$W = 180)
    $b = [System.Windows.Forms.Button]::new()
    $b.Text = $Text
    $b.Location = [System.Drawing.Point]::new($X, $Y)
    $b.Size = [System.Drawing.Size]::new($W, 34)
    $b.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $b.FlatAppearance.BorderSize = 0
    $b.BackColor = $script: AccentViolet
    $b.ForeColor = $script: TextPrimary
    $b.Font = $script: FontMain
    return $b
}

$btnAudit = New-CmButton '🔍 Audit sicurezza'    10  10
$btnSig   = New-CmButton '⟳ Aggiorna firme'      200 10
$btnScan  = New-CmButton '🛡️ Scansione rapida'   390 10
$btnPorts = New-CmButton '📡 Scansiona porte LAN' 580 10 200
$btnCsv   = New-CmButton '💾 Esporta CSV'         790 10

$script: lvSec = [System.Windows.Forms.ListView]::new()
$script: lvSec.Location = [System.Drawing.Point]::new(10, 54)
$script: lvSec.Size = [System.Drawing.Size]::new(960, 380)
$script: lvSec.View = [System.Windows.Forms.View]::Details
$script: lvSec.FullRowSelect = $true
$script: lvSec.GridLines = $false
$script: lvSec.BackColor = $script: BgTerminal
$script: lvSec.ForeColor = $script: TextPrimary
$script: lvSec.Font = $script: FontMain
[void]$script: lvSec.Columns.Add('Controllo', 280)
[void]$script: lvSec.Columns.Add('Stato', 110)
[void]$script: lvSec.Columns.Add('Dettaglio', 540)

$script: SecLast = @()

$btnAudit.Add_Click({
    try {
        $script: lvSec.Items.Clear()
        $script: SecLast = Get-CmSecurityAudit
        foreach ($r in $script: SecLast) {
            $it = [System.Windows.Forms.ListViewItem]::new($r.Check)
            [void]$it.SubItems.Add($r.Status)
            [void]$it.SubItems.Add($r.Detail)
            if ($r.Status -ne 'OK') { $it.ForeColor = $script: AccentRed } else { $it.ForeColor = $script: AccentGreen }
            [void]$script: lvSec.Items.Add($it)
        }
        Write-CmLog ("Audit completato: {0} controlli, {1} da verificare" -f $script: SecLast.Count, @($script: SecLast | Where-Object Status -ne 'OK').Count) 'SUCCESS'
    } catch { Write-CmLog $_.Exception.Message 'ERROR' }
})

$btnSig.Add_Click({ Update-CmDefenderSignatures })
$btnScan.Add_Click({ Start-CmDefenderQuickScan })

$btnPorts.Add_Click({
    $net = Get-CmLocalSubnet
    if (-not $net) { Write-CmLog 'Nessuna rete attiva trovata.' 'ERROR'; return }
    Start-CmPortScan -BaseNet $net.Base -OnDone {
        param($found)
        $script: lvSec.Items.Clear()
        $script: SecLast = @($found)
        foreach ($f in $found) {
            $it = [System.Windows.Forms.ListViewItem]::new("$($f.IP):$($f.Port)")
            [void]$it.SubItems.Add($f.State)
            [void]$it.SubItems.Add('Porta raggiungibile')
            $it.ForeColor = $script: AccentCyan
            [void]$script: lvSec.Items.Add($it)
        }
    }
})

$btnCsv.Add_Click({
    if ($script: SecLast.Count) { [void](Export-CmResults -Data $script: SecLast -Name 'sicurezza') }
    else { Write-CmLog 'Nessun risultato da esportare.' 'WARN' }
})

$pb = [System.Windows.Forms.ProgressBar]::new()
$pb.Location = [System.Drawing.Point]::new(10, 444)
$pb.Size = [System.Drawing.Size]::new(960, 14)
$script: Ui.Progress = $pb

[void]$script: TabSec.Controls.AddRange(@($btnAudit, $btnSig, $btnScan, $btnPorts, $btnCsv, $script: lvSec, $pb))
[void]$script:TabControl.TabPages.Add($script: TabSec)