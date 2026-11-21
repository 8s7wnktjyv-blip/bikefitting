# Plan: Fahrradpass auf Englisch (Punkt 14, freigegeben 21.11.2026 – „erst Plan, dann bauen“)

Stand 21.11.2026

## Ausgangslage
- `rad.html` (Pass-App, ca. 450 KB) und `finder.html` (Händlerfinder) sind komplett auf Deutsch, Texte stehen direkt im Code.
- Geschätzt **1.400–1.600 Texte** (Knöpfe, Hinweise, Hilfe, Fehlermeldungen, Verkaufs- und Vertragstexte).
- Datumsformat fest auf Deutsch.

## Vorgehen (ohne Umbau der App, ohne bezahlten Dienst, ohne KI-Übersetzung zur Laufzeit)
1. **Sprachumschalter** in den Einstellungen des Passes: Deutsch / English. Voreinstellung nach Handy-Sprache, Wahl wird auf dem Gerät gespeichert. Fehlt eine Übersetzung, erscheint Deutsch – nichts geht kaputt.
2. **Wörterbuch** `pass-en.js` (Deutsch → Englisch), wird nur geladen, wenn Englisch gewählt ist. Übersetzt beim Anzeigen alle sichtbaren Texte, Knöpfe und Hinweise.
3. **Stufen** (je ein Lauf, jeweils getestet und einzeln nutzbar):
   - Stufe 1: Start, Garage, Radseite, Service, Kilometer, Diebstahl-Notfall, Einstellungen.
   - Stufe 2: Belege, Kosten, Ausstattung, Setups, Werkstatt-Status, Termin/Ersatzrad, Händlerfinder.
   - Stufe 3: Verkaufen (Anzeigentext, Kauf-Check), Hilfe.
4. **Bewusst Deutsch bleiben:** Kaufvertrag und rechtliche Texte (Datenschutz, Impressum) – eine englische Fassung ersetzt nicht die deutsche Rechtslage. Hinweis „Legal texts in German“.
5. **Einträge der Werkstätten** (z. B. „Kette getauscht“) bleiben wie eingetragen – das ist Inhalt, keine Oberfläche.

## Tests
Browser-Test je Stufe: Umschalten, alle Knöpfe der Stufe ohne Fehler, keine deutschen Reste auf den übersetzten Seiten (Liste erlaubter Ausnahmen), Rückschalten auf Deutsch.

## Was ich von Dominik brauche
- Freigabe: **„Englisch: Stufe 1 bauen“** (oder alle Stufen).
- Optional: Wer prüft die englischen Texte einmal gegen? (Muttersprachler/Kunde) – sonst bleibt es bei meiner Übersetzung.
