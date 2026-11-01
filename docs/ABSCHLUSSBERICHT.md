# FYF – Fit your Frame · Abschlussbericht Weiterentwicklung

Stand: 01.11.2026 · Version **v.52** (`2026-11-01.52`) · Repo: bikefitting · Demo: https://8s7wnktjyv-blip.github.io/bikefitting/

## Kurzfassung
- Alle 11 Phasen sind umgesetzt, getestet und ins Repo **bikefitting** hochgeladen (v.42 bis v.52). Andere Repos wurden nicht verändert.
- **Praxistest:** 14 Schritte mit einem fiktiven Testkunden, am Handy-, Tablet- und PC-Format. Je 22 von 22 Prüfungen bestanden.
- **Alle älteren Prüfungen bestehen weiter:** 41 Prüfungen je Format und 19 Prüfungen zur Sattelhöhe.
- **Daten:** Bestehende Daten bleiben erhalten, auch die von Dominik Böhm. Vor jedem Update entsteht automatisch eine Sicherung.
- **Was ich nicht testen konnte:** echte Geräte, Kamera, Videos abspielen, Drucken auf dem iPhone. Das musst du selbst prüfen.

---

## 1. Übersicht aller Änderungen

| Version | Phase | Inhalt |
|---|---|---|
| v.42 | 1 Navigation & Design | Menü in 10 Bereichen, Dashboard mit echten Kennzahlen, Übersichten Körperanalyse/Bike-Vermessung/Berichte, Löschen mit 2 Klicks, größere Bedienelemente |
| v.43 | 2 Kunden- und Fahrradakte | Geburtsdatum, Gewicht, Fahrprofil, Ziele; Produktkäufe; Rad-Komponenten; Fotos/Videos mit eigener Einwilligung |
| v.44 | 3 Kundenakte & Körperanalyse | Kundenakte mit 8 Tabs; Sitzknochen mit bis zu 3 Messungen; Füße links/rechts; 6 neue Tests; „nicht eindeutig“; Messwert, Beobachtung und Einschätzung getrennt |
| v.45 | 4 Geführter Ablauf | 12 Schritte, Fortschritt, überspringen und nachholen, Notizen im Termin, frühere Daten, Warnung bei Pflichtangaben, Vorlagen je Radtyp |
| v.46 | 5 Vermessung | Schematische Fahrradgrafik, Änderungsprotokoll mit wer/wann/warum/Bewertung und Grafik, Messmittelverwaltung, erweiterte Plausibilitätsprüfung |
| v.47 | 6 Vergleich & Feedback | Vergleich zweier Sitzungen eines Kunden mit Diagramm und Fotos; Feedback mit 7 Fragen; frei wählbare Nachkontrollen; Fotos, Videos und Standbilder je Sitzung |
| v.48 | 7 Bericht | Bericht mit 16 nummerierten Abschnitten, nur aus echten Daten, als PDF druckbar |
| v.49 | 8 Produkte & Wissen | Produktdatenbank mit belegten Herstellerdaten und Marge; Empfehlungen mit Begründung annehmen/ablehnen; Wissensbereich |
| v.50 | 9 Datenschutz & Technik | Rollen, Portal-Freigabe je Inhalt, Auskunft und Löschen, Datenschicht, Supabase-Schema (nur vorbereitet) |
| v.51 | 10 Design | Größere Bedienelemente am Tablet, Auswahlfelder, Tabellen, Fokus-Rahmen, weniger Bewegung, wenn im Gerät eingestellt |
| v.52 | 11 Praxistest | Test mit 14 Schritten; behoben: Komponenten aus der Fahrradakte werden ins Fitting übernommen |

## 2. Unverändert gebliebene Funktionen

Diese Funktionen funktionieren weiter. Sie wurden höchstens neu einsortiert oder ergänzt.

- **Fitting:**
  - Ablauf Ziel → Körper → Messen → Anpassen → Ergebnis
  - Doppelmessung und Mittelwert
  - geführter Anpassungsplan mit Teilen (Spacer, Vorbau, Cockpit)
- **Sattelhöhe:**
  - Methode mit Kniewinkel und Beinmodell (v.41)
  - weiterhin keine Änderung allein aus der Schrittlänge
