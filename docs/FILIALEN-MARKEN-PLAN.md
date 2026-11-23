# Mehrere Filialen und Marken in einem Konto – Plan

Stand 23.11.2026 · Wunsch Dominik: „Verschiedene Filialen in einem Account verwalten, darunter eigene Marken führen oder eine andere Filiale, die in der App trotzdem einzeln angezeigt wird. Z. B. Hauptaccount für Fitting und darin Cunuma, wo ich Laufräder über den Marktplatz anbiete.“

**Status: freigegeben (Dominik 23.11.2026, 07:22).**

## Ziel
Ein Login, ein Konto (Betrieb) – darunter beliebig viele **Auftritte**:

| Art | Beispiel | Im Händlerfinder („Werkstätten“) | Im Marktplatz | Adresse nötig |
|---|---|---|---|---|
| **Filiale** | „FYF Erlangen“, zweiter Laden | ja, eigene Karte mit Leistungen, Öffnungszeiten, Bewertungen | ja | ja |
| **Marke** | „Cunuma“ (Laufräder) | nein | ja, eigener Name, Logo, Beschreibung | nein |

Kunden sehen jeden Auftritt einzeln. Der Betrieb sieht alles in einer Software und schaltet oben zwischen „Alle“ und einem Auftritt um.

## Was es heute schon gibt (geprüft)
- Händlersoftware: **Filialen** im Konto (Name, Adresse), Gerät einer Filiale zuordnen, Bestand je Filiale, Vergleich (seit v.70).
- Datenbank: Tabelle `locations` (je Konto) und `subscriptions` (Abo **je Standort**, 99/149 €).
- Öffentliches Profil (`dealer_profiles`): **nur eins je Konto** – das ist die eigentliche Lücke.

## Umbau (Schritte)
1. **Datenbank (`standNN.sql`, mit Test):**
   - `locations` bekommt `kind` (`filiale`/`marke`), `logo`, `slug`.
   - `dealer_profiles` wird **je Auftritt** geführt (`location_id`); das bisherige Profil wird automatisch der ersten Filiale zugeordnet → nichts geht verloren, Links bleiben gültig.
   - Bewertungen, Anfragen, Marktplatz-Angebote und Pass-Einträge merken sich den Auftritt (`location_id`, optional; alte Einträge = Hauptfiliale).
   - Rechte: Rolle „Filialleitung“ kann auf eine Filiale beschränkt werden (Weg A bleibt).
2. **Händlersoftware:** Umschalter „Alle / FYF / Cunuma …“ oben; „Auftritte verwalten“ (anlegen, Art, Logo, veröffentlichen); Profil-Editor je Auftritt; Marktplatz-Angebot wählt den Auftritt; Rechnungen tragen Name/Logo des Auftritts (gleiche Firma, gleiche Steuernummer, Hinweis „eine Marke von …“).
3. **Pass / Händlerfinder:** Filialen erscheinen einzeln; Marken nur im Marktplatz mit eigener Seite („Alle Angebote von Cunuma“); Bewertungen je Filiale.
4. **Tests:** Datenbank-Test (Umstellung ohne Datenverlust, Rechte je Filiale), Browser-Tests für Umschalter, Profil je Auftritt, Marktplatz-Zuordnung.

## Rechtliches (Einschätzung, keine Rechtsberatung)
- Eine Marke ohne eigene Firma ist ein Name desselben Unternehmens: Impressum und Rechnung nennen das Unternehmen (Dominik Böhm, Anschrift) mit Zusatz „Cunuma ist eine Marke von …“.
- Marktplatz bleibt wie festgelegt: FYF verwahrt kein Geld, Kauf direkt beim Anbieter.
- Für Laufräder als Neuware gelten Widerrufsrecht und Gewährleistung beim Online-Verkauf – Texte vor dem Start prüfen lassen.

## Entscheidungen (Dominik 23.11.2026)
1. **Preis:** Für FYF selbst (Dominiks eigenes Konto, Plattform-Admin) sind alle Filialen und Marken **kostenlos**. **Alle anderen Betriebe zahlen je Auftritt wie je Standort: 99 € ohne / 149 € mit Fitting-Modul** – das gilt für jede Filiale und auch für jede Marke (kein neuer Preis). In der Software beim Anlegen klar anzeigen: „Jeder weitere Auftritt kostet 99 €/149 € im Monat“ (bei FYF selbst: „kostenlos“).
2. **Reihenfolge:** direkt nach Punkt 17 (alle Läden im Händlerfinder), vor Punkt 18 ff.
3. **Sonst:** „so umsetzen, dass es Sinn macht“ – Details nach bestem Urteil im Rahmen dieses Plans und der festen Regeln (keine Daten verlieren, keine Funktionen entfernen, Datenbank-Update mit Test, Dominik spielt es ein).
