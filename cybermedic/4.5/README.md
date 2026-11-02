# CyberMedic v3.0.1 - Enterprise IT Helpdesk Suite (tema Obsidian Purple)

Suite per il supporto tecnico di postazione: **dashboard di sicurezza**,
**inventario delle stampanti** (locali, condivise, di rete e **offline**),
diagnostica di rete (DNS / WSD / TCP), **subnet mask e modifica dell'indirizzo
IP**, gestione dei lavori in coda, controllo del servizio Spooler, **strumenti
di rete** (`ipconfig`), **manutenzione del PC** (pulizia file temporanei e
aggiornamenti `winget`), pagina di prova, ricerca driver, WebAdmin,
eliminazione stampante, export report e chiusura volatile dell'applicazione.

La **v3.0.0** rinomina il prodotto in **CyberMedic** (tutti i file, i moduli e
le interfacce) e aggiunge:

- **riquadro Office e licenze** nella Home: inserimento della Product Key
  (`OSPP.VBS` con guardia sulla chiave vuota), lettura dello stato delle
  licenze e piano di rimozione basato sui **disinstallatori ufficiali**
  Microsoft;
- **informazioni Wi-Fi avanzate**: inventario dell'interfaccia wireless
  (SSID, BSSID, stato, autenticazione, crittografia, canale, segnale, velocita')
  e dei profili salvati, senza estrarre il materiale chiave;
- **box separati** per le risorse del Task Manager (CPU, RAM, disco, GPU) e per
  **Aggiornamenti applicazioni** / **Driver di sistema** nella scheda Updates;
- nuova coppia di moduli core `office.ps1` e `wifi.ps1` (SelfTest a 38
  controlli, SmokeTest a 28).

La **v2.5.0** centralizza l'identita' del prodotto nel file **`product.psd1`**
(nome, versione, edizione, build, slogan, colore dello splash): non esistono
piu' stringhe hardcoded nel codice, quindi rinominare o versionare il prodotto
richiede la modifica di **un solo file**. La schermata di avvio diventa la
**schermata blu** richiesta, con checklist dei passi di avvio, e la dashboard
si apre solo al 100% dell'inizializzazione.

La v2.0.0 riorganizza l'interfaccia in **4 schede principali**
(`🛡️ Home / Dashboard`, `🖨️ Gestione Stampanti`, `📡 Network & Rete`,
`🛠️ Manutenzione PC`) mantenendo invariate le funzionalita' del core 1.4.0.

La v2.1.0 separa il prodotto in **architettura Thin Client**: il backend
(`CyberMedic_Core.ps1`) raccolta logica di sistema, WMI/CIM, registro, rete e
sicurezza; il front-end (`CyberMedic_GUI.ps1`) costruisce l'interfaccia e
pilota i comandi. Il thin client carica il core all'avvio e resta l'unico
punto d'ingresso dell'applicazione.

La **v2.4.0** estende l'interfaccia a **6 schede principali** e aggiunge al
backend i moduli richiesti dal supporto:

- **splash di avvio** con versione e stato del caricamento;
- **⚡ Gestione Attivita'**: metriche live di CPU, RAM e disco con grafici,
  registro di sessione live e coda delle operazioni;
- **📧 Posta & Outlook**: rilevamento di SCANPST e degli archivi PST/OST del
  profilo, con avvio della scansione sull'archivio selezionato;
- **🌐 Nmap**: riquadro con 5 preset e argomenti personalizzati;
- **coda sequenziale** applicazioni + driver nella scheda Manutenzione PC,
  con console live e riepilogo dei driver di sistema.

Progettata per **non terminare mai in modo anomalo**: ogni query di sistema,
ogni accesso al registro e ogni operazione di rete e' protetta da `try/catch`
con fallback multipli e valori di default sicuri.

## Requisiti

| Componente | Requisito |
| --- | --- |
| Sistema operativo | Windows 10 / 11 / Windows Server 2016+ |
| PowerShell | 5.1 (Windows PowerShell) o 7.x (PowerShell Core) |
| Privilegi | Amministratore, per svuotamento spooler e riavvio servizio |
| Dipendenze | Nessuna: nessun modulo esterno, nessuna installazione |

> **Attenzione in caso di modifica dei file**: salvare gli script in
> **UTF-8 con BOM**. Windows PowerShell 5.1 interpreta i file senza BOM
> come ANSI e le emoji della barra dei comandanti diventano illeggibili,
> causando un errore di parsing all'avvio.

## Struttura del repository

```text
CyberMedic/
├── product.psd1            # Identita' del prodotto (nome, versione, build): unica fonte
├── CyberMedic_Core.ps1    # Backend: logica di sistema, WMI/CIM, registro, rete
├── CyberMedic_GUI.ps1     # Thin client: interfaccia a schede e dispatch sessione
├── launch.ps1             # Launcher con auto-elevazione Administrator
├── core/                  # Moduli del backend, caricati per dot-sourcing
│   ├── metrics.ps1        # Metriche CPU/RAM/disco, temperatura, stato SMART
│   ├── updates.ps1        # Winget, driver di sistema, coda dei pacchetti
│   ├── maintenance.ps1    # Pulizia temporanei, password utente, console sicura
│   ├── outlook.ps1        # SCANPST, archivi PST/OST, cache di Outlook
│   ├── office.ps1         # Info Office, licenze (OSPP.VBS), rimozione ufficiale
│   ├── wifi.ps1           # Inventario interfacce e profili Wi-Fi
│   └── cybermedic.ps1     # Riparazione rete, file hosts, Microsoft Defender
├── gui/                   # Moduli del front-end
│   ├── theme.ps1          # Design system Fluent (angoli arrotondati, toggle, card)
│   ├── splash.ps1         # Splash di avvio
│   └── tabs/              # Una scheda per file
│       ├── taskmanager.ps1
│       ├── updates.ps1
│       ├── maintenance.ps1
│       ├── mail.ps1
│       └── cybersecurity.ps1
├── winui3/                # Scaffold WinUI 3 (richiede Visual Studio + .NET 8 + Windows App SDK)
├── installer/             # Installer PowerShell (portable / installata)
├── docs/                  # Documentazione di continuita' (session_state, architettura, test, deploy, decisioni, installer)
├── README.md              # Documentazione tecnica per il team
├── RELEASE_NOTES.md       # Note di rilascio per versione
├── .gitignore             # Esclude log e report generati
├── archive/               # Versione monolitica 2.0.0 (solo riferimento)
└── logs/                  # Creata automaticamente al primo avvio
```

### Architettura modulare (v2.4.0)

Il progetto e' separato in due componenti indipendenti, a loro volta composti
da moduli caricati con il dot-sourcing:

| Componente | Ruolo | Contenuto |
| --- | --- | --- |
| `CyberMedic_Core.ps1` | Backend | Logica di sistema, query WMI/CIM, risoluzione delle porte tramite registro (`HKLM:\SYSTEM\CurrentControlSet\Control\Print\Monitors\...`), subnet mask e CIDR, diagnostica di rete, controlli di sicurezza, spooler, `winget` |
| `core\*.ps1` | Moduli del backend | Metriche, aggiornamenti, manutenzione, Outlook, Office, Wi-Fi, CyberMedic: ogni file aggiunge funzioni allo stesso scope del core e non richiede alcuna installazione |
| `CyberMedic_GUI.ps1` | Thin client | Costruzione dei controlli, gestione degli eventi, tema Obsidian Purple, dispatch della sessione |
| `gui\*.ps1` | Moduli del front-end | Splash di avvio e le schede modulari: ogni scheda espone `New-XxxTab -MainTabs` e registra i controlli in `$script:Ui` |
| `launch.ps1` | Launcher | Auto-elevazione Administrator (UAC) e avvio del thin client |

Il thin client carica il backend all'avvio con il dot-sourcing:

```powershell
. (Join-Path -Path $PSScriptRoot -ChildPath 'CyberMedic_Core.ps1')
```

e subito dopo i moduli del front-end, ognuno protetto da `try/catch` e da un
controllo di esistenza: la mancanza di un modulo non impedisce l'avvio della
GUI, ma viene registrata nel log di sessione.

```powershell
$script:GuiModules = @(
    'gui\splash.ps1'
    'gui\tabs\taskmanager.ps1'
    'gui\tabs\updates.ps1'
    'gui\tabs\maintenance.ps1'
    'gui\tabs\mail.ps1'
    'gui\tabs\cybermedic.ps1'
)
```

**Contratto Core -> Client**: il backend non conosce WinForms. Comunica con
l'interfaccia attraverso tre punti, tutti protetti da controlli null:

| Canale | Uso |
| --- | --- |
| `$script:Ui.LogBox` | Eco del registro nella casella di log |
| `$script:LogEntries` | Registro della sessione |
| `$script:PendingCommands` | Coda dei processi esterni in background |

Il backend restituisce dati semantici (testo, badge, chiave di stato
`muted/error/success/accent/warning`) e il thin client li traduce nei colori
del tema: le scelte cromatiche restano nel front-end.

La coda `PendingCommands` e' una lista: piu' comandi in background (per
esempio `ipconfig` e `winget upgrade`) possono essere in esecuzione
contemporanea senza che i callback si sovrascrivano a vicenda.

## Installazione sulle postazioni dei colleghi

```powershell
git clone <url-del-repository> C:\CyberMedic
```

In alternativa, copiare l'intera cartella (i tre script `CyberMedic_Core.ps1`,
`CyberMedic_GUI.ps1`, `launch.ps1`, il file `product.psd1`, i documenti
`README.md` e `RELEASE_NOTES.md`, il `.gitignore` e le due cartelle `core\` e
`gui\`) in `C:\CyberMedic`: le cartelle dei moduli sono necessarie, perch' il
thin client carica le schede e il backend carica le funzioni di dominio.

Il percorso puo' essere diverso: lo script usa sempre `$PSScriptRoot`, quindi
la posizione della cartella non influisce sul funzionamento.

## Identita' del prodotto (`product.psd1`)

Nome, versione, edizione, build e slogan del prodotto sono definiti in un
unico file, `product.psd1`, accanto a `launch.ps1`:

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

| Priorita' | Origine | Esempio |
| --- | --- | --- |
| 1 | Argomenti `-ProductName` / `-ProductVersion` | `.\launch.ps1 -ProductName "CyberMedic" -ProductVersion "3.1.0"` |
| 2 | Variabili d'ambiente `APP_PRODUCT_NAME` / `APP_PRODUCT_VERSION` | solo per la sessione corrente |
| 3 | `product.psd1` | valore permanente, valido per tutti i PC |
| 4 | Fallback interni del Core | usati solo se `product.psd1` manca |

I valori del file si applicano **automaticamente** a: splash di avvio, titolo
della finestra, intestazione dell'interfaccia, caption delle finestre di
dialogo, banner del log e controllo di identita' del SelfTest. Per cambiare
identita' non serve toccare `CyberMedic_Core.ps1`, `CyberMedic_GUI.ps1` o
`gui\splash.ps1`.

## Avvio

```powershell
cd C:\CyberMedic
.\launch.ps1
```

`launch.ps1` verifica i privilegi e, se la sessione non e' elevata, si rilancia
da solo con `-Verb RunAs` (prompt UAC) passando i privilegi di Amministratore al
thin client. La chiusura della finestra UAC annulla l'operazione senza errori.

Per lanciare direttamente il thin client in una sessione gia' elevata:

```powershell
pwsh -ExecutionPolicy Bypass -STA -File C:\CyberMedic\CyberMedic_GUI.ps1
```

## Interfaccia (tema Obsidian Purple)

L'applicazione e' organizzata in 8 schede principali. Le due schede interne
(Elenco stampanti e la barra comandi) appartengono alla scheda **Gestione
Stampanti**, che conserva il layout della 1.4.0. All'avvio viene mostrata la
**schermata blu** con il nome del prodotto, l'edizione, la versione, la build
e una **checklist dei passi di avvio**; la barra di avanzamento e'
**determinata** e la dashboard viene aperta solo quando l'inizializzazione e'
completata al 100%. Lo splash non ha pulsanti e non puo' essere saltato.

| Scheda | Contenuto |
| --- | --- |
| 🛡️ Home / Dashboard | Stato di sicurezza (antivirus, firewall, VPN, UAC, riavvio pendente) e riepilogo della postazione, con pulsante di aggiornamento |
| 🖨️ Gestione Stampanti | Inventario, barra comandi a 11 pulsanti e 5 schede interne: Card, Dettagli, Rete, Lavori, Registro |
| 📡 Network & Rete | Comandi `ipconfig` (`/all`, `/renew`), riquadro DNS (`/displaydns`, `/flushdns`, test `nslookup`), riquadro **Nmap** con preset e argomenti personalizzati, avvio Wireshark |
| ⚡ Task Manager | Metriche live di CPU / RAM / disco, tre **grafici attivabili a richiesta** (CPU, RAM, disco), riepilogo risorse, **diagnostica hardware** (thermal throttling e dischi SMART), registro live e coda operazioni |
| 📦 Updates | Elenco dei pacchetti aggiornabili (`winget`), elenco dei driver di sistema, coda sequenziale app + driver con console live, aggiornamento globale `winget upgrade --all` |
| 🧹 Maintenance | Pulizia dei file temporanei con piano e conferma per Prefetch, cambio password utente, scansioni **Nmap** con preset e argomenti personalizzati |
| 📧 Mail & PowerShell | Rilevamento SCANPST e archivi PST/OST, scansione dell'archivio selezionato, sincronizzazione degli archivi, ricostruzione della cache di Outlook, report degli archivi, console PowerShell in sola lettura |
| 🛡️ CyberMedic | Ripristino di rete (Winsock, TCP/IP, DNS, DHCP, ARP, adapter), analisi del file hosts, stato di Microsoft Defender e scansione rapida |

| Area | Contenuto |
| --- | --- |
| Header | Titolo in viola lavanda su fondo nero |
| Barra comandi | 11 pulsanti operativi con icona, hover e bordo antracite |
| Elenco stampanti | Badge di stato colorato, IP, subnet mask, predefinita, coda, porta, tipo porta |
| Scheda 📊 Card | Diagnostica live della stampante selezionata (monospace) |
| Scheda 🔍 Dettagli | 20 campi: porta, host, IP, subnet mask, CIDR, driver, stato, offline, ultimo errore |
| Scheda 📡 Rete | Test ping/TCP con timeout e profilo di rete |
| Scheda 🧾 Lavori | Lavori in coda per stampante |
| Scheda 📜 Registro | Log della sessione con copia/salvataggio |
| Barra inferiore | Stato, spooler, privilegi e pulsante rosso di chiusura |

**Badge di stato**: verde = pronta, viola = in stampa, giallo = in attesa /
in pausa, rosso = errore, bianco = offline o inattiva. Lo stato offline e'
rilevato sia da `WorkOffline` sia dai bit di `PrinterState`.

## Comandi operativi

| Pulsante | Funzione |
| --- | --- |
| 🔄 Aggiorna | Rilegge l'inventario, i lavori e lo stato spooler |
| ⭐ Predefinita | Imposta la stampante selezionata come predefinita (COM, fallback CIM) |
| 🧹 Pulisci Coda | Rimuove i lavori in coda della stampante selezionata |
| ⚙️ Svuota Spooler | Ferma lo spooler, cancella i file in coda, riavvia il servizio |
| 📡 Test di Rete | Ping + test TCP 9100/631 con timeout 1500 ms, profilo di rete |
| ✏️ Modifica IP | Cambia l'indirizzo IPv4 della stampante selezionata (vedi sotto) |
| 📄 Pagina di Prova | Invia la pagina di prova (CIM `PrintTestPage`, fallback printui) |
| 🔍 Cerca Driver | Apre il sito ufficiale del produttore, o una ricerca web generica |
| 🌐 WebAdmin | Apre `http://<IP>` del dispositivo, se l'IP e' risolvibile |
| 📊 Esporta Report | Esporta il CSV dell'inventario (Desktop o cartella log) |
| 🗑️ Elimina | Rimuove la stampante dal sistema (con doppia conferma) |
| 🛑 Termina Applicazione | Chiusura volatile: chiude il form e libera tutte le risorse |

## Parametri di `CyberMedic_GUI.ps1`

| Parametro | Descrizione |
| --- | --- |
| `-PrinterName` | Preseleziona la stampante da mostrare |
| `-LogDirectory` | Cartella dei log (default: `<cartella script>\logs`) |
| `-SelfTest` | Esegue il protocollo di verifica locale e termina |
| `-SmokeTest` | Costruisce la GUI senza mostrarla e verifica i controlli |
| `-Diagnose` | Stampa il report diagnostico su console e termina |
| `-ResolvePort` | Risolve una porta di stampa e ne stampa host, IP e porta TCP |
| `-NoElevation` | Non tenta l'auto-elevazione del processo |
| `-ProductName` | Sovrascrive il nome del prodotto per questa esecuzione |
| `-ProductVersion` | Sovrascrive la versione del prodotto per questa esecuzione |

## Funzionalita' operative

### Dashboard di sicurezza (Home)
La prima scheda raccoglie, in un unico report monospace, lo stato della
postazione:

- **Sicurezza**: antivirus registrato in `Root\SecurityCenter2`, firewall con
  l'elenco dei profili attivi, VPN (connessioni `Get-VpnConnection` e processi
  client noti), UAC (`EnableLUA`) e riavvio pendente (Component Based Servicing
  e WindowsUpdate);
