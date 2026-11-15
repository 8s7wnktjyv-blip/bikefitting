# Bericht: Master-Prompt Bike Pass + Master-Prompt Händlersoftware

Stand: 15.11.2026 · Version Händlersoftware 2026-11-15.102 · Pass-App Cache p18 · Commit b44fb6e

Ehrlich getrennt: **fertig und getestet** / **vorbereitet, aber nicht verbunden** / **fehlt**.
Getestet heißt: automatisch im Testbrowser (iPhone-13-Größe) mit Test-Server. Auf deinem echten iPhone ist es noch nicht geprüft.

---

## 1. Fahrradpass (rad.html)

### Fertig und getestet (neu in dieser Runde)
| Funktion | Wo | Hinweis |
|---|---|---|
| Verkaufsunterlage als PDF | Rad → Verkaufen → „Verkaufsunterlage erstellen“ | Foto, Eckdaten, Ausstattung (Quelle Werkstatt/Serie), Service mit „werkstattbestätigt“ / „selbst eingetragen“, gemessener Verschleiß, Umbauten mit km, Belege (Beträge und Belegfotos nur auf Wunsch), E-Akku, QR zum Pass, Datenschutz-Hinweis. Drucken → „Als PDF sichern“ geht auf dem iPhone über das Teilen-Menü. |
| Laufleistung je Teil | Rad → Ausstattung | km-Stand beim Einbau wird fest gespeichert. Beim Umbau steht „ausgebautes Teil lief X km“. Bei Teil-Umzug auf ein anderes Rad werden die km mitgenommen. |
| Kilometer-Verlauf + km pro Jahr | Rad → Service | Aus jedem gespeicherten km-Stand. |
| Strava-Import | Rad → Service → Kilometer → „Strava: Fahrten importieren“ | Datei activities.csv aus dem Strava-Datenexport. Doppelte Fahrten werden erkannt, Rolle (virtuell) und Laufen zählen nicht. Ausrüstung wählbar, Startwert möglich. |
| Verschleiß-Messungen | Rad → Service | Nur echte Messungen (Kettenlehre, Messschieber, Werkstatt). Keine geschätzte Anzeige. |
| Kosten | Neue Kachel „Kosten“ | Gesamt, pro Monat, pro km, laufende Kosten ohne Kaufpreis, nach Art und Jahr. Quelle: Belege mit Betrag. |
| Setups (Sommer/Winter) | Rad → Ausstattung → Setups | Speichern, Unterschiede sehen, übernehmen (landet im Verlauf). |
| Rückrufe prüfen | Rad → Belege | Link EU Safety Gate + Suche „Marke Rückruf“, Vermerk „geprüft am“. |
| Werkstattfoto im Pass | Foto oben am Rad | Hat der Kunde selbst kein Foto, wird das Foto aus der Werkstatt gezeigt. |
| Weitere Belegarten | Belege | Zubehör, Bikefitting, Reparatur (privat). |

### Vorbereitet, aber nicht verbunden
- **Strava direkt (automatisch):** nicht verbunden. Braucht einen eigenen Server und eine App-Freigabe bei Strava. Jetzt geht nur der Datei-Import.
- **E-Bike-Daten direkt (Bosch, Shimano, Yamaha, Brose):** nicht verbunden. Die Hersteller geben dafür keine offene Schnittstelle frei. Akku-Werte werden von Hand oder von der Werkstatt eingetragen.
- **Rückruf-Datenbank:** FYF hat keine eigene und meldet nichts automatisch. Es gibt nur die Links.
- **Verkaufsplattformen (buycycle, Kleinanzeigen):** nicht angebunden. Die Verkaufsanzeige wird als Text erstellt und von Hand eingefügt.

---

## 2. Händlersoftware (index.html)

### Fertig und getestet (neu in dieser Runde)
| Funktion | Wo |
|---|---|
| Tarif Standard 99 € / Professional 149 € (je Betrieb) | Betrieb → Ladenart. Bei Standard ist das Fitting-Modul gesperrt. |
| **Neurad verkaufen** | **Fahrräder → „Neurad verkaufen“** oder Kachel im Dashboard. Kunde (neu oder vorhanden) + Rad mit Kaufdatum und Preis → Rechnung öffnet sich vorausgefüllt → Rechnung wird mit dem Rad verknüpft. Danach in der Fahrradakte den Pass ausstellen. |
| Fahrradfoto | Fahrradakte → Foto. Wird auch im Pass des Kunden gezeigt (kleine Version). |
| Fahrradakte als Verkaufsunterlage | Fahrradakte → „Verkaufsunterlage“ (werkstattbestätigt). |
| Werkstatt: Status „Wartet auf Teile“, Stornieren / Wieder öffnen | Auftrag öffnen. |
| Abschlusskontrolle (Checkliste) | Auftrag. Fehlt etwas, kommt beim Abschließen eine Warnung. |
| Arbeitszeit-Timer | Auftrag → Start/Stopp. Zeit wird auf 0,25 h gerundet als Position übernommen. |
| Lagerbuchung | Teil aus dem Lager in den Auftrag → Bestand sinkt. Löschen oder Storno → Bestand kommt zurück. |
| Hinweis auf neue Anfragen | Dashboard. |

### Nicht verbunden / fehlt
- Online-Zahlung, Kassensystem (TSE) und DATEV-Export: nicht angebunden.
- Abrechnung direkt mit Leasinganbietern: nicht angebunden. Es gibt nur die Angabe, mit wem der Laden abrechnet, und die Links zur offiziellen Händlersuche.
- Bezahlung des Tarifs (99/149 €): nur Anzeige und Freischaltung in der App, keine echte Abrechnung.

---

## 3. Prüfungen
- Gesamtprüfung Händlersoftware: 41 von 41 Punkten ok.
- Alle 33 Bereiche geöffnet: keine toten Knöpfe, kein Querscrollen auf dem Handy, keine JS-Fehler.
- 560 Klicks automatisch: keine Fehler.
- Einzeltests ohne Fehler: Tarif/Werkstatt/Lager/Neurad/Foto (v.101), Pass v.102 (Laufleistung 2.500 km korrekt, Strava 2 von 4 Fahrten gezählt, doppelt importiert = keine Änderung, Kosten 1.289,90 €, Setup übernommen, Verkaufsunterlage mit allen Abschnitten), Leasing, Teile, Umbau, Zustandsbericht, Sichtbarkeit, Shop, Dashboard, Rahmennummer, Übernahme.
- Zwei alte Testskripte waren fehlerhaft, nicht die App. Sie wurden korrigiert.

## 4. Veröffentlicht
- Gepusht auf `master-auftrag` und `main` (GitHub Pages). Der Cache wurde auf p18 erhöht, damit iPhones die neue Version laden.
- Kein kostenpflichtiger Dienst wurde eingeschaltet.

## 5. Nächster Schritt für dich (auf dem iPhone)
Die Pass-App öffnen und einmal schließen/neu laden. Dann an einem Rad: **Verkaufen → Verkaufsunterlage erstellen** und prüfen, ob das PDF so passt.
