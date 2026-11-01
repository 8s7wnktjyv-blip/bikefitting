# Datenschicht und Umstieg auf eine Server-Datenbank

Stand: v.50 · **Vorbereitet, nicht angeschlossen.** Alle Daten bleiben lokal im Browser.

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
