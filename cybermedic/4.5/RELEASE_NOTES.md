# CyberMedic - Note di rilascio


## 3.0.1 - 2026-10-22

Tema: **correzione del crash di avvio e consolidamento WinUI 3**.

### Correzioni

- **Crash di avvio della GUI risolto**: `Controls.Add` con argomento `Control`
  null. Causa: gli handler WinForms registrati come scriptblock non ricevono
  automaticamente `$sender` in PowerShell 5.1 e 7. Tutti gli handler senza
  blocco `param()` ora usano `param($sender)` (o `param($sender, $e)`).
- **`New-FluentToggleButton` restituiva due oggetti**: il `True` di
  `Set-FluentToggleState` piu' il bottone. Wrappato in `[void](...)`.
- **SmokeTest**: conteggio dei moduli GUI aggiornato da 6 a 7 (era fermo a
  prima di `gui\theme.ps1`).
- **Etichette splash** allineate: "Moduli core (5)" -> 7, "Schede GUI
  modulari (5)" -> 7.
- **Cache degli aggiornamenti**: `$script:UpdatesLoadedAt` inizializzata a
  `$null` a livello di modulo.
- **Caricamento automatico degli aggiornamenti**: `Load-UpdatePackages` parte
  in background all'avvio, non solo aprendo la scheda Updates.
- **Grafici prestazione non piu' fermi**: `Update-ActivityMetrics` invalida
  anche `$script:Ui.UpdateCharts`.
- **Toggle in stile WinUI 3 nel Task Manager**: i tre pulsanti dei grafici
  usano `New-FluentToggleButton`, in coerenza con la scheda Updates.
