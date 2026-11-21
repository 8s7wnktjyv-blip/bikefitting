# FYF Station v0.4.6 – Einwilligung geht an FYF

Stand: 21.11.2026 · auf dem Tab5 noch **nicht** getestet.

- **Übersicht → „An FYF senden“** schickt jetzt die Einwilligung des aktiven Kunden mit (Häkchen, Datum, Unterschrift als Bild). Meldung: „Gesendet mit Einwilligung“.
- **In FYF** (ab v.126): Fitting → „Werte vom Tab5 holen“ → „Übernehmen“. Dann steht beim Kunden „Einwilligung liegt vor“ mit Unterschrift, und im Protokoll steht „Einwilligung vom Tab5 übernommen“.
- FYF übernimmt nur ein echtes PNG-Bild als Unterschrift und ein Datum im Format TT.MM.JJJJ hh:mm. Alles andere wird verworfen.
- **Speicherdauer** ist jetzt in Tab5 und FYF-App gleich: „längstens 3 Jahre nach dem letzten Termin“.
- Am Rechner geprüft: Die Einwilligung vom Tab5 wird von der FYF-App richtig gelesen, und die Unterschrift kommt als gültiges Bild an.

---

# FYF Station v0.4.5 – Einwilligung und Abschluss

Stand: 21.11.2026
**Status:** Am Rechner mit der echten Grafik-Bibliothek durchgelaufen, ohne Speicherfehler. Die drei QR-Codes habe ich am Rechner ausgelesen, sie führen zu den richtigen Adressen. Auf dem Tab5 noch **nicht** getestet.

## Neu in v0.4.5
| Wo | Was |
|---|---|
| **Kunden → Kunde → „Einwilligung fehlt – erfassen“** | Text zur Datenverarbeitung (wie „Muster 3“ in der FYF-App, gekürzt). Häkchen: Fitting-Daten (nötig), Beschwerden & Körpercheck, Fotos & Videos, anonyme Auswertung, Service-Erinnerung. Der Kunde unterschreibt mit dem Finger, dann „Einwilligen“. Danach zeigt der Knopf das Datum. Dort kann man die Einwilligung ansehen, **widerrufen** (löscht Häkchen und Unterschrift) oder neu erfassen. |
| **Übersicht → „Abschluss“** | Bildschirm für den Kunden: „Danke, Vorname!“ und 3 QR-Codes: **Google-Bewertung** (dein Profil FYF Fit your Frame, Uttenreuth), **FYF Fahrradpass** (rad.html), **WhatsApp** an +49 1575 1806152 mit vorausgefülltem Text. |
| **Abschluss → „Links“** | WhatsApp-Nummer und Google Place-ID ändern (für andere Läden). |
| **SD-Sicherung** | Einwilligungen samt Unterschrift werden mitgesichert und mit zurückgeholt. |

Gespeichert wird auf dem Tab5 unter `/e/<Kundennummer>.txt` (Häkchen, Datum, Fassung) und `/e/<Kundennummer>.png` (Unterschrift). Beim Löschen eines Kunden wird beides mit gelöscht.

**Bitte selbst prüfen (kein Rechtsrat):**
- „spätestens 3 Jahre nach dem letzten Termin“ ist mein Vorschlag. In der FYF-App steht dort noch „[Frist eintragen]“. Beides sollte gleich sein.
- Die Einwilligung bleibt vorerst auf dem Tab5 und der SD-Karte. Sie wird noch **nicht** an FYF gesendet.

---

# FYF Station v0.4.4 – Wetterstation und SD-Karte

Stand: 21.11.2026
**Status:** Am Rechner mit der echten Grafik-Bibliothek (M5GFX) und Testdaten durchgelaufen, ohne Speicherfehler. Auf dem Tab5 noch **nicht** getestet. Ob die Verbindung zu Bright Sky und zur BKG-Karte klappt, zeigt erst das Gerät.

