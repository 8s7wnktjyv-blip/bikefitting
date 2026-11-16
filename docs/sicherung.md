# Sicherung und Wiederherstellung

**Was:** Der Workflow „Sicherung“ sichert jede Nacht (02:17 UTC) das Schema `public` der Datenbank (alle Läden, Kunden, Aufträge, Rechnungsarchiv, Fahrradpässe), verschlüsselt die Datei mit deinem Passwort (AES-256) und hebt sie 30 Tage bei GitHub auf. Danach spielt er die Sicherung testweise in eine leere Datenbank ein und zählt die Tabellen und Zeilen.

**Einmal einrichten (am iPhone möglich, github.com im Browser):**
1. Repo → Settings → Secrets and variables → Actions → New repository secret.
2. Name `BACKUP_PASSPHRASE`, Wert: eigenes langes Passwort (mind. 20 Zeichen). Im Passwort-Manager speichern – ohne es ist keine Sicherung lesbar.
3. Actions → „Sicherung“ → Run workflow. Grüner Haken = Sicherung und Probe-Wiederherstellung haben geklappt.

**Wiederherstellen (braucht einen Computer):**
1. Actions → letzter erfolgreicher Lauf „Sicherung“ → Artefakt herunterladen und entpacken.
2. `gpg -d sicherung.tar.gz.gpg | tar -xz` (Passwort eingeben). Ergebnis: `sicherung.sql` (Daten) und `nutzer.csv` (Nutzerkonten: ID und E-Mail).
3. In ein **leeres** Supabase-Projekt: zuerst die Nutzerkonten aus `nutzer.csv` in `auth.users` übernehmen (gleiche IDs, damit Läden und Mitarbeiter zusammenpassen), dann `psql "<Verbindung>" -f sicherung.sql`. Danach melden sich die Nutzer per E-Mail-Code wie gewohnt an.
4. Bei Problemen: nicht in die Live-Datenbank einspielen, erst in ein Test-Projekt.

**Grenzen:** Von den Nutzerkonten werden nur ID und E-Mail gesichert (keine Anmeldesitzungen). Dateien (Fotos/Videos im Speicher) sind nicht enthalten. Läden können zusätzlich in FYF unter Einstellungen eine eigene Sicherung herunterladen. Hinweis: Solange das Repo öffentlich ist, kann jeder angemeldete GitHub-Nutzer die verschlüsselte Datei herunterladen – lesbar ist sie nur mit dem Passwort.