- **Füße:** Fuß-, Keil- und Unterlegplatten-Logik, Schalthebelhöhe, Simulator, Rollentrainer-Anleitung.
- **Kamera:** Live-Analyse (Beta), Video von vorn, Körper-Scan.
- **Weitere Bereiche:**
  - Geometrie-Bibliothek und Neurad-Suche
  - Fit-Pass
  - Angebot, Lager, Werkstatt
  - Schreibhilfe
  - Kennzahlen, Team
  - Hardware Lab
- **Daten:** Sicherung als Datei und als Text, Import, „Beispielkunden entfernen“, „Demo zurücksetzen“.

## 3. Neu umgesetzte Funktionen

| Bereich | Neu |
|---|---|
| Navigation | 10 Bereiche; neu unter Datenbanken: Messmittel, Produktdatenbank, Wissen |
| Dashboard | Kennzahlen, letzte Fittings, Diagramm erst ab 3 echten Fittings, Aktivitäten |
| Kundenakte | 8 Tabs, Fahrprofil, Käufe, Dokumente (Berichte + Medien), Nachkontrollen, Export, Löschen |
| Fahrradakte | Komponenten, Fotos/Videos, Fahrradgrafik |
| Körperanalyse | 18 Tests (6 neu), Sitzknochen-Verlauf, Füße L/R, getrennte Beobachtung/Einschätzung |
| Fitting | 12-Schritte-Ablauf, Vorlagen, Notizen, frühere Daten, Pflicht-Warnung |
| Vermessung | Grafik, Änderungsprotokoll, Messmittel, Prüfhinweise mit „Ist korrekt“ |
| Vergleich | Je Kunde, Diagramm, Körper/Beschwerden/Feedback, Fotos |
| Feedback | 7 Fragen, beim Fitting und bei der Nachkontrolle |
| Bericht | 16 Abschnitte, Unterschriftsfeld, PDF |
| Produkte | Fachdaten mit Quelle, Einkaufspreis, Marge, Empfehlungen |
| Datenschutz | Einwilligung für Fotos/Videos, Auskunft, Löschen inkl. Gerät und Browser-Sicherungen |
| Technik | Datenschicht `STORE`, Rollen (Demo), Portal-Freigaben, Supabase-Schema mit Zugriffsregeln |

## 4. Noch offene Funktionen

- **Server-Datenbank und Login (Supabase):** Nur vorbereitet. Anschließen braucht dein Konto und deine Zustimmung.
- **Echtes Kundenportal mit eigenem Zugang:** Bisher nur Vorschau und Freigaben. Das echte Portal kommt erst mit Login.
- **Echte Rechteprüfung:** Rollen werden nur in der Oberfläche geprüft. Sichern lässt sich das erst über die Datenbank-Regeln.
- **Erinnerungen per E-Mail oder SMS:** Weiter nur simuliert.
- **Produktdatenbank:**
  - weitere Hersteller und Modelle
  - Preise für neu ergänzte Produkte eintragen (stehen auf 0 €)
- **Video-Bewegungsanalyse:** Gespeicherte Videos werden nicht automatisch ausgewertet. Winkel misst man weiter über „Bewegung & Video“.
- **Druck-Layout:** Feinschliff nach deinem Test am echten Gerät.

## 5. Experimentelle oder simulierte Bereiche

In der App ist jeweils angegeben, was davon Beta, Simulation oder Vorschau ist.

- **Live-Analyse und automatische Gelenkerkennung:** Beta, braucht Internet und eine echte Kamera.
- **Bewegungssimulation:** aus Körpermaßen berechnet.
- **Fahrradgrafik:** schematisch, nicht maßstäblich.
- **Schreibhilfe:** Textvorlagen, keine KI.
- **Kundenportal, Kennzahlen, Team:** Vorschau mit Demo-Daten.
- **Rollen:** nur in der Demo-Oberfläche.
- **Hardware Lab, Flotten, Anbindungen:** Konzept.
- **Faustregeln** (Sattelbreite, Keile, Float-Empfehlung, Übungen): Fitting-Praxis, nicht validiert, keine Diagnose.

## 6. Technische Einschränkungen

- **Wo die Daten liegen:** nur im Browser des jeweiligen Geräts, unverschlüsselt. Ein anderes Gerät sieht sie nicht.
  - Fotos und Videos liegen ebenfalls nur auf dem Gerät.
  - Sie sind nicht in der Text-Sicherung enthalten.
