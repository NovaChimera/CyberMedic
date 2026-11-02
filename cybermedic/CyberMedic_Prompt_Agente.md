\xEF\xBB\xBF# CyberMedic v3.0.1 – Prompt e codice per l'agente

Come usarlo: incolla la **PARTE 1** come primo messaggio all'agente. Poi, un file alla volta, incolla i blocchi della **PARTE 2** (o chiedi all'agente di crearli). La **PARTE 3** è un promemoria dei comandi PowerShell 7.

---

# PARTE 1 – PROMPT PER L'AGENTE

## Ruolo
Sei un ingegnere PowerShell 7 senior. Stai sviluppando **CyberMedic v3.0.1**, un'applicazione desktop per tecnici IT che lavorano su hotel e uffici di grande scala. Il tema è la diagnostica, la manutenzione e la **cybersecurity difensiva** (audit, hardening, monitoraggio). Rispondi in italiano; i commenti nel codice e i testi dell'interfaccia sono in italiano.

## Limiti etici (obbligatori)
- Strumento **difensivo** per amministratori. Niente exploit, malware, keylogger, furto di credenziali, bypass di antivirus.
- Le scansioni di rete partono solo dopo una **conferma esplicita** di autorizzazione dell'utente e restano limitate alla sottorete locale (/24).
- Nessuna password o chiave API nel codice. Per i segreti usa `Export-Clixml` (DPAPI) o `SecretManagement`.
- Ogni azione che modifica il sistema deve scrivere nel log; le operazioni distruttive chiedono conferma.

## Stato attuale del progetto
- PowerShell 7, **solo Windows Forms** (nessun XAML/WPF), eseguito come Amministratore.
- Stile "Obsidian Purple": sfondo `#0F0F14`, schede `#181820`, terminale `#0A0A0E`, accento viola `#8A2BE2`. Font Segoe UI 10 e Consolas 10 Bold per la console log.
- Il tema `gui\CyberMedic_Theme.ps1` crea `$script:MainForm`, la funzione `Write-PoshLog -Message <testo> -Status INFO|SUCCESS|WARN|ERROR` e definisce le variabili colore/font: `BgMain, BgTabs, BgTerminal, AccentViolet, AccentGreen, AccentCyan, AccentBlue, AccentRed, TextPrimary, TextSecondary, FontMain, FontBold, FontConsole`.
- `launch.ps1` fa: elevazione UAC, istanza singola, carica il tema, il bridge `core\wintoolkit-ipc.ps1`, poi i moduli in `gui\tabs\` con dot-sourcing nell'ordine: dashboard, pipeline-tab, wintoolkit-winget, gaming-toolkit, it-tools, printers-tab, cybersecurity-tab, maintenance-tab, log-registry. Poi `ShowDialog()`. **Non cambiare il launcher** senza chiedere.
- Struttura cartelle:
```
CyberMedic\
  bin\WinToolkit.exe
  core\wintoolkit-ipc.ps1        (bridge asincrono verso i processi figli)
  core\cm-runner.ps1             (NUOVO – parte 2, file 1)
  core\cm-security.ps1           (NUOVO – parte 2, file 2)
  gui\CyberMedic_Theme.ps1
  gui\tabs\dashboard.ps1 | pipeline-tab.ps1 | wintoolkit-winget.ps1 | gaming-toolkit.ps1
  gui\tabs\it-tools.ps1 | printers-tab.ps1 | cybersecurity-tab.ps1 | maintenance-tab.ps1
  gui\tabs\graphs-tab.ps1        (NUOVO – parte 2, file 3)
  gui\tabs\log-registry.ps1
  cybermedic\launch.ps1
