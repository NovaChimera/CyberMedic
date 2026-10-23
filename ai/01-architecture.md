# 01 - Architettura

## Schema complessivo

```
launch.ps1
    │  auto-elevazione UAC, forwarding argomenti
    ▼
CyberMedic_GUI.ps1  (thin client)
    │  dot-sourcing del backend
    ▼
CyberMedic_Core.ps1  (backend: logica di sistema)
    │  dot-sourcing dei moduli
    ├── core\metrics.ps1
    ├── core\updates.ps1
    ├── core\maintenance.ps1
    ├── core\outlook.ps1
    ├── core\office.ps1
    ├── core\wifi.ps1
    └── core\cybermedic.ps1

gui\theme.ps1        (design system Fluent)
gui\splash.ps1       (splash di avvio)
gui\tabs\*.ps1       (una scheda per file)
```

## Architettura Thin Client (D-002)

Il backend e il front-end sono due file separati, a loro volta composti da
moduli caricati con il dot-sourcing. Questo permette di testare il backend
senza interfaccia (SelfTest) e di rifare la UI senza toccare la logica
(SmokeTest).

**Conseguenza**: il Core non conosce WinForms. Comunica con l'interfaccia
attraverso tre canali, tutti protetti da controlli null.

## Contratto Core → Client

| Canale | Uso |
| --- | --- |
| `$script:Ui.LogBox` | Eco del registro nella casella di log |
| `$script:LogEntries` | Registro della sessione (lista generica) |
| `$script:PendingCommands` | Coda dei processi esterni in background |

Il backend restituisce dati semantici (testo, badge, chiave di stato
`muted`/`error`/`success`/`accent`/`warning`) e il thin client li traduce nei
colori del tema. Le scelte cromatiche restano nel front-end.

## Register dei controlli: `$script:Ui`

Ogni modulo GUI registra i propri controlli in `$script:Ui` ( hashtable
inizializzata dal Core). Il SmokeTest verifica la presenza e il popolamento di
questi riferimenti: è il contratto fra costruzione della UI e verifica
automatica.

Chiavi principali: `Form`, `MainTabs`, `Tabs`, `Split`, `Toolbar`,
`PrinterList`, `DetailList`, `HomeBox`, `StatusLabel`, `SpoolerLabel`,
`ElevLabel`, `ActivityCharts`, `ActivityChartButtons`, `ActivityMetricBoxes`,
`ActivityGauges`, `ActivityDetail`, `ActivityLog`, `ActivityQueue`,
`HardwareReport`, `MaintList`, `MaintPackageIds`, `DriverList`,
`MaintenanceConsole`, `UpdateCharts`, `UpdatesTab`, `OutlookList`,
`SafePsCommand`, `OfficeKey`, `OfficeOutput`, `CyberOutput`, `NetBox`,
`PrefetchCheck`, `NmapPreset`, `NmapCustom`, `MaintenanceOutput`.

## Regole di robustezza (non violare)

1. **Ogni handler WinForms che usa `$sender` deve avere un blocco `param()`.**
   In PowerShell 5.1 e 7 `$sender` non è disponibile automaticamente dentro uno
   scriptblock registrato come handler: va dichiarato esplicitamente come
   parametro. Senza questo, `$sender` è `$null` e le chiamate a funzioni con
   parametri obbligatori falliscono.
   Formato corretto:
   ```powershell
   $button.Add_Resize({ param($sender) Set-FluentCorners -Control $sender -Radius 6 })
   $button.Add_Click({ param($sender, $eventArgs) ... })
   ```

2. **Le funzioni che restituiscono un controllo devono restituire un solo oggetto.**
   Ogni chiamata che emette output va wrappata in `[void](...)`, altrimenti il
   chiamante riceve un array e le operazioni sul controllo falliscono.

3. **`try/catch` ovunque**: il tool non deve mai terminare in modo anomalo.

4. **Niente `GetNewClosure()`** nei callback GUI: `script:` non è visibile nel
   relativo scope.

5. **Codice asincrono via `Start-BackgroundCommand`** per qualsiasi comando
   esterno lento; il callback ha firma `param($text, $exitCode, $cmdArgs, $task)`.

## Coda dei comandi in background (`$script:PendingCommands`)

È una lista: più comandi in background (es. `ipconfig` e `winget upgrade`)
possono essere in esecuzione contemporanea senza che i callback si sovrascrivano.
Il timer del thin client (400 ms) consuma la coda e invoca i callback dei
comandi terminati; la coda è limitata a 8 elementi consumati per tick.

## Coda operativa sequenziale (`$script:TaskQueue`)

`Add-QueuedTask` accoda il lavoro, `Start-NextQueuedTask` avvia la coda solo
quando non ci sono processi in corso e il callback di completamento avvia
l'attività successiva. Ogni task riceve il proprio oggetto come quarto argomento
del callback, così il client non dipende da variabili di funzione.
`winget` e l'installazione dei driver non possono girare in parallelo.

## Compatibilità

- Windows PowerShell 5.1 e PowerShell 7: niente `#Requires -Version 7.0`, niente
  sintassi esclusiva di PS7.
- `launch.ps1` seleziona `pwsh.exe` quando disponibile e ripiega su
  `powershell.exe`.
- I file vanno salvati in UTF-8 con BOM.