- **Speicherplatz:** Der Browser-Speicher ist begrenzt. Viele Videos können ihn füllen.
- **Privates Surfen und gelöschte Website-Daten:** Daten gehen verloren.
- **Ohne Internet** gehen nicht: Kamera-Erkennung (MediaPipe), Schriftarten. Alles andere läuft offline.
- **Drucken als PDF:** Das funktioniert über den GitHub-Link der Demo, nicht in der Claude-Vorschau.

## 7. Ausgeführter Testlauf

| Test | Handy (390 px) | Tablet (820 px, Touch) | PC (1366 px) |
|---|---|---|---|
| Praxistest 14 Schritte (Testkunde „TEST Max Praxistest“) | 22/22 | 22/22 | 22/22 |
| Bisheriger Prüflauf (Testkundin „TEST Anna Probe“) | 41/41 | – | 41/41 |
| Sattelhöhe | 19/19 | | |
| Tests je Phase (2 bis 9) | 158/158 | – | 158/158 |
| Alle Ansichten: Überlauf, Fehler in der Konsole | keine | keine | keine |
| Alle Knöpfe durchgeklickt | keine echten Fehler | | keine echten Fehler |

Die Tests liefen in einem Testbrowser in Handy-, Tablet- und PC-Größe, nicht auf echten Geräten.

**14 Schritte:**
1. Kunde anlegen
2. Fahrrad mit Komponenten
3. Fitting starten
4. Körperanalyse
5. Sitzknochen (3 Messungen, Mittelwert)
6. Körpermaße
7. Fahrrad vermessen (Doppelmessung, Messmittel)
8. Bewegungsanalyse (Ansicht und Markierung)
9. Anpassungen
10. Produktempfehlung
11. Bericht (16 Abschnitte)
12. Abschluss mit Nachkontrollen
13. Neue Sitzung aus der Nachkontrolle
14. Vergleich

Danach wurden die Verknüpfungen in Kunden- und Fahrradakte geprüft und ob nach dem Neuladen alles noch gespeichert ist.

**Meldungen beim Durchklicken aller Knöpfe, die keine Fehler sind:**
- Filter, die schon aktiv waren
- Lagerbuttons ohne Lagerartikel
- Infos zum Status
- Klicks auf die Fahrradgrafik, die das Testwerkzeug nicht ausführen kann

## 8. Erkannte und behobene Fehler

- **Tab-Leiste der Kundenakte:** Sie war auf schmalen Bildschirmen nicht anklickbar, weil sie gestaucht wurde. Behoben, sie bleibt jetzt beim Scrollen oben stehen.
- **Gleicher Funktionsname:** Ein neuer Name überdeckte eine bestehende Funktion (Teile-Hinweise). Ich habe den neuen umbenannt.
- **Nachkontrolle in der Übersicht:** Eine überfällige Nachkontrolle war nicht als überfällig markiert. Behoben.
- **Fotos und Videos je Sitzung:** Der Bereich klappte nach dem Hochladen zu. Behoben.
- **Löschen eines Kunden:** Ältere Protokolleinträge enthielten noch seinen Namen. Sie werden jetzt mit anonymisiert.
- **Kurbellänge:** Aus der Fahrradakte kam sie nicht im Fitting an. Deshalb blieb „Fahrrad vermessen“ offen. Behoben.
- **Vergleich am Tablet:** Die Auswahlfelder waren zu schmal. Behoben.
- **Kleine Knöpfe am Tablet:** Segmentknöpfe und Status-Markierungen waren für Touch zu klein. Behoben.

## 9. Bestehende Daten erhalten

- Dominik Böhm ist weiter vorhanden und gegen Löschen gesperrt.
- Alle Demo-Kunden sind vorhanden.
- Eigene Einträge bleiben bei Updates erhalten.
- Vor jedem Versionswechsel legt FYF automatisch eine Sicherung im Browser an.
- Alle Datenänderungen sind abwärtskompatibel: Neue Felder kommen hinzu, alte bleiben.

---

## Nächster Schritt für dich (am iPhone möglich)
1. Demo öffnen → Mehr → ganz unten bei „Rolle und Datenspeicherung“ muss **Version v.52** stehen. Falls noch eine ältere Version erscheint: Seite neu laden (GitHub braucht manchmal ein paar Minuten).
2. Mit einem Testkunden: ein Foto aufnehmen und speichern, den Bericht über „Drucken“ als PDF sichern.
3. Rückmeldung geben, was sich am echten Gerät unhandlich anfühlt.
