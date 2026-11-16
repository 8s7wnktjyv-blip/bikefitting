# Sicherung und Wiederherstellung

**Was:** Der Workflow „Sicherung“ sichert jede Nacht (02:17 UTC) das Schema `public` der Datenbank (alle Läden, Kunden, Aufträge, Rechnungsarchiv, Fahrradpässe), verschlüsselt die Datei mit deinem Passwort (AES-256) und hebt sie 30 Tage bei GitHub auf. Danach spielt er die Sicherung testweise in eine leere Datenbank ein und zählt die Tabellen und Zeilen.

**Einmal einrichten (am iPhone möglich, github.com im Browser):**
1. Repo → Settings → Secrets and variables → Actions → New repository secret.
2. Name `BACKUP_PASSPHRASE`, Wert: eigenes langes Passwort (mind. 20 Zeichen). Im Passwort-Manager speichern – ohne es ist keine Sicherung lesbar.
3. Actions → „Sicherung“ → Run workflow. Grüner Haken = Sicherung und Probe-Wiederherstellung haben geklappt.

**Wiederherstellen (braucht einen Computer):**
1. Actions → letzter erfolgreicher Lauf „Sicherung“ → Artefakt herunterladen und entpacken.
2. `gpg -d sicherung.sql.gz.gpg | gunzip > sicherung.sql` (Passwort eingeben).
3. In ein **leeres** Supabase-Projekt mit `psql "<Verbindung>" -f sicherung.sql` einspielen (die Sicherung enthält Tabellen, Daten und Funktionen). Danach melden sich die Nutzer neu an.
4. Bei Problemen: nicht in die Live-Datenbank einspielen, erst in ein Test-Projekt.

**Grenzen:** Die Nutzerkonten (Schema `auth`) und Dateien (Fotos/Videos im Speicher) sind nicht enthalten. Läden können zusätzlich in FYF unter Einstellungen eine eigene Sicherung herunterladen. Hinweis: Solange das Repo öffentlich ist, kann jeder angemeldete GitHub-Nutzer die verschlüsselte Datei herunterladen – lesbar ist sie nur mit dem Passwort.
