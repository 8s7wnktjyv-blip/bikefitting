# Plattform-Ausbau (v.64–v.65, 08.11.2026)

Umsetzung des Master-Auftrags „Ausbau zur Fahrradhandelsplattform“. Stand jeder Funktion: in der App unter **Mehr → Stand aller Funktionen** (Kategorien 1–6).

## Marke
- `BRAND` in index.html: `platform: 'PLATFORM BRAND'` (Platzhalter, Name nicht entschieden), `fit: 'FYF – Fit your Frame'`.
- Umbenennen = diese eine Stelle ändern (+ Titel in finder.html).

## Was neu ist

| Bereich | Wo | Daten | Server |
|---|---|---|---|
| Team & Rollen | Mehr → Team | Supabase `memberships`, `invitations` | team.sql |
| Rechnungs-/Löschschutz | beim Speichern | `save_state` + `fyf_guard` | team.sql |
| Protokoll | – | `audit_log` (nur Admin lesbar) | team.sql |
| Fahrrad-Lebenslauf | Fahrrad öffnen → Lebenslauf | `bike.life`, `bike.events`, `bike.kmLog` | – |
| Warenwirtschaft | Angebote & Lager (unten) | `S.suppliers`, `S.stockMoves`, `item.ek`, `item.supplierId` | – |
| Zahlungen | Rechnung öffnen → Zahlungen | `S.payments` (Rechnung selbst bleibt unverändert, nur Status) | – |
| Filialen | Mehr → Filialen | `S.locations`, Gerät → Filiale in `localStorage['fyf-location']`, `loc` an Kunden/Fittings/Werkstatt | – |
| Import & Export | Mehr → Import & Export | CSV | – |
| Händlerprofil & Anfragen | Händlernetzwerk → Händlerprofil | `dealer_profiles`, `inquiries`, `product.pub` | netz.sql |
| Öffentliche Händlersuche + Marktplatz | `finder.html` | liest `dealer_profiles` (veröffentlicht) und `public_products` | netz.sql |
| Händlerbörse | Händlernetzwerk → Händlerbörse | `trade_offers`, `trade_requests` | netz.sql |
| Plattform-Verwaltung | Händlerprofil (nur Plattform-Admins) | `platform_admins`, `tenants.verified`, `dealer_profiles.certified` | netz.sql |
| Academy | Händlernetzwerk → Academy | `S.academy[E-Mail]` | – |
| Hinweis auf neue Anfragen | Dashboard + Zahl am Menüpunkt (Abfrage alle 60 s und beim Zurückkehren in die App) | `inquiries` | netz.sql |
| Kostenvoranschlag per Link | Werkstatt → Auftrag → „Kostenvoranschlag an Kunden senden“; Kundenseite `freigabe.html` | `kva_links` (Schlüssel 32 Zeichen, 30 Tage gültig, einmal beantwortbar); `wo.kva` | freigabe.sql |
| Datenbank-Lesekopie | – | `fyf_customers`, `fyf_bikes`, `fyf_sessions`, `fyf_invoices`, `fyf_products` per Trigger | netz.sql |

## Zeichnungen und Beinlänge (v.69)
- `FIG` in index.html: Fahrrad maßstabsgetreu (Rad 340 mm, Kettenstrebe 410, Stack/Reach 565/385, Lenkwinkel 73°, Sitzwinkel 73,5°, Kurbel 172,5) und Fahrer nach Körperanteilen (Drillis & Contini). Kniewinkel unten ca. 141°, oben ca. 68° bei Standardmaßen. `FIG_GUIDES` ersetzt die alten Strich-Skizzen; Fahrradgrafik im Fitting nutzt die echten Messwerte (Sattelhöhe, Versatz, Abstand, Überhöhung). Tretbewegung per SVG-Animation (aus bei „Bewegung reduzieren“).
- Beinlänge: `s.legM` = je Seite bis 3 Werte + Gegenprobe im Stehen (Brettchen). `legEval`: unter 10 mm oder innerhalb der Streuung (mind. 5 mm) = „nicht sicher“, kein Ausgleich; ohne Gegenprobe „prüfen“; widersprüchlich = kein Ausgleich; bestätigt = Fachperson, Ausgleich höchstens die Hälfte nach Rücksprache. Mittelwerte bleiben in `check.legLenL/R`.

