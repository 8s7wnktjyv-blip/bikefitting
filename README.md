# FitFrame – Bikefitting-Demo

Klickbare Demo einer Bikefitting-Software für Fahrradläden. Eine einzige Datei (`index.html`), ohne Server, ohne Kosten.

## Öffnen

- `index.html` im Browser öffnen (iPhone, iPad, Mac, PC).
- Alle Daten werden nur lokal im Browser gespeichert (`localStorage`). Sie sind unverschlüsselt und nicht auf anderen Geräten sichtbar.
- Die Beispielkunden sind erfunden. „Mehr → Demo zurücksetzen“ lädt sie neu.

## Ablauf eines Fittings

1. **Ziel** – Anamnese, Beschwerden, Wünsche
2. **Körpercheck** – 11 Tests mit Anleitung (Beinlänge, Becken, Kniespur, Fußgewölbe, Vorfuß, Beweglichkeit, Sitzknochen …). Die App wertet die Ergebnisse nach festen Regeln aus und schlägt einen Ausgleich vor dem Fitting vor (z. B. Shim, Einlage, Keil) oder empfiehlt eine Fachperson.
3. **Ausgangsposition** – jeder Messpunkt mit „So misst du“-Anleitung, Methode und Genauigkeit
4. **Anpassen** – Vorschläge aus Beschwerden, Körpercheck und Kniewinkel; jede Änderung mit Begründung
5. **Ergebnis & Bericht** – Vorher/Nachher, Datenqualität, Bericht, Freigabe im Kundenportal

## Stand

| Bereich | Stand |
|---|---|
| Kunden, Fahrräder, Fitting, Körpercheck, Verlauf, Nachkontrollen, Werkstatt, Lager | funktioniert, lokal gespeichert |
| Auswertung Körpercheck, Vorschläge, Datenqualität | regelbasiert (Faustregeln, nicht validiert) |
| Bewegungsanalyse | simuliert aus eingetragenen Körpermaßen, keine Kamera |
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
