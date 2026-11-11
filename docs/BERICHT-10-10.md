# FYF – Bericht zum Auftrag „Beide Anwendungen auf 10/10“ (Stand 11.11.2026)

Ehrliche Bewertung. Alle Angaben „getestet“ beziehen sich auf automatische Tests im Browser (simuliertes iPhone 13, Pixel 7, Desktop 1280 px) gegen einen Test-Server und eine lokale Test-Datenbank (PostgreSQL 16) – **nicht** auf echte Geräte und **nicht** auf die echte Supabase-Datenbank.

---

## Teil C zuerst: Die 5 Szenarien (Zusammenspiel beider Anwendungen)

| Szenario | Ablauf | Ergebnis | Test |
|---|---|---|---|
| 1 Registrierung | Kunde registriert Rad → Garage → Händler übernimmt mit Teil II → Inspektion → Eintrag im Pass, „bestätigt“ | **funktioniert** | tp82, tp81 |
| 2 Werkstatt | Auftrag → Positionen/Teile → „Übergeben“ → Pass-Eintrag inkl. „Neue Teile“ → Service in der App erledigt, Ausstattung aktualisiert | **funktioniert** | tp81, tp87, tshop |
| 3 Komponentenwechsel | Händler: neue Teile per Auftrag → Ausstattung „Werkstatt“. Besitzer: Teiletausch mit Verlauf (alt → neu), optional öffentlicher „Umbau“-Eintrag, **Teil auf anderes Rad umziehen mit Verlauf** | **funktioniert** (neu) | tumbau, tshop |
| 4 Bikefitting | Fitting abschließen (mit Kunden-Zustimmung) → Werte im Pass → „Sitzposition“ + **Verlauf mehrerer Fittings mit Differenzen** | **funktioniert** | tfit2, thealth |
| 5 Verkauf | **Verkäufer startet Übergabe → Link → Käufer bestätigt → neuer Teil II nur beim Käufer**, Historie bleibt, Verkäufer-Code ungültig, keine Daten des Vorbesitzers | **funktioniert ohne Werkstatt** (neu) | tclaim + SQL-Test |

---

## A. FYF Händler-Software

1. **Ursprünglicher Zustand:** 33 Bereiche, umfangreich, lokal-zuerst mit Cloud-Synchronisierung. Keine toten Knöpfe, keine JS-Fehler (vorheriger Prüflauf 552 Klicks).
2. **Geprüfte Bereiche:** alle 33 (Dashboard, Werkstatt, Termine, Fahrwerk, Kunden, Fahrräder, Rechnungen, Angebote & Lager, Produkte & Preise, Bikefitting/Sitzung/Verlauf/Nachkontrollen/Qualität, Geometrie, Messmittel, Produkt-DB, Wissen, Quick-Fit, Motion, Hardware, KI, Portal, Betrieb, Module, Händlernetz, Börse, Academy, Fahrradpass u. a.).
3. **Anzahl getesteter Funktionen:** automatische Prüfsuiten 41 + 41 Prüfpunkte, Bereichs-Scan 33 Bereiche × 2 Bildschirmgrößen, Klick-Test 552 Knöpfe, dazu Ablauf-Tests (siehe Testbericht).
4. **Erfolgreich:** siehe Testbericht unten.
5. **Fehlgeschlagen:** `tteam` (Fehler im Testskript selbst); `tplat`/`trep` melden nur blockierte Web-Schriften im Testnetz.
6. **Teilweise funktionierend / simuliert (ehrlich gekennzeichnet):** KI-Assistent und Copilot sind regelbasiert (kein Sprachmodell). Kostenvoranschlag-Versand an Kunden ist „simuliert“. E-Rechnung: Erzeugung vorhanden, keine Prüfung mit offiziellem Validator. Zahlungen/Käuferschutz: nicht angebunden.
7. **Behobene Fehler (diese Runde):** Partner-Merkmale wurden nie übertragen → Laden fehlte bei „Bikefitting buchen“ (jetzt automatisch); Sichtbarkeit nicht prüfbar (jetzt „Sichtbarkeit prüfen“).
8. **Neue Funktionen:** Leistungen gruppiert (Bikefitting / Werkstatt / Verkauf) mit Wirkung in der Pass-App; „Sichtbarkeit prüfen“; Dashboard zeigt zusätzlich fehlende Teile für offene Aufträge, überfällige Rechnungen, offene Garantiefälle (ohne Doppelungen); Werkstatt-Wartungsplan geht in den Pass; Copilot, Kompatibilitäts-Prüfung, Teil-II-Ersatz (vorherige Runde).
9. **Design:** bestehende Identität (Beige/Creme, Orange, dunkle Seitenleiste) unverändert; neue Bereiche nutzen vorhandene Bausteine (Panels, Chips, Formulare).
10. **Bedienbarkeit:** Ursachen-Diagnose statt Rätselraten (Sichtbarkeit), Leistungen mit Erklärung, Aktionen direkt aus Dashboard-Hinweisen.
11. **Verbindungen zur Pass-App:** Service, Teile, Ausstattung, Akku-Check, km, Fitting (mit Zustimmung), Wartungsplan, Leistungen, Diebstahl-Abgleich bei Annahme, Teil-II-Ersatz.
12. **Einschränkungen:** Werkstattprozess hat keine Arbeitszeit-Stoppuhr je Position; Fotos/Schäden bei Annahme vorhanden, aber nicht als strukturierte Schadenskarte; Anfragen-Eingang zeigt keine „unbeantwortet“-Zählung auf dem Dashboard; komplette Design-Überarbeitung nicht erfolgt (automatisch keine Fehler gefunden, ein Umbau ohne Nutzer-Rückmeldung wäre riskant).