## Neu in v0.4.4 (Seite „Mehr“)
| Kachel | Was sie kann |
|---|---|
| **Wetter** | Links: Regenradar als Film (ca. 75 Min. zurück, 2 Std. Vorhersage, alle 5 Min.), Karte ±40 km um Uttenreuth, Zeitleiste mit Play/Pause, Wischen zum Vor- und Zurückspulen, Knopf „neu laden“. Rechts: Uhr, Temperatur, Wind mit Richtungspfeil und Böen, Feuchte und Taupunkt, Sonnenauf- und -untergang, Heute (alle 2 Std.), 3 Tage. Bewegte Symbole. DWD-Warnungen als farbiger Balken, Antippen zeigt den Text. Kein Bildschirmschoner auf dieser Seite. |
| **SD-Karte** | Jetzt sichern, tägliche Auto-Sicherung, Zurückholen (zweimal tippen), Radar-Karte laden. |

**Daten:** Deutscher Wetterdienst über api.brightsky.dev (kostenlos, ohne Schlüssel). Aktualisierung: Wetter alle 10 Min., Warnungen alle 5 Min., Vorhersage stündlich, Radar alle 5 Min. (nur solange die Wetter-Seite offen ist).
**Karte:** BKG TopPlusOpen (grau, auf dem Tab5 blau eingefärbt). Sie wird einmal geladen, sobald SD-Karte und WLAN da sind, und liegt dann als `/FYF/karte.png` auf der Karte. Quellenvermerk steht unten rechts auf der Karte: „© BKG (Jahr) dl-de/by-2-0“, Datenquellen: https://sgx.geodatenzentrum.de/web_public/gdz/datenquellen/datenquellen_topplusopen.html
Ohne SD-Karte zeigt das Radar eine Ersatzkarte mit Orten (Lage ungefähr).

**Sicherung auf der SD-Karte:** `/FYF/Sicherung/JJJJ-MM-TT_HHMM/` mit allen Kunden samt Fittings (`k/`), dem laufenden Fitting, Ablauf, Beobachtungen, Checkliste und Einstellungen (`aktuell.txt`). **Nicht** gesichert: WLAN-Passwort und FYF-Kopplung. Die 10 neuesten Sicherungen bleiben, ältere werden gelöscht. Vor jedem Zurückholen sichert das Tab5 den aktuellen Stand (Name mit „(vorher)“).

**SD-Karte:** FAT32, Kontakte zeigen beim Einstecken in dieselbe Richtung wie der Bildschirm. Bei SD-Karten über 32 GB formatiert der Mac oft als exFAT – dann erkennt das Tab5 sie nicht. Im Festplattendienstprogramm „MS-DOS (FAT)“ wählen.

## Hochladen (iMac)
1. ZIP doppelt anklicken.
2. Arduino IDE: *Datei → Öffnen → FYF-Station-v0.4.4 → FYF_Station → FYF_Station.ino*. In Zeile 1 steht **v0.4.4**.
3. Board **M5Tab5**, Port „usbmodem“, „Erase All Flash“ = **Disabled** (sonst sind die Kunden weg).
4. Pfeil ➡️ klicken.
5. Danach am Tab5: Mehr → **SD-Karte** → **Jetzt sichern**. Dann Mehr → **Wetter**.

## Wenn es beim Wetter hakt
- **„keine sichere Verbindung (WLAN/Zertifikat)“:** Foto schicken. Dann passt die Zertifikats-Prüfung für Bright Sky oder BKG nicht und ich ergänze das Zertifikat.
- **„Karte: Antwort ist kein Bild“:** Foto schicken. Dann hat der BKG-Dienst den Kartennamen geändert.
- **Radar liegt sichtbar neben Orten oder Grenzen:** Foto vom Tab5 schicken. Die Umrechnung des DWD-Rasters auf die Karte ist am Rechner geprüft, aber nicht mit echten Daten.
- **SD-Karte „nicht erkannt“:** Format prüfen (FAT32), Karte richtig herum einstecken, „pruefen“ tippen.

---

# FYF Station v0.3 – Anleitung

Stand: 20.11.2026
**Status:** v0.2 lief auf deinem Tab5. v0.3 ist geschrieben, aber noch nicht auf dem Tab5 getestet. Am Rechner getestet sind die Rechenteile (47 + 66 Prüfungen), der FYF-Import (14 Prüfungen) und die Datenbank-Regeln (lokal mit Postgres).

## Neu in v0.3

Der Startbildschirm hat jetzt oben 2 Seiten: **Fitting** und **Mehr**.

