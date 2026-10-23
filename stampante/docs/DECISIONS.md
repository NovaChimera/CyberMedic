# CyberMedic - Decisioni tecniche

Registro delle decisioni prese e del loro motivo. Serve a evitare di
riproporre discussioni gia' chiuse e a spiegare le scelte non ovvie.

---

## D-001 - WinForms invece di WinUI 3

**Decisione.** Il toolkit resta WinForms; l'aspetto WinUI 3 / Fluent viene
ricostruito a mano in `gui\theme.ps1`.

**Motivo.** WinUI 3 richiede il Windows App SDK e un'applicazione .NET
pacchettizzata: non e' eseguibile come script PowerShell. Il requisito di
prodotto e' "zero installazioni, zero dipendenze", che WinForms rispetta.

**Conseguenza.** Angoli arrotondati, hover, toggle, card e tab disegnate sono
implementati a mano con `GraphicsPath`, `Region` e `DrawItem`. Il risultato e'
visivamente vicino allo stile Fluent, non identico.

---

## D-002 - Architettura Thin Client con dot-sourcing

**Decisione.** Il backend (`CyberMedic_Core.ps1`) e il front-end
(`CyberMedic_GUI.ps1`) sono due file, a loro volta composti da moduli
caricati con il dot-sourcing.

**Motivo.** Separare la logica di sistema dalla costruzione dell'interfaccia
consente di testare il backend senza interfaccia (SelfTest) e di rifare la UI
senza toccare la logica (SmokeTest).

**Conseguenza.** Il Core non conosce WinForms e restituisce dati semantici;
la traduzione in colori e controlli resta nel thin client.

---

## D-003 - Compatibilita' Windows PowerShell 5.1 e PowerShell 7

**Decisione.** Ogni script deve funzionare su entrambe le shell.

**Motivo.** Il prodotto gira su postazioni eterogenee: alcune hanno solo
Windows PowerShell 5.1, altre anche PowerShell 7. `launch.ps1` seleziona
`pwsh.exe` quando disponibile e ripiega su `powershell.exe`.

**Conseguenza.** Niente `#Requires -Version 7.0`, niente sintassi esclusiva di
PS7, e i file vanno salvati in UTF-8 con BOM (senza BOM, PS 5.1 interpreta
le emoji come ANSI e il parsing fallisce).

---

## D-004 - `$sender` va dichiarato con `param()` negli handler WinForms

**Decisione.** Ogni handler registrato come scriptblock che usa `$sender`
dichiara esplicitamente `param($sender)` o `param($sender, $e)`.

**Motivo.** In PowerShell 5.1 e 7 `$sender` **non** viene popolato
automaticamente dentro uno scriptblock passato a `Add_Click` / `Add_Resize` /
`Add_MouseEnter`. Il valore e' `$null`, e le funzioni con parametri
obbligatori falliscono con "Impossibile associare l'argomento al parametro
'X' perché è Null". Il bug era invisibile finche' il `Resize` automatico
scattato durante `Controls.Add` non ha fatto fallire l'avvio della dashboard.

**Conseguenza.** Regola scritta in `docs/ARCHITECTURE.md` e verificata nei
test.

---

## D-005 - Le funzioni costruttrici restituiscono un solo oggetto

**Decisione.** Ogni chiamata che emette output all'interno di una funzione
`New-*` o di un helper va wrappata in `[void](...)`.

**Motivo.** In PowerShell una funzione restituisce *tutto* cio' che scrive
nella pipeline. `New-FluentToggleButton` chiamava `Set-FluentToggleState`,
che a sua volta scriveva `True` nella pipeline: il chiamante riceveva
`[True, Button]` invece del bottone, e `.Tag` falliva con "Impossibile
trovare la proprietà 'Tag' in questo oggetto".

**Conseguenza.** Stessa regola che vale per `Add-QueuedTask` e per tutti gli
helper che restituiscono dati e valori di stato insieme.

---

## D-006 - Le funzioni non emettono piu' di un valore nei costruttori GUI

**Decisione.** I costruttori UI (`New-ThemedButton`, `New-FluentButton`,
`New-FluentToggleButton`, `New-FluentCard`) restituiscono esclusivamente il
controllo.

**Motivo.** Il caller aggiunge il controllo a un container
(`$container.Controls.Add($x)`): se `$x` fosse un array, l'aggiunta
fallirebbe con un errore di associazione degli argomenti poco leggibile.

---

## D-007 - Identita' del prodotto in `product.psd1`

**Decisione.** Nome, versione, edizione, build, slogan, accento e tema stanno
in un unico file dati; il codice non contiene stringhe hardcoded.

**Motivo.** Rinominare o versionare il prodotto richiede la modifica di un
solo file. Gli override da riga di comando (`-ProductName`, `-ProductVersion`)
e da variabili d'ambiente (`APP_PRODUCT_NAME`, `APP_PRODUCT_VERSION`) hanno la
precedenza per l'avvio corrente.

**Conseguenza.** La rinomina da NovaChimera a CyberMedic (3.0.0) ha richiesto
solo il file `product.psd1` piu' il rinominamento dei file.

---

## D-008 - Comandi esterni sempre asincroni

**Decisione.** Nmap, Winget, SCANPST e gli altri comandi lenti girano tramite
`Start-BackgroundCommand`; l'interfaccia non si blocca.

**Motivo.** Un'interfaccia bloccata su un comando di rete e' un difetto
percettibile grave in un tool di supporto.

**Conseguenza.** Il callback di completamento ha la firma
`param($text, $exitCode, $cmdArgs, $task)` e il testo viene tradotto in
badge colorati dal thin client.

---

## D-009 - Niente `GetNewClosure()` nei callback GUI

**Decisione.** I callback che devono leggere variabili di script usano
esplicitamente `$script:` oppure valori copiati in una variabile locale
chiusa lessicalmente.

**Motivo.** `GetNewClosure()` crea un nuovo scope in cui `script:` non
risolve: le variabili di script diventerebbero `$null` e il callback
fallirebbe silenziosamente.

---

## D-010 - La coda operazioni e' sequenziale

**Decisione.** Applicazioni e driver vengono applicati uno alla volta dalla
coda (`Add-QueuedTask` / `Get-QueuedTask` / `Start-NextQueuedTask`).

**Motivo.** `winget` e l'installazione dei driver non possono girare in
parallelo: si bloccano a vicenda e il risultato non e' affidabile.

**Conseguenza.** `Add-QueuedTask` accetta `-Tag` per identificare il tipo di
lavoro; i preset Nmap usano token separati (mai un argomento tipo
`"-F 127.0.0.1"`).

---

## D-011 - I grafici partono spenti

**Decisione.** I grafici delle metriche sono creati con `Visible = $false` e si
attivano solo su richiesta esplicita dell'utente.

**Motivo.** Riduce il carico della CPU e il tempo di avvio; il monitoraggio
resta comunque sempre attivo e i valori live sono gia' nelle caselle metriche.

**Conseguenza.** I toggle dei grafici (Task Manager e Updates) usano
`New-FluentToggleButton`: il colore del pulsante riflette lo stato reale del
grafico, sincronizzato da `Update-MetricChartButtons`.

---

## D-012 - `C:\StampantiTool` non e' piu' l'installazione

**Decisione.** L'installazione attiva e' `C:\CyberMedic`; in
`C:\StampantiTool` restano solo backup e la nota `SE-MOVIDA-CyberMedic.txt`.

**Motivo.** Il prodotto e' stato rinominato da StampantiTool a CyberMedic:
mantenere due copie attive avrebbe creato due divergenze divergenti.
