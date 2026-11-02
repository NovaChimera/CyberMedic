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