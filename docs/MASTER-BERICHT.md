# FYF – Master-Auftrag: Bericht (Stand 11.11.2026, Branch `master-auftrag`)

Alle Änderungen liegen auf dem Git-Branch **`master-auftrag`** – **nicht live**. Die Live-Seite (Branch `main`) ist unverändert, bis du den Branch freigibst.

---

## 0. Bestandsaufnahme (was geprüft wurde)

| Bereich | Ergebnis |
|---|---|
| Händler-Software `index.html` (1,2 MB, 33 Bereiche) | Alle 33 Bereiche automatisch geöffnet (Desktop 1280 px + Handy 390 px): **0 tote Knöpfe, 0 Formulare ohne Funktion, 0 tote Menülinks, 0 JS-Fehler, kein seitliches Verrutschen** |
| Klick-Test | **552 Knöpfe** in allen Bereichen gedrückt: keine JS-Fehler, keine toten Elemente in geöffneten Fenstern (eine Meldung betrifft nur das Test-Werkzeug bei einer SVG-Grafik) |
| Bestehende Prüfsuite | 41/41 (Mobil) und 41/41 (Desktop) bestanden |
| Pass-App `rad.html`, `finder.html`, `status.html`, `portal.html`, `freigabe.html` | geprüft; **eine Sicherheitslücke gefunden und behoben** (siehe 2.) |
| Datenbank (12 SQL-Dateien, 26 Tabellen) | **Alle 26 Tabellen mit Row Level Security.** Anonymer Lesezugriff nur auf `dealer_profiles` (nur veröffentlichte) und `public_products` – gewollt. 64 Security-Definer-Funktionen, alle mit festem `search_path`. |
| Geheimnisse | Keine Secrets im Code. Nur der öffentliche Supabase-Schlüssel ist eingebaut; geheime Schlüssel (`sb_secret_`, `service_role`) werden aktiv abgewiesen. GitHub-Action nutzt `secrets.SUPABASE_DB_URL`. |

### Zentrale Fahrradidentität (Architektur – Ist-Stand und Entscheidung)
- **Fahrrad-ID im Ökosystem = Fahrradpass-Code** (8 Zeichen, eindeutig, Tabelle `bike_passes`, Primärschlüssel).
- Jede Werkstatt führt das Rad intern unter ihrer eigenen Rad-ID (`bike_ref`) – Verknüpfung `(tenant_id, bike_ref) → code` ist eindeutig.
- **Doppelte Akten werden verhindert** über den Rahmennummer-Hash (`frame_hash`): Selbst-Registrierung einer schon bekannten Rahmennummer wird abgelehnt.
- **Werkstattwechsel / mehrere Werkstätten**: Übergabe mit `pass_handover` (Teil II), alte Werkstatt wird `bike_pass_moved`; verifizierte Werkstätten können Einträge nachtragen.
- **Historie unveränderlich**: Einträge in `bike_pass_entries` sind per Trigger gesperrt; Korrekturen nur als neuer Eintrag mit Verweis (`corrects`) – nichts ändert sich unbemerkt.
- **Vertrauensstufen**: `self` (Selbstauskunft), `shop` (Werkstatt), `verified` (verifizierte Werkstatt). *Verifizierte Herstellerdaten* gibt es noch nicht (keine rechtmäßige Datenquelle angebunden).
- **Datenschutz**: Kundendaten (Name, Kontakt, Körpermaße) bleiben in der Werkstatt-Akte. Der Pass enthält nur Rad-Daten; Fitting-Werte nur mit Zustimmung des Kunden.
- **Entscheidung**: Kein zweites Fahrrad-Datenmodell gebaut. Die Pass-App liest die Werkstatt-Daten direkt aus dem Pass (Service, Teile, Ausstattung, Akku, km, Fitting) – eine Quelle, keine Doppelpflege.

---

