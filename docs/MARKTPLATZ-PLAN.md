# Marktplatz ausbauen – Plan

Stand 23.11.2026 · Wunsch Dominik: „Marktplatz muss so gebaut sein, dass man die Räder von der Pass-App auch reinstellen kann und dass Händler ihre Artikel reinstellen können – Marktplatz insgesamt ausführlicher.“ · **Freigegeben** (Reihenfolge: nach Punkt 27 Filialen/Marken).

## Stand heute (geprüft, v.214)
- Marktplatz (Händlerfinder → Marktplatz) zeigt nur **Gebrauchträder von FYF-Werkstätten**.
- Pass → „Verkaufen“ erzeugt nur einen **Anzeigentext** zum Kopieren für andere Portale, Kaufvertrag und Pass-Übergabe. Privatleute können **nicht** im FYF-Marktplatz inserieren.
- Händler können keine **Teile/Zubehör/Neuware** einstellen.

## Ziel
Ein Marktplatz für **Räder, Teile und Zubehör** von **Privatleuten (aus dem Pass)** und **Händlern/Marken** (z. B. Cunuma-Laufräder) – mit dem FYF-Vorteil, den kein anderes Portal hat: **Räder mit geprüfter Geschichte** (Pass, Werkstatt-Einträge, Diebstahl-Check).

## Funktionen
1. **Privat inserieren aus dem Pass** („Im FYF-Marktplatz anbieten“ im Verkaufen-Dialog): Daten aus dem Pass vorausgefüllt (Marke, Modell, Typ, Größe, Baujahr, Ausstattung, km), bis 8 Fotos (auf dem Handy verkleinert), Preis/VB, Zustand, Ort (nur PLZ/Ort, nie Adresse), Laufzeit 60 Tage, verlängern/beenden/„verkauft“. Pass-Geschichte als Abzeichen („12 Werkstatt-Einträge · kein Diebstahl gemeldet“) – nur wenn der Besitzer sie freigibt. Ohne Konto über den Besitzer-Nachweis des Passes.
2. **Händler und Marken stellen ein** (Händlersoftware): Räder (neu/gebraucht, mit Pass), **Teile und Zubehör** (Kategorie, Marke, Zustand neu/gebraucht, Preis, Menge, Fotos); aus dem Bestand übernehmen; Auftritt wählen (Filiale oder Marke, Punkt 27); Gebrauchträder mit § 25a-Hinweis (Punkt 19).
3. **Suchen und finden:** Kategorien (Rennrad, Gravel, MTB, E-Bike, Stadt/Trekking, Kinder, Laufräder, Komponenten, Zubehör, Bekleidung), Filter (Preis, Größe, Rahmenhöhe, Umkreis, privat/Händler, „mit Fahrradpass“, Zustand), Sortierung, Merkliste (auf dem Gerät), Größen-Hinweis aus dem eigenen Fitting („passt zu dir“), wenn vorhanden.
4. **Detailseite:** Fotogalerie, Daten, Pass-Abzeichen, Verkäufer (Privat/Händler mit Bewertungen), Sicherheitstipps, „Melden“.
5. **Kontakt ohne Datenleck:** Anfrage-Formular; FYF speichert die Nachricht, der Verkäufer sieht sie im Pass bzw. in der Händlersoftware und antwortet dort. Telefonnummer/E-Mail nur, wenn der Verkäufer sie freiwillig zeigt. Kein bezahlter Mail-/SMS-Dienst.
6. **Sicherheit und Recht (Einschätzung, keine Rechtsberatung):** FYF verwahrt nie Geld; Kauf direkt zwischen den Parteien, Käuferschutz nur extern (Kandidat Trustap) als Hinweis. Pflichtangaben Händler (Impressum/Widerruf bei Händlern) im Händlerprofil. Verbotene Inhalte, gestohlene Räder: Rahmennummer wird gegen FYF-Diebstahlmeldungen geprüft, Treffer = Inserat gesperrt. Melden-Knopf → Plattform-Prüfung (wie Bewertungen). Begrenzungen gegen Spam (Anzahl Inserate je Pass/Tag, Textlänge, keine Links).
7. **Fotos:** Supabase Storage im kostenlosen Rahmen; Bilder auf dem Handy auf ca. 1600 px / < 300 KB verkleinern, Metadaten (GPS) entfernen.

## Datenbank (standNN.sql mit Test, Nummern mit Punkt 17/18/19/27 abstimmen)
- `market_listings` (Quelle privat/Händler, Pass-Code oder tenant + Auftritt, Kategorie, Titel, Daten als JSON, Preis, VB, PLZ/Ort grob, Status aktiv/reserviert/verkauft/gesperrt, läuft ab, Zeitstempel).
- `market_photos`, `market_messages` (Anfrage/Antwort, nur Beteiligte lesen), `market_reports`.
- Lesen öffentlich nur aktive Inserate über RPC/Ansicht ohne Kontaktdaten; Schreiben nur über RPC mit Prüfung (Pass-Besitzer-Nachweis bzw. Mitgliedschaft im Laden), Ratenbegrenzung.

## Reihenfolge
1. Händler-Artikel (Teile/Zubehör/Räder) + Kategorien/Filter/Detailseite.
2. Privat-Inserat aus dem Pass + Fotos.
3. Nachrichten, Melden, Diebstahl-Abgleich, Merkliste, „passt zu dir“.
Jeder Schritt getestet und veröffentlicht; Datenbank-Erweiterungen spielt Dominik ein.