```

## Regole di codice (non negoziabili)
1. **Prima di scrivere qualsiasi cosa**, leggi `CyberMedic_Theme.ps1`, `launch.ps1` e `dashboard.ps1` (che funziona) e riassumimi in 10 righe: nome della variabile TabControl, come si aggiunge un tab, scope delle variabili, firma di `Write-PoshLog`. Non inventare nomi: usa solo quelli che esistono.
2. Ogni tab è un file in `gui\tabs\`, dot-sourced: le variabili che servono ai gestori eventi (controlli, liste) vanno in scope script (`$script:nome`), mai locali a una funzione.
3. **Prima di usare `$TabControl.TabPages.Add(...)` verifica che la variabile non sia `$null`** e lancia un errore chiaro se manca (bug attuale di `maintenance-tab.ps1`).
4. Mai `Get-WmiObject`, `Get-EventLog` o `Invoke-Expression`. Usa `Get-CimInstance` e `Get-WinEvent`.
5. Il controllo `System.Windows.Forms.DataVisualization.Chart` **non esiste in PowerShell 7**: i grafici si disegnano con `System.Drawing` (vedi file 3).
6. Nessuna finestra esterna: ogni processo con `CreateNoWindow = $true`. Nessun blocco dell'interfaccia: per compiti lunghi usa `Start-CmTask` (processi) o `Start-ThreadJob` + `Timer` (calcoli). Non fare mai `Start-Sleep` o `.WaitForExit()` sul thread dell'interfaccia.
7. Gli scriptblock di eventi .NET (`OutputDataReceived`, ecc.) **non funzionano** su thread senza runspace: per leggere l'output dei processi usa la classe C# `CmProcessRunner` del file 1.
8. Le chiamate che restituiscono oggetti (`$lv.Items.Add(...)`, `$tab.Controls.Add(...)`) vanno prefissate con `[void]`, altrimenti l'oggetto stampa in console (bug attuale di `printers-tab.ps1`).
9. Salva i file in **UTF-8 con BOM**. Le emoji e i glifi (➜ ✔ ✖ ⚡) solo nei testi, non nei nomi di variabili.
10. Ogni funzione ha `try/catch`, scrive gli errori con `Write-CmLog ... 'ERROR'` e non lascia mai l'interfaccia in stato inconsistente.
11. I comandi che cancellano o modificano supportano `-WhatIf`/conferma; chiedi conferma con un `MessageBox` solo per azioni distruttive.

## Bug noti da correggere subito
- `maintenance-tab.ps1` riga 8: `$TabMaintenance.Controls.Add($GroupUpdateGrid)` con `$TabMaintenance = $null`. Crea la `TabPage` (`[System.Windows.Forms.TabPage]::new('🔧 Manutenzione')`, `BackColor = $BgTabs`), poi i controlli, poi aggiungila al TabControl del tema.
- `printers-tab.ps1`: mette a schermo i `ListViewItem` (manca `[void]` davanti a `Items.Add`). Correggi tutte le occorrenze.
- Tutti i moduli devono usare **le variabili colore del tema** (`$BgTabs`, `$AccentViolet`, ...) e non colori scritti a mano né variabili con altri nomi.

## Cosa devi costruire (in quest'ordine)
1. **Correzioni** dei bug noti sopra, senza altre modifiche.
2. **`core\cm-runner.ps1`** (file 1): esecuzione processi in background, output ripulito dai caratteri di controllo, percentuale estratta e inviata al log.
3. **`core\cm-security.ps1`** (file 2): audit di sicurezza locale, aggiornamento firme e scansione rapida Defender, scansione porte della sottorete, sblocco coda stampa.
4. **Tab Cybersecurity** (`cybersecurity-tab.ps1`): pulsanti per le funzioni del file 2, una lista risultati (colonne Controllo / Stato / Dettaglio, righe non OK in `$AccentRed`), una `ProgressBar` collegata a `$script:Ui.Progress` e il pulsante di esportazione CSV. Usa lo schema del file 4.
5. **Tab Grafici** (`graphs-tab.ps1`, file 3): CPU, RAM e disco C: in tempo reale.
6. **Tab Manutenzione/IT**: aggiungi funzioni prese dall'Allegato A (inventario hardware, eventi errori ultime 24 ore con raggruppamento, stato servizi critici, test rete e DNS).
7. Collega l'esportazione dei risultati al tab `log-registry.ps1`.

## Come devi lavorare
- Fai un passo alla volta. Dopo ogni file mostrami: cosa hai cambiato, come lo provo, cosa potrebbe rompersi.
- Prima del codice chiedimi ciò che non sai (nomi variabili, firma di funzioni). Non indovinare.
- Alla fine di ogni passo avvia il progetto con `pwsh -File ...\launch.ps1 -ShowConsole` e riportami il log degli errori **senza nasconderli**.
- Non toccare file che non c'entrano con il passo in corso.

## Definizione di "fatto"
Il launcher carica tutti i moduli senza `[ERROR]`, la finestra si apre con tutti i tab, nessun oggetto spurio compare in console, nessuna finestra esterna lampeggia, l'interfaccia non si blocca durante una scansione, e chiudendo la finestra non restano processi figli attivi.

---

# PARTE 2 – CODICE

> Questo codice non è stato eseguito in un ambiente Windows: prova ogni file su un PC di prova. Se un nome di variabile del tema è diverso, l'agente deve adattarlo (vedi regola 1).

## File 1 – `core\cm-runner.ps1`

```powershell
# core\cm-runner.ps1
# Esecuzione di processi in background (nessuna finestra), output pulito riga per riga.

