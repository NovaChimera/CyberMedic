# CyberMedic - Documentazione

Documentazione tecnica del progetto. I file in questa cartella servono a
riprendere il lavoro senza perdere il contesto.

| Documento | Contenuto | Aggiornato |
| --- | --- | --- |
| [SESSION_STATE.md](SESSION_STATE.md) | Stato della sessione, test, prossimi passi, vincoli | 2026-10-22 |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Componenti, moduli, contratti, regole di robustezza | 2026-10-22 |
| [TESTING.md](TESTING.md) | Comandi di test, checklist di rilascio, diagnostica | 2026-10-22 |
| [ROADMAP.md](ROADMAP.md) | Backlog aperto per priorita' | 2026-10-22 |
| [DEPLOY.md](DEPLOY.md) | Deploy in `C:\CyberMedic` e rollback | 2026-10-22 |
| [INSTALLER.md](INSTALLER.md) | Installer portable/installata | 2026-10-22 |

## Documentazione di livello superiore

| Documento | Contenuto |
| --- | --- |
| `../README.md` | Documentazione tecnica completa per il team |
| `../RELEASE_NOTES.md` | Note di rilascio per versione |

## Regola di aggiornamento

Ogni sessione conclusa deve:

1. aggiornare `SESSION_STATE.md` con i test eseguiti e i loro esiti;
2. spostare in `ROADMAP.md` le attivita' rimaste aperte;
3. annotare in `DECISIONS.md` ogni scelta tecnica non ovvia;
4. aggiornare la colonna "Aggiornato" della tabella qui sopra.
