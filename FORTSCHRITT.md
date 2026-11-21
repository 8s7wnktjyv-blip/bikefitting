# FYF – Fortschritt (maßgebliche Quelle)

Angelegt am 21.11.2026 aus den bisherigen Berichten (`docs/MASTER-BERICHT.md`, `docs/BERICHT-MASTER-PROMPTS-2026-11.md`, `docs/PLATTFORM.md`, `docs/ROADMAP-PASSPORT.md`) und dem Git-Verlauf.
Bei jedem Lauf „Stand“ und „Nächster Schritt“ aktualisieren.

## Stand

- Live (GitHub Pages aus Branch **`main`**): Händlersoftware `index.html` **v.128** (APP_VER 2026-11-21.128), Service-Worker-Cache `fyf-app-v1-p59`, Datenbank-Stand **26** in `docs/supabase/alles.sql` (eingespielt: 25 – Update auf 26 offen).
- Demo: https://8s7wnktjyv-blip.github.io/bikefitting/ · Pass: `rad.html` · Händlerfinder: `finder.html`
- Browser-Tests: `sh tests/e2e/run.sh` (8 Tests, iPhone-13-Größe, gegen `mock.js`), laufen bei jedem Push als GitHub-Action „Tests“.
- Weitere Branches: `plattform-neu` (Neubau, **nicht live**), `master-auftrag` (in `main` übernommen), `v59-cloud` (alt).
- Geplanter Task „FYF: Bauschritt (2× täglich)“ läuft im festen Chat (Archiv mit Schreibrecht), Mo–Sa 04:23 und 11:23 Uhr.

### Zuletzt erledigt
| Version | Inhalt |
|---|---|
| v.128 (21.11.) | Rollen Werkstattleitung, Verkauf, Filialleitung, Buchhaltung vergebbar (Team → Einladen/Rolle, ab DB-Stand 26) mit Server-Filter nach Weg A (`stand26.sql`): Werkstattleitung ohne Rechnungen/Zahlungen/Verkäufe/DATEV/Mahnwesen, Verkauf ohne DATEV/Mahnwesen, Filialleitung und Buchhaltung sehen alles. Mitarbeiter unverändert. Tests `stand26_test.sql` (Postgres 16 lokal) und `t128.js`. |
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
2. Rechte: Rollen fertig (v.128). Offen: Sollen Werkstattleitung, Verkauf, Filialleitung, Buchhaltung Körper-/Gesundheitsdaten sehen? Derzeit ja (wie Mitarbeiter). Ausblenden braucht Umbau in der App (Fitting-Daten liegen in `sessions`) → nur nach Entscheidung.
3. Kündigung eines Ladens: geprüft 21.11. – **Lücke**: Löschen eines Ladens löscht seine ausgestellten Pässe samt aller Einträge (`bike_passes` on delete cascade). Plan in `docs/KUENDIGUNG-PLAN.md`, wartet auf Freigabe (Datenmodell).
4. Händlerfinder mit Werkstatt-Bewertungen: fertig (v.124); Feinschliff nach Rückmeldung.

## Wartet auf Dominik

- Datenbank-Update auf Stand 26 einspielen (neue Rollen): GitHub → Actions → „Datenbank aktualisieren“ → Run workflow.
- Entscheidung Gesundheitsdaten für die neuen Rollen (siehe Punkt 2).
- Freigabe Kündigungs-Plan (`docs/KUENDIGUNG-PLAN.md`): „Kündigung: Schritt 1“ oder „Kündigung: alles“. Bis dahin keinen Laden im Supabase-Dashboard löschen.
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

Nach Freigabe: Kündigung laut `docs/KUENDIGUNG-PLAN.md`. Ohne Freigabe: Punkt 1 (Fehler/tote Knöpfe/Datensicherheit) – Rundgang durch Pass-App (`rad.html`) in Handy-Größe.
