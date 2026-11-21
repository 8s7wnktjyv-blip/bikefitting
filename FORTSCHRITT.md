# FYF – Fortschritt (maßgebliche Quelle)

Angelegt am 21.11.2026 aus den bisherigen Berichten (`docs/MASTER-BERICHT.md`, `docs/BERICHT-MASTER-PROMPTS-2026-11.md`, `docs/PLATTFORM.md`, `docs/ROADMAP-PASSPORT.md`) und dem Git-Verlauf.
Bei jedem Lauf „Stand“ und „Nächster Schritt“ aktualisieren.

## Stand

- Live (GitHub Pages aus Branch **`main`**): Händlersoftware `index.html` **v.135** (APP_VER 2026-11-21.135), Service-Worker-Cache `fyf-app-v1-p66`, Datenbank-Stand **28** in `alles.sql` (eingespielt: 27 – Update auf 28 offen).
- Demo: https://8s7wnktjyv-blip.github.io/bikefitting/ · Pass: `rad.html` · Händlerfinder: `finder.html`
- Browser-Tests: `sh tests/e2e/run.sh` (14 Tests, iPhone-13-Größe, gegen `mock.js`), laufen bei jedem Push als GitHub-Action „Tests“.
- Weitere Branches: `plattform-neu` (Neubau, **nicht live**), `master-auftrag` (in `main` übernommen), `v59-cloud` (alt).
- Geplanter Task „FYF: Bauschritt (2× täglich)“ läuft im festen Chat (Archiv mit Schreibrecht), Mo–Sa 04:23 und 11:23 Uhr.

### Zuletzt erledigt
| Version | Inhalt |
|---|---|
| v.135 (21.11.) | Termin im Pass (Punkt 10): Läden veröffentlichen freie Zeiten schon (Software → Kalender → freie Zeiten online), der Finder zeigte sie. Neu: bei fälliger Wartung zeigt der Pass die nächsten 3 freien Termine des eigenen Ladens; Tippen öffnet die Anfrage mit vorausgewähltem Termin; vergebener Termin → Hinweis. Der Laden bestätigt wie bisher (keine automatische Reservierung – das wäre ein Datenmodell-Umbau). Test `t135.js`. |
| v.134 (21.11.) | Bestellvorschlag (Punkt 9): Vorschlag je Lieferant und „Aus Bestellvorschlag anlegen“ gab es schon. Fehler behoben: bereits bestellte, noch nicht gelieferte Mengen (auch Teillieferungen) werden abgezogen – keine Doppelbestellungen mehr; Hinweis „schon bestellt“. Test `t134.js`. |
| v.133 (21.11.) | Ersatzrad anfragen (Punkt 8): Pass – solange das Rad beim eigenen Laden in Arbeit ist (Besitzer-Ansicht), Knopf „Ersatzrad für die Zeit anfragen“ → Finder mit fertigem Text; Software – Anfrage zeigt „Ersatzrad gewünscht“ mit freien Leihrädern. Test `t133.js`. |
| v.132 (21.11.) | Auftragsstatus im Pass (Punkt 7): Befund – der Besitzer sieht laufende Aufträge schon seit Stand 18 (Server spiegelt Aufträge, `pass_get_owner`, nur mit Besitzer-Code, ohne Preise). Lücke behoben (`stand28.sql`): „Wartet auf Teile“ kommt jetzt beim Besitzer an. Bewusst NICHT in den öffentlichen Pass geschrieben (sonst sähe jeder mit Pass-Code den Status). Test `stand28_test.sql`. |
| v.131 (21.11.) | Saison-Check (Punkt 6): Software – Werkstatt zeigt „Saison-Check Frühjahr/Herbst“ mit allen Kunden mit Einwilligung zur Service-Erinnerung (ohne Einwilligung nur Anzahl, nicht anschreiben), fertiger Text mit Abmelde-Hinweis, WhatsApp/SMS/E-Mail öffnet der Laden selbst, „Erledigt“, CSV (Formeln entschärft). Pass – bei fälliger Wartung „Bei <Laden> anfragen“ direkt zum eigenen Laden (Finder-Adresse kommt mit dem Pass, sobald das Profil öffentlich ist und der Pass das nächste Mal aktualisiert wird), daneben „Andere Werkstatt wählen“; Finder schreibt die fälligen Punkte in die Anfrage. Test `t131.js`. |
| v.130 (21.11.) | Werkstatt-Tafel (Punkt 5): Werkstatt → „Werkstatt-Tafel“. Spalten Angenommen / In Arbeit / Wartet auf Teile / Abholbereit, Filter je Mechaniker, Knopf schiebt weiter (gleiche Regeln wie im Auftrag), „Teile sind da“, Abholbereit öffnet die Übergabe, Vollbild (wo der Browser es kann), aktualisiert jede Minute. Handy: Spalten untereinander, großer Bildschirm: 4 nebeneinander. Test `t130.js`. |
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
5. ✅ **Werkstatt-Tafel** (fertig v.130) (Software): Großansicht für einen Bildschirm in der Werkstatt, Spalten angenommen / in Arbeit / wartet auf Teile / abholbereit, Antippen schiebt weiter.
6. ✅ **Saison-Check** (fertig v.131) (Pass + Software): Pass zeigt „Service fällig – beim Laden anfragen“ (ein Tippen); Software: Liste der Kunden mit fälligem Service, Laden verschickt selbst (FYF versendet nichts).
7. ✅ **Auftragsstatus im Pass** (fertig v.132) („in Arbeit“, „abholbereit“) automatisch aus dem Werkstattauftrag (Status-Link gibt es schon).
8. ✅ **Ersatzrad anfragen** (fertig v.133) im Pass während der Reparatur (Leihräder der Software).
9. ✅ **Bestellvorschlag bei Mindestbestand** (fertig v.134) je Lieferant (Software).
10. ✅ **Termin direkt im Pass buchen** (fertig v.135, Bestätigung durch den Laden): freie Werkstatt-Termine des Ladens sehen und buchen (Auslastung aus der Software).
11. ◐ **Geprüfte Historie für Käufer** (geprüft 21.11.: Historie mit Kennzeichnung, Kauf-Check, Kaufvertrag gibt es schon; zeitlich begrenzter Käufer-Link als Plan `docs/KAEUFER-LINK-PLAN.md`, wartet auf Freigabe): Käufer scannt QR und sieht die werkstattbestätigte Historie (ohne Preise/Belege, nur mit Freigabe des Besitzers).
12. **Hol- und Bringservice** (Software): Abholtermine, Tagesliste mit Adressen.
13. **Datenübernahme aus Altsystem**: Kunden und Räder als CSV mit Vorschau und Prüfung.
14. **Pass auf Englisch**: größer – erst Plan in `docs/`, dann bauen.
Regeln dafür: keine bezahlten Dienste, kein Versand durch FYF, keine neuen Preise, nichts entfernen.

## Wartet auf Dominik

- Freigabe Käufer-Link auf Zeit (`docs/KAEUFER-LINK-PLAN.md`): „Käufer-Link: ja/nein“.
- Datenbank-Update auf Stand 28 einspielen (Auftragsstatus „Wartet auf Teile“ im Pass): GitHub → Actions → „Datenbank aktualisieren“ → Run workflow.
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

Punkt 12: Hol- und Bringservice (Software).