if (-not ('CmProcessRunner' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.Text;
using System.Text.RegularExpressions;

public class CmProcessRunner : IDisposable
{
    public readonly ConcurrentQueue<string> Lines = new ConcurrentQueue<string>();
    public Process Proc;
    public volatile bool Finished;
    public int ExitCode = -1;

    static readonly Regex Ctrl = new Regex(
        @"\x1B\[[0-9;?]*[A-Za-z]|[\x00-\x08\x0B\x0C\x0E-\x1F]|[\u2580-\u259F]",
        RegexOptions.Compiled);
    static readonly Regex Spinner = new Regex(@"^[\-\\|/]$", RegexOptions.Compiled);

    public void Start(string file, string args)
    {
        var psi = new ProcessStartInfo(file, args ?? "")
        {
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8
        };
        Proc = new Process { StartInfo = psi, EnableRaisingEvents = true };
        Proc.OutputDataReceived += (s, e) => Enqueue(e.Data);
        Proc.ErrorDataReceived += (s, e) => Enqueue(e.Data);
        Proc.Exited += (s, e) =>
        {
            try { Proc.WaitForExit(); ExitCode = Proc.ExitCode; } catch { }
            Finished = true;
        };
        Proc.Start();
        Proc.BeginOutputReadLine();
        Proc.BeginErrorReadLine();
    }

    void Enqueue(string data)
    {
        if (string.IsNullOrEmpty(data)) return;
        // le barre di avanzamento riscrivono la riga con \r: teniamo l'ultimo segmento
        string[] parts = data.Split('\r');
        string last = parts[parts.Length - 1];
        string clean = Ctrl.Replace(last, "").Trim();
        if (clean.Length == 0 || Spinner.IsMatch(clean)) return;
        Lines.Enqueue(clean);
    }

    public void Kill()
    {
        try { if (Proc != null && !Proc.HasExited) Proc.Kill(true); } catch { }
    }

    public void Dispose()
    {
        Kill();
        if (Proc != null) Proc.Dispose();
    }
}
'@
}

function Write-CmLog {
    param([string]$Message, [ValidateSet('INFO','SUCCESS','WARN','ERROR')][string]$Status = 'INFO')
    if (Get-Command -Name Write-PoshLog -CommandType Function -ErrorAction SilentlyContinue) {
        try { Write-PoshLog -Message $Message -Status $Status; return } catch {}
    }
    Write-Host "[$Status] $Message"
}

function Write-CmProgress {
    param([string]$Line)
    if ($Line -match '(\d{1,3}(?:[.,]\d+)?)\s*%') {
        $pct = [int][double]($Matches[1] -replace ',', '.')
        if ($pct -ge 0 -and $pct -le 100 -and $script:Ui -and $script:Ui.Progress) {
            try { $script:Ui.Progress.Value = $pct } catch {}
        }
        Write-CmLog ("{0}%  {1}" -f $pct, $Line) 'INFO'
    }
    else {
        Write-CmLog $Line 'INFO'
    }
}

function Start-CmTask {
    <#
      Esempio:
        Start-CmTask -Title 'DISM RestoreHealth' -FilePath 'dism.exe' `
            -Arguments '/Online /Cleanup-Image /RestoreHealth' -OnDone { param($code) ... }
    #>
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$FilePath,
        [string]$Arguments = '',
        [scriptblock]$OnDone
    )

    $runner = [CmProcessRunner]::new()
    try { $runner.Start($FilePath, $Arguments) }
    catch {
        Write-CmLog "Avvio fallito ($Title): $($_.Exception.Message)" 'ERROR'
        return
    }
    if ($script:ChildProcesses) { [void]$script:ChildProcesses.Add($runner.Proc) }   # per il cleanup del launcher
    Write-CmLog "➜ $Title" 'INFO'

    $timer = [System.Windows.Forms.Timer]::new()
    $timer.Interval = 200
    $timer.Tag = @{ Runner = $runner; Title = $Title; OnDone = $OnDone }
    $timer.Add_Tick({
        param($s, $e)
        $st = $s.Tag
        $line = $null
        while ($st.Runner.Lines.TryDequeue([ref]$line)) { Write-CmProgress -Line $line }

        if ($st.Runner.Finished -and $st.Runner.Lines.IsEmpty) {
            $s.Stop(); $s.Dispose()
            $code = $st.Runner.ExitCode
            if ($code -eq 0) { Write-CmLog "✔ $($st.Title) completato" 'SUCCESS' }
            else { Write-CmLog "✖ $($st.Title) terminato con codice $code" 'ERROR' }
            if ($script:Ui -and $script:Ui.Progress) { try { $script:Ui.Progress.Value = 0 } catch {} }
            if ($st.OnDone) { try { & $st.OnDone $code } catch { Write-CmLog $_.Exception.Message 'ERROR' } }
            $st.Runner.Dispose()
        }
    })
    $timer.Start()
}
```

## File 2 – `core\cm-security.ps1`

```powershell
# core\cm-security.ps1
# Funzioni di sicurezza difensiva. Richiede core\cm-runner.ps1 caricato prima.

function Confirm-CmAuthorizedScan {
    $r = [System.Windows.Forms.MessageBox]::Show(
        "Stai per scansionare le porte della rete locale.`nProcedi solo se sei autorizzato ad amministrare questa rete.`n`nConfermi?",
        'CyberMedic – Autorizzazione scansione',
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning)
    return ($r -eq [System.Windows.Forms.DialogResult]::Yes)
}

