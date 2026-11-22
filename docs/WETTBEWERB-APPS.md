# Wettbewerb: 4 Fahrrad-Apps im Vergleich (Stand 22.11.2026, Quelle: App-Store-Seiten)

## Kurzüberblick

| App | Wer / Modell | Bewertung | Stärken | Schwächen |
|---|---|---|---|---|
| **linexo** (Wertgarantie) | Versicherer, App kostenlos, verdient über Versicherung | 4,7 ★ (3.898) | Versicherung + Schaden melden mit Status, **BikeCard in Apple Wallet**, Pannen-Abholung, Touren aufzeichnen + km-Ziele, **Karte mit Werkstätten / Ladestationen / Schlauch-Automaten / Polizei / sicheren Parkplätzen**, Ratgeber-Videos | Konto nötig, Tracking über andere Apps, Support schwer erreichbar, Kunde kann Daten nicht selbst ändern, Symbol schwer zu erkennen (laut Bewertung) |
| **BikePass – Fahrradausweis** | Einzelentwickler, kostenlos + **einmalig 2,99 €** | 3,6 ★ (11) | Kein Konto, Daten nur auf dem Gerät, **sehr detaillierte Felder je Radtyp** (ADFC-Codierung, Polizei-Registrierung, Position der Rahmennummer, Seriennummern von Motor/Akku/Display/Licht/Gabel/Dämpfer, 2. Schloss, GPS-Tracker), **PDF-Ausweis für Polizei** (Versteck des Trackers nie im PDF), **Fotos im Vollbild mit Zoom**, abweichender Halter | Gratis-Version beschränkt (3 Räder, PDF mit Wasserzeichen), iCloud-Sync war lange fehlerhaft, keine Werkstatt-Anbindung |
| **BikePass EU** (LEAP42) | Start-up, kostenlos, verkauft ID-Aufkleber | 4,8 ★ (4) | **EU-weite Diebstahlmeldung**, Finder scannt Aufkleber und erreicht den Besitzer, ohne Daten zu sehen, Besitzerwechsel mit Historie, **Diebstahl-Hotspots + Warnung beim Parken**, KI erkennt Marke/Modell/Farbe aus Foto, **Händler verknüpfen und Zugriff wieder entziehen**, Termine bei der Werkstatt, Service-Erinnerung per Push | Konto mit E-Mail nötig, sammelt Standort/Kontakt, nur Englisch im Store, noch sehr neu |
| **ENDURE** | Training (kein Pass), 14 Tage gratis, dann 9,99 €/Monat | 5,0 ★ (1) | Ruhiges Design („Farbe zeigt Daten“), Start in 30 Sekunden, **Teilen-Karten hell/dunkel + Sticker mit durchsichtigem Hintergrund**, **Roadmap in der App mit „Will ich haben“-Knopf**, freundliche Änderungslisten | Abo, Konto, für unseren Zweck nur als Design-Vorbild relevant |

## Wo FYF heute schon vorne ist
- **Werkstattbestätigte Einträge.** Keiner der anderen hat eine echte Laden-Software dahinter. Bei BikePass EU sind Händler nur verknüpft.
- **Kein Konto und trotzdem eine Sicherung** über den Sicherungscode. Das bietet nur der kleine BikePass, und dort ohne Sicherung oder Sync.
- **Bikefitting- und Sitzpositionsdaten**, Fahrwerk, Reifendruck, Teile-Verschleiß, Wert-Schätzung, Verkauf in 5 Schritten, Kauf-Check: Das hat niemand.
- **Komplett kostenlos und ohne Grenzen.** BikePass begrenzt auf 3 Räder und setzt ein Wasserzeichen ins PDF.

## Was wir übernehmen sollten (priorisiert)

