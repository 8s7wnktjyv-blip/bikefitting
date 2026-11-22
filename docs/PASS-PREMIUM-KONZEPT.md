# FYF Fahrradpass – Premium-Konzept (22.11.2026)

**Leitsatz:** Der Pass ist der Ausweis und das Gedächtnis des Rads. Jeder Screen beantwortet in 3 Sekunden eine von drei Fragen:
1. **Ist mein Rad in Ordnung?**
2. **Was muss ich als Nächstes tun?**
3. **Kann ich es beweisen?** (Diebstahl, Verkauf, Versicherung)

Alles, was keine dieser Fragen beantwortet, gehört eine Ebene tiefer.

Stand heute (v.182): Dunkles Design, Cockpit mit Zustand · Pass · Schutz, Wert, Teile-Ampel, Ziele, Verkauf in 5 Schritten und Offline-Grundfunktion sind schon da. Dieses Konzept schließt die Lücken bis „fühlt sich fertig an“.

---

## A. Design-Richtung „Garage bei Nacht“

**Idee:** Das Rad steht im Licht, alles andere tritt zurück. Dunkel als Standard, Hell gleichwertig.

| Rolle | Dunkel | Hell | Regel |
|---|---|---|---|
| Hintergrund | `#07090C` mit Nachtblau-Verlauf oben (`#1C2936`) | `#F3F3F1` | nie reines Schwarz/Weiß |
| Karte | `#12171E` → `#10151B`, Rand `rgba(255,255,255,.06)` | `#FFFFFF`, Schatten weich | Tiefe durch Rand + Licht, nicht durch Farbe |
| Text / gedämpft | `#F3F6F9` / `#8D99A8` | `#111416` / `#6C7176` | |
| **Signal-Orange** | `#FF6A1A` | `#E8601C` | nur 1 Hauptaktion pro Screen + Marke |
| Zustand | gut `#22C55E` · bald `#F59E0B` · jetzt `#EF4444` · Info `#60A5FA` | dunklere Töne | immer mit Text, nie nur Farbe |

- **Schrift:**
  - Inter/System, Titel 32/800 mit −3 % Laufweite.
  - Kennzahlen 22–40/800 mit festen Ziffernbreiten.
  - Labels 11–12/700 in Großbuchstaben mit +8 % Laufweite.
  - Fließtext 15/400.
- **Raster und Formen:**
  - 4-px-Raster, Abstände 8/12/16/24.
  - Ecken: 30 px für Hero und Cockpit, 20 px für Karten, 999 px für Knöpfe.
- **Identität:**
  - FYF-Edding-Tag als Logo.
  - Rad-Foto bzw. Rad-Grafik immer groß, mit Verlauf darunter.
  - Ringe für Zustände.
  - Orange Akzentlinie beim aktiven Rad.
- **Wertigkeit entsteht durch:**
  - echte Zahlen (km, Euro, Prozent) statt Floskeln,
  - Quelle bei jeder Angabe („werkstattbestätigt“, „selbst eingetragen“),
  - ruhige Bewegung: 150–220 ms, Ringe füllen sich beim Öffnen,
  - kurzes Vibrieren beim Speichern (wo das Handy es kann),
  - keine leeren Felder ohne Erklärung.
- **Leere Zustände:** Jeder leere Bereich zeigt drei Dinge:
  - was hier entsteht (Bild oder Beispiel),
  - den Nutzen in einem Satz,
  - genau einen Knopf.

  Beispiel Garage leer: Rad-Grafik, „Gib deinem Rad einen Ausweis.“ und darunter drei Nutzen-Chips: Diebstahlschutz, Service-Erinnerung, Wert beim Verkauf.

## B. Struktur

**Unten 4 Bereiche:**
- **Garage:** meine Räder
- **Prüfen:** fremdes Rad checken
- **Werkstätten:** Service und Termin
- **Marktplatz**

**Garage (Home), von oben nach unten:**
1. Logo
2. „Nächste Schritte“: höchstens 3 Karten, das Wichtigste zuerst
3. Rad-Karten mit Foto, Zustand, km und Ziel
4. „+ Rad“
5. Sicherung und Einstellungen

**Rad-Seite:**
1. Foto-Kopf
2. Schnellzugriff
3. **Cockpit** (Zustand · Pass · Schutz)
4. **Nächste Schritte für dieses Rad**
5. Mein Rad: Wert, Teile, Ziel und Werkzeuge
6. **Lebenslauf** als Zeitleiste
7. Details und Besitzer-Einstellungen

## C. Kern-Screens (Soll)

