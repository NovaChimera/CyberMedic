# CyberMedic - Roadmap

Backlog aperto, in ordine di priorita'. Ogni voce indica il file coinvolto e
il criterio di accettazione.

## P0 - Rilascio 3.0.1

| # | Attivita' | File | Accettazione |
| --- | --- | --- | --- |
| 1 | Aggiornare `RELEASE_NOTES.md` con le correzioni 3.0.1 | `RELEASE_NOTES.md` | Sezione 3.0.1 in testa, con le 9 correzioni della sessione 2026-10-22 |
| 2 | Aggiornare il README (struttura `docs/`, moduli GUI, conteggi test) | `README.md` | Struttura del repository allineata al contenuto reale |
| 3 | Bump di versione e build | `product.psd1` | `Version = '3.0.1'`, `BuildDate` aggiornata |
| 4 | Deploy in `C:\CyberMedic` | vedi `docs/DEPLOY.md` | SmokeTest e SelfTest verifi dalla directory installata |

## P1 - Qualita' del codice

| # | Attivita' | File | Accettazione |
| --- | --- | --- | --- |
| 5 | Verificare tutti i `Add_Click` / `Add_Resize` / `Add_Mouse*` per il blocco `param()` | `gui\*.ps1`, `CyberMedic_GUI.ps1` | Nessun handler usa `$sender` senza dichiararlo come parametro |
| 6 | Verificare che ogni funzione costruttrice restituisca un solo oggetto | `gui\theme.ps1` | Nessuna emissione multipla dalle funzioni `New-*` |
| 7 | Allineare la checklist dello splash al numero reale di moduli | `CyberMedic_GUI.ps1` | I numeri derivano da `$script:GuiModules.Count` e `$script:CoreModules.Count` invece di essere scritti a mano |
| 8 | Verifica statica dei file in `archive\` | `archive\stampanti-v2.0.0.ps1` | Il file non e' piu' caricato a runtime: nessun action richiesto, ma va documentato come "solo riferimento" |

## P2 - Funzionalita'

| # | Attivita' | File | Accettazione |
| --- | --- | --- | --- |
| 9 | Refresh manuale degli aggiornamenti | `gui\tabs\updates.ps1` | Pulsante "Aggiorna" che forza `Load-UpdatePackages -Force` (la cache attuale e' di 5 minuti) |
| 10 | Esportazione del report di diagnostica hardware | `gui\tabs\taskmanager.ps1` | Esportazione del testo di `$script:Ui.HardwareReport` in file |
| 11 | Filtro e ordinamento nella scheda Cybersecurity | `gui\tabs\cybersecurity.ps1` | Elenco dei controlli di sicurezza filtrabile per esito |
| 12 | Persistenza delle preferenze di visualizzazione | da definire | Tema e layout riportati al riavvio (richiede un file di impostazioni) |

## P3 - Debito tecnico noto

| # | Attivita' | Nota |
| --- | --- | --- |
| 13 | `CyberMedic_Core.ps1` supera le 2300 righe | Valutare l'estrazione dei blocchi stampanti/rete in moduli core dedicati |
| 14 | `gui\tabs\taskmanager.ps1` supera le 500 righe | Estrazione dei grafici e della diagnostica in `gui\charts.ps1` |
| 15 | `stampante.txt` (0 byte) nella root | Residuo del nome storico: rimuovere |
| 16 | Nessun repository Git attivo | La cartella di sviluppo non e' un repository Git: i backup sono manuali |

## P4 - WinUI 3 (nuova interfaccia grafica)

Struttura in `winui3/` (scaffold creato, richiede Visual Studio + .NET 8 + Windows App SDK).

| # | Attivita' | Stato |
| --- | --- | --- |
| 17 | Creare la solution e il progetto WinUI 3 | Fatto (scaffold) |
| 18 | NavigationView con le 8 schede | Fatto (MainWindow) |
| 19 | Wrapper PowerShell (`PowerShellService`) | Fatto (base) |
| 20 | HomePage con metriche live | Placeholder |
| 21 | Pagine delle schede (Printers, Network, TaskManager, Updates, Maintenance, Mail, Cybersecurity) | Da fare |
| 22 | Controlli nativi WinUI 3 (ListView, Chart, ToggleButton, Card) | Da fare |
| 23 | Binding MVVM (CommunityToolkit.Mvvm) | Da fare |
| 24 | Packaging MSIX | Da fare |
| 25 | Installer con scelta portable/installata | Da fare |

- Esportazione di un report HTML dal pannello Home.
- Installazione come servizio Windows per la raccolta metriche continua.
- Sincronizzazione delle impostazioni fra postazioni.
