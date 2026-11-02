using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using CyberMedic.WinUI.Services;
using System;
using System.Threading.Tasks;

namespace CyberMedic.WinUI.Pages;

public sealed partial class NetworkPage : Page
{
    private readonly PowerShellService _ps;

    public NetworkPage()
    {
        InitializeComponent();
        _ps = new PowerShellService(@"C:\Users\User\Desktop\git\stampante\CyberMedic_Core.ps1");
    }

    private async void ConnectivityButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            OutputBox.Text = "Test connettività in corso...";
            var result = await _ps.RunCommandAsync("Test-Connection -ComputerName 8.8.8.8 -Count 2 | Select-Object -ExpandProperty ResponseTime | ForEach-Object { \"Ping: $_ ms\" }; (Test-NetConnection -ComputerName google.com -Port 443).TcpTestSucceeded | ForEach-Object { \"HTTPS: $_\" }");
            OutputBox.Text = string.IsNullOrWhiteSpace(result) ? "Nessun risultato" : result;
        }
        catch (Exception ex)
        {
            OutputBox.Text = $"Errore: {ex.Message}";
        }
    }

    private async void NetworkInfoButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            OutputBox.Text = "Recupero info rete...";
            var result = await _ps.RunCommandAsync("Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne '127.0.0.1' } | Select-Object IPAddress, InterfaceAlias | ForEach-Object { \"$($_.InterfaceAlias): $($_.IPAddress)\" }");
            OutputBox.Text = string.IsNullOrWhiteSpace(result) ? "Nessun risultato" : result;
        }
        catch (Exception ex)
        {
            OutputBox.Text = $"Errore: {ex.Message}";
        }
    }

    private async void ResetNetworkButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            OutputBox.Text = "Reset rete in corso (richiede admin)...";
            var result = await _ps.RunCommandAsync("ipconfig /flushdns; ipconfig /release; ipconfig /renew; 'Reset completato'");
            OutputBox.Text = string.IsNullOrWhiteSpace(result) ? "Reset completato" : result;
        }
        catch (Exception ex)
        {
            OutputBox.Text = $"Errore: {ex.Message}";
        }
    }
}
