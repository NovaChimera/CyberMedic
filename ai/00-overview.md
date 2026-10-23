# 00 - Overview

## Cos'è CyberMedic

CyberMedic è una suite di supporto tecnico di postazione IT, **senza dipendenze
esterne**: tutto risiede in script PowerShell + WinForms. Versione corrente
`3.0.1` (data build `2026-10-22`), tema **Obsidian Purple** (stile WinUI 3
ricostruito su WinForms).

## Stack tecnologico

| Livello | Tecnologia |
| --- | --- |
| Linguaggio | PowerShell 5.1 e 7.x (compatibili entrambi) |
| Interfaccia | WinForms (System.Windows.Forms) con design system Fluent |
| Backend | Script PowerShell, WMI/CIM, registro HKLM, .NET (System.Net, System.Diagnostics) |
| Strumenti esterni | winget, nmap, Wireshark, ipconfig, netsh, nslookup, cscript, OSPP.VBS, pnputil |
| Build/Deploy | Nessuna build: script eseguiti direttamente |
| Test | SelfTest (38 controlli), SmokeTest (28 controlli) |

## Entry point

```
launch.ps1  →  CyberMedic_GUI.ps1 (thin client)  →  CyberMedic_Core.ps1 (backend)
```

- `launch.ps1`: auto-elevazione UAC, selezione `pwsh.exe` vs `powershell.exe`,
  forwarding degli argomenti.
- `CyberMedic_GUI.ps1`: unico punto d'ingresso; carica il backend via dot-sourcing,
  poi i moduli GUI.
- `CyberMedic_Core.ps1`: logica di sistema, non conosce WinForms.

## Identità del prodotto

Unica fonte di verità: `product.psd1` (accanto a `launch.ps1`).

```powershell
@{
    Name      = 'CyberMedic'
    Version   = '3.0.1'
    Edition   = 'Enterprise IT Helpdesk Suite'
    BuildDate = '2026-10-22'
    Slogan    = 'Advanced IT Diagnostics & Maintenance'
    Accent    = '#b388ff'
    Theme     = 'Obsidian Purple WinUI3 Style'
}
```

Priorità di override: argomenti CLI (`-ProductName`/`-ProductVersion`) >
variabili env (`APP_PRODUCT_NAME`/`APP_PRODUCT_VERSION`) > `product.psd1` >
fallback interni del Core.

## Requisiti

- Windows 10/11 o Windows Server 2016+
- PowerShell 5.1 o 7.x
- Privilegi amministratore per alcune operazioni (svuotamento spooler, riavvio servizio)
- Nessuna dipendenza esterna

## Note sui file

- Salvare gli script in **UTF-8 con BOM**: PS 5.1 legge i file senza BOM come
  ANSI e le emoji diventano illeggibili, causando un errore di parsing.
- I log vengono scritti in `logs\cybermedic-YYYYMMDD.log`.