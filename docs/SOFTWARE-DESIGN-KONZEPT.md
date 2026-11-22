# FYF Software – Design- und Produktkonzept „Präzision“ (22.11.2026)

Auftrag von Dominik: Die Software soll wie ein modernes, professionelles Werkzeug für Fitting-Studios und gute Werkstätten wirken und funktionieren.
Leitfrage für jede Änderung: **Spart das dem Fitter oder Mechaniker am Tag Zeit oder Fehler?**

Stand: Schritt 1 (Design-Grundlage) ist mit **v.143** online. Alles Weitere steht in der Roadmap unten.

---

## 1. Neue Design-Richtung

### Farbpalette
| Rolle | Hell | Dunkel | Wofür |
|---|---|---|---|
| Hintergrund | `#F3F4F6` | `#0C0F13` | ruhige Fläche, kein Beige mehr |
| Fläche (Karten) | `#FFFFFF` | `#151A20` | Inhalt |
| Fläche 2 | `#EEF0F3` | `#1C232B` | Felder, Spalten, Symbole |
| Linie | `#E2E5EA` | `#28313B` | Trennlinien statt Schatten |
| Text | `#0F1419` | `#EEF1F4` | |
| Text gedämpft | `#56606B` | `#A3ACB6` | Beschriftungen |
| Seitenleiste | `#0F1419` | `#080A0D` | Graphit |
| **Akzent Orange** | `#E8620F` | `#E8620F` | **nur** Hauptaktion je Ansicht (z. B. „Fitting starten“) und Marke |
| **Messwert-Blau** | `#1F5FAE` | `#6AA5EC` | Maße, Zielwerte, Fokus in Feldern |
| OK | `#15803D` | | erledigt, im Zielbereich |
| Achtung | `#B45309` | | bald fällig, knapp |
| Problem | `#B91C1C` | | überfällig, außerhalb Bereich |

Regel: **Farbe trägt Bedeutung, nie Dekoration.** Bunte Kacheln entfallen. Farbe nur noch im Symbol oder im Status.

### Schrift
- Überschriften: Archivo, 28 px Seitentitel, 18 px Abschnitt, enger Buchstabenabstand.
- Text: Figtree, 14–15 px.
- **Zahlen mit fester Breite** (`tabular-nums`). Messwerte in IBM Plex Mono, damit 742 / 745 mm untereinander sauber stehen.
- Kleine Großbuchstaben-Labels (11 px, +8 % Abstand) für Abschnitte: „WERKSTATT & TERMINE“.

### Abstände, Ecken, Schatten
- 4-px-Raster (8 / 12 / 16 / 24 / 32).
- Ecken: 12 px für Karten, 8 px für Knöpfe und Felder, 6 px für Status-Chips.
- Schatten nur hauchdünn (1–3 px). Tiefe entsteht durch Linien. Großer Schatten nur bei Fenstern, die über der Seite liegen.

### Komponenten
- **Status-Chip:** Rahmen und zarte Füllung in Statusfarbe, mit Text. Ein Punkt reicht nicht, weil man Farbe allein nicht zuverlässig erkennt.
- **Knöpfe:** primär orange (max. einer pro Ansicht), sekundär weiß mit Linie, tertiär nur Text.
- **Felder:** 44 px hoch (Tablet), Fokus blau, Einheit (mm, °, bar) fest im Feld rechts.
- **Seitenleiste:** Hauptpunkte mit Symbol, Unterpunkte eingerückt ohne Symbol. Aktive Seite mit orangem Balken links statt Farbverlauf.

---

## 2. Dashboard „Heute“
Reihenfolge (umgesetzt v.143: Heute steht vor der Einrichtung):
1. **Warnungen, die Daten kosten können** (Sicherung). Nur wenn wirklich nötig.
2. **Heute-Karte (Graphit):** nächster Termin mit „Öffnen“ und Zahl der fälligen, abholbereiten und geplanten Aufträge.
3. **4 Kennzahlen:** Werkstatt offen, Termine heute, Kunden, Fittings.
4. **Arbeitsliste „Braucht Aufmerksamkeit“:** überfällige Aufträge, Freigaben, Nachkontrollen, sortiert nach Dringlichkeit.
5. Letzte Fittings und zuletzt bearbeitete Kunden.
6. Einrichtung und Ladentyp **unten**. Wenn alles erledigt ist, verschwinden sie ganz (das war schon so).

