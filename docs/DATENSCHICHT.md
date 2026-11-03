# Datenschicht und Umstieg auf eine Server-Datenbank

Stand: v.59 · **Cloud-Start eingebaut, standardmäßig aus.** Ohne Verbindung bleiben alle Daten lokal im Browser.

## Heute
- Der gesamte Zustand (`S`) wird über `STORE.read()` / `STORE.write(json)` gelesen und gespeichert (localStorage, Schlüssel `fitframe-demo-v3`).
- Fotos und Videos liegen getrennt in IndexedDB (`fyf-media`, Speicher `m`). In `S.media` stehen nur Metadaten.
- Automatische Sicherungen im Browser: `fitframe-before-<Version>` (bei Updates) und `fitframe-rescue-<Zeit>` (vor dem Zurücksetzen).

## Schnittstelle für einen Server-Adapter
Ein Adapter muss dieselben zwei Funktionen anbieten:

| Funktion | Aufgabe |
|---|---|
| `read()` | Zustand als JSON-Text liefern |
| `write(json)` | Zustand speichern und den gespeicherten Stand zurückgeben (für die Kontrolle „gespeichert“) |

Für Supabase ist der empfohlene Weg, die Daten nicht als ein großes JSON zu speichern, sondern auf die Tabellen in `docs/supabase/schema.sql` zu verteilen (Kunden, Räder, Sitzungen …). Schritte:

1. Supabase-Projekt anlegen (kostenloser Tarif reicht zum Testen) – **nur mit Zustimmung des Inhabers**.
2. `schema.sql` im SQL-Editor ausführen, Bucket `media` anlegen.
3. Anmeldung (E-Mail-Link) einbauen; Nutzer einem Betrieb und einer Rolle zuordnen (`memberships`).
4. Adapter schreiben: beim Start Kunden/Räder/Sitzungen des Betriebs laden, Änderungen je Datensatz speichern.
5. Fotos/Videos in den Bucket hochladen statt nach IndexedDB.
6. Bestehende lokale Daten einmalig über „Sicherung herunterladen“ → Import übernehmen.

## Rollen
| Rolle | Darf |
|---|---|
| Admin | alles, auch Kunden löschen, Preise, Benutzer |
| Fitter | Fittings, Kunden, Messmittel; keine Preise, kein Löschen von Kunden |
| Mitarbeiter | messen und dokumentieren; nichts löschen, nicht abschließen, keine Preise |

In der Demo wird die Rolle nur in der Oberfläche geprüft. Echte Sicherheit entsteht erst durch die Regeln in der Datenbank (Row Level Security im Schema).

## Mandantentrennung
Jede Tabelle hat `tenant_id`. Die Regeln erlauben nur Zugriff für Mitglieder dieses Betriebs. Kunden im Portal sehen nur `portal_items` mit ihrer eigenen `customer_id`.


## Cloud-Start (ab v.59)

Eingebaut unter **Mehr → Cloud-Speicherung**. Aus, solange keine Supabase-Verbindung eingetragen ist.

- Gespeichert wird der komplette Stand je Laden als ein Datensatz (`docs/supabase/start.sql`, Tabelle `tenant_state`).
- Jede Änderung wird ca. 2,5 Sekunden nach dem lokalen Speichern hochgeladen. Versionsnummer schützt vor Überschreiben: Hat ein anderes Gerät inzwischen gespeichert, erscheint „Konflikt“ und der Nutzer wählt. Der verworfene Stand wird als `fitframe-rescue-…` im Browser gesichert.
- Beim ersten Verbinden eines Geräts mit eigenen Kunden wird nie automatisch überschrieben, sondern gefragt.
- Die Cloud hebt die letzten 30 Stände je Laden auf (`tenant_state_history`, nur Admin lesbar).
- Anmeldung per E-Mail-Code oder Link (Supabase Auth). Nur der öffentliche Schlüssel wird eingetragen; der geheime `service_role`/`sb_secret_`-Schlüssel wird abgelehnt.
- Einrichten der Verbindung und Anlegen des Ladens nur mit Rolle Admin.
- Noch nicht in der Cloud: Fotos und Videos (bleiben in IndexedDB auf dem Gerät).
- Getestet: SQL mit Postgres 16 (Konflikt, Rechte, fremder Laden gesperrt, direkte Schreibzugriffe gesperrt); App gegen einen nachgebauten Supabase-Server (Anmelden, Laden anlegen, zweites Gerät, Konflikt, Abmelden). Am 03.11.2026 mit echtem Supabase (Region Frankfurt, Free-Tarif) erfolgreich eingerichtet: Anmeldung per Link, Laden angelegt, Stand hochgeladen. Nötig war zusätzlich das Grant für `authenticated` (jetzt in start.sql).

### Einrichten (Inhaber, am iPhone möglich)
1. supabase.com → kostenloses Konto → „New project“, Region **Frankfurt (eu-central-1)**, Datenbank-Passwort sicher aufbewahren (nicht in FYF eintragen).
2. SQL Editor → Inhalt von `docs/supabase/start.sql` einfügen → Run.
3. Authentication → URL Configuration: „Site URL“ und „Redirect URLs“ auf die Adresse der App setzen.
4. Authentication → Email Templates → „Magic Link“: zusätzlich `{{ .Token }}` in den Text einfügen, damit der 6-stellige Code mitkommt (wichtig für die App auf dem Home-Bildschirm).
5. Project Settings → API: „Project URL“ und den **öffentlichen** Schlüssel (anon / publishable) in FYF unter Mehr → Cloud-Speicherung eintragen.
6. E-Mail eingeben → Code eintragen → „Laden anlegen und Daten hochladen“.

Hinweis: Der kostenlose Tarif pausiert nach 1 Woche ohne Nutzung und hat keine automatischen Sicherungen. Für zahlende Läden auf Pro wechseln.
