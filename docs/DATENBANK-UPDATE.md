# Datenbank aktualisieren – ohne SQL einfügen

Die komplette Datenbank steht in **`docs/supabase/alles.sql`**. Diese Datei wird aus den Einzeldateien gebaut (`tools/build-alles.sh`) und kann beliebig oft ausgeführt werden. Sie ergänzt und ersetzt nur, löscht keine Daten. Alles läuft in einem Block: Bei einem Fehler wird nichts übernommen.

Eingespielt wird sie über GitHub: **Actions → „Datenbank aktualisieren“ → Run workflow**. Die App zeigt unter Mehr → Rolle und Datenspeicherung → **Datenbank**, ob der Stand aktuell ist (Funktion `fyf_schema()`).

## Einmalig einrichten (ca. 5 Minuten, am iPhone in Safari)

1. **Datenbank-Passwort bereit haben.** Wenn du es nicht mehr weißt: Supabase → Projekt → Project Settings → Database → *Reset database password* → *Generate a password* → kopieren. Das ändert nichts an der App (die App nutzt nur den öffentlichen Schlüssel). Am besten ein Passwort nur aus Buchstaben und Ziffern.
2. **Verbindungsadresse kopieren.** Supabase → Projekt → oben **Connect** → Typ **Session pooler** → die Adresse kopieren. Sie sieht so aus:
   `postgresql://postgres.<projekt>:[YOUR-PASSWORD]@aws-0-<region>.pooler.supabase.com:5432/postgres`
   In Notizen einfügen und `[YOUR-PASSWORD]` (mit den eckigen Klammern) durch dein Passwort ersetzen.
3. **In GitHub speichern.** github.com → Repo **bikefitting** → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**.
   Name: `SUPABASE_DB_URL` · Secret: die Adresse aus Schritt 2 → **Add secret**.
   Danach die Adresse aus den Notizen löschen.
4. **Einmal ausführen.** Repo → **Actions** → **Datenbank aktualisieren** → **Run workflow** → grüner Knopf **Run workflow**. Nach ca. 1 Minute grüner Haken = fertig.
   Optional im Feld „plattform_admin_email“ deine E-Mail eintragen – dann bist du gleichzeitig Plattform-Admin.

Falls der Knopf „Run workflow“ am iPhone fehlt: in Safari über das **aA**-Menü „Desktop-Website anfordern“.

## Was nicht über die Datei geht
- Schalter **Allow anonymous sign-ins** (für „Gerät koppeln“): Supabase → Authentication → Sign In / Providers. Einmalig von Hand.

## Für Entwickler: neue Datenbank-Änderung
1. Neue Datei in `docs/supabase/` (nur `create … if not exists`, `create or replace`, `drop policy if exists` vor `create policy` usw.).
2. In `tools/build-alles.sh` an `LISTE` anhängen, `SCHEMA` um 1 erhöhen; in `index.html` `DB_SCHEMA` gleich setzen.
3. `sh tools/build-alles.sh`, committen. Die Aktion prüft, dass `alles.sql` zu den Einzeldateien passt.

## Sicherheit
- Das Secret ist nur für die Aktion lesbar, nicht in Logs sichtbar und nicht im Code.
- Die Aktion startet nur von Hand (kein automatischer Lauf bei jedem Update).
- Getestet lokal mit Postgres 16: leere Datenbank, dreimal hintereinander, und Aufrüsten eines Stands mit Daten (Daten bleiben erhalten). Gegen das echte Supabase noch nicht gelaufen.
