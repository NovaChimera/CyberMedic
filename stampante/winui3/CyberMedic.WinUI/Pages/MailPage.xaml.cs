using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using CyberMedic.WinUI.Services;
using System;
using System.Threading.Tasks;

namespace CyberMedic.WinUI.Pages;

public sealed partial class MailPage : Page
{
    private readonly PowerShellService _ps;

    public MailPage()
    {
        InitializeComponent();
        _ps = new PowerShellService(@"C:\Users\User\Desktop\git\stampante\CyberMedic_Core.ps1");
    }

    private async void CheckOutlookButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            OutputBox.Text = "Verifica Outlook in corso...";
            var result = await _ps.RunCommandAsync("Get-OutlookInstallation | Out-String");
            OutputBox.Text = string.IsNullOrWhiteSpace(result) ? "Outlook non trovato" : result;
        }
        catch (Exception ex)
        {
            OutputBox.Text = $"Errore: {ex.Message}";
        }
    }

    private async void FindPstButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            OutputBox.Text = "Ricerca PST/OST in corso...";
            var result = await _ps.RunCommandAsync("$roots = @((Join-Path $env:APPDATA 'Microsoft\\Outlook'), (Join-Path $env:LOCALAPPDATA 'Microsoft\\Outlook')); $roots | ForEach-Object { if (Test-Path $_) { Get-ChildItem $_ -Recurse -Filter '*.pst' -ErrorAction SilentlyContinue; Get-ChildItem $_ -Recurse -Filter '*.ost' -ErrorAction SilentlyContinue } } | ForEach-Object { $_.FullName }");
            OutputBox.Text = string.IsNullOrWhiteSpace(result) ? "Nessun PST/OST trovato" : result;
        }
        catch (Exception ex)
        {
            OutputBox.Text = $"Errore: {ex.Message}";
        }
    }
}
