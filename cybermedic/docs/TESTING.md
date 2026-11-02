# CyberMedic - Testing e checklist di rilascio

## Ambiente di test

| Componente | Percorso |
| --- | --- |
| PowerShell 7 | `C:\Users\User\AppData\Local\Microsoft\WindowsApps\pwsh.exe` (verificato: 7.6.7) |
| Windows PowerShell 5.1 | `C:\windows\System32\WindowsPowerShell\v1.0\powershell.exe` (verificato: 5.1.26100.9711) |

La shell di default del terminale e' PowerShell 5.1: i comandi con `pwsh`
devono essere invocati con il percorso completo o con il call operator.

## Test automatici

### SelfTest (backend)

```powershell
& 'C:\Users\User\AppData\Local\Microsoft\WindowsApps\pwsh.exe' -NoProfile -ExecutionPolicy Bypass `
    -File 'C:\Users\User\Desktop\git\stampante\CyberMedic_GUI.ps1' -SelfTest

& 'C:\windows\System32\WindowsPowerShell\v1.0\powershell.exe' -NoProfile -ExecutionPolicy Bypass `
    -File 'C:\Users\User\Desktop\git\stampante\CyberMedic_GUI.ps1' -SelfTest
```

- 38 controlli, nessuna interfaccia grafica.
- Exit code 0 se nessun controllo fallisce.
- WARN attesi: sessione non elevata, Nmap non installato.

### SmokeTest (front-end)

```powershell
& 'C:\Users\User\AppData\Local\Microsoft\WindowsApps\pwsh.exe' -NoProfile -ExecutionPolicy Bypass -STA `
    -File 'C:\Users\User\Desktop\git\stampante\CyberMedic_GUI.ps1' -SmokeTest

& 'C:\windows\System32\WindowsPowerShell\v1.0\powershell.exe' -NoProfile -ExecutionPolicy Bypass -STA `
    -File 'C:\Users\User\Desktop\git\stampante\CyberMedic_GUI.ps1' -SmokeTest
```

- Costruisce l'interfaccia **senza mostrarla** e verifica il popolamento dei
  controlli registrati in `$script:Ui`.
- 29 controlli (dal 2026-10-22).
- Exit code 1 se almeno un controllo fallisce; in caso di eccezione stampa
  anche lo stack trace.

> Lo `-STA` e' obbligatorio per lo SmokeTest: i controlli WinForms richiedono
> un apartment single-threaded.

### Controllo di parsing (rapido)

```powershell
$files = Get-ChildItem -LiteralPath 'C:\Users\User\Desktop\git\stampante' -Recurse -Filter *.ps1 |
    Where-Object { $_.FullName -notlike '*\archive\*' }
$errors = @()
foreach ($file in $files) {
    $tokens = $null; $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors) { $errors += "$($file.Name): $($parseErrors[0].Message)" }
}
if ($errors) { $errors } else { 'Parsing OK su tutti i file.' }
```

## Checklist di rilascio

- [ ] `SelfTest` superato su **PowerShell 5.1** e **7** (0 falliti)
- [ ] `SmokeTest` superato su **PowerShell 5.1** e **7** (0 falliti)
- [ ] Parsing OK su tutti i file `.ps1` (escludere `archive\`)
- [ ] `product.psd1` aggiornato: versione e `BuildDate` corretti
- [ ] `RELEASE_NOTES.md` aggiornato con le correzioni della versione
- [ ] `README.md` aggiornato (struttura, moduli, conteggi dei test)
- [ ] `docs/SESSION_STATE.md` aggiornato con lo stato della sessione
- [ ] Nessuna riga di debug residua (grep di `Write-Output 'DBG`, `Console]::Error`)
- [ ] Nessun file temporaneo lasciato in `C:\Users\User\AppData\Local\Temp\kilo`
- [ ] Backup della release precedente creato
- [ ] Deploy completato e verificato **dalla directory installata**

## Test manuali (interfaccia)

| Scenario | Risultato atteso |
| --- | --- |
| Avvio normale | Splash con checklist, dashboard che si apre al 100% |
| Avvio non elevato | Messaggio "Sessione NON elevata" nello stato, nessun crash |
| Svuotamento spooler | Chiede conferma, funziona solo se elevato |
| Scheda Updates | L'elenco Winget e' gia' popolato all'apertura (caricato in background all'avvio) |
| Toggle grafici Task Manager | Il pulsante cambia stato/colore, il grafico appare e scompare |
| Toggle grafici Updates | Idem, con riquadro card |
| Scheda Cybersecurity | Console, analisi hosts, stato Defender |
| Chiusura | Finestra chiusa, log scritto in `logs\cybermedic-<data>.log` |

## Diagnosi rapida

| Sintomo | Causa probabile |
| --- | --- |
| `Impossibile associare l'argomento al parametro 'X' perché è Null` in un handler | `$sender` non dichiarato: usare `param($sender)` |
| `Impossibile trovare la proprietà 'Tag'` su un pulsante | La funzione costruttrice restituisce piu' di un oggetto: wrappare in `[void](...)` |
| `GUI smoke test FALLITO` subito dopo l'avvio | Un modulo GUI non e' stato caricato: controllare il log di sessione |
| Emoji illeggibili / errore di parsing in PS 5.1 | File salvato senza BOM: salvare in UTF-8 con BOM |
