using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace CyberMedic.WinUI;

public sealed partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        ContentFrame.Navigate(typeof(Pages.HomePage));
        Activated += MainWindow_Activated;
    }

    private bool _dialogShown;

    private async void MainWindow_Activated(object sender, WindowActivatedEventArgs e)
    {
        if (_dialogShown) return;
        _dialogShown = true;

        var dialog = new ContentDialog
        {
            Title = "CyberMedic - Scelta modalità",
            Content = "Come vuoi utilizzare CyberMedic?\n\n" +
                      "• Portable: esecuzione senza installazione, nessuna modifica al sistema.\n" +
                      "• Installato: installazione completa con integrazione nel menu Start.",
            PrimaryButtonText = "Portable",
            SecondaryButtonText = "Installato",
            DefaultButton = ContentDialogButton.Primary,
            XamlRoot = Content.XamlRoot
        };

        var result = await dialog.ShowAsync();
        Title = result == ContentDialogResult.Primary
            ? "CyberMedic - Portable"
            : "CyberMedic - Installato";
    }

    private void NavView_SelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (args.SelectedItem is NavigationViewItem item && item.Tag is string tag)
        {
            var pageType = tag switch
            {
                "Home" => typeof(Pages.HomePage),
                "Printers" => typeof(Pages.PrintersPage),
                "Network" => typeof(Pages.NetworkPage),
                "TaskManager" => typeof(Pages.TaskManagerPage),
                "Updates" => typeof(Pages.UpdatesPage),
                "Maintenance" => typeof(Pages.MaintenancePage),
                "Mail" => typeof(Pages.MailPage),
                "Cybersecurity" => typeof(Pages.CybersecurityPage),
                _ => typeof(Pages.HomePage)
            };
            ContentFrame.Navigate(pageType);
        }
    }
}