- **Postazione**: produttore, modello, numero di serie, nome computer, utente,
  RAM, sistema con build, ultimo avvio, processore con core e logici, spazio
  libero su C:;
- **Rete locale**: indirizzi IPv4 con prefisso e maschera, gateway, DNS;
- **Servizio Spooler**: stato corrente.

Il pulsante `🛡️ Aggiorna Dashboard` ricalcola il report senza ricaricare
l'inventario delle stampanti.

#### Riquadro Office e licenze (v3.0.0)

Sul lato destro della Home si apre il riquadro **🔑 Office e licenze**:

| Controllo | Azione |
| --- | --- |
| Campo Product Key | Chiave nel formato `XXXXX-XXXXX-XXXXX-XXXXX-XXXXX` |
| 🔑 Installa e attiva chiave | Applica la chiave con `OSPP.VBS /inpkey` e attiva con `/act`, riportando l'output nella casella di esito |
| 📜 Stato licenze Office | Legge lo stato delle licenze con `OSPP.VBS /dstatus` |
| 🧹 Rimuovi Office | Mostra il piano di rimozione e, solo dopo conferma, avvia i **disinstallatori ufficiali Microsoft** (nessuna cancellazione manuale delle cartelle di Office) |

Se la chiave e' vuota o malformata l'operazione si ferma con un messaggio
esplicito: non viene mai eseguito alcun comando con un valore vuoto (e' il
caso che in precedenza produceva l'errore di binding sul parametro `Key`).

### Network & Rete

La scheda e' organizzata in tre livelli: una barra con i comandi generali,
un riquadro dedicato ai **servizi DNS** e il terminale di output.

**Barra comandi generali**

| Pulsante | Azione |
| --- | --- |
| 📋 Info complete | `ipconfig /all` in background |
| 🔄 Rinnova IP | `ipconfig /renew` in background |
| 🦈 Wireshark | Avvia Wireshark se installato, altrimenti avvisa |
| 📶 Info Wi-Fi avanzate | Inventario dell'interfaccia wireless e dei profili salvati (v3.0.0) |
| 🌐 Nmap Scan (localhost) | Scansione di `127.0.0.1` con nmap, se installato |
| 🧹 Clear Output | Svuota il terminale di output |

**Inventario Wi-Fi (v3.0.0)**

Il pulsante `📶 Info Wi-Fi avanzate` interroga `netsh wlan show interfaces` e
`netsh wlan show profiles` e produce un report con interfaccia, SSID, BSSID,
stato, tipo radio, autenticazione, crittografia, canale, segnale, velocita' di
ricezione e di trasmissione, seguito dall'elenco dei profili salvati. E' un
inventario di rete: il materiale chiave dei profili non viene estratto.

**Riquadro "🌐 Servizi e gestione DNS"**

| Pulsante | Azione |
| --- | --- |
| 🔎 Cache DNS | `ipconfig /displaydns` in background |
| 🧹 Pulisci cache DNS | `ipconfig /flushdns` in background |
| 🌐 Test risoluzione (nslookup) | Risolve il dominio indicato nel campo di testo |

Il campo **Dominio** accetta un nome qualsiasi (default `google.com`): il
test usa `nslookup` in background e mostra la risposta completa del resolver,
server di interrogazione incluso.

L'output completo del comando e il relativo exit code vengono mostrati nella
console della scheda. I processi esterni sono lanciati con
`Start-BackgroundCommand`: stdout e stderr sono raccolti in memoria e il
callback di completamento viene invocato dal timer della GUI, quindi
l'interfaccia non si blocca mai.

Wireshark e nmap sono **opzionali**: se non sono installati il pulsante
mostra un avviso con le istruzioni, senza errori. La scansione nmap rapida
resta limitata al localhost per non esporre la postazione.

**Riquadro "🌐 Nmap - scansione di rete"**

| Controllo | Azione |
| --- | --- |
| Preset | 5 profili pronti: porte rapide (`-F`), ping sweep (`-sn`), rilevamento sistema operativo (`-O`), scansione completa porte (`-p-`), scansione aggressiva (`-A`) |
| Argomenti personalizzati | Sovrascrive il preset; accetta la riga di comando nmap (es. `-sn 192.168.1.0/24`) |
| ▶ Esegui scansione Nmap | Avvia `nmap` in background e scrive l'output nella console della scheda |

Gli argomenti personalizzati vengono spezzati in token rispettando le
virgolette (`ConvertTo-CommandArgumentArray`), cosi' il comando nmap riceve
opzioni e target separati.

### Updates
La scheda e' un **centro di manutenzione software**: elenca i pacchetti con
aggiornamento disponibile, permette di selezionare i pacchetti da aggiornare e
consente l'aggiornamento massivo con un solo comando.

| Pulsante | Azione |
| --- | --- |
| 📦 Carica aggiornamenti | Interroga `winget upgrade` e popola l'elenco dei pacchetti aggiornabili (spuntati) |
| ☑️ Seleziona tutti | Spunta tutti i pacchetti dell'elenco |
| 🔲 Deseleziona tutti | Azzera la selezione |
| 🔄 Aggiorna driver | Rilegge i dispositivi PnP con errore e aggiorna l'elenco dei driver |
| 📥 Applica in sequenza (app + driver) | Accoda gli aggiornamenti dei pacchetti spuntati e la verifica dei driver spuntati, eseguendoli **uno alla volta** e scrivendo l'esito nella console live |
| 🚀 Scarica e installa tutto | `winget upgrade --all --accept-source-agreements --accept-package-agreements` con conferma preventiva e finestra di riepilogo |

La pulizia dei file temporanei, il cambio password e le scansioni Nmap sono
nella scheda **Maintenance**.

L'elenco e' una `CheckedListBox` con una riga per pacchetto:
`Nome  [Id]  versione -> versione disponibile`.

Sotto l'elenco dei pacchetti compare il riquadro **Driver di sistema**: la
riga `Analisi dei driver` riporta il riepilogo (dispositivi analizzati,
problemi rilevati) e le righe dell'elenco sono spuntate solo quando il
dispositivo presenta un errore di configurazione.

Dalla v3.0.0 i due elenchi sono **box separati**: `📦 Aggiornamenti
applicazioni (Winget)` occupa l'area principale e `🎮 Driver di sistema` il
riquadro in basso, ciascuno con la propria lista, la propria selezione e la
propria coda di esecuzione.

La **console live** in fondo alla scheda riceve, riga per riga, l'avanzamento
della coda: `[3/7] in coda: aggiornamento 7zip.7zip`, l'esito con exit code e
le prime righe dell'output del comando.

Il parsing della tabella di `winget` e' indipendente dalla lingua: l'Id del
pacchetto viene riconosciuto come token con un punto e almeno un segmento
alfanumerico, e le versioni vengono isolate dal token finale (la sorgente
`winget` o `msstore` viene rimossa).

Tutti i comandi winget girano **in background**: la coda dei processi
(`$script:PendingCommands`) esegue un pacchetto alla volta e il riepilogo
compare al termine in una finestra scorrevole. L'interfaccia resta sempre
rispondibile.

La coda delle operazioni della v2.4.0 e' sequenziale per costruzione:
`Add-QueuedTask` accoda il lavoro, `Start-NextQueuedTask` avvia la coda solo
quando non ci sono processi in corso e il callback di completamento avvia
l'attivita' successiva. Ogni task riceve il proprio oggetto come quarto
argomento del callback, cosi' il client non dipende da variabili di funzione.

### Maintenance
Scheda operativa per la pulizia del sistema, le credenziali e le scansioni di
rete.

| Pulsante | Azione |
| --- | --- |
| 📋 Analizza cartelle | Elenca `%TEMP%`, `%SystemRoot%\Temp` e `Prefetch` con dimensione, numero di file e percorso |
| 🧹 Esegui pulizia | Cancella i file temporanei e riporta elementi rimossi, elementi in uso saltati e spazio liberato |
| ⬜ Includi Prefetch | Facoltativa, con avviso: Microsoft sconsiglia la pulizia di Prefetch perche' rallenta il primo avvio delle applicazioni |
| 🔑 Cambio password utente | Imposta la password dell'utente locale (richiede sessione elevata) |
| ▶ Esegui scansione Nmap | Esegue il preset selezionato oppure gli argomenti personalizzati, in background |

Il cambio password usa l'API ADSI (`WinNT://./<utente>,user`): la password
non transita dalla riga di comando e non compare nella cronologia dei
processi.

Le scansioni Nmap girano in background (`Start-BackgroundCommand`): la GUI
resta responsiva e l'output viene scritto nella console di rete. Il preset
`Nmap` e' composto da token separati (non da un argomento unico), cosi'
`-sn 192.168.1.0/24` viene passato correttamente a `nmap.exe`.

### Task Manager
Scheda di monitoraggio della postazione, con due colonne.

| Controllo | Contenuto |
| --- | --- |
| Gauge CPU | Carico percentuale del processore, con soglia di allerta a 70% (giallo) e 85% (rosso) |
| Gauge RAM | Percentuale di memoria usata e spazio libero |
| Gauge Disco | Percentuale di occupazione del disco di sistema |
| 📈 Grafico CPU | Attiva o disattiva il grafico dell'andamento della CPU (ultimi 60 campioni) |
| 📈 Grafico RAM | Attiva o disattiva il grafico dell'andamento della memoria |
| 📈 Grafico Disco | Attiva o disattiva il grafico dell'andamento del disco di sistema |
| Riepilogo risorse | Core logici, RAM usata/libera, disco libero, GPU, adapter di rete, orario del rilevamento |
| 🖥️ CPU (processore) | Box separato: percentuale di utilizzo, core logici e stato (normale / critico) |
| 🧠 Memoria RAM | Box separato: totale, utilizzati e percentuale |
| 💾 Disco di sistema | Box separato: totale, liberi e percentuale di occupazione |
| 🎮 Scheda grafica | Box separato: controller in uso e stato della rete |
| 🔥 Diagnostica hardware | Thermal throttling della CPU, stato SMART dei dischi (temperatura, usura, ore accese, errori di lettura) |
| Registro live | Ultime 400 righe del log di sessione, aggiornate ogni 2 secondi |
| Coda operazioni | Stato delle attivita' accodate (in coda / in esecuzione / completato) |

I grafici sono **on demand**: all'avvio sono spenti e si attivano solo con i
pulsanti dedicati; il pulsante dell'area attiva diventa `📉` e nasconde
nuovamente il grafico. Dalla v3.0.0 le risorse sono presentate anche in **box
separati** (CPU, RAM, disco, GPU) con valori live indipendenti l'uno
dall'altro, aggiornati insieme al riepilogo. I pulsanti `⚡ Aggiorna
metriche`, `▶ Avvia monitoraggio`, `⏸ Ferma monitoraggio` e `🧹 Pulisci log
attivita` controllano il ciclo di aggiornamento; il monitoraggio si avvia automaticamente
all'apertura della finestra e si ferma alla chiusura.

Il riquadro **Diagnostica hardware** si aggiorna con il pulsante `🔄 Aggiorna
diagnostica`: il thermal throttling e' ricavato dalla zona termica ACPI
(`root/wmi`) confrontando la temperatura con la soglia critica, mentre lo
stato SMART arriva da `Get-PhysicalDisk` e `Get-StorageReliabilityCounter`, con
fallback su `Win32_DiskDrive`.

Le metriche sono raccolte in modo leggero: il carico della CPU usa il
`PerformanceCounter` (con ripiego su WMI se il contatore non e' disponibile),
l'adapter di rete arriva dalle API .NET e termica e SMART sono memorizzati in
cache per 60 secondi, cosi' il ciclo di aggiornamento resta sotto i 300 ms.

### Mail & PowerShell
Scheda dedicata alla manutenzione degli archivi di posta di Outlook e alla
console PowerShell in sola lettura.

| Controllo | Contenuto |
| --- | --- |
| Stato | Percorso di `SCANPST.EXE`, presenza di `OUTLOOK.EXE`, numero di archivi PST e OST |
| Elenco | Tipo, nome, dimensione, data di modifica e percorso completo di ogni archivio |
| 🔄 Aggiorna archivi | Rileva di nuovo SCANPST e gli archivi del profilo |
| 🩺 Scansiona PST selezionato | Avvia SCANPST sull'archivio selezionato |
| ▶ Apri SCANPST | Avvia l'utilita' Microsoft per la riparazione degli archivi |
| 🔄 Sincronizza archivio | Avvia Outlook sull'archivio selezionato per la sincronizzazione (senza archivio avvia Outlook) |
| 🧹 Ricostruisci cache | Sposta la cache RoamCache con un backup datato: viene ricreata al prossimo avvio di Outlook |
| 📋 Report archivi | Riepilogo di SCANPST, Outlook e di ogni archivio PST/OST con dimensione e data |
| 💻 Console PowerShell sicura | Catalogo di 21 comandi consentiti, argomenti opzionali e output in sola lettura |

La console PowerShell e' vincolata a un catalogo bianco: sono ammessi solo i
comandi in lettura elencati (per esempio `Get-Process`, `Get-NetAdapter`,
`Get-MpComputerStatus`), e vengono bloccati i token che modificano il sistema
(`Remove-`, `Set-`, `New-`, `Start-`, `Stop-`, `Out-File`, `Invoke-Expression`
e simili). Un comando fuori catalogo viene rifiutato e registrato nel log.

La rilevazione dei file PST/OST interroga `%APPDATA%\Microsoft\Outlook` e
`%LOCALAPPDATA%\Microsoft\Outlook`; l'avvio con archivio selezionato passa il
percorso del file a `SCANPST.EXE`. Ogni voce dell'elenco conserva il
percorso completo, cosi' le operazioni agiscono sempre sull'archivio
effettivamente selezionato.

### Modulo CyberMedic (riparazione rete e sicurezza)
Scheda di ripristino della rete e di diagnostica di sicurezza.

| Pulsante | Azione |
| --- | --- |
| Reset Winsock | `netsh winsock reset` (richiede elevazione e riavvio) |
| Reset TCP/IP | `netsh int ip reset` (richiede elevazione e riavvio) |
| Svuota cache DNS | `ipconfig /flushdns` |
| Release / Renew IP | `ipconfig /release` e `ipconfig /renew` |
| Svuota cache ARP | `arp -d *` |
| Reimposta adapter | Disable/enable dell'adapter (richiede elevazione) |
| 🔍 Report sicurezza | Antivirus, firewall, firme, file hosts e porte in ascolto |
| 📄 Analisi file hosts | Elenco delle voci attive e segnalazione delle voci sospette |
| 🛡️ Scansione rapida Defender | Avvia `Start-MpScan -ScanType QuickScan` |
| 🔄 Aggiorna stato | Rilegge lo stato di Microsoft Defender |

I comandi che richiedono elevazione propongono il riavvio dell'applicazione
come amministratore (`Request-Elevation`); tutti gli interventi girano in
background e l'esito viene riportato nella console della scheda.

### Inventario
Elenco di tutte le stampanti con badge di stato, porta, tipo di porta, IP,
lavori in coda, host, tipo e indicazione della predefinita. Lo stato viene
normalizzato (`Pronta`, `Offline`, `Errore`, `In pausa`...) con fallback su
`PrintManagement` e valore `N/D` quando il dato non e' disponibile. Sono
incluse anche le stampanti **offline** e quelle con driver corrotti.

### Rete
Risoluzione dell'endpoint di stampa con catena di fallback:

1. **Cache porte** (`Get-PrinterPort`)
2. **Registro di sistema**
   (`HKLM\SYSTEM\CurrentControlSet\Control\Print\Monitors\Standard TCP\IP Port\Ports`
   e `HKLM\SYSTEM\CurrentControlSet\Control\Print\Ports`)
3. **Stringa porta** (`IP_192.168.1.50`, `WSD-...`, `\\SERVER\PRN`, host)

Per le porte **WSD**, non risolvibili via DNS, il tool cerca l'endpoint nel
registro dei dispositivi `Enum\SWD\WSDPrint`; se il dispositivo non e'
identificabile, indica la procedura correttiva (leggere l'IP dal pannello e
ricreare una porta TCP/IP Standard RAW 9100).

Il test di rete esegue ping (timeout 1500 ms), test TCP sulle porte 9100/631
(timeout 1500 ms ciascuna) e riporta il profilo di rete attivo. Nessuna
operazione di rete puo' bloccare l'interfaccia: i timeout sono sempre
impostati e il fallimento DNS produce un fallback, non un crash.

### Subnet mask e modifica dell'indirizzo IP

La colonna **Subnet Mask** dell'elenco e le righe `Subnet Mask` / `Sottorete`
della Card e della scheda Dettagli mostrano la maschera di sottorete della
stampante e la rete CIDR derivata. La maschera viene risolta con questa catena
di fallback:

1. **Cache porte** (`Get-PrinterPort`, proprieta' `SubnetMask`)
2. **Registro di sistema**
   (`Control\Print\Monitors\Standard TCP\IP Port\Ports\<porta>` e
   `Control\Print\Ports\<porta>`)
3. **Rete locale**: se l'IP della stampante appartiene alla sottorete di una
   scheda del PC, viene riportata la mask di quella scheda (con interfaccia e
   prefisso come sorgente)
4. `N/D` quando nessuna sorgente e' disponibile

Il pulsante **✏️ Modifica IP** (menu *Azioni > Modifica indirizzo IP*)
apre un dialogo con stampante, porta attuale, tipo di porta, subnet mask
corrente e il campo per il nuovo indirizzo. L'indirizzo viene validato come
IPv4 prima di applicare. Le operazioni possibili:

| Tipo di porta | Comportamento |
| --- | --- |
| TCP/IP RAW (`IP_192.168.1.50`) | Aggiornamento in-place del valore `HostName` della porta nel registro, con riavvio dello Spooler |
| TCP/IP Standard (`192.168.1.50`) | Creazione della nuova porta con l'IP richiesto (numero di porta TCP preservato), riorientamento della stampante e rimozione della vecchia porta se non piu' usata |
| WSD | La porta non e' modificabile in-place: la stampante viene spostata su una porta TCP/IP Standard |
| Locale, USB, virtuale | Operazione rifiutata: l'IP non e' modificabile |
| Condivisa (`\\SERVER\PRN`) | Operazione rifiutata: l'IP va modificato sul server che ospita la coda |

La modifica del registro richiede privilegi di **Amministratore**: senza
elevazione la scrittura fallisce e l'errore e' riportato nella finestra di
esito, senza modificare nulla. Ogni scrittura viene riletta e verificata
prima di dichiarare l'operazione riuscita.

### Lavori in coda
Lettura dei lavori per stampante con `Get-PrintJob` (fallback WMI
`Win32_PrintJob`) e rimozione selettiva con `Remove-PrintJob -PrinterName -ID`.
Se il servizio spooler e' instabile il contatore resta a `0` invece di generare
un errore.

### Spooler
- Riavvio del servizio con attesa dello stato reale (`Stopped` / `Running`)
- Svuotamento della coda: il servizio viene fermato, i file in
  `%WINDIR%\System32\spool\PRINTERS` vengono rimossi e il servizio riparte
  sempre, anche in caso di errore
- Se la rimozione fallisce per permessi, il tool imposta la proprieta' della
  cartella su `Administrators` tramite API .NET, `icacls` con il SID
  `S-1-5-32-544` e `takeown` (nessun problema di localizzazione)
- Il servizio Spooler viene comunque riavviato nel blocco `finally`

### Diagnostica
Report testuale con ambiente, stato spooler, dettaglio della stampante
selezionata, inventario completo, eventi di Print Service delle ultime 24 ore
e registro della sessione. Esportabile in `.txt` dal menu File.
L'export CSV (`📊 Esporta Report`) produce una riga per stampante con 16 campi
operativi, pronto per allegarlo al ticket.

## Protocollo di test e verifica locale

Verifica rapida prima di aprire i ticket, senza toccare le stampanti:

```powershell
cd C:\CyberMedic
.\launch.ps1 -SelfTest
```

Uscita `0` se tutti i controlli passano, `1` in caso di fallimenti. I controlli
eseguiti:

| Controllo | Cosa verifica |
| --- | --- |
| Windows Forms caricato | La GUI e' utilizzabile in PowerShell 5.1 e 7 |
| `Get-CimInstance Win32_Printer` | La raccolta stampanti risponde |
| `Get-Printer (PrintManagement)` | Il modulo di gestione e' disponibile |
| Servizio Spooler raggiungibile | Il servizio di stampa e' attivo |
| Inventario stampanti | La costruzione dell'elenco non va in errore |
| `Get-PrintJob` | La lettura dei lavori non genera errori |
| Risoluzione endpoint | La catena di fallback risolve la porta |
| Subnet mask | La maschera e la sua sorgente vengono determinate |
| Subnet mask e CIDR | Conversione prefisso/mask, CIDR e validazione IPv4 |
| Controllo coda spool | La cartella spool e' leggibile |
| Stato sicurezza | Antivirus, firewall, VPN, UAC e riavvio pendente |
| Dashboard di sistema | Il report della scheda Home viene generato |
| Winget (aggiornamenti) | Il client `winget` e' individuato |
| Risoluzione DNS | Il resolver restituisce indirizzi per `localhost` |
| Servizio nslookup | Il client `nslookup` e' disponibile |
| Privilegi Administrator | Avvisa se la sessione non e' elevata |
| Motore Nmap | Il client `nmap` e' individuato (avviso se assente) |
| Outlook SCANPST | L'utilita' Microsoft e' installata (avviso se assente) |
| Archivi Outlook (PST/OST) | Conteggio degli archivi del profilo |
| Preset Nmap | I 5 preset sono disponibili e completi |
| Driver di sistema | Riepilogo dei dispositivi con problemi |
| Sensore termico | La temperatura ACPI viene letta quando disponibile (avviso altrimenti) |
| Stato SMART dei dischi | Salute dei dischi fisici e sorgente del dato |
| Riparazione di rete | Il catalogo degli interventi e' disponibile (7 voci) |
| Analisi file hosts | Il file `hosts` viene letto e valutato |
| Microsoft Defender | Antivirus, protezione in tempo reale e eta' delle firme |
| Console PowerShell sicura | Un comando in sola lettura del catalogo viene eseguito |
| Piani di pulizia | Le cartelle temporanee vengono enumerate |
| Cache termica e SMART | La cache temporizzata delle query hardware e' valida |
| Report archivi di posta | Il riepilogo degli archivi PST/OST viene generato |
| Adapter di rete attivo | L'adapter collegato viene rilevato dalle API .NET |
| Moduli core caricati | Tutti i moduli di `core\` sono presenti e caricati |
| Metriche risorse di sistema | CPU, RAM e disco vengono rilevati |
| Versione toolkit | La versione in uso e' quella dichiarata |
| Identita prodotto | Nome e versione letti da `product.psd1` |

Il SelfTest della v3.0.0 esegue **38 controlli** (23 nella 2.2.2): i 23
controlli storici piu' 15 nuovi, dedicati all'architettura modulare,
all'identita' del prodotto, alle utility Office e all'inventario Wi-Fi.

Il **SmokeTest** esegue **28 controlli** sulla GUI costruita: schede, titolo,
dashboard, elenchi, grafici on-demand, diagnostica hardware, console
PowerShell, moduli caricati, pulsanti operativi, riquadro Office, box
metriche e separazione App / Driver.

Verifica della sola interfaccia grafica (costruisce la GUI, popola i controlli e
termina):

```powershell
.\launch.ps1 -SmokeTest
```

Verifica del comportamento di rete senza aprire la GUI:

```powershell
.\launch.ps1 -ResolvePort "IP_192.168.1.50"
.\launch.ps1 -Diagnose
```

## Troubleshooting

| Sintomo | Causa probabile | Azione |
| --- | --- | --- |
| "Accesso negato" su `PRINTERS\` | Sessione non elevata | Avviare con `launch.ps1` |
| La coda non si svuota | File bloccati dal driver | Usare "Svuota Spooler": il tool forza la proprieta' e riavvia il servizio |
| "Impossibile aggiornare la porta" | Sessione non elevata o porta non installata | Riavviare come Amministratore; verificare in "Porte stampante" che la porta esista |
| Subnet mask `N/D` | La stampante non e' nella sottorete di nessuna scheda locale | Il valore arriva dalla cache porte o dal registro della porta |
| La stampante e' "Offline" | Porta WSD non risolvibile | Scheda Rete: ricreare la porta TCP/IP Standard con l'IP del dispositivo |
| `Get-PrintJob` non risponde | Spooler instabile | "Riavvia spooler", poi ripetere la lettura |
| DNS non risolvibile | Timeout di rete | Il tool passa al fallback e segnala l'assenza di IP; verificare il resolver |
| La GUI non si apre | Modulo WinForms assente | Usare Windows PowerShell 5.1 (incluso) |
| Errore di parsing all'avvio | File salvato in UTF-8 senza BOM | Risalvare in UTF-8 con BOM |
| La finestra resta sopra le altre | `TopMost` attivo | Chiudere l'applicazione con il pulsante rosso |

## Log e privacy

I log sono scritti in `logs\stampanti-YYYYMMDD.log` (una sessione per giorno)
e includono solo dati locali della postazione. I report diagnostici esportati
contengono nomi di stampanti, indirizzi IP e nomi utente: prima di allegarli a
un ticket, verificare che non contengano dati riservati.

## Log delle modifiche

| Versione | Data | Note |
| --- | --- | --- |
| 3.0.0 | 2026-10-22 | **CyberMedic**: rinomina completa di file, moduli e interfacce (`CyberMedic_Core.ps1`, `CyberMedic_GUI.ps1`, `core\office.ps1`, `core\wifi.ps1`); riquadro **Office e licenze** nella Home (Product Key via `OSPP.VBS` con guardia sulla chiave vuota, lettura dello stato licenze, rimozione tramite disinstallatori ufficiali Microsoft); **informazioni Wi-Fi avanzate** (interfaccia e profili salvati, senza estrazione del materiale chiave); **box separati** per CPU, RAM, disco e GPU nel Task Manager e per Aggiornamenti applicazioni / Driver di sistema nella scheda Updates; SelfTest a 38 controlli e SmokeTest a 28 |
| 2.5.0 | 2026-10-21 | **Identita' centralizzata**: nuovo file `product.psd1` (nome, versione, edizione, build, slogan, colore) unica fonte di verita', letto dal Core all'avvio; nessuna stringa di prodotto hardcoded nel codice; splash **blu** con checklist dei passi di avvio e marcatori `[ OK ] / [ .. ]`; override puntuale con `-ProductName` / `-ProductVersion` e con le variabili d'ambiente `APP_PRODUCT_NAME` / `APP_PRODUCT_VERSION`; caption delle finestre, titolo, header, log e SelfTest allineati all'identita'; SelfTest a 35 controlli |
| 2.4.0 | 2026-10-21 | **Architettura modulare**: backend diviso in `core\` (metrics, updates, maintenance, outlook, cybermedic) e front-end diviso in `gui\` (splash + una scheda per file in `gui\tabs\`), 8 schede (Home, Gestione Stampanti, Network & Rete, Task Manager, Updates, Maintenance, Mail & PowerShell, CyberMedic), splash deterministico che si chiude solo al 100% dell'avvio, grafici CPU/RAM/disco attivabili a richiesta, diagnostica hardware con thermal throttling e dischi SMART, manutenzione archivi PST/OST (sincronizzazione, cache, report), console PowerShell in sola lettura, riparazione di rete, SelfTest a 34 controlli e SmokeTest a 25 |
| 2.2.2 | 2026-10-21 | Modulo manutenzione software: elenco pacchetti aggiornabili con selezione multipla, applica selezionati, "scarica e installa tutto" (`winget upgrade --all`), cambio password utente via ADSI, parsing della tabella winget indipendente dalla lingua |
| 2.2.1 | 2026-10-21 | Sezione DNS dedicata nella scheda Network & Rete (cache, flush, test di risoluzione `nslookup` con dominio personalizzabile), avvio Wireshark e nmap opzionali, decodifica output console con codepage OEM |
| 2.1.0 | 2026-10-21 | Architettura Thin Client: `NovaChimera_Core.ps1` (backend) e `NovaChimera_GUI.ps1` (front-end), launcher aggiornato, coda dei comandi in background, colori spostati nel client, monolitico 2.0.0 conservato in `archive/` |
| 2.0.0 | 2026-10-21 | GUI a 4 schede (Home/Dashboard, Gestione Stampanti, Network & Rete, Manutenzione PC), dashboard di sicurezza, comandi `ipconfig` in background, pulizia file temporanei, aggiornamenti `winget`, SelfTest a 14 controlli |
| 1.4.0 | 2026-10-21 | Subnet mask e CIDR nell'inventario, colonna "Subnet Mask", pulsante e menu "Modifica IP", correzioni PowerShell 5.1 (conversioni a 32 bit, raccolte generiche) |
| 1.2.0 | 2026-10-21 | Tema Obsidian Purple, badge di stato, colonna IP, Card diagnostica live, pulsanti Cerca Driver / WebAdmin / Elimina / Termina, export CSV, stato offline |
| 1.0.0 | 2026-10-21 | Prima release: inventario, diagnostica di rete, gestione coda e spooler |
