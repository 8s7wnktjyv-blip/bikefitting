# Lösch- und Einwilligungskonzept (Entwurf)

Stand: v.50 · Mustertext, keine Rechtsberatung. Vor echtem Einsatz prüfen lassen.

## Einwilligungen
- Grunddaten (Kontakt, Körpermaße, Einstellungen): Pflicht für das Fitting.
- Gesundheitsangaben (Beschwerden, Körpercheck): eigene, freiwillige Zustimmung (Art. 9 DSGVO).
- Fotos und Videos: eigene, freiwillige Zustimmung. Ohne sie lässt FYF keine Uploads zu.
- Jede Einwilligung wird mit Datum und Textversion gespeichert und ist änderbar.

## Auskunft (Art. 15)
Kundenakte → Persönliche Daten → „Daten exportieren (Auskunft)“: JSON-Datei mit Kunde, Rädern, Fittings, Käufen, Werkstattaufträgen, Nachrichten und der Liste der Fotos/Videos.

## Löschen (Art. 17)
Kundenakte → Persönliche Daten → „Kunde löschen“ (nur Rolle Admin, Name zur Bestätigung):
1. Kunde, Räder, Fittings, Käufe, Werkstattaufträge, Wartungen, Nachrichten, Portal-Freigaben.
2. Fotos und Videos (Metadaten und Dateien auf dem Gerät).
3. Derselbe Kunde auch in den automatischen Sicherungen dieses Browsers.
4. Protokolleinträge zum Kunden werden anonymisiert („[Eintrag zu gelöschtem Kunden]“), nicht gelöscht.

Nicht automatisch erfasst: heruntergeladene Sicherungsdateien und Exporte auf anderen Geräten – diese muss der Betrieb selbst löschen.

Gesperrt: die dauerhaft gespeicherten Daten von Dominik Böhm (Projektentscheidung).

## Aufbewahrung
- Löschfrist im Einwilligungstext eintragen (z. B. X Monate nach dem letzten Termin).
- Mit Server-Datenbank: regelmäßige Prüfung „letzter Termin älter als Frist“ und Löschvorschlag an den Admin.
- Rechnungen/Kaufbelege unterliegen eigenen Aufbewahrungspflichten und gehören nicht in FYF.
