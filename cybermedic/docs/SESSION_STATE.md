# CyberMedic - Stato della sessione

> Documento di continuazione. Scritto per permettere di riprendere il lavoro
> senza perdere il contesto. Aggiornare a ogni sessione conclusa.

Ultimo aggiornamento: **2026-10-22**

## Identita' del progetto

| Campo | Valore |
| --- | --- |
| Prodotto | CyberMedic |
| Versione | 3.0.0 (build 2026-10-22) |
| Edizione | Enterprise IT Helpdesk Suite |
| Slogan | Advanced IT Diagnostics & Maintenance |
| Accento | `#b388ff` (Obsidian Purple WinUI3 Style) |
| Fonte di verita' | `product.psd1` (nome, versione, build, accento) |

## Percorsi

| Scopo | Percorso |
| --- | --- |
| Repository di sviluppo | `C:\Users\User\Desktop\git\stampante` |
| Installazione attiva | `C:\CyberMedic` |
| Archivio / backup delle versioni precedenti | `C:\StampantiTool\backup` |
| Nota di migrazione | `C:\StampantiTool\SE-MOVIDA-CyberMedic.txt` |
| Log di sessione | `<installazione>\logs\cybermedic-<data>.log` |

> La cartella `C:\StampantiTool` **non** e' piu' l'installazione: contiene solo
> backup e la nota che dichiara lo spostamento in `C:\CyberMedic`.

## Come verificare lo stato (2 comandi)

```powershell
# SelfTest: 38 controlli di backend, nessuna interfaccia
& pwsh -NoProfile -ExecutionPolicy Bypass -File 'C:\Users\User\Desktop\git\stampante\CyberMedic_GUI.ps1' -SelfTest

# SmokeTest: costruisce la GUI senza mostrarla, 29 controlli sui controlli UI
& pwsh -NoProfile -ExecutionPolicy Bypass -STA -File 'C:\Users\User\Desktop\git\stampante\CyberMedic_GUI.ps1' -SmokeTest
```

Sostituire `pwsh` con `powershell` per validare su Windows PowerShell 5.1.
**I due comandi devono essere eseguiti su entrambe le shell** prima di ogni
deploy: la compatibilita' 5.1/7 e' un requisito di prodotto, non un extra.

## Stato dei test (2026-10-22)

| Test | Shell | Esito |
| --- | --- | --- |
| SelfTest | PowerShell 7.6.7 | 38 controlli, 0 falliti |
| SelfTest | Windows PowerShell 5.1 | 38 controlli, 0 falliti |
| SmokeTest | PowerShell 7.6.7 | 29 controlli, 0 falliti |
| SmokeTest | Windows PowerShell 5.1 | 29 controlli, 0 falliti |

Gli unici WARN del SelfTest sono **attesi** e non dipendono dal codice:
sessione non elevata e Nmap non installato sulla postazione.

## Cosa e' stato completato in quest'ultima sessione

1. **Correzione del crash di avvio della GUI** (`Controls.Add` con argomento
   `Control` null). Causa: dentro gli handler WinForms registrati come
   scriptblock, `$sender` **non e' popolato** in PowerShell 5.1 e 7; il
   `Resize` scattato durante `Controls.Add` chiamava
   `Set-FluentCorners -Control $sender` con `$sender = $null`.
   Fix: tutti gli handler senza blocco `param()` ora usano
   `param($sender)` (o `param($sender, $e)`).
   File toccati: `gui\theme.ps1`, `CyberMedic_GUI.ps1`.