## 1. Alle vorgenommenen Änderungen (dieser Auftrag)
1. Sicherheit: öffentliche Seiten laden Daten nur noch vom offiziellen FYF-Server (`rad.html`, `finder.html`, `status.html`, `portal.html`, `freigabe.html`).
2. Pass-App: **Zustandsbericht** (Bike Health Score).
3. Pass-App: **Fitting-Verlauf** – alle Fittings im Vergleich mit Änderungen.
4. Pass-App: **Fundmeldung mit freiwilligem Finder-Kontakt** (nur für den Besitzer sichtbar), Kennzeichnung „unbestätigte Meldung“.
5. Pass-App: Anleitung „So funktioniert’s“ um Zustandsbericht und Teil-II-Ersatz ergänzt.
6. Händler-Software: **Werkstatt-Copilot** (regelbasiert) im Bereich KI-Assistent.
7. Händler-Software: **Kompatibilitäts-Prüfung** (9 Prüfungen) im Bereich Werkstatt.
8. Händler-Software: **Teil II nach Eigentumsprüfung neu ausstellen** im Bereich FYF Fahrradpass.
9. Datenbank: `funde.sql` erweitert (siehe 7.).
10. Textfehler im KI-Assistenten behoben („… ist integration nötig“).
11. **Hersteller-QR am Rahmen** (z. B. Canyon, enthält die Rahmennummer als Text): Beim Registrieren „Rahmennummer per QR scannen“; unter „Rad prüfen“ findet der Scan des Hersteller-QR (oder die eingetippte Rahmennummer) den passenden FYF-Pass – Diebstahl-Check auch ohne FYF-Aufkleber. Neue Datenbank-Funktion `pass_find_frame` (nur Hash wird übertragen).

Davor heute bereits live (main): QR-Scanner, Fundmeldung, Kauf-Check + Kaufvertrag, Besitzer-Code merken, Pass-Vollständigkeit, Sichern/Wiederherstellen, Garage teilen, automatische Übernahme von Werkstatt-/Fitting-Daten, Besitzer-Vollansicht.

## 2. Behobene Fehler
| Fehler | Auswirkung | Behebung |
|---|---|---|
| Öffentliche Seiten akzeptierten beliebigen Server über Link-Parameter `cfg` | Gefälschter QR-Aufkleber hätte unter der FYF-Adresse falsche Daten (z. B. „Keine Diebstahlmeldung“) zeigen können | Nur noch offizieller Server + localhost (Test) erlaubt |
| Fitting-Abschluss kam nicht automatisch in den Pass | Kunde sah Fitting-Werte nicht | Abschluss löst Pass-Aktualisierung aus (heute, main) |
| Besitzer sah bei „Nur Werkstätten“ nichts | Daten der Werkstatt unsichtbar | `pass_get_owner` (heute, main) |
| Copilot-Entwurf „über 0,00 €“ bei Rechnungen ohne Summe | falscher Betrag im Text | Betrag nur, wenn > 0 |
| Textfehler KI-Hinweis | unverständlich | korrigiert |

