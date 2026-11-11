# Aufkleber-Bestellung einschalten

Der Knopf „Aufkleber bestellen“ in der FYF-Pass-App ist fertig gebaut, aber **ausgeschaltet**, solange keine Bezahl-Links eingetragen sind.

## Voraussetzungen (vor dem ersten Verkauf)
1. Jobcenter informiert, Gewerbe angemeldet
2. Impressum (`impressum.html`), Datenschutz (`datenschutz.html`) und Bestellinfos (`kauf.html`) ausgefüllt – alle Stellen in eckigen Klammern
3. Umsatzsteuer geklärt: Preise inkl. MwSt. oder Kleinunternehmerregelung (§ 19 UStG) – Satz in `kauf.html` anpassen

## Stripe einrichten (am iPhone in Safari oder in der Stripe-App)
1. Konto anlegen auf stripe.com (keine Grundgebühr)
2. Produkte → „FYF-Aufkleber“ 4,90 € und „FYF-Aufkleber 2er-Set“ 7,90 €
3. Je Produkt einen **Zahlungslink** erstellen:
   - „Versandadresse erfassen“ einschalten, Land: Deutschland
   - „Benutzerdefiniertes Feld“ hinzufügen: *Fahrradpass-Code* (Text, optional)
   - Nach der Zahlung: „Zu Ihrer Website weiterleiten“ → `https://8s7wnktjyv-blip.github.io/bikefitting/rad.html#bestellt=1`
4. Die beiden Links (`https://buy.stripe.com/…`) an Claude schicken. Sie werden in `rad.html` bei `ORDER.one` und `ORDER.two` eingetragen.

Die App hängt den Pass-Code automatisch als `client_reference_id` an den Link. Zusätzlich steht der Code im Bestellfenster zum Abschreiben.

## Übergangslösung ohne Stripe
Statt der Links nur `ORDER.whatsapp` (Nummer) oder `ORDER.mail` eintragen – dann öffnet der Knopf eine fertige Nachricht mit dem Pass-Code.

## Ablauf nach einer Bestellung
Stripe-App zeigt Bestellung mit Adresse und Code → in FYF Aufkleber drucken (Pass öffnen → Etikett) → Brief verschicken.
