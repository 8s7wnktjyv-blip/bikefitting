# FYF – Bestandsaufnahme, Marktcheck und Roadmap (Passport, Network, Market)

Stand: 10.11.2026 · App-Version v.82 · Datenbank Stand 13.
Dieses Dokument ist **nur Analyse und Plan**. Umgesetzt ist ausschließlich, was unter „Bestand“ als vorhanden markiert ist.

Legende: ✅ vorhanden · 🟡 vorhanden, verbesserungswürdig · 🟠 teilweise · ❌ fehlt
Kennzeichnung: **[Fakt]** belegt (Quelle oder getestet) · **[Schätzung]** eigene Einschätzung · **[Offen]** muss Dominik entscheiden

---

## 1. Kurzfazit

1. **Ein digitaler Fahrradpass allein ist nicht neu.** [Fakt] Es gibt bereits Velopass, BikePass, Radwache, bikecheck.eu, die Fahrradpass-App der Polizei, Fahrradpässe in Apps wie linexo, das digitale Serviceheft von Bosch und seit 2026 CrankPal (kostenlose Werkstattsoftware mit Fahrradpass).
2. **Neu wäre die Kombination**, die keiner der genannten Anbieter erkennbar hat. Grundlage ist das, was FYF schon kann. [Schätzung]
   - **Der Pass füllt sich von selbst.** Jeder Werkstattauftrag, jedes Teil, jedes Fitting und jeder Gebrauchtrad-Check landet ohne zusätzliche Eingabe im Pass. Bei den anderen Pässen trägt meist der Besitzer selbst ein.
   - **Vertrauensstufen pro Eintrag.** Jeder Eintrag zeigt, ob er werkstatt-bestätigt, belegt oder Selbstauskunft ist. Er kann nicht still geändert werden, und es bleibt sichtbar, wer ihn wann eingetragen hat.
   - **Fahrzeugschein-Prinzip mit zwei Teilen.**
     - Teil I ist der QR-Aufkleber mit dem öffentlichen Code.
     - Teil II ist eine Karte mit einem **geheimen Übergabe-Code** für den Besitzerwechsel.
     - Wer nur den Aufkleber hat, kann das Rad nicht übernehmen.
   - **Fitting-Daten im Pass.** Die Sitzposition zieht mit dem Rad oder dem Fahrer um. Das hat kein Wettbewerber, denn FYF ist im Kern Bikefitting.
   - **Offen für jede Werkstatt.** Auch Läden ohne FYF-Abo können eintragen. Das macht den Pass mit der Zeit vollständiger als jedes Händler-Inselsystem.
3. **Größtes Risiko: CrankPal.** [Fakt] Das Angebot ist kostenlos, hat einen Fahrradpass und ist in vielen Ländern verfügbar. Gegen kostenlos gewinnt FYF nicht über den Preis, sondern nur über Bikefitting, Deutsch, Nähe und Netzwerk. [Schätzung]
4. **Empfehlung:**
   - Als Nächstes den **Passport-Kern** bauen: Vertrauensstufen, nicht änderbare Einträge, Fahrradschein mit Übergabe-Code und Etikett vom Etikettiergerät.
   - Marktplatz, Käuferschutz, Affiliate und KI erst, wenn mindestens 3 Läden FYF wirklich nutzen.
   - Wenn es vorher keine Nutzer gibt, ist jede dieser Funktionen eine leere Hülle. [Schätzung]

---

## 2. Marktcheck (Recherche 10.11.2026)