2. **`New-FluentToggleButton` restituiva due oggetti** (il `True` di
   `Set-FluentToggleState` piu' il bottone). Il chiamante riceveva un array e
   `.Tag` falliva. Fix: `[void](Set-FluentToggleState ...)`.
3. **SmokeTest**: il conteggio dei moduli GUI era fermo a 6 mentre i moduli
   reali sono 7 (aggiunto `gui\theme.ps1`). Corretto a 7.
4. **Etichette dello splash** allineate: "Moduli core (5)" -> 7,
   "Schede GUI modulari (5)" -> 7.
5. **Cache degli aggiornamenti**: `$script:UpdatesLoadedAt` ora e' inizializzata
   a `$null` a livello di modulo (`gui\tabs\updates.ps1`).
6. **Caricamento automatico degli aggiornamenti**: `Load-UpdatePackages` viene
   chiamata in `Initialize-DashboardState`, quindi l'elenco Winget si popola in
   background gia' all'avvio e non solo aprendo la scheda Updates.
7. **Grafici prestazione non piu' fermi**: `Update-ActivityMetrics` invalida
   anche `$script:Ui.UpdateCharts` (prima ridisegnava solo i grafici del Task
   Manager).
8. **Toggle in stile WinUI 3 nel Task Manager**: i tre pulsanti dei grafici
   usano ora `New-FluentToggleButton` (stato on/off, colore di accento), in
   coerenza con la scheda Updates.
9. **SmokeTest esteso**: nuovo controllo "Toggle in stile WinUI" (>= 6 toggle
   attivi), da 28 a 29 controlli.
10. **Rimozione della strumentazione di debug** temporanea usata per la
    diagnosi.

- **Installer PowerShell** creato in `installer\CyberMedic_Installer.ps1`:
  modalita' Portabile (nessuna modifica al sistema) o Installata
  (Program Files, menu Start, disinstallazione). Verificato su entrambe le
  modalita'. Documentazione in `docs/INSTALLER.md`.

1. ~~Aggiornare `README.md` e `RELEASE_NOTES.md` con le correzioni 3.0.1 e la
   nuova struttura `docs/`.~~ **Fatto** (2026-10-22).
2. ~~Decidere il numero di versione della patch: **3.0.1** (solo correzioni).~~
   **Fatto**.
3. ~~Aggiornare `product.psd1` (Version + BuildDate) e la checklist dello splash.~~
   **Fatto**: Version = 3.0.1.
4. ~~Backup dell'installazione corrente in `C:\StampantiTool\backup\v3.0.0`.~~
   **Fatto**.
5. ~~Deploy della repository in `C:\CyberMedic` (vedi `docs/DEPLOY.md`).~~
   **Fatto** (2026-10-22).
6. ~~Verifica post-deploy: `SelfTest` e `SmokeTest` dalla directory installata.~~
   **Fatto**: 38/38 SelfTest e 29/29 SmokeTest su entrambe le shell.

Nessuna attivita' bloccante residua. Le attivita' aperte sono in
`docs/ROADMAP.md` (P1/P2/P3).

## Deploy (2026-10-22)

- Backup creato in `C:\StampantiTool\backup\v3.0.0` (robocopy, esclusa `logs`).
- Deploy della repository in `C:\CyberMedic` (esclusi `logs`, `archive`, `docs`).
- File orfano `gui\tabs\cybermedic.ps1` rimosso.
- Verifica post-deploy superata su entrambe le shell:
  - SelfTest: 38/38 (pwsh 7 e PS 5.1)
  - SmokeTest: 29/29 (pwsh 7 e PS 5.1)

- Compatibilita' **Windows PowerShell 5.1 + PowerShell 7**: niente
  `#Requires -Version 7.0`, niente sintassi esclusiva di PS7.
- Salvare gli script in **UTF-8 con BOM**: senza BOM, PS 5.1 interpreta le
  emoji come ANSI e il parsing fallisce all'avvio.
- Il backend non deve conoscere WinForms: il Core restituisce dati
  semantici, il thin client li traduce in colori.
- Comandi esterni lunghi (Nmap, Winget, SCANPST) restano asincroni via
  `Start-BackgroundCommand`.
- Nei callback GUI **non usare `GetNewClosure()`**: `script:` non e' visibile
  nel relativo scope. Firma standard dei callback:
  `param($text, $exitCode, $cmdArgs, $task)`.
- Nessun nuovo modulo esterno: zero installazioni richieste.
- Un solo `Show-SplashScreen` per esecuzione.

## Documenti collegati

| Documento | Contenuto |
| --- | --- |
| `docs/SESSION_STATE.md` | questo file: stato, test, prossimi passi |
| `docs/ARCHITECTURE.md` | come e' organizzato il codice |
| `docs/TESTING.md` | comandi di test e checklist di rilascio |
| `docs/ROADMAP.md` | backlog delle attivita' aperte |
| `docs/DEPLOY.md` | procedura di deploy e rollback |
| `docs/DECISIONS.md` | decisioni tecniche e loro motivazione |