### Bewertung Händler-Software (1–10)
| Kategorie | Note | Warum nicht 10 |
|---|---|---|
| Funktionsumfang | 9 | Sehr breit; es fehlen Zeiterfassung je Position, strukturierte Schadenskarte |
| Tatsächliche Funktionalität | 8 | Lokal alles getestet; Cloud-Teile nur gegen Test-Server; einige Teile bewusst simuliert (KV-Versand, KI) |
| Bedienbarkeit | 7 | Viele Funktionen → Lernkurve; 33 Bereiche sind viel |
| UX/UI-Design | 7 | Einheitlich, aber dicht; keine Überarbeitung mit echten Nutzern |
| Navigation | 7 | Gruppiert, aber tief |
| Verständlichkeit | 8 | Viele Erklärtexte; Fachbegriffe bleiben |
| Mobile Darstellung | 7 | Kein seitliches Verrutschen (getestet), aber für Tablet/Desktop gedacht |
| Prozessdurchgängigkeit | 8 | Annahme → Auftrag → Rechnung → Pass verbunden; Zeit/Schaden fehlen |
| Fehlerbehandlung | 8 | Fehlermeldungen mit Klartext; Netzfehler abgefangen |
| Visuelle Konsistenz | 8 | Einheitliche Bausteine |
| Innovationsgrad | 9 | Bikefitting + Fahrradpass + Diebstahl-Abgleich + Kompatibilität in einem |
| Zusammenspiel | 9 | 5 Szenarien laufen; echte Datenbank-Bestätigung steht aus |

---

## B. FYF Bike Pass

1. **Ursprünglicher Zustand (vor heute):** Garage, Registrierung, Pass mit QR, Besitzer-Einstellungen, Werkzeuge (Service, Sitzposition, Fahrwerk, Reifen, E-Bike, Ausstattung, Belege, Verkaufen, Diebstahl).
2. **Geprüfte Bereiche:** alle oben genannten + Scanner, Fundmeldung, Kauf-Check, Kaufvertrag, Sicherung, Garage teilen, Anleitung, Installation (iOS/Android).
3. **Anzahl getesteter Funktionen:** über 30 Ablauf-Tests für die Pass-App (siehe Testbericht).
4./5. siehe Testbericht.
6. **Teilweise / Grenzen:** Daten der Werkzeuge (Belege, Notizen, Fahrwerk-Setups) liegen nur auf dem Gerät (Sicherung per Datei vorhanden, Konto folgt später); Kalender statt Push; QR-Scanner auf iPhone lädt eine Bibliothek aus dem Netz.
7. **Behobene Fehler (diese Runde):** Wartung hakte nach einer Inspektion automatisch Kette/Bremsen/Reifen ab (nicht erlaubt) → jetzt nur ausdrücklich eingetragene Arbeiten; Verkäufer-Handy sperrte still nach Übergabe → klarer Hinweis + „Aus Garage entfernen“; „Bikefitting buchen“-Knopf stand unter den Kacheln.
8. **Neue Funktionen:** privater Besitzerwechsel (Link + Bestätigung); Umbau-Verlauf + Teil umziehen + öffentlicher Umbau-Eintrag; Werkstatt-Empfehlungen im Service; getrennte Quellen (allgemeine Empfehlung / Werkstatt-Empfehlung / durchgeführt laut … / von dir eingetragen); Garage zeigt „neu“, „Pass x %“, „bald fällig“ und aktualisiert sich selbst; Bikefitting buchen (Rennlenker), Leistungen je Knopf; Schaltgruppen-Vorauswahl; Serienausstattung per eingefügter Herstellerliste; Hersteller-QR (Canyon) für Rahmennummer und Suche.
9. **Design:** helles, ruhiges Design beibehalten; Kacheln, Chips und Karten einheitlich.
10. **Bedienbarkeit:** Anleitung „So funktioniert’s“ mit allen Funktionen; weniger Abtippen (Scanner, Vorauswahl, Einfügen).
11. **Verbindungen:** siehe Szenarien.
12. **Einschränkungen:** kein Konto (Daten auf dem Gerät); Herstellerdaten nur per Einfügen (keine offene Schnittstelle); Kalender-Import und Kamera nicht auf echten Geräten getestet; Impressum/Datenschutz noch Vorlagen.

