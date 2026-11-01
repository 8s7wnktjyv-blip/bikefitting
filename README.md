# FYF – Fit your Frame – Bikefitting-Demo

Klickbare Demo einer Bikefitting-Software für Fahrradläden. Eine einzige Datei (`index.html`), ohne Server, ohne Kosten.

## Öffnen

- `index.html` im Browser öffnen (iPhone, iPad, Mac, PC).
- Alle Daten werden nur lokal im Browser gespeichert (`localStorage`). Sie sind unverschlüsselt und nicht auf anderen Geräten sichtbar.
- Die Beispielkunden sind erfunden. „Mehr → Demo zurücksetzen“ lädt sie neu.

## Aufbau (ab v.42)

- Menü in 10 Bereichen: Dashboard, Kunden, Bikefitting, Körperanalyse, Bike-Vermessung, Bewegungsanalyse, Produktempfehlungen, Berichte, Datenbanken, Einstellungen.
- Dashboard: Kennzahlen, Schnellaktionen, letzte Fittings, zuletzt bearbeitete Kunden, Aktivitäten. Das Diagramm erscheint erst ab 3 abgeschlossenen Fittings, nur mit echten Daten.
- Neue Übersichten: Körperanalyse (je Kunde), Bike-Vermessung (aktuelle Werte je Rad), Berichte (Filter und Suche).
- Löschen braucht zwei Klicks („Wirklich löschen?“). Größere Bedienelemente auf Touch-Geräten.

## Kunden- und Fahrradakte (ab v.43)

- Kunde: Geburtsdatum (mit Alter), Gewicht, Trainingsstunden pro Woche, Kilometer pro Jahr, Ziele/Hinweise. Werte außerhalb plausibler Grenzen werden abgelehnt.
- Produktkäufe je Kunde erfassen (Artikel, Betrag, Datum, Rad, Status), mit Summe.
- Fahrrad: Komponenten (Material, Schaltgruppe, Kurbel, Lenker, Vorbau, Sattel, Sattelbreite, Stütze, Cleats). Leere Felder bleiben leer; Kurbel, Lenker und Vorbau werden sonst aus dem letzten Fitting angezeigt und so gekennzeichnet.
- Kundenakte in 8 Tabs (ab v.44): Übersicht, Persönliche Daten, Körperanalyse, Fahrräder, Fitting-Historie, Produkte, Dokumente, Nachkontrollen.
- Körperanalyse (ab v.44):
  - Sitzknochen mit bis zu 3 Einzelmessungen, Methode und Sitzhaltung. FYF bildet den Mittelwert; bei mehr als 5 mm Streuung erscheint ein Hinweis. Verlauf über alle Sitzungen.
  - Füße links/rechts: Länge, Breite, Gewölbe, Vorfuß, Fußstellung, Kniespur.
  - Neue Tests: Fußbreite, Fußstellung, Beinachse, Hüftrotation, Rumpfstabilität, Einbeinstand – jeweils mit Anleitung und Skizze.
  - Jeder Auswahl-Test hat „nicht eindeutig“; das fließt nicht in die Auswertung ein.
  - Messwert, Beobachtung und Einschätzung des Fitters werden getrennt gespeichert und angezeigt. Hinweise von FYF sind Faustregeln, keine Diagnose.
- Fotos und Videos je Kunde und je Rad. Nur mit eigener Einwilligung für Fotos/Videos. Gespeichert nur auf dem Gerät (IndexedDB, Fotos bis 15 MB, Videos bis 80 MB), nicht in der Text-Sicherung.

## Geführter Ablauf und Vorlagen (ab v.45)

- Im Fitting oben: „Geführter Ablauf“ mit 12 Schritten (Kunde und Fahrrad, Ziele, Körperanalyse, Sitzknochen, Körpermaße, Beweglichkeit, Fahrrad vermessen, Bewegungsanalyse, Anpassungen, Produktempfehlungen, Abschluss, Bericht).
- Fortschritt, erledigt/offen/übersprungen, „Öffnen“ springt direkt zum Schritt, „Überspringen“ und „Nachholen“.
- Notizen während des Termins mit Uhrzeit; frühere Daten des Kunden (letztes Fitting, Werte, Bericht) direkt im Ablauf.
- Pflichtangaben (Ziele, Körpermaße, Fahrrad vermessen): Beim Abschließen erscheint eine Warnung. Trotzdem abschließen wird protokolliert.
- Vorlagen Rennrad, Gravel, MTB, Triathlon, Trekking, Allroad: legen fest, welche Tests vorgeschlagen werden, je Fitting anpassbar. Berechnungen ändern sich dadurch nicht.