| Prio | Idee | Von | Aufwand | Hinweis |
|---|---|---|---|---|
| 1 | **Händler-Zugang erteilen und wieder entziehen** (bei uns: 7-Tage-Freigabe) | BikePass EU | mittel, Datenbank | Plan liegt bereit (`docs/PASS-WERKSTATT-FREIGABE-PLAN.md`). Der Wettbewerb hat das schon, deshalb jetzt freigeben |
| 2 | **Fotos im Vollbild mit Zoom und Blättern** | BikePass | klein | Im Diebstahlfall Details zeigen |
| 3 | **Fehlende Ausweis-Felder:** ADFC-Codierung, Polizei-Registrierung, Position der Rahmennummer, Seriennummern von Licht/Display/Gabel/Dämpfer, 2. Schloss, abweichender Halter (Familie) | BikePass | klein | Ins Diebstahl-PDF übernehmen; das Tracker-Versteck nie ins PDF |
| 4 | **Helfer-Karte:** Werkstätten, Schlauch-Automaten, Luftpumpen, E-Bike-Ladestationen, Polizei | linexo, BikePass EU | mittel | Kostenlos über OpenStreetMap-Daten möglich |
| 5 | **Service-Erinnerung als Push** | BikePass EU | mittel, Server | Web-Push ist kostenlos, braucht eine Server-Funktion → Plan |
| 6 | **Teilen-Karte hell/dunkel + Sticker** | ENDURE | klein | Unsere Rad-Karte um diese Varianten erweitern |
| 7 | **„Wünsch dir was“ in der App:** Roadmap mit „Will ich haben“ | ENDURE | klein | Zählen über die vorhandene anonyme Nutzungszählung |
| 8 | **Kurze Ratgeber-Tipps** (Kette ölen, Reifendruck, Winter) | linexo | klein bis mittel | Bindet Nutzer, die kein Wartungs-Fan sind |
| 9 | **Foto erkennt Marke/Modell/Farbe** | BikePass EU | groß | Nur regelbasiert erlaubt (Text auf dem Rahmen lesen), keine bezahlte KI |
| 10 | **Diebstahl-Hotspots / Warnung beim Parken** | BikePass EU | groß | Braucht viele Nutzer und Standortdaten, steht im Konflikt mit privacy-first, später prüfen |
| – | **Apple-Wallet-Karte** | linexo | – | Braucht einen kostenpflichtigen Apple-Entwickler-Zugang (99 $/Jahr) → nur mit Ihrer Entscheidung |

## Lehren für Positionierung und Monetarisierung
- **linexo** zeigt: Eine kostenlose App mit Versicherungs-Angebot funktioniert und wird gut bewertet. Die Bewertungen strafen aber schlechten Support und fehlende Kontrolle über die eigenen Daten ab. **Unser Vorteil: Kontrolle beim Nutzer.**
- **BikePass (2,99 € einmalig)** zeigt: Nutzer zahlen für „kein Abo, kein Konto“. Wir bleiben trotzdem komplett kostenlos und machen das zum Verkaufsargument: „Alles gratis, keine Grenzen, kein Wasserzeichen“.
- **BikePass EU** ist der direkteste Wettbewerber, denn er geht auch auf Händler. Er hat aber Konto-Zwang und sammelt Standort. **Unser Vorteil: echte Laden-Software, kein Konto.**
- **Symbol und Wiedererkennung** zählen, so steht es in einer linexo-Bewertung. Das neue FYF-Tag-Symbol ist eindeutig.
- **Support sichtbar machen:** Kontaktweg und Hilfe in der App, persönliche Antworten wie beim BikePass-Entwickler.

## Mein Vorschlag für die nächsten Schritte
1. **Sofort, ohne Freigabe:**
   - Fotos im Vollbild
   - fehlende Ausweis-Felder plus Diebstahl-PDF
   - Teilen-Karte hell/dunkel/Sticker
   - „Wünsch dir was“-Roadmap
   - Helfer-Karte (OpenStreetMap)
2. **Mit Ihrer Freigabe:** Händler-Zugang erteilen und entziehen (7 Tage), Datenbank-Update.
3. **Später:** Push-Erinnerungen (Server), Ratgeber-Inhalte, Diebstahl-Hotspots.
