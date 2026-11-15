# FYF Plattform – Neubau (Branch `plattform-neu`)

Stand 15.11.2026. Grundlage: Arbeitsauftrag „vollständige Plattformweiterentwicklung“ und die Bestandsaufnahme `FYF_Bestandsaufnahme_Plattform_2027.pdf`.

## Entscheidungen von Dominik (15.11.2026)

| Frage | Entscheidung |
|---|---|
| Datenspeicher | Auf echte Tabellen umstellen, schrittweise mit Doppelschreiben und Abgleich |
| Technik | Händlersoftware **komplett neu** (TypeScript + React), Design und Bedienung bleiben gleich |
| Server | **Vorerst kostenlos** (Supabase Free, Frankfurt) |
| Preis | 99 € / 149 € **pro Standort** und Monat |
| QR-Aufkleber | Es gibt noch keine gedruckten mit der GitHub-Adresse |
| KI-Assistent | Vorerst regelbasiert (kein Sprachmodell, keine Kosten) |
| Endkunden-Konto | Ja, freiwillig. Der Pass bleibt ohne Konto nutzbar. |
| Kündigung eines Ladens | Pass-Einträge bleiben mit Laden als Quelle; der Laden sieht danach nichts mehr; keine neuen „verifiziert“-Einträge |
| Rollen | Neu: Werkstattleitung, Verkauf, Filialleitung, Buchhaltung (zusätzlich zu Admin, Fitter, Mitarbeiter) |
| Repo | Soll privat werden |
| Kasse | Zertifizierte Kasse mit TSE extern anbinden |

## Offene Konflikte aus diesen Entscheidungen (brauchen Antwort)

1. **Repo privat + kostenlos:** GitHub Pages läuft bei privaten Repos nur mit einem bezahlten GitHub-Tarif. Wird das Repo heute privat gestellt, **geht die Live-App sofort offline**. Optionen: GitHub Pro (ca. 4 $/Monat) oder kostenloser Hoster mit Anbindung an das private Repo (z. B. Cloudflare Pages; US-Anbieter, Datenschutz prüfen). Bis zur Entscheidung bleibt das Repo öffentlich.
2. **Kostenloser Server:** Supabase Free hat keine automatischen Backups und pausiert nach 7 Tagen ohne Nutzung. Für Tests ist das in Ordnung. **Vorschlag:** spätestens vor dem ersten zahlenden Laden auf Pro wechseln.
3. **Komplett neu:** Die bisherige App bleibt unverändert live, bis die neue alle Funktionen hat. Umgeschaltet wird nur mit Freigabe. Schätzung (Annahme): 20–30 Arbeitstage mit Claude bis zur vollen Ablösung.
4. **Domain:** Der Name ist noch offen (Dachmarke „PLATFORM BRAND“). Eine Domain kostet Geld und braucht deine Zustimmung.

## Was bisher gebaut ist (ehrlicher Stand)

| Teil | Stand |
|---|---|
| `app/` Grundgerüst (TypeScript/React, Build mit esbuild) | Fertig. Anmeldung mit E-Mail-Code, Laden aus `memberships`, Modul-Navigation, Cockpit liest Kennzahlen aus dem bisherigen Speicher (nur lesen) |
| Design | Alle Farben und Bausteine werden beim Build aus `index.html` übernommen. Schriften liegen lokal in `app/public/fonts` (OFL-Lizenz), keine Google-Server mehr |
| Sicherheit | Content-Security-Policy, keine Fremdskripte, nur öffentlicher Schlüssel |
| Module B–J | Noch **nicht** übertragen. Die neue App zeigt das ehrlich an und verlinkt in die bisherige App |
| Datenbank `docs/supabase/migrations/20270101_01_plattform_kern.sql` | Entwurf. Lokal mit Postgres 16 getestet (zweimal einspielbar, Rechte geprüft). In Supabase **noch nicht eingespielt** |
| Typprüfung (tsc) | Noch nicht möglich, weil die React-Typdefinitionen hier fehlen. esbuild baut ohne Typprüfung. |

## Bauen und testen

```
cd app
node build.mjs          # erzeugt app/dist (nicht im Repo)
```
Lokaler Test gegen den Testserver: `app/dist/index.html?api=http://localhost:8765` (nur localhost erlaubt).

## Reihenfolge (Plan)

1. Migration 01 im Supabase-Projekt einspielen (nach Freigabe) – nur neue Tabellen, nichts Bestehendes ändert sich.
2. Doppelschreiben: Die bisherige App schreibt beim Speichern zusätzlich in die Tabellen. Ein Abgleich prüft, dass alles gleich ist.
3. Module in der neuen App: Kunden → Werkstatt (inkl. Preisliste, Checklisten) → Lager → Verkauf (neu: Aufträge, Rabatte, Retouren, Reservierungen) → Organisation (neu: Urlaub, Schichten) → Netzwerk → Fitting (zuletzt).
4. Endkunden-Konto, Kündigungsregel, Zugriffsprotokoll Pass.
5. Integrationen: externe Kasse mit TSE, Lexware Office / sevDesk, DATEV-Export.
6. Umschalten auf die neue App (nach Freigabe), alte App bleibt als Rückweg.