function Get-CmLocalSubnet {
    $cfg = Get-NetIPConfiguration |
        Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } |
        Select-Object -First 1
    if (-not $cfg) { return $null }
    $ip = $cfg.IPv4Address.IPAddress
    [pscustomobject]@{
        IP     = $ip
        Prefix = $cfg.IPv4Address.PrefixLength
        Base   = ($ip -replace '\.\d+$', '')     # es. 192.168.1  (si scansiona solo il /24 locale)
    }
}

function Get-CmSecurityAudit {
    $r = [System.Collections.Generic.List[object]]::new()
    $add = {
        param($Check, $Ok, $Detail)
        $r.Add([pscustomobject]@{ Check = $Check; Status = $(if ($Ok) { 'OK' } else { 'ATTENZIONE' }); Detail = $Detail })
    }

    try {
        $mp = Get-MpComputerStatus
        & $add 'Defender: protezione in tempo reale' $mp.RealTimeProtectionEnabled "Attiva: $($mp.RealTimeProtectionEnabled)"
        & $add 'Defender: firme aggiornate' ($mp.AntivirusSignatureAge -le 3) "Età firme: $($mp.AntivirusSignatureAge) giorni"
    } catch { & $add 'Defender' $false "Non leggibile: $($_.Exception.Message)" }

    try {
        $off = @(Get-NetFirewallProfile | Where-Object { -not $_.Enabled }).Name
        & $add 'Firewall (tutti i profili)' ($off.Count -eq 0) $(if ($off.Count) { "Disattivo: $($off -join ', ')" } else { 'Attivo' })
    } catch { & $add 'Firewall' $false $_.Exception.Message }

    try {
        $smb1 = (Get-SmbServerConfiguration).EnableSMB1Protocol
        & $add 'SMB1 disattivato' (-not $smb1) "SMB1 attivo: $smb1"
    } catch { & $add 'SMB1' $false $_.Exception.Message }

    try {
        $bl = Get-BitLockerVolume -MountPoint $env:SystemDrive
        & $add "BitLocker $($env:SystemDrive)" ($bl.ProtectionStatus -eq 'On') "Stato: $($bl.ProtectionStatus), cifrato al $($bl.EncryptionPercentage)%"
    } catch { & $add 'BitLocker' $false 'Non disponibile o permessi insufficienti' }

    try {
        $tpm = Get-Tpm
        & $add 'TPM presente e pronto' ($tpm.TpmPresent -and $tpm.TpmReady) "Presente: $($tpm.TpmPresent), pronto: $($tpm.TpmReady)"
    } catch { & $add 'TPM' $false 'Non leggibile' }

    try {
        $sb = Confirm-SecureBootUEFI
        & $add 'Secure Boot' $sb "Attivo: $sb"
    } catch { & $add 'Secure Boot' $false 'Non supportato (BIOS legacy?)' }

    try {
        $rdp = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server').fDenyTSConnections
        & $add 'Desktop remoto (RDP) disattivato' ($rdp -eq 1) $(if ($rdp -eq 1) { 'Disattivato' } else { 'RDP attivo: verifica che sia necessario' })
    } catch { & $add 'RDP' $false $_.Exception.Message }

    try {
        $uac = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System').EnableLUA
        & $add 'UAC attivo' ($uac -eq 1) "EnableLUA = $uac"
    } catch { & $add 'UAC' $false $_.Exception.Message }

    try {
        $admins = @(Get-LocalGroupMember -Group 'Administrators')
        & $add 'Amministratori locali' ($admins.Count -le 3) "$($admins.Count): $(($admins.Name) -join ', ')"
    } catch { & $add 'Amministratori locali' $false $_.Exception.Message }

    try {
        $guest = Get-LocalUser -Name 'Guest' -ErrorAction Stop
        & $add 'Account Guest disattivato' (-not $guest.Enabled) "Attivo: $($guest.Enabled)"
    } catch { & $add 'Account Guest' $true 'Non presente' }

    try {
        $last = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1
        $days = if ($last.InstalledOn) { [int]((Get-Date) - $last.InstalledOn).TotalDays } else { 9999 }
        & $add 'Aggiornamenti recenti (ultimi 45 giorni)' ($days -le 45) "Ultimo: $($last.HotFixID), $days giorni fa"
    } catch { & $add 'Aggiornamenti' $false $_.Exception.Message }

    return $r
}

