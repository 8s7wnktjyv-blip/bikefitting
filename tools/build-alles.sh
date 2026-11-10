#!/bin/sh
# Baut docs/supabase/alles.sql aus den einzelnen Schritten. Aufruf: sh tools/build-alles.sh
# Neue Datenbank-Änderung: neue Datei in docs/supabase anlegen, hier in LISTE ergänzen, SCHEMA um 1 erhöhen.
set -e
cd "$(dirname "$0")/../docs/supabase"
SCHEMA=11
LISTE="start.sql media.sql team.sql netz.sql freigabe.sql pair.sql ausbau.sql feedback.sql werkstatt.sql pass.sql passport.sql"
{
  echo "-- FYF – Fit your Frame · KOMPLETTE Datenbank (Stand $SCHEMA). Automatisch erzeugt aus: $LISTE"
  echo "-- Nicht von Hand ändern – stattdessen die Einzeldatei ändern und tools/build-alles.sh ausführen."
  echo "-- Mehrfach ausführen schadet nicht: es wird nur ergänzt und ersetzt, keine Daten gelöscht."
  echo "-- Normal läuft das über GitHub → Actions → „Datenbank aktualisieren“ → Run workflow."
  for f in $LISTE; do
    echo; echo "-- ===================== $f ====================="
    cat "$f"
  done
  echo
  echo "-- ===================== Stand der Datenbank (für die Prüfung in der App) ====================="
  echo "create or replace function fyf_schema() returns int language sql immutable as \$\$ select $SCHEMA \$\$;"
  echo "grant execute on function fyf_schema() to anon, authenticated;"
} > alles.sql
echo "alles.sql gebaut (Stand $SCHEMA)"
