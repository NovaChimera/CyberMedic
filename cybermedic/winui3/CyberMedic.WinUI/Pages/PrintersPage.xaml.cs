using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using CyberMedic.WinUI.Services;
using System;
using System.Threading.Tasks;

namespace CyberMedic.WinUI.Pages;

public sealed partial class PrintersPage : Page
{
    private readonly PowerShellService _ps;

    public PrintersPage()
    {
        InitializeComponent();
        _ps = new PowerShellService(@"C:\Users\User\Desktop\git\stampante\CyberMedic_Core.ps1");
        Loaded += async (s, e) => await RefreshPrintersAsync();
    }

    private async Task RefreshPrintersAsync()
    {
        try
        {
            OutputBox.Text = "Caricamento inventario stampanti...";
            var json = await _ps.GetPrinterInventoryAsync();
            OutputBox.Text = json;
        }
        catch (Exception ex)
        {
            OutputBox.Text = $"Errore: {ex.Message}";
        }
    }

    private async void RefreshButton_Click(object sender, RoutedEventArgs e)
    {
        await RefreshPrintersAsync();
    }

    private async void ClearQueuesButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            OutputBox.Text = "Pulizia code di stampa...";
            var result = await _ps.RunCommandAsync("Get-Printer | ForEach-Object { Clear-PrintJob -PrinterName $_.Name -ErrorAction SilentlyContinue }; 'Code pulite'");
            OutputBox.Text = result;
        }
        catch (Exception ex)
        {
            OutputBox.Text = $"Errore: {ex.Message}";
        }
    }
}