| Seite | Kachel | Was sie kann |
|---|---|---|
| Fitting | **Kunden** (neu) | Kunden anlegen: Name, Größe, Schrittlänge, Rad. Einen Kunden als **aktiv** wählen. Die letzten Fittings stehen beim Kunden. **Folgefitting**: Nimmt die letzten Nachher-Werte als neue Vorher-Werte. |
| Fitting | **Rechner** (neu) | **Sattel & Kurbel:** Sattelhöhe nach LeMond und Hamley, Kurbellänge nach Faustregel. **Vorbau:** zeigt, wie viele mm der Lenker vor/zurück und hoch/runter wandert, wenn Länge, Winkel oder Spacer geändert werden. Alles sind Richtwerte. |
| Fitting | **Übersicht** | Neue Knöpfe: **An FYF senden** und **Beim Kunden speichern**. |
| Mehr | **Stoppuhr** (neu) | Start/Stopp, bis 8 Runden. |
| Mehr | **Checkliste** (neu) | 12 Punkte zur Vorbereitung (Rad, Rolle, Werkzeug, Einwilligung …). |
| Mehr | **FYF & WLAN** (neu) | WLAN einrichten. Danach stellt sich die Uhr selbst. Mit FYF koppeln, Kunden aus FYF laden, Fitting an FYF senden. |
| Mehr | **Einstellungen** | Neu: **Bildschirmschoner**. Nach 2, 5 oder 10 Minuten ohne Berührung erscheint die Uhr groß. Antippen bringt dich zurück. Standard: 5 Minuten. Während Fahrprogramm oder Stoppuhr laufen, kommt kein Bildschirmschoner. |

Alle Funktionen aus v0.2 bleiben gleich. Deine Werte bleiben beim Update erhalten.

## 1. Hochladen (iMac)
1. ZIP entpacken. Wichtig: Im Ordner `FYF_Station` müssen **4 Dateien** liegen: `FYF_Station.ino`, `fyf_math.h`, `fyf_calc.h`, `fyf_roots.h`.
2. Arduino IDE: *Datei → Öffnen* → `FYF_Station/FYF_Station.ino`. Oben müssen 4 Reiter zu sehen sein.
3. In Zeile 1 muss **v0.3** stehen.
4. Board **M5Tab5** und den Port mit „usbmodem“ wählen, wie beim letzten Mal.
5. **Partition Scheme** prüfen: *Werkzeuge → Partition Scheme* muss „Default (… SPIFFS)“ sein. Das ist schon so eingestellt. Dort speichert das Tab5 die Kunden.
6. Klick auf den **Pfeil-Knopf ➡️**. Nicht auf den Käfer.
7. **„Erase All Flash“ muss auf „Disabled“ stehen.** Sonst werden deine Werte gelöscht.

## 2. WLAN einrichten (am Tab5)
1. Mehr → **FYF & WLAN** → **WLAN wählen**.
2. Dein Netz antippen, das Passwort tippen und **OK** drücken.
3. Grün „Verbunden“ = fertig. Die Uhrzeit wird jetzt automatisch aus dem Internet gestellt.

Das Passwort bleibt nur auf dem Tab5 gespeichert.

## 3. Mit FYF koppeln (iPhone + Tab5)
Das geht nur, wenn die FYF-App mit der **Cloud-Speicherung** angemeldet ist.

**Vorher einmal in Supabase einrichten, am iMac:** Diese Schritte ändern deine Datenbank. Mach sie erst, wenn du einverstanden bist.
- Supabase → *Authentication → Sign In / Providers* → **„Allow anonymous sign-ins“** einschalten. Falls die Geräte-Kopplung schon läuft, ist das bereits an.
- Supabase → *SQL Editor* → den Inhalt von `docs/supabase/station.sql` aus dem Repo bikefitting einfügen → **Run**. Ohne diesen Schritt kann das Tab5 koppeln, aber keine Kunden laden und keine Werte senden. Das Tab5 zeigt dann einen Hinweis.

**Koppeln:**
1. In der FYF-App auf dem iPhone: **Mehr → Cloud-Speicherung → „Weiteres Gerät verbinden“**. Ein Code mit 8 Zeichen erscheint und gilt 10 Minuten.
2. Am Tab5: FYF & WLAN → **Mit FYF koppeln** → den Code tippen → **OK**.
3. Danach steht das Tab5 in FYF unter Team als „Gerät: FYF Station Tab5“.

