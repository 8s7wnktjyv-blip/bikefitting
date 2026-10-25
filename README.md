# FitFrame – Bikefitting-Demo

Klickbare Demo einer Bikefitting-Software für Fahrradläden. Eine einzige Datei (`index.html`), ohne Server, ohne Kosten.

## Öffnen

- `index.html` im Browser öffnen (iPhone, iPad, Mac, PC).
- Alle Daten werden nur lokal im Browser gespeichert (`localStorage`). Sie sind unverschlüsselt und nicht auf anderen Geräten sichtbar.
- Die Beispielkunden sind erfunden. „Mehr → Demo zurücksetzen“ lädt sie neu.

## Ablauf eines Fittings

Jeder Schritt beginnt mit einer Übersicht und führt dann mit „eine Sache pro Bildschirm“ durch die Punkte.

1. **Ziel** – 7 Fragen mit vorgefertigten Antworten zum Antippen
2. **Körper** – optionaler Körper-Scan mit Kamera (Foto von vorn/Seite, Punkte antippen oder automatisch erkennen lassen) und 12 Tests mit Anleitung (Beinlänge, Becken, Kniespur, Fußgewölbe, Vorfuß, Beweglichkeit, Sitzknochen …). Die App wertet die Ergebnisse nach festen Regeln aus und schlägt einen Ausgleich vor dem Fitting vor (z. B. Shim, Einlage, Keil) oder empfiehlt eine Fachperson.
3. **Messen** – 5 Pflichtpunkte mit Skizze und Anleitung, Serienwerte (Vorbau, Lenker, Kurbel) automatisch vom Hersteller
4. **Anpassen** – bis zu 3 Vorschläge, Änderungen mit Begründung, optionale Fahr-Analyse mit Kamera
5. **Ergebnis** – Reiter für Vorher/Nachher, Rahmengröße, Datenqualität und Bericht (Drucken/PDF)

## Geometrie-Bibliothek

34 Modelle (Canyon, Giant, Rose und 24 Cube-Rahmenplattformen) mit allen Größen, am 25.10.2026 von den Herstellerseiten übernommen, jeweils mit Quellenlink. Beim Anlegen eines Fahrrads Modell und Größe wählen, die Geometrie wird übernommen. Eigene Modelle lassen sich ergänzen. Die Größenberatung berechnet näherungsweise (±10 mm) Vorbau und Spacer je Rahmengröße aus der gefitteten Position.

## Stand

| Bereich | Stand |
|---|---|
| Kunden, Fahrräder, Fitting, Körpercheck, Verlauf, Nachkontrollen, Werkstatt, Lager | funktioniert, lokal gespeichert |
| Auswertung Körpercheck, Vorschläge, Datenqualität | regelbasiert (Faustregeln, nicht validiert) |
| Kamera (Körper-Scan, Fahr-Analyse) | Punkte antippen funktioniert; automatische Erkennung mit Google MediaPipe (Beta, braucht Internet, nicht getestet) |
| Bewegungssimulation | simuliert aus eingetragenen Körpermaßen |
| Schreibhilfe („KI“) | Textvorlagen, kein Sprachmodell |
| Kundenportal, Kapazität, Kennzahlen | Vorschau mit Demo-Daten |
| Hardware Lab, Team, Flotten, Anbindungen | Konzept |

FitFrame stellt keine Diagnosen. Alle Zahlen und Faustregeln sind Demonstrationswerte.

## Fehlt für eine echte Version

- Backend mit Anmeldung, Rollen, Trennung zwischen Betrieben
- EU-Hosting, Verschlüsselung, Backup, Export und Löschung (DSGVO)
- PDF-Bericht, E-Mail/SMS
- Echte Videoanalyse mit Kalibrierung
- Gedruckte und getestete Hardware
- Prüfung der Abläufe und Faustregeln mit erfahrenen Bikefittern
