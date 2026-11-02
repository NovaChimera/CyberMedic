using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using CyberMedic.WinUI.Services;
using System;
using System.Threading.Tasks;

namespace CyberMedic.WinUI.Pages;

public sealed partial class HomePage : Page
{
    private readonly PowerShellService _ps;

    public HomePage()
    {
        InitializeComponent();
        _ps = new PowerShellService(@"C:\Users\User\Desktop\git\stampante\CyberMedic_Core.ps1");
        Loaded += async (s, e) => await RefreshAsync();
    }

    private async Task RefreshAsync()
    {
        try
        {
            OutputBox.Text = "Caricamento info sistema...";
            var osInfo = await _ps.RunCommandAsync("(Get-CimInstance Win32_OperatingSystem).Caption + ' ' + (Get-CimInstance Win32_OperatingSystem).Version");
            var cpuInfo = await _ps.RunCommandAsync("(Get-CimInstance Win32_Processor | Select-Object -First 1).Name");
            var ramInfo = await _ps.RunCommandAsync("$os = Get-CimInstance Win32_OperatingSystem; [math]::Round($os.TotalVisibleMemorySize/1MB,1).ToString() + ' GB totali, ' + [math]::Round($os.FreePhysicalMemory/1MB,1).ToString() + ' GB liberi'");
            var officeInfo = await _ps.RunCommandAsync("if (Get-Command Get-OfficeLicenseStatus -ErrorAction SilentlyContinue) { Get-OfficeLicenseStatus } else { 'Office license info non disponibile' }");

            OsInfoText.Text = $"OS: {osInfo.Trim()}";
            CpuInfoText.Text = $"CPU: {cpuInfo.Trim()}";
            RamInfoText.Text = $"RAM: {ramInfo.Trim()}";
            OfficeInfoText.Text = officeInfo.Trim();
            OutputBox.Text = "Info sistema aggiornate.";
        }
        catch (Exception ex)
        {
            OutputBox.Text = $"Errore: {ex.Message}";
        }
    }

    private async void RefreshButton_Click(object sender, RoutedEventArgs e)
    {
        await RefreshAsync();
    }
}
