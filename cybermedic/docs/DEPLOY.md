# CyberMedic - Deploy e rollback

## Percorsi

| Ruolo | Percorso |
| --- | --- |
| Sviluppo | `C:\Users\User\Desktop\git\stampante` |
| Installazione | `C:\CyberMedic` |
| Backup versioni | `C:\StampantiTool\backup` |

## Procedura di deploy

### 1. Verifica pre-deploy (nella repository)

```powershell
$root = 'C:\Users\User\Desktop\git\stampante'
$pwsh = 'C:\Users\User\AppData\Local\Microsoft\WindowsApps\pwsh.exe'
$ps51 = 'C:\windows\System32\WindowsPowerShell\v1.0\powershell.exe'

& $pwsh -NoProfile -ExecutionPolicy Bypass -File "$root\CyberMedic_GUI.ps1" -SelfTest
& $ps51 -NoProfile -ExecutionPolicy Bypass -File "$root\CyberMedic_GUI.ps1" -SelfTest
& $pwsh -NoProfile -ExecutionPolicy Bypass -STA -File "$root\CyberMedic_GUI.ps1" -SmokeTest
& $ps51 -NoProfile -ExecutionPolicy Bypass -STA -File "$root\CyberMedic_GUI.ps1" -SmokeTest
```

Tutti e quattro i comandi devono terminare con 0 falliti.

### 2. Backup dell'installazione corrente

```powershell
$src = 'C:\CyberMedic'
$dst = 'C:\StampantiTool\backup\v3.0.0'
if (Test-Path -LiteralPath $dst) { $dst = 'C:\StampantiTool\backup\v3.0.0-' + (Get-Date -Format 'yyyyMMdd-HHmmss') }
New-Item -ItemType Directory -Path $dst -Force | Out-Null
robocopy $src $dst /E /XD logs /R:1 /W:1
```

### 3. Copia dei file

```powershell
$src = 'C:\Users\User\Desktop\git\stampante'
$dst = 'C:\CyberMedic'
robocopy $src $dst /E /XD logs archive docs /R:1 /W:1
```

Note sulla copia:
- `logs` non viene copiata: i log sono specifici della postazione.
- `archive` non viene copiata: contiene solo la versione monolitica 2.0.0 di
  riferimento.
- `docs` puo' essere esclusa dal deploy (documentazione interna) oppure
  copiata: decidere in fase di deploy e annotare qui la scelta.

Il file `gui\tabs\cybermedic.ps1` presente nella vecchia installazione (nome
precedente della scheda) **deve** essere rimosso: non e' piu' un modulo valido
e non viene caricato, ma lascia un file orfano nella cartella.

```powershell
Remove-Item -LiteralPath 'C:\CyberMedic\gui\tabs\cybermedic.ps1' -Force -ErrorAction SilentlyContinue
```

### 4. Verifica post-deploy

```powershell
$pwsh = 'C:\Users\User\AppData\Local\Microsoft\WindowsApps\pwsh.exe'
$ps51 = 'C:\windows\System32\WindowsPowerShell\v1.0\powershell.exe'
& $pwsh -NoProfile -ExecutionPolicy Bypass -File 'C:\CyberMedic\CyberMedic_GUI.ps1' -SelfTest
& $ps51 -NoProfile -ExecutionPolicy Bypass -File 'C:\CyberMedic\CyberMedic_GUI.ps1' -SelfTest
& $pwsh -NoProfile -ExecutionPolicy Bypass -STA -File 'C:\CyberMedic\CyberMedic_GUI.ps1' -SmokeTest
& $ps51 -NoProfile -ExecutionPolicy Bypass -STA -File 'C:\CyberMedic\CyberMedic_GUI.ps1' -SmokeTest
```

## Rollback

```powershell
$backup = 'C:\StampantiTool\backup\v3.0.0'   # cartella del backup
robocopy $backup 'C:\CyberMedic' /E /R:1 /W:1
```

Dopo il rollback eseguire il SelfTest per confermare che l'installazione
ripristinata e' funzionante.

## Deploy manuale in alternativa

Se `robocopy` non e' disponibile o si preferisce un deploy selettivo:

```powershell
$src = 'C:\Users\User\Desktop\git\stampante'
$dst = 'C:\CyberMedic'
$files = @(
    'CyberMedic_Core.ps1'
    'CyberMedic_GUI.ps1'
    'launch.ps1'
    'product.psd1'
    'README.md'
    'RELEASE_NOTES.md'
)
foreach ($file in $files) { Copy-Item -LiteralPath (Join-Path $src $file) -Destination (Join-Path $dst $file) -Force }
Copy-Item -LiteralPath (Join-Path $src 'core') -Destination $dst -Recurse -Force
Copy-Item -LiteralPath (Join-Path $src 'gui') -Destination $dst -Recurse -Force
```

## Promemoria

- Salvare gli script in **UTF-8 con BOM** prima del deploy: PS 5.1 legge i
  file senza BOM come ANSI e le emoji diventano illeggibili.
- Il deploy non deve mai essere eseguito mentre la GUI e' aperta: i file
  `.ps1` gia' caricati in memoria restano in uso e i log vengono ruotati.
