# Foto-Messung (Beta)

Stand: 15.11.2026 · v.107 · Status: **eingebaut, Rechnung automatisch geprüft, am echten Rad noch nicht getestet**

## Entscheidungen
- Kein eigenes Mess-Programm: neue Messart im Bereich „Messen“, die Werte landen in denselben Feldern wie Maßband-Werte.
- Maßstab über ein Messzeichen bekannter Länge in der Mitte des Rads (nicht über die Kurbellänge).
- Schiefes Bild: Ausgleich über zwei Punkte auf der waagerechten Laserlinie; ohne Linie Hinweis, das iPhone gerade auszurichten („Ausrichtung prüfen“ über den Lagesensor).
- Vorhandene Werte werden nie ohne Haken überschrieben.
- Unsicherheit wird vorsichtig geschätzt (mindestens ±3 mm), bis der Praxistest echte Zahlen liefert.
- Nur Rad, keine Person auf dem Foto. Nachweis-Foto nur mit Foto-Einwilligung.

## Rechnung
- Funktion `fotoCalc` in `index.html` (zwischen `FOTO-CALC-START` und `FOTO-CALC-END`).
- Test: `node tools/test-foto-messung.mjs` – erfundene Räder mit bekannten Maßen, Rad nach links/rechts, Bild gedreht, verschiedene Maßstäbe, fehlende Punkte, Warnungen.

## Bekannte Grenzen
- Perspektive: Liegt das Messzeichen nicht in der Mitte des Rads oder steht das iPhone nicht rechtwinklig, stimmt der Maßstab nicht.
- Sattelhöhe stimmt nur, wenn der Punkt „Sattel oben“ in der Verlängerung des Sitzrohrs liegt.
- Lenkermitte = Lenkeroberseite minus 16 mm (wie in der übrigen Koordinaten-Rechnung).

## Praxistest (offen)
Am Rad: je Wert 3× Maßband, 3 Fotos. Ziel: höchstens ±2–3 mm Abweichung.

| Wert | Maßband (Mittel) | Foto (Mittel) | Abweichung |
|---|---|---|---|
| Sattelhöhe | | | |
| Sattel über Boden | | | |
| Lenker über Boden | | | |
| Sattelversatz | | | |
| Lenkermitte vor Tretlager | | | |

Erst nach bestandenem Test: Genauigkeit eintragen und „Beta“ entfernen. Wird das Ziel verfehlt, bleibt die Funktion als Orientierung markiert.
