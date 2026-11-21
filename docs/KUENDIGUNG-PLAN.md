# Plan: Kündigung eines Ladens (zur Freigabe)

Stand 21.11.2026 · betrifft das Datenmodell → **nicht umgesetzt, wartet auf Freigabe von Dominik**.

## Regel (verbindlich)
Kündigt ein Laden, bleiben die Pass-Einträge der Radbesitzer erhalten. Der Laden sieht danach nichts mehr.

## Befund (lokal mit Postgres 16 geprüft)
- Eine Kündigung gibt es heute weder in der App noch auf dem Server. Ein Laden ließe sich nur von Hand im Supabase-Dashboard löschen.
- **Lücke:** Wird ein Laden gelöscht, löscht die Datenbank automatisch alle Fahrradpässe, die er ausgestellt hat (`bike_passes.tenant_id … on delete cascade`). Mit dem Pass verschwinden auch **alle** Einträge darin, auch die anderer Läden und die des Besitzers.
  Test: Laden anlegen → Pass ausstellen → fremder Eintrag „Kette getauscht“ → Laden löschen → Pass 0, Einträge 0.
- Schon richtig: Einträge, die ein Laden in fremden Pässen gemacht hat, bleiben erhalten (`bike_pass_entries`: on delete set null, seit `passport.sql`).
- Läden mit archivierten Rechnungen lassen sich gar nicht löschen (`invoice_archive`: on delete restrict, wegen der Aufbewahrungspflicht von 10 Jahren). Löschen ist deshalb nicht der richtige Weg für eine Kündigung.

## Vorschlag
1. **Pässe schützen (klein, sofort sinnvoll):** `bike_passes.tenant_id` auf „on delete set null“ umstellen. Wird ein Laden doch einmal gelöscht, bleibt der Pass mit allen Einträgen erhalten und hat nur keinen ausstellenden Laden mehr. Das gibt es heute schon für Pässe, die Besitzer selbst anlegen (`tenant_id` leer).
2. **Kündigung als Status statt Löschen:** neue Spalte `tenants.closed_at`.
   - Nur ein Plattform-Admin setzt sie (Funktion `tenant_close`, mit Protokoll). Rückgängig machen geht (`tenant_reopen`).
   - Ab dann geben `is_member()` und `has_role()` für diesen Laden „nein“ zurück. Der Laden sieht und ändert nichts mehr, weder Kunden noch Pässe, Anfragen oder Bewertungen.
   - Händlerfinder: Profil und Produkte werden ausgeblendet.
   - Fahrradpässe: bleiben für die Besitzer vollständig lesbar. Einträge des Ladens bleiben mit seinem Namen stehen. Der Laden kann nichts mehr ergänzen.
   - Das Rechnungsarchiv bleibt für die Aufbewahrungsfrist erhalten. Den Export bekommt der Laden vor der Schließung (läuft heute schon über „Rechnungsarchiv → Export“).
3. **App:** Ein geschlossener Laden sieht nach der Anmeldung nur den Hinweis „Zugang beendet“ und einen Knopf „Eigene Daten herunterladen“ (letzter lokaler Stand), sonst nichts.
4. **Tests:** Datenbank-Test (Laden schließen → Mitglied liest nichts, Pass und alle Einträge bleiben, Besitzer liest weiter) und Browser-Test.

## Aufwand und Risiko
- Schritt 1: eine Datenbank-Änderung, kein Einfluss auf die App. Risiko gering.
- Schritt 2–4: ein Lauf. `is_member`/`has_role` sind zentrale Funktionen, deshalb mit Tests für alle bestehenden Rollen.

## Was ich von Dominik brauche
Freigabe: **„Kündigung: Schritt 1“** (nur Pässe schützen) oder **„Kündigung: alles“**.
