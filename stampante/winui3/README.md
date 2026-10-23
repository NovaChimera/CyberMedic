# CyberMedic - WinUI 3 (in sviluppo)

Progetto in fase di scaffold: la UI WinUI 3 e' una riscrittura completa
dell'interfaccia WinForms. Il backend PowerShell resta la fonte di verita'
della logica di sistema, richiamato tramite `PowerShellService`.

## Prerequisiti per compilare

- Windows 10 1809+ / Windows 11
- Visual Studio 2022 17.8+ con workload "Windows application development"
- .NET 8 SDK
- Windows App SDK 1.5

## Stato

- [x] Struttura del progetto (solution, csproj, App, MainWindow)
- [x] NavigationView con le 8 schede
- [x] HomePage placeholder con wrapper PowerShell
- [ ] Pagine delle schede (Printers, Network, TaskManager, Updates, Maintenance, Mail, Cybersecurity)
- [ ] Controlli nativi WinUI 3 (ListView, Chart, ToggleButton, Card)
- [ ] Binding MVVM (CommunityToolkit.Mvvm)
- [ ] Packaging MSIX
- [ ] Installer con scelta portable/installata

## Avvio

Aprire `CyberMedic.WinUI.sln` in Visual Studio e premere F5.

## Note

Il backend PowerShell (`CyberMedic_Core.ps1` e i moduli `core\`) non viene
modificato: viene richiamato come processo esterno. La logica di sistema
resta unica e condivisa fra la versione WinForms (portabile) e la versione
WinUI 3 (installata).
