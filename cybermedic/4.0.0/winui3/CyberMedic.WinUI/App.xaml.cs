using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace CyberMedic.WinUI;

public partial class App : Application
{
    public App() { InitializeComponent(); }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        new MainWindow().Activate();
    }
}