### Bewertung Bike Pass (1–10)
| Kategorie | Note | Warum nicht 10 |
|---|---|---|
| Funktionsumfang | 9 | Sehr vollständig; Konto/Sync fehlt bewusst |
| Tatsächliche Funktionalität | 8 | Automatisch getestet; nicht auf echten Geräten, echte Datenbank Stand 15 noch nicht eingespielt |
| Bedienbarkeit | 8 | Einfache Hauptwege; viele Werkzeuge |
| UX/UI-Design | 8 | Hochwertig und ruhig; Feinschliff nach echten Nutzern offen |
| Navigation | 8 | 4 Tabs + Kacheln; Werkzeuge als Vollbildseiten |
| Verständlichkeit | 8 | Anleitung + Hinweise; einige Fachbegriffe (SAG, Hookless) |
| Mobile Darstellung | 8 | Für Handy gebaut, getestet auf 2 simulierten Geräten |
| Prozessdurchgängigkeit | 9 | Registrieren → Pflege → Verkauf → Übergabe durchgängig |
| Fehlerbehandlung | 8 | Klartext-Fehler, Offline-Stand, „bald verfügbar“ statt Fehlerseite |
| Visuelle Konsistenz | 9 | Einheitlich |
| Innovationsgrad | 9 | Fundmeldung, Hersteller-QR, Zustandsbericht, Besitzerwechsel ohne Werkstatt |
| Zusammenspiel | 9 | Werkstatt-Daten kommen automatisch an |

**Keine Kategorie erreicht ehrlich 10/10**, weil echte Geräte, echte Datenbank und echte Nutzer-Rückmeldungen noch fehlen.

---

## Testbericht (diese Runde, tatsächlich ausgeführt)
- **Datenbank lokal:** besitz.sql zweimal ausgeführt; Besitzerwechsel-Test: falscher Code abgelehnt, Link öffnet, falscher Token abgelehnt, Übernahme → 2. Besitzer, alter Code ungültig, neuer gültig, Link nur einmal, gestohlen gesperrt, Abbrechen wirkt, Historie erhalten. **Alle bestanden.**
- **Prüfsuiten Händler-Software:** 41/41 (Handy) + 41/41 (Desktop); Bereichs-Scan 33 Bereiche × 2 Größen: 0 tote Knöpfe/Formulare/Links, 0 JS-Fehler, kein seitliches Verrutschen; Klick-Test: keine toten Elemente.
- **Ablauf-Tests: 47 Testläufe, 47 ohne Fehler:**

  - `tp82`
  - `tp81`
  - `tp87`
  - `tfit2`
  - `tshop`
  - `thealth`
  - `tumbau`
  - `tclaim`
  - `tgchip`
  - `tframe`
  - `tparts`
  - `tfitbook`
  - `tfeat`
  - `tvis`
  - `treissue`
  - `tmore`
  - `ttools`
  - `tand`
  - `tgar`
  - `tintro`
  - `tpwa`
  - `tord`
  - `tpho`
  - `towner3`
  - `tp79`
  - `tp80`
  - `tp83`
  - `tp84`
  - `tp86`
  - `tcloud`
  - `tgeo`
  - `tgeo2`
  - `tinv`
  - `tinv2`
  - `tkva`
  - `tleg`
  - `tlink`
  - `tmedia`
  - `tnetz`
  - `tpair`
  - `tplat2`
  - `tqr`
  - `tviz`
  - `tdb`
  - `t70`
  - `t77`
  - `t78`
- Nicht ausgeführt bzw. bekannt fehlerhaft: `tteam` (Fehler im Testskript), `tplat`/`trep` (Web-Schriften im Testnetz blockiert).

## Datenbank
Neu: `docs/supabase/besitz.sql` (Stand 15): Spalten `claim_hash`, `claim_until`; Funktionen `pass_claim_start`, `pass_claim_cancel`, `pass_claim`, `pass_claim_info`, interne Hilfsfunktion `fyf_owner_ok`. Nur ergänzend, mehrfach ausführbar, lokal getestet.

## Manuelle Schritte
1. GitHub → Actions → „Datenbank aktualisieren“ → Run workflow (Stand 15).
2. Händler-Software: Händlernetz → „Sichtbarkeit prüfen“, Leistungen ankreuzen.
3. Test auf echtem iPhone/Android (QR scannen, Übergabe-Link, Kalender).
4. Impressum/Datenschutz ausfüllen, bevor Fremde die App nutzen.
