# Plan: Käufer-Link auf Zeit (zur Freigabe)

Stand 21.11.2026 · Punkt 11 „Geprüfte Historie für Käufer“

## Was es schon gibt (geprüft)
- Öffentlicher Pass-Link mit Geschichte; Einträge sind gekennzeichnet: werkstattbestätigt / Werkstatt / selbst eingetragen.
- Kauf-Check für Käufer (Diebstahlmeldung, Ausweis, Beleg, Schlüssel …), Kaufvertrag, Besitzerwechsel per Übergabe-Link.
- Verkaufswerkzeug im Pass erklärt, wie Käufer die Geschichte sehen.

## Was fehlt
Damit ein Käufer die Geschichte sieht, muss der Besitzer seinen Pass heute **dauerhaft auf „Jeder“** stellen.

## Vorschlag
- Im Verkaufswerkzeug: **„Link für Käufer (14 Tage)“**. Erzeugt einen eigenen Link, der nur die werkstattbestätigte Geschichte zeigt (ohne Belegfotos, ohne Preise, ohne Besitzerdaten) und nach 14 Tagen von selbst erlischt. Der Besitzer kann ihn jederzeit zurückziehen.
- Server: neue kleine Tabelle `pass_buyer_links` (Code, Ablaufdatum, Hash des Tokens) und zwei Funktionen (anlegen nur mit Besitzer-Code, lesen mit Token). Der Pass selbst bleibt unverändert und kann auf „nur Werkstätten“ bleiben.
- Tests: Datenbank-Test (abgelaufen = nichts, zurückgezogen = nichts, falscher Token = nichts) und Browser-Test.

## Aufwand / Risiko
Ein Lauf. Neue Tabelle, nichts Bestehendes wird geändert.

## Freigabe
„Käufer-Link: ja“ oder „nein“.
