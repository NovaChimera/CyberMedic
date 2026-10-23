# AI Brain - CyberMedic Codebase

Questo insieme di documenti descrive la codebase di CyberMedic per il "brain"
dell'agente. Aggiornato in modo incrementale tramite harness e file temporanei
per evitare di superare i limiti strutturali.

Ultimo aggiornamento: 2026-10-23

## Indice

- `00-overview.md` — Visione d'insieme, stack tecnologico, entry point.
- `01-architecture.md` — Architettura Thin Client, moduli, contratti.
- `02-core.md` — Backend `CyberMedic_Core.ps1` e moduli `core\`.
- `03-gui.md` — Thin client `CyberMedic_GUI.ps1`, tema, splash, schede.
- `04-tabs.md` — Le 8 schede principali e le 5 schede interne.
- `05-modules.md` — Moduli backend e front-end, funzioni principali.
- `06-contracts.md` — Contratti Core→Client, `$script:Ui`, regole di robustezza.
- `07-testing.md` — SelfTest (38 controlli), SmokeTest (28 controlli).
- `08-deploy-install.md` — Deploy, rollback, installer.
- `09-winui3.md` — Scaffold WinUI 3 (in sviluppo).
- `10-history.md` — Storia delle versioni, decisioni tecniche, vincoli.
- `11-glossary.md` — Glossario dei termini tecnici e delle sigle.