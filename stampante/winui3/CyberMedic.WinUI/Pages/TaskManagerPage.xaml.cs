using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using CyberMedic.WinUI.Services;
using System;
using System.Threading.Tasks;

namespace CyberMedic.WinUI.Pages;

public sealed partial class TaskManagerPage : Page
{
    private readonly PowerShellService _ps;

    public TaskManagerPage()
    {
        InitializeComponent();
        _ps = new PowerShellService(@"C:\Users\User\Desktop\git\stampante\CyberMedic_Core.ps1");
        Loaded += async (s, e) => await RefreshMetricsAsync();
    }

    private async Task RefreshMetricsAsync()
    {
        try
        {
            MetricsText.Text = "Caricamento metriche...";
            var json = await _ps.GetResourceMetricsAsync();
            MetricsText.Text = json;
        }
        catch (Exception ex)
        {
            MetricsText.Text = $"Errore: {ex.Message}";
        }
    }

    private async void RefreshButton_Click(object sender, RoutedEventArgs e)
    {
        await RefreshMetricsAsync();
    }

    private async void TopProcessesButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            OutputBox.Text = "Caricamento processi...";
            var result = await _ps.RunCommandAsync("Get-Process | Sort-Object CPU -Descending | Select-Object -First 15 Name, CPU, WorkingSet | ForEach-Object { \"$($_.Name)  CPU=$([math]::Round($_.CPU,1))  RAM=$([math]::Round($_.WorkingSet/1MB,1))MB\" }");
            OutputBox.Text = string.IsNullOrWhiteSpace(result) ? "Nessun risultato" : result;
        }
        catch (Exception ex)
        {
            OutputBox.Text = $"Errore: {ex.Message}";
        }
    }

    private void Toggle_Toggled(object sender, RoutedEventArgs e)
    {
        // Toggles are visual only in this scaffold; could drive metric collection
    }
}
