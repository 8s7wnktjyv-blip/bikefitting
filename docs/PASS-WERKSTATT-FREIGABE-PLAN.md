# Plan: Werkstatt-Freigabe (7 Tage) und Schadens-Einträge von Läden (zur Freigabe)

Wunsch von Dominik (22.11.2026). Beides braucht **Änderungen an der Datenbank** und wird deshalb erst nach Ihrer Freigabe gebaut.

## 1. Werkstatt-Freigabe mit Ablaufdatum
**Ziel:** Der Besitzer gibt einer Werkstatt für 7 Tage (wählbar 1/7/30 Tage) Zugriff auf seinen Pass, ohne Konto und ohne seinen Besitzer-Code.

**Ablauf:**
1. Im Pass „Werkstatt freigeben“ antippen. Es entsteht ein Link oder QR-Code mit zufälligem Schlüssel.
2. Die Werkstatt öffnet den Link in der FYF-Software. Ab dann sieht sie:
   - Teile und Kilometer
   - offene Schäden
   - Sitzposition
3. Die Werkstatt kann **Einträge hinzufügen**: Service, Teiletausch, Schaden mit Foto und Status. Sie kann nichts löschen und nichts ändern.
4. Nach Ablauf ist der Schlüssel tot. Der Besitzer kann jederzeit vorher „Freigabe beenden“ antippen.

**Technik (Supabase, Stand 30):**
- Neue Tabelle `pass_grants` mit Spalten `code`, `token_hash`, `shop_tenant`, `expires_at` und `revoked_at`.
- Neue Funktionen:
  - `grant_create`: nur mit Besitzer-Code
  - `grant_use`: legt die Werkstatt fest, prüft das Ablaufdatum
  - `grant_revoke`
- `pass_add_entry` prüft zusätzlich eine gültige Freigabe. RLS bleibt „nur über Funktionen“.
- Schadens-Einträge als neue Eintragsart `kind='Schaden'` mit `status` in `pass_entries`. Damit ist **kein Löschen möglich** (wie heute schon bei Werkstatt-Einträgen).

**Aufwand:** ca. 2 Läufe, mit Test gegen lokales Postgres und Browser-Test.

## 2. Versicherung
Eine Versicherung direkt anbinden geht nicht ohne Vertrag mit dem Versicherer. Möglich ist schon jetzt das PDF „Unterlagen für die Versicherung“ (Schaden, Fotos, Rechnung, Pass-Auszug). Das ist der nächste Schritt und braucht keine Freigabe.

## 3. Tracker
AirTag, Chipolo, Tile und Specialized haben **keine offene Schnittstelle**. FYF kann sie also nicht selbst orten.

**Umgesetzt (v.144):**
- Tracker-Typ, Name und Versteck werden gespeichert. Das Versteck bleibt nur auf dem Gerät.
- Knopf zur Hersteller-Suche (Apple „Wo ist?“, Samsung SmartThings Find).

**Möglich später:** GPS-Tracker mit eigener Schnittstelle (z. B. PowUnity), aber nur wenn der Hersteller die Schnittstelle kostenlos anbietet.

## Was Sie entscheiden müssen
- Freigabe für Punkt 1 (Datenbank Stand 30)? Danach müssen Sie wie gewohnt einmal das Datenbank-Update in GitHub Actions starten.
