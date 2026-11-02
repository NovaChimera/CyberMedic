using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using CyberMedic.WinUI.Services;
using System;
using System.Threading.Tasks;

namespace CyberMedic.WinUI.Pages;

public sealed partial class UpdatesPage : Page
{
    private readonly PowerShellService _ps;

    public UpdatesPage()
    {
        InitializeComponent();
        _ps = new PowerShellService(@"C:\Users\User\Desktop\git\stampante\CyberMedic_Core.ps1");
    }

    private async void CheckUpdatesButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            OutputBox.Text = "Verifica aggiornamenti in corso...";
            var result = await _ps.RunCommandAsync("Get-WingetUpgradeReport");
            OutputBox.Text = string.IsNullOrWhiteSpace(result) ? "Nessun aggiornamento trovato" : result;
        }
        catch (Exception ex)
        {
            OutputBox.Text = $"Errore: {ex.Message}";
        }
    }

    private async void UpdateDriversButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            OutputBox.Text = "Verifica driver in corso...";
            var result = await _ps.RunCommandAsync("Get-PnpDevice -Class 'Display','Net','Media' | Where-Object { $_.Status -ne 'OK' } | Select-Object FriendlyName, Status | ForEach-Object { \"$($_.FriendlyName): $($_.Status)\" }");
            OutputBox.Text = string.IsNullOrWhiteSpace(result) ? "Tutti i driver OK" : result;
        }
        catch (Exception ex)
        {
            OutputBox.Text = $"Errore: {ex.Message}";
        }
    }
}
