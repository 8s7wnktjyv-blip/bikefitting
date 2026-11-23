# Plan: „Helfer in der Nähe“ unabhängig von überlasteten Servern (zur Freigabe)

Stand 23.11.2026. **Noch nicht umgesetzt, bitte freigeben.**

## Problem
Die Orte (Luftpumpen, Schlauch-Automaten, Werkstätten, Krankenhäuser …) kommen live von den kostenlosen OpenStreetMap-Servern (Overpass).
Am 23.11. gegen 3:30 Uhr waren alle drei getesteten öffentlichen Server überlastet („at capacity“) oder gaben keine Antwort.
Dann findet die App nichts, und es helfen nur die Apple-Karten-Knöpfe (seit v.201/v.202).

## Vorschlag
1. Eine kostenlose GitHub-Aktion holt **einmal pro Woche** alle Orte in Deutschland, Österreich und der Schweiz.
   Sie wartet geduldig, bis ein Server frei ist, und legt die Orte als kleine Dateien ins Archiv, z. B. `helfer/47_11.json` für je 1 × 1 Grad.
   Schätzung: zusammen ca. 1–2 MB. Ein Handy lädt nur die 1–4 Dateien rund um den Standort, also ca. 20–100 KB.
2. Die App sucht zuerst in diesen Dateien. Das geht sofort, auch nachts. Der Standort verlässt das Handy dabei **gar nicht** (besser für den Datenschutz).
3. Nur außerhalb von DACH oder bei fehlender Datei fragt die App wie heute live bei Overpass.

## Kosten und Aufwand
- 0 €: GitHub Actions und GitHub Pages sind im kostenlosen Rahmen, die OSM-Daten stehen unter ODbL mit Namensnennung (ist schon in der App).
- Aufwand: etwa ein Arbeitsblock. Dominik muss nichts tun außer freigeben.
- Nachteil: Die Daten sind bis zu 1 Woche alt. Für Luftpumpen und Automaten reicht das.

## Nicht gewählt
- Server `maps.mail.ru` (antwortet zwar, steht aber in Russland: Standortdaten dorthin zu schicken ist datenschutzrechtlich nicht vertretbar).
- Bezahlte Kartendienste (verboten laut Regeln).
