# lafl_lib extras – replacement folders

Replacement resources with the same name, exports and events as the originals of your framework.
They show notify, text UI and progress bar of **all** scripts in the LAFL design – no script has to be changed.

- `esx/` – only for ESX: `esx_notify`, `esx_textui`, `esx_progressbar`. Delete it if you use QBCore.
- `qb/` – only for QBCore: `progressbar`. Delete it if you use ESX.

Replace the original folders in your `resources` with these, start them **after** `lafl_lib`,
and keep `LibConfig.Notify` / `Progress` / `TextUI` on `'lafl'`.
Full guide: `lafl_lib/README.md` → "LAFL design for ALL scripts".

---

# lafl_lib extras – Ersatz-Ordner

Ersatz-Ressourcen mit demselben Namen, denselben Exports und Events wie die Originale deines Frameworks.
Sie zeigen Notify, Text-UI und Fortschrittsbalken **aller** Skripte im LAFL-Design – kein Skript muss geändert werden.

- `esx/` – nur für ESX: `esx_notify`, `esx_textui`, `esx_progressbar`. Löschen, wenn du QBCore nutzt.
- `qb/` – nur für QBCore: `progressbar`. Löschen, wenn du ESX nutzt.

Die Original-Ordner in deinen `resources` durch diese ersetzen, **nach** `lafl_lib` starten
und `LibConfig.Notify` / `Progress` / `TextUI` auf `'lafl'` lassen.
Ganze Anleitung: `lafl_lib/README.de.md` → „LAFL-Design für ALLE Skripte“.
