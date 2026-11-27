# Plan: Pass-App überarbeiten („Überarbeite alles“, 26.11.2026)

Gilt für die Pass-App `rad.html` (mit `pass-theme.css`, `pass-en.js`) und, wo genannt, für `finder.html`.
Die Werkstatt-Software `index.html` ist ein eigenes, großes Stück – dafür gibt es `docs/SOFTWARE-DESIGN-KONZEPT.md`
und einen eigenen Abschnitt am Ende dieses Plans.

## Befund

Die App ist über 120 Versionen gewachsen. Funktionen sind vollständig, aber jedes Werkzeug ist
eigenständig gebaut – deshalb fühlt sich die App an vielen Stellen unterschiedlich an:

- **Seitenköpfe:** `page('Titel')` zeigt nur den Titel. Untertitel, Zweck und „was kann ich hier tun“
  fehlen bei etwa der Hälfte der Werkzeuge, bei anderen stehen sie als erster Absatz im Inhalt.
- **Zurück:** drei Wege nebeneinander (eigene `.tpage`, Sheets, `docWin()`), jeder mit eigener Kopfzeile.
  Die Wischgeste/Zurück-Taste greift global, die Optik ist aber je Seite anders.
- **Karten und Knöpfe:** mal `card`, mal `card` mit eigenem Inline-Stil, mal nacktes `div`;
  Hauptaktion mal `.btn` (schwarz), mal `.btn.ghost`, mal `.btn` mit `style="background:…"`.
- **Leere Zustände:** jede Seite formuliert sie neu („Noch nichts eingetragen“, „Noch keine Messung“ …),
  mit und ohne Handlungsknopf.
- **Zahlen, Einheiten, Daten:** teils `num()`/`f1()`, teils roh; `km`, `mm`, `bar` mal mit, mal ohne
  Leerzeichen; Datum überall `fd()`, Monatsnamen nur an wenigen Stellen.
- **Dialoge:** Löschen und Bestätigen laufen teils über `confirm()` (grauer Browser-Dialog),
  teils über ein eigenes `sheet`. Das bricht die Optik und ist am iPhone schlecht zu treffen.
- **Dark Mode:** `pass-theme.css` erzwingt rund 30 Regeln mit `!important`. Neue Bausteine werden darin
  leicht vergessen und bleiben im Dunkeln hell (Kandidaten: `hint`, `svc-*`, `gl-*`, `bdg`, `ck-ring`,
  Tabellen `table.fh`, Beleg-Fotos, neue Abschnitte aus v.150–v.215).
- **Englisch:** das Wörterbuch deckt statische Texte, aber dynamische Sätze bleiben deutsch
  (z. B. „Fällig seit 01.03.2026“, „2 von 5 eingetragen“ in neuen Abschnitten).
- **Barrierefreiheit:** keine sichtbaren Fokus-Ringe für Tastatur/NFC-Stifte, einzelne Symbol-Knöpfe ohne
  `aria-label`, Tap-Ziele unter 44 px (`.sm2`, `.linkbtn`, Chips in `.miss`).
- **Rückmeldung:** Speichern bestätigt über `toast()`; Fehler und Ladezustände sind je Werkzeug anders.

## Ziel

Ein Fahrradbesitzer soll in **jeder** Seite sofort sehen: wo bin ich, was steht hier, was ist der nächste
Schritt – und alles sieht und fühlt sich gleich an. Keine Funktion wird entfernt, hell und dunkel bleiben
gleichwertig, alles bleibt auf dem Gerät, kein bezahlter Dienst, KI weiter nur regelbasiert.

## Regeln

- Jede Änderung in kleinen Paketen, je Paket ein Browser-Test, alle vorhandenen Tests bleiben grün.
- Neue Texte sofort ins Wörterbuch `pass-en.js` (auch Muster für dynamische Sätze).
- Nichts umbenennen, was Tests oder `find`-Links benutzen (`data-tool`, `#ids`, `location.hash`).
- Nach jedem Paket: Rundgang auf iPhone-13-Größe (alle Werkzeuge: kein JS-Fehler, kein Querscrollen).

## Pakete (Reihenfolge = Vorrang)

1. **Fundament (CSS + ein Helfer).** Ein Satz Abstände und Typo (4/8/12/18/26 px, Titel 30/20/15/13),
   Mindest-Tap 44 px, sichtbarer Fokus-Ring (`:focus-visible`), ruhiger Ladezustand.
   `confirm()`/`alert()` durch einen eigenen Bestätigungs-Dialog ersetzen (`askSheet(t, text, ja, nein)`),
   damit Löschen überall gleich aussieht und groß zu treffen ist.
2. **Seitenkopf & Zurück.** `page()` bekommt einen zweiten Parameter für einen Untertitel und eine
   optionale Hauptaktion; alle Werkzeuge nutzen denselben Kopf (Logo-Zeile, Zurück-Pille, Titel, Untertitel).
   Sheets bekommen dieselbe Kopfzeile.
