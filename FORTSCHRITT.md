# FYF – Fortschritt (maßgebliche Quelle)

Angelegt am 21.11.2026 aus den bisherigen Berichten (`docs/MASTER-BERICHT.md`, `docs/BERICHT-MASTER-PROMPTS-2026-11.md`, `docs/PLATTFORM.md`, `docs/ROADMAP-PASSPORT.md`) und dem Git-Verlauf.
Bei jedem Lauf „Stand“ und „Nächster Schritt“ aktualisieren.

## Stand

- Live (GitHub Pages aus Branch **`main`**): Händlersoftware `index.html` **v.129** (APP_VER 2026-11-21.129), Service-Worker-Cache `fyf-app-v1-p60`, Datenbank-Stand **27** (eingespielt 21.11.).
- Demo: https://8s7wnktjyv-blip.github.io/bikefitting/ · Pass: `rad.html` · Händlerfinder: `finder.html`
- Browser-Tests: `sh tests/e2e/run.sh` (9 Tests, iPhone-13-Größe, gegen `mock.js`), laufen bei jedem Push als GitHub-Action „Tests“.
- Weitere Branches: `plattform-neu` (Neubau, **nicht live**), `master-auftrag` (in `main` übernommen), `v59-cloud` (alt).
- Geplanter Task „FYF: Bauschritt (2× täglich)“ läuft im festen Chat (Archiv mit Schreibrecht), Mo–Sa 04:23 und 11:23 Uhr.

### Zuletzt erledigt
| Version | Inhalt |
|---|---|
| v.129 (21.11.) | Kündigung (Freigabe 21.11.): Plattform-Admin kann einen Laden schließen und wieder öffnen (`stand27.sql`). Geschlossen: Team, Einladungen, Kopplungscodes gesichert und entfernt → Laden sieht nichts; Profil offline, Börsen-Angebote beendet; Pässe und alle Einträge bleiben; Daten bleiben für die Aufbewahrung. Ex-Mitglied sieht „Zugang beendet“ und kann Daten als Datei sichern. Zusätzlich: Löschen eines Ladens löscht keine Pässe mehr. Tests `stand27_test.sql`, `t129.js`. |
| v.128 (21.11.) | Rollen Werkstattleitung, Verkauf, Filialleitung, Buchhaltung vergebbar (Team → Einladen/Rolle, ab DB-Stand 26) mit Server-Filter nach Weg A (`stand26.sql`): Werkstattleitung ohne Rechnungen/Zahlungen/Verkäufe/DATEV/Mahnwesen, Verkauf ohne DATEV/Mahnwesen, Filialleitung und Buchhaltung sehen alles. Mitarbeiter unverändert. Tests `stand26_test.sql` (Postgres 16 lokal) und `t128.js`. |
| v.127 (21.11.) | Dominiks Grail CF 7 (M) hat Pedalsystem „Shimano SPD“ in den festen Demodaten; bestehende Daten nur ergänzt, wenn das Feld leer ist (Merker `fixPedal1`). Test `t127.js`. |
| v.126 | Tab5-Station: Einwilligung mit Unterschrift wird beim Kunden gespeichert; FYF Station v0.4.6 in `station/` |
| v.125 | Rechte auf dem Server (Weg A, Stand 25): `state_get` filtert je Rolle |
| v.124 | Werkstatt-Bewertungen im Pass und Händlerfinder (Stand 24) |
| v.121–123 | Mahnwesen, Zahlungsabgleich, Arbeitszeit, Leihräder, Cockpit-Vergleich |
| bereits vorhanden | Marken-/Modellauswahl in Händlersoftware und Pass |

### Erledigt durch Dominik (21.11.)
- Datenbank auf Stand 26 und 27 eingespielt (Rollen und Kündigung live); Kündigungs-Plan und neue Funktionen 5–14 freigegeben.
- Datenbank auf Stand 25 eingespielt (Lauf erfolgreich, 14:46 Uhr).
- Impressum vollständig; Verantwortlicher im Datenschutz eingetragen (USt-IdNr. keine angegeben).

## Freigegebene offene Punkte (Reihenfolge = Vorrang)

1. Fehler / nicht funktionierende Knöpfe / Datensicherheit – laufend prüfen. Rundgang 21.11. (v.128, iPhone-13-Größe): Pass-App – alle Knöpfe der Radseite und aller 7 Werkzeuge unter „Mehr Funktionen“ ohne JS-Fehler und ohne Querscrollen; Händlersoftware – alle 33 Bereiche ohne Fehler und ohne Querscrollen. Kein Befund.
2. Rechte: Rollen fertig (v.128). Entscheidung 21.11.: neue Rollen sehen Körper-/Gesundheitsdaten wie Mitarbeiter (so belassen).
3. Kündigung eines Ladens: fertig (v.129, Stand 27), siehe `docs/KUENDIGUNG-PLAN.md`.
4. Händlerfinder mit Werkstatt-Bewertungen: fertig (v.124); Feinschliff nach Rückmeldung.

### Neue Funktionen (alle freigegeben von Dominik am 21.11.2026, in dieser Reihenfolge bauen)
5. **Werkstatt-Tafel** (Software): Großansicht für einen Bildschirm in der Werkstatt, Spalten angenommen / in Arbeit / wartet auf Teile / abholbereit, Antippen schiebt weiter.
6. **Saison-Check** (Pass + Software): Pass zeigt „Service fällig – beim Laden anfragen“ (ein Tippen); Software: Liste der Kunden mit fälligem Service, Laden verschickt selbst (FYF versendet nichts).
7. **Auftragsstatus im Pass** („in Arbeit“, „abholbereit“) automatisch aus dem Werkstattauftrag (Status-Link gibt es schon).
8. **Ersatzrad anfragen** im Pass während der Reparatur (Leihräder der Software).
9. **Bestellvorschlag bei Mindestbestand** je Lieferant (Software).
10. **Termin direkt im Pass buchen**: freie Werkstatt-Termine des Ladens sehen und buchen (Auslastung aus der Software).
11. **Geprüfte Historie für Käufer**: Käufer scannt QR und sieht die werkstattbestätigte Historie (ohne Preise/Belege, nur mit Freigabe des Besitzers).
12. **Hol- und Bringservice** (Software): Abholtermine, Tagesliste mit Adressen.
13. **Datenübernahme aus Altsystem**: Kunden und Räder als CSV mit Vorschau und Prüfung.
14. **Pass auf Englisch**: größer – erst Plan in `docs/`, dann bauen.
Regeln dafür: keine bezahlten Dienste, kein Versand durch FYF, keine neuen Preise, nichts entfernen.

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

Punkt 5: Werkstatt-Tafel.
