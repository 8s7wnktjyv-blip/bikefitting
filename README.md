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
4. **Anpassen** – bis zu 3 Vorschläge mit Millimeter-Empfehlung (Wert wird vorausgefüllt), Änderungen mit Begründung, optionale Fahr-Analyse mit Kamera
5. **Ergebnis** – Reiter für Vorher/Nachher, Größe & Teile (Rahmengröße, Rahmen-Finder über die ganze Bibliothek, Sattelbreite, Schuhgröße), Datenqualität und Bericht (Drucken/PDF, Teilen, mit Logo und Ladendaten)

## Live-Analyse (Beta)

Kamera seitlich aufs Rad richten: Google MediaPipe erkennt Schulter, Hüfte, Knie, Knöchel und Fuß, zählt die Kurbelumdrehungen und bildet den Mittelwert über 30 Umdrehungen für Kniewinkel unten, Hüftwinkel, Oberkörperwinkel und Knielot. Das Knielot wird über die Kurbellänge in Millimeter umgerechnet (etwa ±10 mm). Aus dem Kniewinkel berechnet ein Körpermodell die empfohlene Änderung der Sattelhöhe in mm. Geht auch mit einem aufgenommenen Video („Ganzes Video auswerten“).

## Weitere Funktionen

- Mehr → Dein Laden: Name, Adresse, Logo für Bericht und Einwilligung
- Mehr → Zahlen: Fittings pro Monat, häufigste Beschwerden, CSV-Export aller Fittings
- Mehr → Einstellungen: Werkstatt, Lager, Kundenportal, Team und Hardware Lab ein- oder ausblenden (Standard: ausgeblendet); Beispielkunden entfernen, ohne eigene Einträge zu löschen

## Geometrie-Bibliothek

34 Modelle (Canyon, Giant, Rose und 24 Cube-Rahmenplattformen) mit allen Größen, am 25.10.2026 von den Herstellerseiten übernommen, jeweils mit Quellenlink. Beim Anlegen eines Fahrrads Modell und Größe wählen, die Geometrie wird übernommen. Eigene Modelle lassen sich ergänzen. Die Größenberatung berechnet näherungsweise (±10 mm) Vorbau und Spacer je Rahmengröße aus der gefitteten Position.

## Genauigkeit und Übertragung

- Jeder Messwert mit Kontrollmessung: Weichen beide mehr als 3 mm bzw. 1° ab, verlangt die App eine dritte Messung und speichert den Mittelwert.
- 15 Messpunkte in drei Gruppen, davon 6 Koordinaten vom Tretlager (Höhen über Boden, Abstände vor dem Lot). Sie prüfen die anderen Werte gegen und erlauben die 1:1-Übertragung auf ein anderes Rad (Ergebnis → „Auf neues Rad“).
- Geführte Anpassung: eine Karte pro Änderung mit Ampel, Zielwert, am Rad machbarem Wert, Anleitung, Drehmoment-Hinweis, Kontrolle und Rückmeldung. Spacer, Vorbauwinkel und Vorbaulänge werden beim Umsetzen mit eingetragen.
- Fuß-Auswertung (Einlage, Keil, Unterlegplatte), Cockpit-Empfehlung (Vorbau, Lenker, Lenker-Vorbau-Einheiten), Oberkante Schalthebel über Boden.
- End-to-End-Test: Kunde anlegen, Rad aus Bibliothek, Ziel, Körpercheck, 15 Messungen mit Kontrollmessung, geführte Anpassung, Ergebnis, Bericht, Übertragung – ohne Fehler (Chromium, Handygröße).

## Stand

| Bereich | Stand |
|---|---|
| Kunden, Fahrräder, Fitting, Körpercheck, Verlauf, Nachkontrollen, Werkstatt, Lager | funktioniert, lokal gespeichert |
| Auswertung Körpercheck, Vorschläge, Datenqualität | regelbasiert (Faustregeln, nicht validiert) |
| Kamera (Körper-Scan, Fahr-Analyse) | Punkte antippen funktioniert; automatische Erkennung und Live-Analyse mit Google MediaPipe (Beta, braucht Internet, mit echter Kamera nicht getestet; Rechenweg mit simulierter Bewegung getestet) |
| mm-Empfehlung Sattelhöhe, Sattelbreite, Schuhgröße | Faustregeln und Körpermodell, nicht validiert |
| Bewegungssimulation | simuliert aus eingetragenen Körpermaßen |
| Schreibhilfe („KI“) | Textvorlagen, kein Sprachmodell |
| Kundenportal, Kapazität, Kennzahlen | Vorschau mit Demo-Daten |
| Hardware Lab, Team, Flotten, Anbindungen | Konzept |

FitFrame stellt keine Diagnosen. Alle Zahlen und Faustregeln sind Demonstrationswerte.

## Fehlt für eine echte Version

- Backend mit Anmeldung, Rollen, Trennung zwischen Betrieben
- EU-Hosting, Verschlüsselung, Backup, Export und Löschung (DSGVO)
- E-Mail/SMS-Versand
- Echte Videoanalyse mit Kalibrierung
- Gedruckte und getestete Hardware
- Prüfung der Abläufe und Faustregeln mit erfahrenen Bikefittern