- **SmokeTest esteso**: da 28 a 29 controlli (nuovo "Toggle in stile
  WinUI").

### Note

- Nessun cambiamento di comportamento utente: solo correzioni e consolidamento.
- Compatibilita' verificata su Windows PowerShell 5.1 e PowerShell 7.

## 3.0.0 - 2026-10-22

Tema: **CyberMedic - rinomina del prodotto, utility Office e Wi-Fi avanzato**.

### Novita'

- **Rinomina completa del prodotto in CyberMedic**: file, moduli, funzioni e
  interfacce. `NovaChimera_Core.ps1` -> `CyberMedic_Core.ps1`,
  `NovaChimera_GUI.ps1` -> `CyberMedic_GUI.ps1`, log `cybermedic-<data>.log`,
  report `report-cybermedic-<data>.csv` e `diagnostica-cybermedic-<data>.txt`.
  L'identita' resta centralizzata in `product.psd1`:

  ```powershell
  @{
      Name      = 'CyberMedic'
      Version   = '3.0.0'
      Edition   = 'Enterprise IT Helpdesk Suite'
      BuildDate = '2026-10-22'
      Slogan    = 'Advanced IT Diagnostics & Maintenance'
      Accent    = '#b388ff'
      Theme     = 'Obsidian Purple WinUI3 Style'
  }
  ```

- **Riquadro "Office e licenze" nella Home** (nuovo modulo `core\office.ps1`):
  - inserimento della Product Key con `OSPP.VBS /inpkey` e attivazione con
    `/act`; la chiave vuota o malformata **interrompe l'operazione con un
    messaggio esplicito** e non esegue alcun comando (risolve l'errore
    "Impossibile associare l'argomento al parametro 'Key' perche' e' una
    stringa vuota");
  - lettura dello stato delle licenze con `OSPP.VBS /dstatus`;
  - piano di rimozione Office basato sulle **stringhe di disinstallazione
    ufficiali** del registro: nessuna cancellazione manuale delle cartelle di
    Office, quindi nessuna installazione corrotta.
- **Informazioni Wi-Fi avanzate** (nuovo modulo `core\wifi.ps1`): inventario
  dell'interfaccia wireless (SSID, BSSID, stato, tipo radio, autenticazione,
  crittografia, canale, segnale, velocita' di ricezione e trasmissione) e
  elenco dei profili salvati. E' un inventario di rete: il materiale chiave dei
  profili non viene estratto.
- **Box separati per le risorse del Task Manager**: CPU, RAM, disco di sistema
  e scheda grafica hanno ciascuno un riquadro proprio con valori live,
  indipendenti l'uno dall'altro e aggiornati insieme al riepilogo.
- **Box separati nella scheda Updates**: `Aggiornamenti applicazioni (Winget)` e
  `Driver di sistema` sono due riquadri distinti, con selezione e coda
  indipendenti.
- **SelfTest a 38 controlli**: nuovi controlli `Utility Office`, `Chiave
  Office vuota gestita` e `Inventario Wi-Fi`.
- **SmokeTest a 28 controlli**: nuovi controlli `Riquadro Office`, `Riquadri
  metriche` e `Box App e Driver`.

### Correzioni

- Il messaggio di errore dello smoke test riporta ora lo stack trace della
  chiamata, rendendo immediatamente individuabile il punto di fallimento.
- Il log di avvio non riporta piu' il nome del prodotto storico: usa
  l'identita' di `product.psd1`.

### Verifiche eseguite

| Ambito | Esito |
| --- | --- |
| Parsing PS 5.1 / 7.6.7 | 0 errori su 16 script |
| SelfTest | 38/38 su entrambe le versioni |
| SmokeTest | 28/28 su entrambe le versioni |
| Avvio reale | splash blu -> dashboard, titolo `CyberMedic v3.0.0 - Enterprise IT Helpdesk Suite` |
| BOM | UTF-8 con BOM su script e documenti |


## 2.5.0 - 2026-10-21

Tema: **identita' del prodotto centralizzata e schermata di avvio blu**.

### Novita'

- **`product.psd1`: identita' in un solo file.** Nome, versione, edizione, data
  di build, slogan e colore dello splash sono definiti in un unico file di
  configurazione accanto a `launch.ps1`:

  ```powershell
  @{
      Name      = 'StampantiTool'
      Version   = '2.5.0'
      Edition   = 'IT Enterprise Suite'
      BuildDate = '2026-10-21'
      Slogan    = 'Supporto Helpdesk & Ticket - gestione stampanti, rete e postazione IT'
      Accent    = '#4d9dff'
      Theme     = 'Blue'
  }
  ```

  il Core lo carica all'avvio (`Initialize-ProductIdentity`) e **tutte** le
  stringhe di prodotto (splash, titolo finestra, header, caption dei dialoghi,
  banner del log, controllo di identita' del SelfTest) derivano da qui: non
  esistono piu' nomi o versioni hardcoded nel codice.
- **Override puntuale dell'identita'**, con priorita' decrescente:
  1. argomenti `-ProductName` / `-ProductVersion` (solo per l'avvio corrente);
  2. variabili d'ambiente `APP_PRODUCT_NAME` / `APP_PRODUCT_VERSION`;
  3. `product.psd1` (valore permanente per la postazione);
  4. fallback interni del Core, usati solo se il file di configurazione manca.
- **Schermata di avvio blu** (`gui\splash.ps1`): sfondo navy, banda del titolo,
  accento configurabile, nome del prodotto, edizione, versione, build e
  slogan, piu' una **checklist dei passi di avvio** con marcatori `[ OK ]` /
  `[ .. ]`. La barra resta determinata e la dashboard si apre solo al 100%.
- **Checklist di avvio a 7 passi** visualizzata nello splash: backend core,
  moduli core, schede GUI, inventario stampanti, dashboard, metriche e
  diagnostica hardware, layout e log.
- **SelfTest a 35 controlli**: nuovo controllo `Identita prodotto` che
  verifica nome, versione e sorgente della configurazione; il controllo
  `Versione toolkit` non e' piu' legato a una versione cablata nel codice.
- **SmokeTest**: il controllo del titolo verifica contemporaneamente nome e
  versione dell'identita' configurata.

### Correzioni

- Tutte le finestre di dialogo dell'interfaccia usano la caption del prodotto
  configurata: restavano 15 occorrenze del nome storico hardcoded.
- La finestra "Informazioni" riporta edizione e build, non piu' una stringa
  fissa.

### Verifiche eseguite

| Ambito | Esito |
| --- | --- |
| Parsing PS 5.1 / 7.6.7 | 0 errori su 14 script |
| SelfTest | 35/35 su entrambe le versioni |
| SmokeTest | 25/25 su entrambe le versioni |
| Avvio reale | splash blu -> dashboard, titolo `StampantiTool v2.5.0 - IT Enterprise Suite` |
| BOM | UTF-8 con BOM su script e documenti |


## 2.4.0 - 2026-10-21

Tema: **architettura modulare, otto schede operative, ripristino di rete e
diagnostica di sicurezza**.

### Novita'

- **Architettura modulare** (la novita' strutturale della release):
  - il backend `NovaChimera_Core.ps1` e' ora affiancato dalla cartella `core\`,
    con un file per dominio: `metrics.ps1`, `updates.ps1`, `maintenance.ps1`,
    `outlook.ps1`, `cybermedic.ps1`;
  - il thin client `NovaChimera_GUI.ps1` carica i moduli front-end dalla
    cartella `gui\`: `splash.ps1` e una scheda per file in `gui\tabs\`
    (`taskmanager.ps1`, `updates.ps1`, `maintenance.ps1`, `mail.ps1`,
    `cybermedic.ps1`);
  - ogni modulo e' caricato per dot-sourcing dentro un `try/catch` con
    controllo di esistenza: l'assenza di un modulo non impedisce l'avvio
    della GUI, ma viene registrata nel log di sessione;
  - i tre script di primo livello (`NovaChimera_Core.ps1`,
    `NovaChimera_GUI.ps1`, `launch.ps1`) restano i punti d'ingresso e non
    sono stati sostituiti.
- **Interfaccia a 8 schede**: Home / Dashboard, Gestione Stampanti,
  Network & Rete, **Task Manager**, **Updates**, **Maintenance**,
  **Mail & PowerShell**, **CyberMedic**.
- **Splash di avvio deterministico**: la barra di avanzamento e' reale (non
  piu' un marquee) e la dashboard viene aperta **solo al 100%** dell'avvio.
  Lo splash non ha pulsanti e non puo' essere saltato; i passi (inventario,
  costruzione dell'interfaccia, primo aggiornamento dei dati) sono annunciati
  nella riga di stato e il completamento viene scritto nel log
  (`Inizializzazione completata: dashboard pronta`).
- **Grafici on-demand nel Task Manager**: i tre grafici (CPU, RAM, disco)
  nascono **spenti** e si attivano solo con i pulsanti dedicati `📈 CPU`,
  `📈 RAM`, `📈 Disco`; il pulsante attivo diventa `📉` e nasconde di nuovo
  il grafico. Ogni grafico e' tracciato sulla propria serie storica (60
  campioni).
- **Diagnostica hardware** (Task Manager): nuovo riquadro con il **thermal
  throttling della CPU** (zona termica ACPI confrontata con la soglia
  critica) e la **salute SMART dei dischi** (temperatura, usura, ore accese,
  errori di lettura, stato `Healthy`/`Warning`), aggiornabile con un
  pulsante.
- **Nuova scheda `Task Manager`**: tre gauge (CPU, memoria, disco) disegnati in
  `GDI+` con soglie verde / giallo (70%) / rosso (85%), riepilogo delle
  risorse, registro live (ultime 400 righe) aggiornato ogni 2 secondi e
  pannello della coda operazioni.
- **Nuova scheda `Updates`**: pacchetti aggiornabili da `winget` con selezione
  multipla, elenco dei driver di sistema con riepilogo, coda sequenziale
  applicazioni + driver con console live, aggiornamento globale
  `winget upgrade --all`.
- **Nuova scheda `Maintenance`**: piano di pulizia con dimensione e numero di
  file per cartella (`%TEMP%`, `%SystemRoot%\Temp`, `Prefetch`), pulizia
  effettiva con conferma separata per `Prefetch` (Microsoft ne sconsiglia la
  rimozione perche' rallenta il primo avvio delle applicazioni), cambio
  password dell'utente locale e scansioni Nmap con preset o argomenti
  personalizzati.
- **Nuova scheda `Mail & PowerShell`**: rilevamento di `SCANPST.EXE` e degli
  archivi PST/OST del profilo, scansione dell'archivio selezionato,
  **sincronizzazione dell'archivio**, **ricostruzione della cache di Outlook**
  (con backup datato), **report degli archivi** e **console PowerShell in
  sola lettura** con catalogo di 21 comandi consentiti (`Get-Process`,
  `Get-NetAdapter`, `Get-MpComputerStatus`, ...); i token che modificano il
  sistema (`Remove-`, `Set-`, `New-`, `Start-`, `Stop-`, `Out-File`,
  `Invoke-Expression`, ...) vengono bloccati e registrati.
- **Nuova scheda `CyberMedic`**: catalogo di 7 interventi di riparazione di
  rete (reset Winsock, reset TCP/IP, flush DNS, release/renew dell'IP, flush
  della cache ARP, reimposta dell'adapter), analisi del file `hosts` con
  segnalazione delle voci sospette, stato di Microsoft Defender e avvio della
  scansione rapida. Gli interventi che richiedono elevazione propongono il
  riavvio dell'applicazione come amministratore.
- **Splash di avvio**: finestra non ridimensionabile con nome del prodotto,
  versione e barra di caricamento, mostrata per 1,4 secondi all'avvio.
- **Backend modulare (`core\*.ps1`)**:
  - `metrics.ps1`: `Get-ResourceMetrics`, `Get-ThermalState`, `Get-DiskHealth`;
  - `updates.ps1`: `Get-WingetUpgradeList`, `Get-WingetList`,
    `Update-SingleWingetPackageSilently`, `Get-SystemDriversList` e la coda
    `Add-QueuedTask` / `Get-QueuedTask` / `Clear-QueuedTask` /
    `Start-NextQueuedTask`;
  - `maintenance.ps1`: `Get-CleanupTarget`, `Invoke-TempCleanup`,
    `Set-LocalUserPassword`, `Get-SafePowerShellCatalog`,
    `Invoke-SafePowerShellCommand`;
  - `outlook.ps1`: `Get-OutlookInstallation`, `Invoke-OutlookScanPst`,
    `Sync-OutlookArchive`, `Repair-OutlookCache`;
  - `cybermedic.ps1`: `Get-NetworkRepairCatalog`, `Get-NetworkRepairCommand`,
    `Get-HostsFileAnalysis`, `Get-DefenderStatus`, `Start-DefenderQuickScan`,
    `Get-SecurityQuickScan`, `Get-NmapCommand -Preset`, `ConvertTo-CommandArgumentArray`.
- **SelfTest a 34 controlli** (era 23) e **SmokeTest a 25 controlli** (era 18):
  oltre ai controlli storici vengono verificati sensore termico, stato SMART,
  catalogo di riparazione di rete, analisi del file hosts, Microsoft Defender,
  console PowerShell sicura, piani di pulizia, caricamento dei moduli core,
  console Maintenance, opzione Prefetch, catalogo PowerShell e console
  CyberMedic, cache termica e SMART, report degli archivi di posta, adapter
  di rete attivo, i tre grafici on-demand (con il grafico CPU spento
  all'avvio), la diagnostica hardware e i moduli delle schede.

### Correzioni

- **Archivio Outlook selezionato**: il percorso del file era letto dalla
  colonna sbagliata (`SubItems[3]`, cioe' la data di modifica) e la scansione
  partiva senza bersaglio. Ora ogni voce dell'elenco conserva il percorso
  completo nel `Tag` dell'elemento, con fallback sulla colonna
  `Percorso`: scansione, sincronizzazione e report agiscono sempre sull'archivio
  effettivamente selezionato.
- **Grafico CPU sempre attivo**: il grafico dell'andamento era permanently
  visibile e costringeva a ridimensionare gli altri riquadri. Ora i grafici
  CPU, RAM e disco sono spenti all'avvio e si attivano a richiesta.
- **Prestazioni del monitoraggio**: ogni ciclo di 2 secondi eseguiva
  `Win32_Processor` e `Get-NetAdapter` (circa 2,5 secondi di WMI) piu' le
  query termiche e SMART, saturando il thread della GUI. Ora il carico della
  CPU usa il `PerformanceCounter` (con ripiego su WMI), l'adapter arriva
  dalle API .NET e termica e SMART sono memorizzati in cache per 60 secondi:
  il ciclo scende a circa 290 ms.
- **Splash non deterministico**: la barra era in stile marquee e la finestra
  si chiudeva dopo un tempo fisso, indipendentemente dallo stato reale
  dell'avvio. Ora la barra e' determinata e lo splash si chiude solo al 100%.
- **Log affollato**: il rilevamento termico fallito (permessi insufficienti)
  veniva scritto a ogni ciclo di aggiornamento. Con la cache il messaggio
  compare al massimo una volta al minuto.
- **Argomenti nmap**: i preset venivano passati come argomento unico
  (`"-F 127.0.0.1"`), quindi nmap riceveva un token solo e la scansione
  falliva. Ora ogni opzione e il target sono argomenti separati e la riga
  personalizzata viene spezzata in token rispettando le virgolette.
- **Callback delle code**: le callback invocate dal timer non vedevano le
  variabili locali della funzione che le aveva definite (scope non conservato
  dopo la fine della funzione): il messaggio di coda riportava un identificativo
  vuoto. Ora il task viene passato come quarto argomento della callback e la
  coda usa `GetNewClosure()` solo dove serve davvero (non nei callback GUI,
  dove `script:` non e' visibile).
- **Aggiornamento dei pacchetti**: l'avvio era simultaneo per tutti i
  pacchetti selezionati, con esito raccolto solo alla fine. Ora i pacchetti
  vengono elaborati in sequenza e il risultato e' visibile durante
  l'esecuzione.
- **Porte stampanti**: la risoluzione usa `Get-PrinterPort` e il registro
  (`HKLM:\SYSTEM\CurrentControlSet\Control\Print\Monitors\Standard TCP\IP
  Port\Ports\<porta>`, valore `HostName`): le classi `Win32_PrinterPort` e
  `Win32_TCPIPPrinterPort` non esistono su tutte le postazioni e generavano
  errori silenziosi.
- **Codice pagina della console**: l'output dei comandi esterni viene
  decodificato con la codepage OEM invece di quello predefinito.

### Verifiche eseguite

| Ambito | Esito |
| --- | --- |
| Parsing sintattico (PS 5.1 / PS 7) | 0 errori su 14 script (Core, GUI, launcher, 5 moduli core, splash, 5 schede) |
| SelfTest PS 5.1 | 34 controlli, 0 falliti (3 avvisi: sessione non elevata, nmap assente, sensore termico assente) |
| SelfTest PS 7 (7.6.7) | 34 controlli, 0 falliti |
| SmokeTest PS 5.1 e PS 7 | 25 controlli, 0 falliti, 8 schede, titolo `NovaChimera v2.4.0` |
| Codepage dei file | UTF-8 con BOM su tutti gli script e i documenti |
| Avvio reale della GUI | Splash deterministico chiuso al 100%, dashboard pronta, nessun errore nel log |
| Grafici on-demand | 3 grafici (CPU, RAM, disco), tutti spenti all'avvio, attivazione e disattivazione dal pulsante |
| Diagnostica hardware | Thermal throttling e stato SMART dei dischi popolati nel riquadro |
| Ciclo di aggiornamento metriche | da ~2,4 s a ~0,29 s per campionamento |
| Driver di sistema | 173 dispositivi analizzati, 1 problema rilevato |
| Outlook | SCANPST rilevato in `Office16`, 0 archivi PST/OST nel profilo di test, report generato |
| Console PowerShell sicura | `Get-Date` eseguito; i token di modifica vengono rifiutati |
| Risorse di sistema | CPU, RAM, disco, GPU e adapter di rete letti correttamente |

### Limitazioni note

- Le metriche vengono aggiornate ogni 2 secondi: il carico della CPU e' una
  media istantanea, non un campionamento continuo. La prima lettura dopo
  l'avvio puo' riportare `0%` (il contatore ha bisogno di un secondo
  campione), quella successiva e' gia' valida.
- Il thermal throttling e' ricavato dalla zona termica ACPI e non dalla
  soglia `TjMAX` della CPU: su molte postazioni da ufficio la zona non e'
  esposta e il riquadro riporta "sensore non disponibile". Lo SMART, invece,
  e' letto realmente da `Get-PhysicalDisk` e `Get-StorageReliabilityCounter`.
- Il sensore termico ACPI e' disponibile solo su some postazioni: quando
  manca, il SelfTest lo segnala come avviso e non come errore.
- La ricostruzione della cache di Outlook richiede Outlook chiuso: con
  Outlook aperto l'operazione viene rifiutata e il messaggio viene
  riportato.
- La verifica dei driver usa `pnputil /scan-devices` e richiede la sessione
  elevata; senza privilegi l'operazione fallisce e l'esito viene riportato
  nella console.
- Il rilevamento degli archivi PST/OST si limita al profilo dell'utente
  corrente (`%APPDATA%` e `%LOCALAPPDATA%`): i file su other share di rete non
  vengono elencati.
- Nmap resta opzionale: senza il client installato i preset e la scansione
  personalizzata segnalano l'assenza del programma.
- L'aggiornamento in sequenza dei pacchetti puo' durare diversi minuti se sono
  selezionati molti pacchetti.
- Il reset di Winsock, di TCP/IP e degli adapter richiede un riavvio del PC
  per completare l'intervento.
- I grafici del Task Manager sono attivabili uno alla volta: mostrando un
  grafico, gli altri due vengono nascosti, perche' condividono la stessa
  area di disegno.

## 2.2.2 - 2026-10-21

Tema: **centro di manutenzione software** nella scheda Manutenzione & PC.

### Novita'

- **Elenco dei pacchetti aggiornabili**: la scheda *Manutenzione & PC* passa
  da una casella di output a una `CheckedListBox` con una riga per pacchetto
  (`Nome  [Id]  versione -> versione disponibile`), caricata con
  `winget upgrade`.
- **Sette comandi operativi** nella barra della scheda:
  - `🧹 Pulisci file temporanei`: pulizia di `%TEMP%` e `%SystemRoot%\Temp`
    con riepilogo di elementi rimossi, saltati e spazio liberato;
  - `📦 Carica aggiornamenti`: interroga winget in background e popola
    l'elenco con i pacchetti aggiornabili, gia' spuntati;
  - `☑️ Seleziona tutti` / `🔲 Deseleziona tutti`: spuntano o azzerano la
    selezione in un colpo;
  - `📥 Applica selezionati`: aggiorna **solo** i pacchetti spuntati, uno alla
    volta, con esito raccolto in una finestra di riepilogo scorrevole;
  - `🚀 Scarica e installa tutto`: esegue
    `winget upgrade --all --accept-source-agreements --accept-package-agreements`
    dopo conferma, con finestra di riepilogo dell'esito;
  - `🔑 Cambio password utente`: dialogo con utente e nuova password.
- **Parsing della tabella winget indipendente dalla lingua**: l'Id del
  pacchetto e' riconosciuto come token con un punto e almeno un segmento
  alfanumerico (evita di scambiare una versione numerica per un Id), la
  sorgente `winget`/`msstore` viene rimossa e le versioni vengono isolate
  dal token finale, anche quando le colonne sono separate da un solo spazio
  (nomi lunghi).
- **Backend (`NovaChimera_Core.ps1`)**:
  - `ConvertTo-WingetUpgradeItem` e `ConvertTo-WingetUpgradeList`: parsing
    della tabella;
  - `Get-WingetUpgradeListCommand`, `Get-WingetUpgradeAllCommand` e
    `Get-WingetUpgradeIdCommand`: costruttori dei comandi winget, usabili
    anche in background;
  - `Get-WingetUpgradeList`, `Update-WingetAllPackages` e
    `Update-WingetSelectedIds`: esecuzione sincrona per l'uso headless;
  - `Set-LocalUserPassword`: cambio password via API ADSI
    (`WinNT://./<utente>,user`), senza esporre la password sulla riga di
    comando.
- **Finestra di riepilogo scorrevole** (`Show-ScrollableResultDialog`): usata
  dal risultato degli aggiornamenti, con tema Obsidian Purple e pulsante di
  chiusura.
- **SelfTest a 16 controlli** (invariato) e **SmokeTest a 10 controlli**: la
  scheda di manutenzione viene verificata con i suoi 7 pulsanti.

### Correzioni

- **Colonne della tabella winget**: la separazione per due o piu' spazi
  falliva sulle righe con nomi lunghi (le versioni restavano attaccate al
  nome del pacchetto). Ora i campi vengono isolati dall'ultimo token.
- **`Set-LocalUserPassword` con parametri vuoti**: il binding falliva prima
  del controllo; i parametri accettano ora stringhe vuote e la funzione
  restituisce `False`.

### Verifiche eseguite

| Ambito | Esito |
| --- | --- |
| Parsing sintattico (PS 5.1 / PS 7) | 0 errori su Core e GUI |
| SelfTest PS 5.1 e PS 7 | 16 controlli, 0 falliti |
| SmokeTest PS 5.1 e PS 7 | 10 controlli, 0 falliti, 7 pulsanti di manutenzione |
| Parsing della tabella winget reale | 15 pacchetti estratti con Id, versione corrente e versione disponibile corretti |
|Casi limite del parsing | Nome lungo con versione (`Microsoft Visual C++ ... 14.51.36231`), versione con prefisso (`ad 9.7.16`), Id numerico (`7zip.7zip`): tutti estratti correttamente |
| Carica aggiornamenti (in background) | `winget upgrade` exit 0, 15 elementi in elenco con spunta attiva |
| Seleziona / deseleziona tutti | 15 spuntati -> 0 -> 15 |
| Applica selezionati (comandi simulati) | 3 pacchetti in coda, risultato aggregato unico; selezione parziale eseguita solo sul pacchetto scelto; nessuna selezione -> avviso e nessun comando |
| Scarica e installa tutto (comando simulato) | Conferma richiesta, esecuzione in background, finestra di riepilogo |
| Log di sessione | 0 errori e 0 warning |

### Limitazioni note

- Il pulsante **Scarica e installa tutto** applica realmente gli aggiornamenti
  a tutti i pacchetti: richiede conferma esplicita e puo' richiedere un
  riavvio del PC.
- L'aggiornamento selettivo esegue un processo winget per pacchetto: con
  molti pacchetti selezionati l'operazione e' sequenziale e puo' durare
  diversi minuti.
- Il cambio password richiede la sessione elevata e vale solo per gli utenti
  locali del PC.
- Il parsing della tabella winget depende dalla struttura dell'output: se
  winget cambia il formato della tabella, il riconoscimento dell'Id puo'
  richiedere un aggiornamento della regex.

## 2.2.1 - 2026-10-21

Tema: **sezione DNS dedicata nella scheda Network & Rete**.

### Novita'

- **Riquadro "🌐 Servizi e gestione DNS"** nella scheda *Network & Rete*:
  i comandi DNS sono raccolti in un `GroupBox` dedicato, separati dai
  comandi generali di rete.
  - `🔎 Cache DNS (/displaydns)`: lettura della cache del resolver;
  - `🧹 Pulisci cache DNS (/flushdns)`: svuotamento della cache;
  - `🌐 Test risoluzione (nslookup)`: risolve il dominio indicato nel campo
    **Dominio** (default `google.com`) e mostra la risposta completa del
    resolver, server di interrogazione incluso.
- **Campo di testo "Dominio"**: il test di risoluzione accetta un nome
  qualsiasi, non un valore fisso.
- **Barra dei comandi generali** arricchita:
  - `🦈 Wireshark`: avvia Wireshark se installato (rilevamento in
    `Program Files`, `Program Files (x86)`, `LOCALAPPDATA` e `PATH`);
  - `🌐 Nmap Scan (localhost)`: scansione di `127.0.0.1` con nmap;
  - `🧹 Clear Output`: svuota il terminale di output.
- **Backend (`NovaChimera_Core.ps1`)**:
  - `Test-DnsHostResolution`: diagnostica di risoluzione con catena di
    fallback (resolver .NET con timeout 2000 ms -> `Resolve-DnsName` ->
    `nslookup`), usata dal SelfTest e dai controlli headless;
  - `Get-DnsLookupCommand`: costruisce il comando esterno da eseguire in
    background per il test interattivo;
  - `Get-ExternalToolPath`: rilevamento di un tool esterno nel PATH e nelle
    cartelle di installazione standard;
  - `Start-WiresharkTool` e `Get-NmapScanCommand`: avvio di Wireshark e
    costruzione del comando nmap (solo localhost, per non esporre la
    postazione).
- **SelfTest a 16 controlli**: nuovi controlli *Risoluzione DNS* e
  *Servizio nslookup*.

### Correzioni

- **Output dei comandi localizzati**: la decodifica dei byte raccolti in
  background era esclusivamente UTF-8 e sostituiva con `�` i caratteri non
  UTF-8 (per esempio la messaggio italiano di `nslookup`). Ora la catena e'
  UTF-8 strict -> codepage OEM della lingua -> ANSI, con fallback ASCII.

### Verifiche eseguite

| Ambito | Esito |
| --- | --- |
| Parsing sintattico (PS 5.1 / PS 7) | 0 errori su Core e GUI |
| SelfTest PS 5.1 e PS 7 | 16 controlli, 0 falliti |
| SmokeTest PS 5.1 e PS 7 | 9 controlli, 0 falliti |
| Layout scheda Network | Barra generale in alto (Top=8), riquadro DNS (Top=56, altezza 104), output a riempimento (Top=160) |
| Test risoluzione DNS | `nslookup` in background, exit 0, output completo con accenti corretti |
| Cache DNS e flush | `ipconfig /displaydns` e `/flushdns` in background, exit 0 |
| Clear Output | Terminale svuotato correttamente |
| Wireshark / nmap assenti | Messaggio esplicito, nessun errore nel log |
| Log di sessione | 0 errori e 0 warning |

### Limitazioni note

- `nslookup` interroga il resolver configurato: un nome presente solo nel
  file `hosts` viene riportato come "non risolvibile" dal resolver DNS.
- Wireshark e nmap sono opzionali: senza installazione i pulsanti informano
  l'utente e non eseguono nulla.
- La scansione nmap e' limitata a `127.0.0.1` per non esporre la postazione
  a scansioni esterne non autorizzate.

## 2.1.0 - 2026-10-21

Tema: **Enterprise Suite (Thin Client Architecture & Backend Separation)**.

Il monolitico 2.0.0 viene separato in due componenti indipendenti: il backend
`NovaChimera_Core.ps1` e il thin client `NovaChimera_GUI.ps1`. Il launcher
avvia il thin client, che carica il backend all'avvio.

### Novita'

- **`NovaChimera_Core.ps1` (backend)**: logica di sistema, query WMI/CIM,
  risoluzione delle porte di stampa tramite registro
  (`HKLM:\SYSTEM\CurrentControlSet\Control\Print\Monitors\Standard TCP\IP
  Port\Ports\<porta>`), subnet mask e CIDR, diagnostica di rete (DNS / WSD /
  TCP), controlli di sicurezza, gestione dei lavori in coda, controllo del
  servizio Spooler, pulizia dei file temporanei e aggiornamenti `winget`.
  Il backend non contiene alcuna form e non referenzia WinForms, se non per
  il controllo di compatibilita' del SelfTest.
- **`NovaChimera_GUI.ps1` (thin client)**: costruisce l'interfaccia a schede
  (`TabControl`) con il tema scuro **Obsidian Purple** (`#0f0f13`, `#181820`,
  accenti viola lavanda `#b388ff`), gestisce gli eventi, il logging unificato
  e il dispatch della sessione (`-SelfTest`, `-Diagnose`, `-ResolvePort`,
  `-SmokeTest`).
- **Contratto Core -> Client**: tre canali, tutti protetti da controlli null -
  `$script:Ui.LogBox` (eco del registro), `$script:LogEntries` (registro della
  sessione) e `$script:PendingCommands` (coda dei processi in background).
- **Dati semantici al posto dei colori**: il backend non conosce piu' il tema.
  `Get-PrinterStatusInfo` e `New-PrinterRecord` restituiscono una chiave di
  stato (`muted`, `error`, `success`, `accent`, `warning`) e il thin client la
  traduce nel colore tramite `Get-ThemeColor`.
- **Coda dei comandi in background**: `$script:PendingCommands` e' una lista.
  Il timer del thin client (400 ms) consuma la coda e invoca i callback dei
  comandi terminati; piu' comandi (`ipconfig`, `winget upgrade`) possono
  essere in esecuzione contemporanea senza perdere i rispettivi callback.
- **`launch.ps1` aggiornato**: avvia `NovaChimera_GUI.ps1` con
  auto-elevazione Administrator (UAC) e ripiega su `pwsh.exe` quando
  disponibile.
- **Monolitico 2.0.0 conservato** in `archive/stampanti-v2.0.0.ps1` come
  riferimento e piano di rollback.

### Correzioni

- **Callback dei comandi in background persi**: la coda dei processi era un
  singolo slot (`$script:Ui.PendingCommand`). Lanciando un secondo comando
  mentre il primo era ancora in esecuzione, il callback del primo veniva
  sovrascritto e il relativo output non compariva nella console. Ora la coda
  e' una lista e ogni comando conserva il proprio callback.
- **Timer dei comandi sempre attivo**: l'avvio del timer era dentro il
  backend, che non puo' piu' conoscere i controlli del client. Il timer e'
  ora avviato dal thin client e resta attivo, con un controllo leggero sul
  ogni tick.
- **Rilancio in STA e auto-elevazione**: puntano al file del thin client
  (`NovaChimera_GUI.ps1`) invece del vecchio monolitico.
- **Inizializzazione del log**: `Initialize-Application` accetta il percorso
  come parametro esplicito, invece di relying sulla variabile `$LogDirectory`
  presente nello scope del chiamante.

### Verifiche eseguite

| Ambito | Esito |
| --- | --- |
| Parsing sintattico (PS 5.1 / PS 7) | 0 errori su Core e GUI |
| SelfTest PS 5.1 e PS 7 | 14 controlli, 0 falliti |
| SmokeTest PS 5.1 e PS 7 | 9 controlli, 0 falliti, 2 stampanti, 20 campi dettaglio |
| Diagnose e ResolvePort | Report completi, nessun errore |
| Audit di disaccoppiamento | Core: 0 riferimenti a WinForms e al tema; GUI: 0 query di sistema |
| Copertura funzioni | 89 funzioni del monolitico, tutte presenti (57 Core + 32 GUI) |
| Layout GUI | 4 schede, 11 pulsanti, 8 colonne, 0 errori e 0 warning nel log |
| Comandi in background (PS 5.1 / PS 7) | `ipconfig /all` exit 0 (2654 caratteri), `winget upgrade` exit 0 (2328 caratteri), nessun callback perso |
| Gestori pulsanti (Home, pulizia, winget, rete) | Verificati con click reale in STA |
| Avvio elevato via `launch.ps1 -SelfTest` | UAC + SelfTest eseguiti, log corretti |

### Limitazioni note

- Il backend e' caricato con il dot-sourcing: le funzioni del Core e del
  thin client condividono lo scope di script (comportamento atteso e
  verificato in PowerShell 5.1 e 7).
- Il thin client resta l'unico punto d'ingresso: il backend non puo' essere
  eseguito come script autonomo perche' non contiene il dispatch.
- La coda dei comandi in background e' limitata a 8 elementi consumati per
  tick: con piu' processi contemporanei il completamento avviene in alcuni
  tick successivi, senza perdita di output.

## 2.0.0 - 2026-10-21

Tema: **IT Enterprise Suite** - nuova GUI a 4 schede con dashboard di sicurezza,
strumenti di rete e manutenzione del PC.

### Novita'

- **Interfaccia a 4 schede principali**:
  - `🛡️ Home / Dashboard` - stato di sicurezza e riepilogo della postazione;
  - `🖨️ Gestione Stampanti` - l'inventario della 1.4.0 con le 5 schede interne
    (Card, Dettagli, Rete, Lavori, Registro) e la barra comandi a 11 pulsanti;
  - `📡 Network & Rete` - comandi `ipconfig` eseguiti in background;
  - `🛠️ Manutenzione PC` - pulizia dei file temporanei e aggiornamenti di
    sistema con `winget`.
- **Dashboard di sicurezza** (`Get-SecurityStatus`): antivirus registrato in
  `Root\SecurityCenter2`, firewall con i profili attivi (Domain, Private,
  Public), VPN (connessioni `Get-VpnConnection` e processi client), UAC
  (`EnableLUA`) e riavvio pendente (Component Based Servicing / WindowsUpdate).
- **Riepilogo postazione** (`Get-HomeDashboardReport`): produttore, modello,
  numero di serie, nome computer, utente, RAM, sistema con build, ultimo
  avvio, processore con core e logici, spazio libero su C:, indirizzi IPv4 con
  prefisso e maschera, gateway, DNS e stato del servizio Spooler.
- **Esecuzione in background** (`Start-BackgroundCommand` /
  `Complete-BackgroundCommand`): il processo viene avviato senza bloccare la
  interfaccia, stdout e stderr sono raccolti in memoria e il callback
  `OnComplete` viene invocato dal timer della GUI al termine, con codice di
  uscita e output completo. Alla base c'e' il comando `ipconfig`.
- **Scheda Network & Rete**: `ipconfig /all`, `/displaydns`, `/flushdns` e
  `/renew`, ognuno con l'output completo e il relativo exit code.
- **Scheda Manutenzione PC**:
  - pulizia di `%TEMP%` e `%SystemRoot%\Temp` con riepilogo di elementi
    rimossi, elementi in uso saltati e spazio liberato (conferma richiesta);
  - controllo aggiornamenti con `winget upgrade` in background e report degli
    aggiornamenti disponibili.
- **Stato di avanzamento** nella barra inferiore (`Set-BusyState`) durante le
  operazioni lunghe, con messaggio contestuale.
- **SelfTest esteso**: nuovi controlli su stato di sicurezza, dashboard di
  sistema e disponibilita' di `winget` (14 controlli, 0 falliti).

### Correzioni

- **Gestori degli eventi**: le variabili locali della funzione che costruisce
  la form non sono visibili dentro i gestori (scope del richiamo). I pulsanti
  `🛡️ Aggiorna Dashboard`, `🧹 Pulisci file temporanei` e
  `📦 Aggiornamenti (Winget)` terminavano con "Impossibile trovare la
  proprieta' 'Text' in questo oggetto". Ora i riferimenti passano per
  `$script:Ui.HomeBox` e `$script:Ui.MaintBox`.
- **Callback dei comandi in background**: lo scriptblock di completamento
  veniva creato in uno scope non piu' attivo al momento dell'invocazione; ora
  usa solo `$script:Ui` e i parametri del callback.
- **Decodifica dell'output**: l'output di un processo esterno viene letto come
  UTF-8 o UTF-16 in base alla presenza di byte null, per non troncare i
  caratteri speciali dei comandi localizzati.

### Verifiche eseguite

| Ambito | Esito |
| --- | --- |
| Parsing sintattico (PS 5.1 / PS 7) | OK |
| SelfTest PS 5.1 (deploy `C:\StampantiTool`) | 14 controlli, 0 falliti |
| Diagnose PS 5.1 (deploy `C:\StampantiTool`) | Report completo senza errori |
| Layout GUI | 4 schede, 11 pulsanti, 8 colonne, 0 errori e 0 warning nel log |
| Scheda Home | Dashboard di 34 righe con stato sicurezza e postazione |
| Scheda Network | `ipconfig /all` in background, exit code 0, 2654 caratteri |
| Scheda Manutenzione | `winget upgrade` in background, exit code 0, 2328 caratteri |
| Gestori pulsanti (Home, pulizia, winget) | Verificati con click reale in STA |
| Avvio elevato via `launch.ps1 -SelfTest` | UAC + SelfTest eseguiti, log corretti |

### Limitazioni note

- Il pulsante `📦 Aggiornamenti (Winget)` esegue `winget upgrade` in
  background: l'applicazione degli aggiornamenti dipende da `winget` e dalle
  policy di gestione pacchetti della postazione.
- La pulizia dei file temporanei raggiunge le cartelle di sistema solo in
  sessione elevata: senza privilegi gli elementi in uso restano "saltati".
- Lo stato VPN e' basato su connessioni e processi note: i client non
  standard possono non essere rilevati.
- La scheda Network & Rete usa `ipconfig`: i comandi che richiedono il
  riavvio dell'IP (`/renew`) non sono sempre disponibili in ambienti
  corporate.

## 1.4.0 - 2026-10-21

Tema: **subnet mask e modifica dell'indirizzo IP** sulle stampanti di rete.

### Novita'

- **Colonna "Subnet Mask"** nell'elenco stampanti, con larghezze adattive
  automatiche al ridimensionamento della finestra (le 8 colonne restano
  visibili senza scorrimento orizzontale).
- **Rilevamento della subnet mask** con catena di fallback:
  cache porte (`Get-PrinterPort`) -> registro
  (`Control\Print\Monitors\Standard TCP\IP Port\Ports\<porta>` e
  `Control\Print\Ports\<porta>`) -> sottorete locale della scheda di rete del
  PC -> `N/D`.
- **Sottorete in notazione CIDR** (es. `192.168.1.0/24`) nelle righe Card e
  Dettagli, con indicazione della sorgente del dato.
- **Pulsante `✏️ Modifica IP`** nella barra comandi e voce di menu
  *Azioni > Modifica indirizzo IP*, con dialogo che mostra stampante, porta
  attuale, tipo di porta, subnet mask e il campo per il nuovo indirizzo.
- **Validazione IPv4** del nuovo indirizzo prima di applicare (formato
  `a.b.c.d`, ottetti 0-255).
- **Applicazione della modifica**:
  - porte TCP/IP RAW (`IP_...`): aggiornamento in-place del valore `HostName`
    della porta nel registro, con riavvio dello Spooler;
  - porte TCP/IP Standard: creazione della nuova porta con l'IP richiesto e il
    numero di porta TCP originale, riorientamento della stampante e rimozione
    della vecchia porta se non piu' usata da altre code;
  - porte WSD: migrazione su una porta TCP/IP Standard (non modificabili
    in-place);
  - porte locali, USB, virtuali e condivise: operazione rifiutata con
    messaggio esplicito.
- **Nuovi controlli nel SelfTest**: subnet mask della stampante di prova,
  conversione prefisso/mask, calcolo CIDR e validazione IPv4 (11 controlli
  totali, 0 falliti in PowerShell 5.1 e 7).

### Correzioni

- Conversione prefisso/mask riscritta su base byte: in Windows PowerShell 5.1
  il letterale `0xFFFFFFFF` viene interpretato come `Int32 -1`, e la
  conversione a `UInt32` falliva per tutte le maschere (`/8` -> `/32`).
- Calcolo del prefisso CIDR: il prefisso veniva contato sui bit dell'indirizzo
  di rete invece che sulla maschera, producendo valori errati
  (es. `169.254.0.0/11` invece di `169.254.0.0/16`).
- Cache delle interfacce IPv4 locali: l'operatore `@()` su una
  `List[object]` genera `ArgumentException` ("Tipi di argomento non
  corrispondenti") sia in PowerShell 5.1 sia in 7. Sostituito con
  `ToArray()`.
- Validazione IPv4 e risoluzione subnet: i parametri obbligatori non accettano
  stringhe vuote e terminavano il flusso con un errore di binding invece di
  restituire `N/D`.
- Modifica IP su porta RAW: il cmdlet `Set-PrinterPort` non esiste nel modulo
  `PrintManagement`; la scrittura passa ora dal registro (sorgente reale del
  dato) con fallback CIM e WMI, e ogni scrittura viene riletta e verificata
  prima di dichiarare l'operazione riuscita.
- Risoluzione dell'host della porta: il percorso di registro letto era
  `Control\Print\Ports\<porta>` (non popolato per le porte TCP/IP) e il valore
  `Port` (numero di porta) veniva interpretato come hostname. Ora viene letta
  prima la chiave corretta
  `Control\Print\Monitors\Standard TCP\IP Port\Ports\<porta>` (valore
  `HostName`).
- Dialogo "Modifica IP": il pannello dei pulsanti e le righe dei campi
  condividevano la stessa cella della griglia (sovrapposizione visibile) e il
  controllo veniva inserito due volte nella stessa tabella.
- Larghezze delle colonne dell'elenco adattive: con 8 colonne la somma
  superava la larghezza utile e l'ultima colonna risultava tagliata.
- Rilevamento della stampante predefinita: `WScript.Network` restituisce una
  stringa vuota nelle sessioni non interattive, e nessuna stampante veniva
  marcata come predefinita. Ora, in assenza del dato, si ricade su
  `Win32_Printer.Default`.

### Verifiche eseguite

| Ambito | Esito |
| --- | --- |
| Parsing sintattico (PS 5.1 / PS 7) | OK |
| SelfTest PS 5.1 e PS 7 | 11 controlli, 0 falliti |
| SmokeTest PS 5.1 e PS 7 | 6 controlli, 2 stampanti, 20 campi dettaglio |
| Conversioni prefisso/mask e CIDR | 9 prefissi e 7 coppie IP/mask verificati |
| Modifica IP su porta RAW (elevato) | Aggiornamento in-place confermato da `Get-PrinterPort` e dal registro |
| Modifica IP su porta TCP/IP Standard (elevato) | Nuova porta creata, stampante riorientata, porta vecchia rimossa |
| Casi di rifiuto (IP non valido, porta locale, porta condivisa, porta inesistente) | Rifiutati con messaggio esplicito |
| Layout GUI | 11 pulsanti senza sovrapposizioni, 8 colonne entro la larghezza, 0 errori e 0 warning nel log |

### Limitazioni note

- La scrittura nel registro delle porte e il riavvio dello Spooler richiedono
  la sessione elevata: senza privilegi la modifica non viene eseguita e
  l'errore e' mostrato senza alterare la configurazione.
- La subnet mask di una stampante remota che non appartiene a nessuna
  sottorete locale resta `N/D` se il valore non e' presente in cache porte o
  registro.
- Le porte WSD non sono modificabili in-place: l'IP del dispositivo va letto
  dal pannello e la porta va ricreata come TCP/IP Standard.

## 1.2.0 - 2026-10-21

Tema Obsidian Purple, badge di stato, colonna IP, Card diagnostica live,
pulsanti Cerca Driver / WebAdmin / Elimina / Termina, export CSV, gestione
dello stato offline.
