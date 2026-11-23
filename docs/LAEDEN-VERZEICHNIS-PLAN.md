# Alle Fahrradläden im Händlerfinder – Plan

Stand: 23.11.2026 · Freigabe Dominik 23.11.2026: „Ok dann Läden mit eintragen in der App“ (Stufe 1 und 2 nach diesem Plan).

## Ziel
Unter „Werkstätten“ sollen nicht nur FYF-Partner stehen, sondern **alle Fahrradläden** in der Nähe. So ist die Liste für Pass-Nutzer sofort nützlich. Läden, die ihren Eintrag pflegen wollen, melden sich von selbst bei FYF – das ist Vertrieb ohne Anrufe.

**Kein neuer Preis.** Eintrag und Übernahme sind kostenlos. Gezahlt wird weiter nur die Software (99 €/149 € pro Standort und Monat).

## Drei Stufen

| Stufe | Was der Laden hat | Kosten | Quelle |
|---|---|---|---|
| 1 Automatischer Eintrag | Name, Adresse, Öffnungszeiten, Telefon, Website, Route | kostenlos | OpenStreetMap |
| 2 Eintrag übernommen | wie 1, dazu selbst gepflegt: Öffnungszeiten, Foto, Kontakt, Leistungen | kostenlos | Laden, von FYF bestätigt |
| 3 FYF-Partner (Software) | Abzeichen, Termine buchen, Werkstatt-Status live, Bewertungen, Pass-Einträge, Marktplatz | 99/149 € | FYF-Software |

## Stufe 1 – Läden aus OpenStreetMap (ohne Datenbank-Änderung)
- Im Händlerfinder unter der Liste der FYF-Partner: Bereich **„Weitere Fahrradläden in der Nähe“**.
- Start nur auf Knopfdruck: „Meinen Standort verwenden“ oder Ort/PLZ eingeben.
  - Standort: wie bei „Helfer in der Nähe“ auf ~100 m gerundet, nichts gespeichert.
  - Ort/PLZ in Koordinaten umwandeln: kostenloser OpenStreetMap-Dienst Nominatim (max. 1 Anfrage pro Sekunde, nur auf Knopfdruck, Ergebnis im Browser zwischenspeichern).
- Abfrage `shop=bicycle` über Overpass (dieselbe Funktion wie im Pass, Ausweich-Server), Umkreis 5 km, erweiterbar auf 10/25 km.
- Doppelte vermeiden: Liegt ein OSM-Laden nahe an einem FYF-Partner mit ähnlichem Namen, nur den FYF-Partner zeigen.
- Darstellung klar getrennt: graue Karte, Kennzeichen **„Kein FYF-Partner · Daten von OpenStreetMap“**, keine Abzeichen, keine Sterne, kein Anfrage-Formular. Knöpfe: Route (Apple Karten), Anrufen, Website.
- Pflichthinweis: „Daten © OpenStreetMap-Mitwirkende“.
- Auf jeder OSM-Karte unten klein: **„Ist das Ihr Laden? Eintrag übernehmen“** (→ Stufe 2).
- Englisch: alle neuen Texte in `pass-en.js`.

## Stufe 2 – „Eintrag übernehmen“ (kleine Datenbank-Erweiterung)
- Formular: Name des Ladens (vorausgefüllt), Ansprechpartner, E-Mail oder Telefon, Hinweis „Ich bin berechtigt, für diesen Laden zu sprechen“.
- Speichern als Anfrage in einer neuen Tabelle (z. B. `shop_claims`: OSM-ID, Ladenname, Kontakt, Zeitpunkt, Status offen/bestätigt/abgelehnt). Schreiben für alle (anon) nur per RPC mit Grenzen (Länge, max. 3 Anfragen pro Stunde je OSM-ID), Lesen nur Plattform-Admin.
- **Bestätigung macht Dominik von Hand:** Er ruft die öffentliche Telefonnummer des Ladens an (nicht die im Formular angegebene). FYF versendet nichts automatisch.
- Nach Bestätigung bekommt der Laden ein kostenloses FYF-Konto mit veröffentlichtem Profil, aber ohne Abo-Funktionen (Termine, Status live, Bewertungen, Pass-Einträge bleiben Partnern vorbehalten).
- Im Plattform-Bereich der Händlersoftware: Liste der Anfragen mit „Bestätigen“/„Ablehnen“.
- Datenbank-Erweiterung als `stand31.sql` mit Test; Dominik spielt sie über „Datenbank aktualisieren“ ein.

## Später (nicht freigegeben)
- Monatlicher Hinweis an Läden mit Gratis-Eintrag („Ihr Eintrag wurde 40× angesehen …“): braucht Mailversand → erst mit Dominik klären (kostenpflichtiger Dienst, Einwilligung).
- Kartenansicht statt Liste (Kacheldienst-Nutzungsregeln beachten).

## Recht und Fairness (Einschätzung, keine Rechtsberatung)
- Öffentliche Firmendaten anzeigen ist üblich. Es darf **nicht nach Partnerschaft oder Empfehlung aussehen** – deshalb die graue Darstellung und das Kennzeichen.
- Jeder Laden kann seinen Eintrag **ausblenden lassen**: Link „Eintrag entfernen lassen“ (gleiche Anfrage-Tabelle, Typ „entfernen“). Ausgeblendete OSM-IDs werden nicht mehr angezeigt.
- OpenStreetMap-Daten stehen unter ODbL: Quelle nennen; nur anzeigen, nicht dauerhaft in eigene Datenbank kopieren.
- Datenschutzerklärung um Nominatim und „Eintrag übernehmen“ ergänzen.

## Tests
- Stufe 1: Mock für Overpass und Nominatim (keine echten Netzaufrufe im Test), Trennung FYF-Partner/OSM, Doppel-Erkennung, Englisch.
- Stufe 2: `stand31_test.sql` (anon kann nur über RPC anfragen, nicht lesen; Grenzen greifen), Browser-Test für Formular und Admin-Liste.

## Reihenfolge
1. Stufe 1 bauen, testen, veröffentlichen.
2. Stufe 2 bauen, `stand31.sql` vorbereiten, im Bericht um das Einspielen bitten.
