using System;
using System.Diagnostics;
using System.Threading.Tasks;

namespace CyberMedic.WinUI.Services;

/// <summary>
/// Wrapper per l'esecuzione del backend PowerShell (CyberMedic_Core.ps1).
/// Il backend resta la fonte di verita' della logica di sistema; questa
/// classe e' il ponte fra WinUI 3 e gli script esistenti.
/// </summary>
public class PowerShellService
{
    private readonly string _corePath;

    public PowerShellService(string corePath)
    {
        _corePath = corePath;
    }

    public async Task<string> RunCommandAsync(string scriptBlock)
    {
        var psi = new ProcessStartInfo
        {
            FileName = "powershell.exe",
            Arguments = $"-NoProfile -ExecutionPolicy Bypass -Command \"{scriptBlock}\"",
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        using var process = Process.Start(psi);
        if (process is null) return string.Empty;

        var output = await process.StandardOutput.ReadToEndAsync();
        await process.WaitForExitAsync();
        return output;
    }

    public async Task<string> GetResourceMetricsAsync()
    {
        return await RunCommandAsync(
            ". '" + _corePath + "'; Get-ResourceMetrics | ConvertTo-Json -Depth 3");
    }

    public async Task<string> GetPrinterInventoryAsync()
    {
        return await RunCommandAsync(
            ". '" + _corePath + "'; Update-Inventory | Out-Null; $script:Inventory | ConvertTo-Json -Depth 3");
    }
}