function Update-CmDefenderSignatures {
    $mp = Join-Path $env:ProgramFiles 'Windows Defender\MpCmdRun.exe'
    if (-not (Test-Path $mp)) { Write-CmLog 'MpCmdRun.exe non trovato.' 'ERROR'; return }
    Start-CmTask -Title 'Defender: aggiornamento firme' -FilePath $mp -Arguments '-SignatureUpdate'
}

function Start-CmDefenderQuickScan {
    $mp = Join-Path $env:ProgramFiles 'Windows Defender\MpCmdRun.exe'
    if (-not (Test-Path $mp)) { Write-CmLog 'MpCmdRun.exe non trovato.' 'ERROR'; return }
    Start-CmTask -Title 'Defender: scansione rapida' -FilePath $mp -Arguments '-Scan -ScanType 1'
}

function Start-CmPortScan {
    param(
        [Parameter(Mandatory)][string]$BaseNet,                 # es. 192.168.1  (solo /24)
        [int[]]$Ports = @(21, 22, 23, 80, 135, 139, 443, 445, 3389, 5900, 9100),
        [int]$TimeoutMs = 500,
        [scriptblock]$OnDone                                     # riceve la lista dei risultati
    )

    if ($BaseNet -notmatch '^\d{1,3}\.\d{1,3}\.\d{1,3}$') { Write-CmLog "Rete non valida: $BaseNet" 'ERROR'; return }
    if (-not (Confirm-CmAuthorizedScan)) { Write-CmLog 'Scansione annullata dall''utente.' 'WARN'; return }

    $ips = 1..254 | ForEach-Object { "$BaseNet.$_" }
    Write-CmLog "Scansione di $BaseNet.1-254 su $($Ports.Count) porte..." 'INFO'

    $job = Start-ThreadJob -ArgumentList $ips, $Ports, $TimeoutMs -ScriptBlock {
        param($ips, $ports, $to)
        for ($i = 0; $i -lt $ips.Count; $i += 24) {
            $chunk = $ips[$i..([Math]::Min($i + 23, $ips.Count - 1))]
            $items = foreach ($ip in $chunk) {
                foreach ($p in $ports) {
                    $c = [System.Net.Sockets.TcpClient]::new()
                    [pscustomobject]@{ IP = $ip; Port = $p; Client = $c; Task = $c.ConnectAsync($ip, $p) }
                }
            }
            try { [void][System.Threading.Tasks.Task]::WaitAll([System.Threading.Tasks.Task[]]@($items.Task), $to) } catch {}
            foreach ($it in $items) {
                if ($it.Client.Connected) { [pscustomobject]@{ IP = $it.IP; Port = $it.Port; State = 'Aperta' } }
                $it.Client.Dispose()
            }
        }
    }

    $timer = [System.Windows.Forms.Timer]::new()
    $timer.Interval = 500
    $timer.Tag = @{ Job = $job; OnDone = $OnDone; Found = [System.Collections.Generic.List[object]]::new() }
    $timer.Add_Tick({
        param($s, $e)
        $st = $s.Tag
        $done = $st.Job.State -in 'Completed', 'Failed', 'Stopped'
        foreach ($r in @(Receive-Job -Job $st.Job)) {
            [void]$st.Found.Add($r)
            Write-CmLog ("{0}:{1} aperta" -f $r.IP, $r.Port) 'WARN'
        }
        if ($done) {
            $s.Stop(); $s.Dispose()
            Remove-Job -Job $st.Job -Force
            Write-CmLog ("Scansione terminata: {0} porte aperte" -f $st.Found.Count) 'SUCCESS'
            if ($st.OnDone) { try { & $st.OnDone $st.Found } catch { Write-CmLog $_.Exception.Message 'ERROR' } }
        }
    })
    $timer.Start()
}