Je nach Ladentyp (vorhandene Einstellung) ändert sich die Reihenfolge:
- **Fitting-Studio:** Heute-Fittings, Nachkontrollen, Fitting-Pipeline.
- **Werkstatt:** Tafel-Kurzansicht, Teile in Wartestellung, Abholungen.
- **Händler:** Übergaben, Probefahrten, Angebote.

*Umgesetzt v.147.*

---

## 3. Bikefitting-Ablauf (Kern)
Fortschrittsleiste oben, immer sichtbar, jeder Schritt anklickbar:
1. **Gespräch:** Ziele, Beschwerden, Fahrprofil. Kurz, mit Ankreuz-Feldern.
2. **Körpermaße:** Felder mit Plausibilitätsprüfung (z. B. Schrittlänge zur Körpergröße).
3. **Ausgangsposition am Rad:** Ist-Werte. Die Skizze der Sitzposition zeichnet sich live mit.
4. **Anpassung:** je Änderung Wert vorher und nachher, Differenz in Blau. Zielbereich als Band in der Skizze.
5. **Kontrolle:** Kniewinkel, Reichweite, Sattelhöhe gegen Zielbereich, mit Ampel.
6. **Abschluss:** Bericht, Maßblatt, automatisch in den Fahrradpass. Werkstattauftrag mit Teilen (Vorbau, Sattel …) per Knopf.

Visualisierung:
- **Überlagerte Seitenansicht** (vorher grau, nachher Graphit) mit Maßpfeilen.
- **Sitzungsvergleich:** Tabelle über alle Sitzungen eines Kunden, Abweichung farbig. Dazu Verlaufslinie je Maß.

Empfehlungslogik: bleibt regelbasiert, mit Begründung und Zahl. Wir sind keine Ärzte, also keine Diagnose.

---

## 4. Kundenakte
- **Kopf:** Name, Kontakt, Einwilligungen als Chips, nächster Termin, offene Beträge.
- **Spalte links „Auf einen Blick“:** Räder (mit Pass-Status), letzte Sitzposition, offene Aufträge.
- **Rechts eine Zeitleiste** für alles: Fittings (mit Maßänderung), Werkstatt, Rechnungen, Pass-Einträge. Filter-Chips oben.
- Von jedem Eintrag aus: „Auftrag daraus machen“, „Im Pass ansehen“, „Bericht“.

---

## 5. Konkrete UI-Regeln
- **Seitenleiste:** 6 Gruppen maximal. Unterpunkte eingerückt, Zähler nur bei Handlungsbedarf.
- **Status:** feste Statusfolge mit festen Farben (Angenommen → Freigabe → In Arbeit → Wartet auf Teile → Abholbereit → Übergeben).
- **Karten:** nur eine Überschrift, maximal eine Hauptaktion.
- **Tabellen:** Köpfe in kleinen Großbuchstaben, Zahlen rechtsbündig, Zeile ganz anklickbar.
- **Seitenfenster:** Titel, Inhalt, feste Fußleiste mit „Speichern“ rechts. Esc oder Wischen schließt das Fenster.
- **Werkstatt-Tafel (Tablet):** Knöpfe mindestens 44 px groß (umgesetzt v.143). Als Nächstes: Karten zwischen Spalten ziehen und eine Spaltenansicht im Querformat.
- **PDF-Berichte:** gleiche Palette, Logo des Ladens, Maßtabelle in Monospace, Skizze vorher/nachher.

---

## 6. Roadmap
**Schnelle Verbesserungen (je ein Lauf):**
1. ✅ Design-Grundlage „Präzision“, Dashboard „Heute“ zuerst (v.143)
2. Feinschliff der Komponenten:
   - Umschaltknöpfe (Woche/Liste/Monat) in Graphit statt Orange
   - Einheiten fest im Feld
   - Seitenfenster mit fester Fußleiste
3. ✅ Dashboard je Ladentyp (v.147)
4. Werkstatt-Tafel: Ziehen und Ablegen, Tablet-Querformat

**Größere Schritte (mehrere Läufe):**
5. ✅ Fitting-Ablauf: Fortschrittsleiste (gab es) + Live-Skizze im Schritt Anpassen (v.156)
6. ◐ Sitzungsvergleich: Überlagerung fertig (v.148), Verlaufslinien gab es schon
7. ✅ Kundenakte mit Kopf und gemeinsamer Zeitleiste (v.151)
8. ✅ Fitting-Bericht (PDF) im neuen Stil mit Skizze (v.155)
9. Geometrie-Bibliothek im Fitting-Ablauf: „passende Rahmen zu dieser Sitzposition“

Keiner dieser Schritte ändert das Datenmodell. Alle sind Darstellung und Abläufe und damit freigegeben.