## Fahrradgrafik, Änderungsprotokoll, Messmittel, Prüfung (ab v.46)

- Fahrradgrafik (im Schritt „Anpassen“ und unter Bike-Vermessung → „Grafik“): Sattel, Stütze, Lenker, Vorbau, Steuerrohr, Tretlager, Kurbeln, Pedale, Cleats antippen; Werte vorher/nachher; Vorher-Position gestrichelt. **Schematisch, nicht maßstäblich** – verbindlich sind nur die Zahlen.
- Änderungsprotokoll: je Änderung wer, wann, warum und Bewertung (noch offen / Kunde: besser, gleich, schlechter); Balkengrafik der Summe je Einstellung.
- Messmittel (Datenbanken → Messmittel): Bezeichnung, Art, Hersteller, Modell, Methode, Genauigkeit nur laut Hersteller mit Quelle, Kalibrier- und Prüfdatum. Zuordnung zur Sitzung im Schritt „Messen“.
- Prüfung der Daten: zusätzlich fehlende Messmethode, Änderungen ohne Begründung oder ohne Protokolleintrag, Unterschied Fußlänge links/rechts, vermutlich falsche Einheit, nicht dokumentierte Messmittel. Der Fitter kann jeden Hinweis als „korrekt“ bestätigen; FYF ändert keine Werte.

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

- Kundenakte → „Stammdaten bearbeiten“ (Name, E-Mail, Telefon, Disziplin) und Fahrradakte → „Fahrraddaten bearbeiten“ (Marke, Modell, Typ, Größe, Pedal, Rahmennummer, Baujahr). Verknüpfte Fittings und Aufträge bleiben erhalten, jede Änderung steht im Audit-Protokoll.
- Mehr → Dein Laden: Name, Adresse, Logo für Bericht und Einwilligung
- Mehr → Zahlen: Fittings pro Monat, häufigste Beschwerden, CSV-Export aller Fittings
- Mehr → Einstellungen: Werkstatt, Lager, Kundenportal, Team und Hardware Lab ein- oder ausblenden (Standard: ausgeblendet); Beispielkunden entfernen, ohne eigene Einträge zu löschen

## Geometrie-Bibliothek

34 Modelle (Canyon, Giant, Rose und 24 Cube-Rahmenplattformen) mit allen Größen, am 25.10.2026 von den Herstellerseiten übernommen, jeweils mit Quellenlink. Beim Anlegen eines Fahrrads Modell und Größe wählen, die Geometrie wird übernommen. Eigene Modelle lassen sich ergänzen. Die Größenberatung berechnet näherungsweise (±10 mm) Vorbau und Spacer je Rahmengröße aus der gefitteten Position.

## Genauigkeit und Übertragung

- **Sattelhöhe:** Pflicht-Messpunkt „Kniewinkel unten“ (Goniometer, zwei Messungen, Toleranz 2°). Daraus rechnet FYF die Millimeter über ein Beinmodell (Schrittlänge, Kurbel) und schlägt Änderungen in Schritten von höchstens 5 mm vor; nach jeder Änderung wird der Kniewinkel neu gemessen, bis er im Zielbereich liegt. Ohne Kniewinkel gibt es nur einen Startwert aus dem Beinmodell. Video-Werte werden als Kontrolle neben dem Goniometer gespeichert (Warnung ab 5° Abweichung). Simulierte Kniewinkel lösen nie eine Änderung aus. Becken-Kippen von vorn über 5° fließt als Hinweis „Sattel eher zu hoch“ ein.
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

FYF – Fit your Frame stellt keine Diagnosen. Alle Zahlen und Faustregeln sind Demonstrationswerte.

## Fehlt für eine echte Version

- Backend mit Anmeldung, Rollen, Trennung zwischen Betrieben
- EU-Hosting, Verschlüsselung, Backup, Export und Löschung (DSGVO)
- E-Mail/SMS-Versand
- Echte Videoanalyse mit Kalibrierung
- Gedruckte und getestete Hardware
- Prüfung der Abläufe und Faustregeln mit erfahrenen Bikefittern
