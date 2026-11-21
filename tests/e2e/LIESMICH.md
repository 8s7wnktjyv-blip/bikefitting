# Browser-Tests

Prüfen die wichtigsten Abläufe in iPhone-Größe gegen `mock.js` (Nachbau der Datenbank, keine echten Daten):

- `t118p.js` – Pass: Zustandsbericht antippen öffnet das passende Fenster, Kettenmessung zählt
- `t118d.js` – Kalender: Termin → Kunde, Kundenakte, Woche/Liste/Monat, Abo-Link, .ics, Anfragen
- `t121.js` – Mahnwesen, Kontoauszug-Abgleich, Arbeitszeit, Leihrad
- `t123.js` – Cockpit-Vergleich (Rechnung und Ansicht)
- `t127.js` – Feste Demodaten: Dominiks Grail mit SPD, vorhandene Werte bleiben erhalten
- `t128.js` – Rollen Werkstattleitung, Verkauf, Filialleitung, Buchhaltung: Auswahl ab DB-Stand 26, Server-Filter je Rolle, nichts geht verloren
- `t129.js` – Kündigung: Plattform-Admin schließt Laden, Ex-Mitglied sieht „Zugang beendet“ und kann Daten sichern, Wieder öffnen

Läuft automatisch bei jedem Push (GitHub → Actions → „Tests“). Lokal: `sh tests/e2e/run.sh`.