function Clear-CmPrintQueue {
    try {
        Stop-Service -Name Spooler -Force -ErrorAction Stop
        Remove-Item -Path "$env:SystemRoot\System32\spool\PRINTERS\*" -Include *.SPL, *.SHD -Force -ErrorAction SilentlyContinue
        Write-CmLog 'Coda di stampa svuotata.' 'SUCCESS'
    }
    catch { Write-CmLog "Sblocco coda fallito: $($_.Exception.Message)" 'ERROR' }
    finally { Start-Service -Name Spooler -ErrorAction SilentlyContinue }
}

function Export-CmResults {
    param([Parameter(Mandatory)]$Data, [string]$Name = 'risultati')
    $dir = Join-Path $env:ProgramData 'CyberMedic\export'
    if (-not (Test-Path $dir)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
    $file = Join-Path $dir ("{0}-{1:yyyyMMdd-HHmmss}.csv" -f $Name, (Get-Date))
    $Data | Export-Csv -Path $file -NoTypeInformation -Encoding UTF8
    Write-CmLog "Esportato: $file" 'SUCCESS'
    return $file
}
```

## File 3 – `gui\tabs\graphs-tab.ps1` (grafici in tempo reale)

```powershell
# gui\tabs\graphs-tab.ps1
# Grafici CPU / RAM / Disco C: disegnati con System.Drawing (il controllo Chart non esiste in PS7).
# L'agente deve sostituire $MainTabControl con la variabile reale del TabControl del tema.

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
    $p.BackColor = $BgTerminal
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
if (-not $MainTabControl) { throw 'TabControl del tema non trovato: leggi CyberMedic_Theme.ps1 e usa il nome reale.' }

$script:TabGraphs = [System.Windows.Forms.TabPage]::new('📈 Grafici')
$script:TabGraphs.BackColor = $BgTabs

$flow = [System.Windows.Forms.FlowLayoutPanel]::new()
$flow.Dock = 'Fill'
$flow.BackColor = $BgTabs
$flow.Padding = [System.Windows.Forms.Padding]::new(10)

$script:GraphCpu  = New-CmLiveGraph -Title 'CPU'    -LineColor $AccentViolet
$script:GraphRam  = New-CmLiveGraph -Title 'RAM'    -LineColor $AccentCyan
$script:GraphDisk = New-CmLiveGraph -Title 'Disco C:' -LineColor $AccentGreen
[void]$flow.Controls.Add($script:GraphCpu)
[void]$flow.Controls.Add($script:GraphRam)
[void]$flow.Controls.Add($script:GraphDisk)
[void]$script:TabGraphs.Controls.Add($flow)

$script:GraphTimer = [System.Windows.Forms.Timer]::new()
$script:GraphTimer.Interval = 2000
$script:GraphTimer.Add_Tick({
    try {
        Add-CmGraphValue $script:GraphCpu  (Get-CmCpuPercent)
        Add-CmGraphValue $script:GraphRam  (Get-CmRamPercent)
        Add-CmGraphValue $script:GraphDisk (Get-CmDiskPercent)
    } catch { }
})
$script:GraphTimer.Start()
$script:MainForm.Add_FormClosed({ try { $script:GraphTimer.Stop() } catch {} })

[void]$MainTabControl.TabPages.Add($script:TabGraphs)
```

## File 4 – schema del tab Cybersecurity (da integrare in `cybersecurity-tab.ps1`)

```powershell
# gui\tabs\cybersecurity-tab.ps1  (schema – l'agente adatta i nomi al tema reale)
if (-not $MainTabControl) { throw 'TabControl del tema non trovato.' }

$script:TabSec = [System.Windows.Forms.TabPage]::new('🛡️ Cybersecurity')
$script:TabSec.BackColor = $BgTabs

function New-CmButton {
    param([string]$Text, [int]$X, [int]$Y, [int]$W = 180)
    $b = [System.Windows.Forms.Button]::new()
    $b.Text = $Text; $b.Location = [System.Drawing.Point]::new($X, $Y); $b.Size = [System.Drawing.Size]::new($W, 34)
    $b.FlatStyle = 'Flat'; $b.FlatAppearance.BorderSize = 0
    $b.BackColor = $AccentViolet; $b.ForeColor = $TextPrimary; $b.Font = $FontMain
    return $b
}

$btnAudit = New-CmButton '🔍 Audit sicurezza'    10  10
$btnSig   = New-CmButton '⟳ Aggiorna firme'      200 10
$btnScan  = New-CmButton '🛡️ Scansione rapida'   390 10
$btnPorts = New-CmButton '📡 Scansiona porte LAN' 580 10 200
$btnCsv   = New-CmButton '💾 Esporta CSV'         790 10

$script:lvSec = [System.Windows.Forms.ListView]::new()
$script:lvSec.Location = [System.Drawing.Point]::new(10, 54)
$script:lvSec.Size = [System.Drawing.Size]::new(960, 380)
$script:lvSec.View = 'Details'; $script:lvSec.FullRowSelect = $true; $script:lvSec.GridLines = $false
$script:lvSec.BackColor = $BgTerminal; $script:lvSec.ForeColor = $TextPrimary; $script:lvSec.Font = $FontMain
[void]$script:lvSec.Columns.Add('Controllo', 280)
[void]$script:lvSec.Columns.Add('Stato', 110)
[void]$script:lvSec.Columns.Add('Dettaglio', 540)

$script:SecLast = @()

$btnAudit.Add_Click({
    try {
        $script:lvSec.Items.Clear()
        $script:SecLast = Get-CmSecurityAudit
        foreach ($r in $script:SecLast) {
            $it = [System.Windows.Forms.ListViewItem]::new($r.Check)
            [void]$it.SubItems.Add($r.Status)
            [void]$it.SubItems.Add($r.Detail)
            if ($r.Status -ne 'OK') { $it.ForeColor = $AccentRed } else { $it.ForeColor = $AccentGreen }
            [void]$script:lvSec.Items.Add($it)
        }
        Write-CmLog ("Audit completato: {0} controlli, {1} da verificare" -f $script:SecLast.Count, @($script:SecLast | Where-Object Status -ne 'OK').Count) 'SUCCESS'
    } catch { Write-CmLog $_.Exception.Message 'ERROR' }
})

$btnSig.Add_Click({  Update-CmDefenderSignatures })
$btnScan.Add_Click({ Start-CmDefenderQuickScan })

$btnPorts.Add_Click({
    $net = Get-CmLocalSubnet
    if (-not $net) { Write-CmLog 'Nessuna rete attiva trovata.' 'ERROR'; return }
    Start-CmPortScan -BaseNet $net.Base -OnDone {
        param($found)
        $script:lvSec.Items.Clear()
        $script:SecLast = @($found)
        foreach ($f in $found) {
            $it = [System.Windows.Forms.ListViewItem]::new("$($f.IP):$($f.Port)")
            [void]$it.SubItems.Add($f.State)
            [void]$it.SubItems.Add('Porta raggiungibile')
            $it.ForeColor = $AccentCyan
            [void]$script:lvSec.Items.Add($it)
        }
    }
})

$btnCsv.Add_Click({
    if ($script:SecLast.Count) { [void](Export-CmResults -Data $script:SecLast -Name 'sicurezza') }
    else { Write-CmLog 'Nessun risultato da esportare.' 'WARN' }
})

$pb = [System.Windows.Forms.ProgressBar]::new()
$pb.Location = [System.Drawing.Point]::new(10, 444); $pb.Size = [System.Drawing.Size]::new(960, 14)
$script:Ui.Progress = $pb

[void]$script:TabSec.Controls.AddRange(@($btnAudit, $btnSig, $btnScan, $btnPorts, $btnCsv, $script:lvSec, $pb))
[void]$MainTabControl.TabPages.Add($script:TabSec)
```

Caricamento: in `launch.ps1` (o all'inizio di `cybersecurity-tab.ps1`) aggiungi, **prima dei tab**, `. "$RootDir\core\cm-runner.ps1"` e `. "$RootDir\core\cm-security.ps1"`, e inserisci `graphs-tab.ps1` nella lista dei moduli.

## Test manuale per ogni passo
1. `pwsh -NoProfile -File ...\launch.ps1 -ShowConsole`: nessun `[ERROR]` nel log dei moduli.
2. Audit sicurezza: compaiono i controlli, le righe non OK sono rosse.
3. Aggiorna firme / scansione rapida: nel log compaiono percentuali e fasi, nessuna finestra esterna, l'interfaccia resta reattiva.
4. Scansione porte: appare la conferma di autorizzazione; con "No" non parte nulla.
5. Grafici: le tre linee si muovono ogni 2 secondi.
6. Chiusura con una scansione in corso: chiede conferma e non lascia `MpCmdRun.exe` o `dism.exe` attivi (Gestione attività).

---

# PARTE 3 – ALLEGATO A: COMANDI POWERSHELL 7 PER IL TECNICO (promemoria per l'agente)

Usa questi comandi per aggiungere funzioni ai tab. I moduli marcati * vanno installati con `Install-Module`.

| Categoria | Comandi principali | Uso |
|---|---|---|
| Base | `Get-Command`, `Get-Help`, `Where-Object`, `Select-Object`, `Sort-Object`, `Group-Object`, `ForEach-Object -Parallel`, `Export-Csv`, `ConvertTo-Json`, `Start-Transcript` | Filtrare, raggruppare, esportare, registrare la sessione |
| Hardware | `Get-CimInstance Win32_ComputerSystem/BIOS/Processor/PhysicalMemory/VideoController/OperatingSystem`, `Get-ComputerInfo`, `Get-Uptime`, `Get-PhysicalDisk`, `Get-Volume`, `Get-PnpDevice`, `Export-WindowsDriver`, `Get-Tpm`, `Confirm-SecureBootUEFI` | Inventario e salute dei dischi, driver, TPM |
| Rete | `Test-Connection`, `Test-NetConnection -Port`, `Get-NetIPConfiguration`, `Get-NetAdapter`, `New-NetIPAddress`, `Set-DnsClientServerAddress`, `Resolve-DnsName`, `Clear-DnsClientCache`, `Get-NetTCPConnection`, `Get-NetNeighbor`, `Get-NetFirewallRule`, `Invoke-RestMethod`, `tracert`, `pathping` | Diagnosi, IP/DNS, porte aperte, API |
| Servizi ed eventi | `Get-Service`, `Restart-Service`, `Set-Service`, `Get-Process`, `Stop-Process`, `Get-WinEvent -FilterHashtable`, `Get-ScheduledTask`, `Register-ScheduledTask` | Servizi, processi, errori di sistema, attività pianificate |
| Software | `winget list/install/upgrade --all`, `Get-HotFix`, `Get-WindowsOptionalFeature`, `Get-AppxPackage`, `Get-WindowsUpdate`*, `sfc /scannow`, `DISM /Online /Cleanup-Image /RestoreHealth` | Installazioni, aggiornamenti, riparazioni |
| Utenti locali | `Get-LocalUser`, `New-LocalUser`, `Set-LocalUser`, `Enable/Disable-LocalUser`, `Get-LocalGroupMember`, `Add-LocalGroupMember` | Account e gruppi, LAPS |
| Dominio / cloud | `Get-ADUser`*, `Search-ADAccount -LockedOut`, `Unlock-ADAccount`, `Add-Computer`, `Test-ComputerSecureChannel`, `Get-GPOReport`*, `gpupdate /force`, `gpresult /r`, `Connect-MgGraph`*, `Connect-ExchangeOnline`* | Active Directory, GPO, Microsoft 365 |
| Remoto | `Enable-PSRemoting`, `Enter-PSSession`, `Invoke-Command -ComputerName`, `New-PSSession`, `Start-ThreadJob`, `Get-Job`, `Receive-Job` | Lavorare su molti PC in parallelo |
| Stampanti | `Get-Printer`, `Add-Printer`, `Get-PrinterPort`, `Get-PrinterDriver`, `Get-PrintJob`, `Remove-PrintJob`, `Restart-Service Spooler` | Gestione e sblocco code |
| File e backup | `Get-ChildItem -Recurse`, `Get-FileHash`, `Get-Acl`, `Compress-Archive`, `robocopy /MIR`, `Get-SmbShare`, `New-SmbMapping`, `Repair-Volume -Scan`, `vssadmin list shadows` | Copie, permessi, condivisioni, controllo dischi |
| Sicurezza | `Get-MpComputerStatus`, `Update-MpSignature`, `Start-MpScan`, `Get-MpThreatDetection`, `Get-BitLockerVolume`, `Backup-BitLockerKeyProtector`, `Set-NetFirewallProfile`, `Set-SmbServerConfiguration -EnableSMB1Protocol $false`, `Get-AuthenticodeSignature`, `SecretManagement`* | Difesa e hardening |
| Registro e sistema | `Get-ItemProperty`, `Set-ItemProperty`, `powercfg /energy`, `w32tm /resync`, `Set-TimeZone`, `Restart-Computer`, `Set-AssignedAccess` | Impostazioni, orario, kiosk |
| Grafici | `Get-Counter`, `Out-GridView`, `PSWriteHTML`*, `ImportExcel`*, `PwshSpectreConsole`*, `System.Drawing` | Visualizzazione dei dati |
| Solo PS7 | `??`, `??=`, `? :`, `&&`, `\|\|`, `Get-Error`, `Join-String`, `Test-Json`, `ForEach-Object -Parallel`, `Start-ThreadJob` | Codice più compatto e parallelo |

**Da evitare in PS7:** `Get-WmiObject` (usa `Get-CimInstance`), `Get-EventLog` (usa `Get-WinEvent`), il controllo `Chart` di WinForms, e alcuni moduli solo Windows PowerShell (usa `-UseWindowsPowerShell`).
