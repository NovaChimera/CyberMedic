# CyberMedic - Installer (portable / installata)

Script: `installer\CyberMedic_Installer.ps1`

## Uso

```powershell
# Interattivo (chiede la modalita' e la cartella)
& 'C:\Users\User\Desktop\git\stampante\installer\CyberMedic_Installer.ps1'

# Portabile, cartella esplicita
& 'C:\Users\User\Desktop\git\stampante\installer\CyberMedic_Installer.ps1' `
    -Mode Portable -Destination 'D:\Tools\CyberMedic-Portable' `
    -Source 'C:\Users\User\Desktop\git\stampante'

# Installata, cartella esplicita (richiede elevazione per il registro)
& 'C:\Users\User\Desktop\git\stampante\installer\CyberMedic_Installer.ps1' `
    -Mode Installed -Destination 'C:\Program Files\CyberMedic' `
    -Source 'C:\Users\User\Desktop\git\stampante'
```

## Modalita'

| Modalita' | Cosa fa | Modifiche al sistema |
| --- | --- | --- |
| **Portabile** | Copia i file in una cartella scelta dall'utente | Nessuna. Avvio tramite `launch.ps1` o `CyberMedic_GUI.ps1` |
| **Installata** | Copia in `%ProgramFiles%\CyberMedic` (o cartella scelta) | Collegamento nel menu Start, voce di disinstallazione in `HKLM:\...\Uninstall`, script `uninstall.ps1` |

## Disinstallazione

- **Portabile**: basta cancellare la cartella.
- **Installata**: `Pannello di controllo -> Programmi -> Disinstalla`, oppure
  eseguire `uninstall.ps1` nella cartella di installazione.

## Note

- Nessuna dipendenza esterna: e' uno script PowerShell, come il prodotto.
- La voce di disinstallazione nel registro richiede privilegi elevati; senza
  elevazione l'installer continua e crea solo il collegamento e lo script di
  disinstallazione.
- I file `logs`, `archive` e `docs` non vengono copiati.
- Il file orfano `gui\tabs\cybermedic.ps1` viene rimosso automaticamente.
- I file vanno salvati in UTF-8 con BOM (vedi `README.md`).
