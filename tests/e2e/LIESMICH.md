# Browser-Tests

Prüfen die wichtigsten Abläufe in iPhone-Größe gegen `mock.js` (Nachbau der Datenbank, keine echten Daten):

- `t118p.js` – Pass: Zustandsbericht antippen öffnet das passende Fenster, Kettenmessung zählt
- `t118d.js` – Kalender: Termin → Kunde, Kundenakte, Woche/Liste/Monat, Abo-Link, .ics, Anfragen
- `t121.js` – Mahnwesen, Kontoauszug-Abgleich, Arbeitszeit, Leihrad
- `t123.js` – Cockpit-Vergleich (Rechnung und Ansicht)
- `t127.js` – Feste Demodaten: Dominiks Grail mit SPD, vorhandene Werte bleiben erhalten
- `t128.js` – Rollen Werkstattleitung, Verkauf, Filialleitung, Buchhaltung: Auswahl ab DB-Stand 26, Server-Filter je Rolle, nichts geht verloren
- `t129.js` – Kündigung: Plattform-Admin schließt Laden, Ex-Mitglied sieht „Zugang beendet“ und kann Daten sichern, Wieder öffnen
- `t130.js` – Werkstatt-Tafel: Spalten, Weiter, Teile sind da, Auftrag öffnen, Zurück (iPhone und großer Bildschirm)
- `t131.js` – Saison-Check: Liste nur mit Einwilligung, Nachricht, Erledigt, CSV; Pass-Knopf zum eigenen Laden; Finder übernimmt fällige Punkte
- `t133.js` – Ersatzrad: Pass-Knopf nur während der Reparatur beim eigenen Laden, Finder-Text, Hinweis mit freien Leihrädern in der Software
- `t134.js` – Bestellvorschlag zieht offene Bestellungen ab, keine Doppelbestellung, Teillieferung
- `t135.js` – Termin im Pass: freie Termine des eigenen Ladens bei fälliger Wartung, Finder wählt Termin vor, Hinweis wenn vergeben
- `t136.js` – Hol- und Bringservice: im Auftrag eintragen, Tagesliste mit Karte und Anruf, Erledigt, Tag wechseln, Zurück
- `t137.js` – Import aus altem System: Sicherung vorher, „Import rückgängig“
- `t138.js` – Käufer-Link: erstellen im Verkaufswerkzeug, Käufer-Ansicht, Zurückziehen
- `t139.js` – Pass auf Englisch (Stufe 1): Umschalten, Garage, Radseite, Service, Diebstahl, Teile, Belege ohne deutsche Reste, zurück auf Deutsch
- `t140.js` – Kalender mit Zeitraster (Desktop), freie Fläche → Termin, Schnellauswahl im Formular, Handy-Tageskarten
- `t142.js` – Pass: Wert-Schätzung und Diebstahlschutz-Check oben bei „Mein Rad“, Preis geht in „Verkaufen“
- `t144.js` – Pass: Zustand der Teile (Ampel), Schäden & Unfälle (nicht löschbar, Status-Verlauf), Tracker-Link, Umbau planen (Kosten/Gewicht)
- `t145.js` – Pass: Zustandsbericht-Urteil (Wartungsstau, Risiko, fast verkaufsbereit) und Kopf in „Verkaufen“
- `t147.js` – Software: Dashboard-Reihenfolge je Ladentyp (Werkstatt: Aufmerksamkeit zuerst), eigene Anpassung hat Vorrang
- `t148.js` – Software: Verlauf & Vergleich mit überlagerter Seitenansicht A/B und Differenzen
- `t150.js` – Pass: Jahresziel (Fortschritt aus km-Verlauf), Abzeichen, Kachel aktualisiert sich
- `t151.js` – Software: Kundenakte mit Kennzahlen-Kopf, eingeklappter Wiedervorlage, Zeitleiste mit Filter (Klick öffnet Fitting)
- `t152.js` – Pass: Rad-Karte als Bild (1080×1350, JPG), Knopf auch auf der Ziel-Seite
- `t153.js` – Software: Werkstatt-Tafel per Ziehen (nur erlaubte Schritte, Wartet auf Teile hin und zurück, kein Rücksprung)
- `t154.js` – Pass: Tour-Check (Knopf erst nach allen Haken, Eintrag gespeichert)
- `t155.js` – Software: Fitting-Bericht im neuen Stil mit Skizze vorher/nachher
- `t156.js` – Software: Live-Skizze im Fitting-Schritt „Anpassen“ aktualisiert sich bei Änderung
- `t157.js` – Pass: Wartungsplan je nach Teilen (12-fach, SRAM/Shimano-Bremse, Carbon)
- `t158.js` – Software: Rahmen-Finder-Kurzkarte im Fitting-Ergebnis, Knopf öffnet Reiter Größe & Sattel
- `t159.js` – Pass: Verkauf in 5 Schritten (Zähler und Speicherung)
- `t160.js` – Pass und Software offline (eigenes Rad ohne frühere Online-Ansicht, kein Diebstahl-Status offline)
- `t161.js` – Englisch Stufe 2/3: Händlerfinder englisch, neue Pass-Seiten englisch, Rückschalten auf Deutsch
- `t162.js` – Pass: Umbau planen mit Kompatibilitäts-Hinweisen (Fachzahl, Marke)
- `t163.js` – Pass: ein Eingang für Schäden/Unfälle, Unfall-Eintrag nur als Fehleintrag markierbar

Läuft automatisch bei jedem Push (GitHub → Actions → „Tests“). Lokal: `sh tests/e2e/run.sh`.
