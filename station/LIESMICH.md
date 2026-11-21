# FYF Station (M5Stack Tab5)

Firmware für das Tab5 als Mess-Station beim Bikefitting. Aktuelle Version: **v0.4.6** (21.11.2026).

- `FYF_Station/FYF_Station.ino` – Hauptprogramm (Arduino IDE, Board „M5Tab5“)
- `KICKR_Test/KICKR_Test.ino` – Test der Rollen-Verbindung
- `ANLEITUNG.md` – Neuerungen je Version, Bedienung, Hochladen

Fertige ZIP-Datei zum Herunterladen: GitHub → Releases → „FYF Station v0.4.6“.

**Status:** am Rechner getestet, auf dem Tab5 noch nicht. Enthält keine Passwörter: WLAN-Zugang und FYF-Kopplung werden erst am Gerät eingegeben und nur dort gespeichert. Der eingetragene FYF-Schlüssel ist der öffentliche „publishable“ Schlüssel (steht auch in der Web-App).

Zusammenspiel mit der FYF-App: Fitting → „Werte vom Tab5 holen“ → „Übernehmen“ (ab App v.126 inkl. Einwilligung mit Unterschrift).
