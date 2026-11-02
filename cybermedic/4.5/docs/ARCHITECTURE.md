# CyberMedic - Architettura

## Visione

CyberMedic e' una suite di supporto tecnico di postazione, senza dipendenze
esterne: tutto risiede in script PowerShell e WinForms.

```
launch.ps1  ->  CyberMedic_GUI.ps1  ->  CyberMedic_Core.ps1
                    (thin client)         (backend)
                         |
                         +-- gui\theme.ps1        design system Fluent
                         +-- gui\splash.ps1       splash di avvio
                         +-- gui\tabs\*.ps1       una scheda per file
```

## Componenti

| Componente | Ruolo |
| --- | --- |
| `launch.ps1` | Auto-elevazione (UAC) e avvio del thin client; preferisce `pwsh.exe`, ripiega su `powershell.exe` |
| `CyberMedic_Core.ps1` | Backend: logica di sistema, WMI/CIM, registro, rete, sicurezza, spooler, stampanti |
| `core\*.ps1` | Moduli del backend, caricati per dot-sourcing |
| `CyberMedic_GUI.ps1` | Thin client: costruzione dei controlli, eventi, tema, dispatch della sessione |
| `gui\theme.ps1` | Design system in stile WinUI 3 (angoli arrotondati, hover, toggle, card, tab disegnate, gradiente) |
| `gui\splash.ps1` | Splash di avvio con checklist dei passi |
| `gui\tabs\*.ps1` | Schede modulari: ognuna espone `New-XxxTab -MainTabs` e registra i controlli in `$script:Ui` |
| `product.psd1` | Identita' del prodotto: unica fonte di verita' |

## Moduli del backend (`core\`)

| Modulo | Funzioni principali |
| --- | --- |
| `metrics.ps1` | `Get-ResourceMetrics`, `Get-ThermalState`, `Get-DiskHealth`, cache termica e SMART |
| `updates.ps1` | Wrapping di Winget, coda pacchetti (`Add-QueuedTask`, `Get-QueuedTask`), driver di sistema |
| `maintenance.ps1` | Pulizia temporanei, cambio password utente, console PowerShell sicura |
| `outlook.ps1` | SCANPST, archivi PST/OST, cache di Outlook |
| `office.ps1` | Info prodotti Office, licenze via `OSPP.VBS`, rimozione con disinstallatori ufficiali |
| `wifi.ps1` | Inventario interfacce wireless e profili salvati (senza materiale chiave) |
| `cybermedic.ps1` | Riparazione rete, analisi file hosts, Microsoft Defender, catalogo Nmap |

## Moduli del front-end (`gui\`)

| Modulo | Funzioni principali |
| --- | --- |
| `theme.ps1` | `New-FluentButton`, `New-FluentToggleButton`, `Set-FluentToggleState`, `New-FluentCard`, `Enable-FluentTabs` |
| `splash.ps1` | `Show-SplashScreen`, `Set-SplashSteps`, `Set-SplashProgress`, `Complete-Splash` |
| `tabs\taskmanager.ps1` | Metriche live, grafici on-demand, diagnostica hardware, log e coda |
| `tabs\updates.ps1` | Aggiornamenti Winget, driver di sistema, grafici prestazione, coda |
| `tabs\maintenance.ps1` | Nmap, pulizia, strumenti di rete |
| `tabs\mail.ps1` | Posta & Outlook |
| `tabs\cybersecurity.ps1` | Sicurezza: hosts, Defender, riparazione rete |

## Le 8 schede principali

1. `🛡️ Home / Dashboard`
2. `🖨️ Gestione Stampanti`
3. `📡 Network & Rete`
4. `⚡ Task Manager`
5. `📦 Updates`
6. `🧹 Maintenance`
7. `📧 Mail & PowerShell`
8. `🛡️ Cybersecurity`

## Contratto Core -> Client

Il backend non conosce WinForms. Comunica con l'interfaccia attraverso tre
punti, tutti protetti da controlli null:

| Canale | Uso |
| --- | --- |
| `$script:Ui.LogBox` | Eco del registro nella casella di log |
| `$script:LogEntries` | Registro della sessione |
| `$script:PendingCommands` | Coda dei processi esterni in background |

Il backend restituisce dati semantici (testo, badge, chiave `muted/error/
success/accent/warning`); il thin client li traduce nei colori del tema.

## Register dei controlli: `$script:Ui`

Ogni modulo GUI registra i propri controlli in `$script:Ui` (una hashtable
inizializzata dal Core). Il SmokeTest verifica la presenza e il popolamento di
questi riferimenti: e' il contratto fra costruzione della UI e verifica
automatica.

Chiavi principali: `Form`, `MainTabs`, `Tabs`, `Split`, `Toolbar`,
`PrinterList`, `DetailList`, `HomeBox`, `StatusLabel`, `SpoolerLabel`,
`ElevLabel`, `ActivityCharts`, `ActivityChartButtons`, `ActivityMetricBoxes`,
`ActivityGauges`, `ActivityDetail`, `ActivityLog`, `ActivityQueue`,
`HardwareReport`, `MaintList`, `MaintPackageIds`, `DriverList`,
`MaintenanceConsole`, `UpdateCharts`, `UpdatesTab`, `OutlookList`,
`SafePsCommand`, `OfficeKey`, `OfficeOutput`, `CyberOutput`, `NetBox`,
`PrefetchCheck`, `NmapPreset`.

## Regole di robustezza (non violare)

1. **Ogni handler WinForms che usa `$sender` deve avere un blocco `param()`.**
   In PowerShell 5.1 e 7 `$sender` **non** e' disponibile automaticamente
   dentro uno scriptblock registrato come handler: va dichiarato esplicitamente
   come parametro. Senza questo, `$sender` e' `$null` e le chiamate a funzioni
   con parametri obbligatori falliscono con
   "Impossibile associare l'argomento al parametro 'X' perché è Null".
   Formato corretto:
   ```powershell
   $button.Add_Resize({ param($sender) Set-FluentCorners -Control $sender -Radius 6 })
   $button.Add_Click({ param($sender, $eventArgs) ... })
   ```
2. **Le funzioni che restituiscono un controllo devono restituire un solo
   oggetto.** Ogni chiamata che emette output va wrappata in `[void](...)`,
   altrimenti il chiamante riceve un array e le operazioni sul controllo
   (`.Tag`, `.Text`, `.Visible`) falliscono.
3. **`try/catch` ovunque**: il tool non deve mai terminare in modo anomalo.
4. **Niente `GetNewClosure()`** nei callback GUI: `script:` non e' visibile nel
   relativo scope.
5. **Codice asincrono via `Start-BackgroundCommand`** per qualsiasi comando
   esterno lento; il callback ha firma
   `param($text, $exitCode, $cmdArgs, $task)`.