## 4. Benutzen
- **Kunden aus FYF laden:** Das Tab5 bekommt nur Name, Größe und Schrittlänge. Keine E-Mail und keine Telefonnummer.
- **Fitting senden:** Übersicht → **An FYF senden**.
- **In FYF übernehmen:** Kunde → Fitting → Reiter **Messen** oder **Anpassen** → **„Werte vom Tab5 holen“** → **Übernehmen**. Gehören die Werte zu einem anderen Kunden, warnt FYF in Rot. Die Beobachtungen landen in den Notizen des Fittings.
- **Ohne Internet:** Kunden und Fittings bleiben auf dem Tab5 („Beim Kunden speichern“). Der QR-Code funktioniert weiterhin.

## 5. KICKR-Test (Bluetooth, optional)
Der Ordner `KICKR_Test` enthält ein eigenes kleines Testprogramm. Es prüft nur eins: Kann das Tab5 die Rolle per Bluetooth lesen?
1. KICKR-App, Zwift und MyWhoosh schließen.
2. `KICKR_Test/KICKR_Test.ino` öffnen und hochladen. Board und Einstellungen bleiben wie oben.
3. Treten. Erscheinen Watt und Trittfrequenz, klappt Bluetooth. Dann baue ich die Rollensteuerung in die FYF Station ein.
4. Danach wieder `FYF_Station.ino` hochladen. Deine Daten bleiben dabei erhalten.

**Wenn schon das Kompilieren mit einem Bluetooth-Fehler scheitert, ist das auch ein Ergebnis.** Dann unterstützt das Board-Paket Bluetooth auf dem Tab5 noch nicht. Schick mir ein Foto davon.

## Wenn es hakt
- **Fehler beim Kompilieren:** Foto vom roten Text schicken.
- **„keine sichere Verbindung (WLAN oder Zertifikat)“:** Ein Foto vom Bildschirm schicken. Dann fehlt vermutlich ein Stammzertifikat in `fyf_roots.h`. Das ergänze ich.
- **„Anonyme Anmeldung ist in Supabase aus“:** Siehe Schritt 3, „Vorher einmal einrichten“.
- **„FYF-Datenbank kennt die Station noch nicht“:** `station.sql` ist noch nicht eingespielt.
- **WLAN-Suche findet nichts oder es kommen Fehler:** Das WLAN-Modul im Tab5 (ESP32-C6) braucht seine Werks-Firmware. Wenn ein anderes Programm sie überschrieben hat, muss sie neu aufgespielt werden. M5Stack erklärt das unter „Tab5 ESP32-C6 Wi-Fi Module Restore Factory Firmware“.
- **Gerät verloren:** In FYF unter Team das Gerät entfernen. Danach kommt es nicht mehr an deine Daten.

## Was noch fehlt
- **Kamera am Tab5:** noch nicht eingebaut. In Arduino gibt es für die Tab5-Kamera noch keine geprüfte Lösung. Zuerst müssen WLAN und Bluetooth laufen.
- **Rollensteuerung vom Tab5 aus:** Sie kommt erst, wenn der KICKR-Test klappt.
- **Umlaute auf dem Tab5:** Bisher steht dort ae/oe/ue.

## Technik
- `fyf_math.h`: Winkel, Ziffernblock, Datum. Test: `g++ -std=c++17 test_math.cpp -o t && ./t`
- `fyf_calc.h`: Rechner, Texteingabe, JSON, Kunden-Dateien und Daten für FYF. Test: `g++ -std=c++17 test_calc.cpp -o tc && ./tc`
- `fyf_roots.h`: Öffentliche Stammzertifikate (Google Trust Services, Let's Encrypt, SSL.com) für die sichere Verbindung zu Supabase.
- Die Supabase-Adresse und der öffentliche Schlüssel stehen in der Firmware. Beides steht auch so in der FYF-Web-App und ist kein Geheimnis. Den Zugriff schützen die Kopplung und die Datenbank-Regeln.
- Speicher auf dem Gerät: Einstellungen, WLAN und Kopplung liegen im NVS. Die Kunden liegen als Dateien unter `/k/` im internen Speicher (LittleFS), höchstens 99 Kunden.