## v.70
- Alle Anleitungs-Zeichnungen im neuen Stil (`FIG2`): Körpertests (Finger-Boden, Hüftbeugung, Unterarmstütz, Sprunggelenk an der Wand, Hüftrotation, Einbeinstand, einbeinige Kniebeuge, Beinachse, Schultern, Schulterbeweglichkeit, Beschwerden), Füße (Breite, Winkel, Gewölbe, Vorfuß), Cleat längs/Drehung, Sattelneigung, Lenkerbreite, Sitzknochen.
- Kalender (`termine`): Wochenansicht, Termine (`S.appts`), Kapazität je Mitarbeiter (`S.capacity`), Werkstatt-Auslastung aus Arbeitsstunden fälliger Aufträge, Überschneidungs- und Überlast-Hinweis, Bestätigung per Nachricht. Heutige Termine im Dashboard.
- Terminwunsch: finder.html schickt Wunschtermin (`inquiries.preferred`, `docs/supabase/ausbau.sql`); im Laden „Als Termin eintragen“ (Anfrage → in Arbeit). Ohne ausbau.sql landet der Wunsch im Nachrichtentext.
- Bestand je Filiale (`item.byLoc`), Umlagerung, Wareneingang/Plus-Minus auf die Filiale des Geräts.
- Unternehmensstruktur (Gruppe → Unternehmen → Marke → Filiale) innerhalb eines Kontos (`S.org`, `location.company/brand`).
- Kundenportal per Link (`portal.html`, `portal_links`, 180 Tage, sperrbar, nur mit Einwilligung): Fahrräder mit Einstellungen, letzte 3 Fittings mit Änderungen und Empfehlungen, Nachkontrolle, Kontakt, Termin anfragen.

## Sicherheit
- Öffentlich lesbar: nur veröffentlichte Profile und als öffentlich markierte Produkte. Alles andere nur für Mitglieder des Ladens (RLS).
- Anfragen: ohne Konto über `submit_inquiry` (verstecktes Feld, Längen, 20/h je Laden, 3/Tag je Absender). Lesen nur der Laden.
- Börse: nur Läden mit `tenants.verified = true`. Angebote einstellen: Admin/Fitter. Kontaktdaten erst bei bestehender Anfrage.
- „Geprüft“ und „FYF Certified Fitter“ setzt nur ein Plattform-Admin.
- Geheime Schlüssel kommen nirgends vor; finder.html nutzt nur den öffentlichen Schlüssel.

## Bewusst nicht gebaut / offen
- Eigene Kasse mit TSE (Recht/Zertifizierung). Zahlungen werden erfasst; Kartenzahlung läuft am Terminal.
- SumUp-Automatik (Betrag ans Terminal) – braucht SumUp-Zugang, Doku-Prüfung und eine Server-Funktion.
- veloconnect, Großhändler, offizielles DATEV-Format – brauchen Zugänge/Prüfung.
- E-Mail an den Laden bei neuer Anfrage (braucht E-Mail-Dienst). Echte Online-Buchung freier Zeiten (heute: Wunschtermin, Laden bestätigt). Mehrere Konten unter einer Gruppe.
- Schreiben in einzelne Tabellen (heute: ein Datensatz je Laden + Lesekopie).
- Aufteilung von index.html in Module.
- Gemeinsame Marketing-Kampagnen, Herstellernetzwerk, eigene Fitting-Werkzeuge (keine erfundenen Partner oder Maße).

## Tests (08.11.2026)
- SQL mit Postgres 16 lokal: team.sql und netz.sql (Rechte, fremde Läden, anon, Spam-Grenzen, Börse nur geprüft, Plattform-Admin).
- App gegen nachgebauten Server in iPhone-Ansicht: Team (2 Geräte), Profil veröffentlichen, finder.html Liste/Filter/Laden/Anfrage, Anfrage im Laden, Börse zwischen zwei Läden, Plattform-Verwaltung; ohne Cloud: Lebenslauf, Lager, Zahlungen, Academy, Filialen, Import/Export.
- Alte Tests (Cloud, Medien, QR, Rechnungen, Rundgang Handy/PC) ohne Fehler.
- Nicht getestet: gegen echtes Supabase.