## 3. Neue Funktionen
- **A. Zustandsbericht (Health Score)**: Wert 0–100 nur aus dokumentierten Faktoren: letzte Inspektion, Wartungsplan (nur Besitzer), gemessener Kettenverschleiß, Schäden (mit/ohne späteren Reparatureintrag), Akku-Zustand (E-Bikes), Werkstatt-Nachweise. **Fehlende Daten = „unbekannt“, zählen nicht.** Unter 2 bekannten Faktoren kein Wert. Für Besitzer und (bei freigegebenem Pass) für Käufer sichtbar. Hinweis „kein Gutachten“.
- **B. Kompatibilität**: Fach-Zahl Antrieb, Kassette↔Freilauf (inkl. 1,85-mm-Spacer-Fälle, 10er-Ritzel), Bremsscheibe↔Nabe, Bremsscheibe↔Aufnahme (Post-Mount-Adapter, Max-Größe), Achsstandard, Sattelstütze↔Sitzrohr, Lenker↔Vorbau, Gabelschaft↔Steuerrohr, Reifen↔Rahmen/Hookless. Status: passt / passt mit Adapter / passt nicht / **ungeprüft** (wenn Daten fehlen oder Herstellerfreigabe nötig, z. B. Carbon).
- **C. Werkstatt-Copilot** (regelbasiert, kein Sprachmodell): überfällige Aufträge, fehlende Freigaben (Kostenvoranschlag > 3 Tage), fehlende Teile für offene Aufträge gegen Lager, Lager unter Mindestbestand, überfällige Rechnungen, offene Garantiefälle > 14 Tage, fällige Nachkontrollen. „Nachricht entwerfen“ erzeugt nur einen Entwurf zum Kopieren. **Versendet, bucht oder schließt nichts.** Kunden-Erinnerungen bleiben auf dem Dashboard (keine Doppelung).
- **D. Wartungsassistent**: Pass-App „Service“ (bereits vorhanden) – Richtwerte klar gekennzeichnet, Werkstatt-Einträge zählen automatisch.
- **E. Diebstahl/Wiedererkennung**: Finder kann den Besitzer erreichen, ohne dessen Daten zu sehen (Fundmeldung, optional Finder-Kontakt). Schutz vor Missbrauch: nur bei aktiv gestohlenen Rädern, max. 10 Meldungen/Stunde je Rad, 500/Stunde gesamt, Kennzeichnung „unbestätigt“. Statushistorie über unveränderliche Einträge („Diebstahl gemeldet/aufgehoben“).
- **Eigentum / Teil II verloren**: Verifizierte Werkstatt stellt nach Prüfung vor Ort (Rahmennummer-Hash muss passen, Rad nicht gestohlen) neuen Übergabe-Code aus; alter Code ungültig; unveränderlicher Pass-Eintrag + Protokoll; max. 20/Tag je Werkstatt.
- **F. Bikefitting**: Fitting-Verlauf im Pass (Werte je Fitting, Differenz zum vorherigen); in der Händler-Software bestehen Vorher/Nachher und „Mit Vorsitzung vergleichen“ bereits.

## 4. Offene technische Abhängigkeiten
- Datenbank-Update **Stand 14** (GitHub Action) – sonst sind Fundmeldung, Rahmennummer-Abgleich, Besitzer-Vollansicht, Teil-II-Ersatz nicht aktiv (die Apps zeigen dann „bald verfügbar“).
- Deine Werkstatt muss als **verifiziert** markiert sein (Plattform-Admin), damit Teil-II-Ersatz geht.
- QR-Scanner auf iPhone lädt die Bibliothek `jsQR` von jsdelivr (Android nutzt den eingebauten Scanner).
- Echte KI (Sprachmodell) für den Copilot: braucht API-Zugang und Kosten-Freigabe.
- Zahlungsanbieter mit Käuferschutz (Marktplatz): Vertrag, Gebühren, API, Recht klären.

## 5. Nicht umgesetzt – mit Begründung
| Funktion | Grund |
|---|---|
| Hersteller-/Produktdaten, Rückrufe, Anleitungen (G) | Keine rechtmäßige Datenquelle/Vertrag vorhanden – nichts erfunden. Grundlage: Kompatibilitätsregeln auf Normen, erweiterbar. |
| Echte KI im Copilot | Kosten + API-Schlüssel nötig (deine Freigabe) |
| Käuferschutz/Zahlung im Marktplatz (Abschnitt 10) | Erst nach Klärung Anbieter/Vertrag/Recht; kein eigenes Treuhandsystem |
| Endkunden-Konto mit Login | Von dir auf später verschoben; technisch mit Supabase-Anmeldung per E-Mail-Link möglich |
| Push-Nachrichten | braucht Server-Zeitplan; derzeit Kalender-Erinnerungen |
| Kompletter Design-Umbau der Händler-Software | Automatische Prüfung ohne Befund; ein großer Umbau ohne Rückmeldung echter Nutzer wäre riskant |
| Korrektur von Fitting-Werten nach Übertragung | Pass-Einträge sind bewusst unveränderlich; Korrektur-Eintrag wäre möglich, ist aber noch nicht automatisiert |
| Rechnungen im Pass | bewusst nicht (Preise/Personendaten) – nur die Arbeiten |