| Anbieter | Was es ist | Unterschied zu FYF |
|---|---|---|
| CrankPal | Italienisches Start-up. Kostenlose Werkstattsoftware mit Fahrradpass, Wartungsprognose und Besitzerwechsel, in vielen Märkten | Kein Bikefitting. Datenhoheit liegt beim Anbieter. [Fakt laut Bericht, Details nicht selbst getestet] |
| Bosch digitales Serviceheft / „Certified by Bosch“ | Service-Historie und Zertifikat für gebrauchte E-Bikes | Nur Bosch-Antriebe |
| Velopass, BikePass (bikepass.eu), Radwache, bikecheck.eu | Fahrradpass bzw. Registrierung, teils mit Aufkleber | Vom Nutzer genannt. Funktionsumfang nicht im Detail geprüft |
| Fahrradpass-App der Polizei | Daten des Rads offline auf dem Handy, ausdruckbar im Diebstahlfall | Kein Register, keine Werkstatt-Einträge |
| linexo-App | Fahrradpass in einer Versicherungs- und Service-App | Fokus auf Versicherung |

Quellen:
- [CrankPal – Gravel Cyclist](https://www.gravelcyclist.com/bicycle-tech/italian-start-up-crankpal-rolls-out-predictive-bike-maintenance-free-workshop-woftware-across-59-markets/)
- [Bosch-Zertifikat gebrauchte E-Bikes – pedelec-elektro-fahrrad.de](https://pedelec-elektro-fahrrad.de/news/bosch-fuehrt-digitales-zertifikat-fuer-gebrauchte-e-bikes-ein/665097/)
- [Polizei-Fahrradpass-App – iphone-ticker](https://www.iphone-ticker.de/lka-empfiehlt-einsatz-der-fahrradpass-app-81479/)
- [linexo Fahrradpass](https://www.linexo.de/magazin/ausruestung-zubehoer/mit-dem-fahrradpass-auf-nummer-sicher-gehen)

### Polizei-Registrierung
- [Fakt] In Deutschland gibt es **kein zentrales Fahrradregister der Polizei**, in das FYF eintragen könnte.
- [Fakt] Es gibt eine Codierung, die die örtliche Polizei oder der ADFC graviert, sowie die Polizei-App als persönliches Dokument.
- **FYF kann deshalb nicht „bei der Polizei registrieren“.** Möglich und sinnvoll ist:
  - Pass-Export mit genau den Angaben, die die Polizei für eine Anzeige braucht: Rahmennummer, Marke, Modell, Farbe, Merkmale, Fotos, Kaufbeleg.
  - Ein „Diebstahl-Paket“ mit einem Tipp: Rad im Pass als gestohlen markieren, PDF für die Online-Wache erzeugen und dem Laden Bescheid geben.
  - Ein Feld „Codierung (EIN-Code)“ im Rad.
- Hinweis-Pflicht: Fehlt eine Meldung in FYF, ist das **kein Nachweis**, dass das Rad nicht gestohlen ist. Seit v.79 steht das so in der Käuferansicht.

### Batteriepass ab 18.02.2027
- [Fakt] Art. 77 der EU-Batterieverordnung 2023/1542: Ab 18.02.2027 braucht jede neu in Verkehr gebrachte **LV-Batterie** einen digitalen Batteriepass mit QR-Code. LV-Batterie heißt Batterie für leichte Verkehrsmittel, darunter fallen E-Bike-Akkus. Eine 2-kWh-Grenze gilt dort nur für Industriebatterien. Quelle: [Art. 77 VO (EU) 2023/1542](https://gesetze.legal/eu/vo_eu_2023_1542/77)
- [Fakt] Die Pflicht trifft den **Hersteller bzw. Inverkehrbringer** des Akkus, nicht die Werkstatt und nicht FYF.
- Ob die EU die Frist inzwischen verschoben hat, habe ich nicht geprüft.
- **Chance für FYF:**
  - Im Rad ein Feld „Batteriepass“ (Link oder QR des Herstellers) und die Akku-Seriennummer.
  - Der FYF-Pass verlinkt den Batteriepass des Herstellers und verbindet ihn mit Akku-Messwerten wie Restkapazität aus dem Gebrauchtrad-Check.
  - FYF erzeugt **keine** Batteriepässe, das darf nur der Hersteller.

### Käuferschutz (Trustap)
- [Fakt laut Sharetribe-Artikel, nicht bei Trustap bestätigt]
  - Kosten: ab etwa 50 $ im Monat plus Einrichtung, dazu etwa 5 % + 0,40 $ pro Verkauf.
  - Trustap ist „Merchant of Record“: Es hält das Geld und bearbeitet Streitfälle.
  - Deutschland ist nicht ausdrücklich genannt.
  - Quelle: [Sharetribe – Trustap overview](https://www.sharetribe.com/academy/marketplace-payments/trustap-overview/)
- [Fakt] Marktplatzbetreiber haben in Deutschland Meldepflichten nach dem Plattformen-Steuertransparenzgesetz (DAC7). Quelle: [eBay-Info DAC7/PStTG](https://static.ebayinc.com/static/assets/Uploads/PressRoom/Local/eBay-Onepager-DAC7-und-PStTG.pdf?dl=1)
- **Empfehlung:** Jetzt nicht integrieren. Laufende Kosten entstehen auch ohne einen einzigen Verkauf. Erst „Verified Used Bikes“ als Anzeige mit Pass-Link und Kontakt zum Verkäufer anbieten, ohne Zahlung über FYF.

---

## 3. Bestandsaufnahme (geprüft im Code, v.79)

| Bereich | Status | Was es gibt | Was fehlt für die neuen Konzepte |
|---|---|---|---|
| Dashboard | 🟡 | Ladenweit (v.78): Heute-Zeile, Werkstatt offen, Termine heute, fällige Aufträge, Erinnerungen, Erfolgsbericht | Neue Passports, Passport-Aktivität, Umsatz-Kachel kompakter |
| Kunden | ✅ | Kundenakte, Einwilligung mit Unterschrift, Erinnerungen nur mit Zustimmung | Kundenkonto für Endkunden (heute nur Link-Portal) |
| Fahrräder | ✅ | Fahrradakte, Ereignisse, Teile aus Aufträgen, Fahrradpass-Druck (v.77), Leasing | Fotos, Originalausstattung vs. aktuell, Akku-Seriennummer, Batteriepass-Link, Codierung |
| QR-Fahrradpass | 🟠 | v.79: Code mit 8 Zeichen, Aufkleber-Druck, Sichtbarkeit, Diebstahl-Markierung, Einträge anderer geprüfter Läden, Rahmennummer gekürzt | Vertrauensstufen pro Eintrag, Schutz gegen Überschreiben, Besitzerwechsel, Selbstauskunft, Belege, Etikettiergerät-Format, Fahrradschein |
| Werkstatt | ✅ | Annahme mit Unterschrift, Kostenvoranschlag mit Online-Freigabe, Status, Checklisten, Live-Status-Link (v.79) | Verbindung Auftrag → Pass ist da; Vertrauensstufe „werkstatt-bestätigt“ fehlt |
| Gebrauchtrad-Check | ✅ | v.79: Checkliste, Gesamtzustand, Zertifikat, Abrechnung | Fotos, standardisierter Zustandsbericht für den Marktplatz |
| Kalender / Online-Termine | ✅ | Freie Zeiten in der Händlersuche | – |
| Rechnungen, Angebote, Lager, Produkte | ✅ | inkl. E-Rechnung | Verknüpfung Beleg → Pass-Eintrag (Rechnung als „Beleg vorhanden“) |
| Bikefitting | ✅ | Kompletter Ablauf, Bewegungsanalyse, Berichte | Fitting-Werte mit Zustimmung in den Pass (Sitzhöhe, Setback, Reach, Cleats) |
| Geometrie, Messmittel, Produktdatenbank, Wissen | ✅ | Mit Quellenangabe | Keine Herstellerschnittstellen. Kompatibilitätsprüfung nur mit lizenzierten Daten |
| Händlerprofil & Anfragen, Händlersuche | ✅ | Öffentliches Profil, Anfragen, Partnerseite mit Abzeichen (v.79), Pass-Code-Prüfung | Partnersiegel und Hervorhebung, Bewertungen nur aus echten Aufträgen |
| Händlerbörse (B2B) | 🟡 | Restposten unter geprüften Händlern | – |
| B2C-Marktplatz | ❌ | Nur Produkte im Händlerprofil | Bereich „Verified Used Bikes“ |
| Academy | 🟡 | Lernpfade | – |
| Rollen, Rechte | 🟡 | Laden-Mitglieder, Plattform-Admin, Händler-Prüfung (`verified`), RLS | Rollen Endkunde, Bikefitter-Profil, Creator/Affiliate |
| Datenbank-Updates | ✅ | GitHub-Aktion, Stand-Anzeige in der App | – |
| Bezahlung (Händler-Abo, Aufkleber) | ❌ | Preis 99 € nur als Text | Zahlungsweg, Rechnungen an Händler, Widerruf |
| Affiliate / Creator | ❌ | – | Komplett |

**Überschneidungen, die vermieden werden:**
- **Fahrradpass:** Es bleibt bei einer Fahrradverwaltung. Der Pass ist eine Eigenschaft des vorhandenen Fahrrads (`b.qr`) und keine zweite Akte. Der Online-Pass wird aus der Fahrradakte erzeugt.
- **„Fahrzeugschein“:** Der Druck aus v.77 und der QR-Pass aus v.79 werden zusammengeführt. Der Fahrradschein ist nur eine weitere Druckansicht derselben Daten.
- **Partnerverzeichnis:** Die Händlersuche (`finder.html`) ist das Partnerverzeichnis. Es kommt kein zweites dazu.
- **Marktplatz:** „Verified Used Bikes“ kommt in die Händlersuche bzw. die vorhandene Produktanzeige, kein drittes System. Die B2B-Börse bleibt getrennt, weil sie nur für Händler ist.

---

## 4. Integrationskonzept FYF Passport

### 4.1 Datenmodell (erweitert, nicht neu)
- **Bike-ID = Pass-Code**, z. B. `K7QM3XPA`. Er ist dauerhaft und bleibt bei Besitzer- und Werkstattwechsel gleich. Gibt es bereits (v.79).
- **Pass-Einträge sind unveränderlich.** Eine Korrektur ist ein neuer Eintrag „korrigiert Eintrag Nr. X“. Der Schutz liegt in der Datenbank selbst: Ändern und Löschen sind gesperrt, Einfügen ist erlaubt.
- Jeder Eintrag bekommt:
  - Herkunft: welcher Betrieb oder der Besitzer
  - Zeitstempel
  - Vertrauensstufe:
    1. **Werkstatt-bestätigt**: eingetragen von einem geprüften Betrieb, mit oder ohne FYF-Abo
    2. **Beleg vorhanden**: Rechnung oder Foto hängt an
    3. **Selbstauskunft**: vom Besitzer eingetragen
- **Besitz:**
  - Die Tabelle „Halter“ speichert nur Konto-Kennungen, nie Namen.
  - Frühere Besitzer sind in der Käuferansicht nur als „Besitzer 1, 2, 3 seit MM/JJJJ“ sichtbar.
- **Besitzerwechsel nach dem Fahrzeugbrief-Prinzip:**
  1. Der Verkäufer gibt dem Käufer die Karte mit dem **Übergabe-Code** (Teil II).
  2. Der Käufer tippt den Code ein und übernimmt den Pass.
  3. Der alte Code wird ungültig, ein neuer wird erzeugt.
  4. Ohne Code geht es nur über die ausstellende Werkstatt, zum Beispiel wenn die Karte verloren ist.
- **Fehlen von Meldungen** wird nie als „sauber“ angezeigt (umgesetzt).

### 4.2 Physischer Pass
- **Teil I – QR-Aufkleber:**
  - Phase 1 ist das **Etikettiergerät**. Die App erzeugt dafür ein Bild in der passenden Bandbreite, das der Laden in die App des Etikettiergeräts lädt. [Offen] Welches Gerät hast du?
  - Brother P-touch mit laminiertem TZe-Band ist laut Hersteller wasser- und abriebfest.
  - Thermo-Etiketten, z. B. von Niimbot, sind meist **nicht** dauerhaft wetterfest. Dann klare Folie darüberkleben. [Schätzung]
  - Phase 2 sind gedruckte Folien-Aufkleber von einer Druckerei, sobald es mehr als etwa 100 Stück im Monat sind. [Schätzung]
- **Teil II – Fahrradschein im Scheckkarten-Format:**
  - Vorderseite: Rad, Rahmennummer, Code, QR.
  - Rückseite: der verdeckte Übergabe-Code, z. B. unter Rubbelfeld oder Klebestreifen. In Phase 1 einfach umgeknickt und versiegelt.
- **Kürzerer Link:** Ein QR-Code mit kurzer Adresse lässt sich auch auf 12–18 mm breitem Band sicher scannen. Dafür braucht es eine eigene Domain. [Offen] Kosten etwa 10–20 € im Jahr. Markenname muss vorher feststehen.

### 4.3 Wer darf was
| Rolle | Darf | Darf nicht |
|---|---|---|
| Käufer/Öffentlichkeit | Pass sehen, wenn öffentlich; Diebstahl-Status sehen | Besitzer sehen, eintragen |
| Besitzer (Konto, kostenlos) | Selbstauskunft, Belege, Sichtbarkeit, gestohlen melden, Pass übergeben | Werkstatt-Einträge ändern |
| Geprüfter Betrieb **ohne** FYF-Abo | Werkstatt-Einträge (bestätigt), Gebrauchtrad-Check | Cockpit, Netzwerk-Vorteile |
| FYF-Händler (99 €/Monat) | Alles: Cockpit, Fitting, Netzwerk, Hervorhebung, Siegel | – |
| Plattform-Admin | Betriebe prüfen, Missbrauch sperren | Kundendaten der Läden sehen |

---

## 5. Roadmap

Bewertung jeweils 1–5. Spalten: **K** Kunde, **H** Händler, **I** Innovation, **W** Wettbewerbsvorteil, **A** Aufwand, **L** laufende Kosten, **R** Rechtsrisiko, **M** Monetarisierung. Für A, L und R gilt: höher ist schlechter. Alles [Schätzung].

### A – Must-have
| Funktion | K | H | I | W | A | L | R | M | Hängt ab von |
|---|---|---|---|---|---|---|---|---|---|
| Vertrauensstufen + unveränderliche Einträge | 5 | 4 | 4 | 4 | 2 | 1 | 1 | 3 | QR-Pass v.79 |
| Fahrradschein mit Übergabe-Code (Besitzerwechsel) | 5 | 3 | 5 | 5 | 3 | 1 | 2 | 4 | Besitzer-Konto |
| Etikett für Etikettiergerät + Bestellung Aufkleber 4,90 € | 4 | 3 | 2 | 3 | 1 | 1 | 2 | 4 | Gewerbe, Impressum |
| Besitzer-Konto light (Anmeldung per E-Mail-Code, kostenlos) | 5 | 3 | 3 | 4 | 3 | 1 | 3 | 2 | vorhandener E-Mail-Login |
| Werkstattauftrag → Pass-Eintrag „bestätigt“ automatisch | 4 | 5 | 4 | 5 | 1 | 1 | 1 | 3 | vorhanden |
| Diebstahl-Paket (Anzeige-PDF, Markierung) + Codierungsfeld | 5 | 2 | 3 | 3 | 1 | 1 | 2 | 1 | – |
| Dashboard: neue Passports, Pass-Aktivität | 2 | 4 | 1 | 2 | 1 | 1 | 1 | 1 | – |

### B – Wettbewerbsvorteil
| Funktion | K | H | I | W | A | L | R | M |
|---|---|---|---|---|---|---|---|---|
| Fitting-Werte im Pass (mit Zustimmung), „Position mitnehmen“ aufs neue Rad | 5 | 5 | 5 | 5 | 2 | 1 | 2 | 4 |
| Offener Zugang für geprüfte Nicht-FYF-Werkstätten (nur Pass) | 3 | 3 | 4 | 5 | 2 | 1 | 2 | 3 |
| Verified Used Bikes in der Händlersuche (Anzeige mit Pass-Link, ohne Zahlung) | 5 | 4 | 4 | 4 | 3 | 1 | 3 | 3 |
| Batteriepass-Link + Akku-Messwerte im Pass | 4 | 4 | 3 | 3 | 1 | 1 | 1 | 2 |
| Bewertungen nur nach abgeschlossenem Auftrag | 4 | 4 | 3 | 4 | 2 | 1 | 2 | 2 |

### C – Zukunft (erst mit Nutzern)
| Funktion | Warum später |
|---|---|
| Käuferschutz (Trustap o. ä.) | Fixkosten ohne Umsatz, DAC7-Pflichten, Vertrag nötig |
| Affiliate/Creator mit Provisionen | Braucht zahlende Kunden, Buchhaltung, Rückbuchungen |
| Hersteller-Schnittstellen, Rückruf-Alarm | Es gibt keine offene Schnittstelle der Hersteller. Rückrufe nur aus öffentlichen Quellen (z. B. EU Safety Gate), manuell gepflegt |
| KI-Assistent über eigene Daten | Laufende Kosten pro Anfrage. Heute: Schreibhilfe mit Textvorlagen |
| Preisermittlung Gebrauchtrad | Braucht viele echte Verkäufe als Vergleich |

### D – Nicht sinnvoll (jetzt)
| Funktion | Grund |
|---|---|
| Eigene Kompatibilitätsdatenbank „für alle Teile“ | Ohne lizenzierte Herstellerdaten unzuverlässig, Haftungsrisiko |
| Eigene Treuhand oder Zahlungsabwicklung | Rechtlich nicht machbar (Zahlungsdiensteaufsicht), ausdrücklich ausgeschlossen |
| Polizei-Registrierung durch FYF | Gibt es nicht. Nur Export und Hinweise |
| Batteriepässe selbst ausstellen | Pflicht und Recht des Herstellers |
| Wartungsprognose ohne Messdaten | Würde Zahlen erfinden. Erst mit km, Kettenmessung usw. |

---

## 6. Reihenfolge der Umsetzung (Vorschlag)

| Schritt | Inhalt | Datenbank | Dauer [Schätzung] |
|---|---|---|---|
| **v.80 Passport-Kern** ✅ umgesetzt 10.11.2026 (Beleg-Stufe folgt mit v.81) | Vertrauensstufen, Sperre gegen Überschreiben, Werkstatt-Einträge automatisch bestätigt, Fahrradschein-Druck (Teil I + II), Etikett-Bild fürs Etikettiergerät, Diebstahl-Paket, Felder Codierung, Akku-Nr., Batteriepass-Link | Stand 11 | 1 Sitzung |
| **v.81 Besitzer** | Besitzer-Konto per E-Mail-Code, Selbstauskunft, Pass übernehmen mit Übergabe-Code, Belege als Foto/PDF | Stand 12 | 1–2 Sitzungen |
| **v.82 Aufkleber-Bestellung** | Bestellseite 4,90 € / 2er-Set 7,90 € ohne Online-Zahlung (Rechnung + Überweisung oder PayPal-Link), Bestellliste für dich | Stand 13 | 1 Sitzung, **erst nach Gewerbe/Impressum** |
| **v.83 Fitting im Pass** | Zustimmung, Fitting-Werte in den Pass, Übernahme aufs neue Rad | – | 1 Sitzung |
| **v.84 Verified Used Bikes** | Anzeige in der Händlersuche, Vertrauenssiegel aus Pass-Daten, Kontakt per Anfrage | Stand 14 | 1–2 Sitzungen |
| später | Käuferschutz, Affiliate, Hersteller | – | – |

## 7. Tests und Akzeptanzkriterien (je Schritt, automatisch)
- **Datenbank:**
  - Ein bestätigter Eintrag lässt sich weder ändern noch löschen, auch nicht vom eigenen Laden. Erlaubt ist nur ein Korrektur-Eintrag.
  - Ein fremder, nicht geprüfter Betrieb kann nicht „bestätigt“ eintragen.
- **Besitzerwechsel:**
  - Ohne Übergabe-Code nicht möglich.
  - Nach dem Wechsel ist der alte Code ungültig.
  - Der Käufer sieht keinen Namen des Vorbesitzers.
- **Käuferansicht:**
  - Ohne Meldung erscheint nie „nicht gestohlen“.
  - Kundendaten tauchen nicht auf (heute schon getestet).
- **Etikett:** Ein QR-Code mit 18 mm Breite lässt sich mit der iPhone-Kamera scannen. Das ist ein Handtest mit deinem Gerät.
- **Rückwärtskompatibel:** Alle bisherigen Tests laufen weiter, ebenso die Prüfungen (41/41) am iPhone und PC.

## 8. Offene Entscheidungen
1. **Kostenloser Zugang für Nicht-FYF-Werkstätten (nur Pass-Einträge)?**
   - Das widerspricht nicht dem einen Preis von 99 €, weil es kein Cockpit enthält.
   - Es ist aber faktisch eine zweite Stufe.
   - Meine Empfehlung: **Ja.** Es macht den Pass vollständiger und ist der Weg zu zahlenden Läden.
2. **Aufkleber:** Laut deiner Preisliste 4,90 € bzw. 7,90 €; vorher hattest du „kostenlos oder 5 €“ genannt.
   - [Schätzung] Kosten pro Aufkleber: etwa 1 € Porto, 0,20–0,60 € Material und Umschlag, dazu Gebühren des Zahlungswegs.
   - Bei 4,90 € bleiben etwa 3 €.
3. **Gewerbe und Rechtliches vor dem ersten Verkauf:**
   - Gewerbeanmeldung, Impressum, Widerrufsbelehrung, Datenschutzerklärung.
   - Einnahmen beim Jobcenter angeben.
   - AVV (Auftragsverarbeitungsvertrag) mit den Läden.
4. **Domain und Marke:** Für kurze QR-Links.
5. **Etikettiergerät:** Welches Modell und welche Bandbreite?

---

## 9. Umgesetzt in v.80 (Passport-Kern)
- Einträge im Online-Pass sind **unveränderlich**. Die Datenbank sperrt Ändern und Löschen, auch für Admins; Korrektur nur als neuer, sichtbarer Eintrag.
- **Vertrauensstufe pro Eintrag**: „Werkstatt-bestätigt“ (geprüfter Betrieb, unabhängig vom Abo) oder „Werkstatt (Betrieb noch nicht geprüft)“. „Selbstauskunft“ und „Beleg vorhanden“ sind vorbereitet und folgen mit v.81.
- Übergebene Aufträge, Teiletausch, Inspektion, Schaden, Garantiefall und Gebrauchtrad-Check werden **automatisch** einzeln eingetragen, ohne Doppelte. Interne Notizen und Kaufdaten bleiben privat.
- **Fahrradschein Teil I + II**: Teil II trägt den geheimen Übergabe-Code; gespeichert wird nur dessen Hash. Ein neuer Druck macht den alten Code ungültig.
- **Besitzerwechsel**:
  - Mit Teil II in jeder FYF-Werkstatt möglich; die Geschichte bleibt.
  - Käufer sehen nur „2. Besitzer seit …“, nie Namen.
  - Der alte Laden kann danach nicht mehr schreiben.
  - **Gestohlen gemeldete Räder können nicht übergeben werden.**
- **Pass zurückziehen statt löschen**: Der Pass ist dann nicht mehr öffentlich, die Geschichte bleibt gespeichert. Löscht ein Betrieb sein Konto, bleiben seine Einträge in fremden Pässen erhalten.
- **Etikett** als Bild für 24-mm-Band (740 × 256 px ≈ 52 × 18 mm bei 360 dpi), teilbar in die App des Etikettiergeräts.
- **Identität & Diebstahlschutz**: Farbe, Merkmale, Codierung, Akku-Nr., Batteriepass-Link, Kauf. Öffentlich sind nur Farbe, gekürzte Akku-Nr. und Batteriepass-Link.
- **Diebstahl-Paket**: Angaben für die Anzeige drucken oder als PDF sichern, Pass als gestohlen markieren. Hinweis, dass FYF mit keinem Polizei-Register verbunden ist.

## 10. Umgesetzt in v.81
- **Besitzer-Bereich ohne Konto**: Auf der Pass-Seite gibt der Besitzer den Code von Teil II ein. Dann kann er:
  - die Sichtbarkeit wählen,
  - selbst Diebstahl melden oder aufheben,
  - eigene Arbeiten als „Selbstauskunft“ eintragen.
  - Nach 10 falschen Codes pro Tag ist der Bereich für 24 h gesperrt.
- **Einstellung des Besitzers geht vor.** Ein späteres Speichern im Laden mit alten Werten hebt sie nicht auf. Die Werkstatt übernimmt Einstellungen und Selbstauskünfte automatisch in die Fahrradakte.
- **Fitting-Werte im Pass**, nur mit Häkchen „Besitzer ist einverstanden“: Sattelhöhe, Sattelversatz, Reach, Überhöhung, Vorbau, Lenker, Kurbel, Cleat.
- **Gebrauchtrad mit Fahrradpass anbieten**: läuft über die vorhandene Produktliste, es gibt keinen zweiten Marktplatz.
  - In der Händlersuche erscheint eine Liste „Gebrauchträder mit Fahrradpass“ mit Link zum Pass und Anfrage an den Laden.
  - Ohne Bezahlung über FYF.
- **Offen**: Belege und Fotos hochladen („Beleg vorhanden“), Besitzer-Konto mit Übersicht aller eigenen Räder, Käuferschutz.

## 11. Umgesetzt in v.82 – Wachstum über Radfahrer und Läden
- **Diebstahl-Abgleich im Werkstattablauf**:
  - Läuft bei jeder Annahme, bei neuem Rad und bei geänderter Rahmennummer automatisch. Zusätzlich gibt es das Feld „Rahmennummer prüfen“ in der Werkstatt.
  - Verglichen wird nur ein Hash der Rahmennummer; die Nummer verlässt den Laden nicht.
  - Bei einem Treffer erscheint eine Warnung mit Pass-Code und meldendem Laden. Hinweis: Die Meldung stammt aus FYF, nicht von der Polizei.
- **Radfahrer registrieren selbst, kostenlos und ohne Konto**:
  - Sie bekommen sofort Pass-Code und Übergabe-Code (Teil II) und drucken Fahrradschein und Aufkleber selbst.
  - Eine schon registrierte Rahmennummer wird abgelehnt. Das verhindert das Neuanmelden gestohlener Räder.
  - Höchstens 300 Selbstregistrierungen pro Tag.
- **„Service bei einer FYF-Werkstatt buchen“** direkt aus dem Pass: Die Händlersuche öffnet sich mit dem Pass-Code. Die Anfrage enthält den Code, und in der App öffnet ein Knopf den Pass.
- **Werkstatt übernimmt selbst registrierte Pässe** mit Teil II; ungeprüfte Betriebe können in fremde Pässe nicht schreiben.
- **Daten gehören dem Besitzer**: Er kann den Pass als Datei (JSON) sichern oder drucken.
- **Quick-Fit**: Hatte der Kunde schon ein Fitting auf einem anderen Rad, rechnet Quick-Fit die gemessene Position auf das neue Rad um. Dafür nutzt es die vorhandene Funktion „1:1 übertragen“ mit der Geometrie-Bibliothek.
- **Kostenloser Pass-Zugang für Läden**: Pass-Einträge sind ohne Abo möglich (es gibt ohnehin noch keine Abrechnung). Die 99 € gelten für das Cockpit, sobald die Abrechnung kommt.
- **Noch nicht aktiv**: Versand wetterfester Aufkleber (4,90 €). Dafür braucht es vorher Gewerbe, Impressum, Widerrufsbelehrung und einen Zahlungsweg.
