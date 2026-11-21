# FYF – Fortschritt (maßgebliche Quelle)

Angelegt am 21.11.2026 aus den bisherigen Berichten (`docs/MASTER-BERICHT.md`, `docs/BERICHT-MASTER-PROMPTS-2026-11.md`, `docs/PLATTFORM.md`, `docs/ROADMAP-PASSPORT.md`) und dem Git-Verlauf.
Bei jedem Lauf „Stand“ und „Nächster Schritt“ aktualisieren.

## Stand

- Live (GitHub Pages aus Branch **`main`**): Händlersoftware `index.html` **v.127** (APP_VER 2026-11-21.127), Service-Worker-Cache `fyf-app-v1-p58`, Datenbank-Stand **25** (`docs/supabase/alles.sql`).
- Demo: https://8s7wnktjyv-blip.github.io/bikefitting/ · Pass: `rad.html` · Händlerfinder: `finder.html`
- Browser-Tests: `sh tests/e2e/run.sh` (7 Tests, iPhone-13-Größe, gegen `mock.js`), laufen bei jedem Push als GitHub-Action „Tests“.
- Weitere Branches: `plattform-neu` (Neubau, **nicht live**), `master-auftrag` (in `main` übernommen), `v59-cloud` (alt).
- Geplanter Task „FYF: Bauschritt (2× täglich)“ läuft im festen Chat (Archiv mit Schreibrecht), Mo–Sa 04:23 und 11:23 Uhr.

### Zuletzt erledigt
| Version | Inhalt |
|---|---|
| v.127 (21.11.) | Dominiks Grail CF 7 (M) hat Pedalsystem „Shimano SPD“ in den festen Demodaten; bestehende Daten nur ergänzt, wenn das Feld leer ist (Merker `fixPedal1`). Test `t127.js`. |
| v.126 | Tab5-Station: Einwilligung mit Unterschrift wird beim Kunden gespeichert; FYF Station v0.4.6 in `station/` |
| v.125 | Rechte auf dem Server (Weg A, Stand 25): `state_get` filtert je Rolle |
| v.124 | Werkstatt-Bewertungen im Pass und Händlerfinder (Stand 24) |
| v.121–123 | Mahnwesen, Zahlungsabgleich, Arbeitszeit, Leihräder, Cockpit-Vergleich |
| bereits vorhanden | Marken-/Modellauswahl in Händlersoftware und Pass |

### Erledigt durch Dominik (21.11.)
- Datenbank auf Stand 25 eingespielt (Lauf erfolgreich, 14:46 Uhr).
- Impressum vollständig; Verantwortlicher im Datenschutz eingetragen (USt-IdNr. keine angegeben).

## Freigegebene offene Punkte (Reihenfolge = Vorrang)

1. Fehler / nicht funktionierende Knöpfe / Datensicherheit – laufend prüfen.
2. Rechte: Rollen Werkstattleitung, Verkauf, Filialleitung, Buchhaltung – auf dem Server nach Weg A filtern; Stand in `team.sql`/`state_get` prüfen, fehlende Rollen ergänzen.
3. Kündigung eines Ladens: Pass-Einträge bleiben, Laden sieht danach nichts mehr – Umsetzung auf dem Server prüfen und testen.
4. Händlerfinder mit Werkstatt-Bewertungen: fertig (v.124); Feinschliff nach Rückmeldung.

## Wartet auf Dominik

- Neubau `plattform-neu`: Freigabe/Weiterführung offen (großer Umbau, nicht eigenmächtig).
- Datenschutz: noch offen sind Vertrag zur Auftragsverarbeitung mit Supabase, Mailversand-Dienst und Speicherort der Sicherung; danach rechtlich prüfen lassen.
- Test auf echtem iPhone/Android.
- Käuferschutz Marktplatz: nur extern (Kandidat Trustap).

## Entscheidungen (verbindlich)

- Preise: Händler 99 €/Standort/Monat ohne Fitting-Modul, 149 € mit; Einrichtung 99 €; Schulung 49 €/Mitarbeiter; Jahresvertrag mit Rabatt zusätzlich zum monatlich kündbaren Abo; Endkunden kostenlos; QR-Aufkleber 4,99 €, 2er-Set 7,99 €; Fitting 200 € bei FYF / 250 € im Laden (50 € an den Laden); Empfehlung 30 €. Alle zzgl. MwSt.
- Rechte Weg A (Rollen-Filter auf dem Server, kein Tabellen-Umbau); Mitarbeiter sehen Körper-/Gesundheitsdaten der Fitting-Kunden.
- KI nur regelbasiert. Supabase nur kostenlos. Keine kostenpflichtigen Dienste.
- Marktplatz: FYF verwahrt kein Geld.
- Keine E-Bike-Fittings; Fitting nur mit Fitter; keine Diagnosen.
- Dominik Böhm bleibt fest in der Demo (Canyon Grail CF 7, M, SPD) – `permanentData()`/`ensurePermanent()` in `index.html`, nie überschreiben.
- Größere Umbauten und Serverumzug (ab Januar 2027) nur als Plan in `docs/` mit Freigabe.

## Nächster Schritt

Punkt 2: prüfen, ob die Rollen Werkstattleitung, Verkauf, Filialleitung und Buchhaltung in `team.sql`/`state_get` und in der App vorhanden sind; fehlende serverseitig nach Weg A ergänzen und mit Datenbank- und Browser-Test absichern.
