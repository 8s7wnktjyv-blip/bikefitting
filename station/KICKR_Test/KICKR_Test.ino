// KICKR-Test für das Tab5 – prüft nur, ob Bluetooth am Tab5 mit der Rolle funktioniert.
// Sucht Rollen mit dem Standard FTMS (z. B. Wahoo KICKR CORE 2), verbindet sich mit der ersten
// und zeigt Leistung und Trittfrequenz. Steuert die Rolle NICHT (keine Last-Änderung).
// Status: geschrieben, NICHT getestet. Ob das M5Stack-Board-Paket Bluetooth auf dem Tab5 (ESP32-P4 + C6) kann,
// ist unklar. Wenn das Kompilieren mit einem Bluetooth-Fehler scheitert, ist genau das das Testergebnis.
// Vorher: KICKR-App, Zwift usw. schließen (die Rolle nimmt nur eine Steuerverbindung an).

#include <M5Unified.h>
#include <BLEDevice.h>

static BLEUUID FTMS((uint16_t)0x1826), BIKE_DATA((uint16_t)0x2AD2);
static BLEAdvertisedDevice* found = nullptr;
static volatile int power = -1, cadence = -1; static volatile uint32_t lastData = 0;
static String status = "Suche Rolle ...";

// Indoor Bike Data lesen (wie in der FYF-App, ftmsParse)
static void onData(BLERemoteCharacteristic*, uint8_t* b, size_t n, bool) {
  if (n < 2) return;
  uint16_t f = b[0] | (b[1] << 8); size_t i = 2;
  auto u16 = [&](size_t k) { return (int)(b[k] | (b[k + 1] << 8)); };
  if (!(f & 0x01)) i += 2;               // Geschwindigkeit
  if (f & 0x02) i += 2;                  // Ø Geschwindigkeit
  if (f & 0x04) { if (i + 2 <= n) cadence = u16(i) / 2; i += 2; }
  if (f & 0x08) i += 2;                  // Ø Trittfrequenz
  if (f & 0x10) i += 3;                  // Distanz
  if (f & 0x20) i += 2;                  // Widerstand
  if (f & 0x40) { if (i + 2 <= n) power = (int16_t)u16(i); i += 2; }
  lastData = millis();
}
class ScanCB : public BLEAdvertisedDeviceCallbacks {
  void onResult(BLEAdvertisedDevice d) override {
    if (!found && d.haveServiceUUID() && d.isAdvertisingService(FTMS)) { found = new BLEAdvertisedDevice(d); BLEDevice::getScan()->stop(); }
  }
};
static void show() {
  auto& D = M5.Display; D.fillScreen(0xFFFF);
  D.setTextDatum(top_left); D.setTextColor(0x18E3, 0xFFFF);
  D.setFont(&fonts::FreeSansBold24pt7b); D.drawString("KICKR-Test (Bluetooth)", 40, 30);
  D.setFont(&fonts::FreeSans18pt7b); D.drawString(status.c_str(), 40, 110);
  char s[48];
  D.setFont(&fonts::FreeSansBold24pt7b); D.setTextSize(2);
  snprintf(s, sizeof s, "%s W", power >= 0 ? String(power).c_str() : "-"); D.drawString(s, 40, 220);
  snprintf(s, sizeof s, "%s U/min", cadence >= 0 ? String(cadence).c_str() : "-"); D.drawString(s, 40, 400);
  D.setTextSize(1);
}
void setup() {
  auto cfg = M5.config(); M5.begin(cfg); M5.Display.setRotation(1);
  show();
  BLEDevice::init("FYF Station");
  BLEScan* sc = BLEDevice::getScan();
  sc->setAdvertisedDeviceCallbacks(new ScanCB()); sc->setActiveScan(true);
  sc->start(15, false);
  if (!found) { status = "Keine Rolle gefunden. Rolle wach? Andere Apps zu?"; show(); return; }
  status = String("Gefunden: ") + found->getName().c_str() + " - verbinde ..."; show();
  BLEClient* c = BLEDevice::createClient();
  if (!c->connect(found)) { status = "Verbinden fehlgeschlagen."; show(); return; }
  BLERemoteService* svc = c->getService(FTMS);
  BLERemoteCharacteristic* ch = svc ? svc->getCharacteristic(BIKE_DATA) : nullptr;
  if (!ch || !ch->canNotify()) { status = "Rolle liefert keine Leistungsdaten (FTMS)."; show(); return; }
  ch->registerForNotify(onData);
  status = String("Verbunden: ") + found->getName().c_str() + " - jetzt treten"; show();
}
void loop() {
  M5.update();
  static uint32_t t = 0;
  if (millis() - t > 500) { t = millis(); show(); }
  delay(20);
}
