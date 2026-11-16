# E-Rechnung – Beispieldateien

Testdaten (kein echter Kunde), erzeugt mit der Funktion `invXml` der Händlersoftware:
`inv_brutto.xml` (Privatkunde), `inv_netto.xml` (Firmenkunde), `inv_storno.xml` (Stornorechnung).

Der Workflow „E-Rechnung prüfen“ prüft sie mit dem offiziellen KoSIT-Validator und der XRechnung-Konfiguration.
Nach Änderungen an `invXml` die Dateien neu erzeugen (Skript `txr.js` im Testordner) und hier ersetzen.