**Garage leer:**
- Grafik und ein Satz Nutzen, ein Knopf „Rad anlegen (1 Minute)“.
- Darunter „Ich habe schon einen Code“.
- Darunter drei Nutzen-Chips.

**Garage befüllt:**
- Rad-Karte mit Foto, Name, Statuspunkt, km, Ziel und Schutz.
- Bei mehreren Rädern: Karten untereinander, das zuletzt geöffnete oben, oben ein Filter nach Fahrer.

**Rad-Übersicht:**
- Das Cockpit liefert sofort das Urteil („Verkaufsbereit“, „Wartungsstau“ …).
- Ein Tipp auf einen Ring öffnet die Begründung.
- „Nächste Schritte“ zeigt höchstens 3 Aufgaben, jede mit Knopf:
  - Service fällig
  - Teil tauschen
  - Pass vervollständigen
  - Sicherung

**Komponenten & Service:**
- Stückliste nach Gruppen.
- Jede Zeile: Verschleißbalken, km seit Einbau, Foto, Tippen zum Bearbeiten.
- Service-Plan mit Ampel, Datum oder km und „Erledigt“ in einem Tipp.
- Belege hängen an der Zeile (Teilfoto, Rechnung).

**Check bike (Ergebnis):**
- Großes Urteil oben in einem Satz:
  - „Keine Diebstahlmeldung · 4 Werkstatt-Einträge · km plausibel“
  - oder rot: „Als gestohlen gemeldet – nicht kaufen“
- Darunter vier Prüfpunkte mit ✓, ! oder ?.
- Dazu Datum und Uhrzeit der Prüfung und „Was heißt das?“.
- **Nie mehr versprechen als belegt ist.**

**Verkauf & Übergabe:**
- 5 Schritte mit Fortschritt: Zustand, Preis, Anzeige, Vertrag, Übergabe.
- Verkaufsunterlage als PDF.
- Käufer-Link mit Kauf-Check.
- Übergabe per Code, ohne Werkstatt.

## D. Funktionen nach Nutzen

| Prio | Funktion | Stand |
|---|---|---|
| 1 | **Nächste Schritte** (Garage + Rad), max. 3, mit Knopf | **neu v.183** |
| 2 | **Offline klar anzeigen:** Hinweis „Offline – Stand vom …“, gespeichert bleibt lokal | **neu v.183** (Hinweis), Grundfunktion v.160 |
| 3 | **Lebenslauf als Zeitleiste** mit Farben (Werkstatt / selbst / Schaden / Teile) | **neu v.184** |
| 4 | Check-bike-Ergebnis als Urteilskarte | **neu v.185** |
| 5 | Garage leer: Nutzen-Chips + 1-Minuten-Versprechen | **neu v.185** |
| 6 | Erinnerungen als Push (Web-Push, kostenlos) | später, braucht Server-Funktion → Plan |
| 7 | Werkstatt-Freigabe 7 Tage | wartet auf Ihre Freigabe |
| 8 | Haptik und Animationen (Ringe füllen sich) | Feinschliff |

## E. Geld verdienen, App bleibt kostenlos

- **Erlaubt:** höchstens ein Hinweis pro Screen, nur im Zusammenhang und klar „Anzeige“:
  - „Kette fällig – passende Werkstätten in deiner Nähe“, zahlende FYF-Läden zuerst
  - Teile-Tipp mit Händlerlink
- **Nie:** Banner, Pop-ups, Video, Tracking, Weitergabe von Daten.
- **Premium/Abo:** nicht empfohlen.
  - Es bricht „Endkunden kostenlos, kein Endkunden-Abo“.
  - Es schwächt das Vertrauen.
  - Besser sind bezahlte **Leistungen beim Laden**: Gebrauchtrad-Check, Fitting, Aufkleber (4,99 €).
- Geld verdient FYF über die Läden (99/149 € im Monat). Der Pass ist der Grund, warum Kunden zum Laden zurückkommen.

## F. Roadmap

1. **Jetzt (v.183–185):**
   - Nächste Schritte
   - Offline-Hinweis
   - Lebenslauf-Zeitleiste
   - Check-bike-Urteil
   - Garage leer
2. **Danach:**
   - Animationen und Haptik
   - Mehrere Räder: zuletzt geöffnetes oben, Fahrer-Filter verfeinern
   - Englisch für neue Texte
3. **Mit Ihrer Freigabe:**
   - Werkstatt-Freigabe 7 Tage, Schadens-Einträge von Läden
   - Web-Push-Erinnerungen
   - dezente Werkstatt-Hinweise, als „Anzeige“ markiert
