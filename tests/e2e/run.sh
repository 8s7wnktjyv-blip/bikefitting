#!/bin/sh
# Startet den Test-Server (Nachbau der Datenbank) und führt alle Browser-Tests aus (iPhone-13-Ansicht).
# Aufruf: sh tests/e2e/run.sh   (braucht Node 20+ und Playwright mit Chromium)
cd "$(dirname "$0")"
node mock.js > /tmp/fyf-mock.log 2>&1 &
MOCK=$!
trap 'kill $MOCK 2>/dev/null' EXIT
sleep 1
FAIL=0
for t in t*.js; do
  OUT=$(node "$t" < /dev/null 2>&1); RC=$?
  if [ $RC -ne 0 ] || ! echo "$OUT" | grep -q "Fehler: keine" || echo "$OUT" | grep -qE "FEHLT|KEIN FENSTER|NICHT markiert"; then
    echo "✗ $t"; echo "$OUT" | tail -25; FAIL=1
  else
    echo "✓ $t"
  fi
done
exit $FAIL
