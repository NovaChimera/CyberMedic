using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using CyberMedic.WinUI.Services;
using System;
using System.Threading.Tasks;

namespace CyberMedic.WinUI.Pages;

public sealed partial class CybersecurityPage : Page
{
    private readonly PowerShellService _ps;

    public CybersecurityPage()
    {
        InitializeComponent();
        _ps = new PowerShellService(@"C:\Users\User\Desktop\git\stampante\CyberMedic_Core.ps1");
    }

    private async void FirewallButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            OutputBox.Text = "Verifica firewall in corso...";
            var result = await _ps.RunCommandAsync("Get-NetFirewallProfile | Select-Object Name, Enabled | ForEach-Object { \"$($_.Name): $($_.Enabled)\" }");
            OutputBox.Text = string.IsNullOrWhiteSpace(result) ? "Nessun risultato" : result;
        }
        catch (Exception ex)
        {
            OutputBox.Text = $"Errore: {ex.Message}";
        }
    }

    private async void PortScanButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            OutputBox.Text = "Scansione porte in corso...";
            var result = await _ps.RunCommandAsync("Get-NetTCPConnection -State Listen | Select-Object -First 20 LocalPort, OwningProcess | ForEach-Object { \"Porta $($_.LocalPort) - PID $($_.OwningProcess)\" }");
            OutputBox.Text = string.IsNullOrWhiteSpace(result) ? "Nessuna porta in ascolto" : result;
        }
        catch (Exception ex)
        {
            OutputBox.Text = $"Errore: {ex.Message}";
        }
    }

    private async void DefenderButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            OutputBox.Text = "Verifica Defender in corso...";
            var result = await _ps.RunCommandAsync("Get-MpComputerStatus | Select-Object AntivirusEnabled, RealTimeProtectionEnabled, NISEnabled | ForEach-Object { \"AV: $($_.AntivirusEnabled) | RTP: $($_.RealTimeProtectionEnabled) | NIS: $($_.NISEnabled)\" }");
            OutputBox.Text = string.IsNullOrWhiteSpace(result) ? "Defender non disponibile" : result;
        }
        catch (Exception ex)
        {
            OutputBox.Text = $"Errore: {ex.Message}";
        }
    }
}
