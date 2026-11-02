using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using CyberMedic.WinUI.Services;
using System;
using System.Threading.Tasks;

namespace CyberMedic.WinUI.Pages;

public sealed partial class MaintenancePage : Page
{
    private readonly PowerShellService _ps;

    public MaintenancePage()
    {
        InitializeComponent();
        _ps = new PowerShellService(@"C:\Users\User\Desktop\git\stampante\CyberMedic_Core.ps1");
    }

    private async void AnalyzeButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            OutputBox.Text = "Analisi spazio in corso...";
            var result = await _ps.RunCommandAsync("Get-CleanupTarget | ForEach-Object { \"$($_.Label): $($_.FileCount) file, $($_.SizeMB) MB\" }");
            OutputBox.Text = string.IsNullOrWhiteSpace(result) ? "Nessun risultato" : result;
        }
        catch (Exception ex)
        {
            OutputBox.Text = $"Errore: {ex.Message}";
        }
    }

    private async void CleanupButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            OutputBox.Text = "Pulizia in corso...";
            var result = await _ps.RunCommandAsync("Invoke-TempCleanup; 'Pulizia completata'");
            OutputBox.Text = string.IsNullOrWhiteSpace(result) ? "Pulizia completata" : result;
        }
        catch (Exception ex)
        {
            OutputBox.Text = $"Errore: {ex.Message}";
        }
    }
}