## 6. Durchgeführte Tests und Ergebnisse (alle tatsächlich ausgeführt)
- **Datenbank lokal (PostgreSQL 16)**: `funde.sql` zweimal hintereinander ausgeführt (idempotent). Tests: Fundmeldung nur bei gestohlenen Rädern, Kontakt ≤ 120 Zeichen, Spam-Grenze, Lesen nur mit Teil II, Rahmennummer-Abgleich, Besitzer-Vollansicht, Teil-II-Ersatz (nicht verifiziert → abgelehnt, fremde Werkstatt → abgelehnt, falsche Rahmennummer → abgelehnt, gestohlen → abgelehnt, alter Code danach ungültig, neuer gültig, Eintrag „verified“). **Alle bestanden.**
- **Browser-Tests (Playwright, simuliertes iPhone 13 / Pixel 7 / Desktop) gegen Test-Server**: thealth, treissue, tcop, tmore, tshop, tfit2, towner3, ttools, tand, tp79–tp87, tgar, tintro, tpwa, tord, tpho, tcloud, tdb, tgeo, tgeo2, tinv, tinv2, tkva, tleg, tlink, tmedia, tnetz, tpair, tplat2, tqr, tviz → **ohne Fehler**.
- Prüfsuiten Händler-Software: 41/41 + 41/41; Bereichs-Scan 33 Bereiche; Klick-Test 552 Knöpfe.
- Hinweise: `tteam` bricht im Testskript selbst ab (Variable fehlt) – App unauffällig; `tplat`/`trep` melden nur blockierte Google-Fonts im Testnetz.
- **Nicht getestet**: echte Supabase (Stand 14 noch nicht eingespielt), echte iPhone/Android-Geräte, echtes QR-Lesen per Kamera, Kalender-Import auf dem Gerät.

## 7. Datenbankänderungen (Stand 14, Datei `docs/supabase/funde.sql`, nur ergänzend)
- Tabelle `bike_pass_seen` (Fundmeldungen; RLS an, kein direkter Zugriff) + Spalte `contact`
- Funktionen: `pass_seen_add` (mit optionalem Kontakt), `pass_seen_list`, `pass_frame_match`, `pass_get_owner`, `pass_owner_reissue`, `pass_find_frame`
- `fyf_schema()` → 14. Keine Daten gelöscht, nichts umbenannt, rückwärtskompatibel.

## 8. Notwendige manuelle Schritte
1. Branch prüfen/freigeben → ich übernehme ihn nach deinem OK nach `main` (dann live).
2. Danach GitHub → Actions → „Datenbank aktualisieren“ → Run workflow (Stand 14).
3. Deine Werkstatt als verifiziert markieren (Plattform-Admin), falls noch nicht geschehen.
4. Impressum und Datenschutz ausfüllen; Datenschutz um Fundmeldung (Standort, freiwilliger Kontakt), Speicherung auf dem Gerät und Google-Kalender-Link ergänzen.
5. Test auf echtem iPhone und Android-Handy (QR scannen, Kalender, Foto, Sichern).

## 9. Verbleibende Risiken
- Daten der Pass-App liegen nur auf dem Gerät (bis zum Konto) – Verlust bei gelöschten Website-Daten; Sicherung per Datei vorhanden.
- Fundmeldungen können falsch sein – nur Hinweis, keine Beweiskraft; Spam-Grenzen vorhanden.
- Teil-II-Ersatz vertraut der verifizierten Werkstatt – abgesichert durch Rahmennummer-Prüfung, Protokoll und sichtbaren Pass-Eintrag.
- Kaufvertrag-Muster ohne Rechtsprüfung („Muster ohne Gewähr“).
- Kompatibilitätsregeln decken Normfälle ab; Herstellerausnahmen werden als „ungeprüft“ markiert, aber nicht alle Sonderfälle sind bekannt.
- Abhängigkeit von jsdelivr (QR-Bibliotheken).

## 10. Empfehlung nächste Schritte
1. Freigabe + Datenbank-Update (10 Minuten am iPhone).
2. 2–3 Freunde testen lassen, Rückmeldungen sammeln.
3. Endkunden-Konto (E-Mail-Link) → Daten sicher und geräteübergreifend.
4. Impressum/Datenschutz → dann öffentliche Nutzung.
5. Danach: Copilot mit echter KI (nach Kostenfreigabe), Herstellerdaten nur mit Partner/Quelle.