3. **Jedes Werkzeug „auf einen Blick“.** Über dem Inhalt eine Karte mit 2–4 Kennzahlen und **einer**
   Hauptaktion (z. B. Service: fällig/bald/Plan; Ausstattung: Teile/Serie; Belege: Anzahl/Garantie).
   Leerer Zustand: ein Satz + ein Knopf, überall gleich aufgebaut.
4. **Texte, Zahlen, Einheiten.** Eine Schreibweise: „1.250 km“, „172,5 mm“, „1,5 bar“, „12.03.2027“,
   „ca.“ nur für Schätzungen. Du-Form, kurze Sätze, keine Anglizismen. Englisch-Lücken schließen
   (dynamische Sätze als Muster in `pass-en.js`).
5. **Dark Mode ohne `!important`-Kaskade.** Eigene Variablen für Flächen/Ränder je Baustein, dann
   `pass-theme.css` auf das Nötige zusammenstreichen; jedes Werkzeug in dunkel und hell durchprüfen.
6. **Radseite ordnen.** Kopf (Foto, Name, Status) → „auf einen Blick“ (Ring/Cockpit) → nächste Schritte →
   Werkzeuge → Details. Nichts doppelt (Wert, Schutz, Pass-Vollständigkeit erscheinen heute teils zweimal).
7. **Garage/Start.** Leere Garage, Karten, Chips und „Daten sichern“ in einer ruhigen Reihenfolge;
   eine Hauptaktion pro Karte.
8. **Drucken und PDF.** Maßblatt, Anzeige-Blatt, Verkaufsunterlage, Übungsblatt, Rad-Karte: gleicher Kopf
   (Logo, Laden, Datum), gleiche Tabellen, gleiche Fußzeile („kein Gutachten“).

## Werkstatt-Software (index.html) – nur nach Freigabe

Eigener Umbau nach `docs/SOFTWARE-DESIGN-KONZEPT.md` (Kalender, Formulare, Dashboard sind dort bereits
beschrieben). Wegen Größe und Datenbanknähe erst als eigener Plan mit Freigabe, nicht in diesem Lauf.

## Wie prüfen

- Vorhandene Tests: `sh tests/e2e/run.sh` (bzw. GitHub-Action „Tests“ bei jedem Push).
- Je Paket ein neuer Test (t217 …): betroffene Seite öffnen, Zahlen und Knöpfe prüfen, kein Querscrollen,
  Englisch und Deutsch, dunkel und hell.
- Schlussprüfung: Rundgang über alle Werkzeuge (`data-tool`), Garage, Radseite, Prüfen – ohne JS-Fehler.

## Stand

- 26.11.2026: Plan angelegt (Antwort auf „Überarbeite alles“); Freigabe „Wirklich alles: auch die Werkstatt-Software“.
- **Paket 1 fertig (v.216):** `fyf-basis.css` (Fokus-Ring, Tap-Ziele, Zahlen untereinander, Umbrechen, Markieren,
  Drucken, Systemwünsche) in `rad.html`, `finder.html` und `index.html` eingebunden (Service-Worker `p146`);
  Pass: `askYes()` ersetzt 7 × `confirm()`; Software: `fyfAsk()` ersetzt 4 × `confirm()` (Startliste,
  Laden wieder öffnen, Auftrag stornieren, Anfrage bestätigen). Test `tests/e2e/t217.js`. Englisch ergänzt.
- **Offen in Paket 1:** `confirmDel()` in `index.html` (3 Stellen: Pass zurückziehen, Fahrradschein,
  Diebstahl) und die restlichen `alert()`-Hinweise im Pass (z. B. „Speicher voll“) auf `fyfAsk()`/`askYes()`.
- Vorher erledigt (v.215): Service-Liste mit dem Dringendsten oben, Terminschätzung aus der Fahrleistung,
  „Erledigt“ zurücknehmen (Test `t216.js`).
- **Paket 2 fertig (Paket 2 = Seitenkopf und Zurück, beide Apps):** `page()` im Pass zeigt unter jedem Titel einen
  Untertitel (`PAGE_SUB`, 30 Seiten, Englisch ergänzt); in der Software sind alle `confirmDel()`-Stellen auf
  `fyfAsk()` umgestellt (Pass zurückziehen, Fahrradschein, Diebstahl). Test `tests/e2e/t218.js`.
  Offen in Paket 2: gleiche Kopfzeile für Sheets (Dokument-Ansicht, Foto-Menü) und einheitliche Ladezustände.
- **Nächstes Paket: 3 – „auf einen Blick“ je Werkzeug** (2–4 Kennzahlen oben, eine Hauptaktion, gleicher leerer Zustand).
- Vorher erledigt (v.215): Service-Liste mit dem Dringendsten oben, Terminschätzung aus der Fahrleistung,
  „Erledigt“ zurücknehmen (Test `t216.js`).
- Nächstes Paket: **2 – Seitenkopf und Zurück** in Pass und Software (gleicher Kopf, gleiche Zurück-Pille,
  gleiche Sheets).
