// FYF Station v0.4.6 – Bedienoberfläche für das M5Stack Tab5
// Seite „Fitting“: Ablauf · Kunden · Messwerte · Winkelmesser · Wasserwaage · Fahrprogramm · Beobachtungen · Übersicht · Rechner
// Seite „Mehr“:    Wetter · Stoppuhr · Checkliste · FYF & WLAN · Nachschlagen · Rad-Sprung · Uhr & Kalender · SD-Karte · Einstellungen
//                  (+ Bildschirmschoner mit Uhr)
// v0.4.4: Wetterstation (DWD über Bright Sky: Wetter, Radar-Film, Warnungen; Karte BKG TopPlusOpen auf SD-Karte)
//         und SD-Karte (Sicherung von Kunden, Fittings und Einstellungen, Zurückholen, tägliche Auto-Sicherung).
// v0.4.5: Einwilligung mit Unterschrift am Bildschirm (Kunden > Kunde > Einwilligung) und
//         Abschluss für den Kunden mit QR-Codes: Google-Bewertung, FYF Fahrradpass, WhatsApp (Übersicht > Abschluss).
// v0.4.6: "An FYF senden" schickt die Einwilligung mit Unterschrift mit (FYF-App ab v.126 übernimmt sie beim Kunden).
// Daten bleiben nach dem Ausschalten gespeichert (Einstellungen im NVS, Kunden als Dateien im internen Speicher).
// Status: v0.2 lief auf dem Tab5. v0.3 ist geschrieben, Rechenteile am Rechner getestet, auf dem Tab5 noch NICHT getestet.
// Benötigt (Arduino IDE): Board-Paket „M5Stack“ (Board: M5Tab5), Bibliothek „M5Unified“ (bringt M5GFX mit).
// Hinweis: Die eingebauten Schriften kennen keine Umlaute – auf dem Gerät steht ae/oe/ue.

#include <M5Unified.h>
#include <Preferences.h>
#include <WiFi.h>
#include <LittleFS.h>
#include <time.h>
#include <ctype.h>
#include "esp_http_client.h"
#include <SPI.h>
#include <SD.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/semphr.h"
// Zertifikats-Sammlung von ESP-IDF für Wetter und Karte (Bright Sky, BKG). Fehlt sie, gelten die FYF-Stammzertifikate.
#if __has_include("esp_crt_bundle.h")
#include "esp_crt_bundle.h"
#define WX_BUNDLE 1
#else
#define WX_BUNDLE 0
#endif
// Rollensteuerung (Wahoo KICKR & Co. per Bluetooth): erst auf 1 stellen, wenn der KICKR-Test auf dem Tab5 geklappt hat.
#ifndef FYF_KICKR
#define FYF_KICKR 0
#endif
#if FYF_KICKR
#include <BLEDevice.h>
#endif
// ---- Inhalt von fyf_math.h (eingebaut, damit nur eine Datei nötig ist) ----
// FYF Station – reine Rechenfunktionen (ohne Arduino), am Rechner testbar.
#include <math.h>

namespace fyf {

// Neigung entlang der langen Seite des Tab5 (Gerät flach aufgelegt), in Grad.
// Positiv = rechte Seite höher. Nutzt die Schwerkraft-Anteile des Beschleunigungssensors.
inline float tiltLongDeg(float ax, float ay, float az) {
  return atan2f(ax, sqrtf(ay * ay + az * az)) * 180.0f / (float)M_PI;
}
// Neigung entlang der kurzen Seite, in Grad.
inline float tiltShortDeg(float ax, float ay, float az) {
  return atan2f(ay, sqrtf(ax * ax + az * az)) * 180.0f / (float)M_PI;
}
// Gerät hochkant an eine Fläche gehalten (Bildschirm senkrecht): Winkel der Unterkante zur Waagerechten.
inline float tiltUprightDeg(float ax, float ay) {
  return atan2f(ax, ay) * 180.0f / (float)M_PI;
}
// Glättung (Tiefpass). k zwischen 0 (keine Änderung) und 1 (keine Glättung).
inline float smooth(float prev, float now, float k) { return prev + (now - prev) * k; }
// Auf eine Nachkommastelle runden.
inline float round1(float v) { return roundf(v * 10.0f) / 10.0f; }
// Ruhig? (Schwankung der letzten Werte kleiner als Grenze)
inline bool steady(float minV, float maxV, float limit) { return (maxV - minV) <= limit; }
// Mittelwert eines Arrays
inline float mean(const float* v, int n) { if (n <= 0) return 0; float s = 0; for (int i = 0; i < n; i++) s += v[i]; return s / n; }

// Eingabe eines Zahlen-Ziffernblocks: Taste an Text anhängen, mit Regeln.
// buf: Text (max cap-1 Zeichen). key: '0'-'9', ',' oder '<' (löschen). Gibt true zurück, wenn geändert.
inline bool keypadInput(char* buf, int cap, char key) {
  int len = 0; while (buf[len]) len++;
  if (key == '<') { if (len == 0) return false; buf[len - 1] = 0; return true; }
  if (key == ',') {
    for (int i = 0; i < len; i++) if (buf[i] == ',') return false; // nur ein Komma
    if (len == 0 || len >= cap - 2) return false;
    buf[len] = ','; buf[len + 1] = 0; return true;
  }
  if (key >= '0' && key <= '9') {
    int dec = -1; for (int i = 0; i < len; i++) if (buf[i] == ',') dec = i;
    if (dec >= 0 && len - dec > 1) return false;          // höchstens 1 Nachkommastelle
    if (dec < 0 && len >= 4) return false;                // höchstens 4 Stellen vor dem Komma
    if (len == 1 && buf[0] == '0' && key == '0') return false;
    if (len == 1 && buf[0] == '0') { buf[0] = key; return true; }
    if (len >= cap - 1) return false;
    buf[len] = key; buf[len + 1] = 0; return true;
  }
  return false;
}
// Text mit Dezimalkomma in Zahl umwandeln. Leer → NAN.
inline float parseComma(const char* s) {
  if (!s || !*s) return NAN;
  float v = 0, f = 0.1f; bool d = false;
  for (const char* p = s; *p; p++) {
    if (*p == ',') { d = true; continue; }
    if (*p < '0' || *p > '9') return NAN;
    if (!d) v = v * 10 + (*p - '0'); else { v += (*p - '0') * f; f *= 0.1f; }
  }
  return v;
}

// ---------- Datum (ohne Bibliothek, am Rechner testbar) ----------
inline bool isLeap(int y) { return (y % 4 == 0 && y % 100 != 0) || y % 400 == 0; }
inline int daysInMonth(int y, int m) {
  static const int d[12] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
  if (m < 1 || m > 12) return 30;
  return m == 2 && isLeap(y) ? 29 : d[m - 1];
}
// Wochentag: 0 = Montag … 6 = Sonntag
inline int weekdayMon0(int y, int m, int d) {
  static const int t[12] = {0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4};
  if (m < 3) y -= 1;
  int w = (y + y / 4 - y / 100 + y / 400 + t[m - 1] + d) % 7;  // 0 = Sonntag
  return (w + 6) % 7;
}
// Tage seit 1970-01-01 und zurück (Verfahren nach H. Hinnant)
inline long daysFromCivil(int y, int m, int d) {
  y -= m <= 2; long era = (y >= 0 ? y : y - 399) / 400; long yoe = y - era * 400;
  long doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1; long doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
  return era * 146097 + doe - 719468;
}
inline void civilFromDays(long z, int& y, int& m, int& d) {
  z += 719468; long era = (z >= 0 ? z : z - 146096) / 146097; long doe = z - era * 146097;
  long yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365; long yy = yoe + era * 400;
  long doy = doe - (365 * yoe + yoe / 4 - yoe / 100); long mp = (5 * doy + 2) / 153;
  d = (int)(doy - (153 * mp + 2) / 5 + 1); m = (int)(mp < 10 ? mp + 3 : mp - 9); y = (int)(yy + (m <= 2));
}
struct DT { int y, mo, d, h, mi, s, wd; };  // wd: 0 = Montag
inline long long toEpoch(int y, int mo, int d, int h, int mi, int s) {
  return (long long)daysFromCivil(y, mo, d) * 86400LL + h * 3600LL + mi * 60LL + s;
}
inline DT fromEpoch(long long e) {
  DT t; long days = (long)(e >= 0 ? e / 86400 : (e - 86399) / 86400); long sec = (long)(e - (long long)days * 86400);
  civilFromDays(days, t.y, t.mo, t.d); t.h = sec / 3600; t.mi = (sec / 60) % 60; t.s = sec % 60; t.wd = weekdayMon0(t.y, t.mo, t.d);
  return t;
}
// Zeigerwinkel in Grad (0 = 12 Uhr, im Uhrzeigersinn)
inline float handHour(int h, int mi) { return ((h % 12) + mi / 60.0f) * 30.0f; }
inline float handMin(int mi, int s) { return (mi + s / 60.0f) * 6.0f; }
inline float handSec(int s) { return s * 6.0f; }
// Römische Zahl 1–12 (für das Zifferblatt)
inline const char* roman12(int h) {
  static const char* r[13] = {"", "I", "II", "III", "IIII", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"};
  return (h >= 1 && h <= 12) ? r[h] : "";
}
// Differenz nachher − vorher, NAN wenn einer fehlt
inline float diffOrNan(float before, float after) { return (isnan(before) || isnan(after)) ? NAN : round1(after - before); }

}  // namespace fyf
// ---- Ende fyf_math.h ----
// ---- Inhalt von fyf_calc.h (eingebaut, damit nur eine Datei nötig ist) ----
// FYF Station – Rechner, Text- und Datenfunktionen (ohne Arduino), am Rechner testbar.
#include <math.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

namespace fyf {

// ---------- Fitting-Rechner (Richtwerte, kein Ersatz für das Fitting) ----------
// Sattelhöhe Mitte Tretlager bis Satteloberfläche, nach LeMond: 0,883 × Schrittlänge.
inline float saddleLemond(float inseamCm) { return inseamCm > 0 ? roundf(inseamCm * 10.0f * 0.883f) : NAN; }
// Nach Hamley/Thomas: 1,09 × Schrittlänge gilt bis zur Pedalachse; minus Kurbellänge = ab Tretlagermitte.
inline float saddleHamley(float inseamCm, float crankMm) {
  return (inseamCm > 0 && crankMm > 0) ? roundf(inseamCm * 10.0f * 1.09f - crankMm) : NAN;
}
// Übliche Kurbellängen in mm
static const float CRANKS[] = {160, 162.5f, 165, 167.5f, 170, 172.5f, 175};
static const int NCRANK = 7;
inline float nearestCrank(float mm) {
  float best = CRANKS[0];
  for (int i = 1; i < NCRANK; i++) if (fabsf(CRANKS[i] - mm) < fabsf(best - mm) - 1e-4f) best = CRANKS[i];
  return best;
}
// Faustregel Kurbellänge: etwa 20 bis 21,6 % der Schrittlänge, gerundet auf übliche Größen.
inline void crankRange(float inseamCm, float& lo, float& hi) {
  if (!(inseamCm > 0)) { lo = hi = NAN; return; }
  lo = nearestCrank(inseamCm * 10.0f * 0.200f); hi = nearestCrank(inseamCm * 10.0f * 0.216f);
}

// Vorbau-Rechner: Lage der Lenkerklemmung relativ zur Oberkante Steuerrohr.
// hta = Lenkwinkel in Grad (z. B. 73), stemLen in mm, stemAngle in Grad (−6 = abfallend),
// spacer in mm unter dem Vorbau, stemStack = Klemmhöhe des Vorbaus (meist 40 mm).
// x = nach vorn, y = nach oben (mm).
inline void stemPos(float hta, float stemLen, float stemAngle, float spacer, float stemStack, float& x, float& y) {
  float H = hta * (float)M_PI / 180.0f, a = stemAngle * (float)M_PI / 180.0f;
  float s = spacer + stemStack / 2.0f;
  x = -s * cosf(H) + stemLen * sinf(H - a);
  y = s * sinf(H) + stemLen * cosf(H - a);
}
// Unterschied neu − alt (dx = Lenker weiter vorn, dy = Lenker höher)
inline void stemDelta(float hta, float l0, float a0, float s0, float l1, float a1, float s1, float stack, float& dx, float& dy) {
  float x0, y0, x1, y1; stemPos(hta, l0, a0, s0, stack, x0, y0); stemPos(hta, l1, a1, s1, stack, x1, y1);
  dx = x1 - x0; dy = y1 - y0;
}

// ---------- Zeit ----------
// Stoppuhr-Anzeige: m:ss,z (unter 1 h) oder h:mm:ss
inline void fmtStopwatch(unsigned long ms, char* out, int cap) {
  unsigned long t = ms / 100, z = t % 10, s = (t / 10) % 60, m = (t / 600) % 60, h = t / 36000;
  if (h) snprintf(out, cap, "%lu:%02lu:%02lu", h, m, s); else snprintf(out, cap, "%02lu:%02lu,%lu", m, s, z);
}

// ---------- Texteingabe (Bildschirmtastatur) ----------
// key: druckbares Zeichen, '\b' = löschen. Keine führenden/doppelten Leerzeichen. Gibt true zurück, wenn geändert.
inline bool textInput(char* buf, int cap, char key) {
  int len = (int)strlen(buf);
  if (key == '\b') { if (!len) return false; buf[len - 1] = 0; return true; }
  if ((unsigned char)key < 32 || (unsigned char)key > 126) return false;
  if (key == ' ' && (len == 0 || buf[len - 1] == ' ')) return false;
  if (len >= cap - 1) return false;
  buf[len] = key; buf[len + 1] = 0; return true;
}
// Umlaute für die Geräteschrift ersetzen (UTF-8 → ae/oe/ue/ss). Ergebnis nur ASCII.
inline void asciiFold(const char* in, char* out, int cap) {
  int o = 0;
  for (const unsigned char* p = (const unsigned char*)in; *p && o < cap - 1; p++) {
    const char* rep = nullptr;
    if (*p == 0xC3 && p[1]) {
      switch (p[1]) {
        case 0xA4: rep = "ae"; break; case 0xB6: rep = "oe"; break; case 0xBC: rep = "ue"; break;
        case 0x84: rep = "Ae"; break; case 0x96: rep = "Oe"; break; case 0x9C: rep = "Ue"; break;
        case 0x9F: rep = "ss"; break; case 0xA9: case 0xA8: rep = "e"; break; case 0xA1: case 0xA0: rep = "a"; break;
        default: rep = "?"; break;
      }
      p++;
    } else if (*p >= 0x80) { while (p[1] && (p[1] & 0xC0) == 0x80) p++; rep = "?"; }
    if (rep) { for (; *rep && o < cap - 1; rep++) out[o++] = *rep; }
    else out[o++] = (char)*p;
  }
  out[o] = 0;
}

// ---------- JSON (klein, ohne Bibliothek) ----------
// Text für JSON maskieren. Gibt Länge zurück (ohne Anführungszeichen).
inline int jsonEsc(const char* in, char* out, int cap) {
  int o = 0;
  for (const unsigned char* p = (const unsigned char*)in; *p; p++) {
    char tmp[8]; const char* add;
    if (*p == '"') add = "\\\""; else if (*p == '\\') add = "\\\\"; else if (*p == '\n') add = "\\n";
    else if (*p == '\r') add = "\\r"; else if (*p == '\t') add = "\\t";
    else if (*p < 32) { snprintf(tmp, sizeof tmp, "\\u%04x", *p); add = tmp; }
    else { tmp[0] = (char)*p; tmp[1] = 0; add = tmp; }
    int n = (int)strlen(add); if (o + n >= cap) break;
    memcpy(out + o, add, n); o += n;
  }
  out[o] = 0; return o;
}
// Zahl für JSON: null bei NAN, sonst mit höchstens 1 Nachkommastelle
inline void jsonNum(float v, char* out, int cap) {
  if (isnan(v) || isinf(v)) { snprintf(out, cap, "null"); return; }
  float r = roundf(v * 10.0f) / 10.0f;
  if (fabsf(r - roundf(r)) < 1e-4f) snprintf(out, cap, "%ld", (long)roundf(r)); else snprintf(out, cap, "%.1f", r);
}
// Wert zu "key" ab Position from suchen. Liefert Zeiger hinter den Wert oder nullptr.
// Strings werden entmaskiert (\uXXXX → UTF-8 für Zeichen < 0x800). Zahlen/true/false/null als Text.
inline const char* jsonGet(const char* from, const char* key, char* out, int cap) {
  if (!from) return nullptr;
  char pat[72]; snprintf(pat, sizeof pat, "\"%s\"", key);
  const char* p = from;
  while ((p = strstr(p, pat))) {
    const char* q = p + strlen(pat);
    while (*q == ' ' || *q == '\n' || *q == '\r' || *q == '\t') q++;
    if (*q != ':') { p = q; continue; }
    q++; while (*q == ' ' || *q == '\n' || *q == '\r' || *q == '\t') q++;
    int o = 0;
    if (*q == '"') {
      q++;
      while (*q && *q != '"') {
        unsigned c = (unsigned char)*q;
        if (c == '\\' && q[1]) {
          q++;
          switch (*q) {
            case 'n': c = '\n'; break; case 't': c = '\t'; break; case 'r': c = '\r'; break;
            case 'b': c = '\b'; break; case 'f': c = '\f'; break;
            case 'u': { char h[5] = {0}; for (int i = 0; i < 4 && q[1]; i++) h[i] = *++q; c = (unsigned)strtoul(h, nullptr, 16); break; }
            default: c = (unsigned char)*q;
          }
          if (c >= 0x80 && c < 0x800) { if (o + 2 < cap) { out[o++] = (char)(0xC0 | (c >> 6)); out[o++] = (char)(0x80 | (c & 0x3F)); } q++; continue; }
          if (c >= 0x800) { if (o < cap - 1) out[o++] = '?'; q++; continue; }
        }
        if (o < cap - 1) out[o++] = (char)c;
        q++;
      }
      out[o] = 0; return *q ? q + 1 : q;
    }
    while (*q && *q != ',' && *q != '}' && *q != ']' && *q != ' ' && *q != '\n') { if (o < cap - 1) out[o++] = *q; q++; }
    out[o] = 0; return q;
  }
  return nullptr;
}

// ---------- Kunden-Datei (einfaches Zeilenformat, eine Datei je Kunde) ----------
// Zeile 1:  K|Name|Größe cm|Schrittlänge cm|Fahrrad|FYF-Kunden-ID
// weitere:  F|Datum|v0;v1;…;v11|v0;…;v11   (vorher | nachher, leer = kein Wert)
static const int CF = 12;  // Anzahl Messfelder
struct Customer { char name[40]; float height, inseam; char bike[40]; char fyfId[40]; };
inline void cleanField(const char* in, char* out, int cap) {
  int o = 0; for (const char* p = in; *p && o < cap - 1; p++) out[o++] = (*p == '|' || *p == '\n' || *p == '\r' || *p == ';') ? '/' : *p;
  out[o] = 0;
}
inline void numField(float v, char* out, int cap) { if (isnan(v)) out[0] = 0; else { jsonNum(v, out, cap); } }
inline int custHeader(const Customer& c, char* out, int cap) {
  char n[40], b[40], f[40], h[12], s[12];
  cleanField(c.name, n, sizeof n); cleanField(c.bike, b, sizeof b); cleanField(c.fyfId, f, sizeof f);
  numField(c.height, h, sizeof h); numField(c.inseam, s, sizeof s);
  return snprintf(out, cap, "K|%s|%s|%s|%s|%s\n", n, h, s, b, f);
}
// Teilt s an sep; schreibt Feld idx nach out. Gibt false zurück, wenn es das Feld nicht gibt.
inline bool splitField(const char* s, char sep, int idx, char* out, int cap) {
  int i = 0; const char* p = s;
  while (i < idx) { p = strchr(p, sep); if (!p) { out[0] = 0; return false; } p++; i++; }
  int o = 0; while (*p && *p != sep && *p != '\n' && *p != '\r' && o < cap - 1) out[o++] = *p++;
  out[o] = 0; return true;
}
inline float parseNum(const char* s) {
  if (!s || !*s) return NAN;
  char* e; float v = strtof(s, &e); return e == s ? NAN : v;
}
inline bool custParse(const char* line, Customer& c) {
  char f[48];
  if (line[0] != 'K' || line[1] != '|') return false;
  splitField(line, '|', 1, c.name, sizeof c.name);
  splitField(line, '|', 2, f, sizeof f); c.height = parseNum(f);
  splitField(line, '|', 3, f, sizeof f); c.inseam = parseNum(f);
  splitField(line, '|', 4, c.bike, sizeof c.bike);
  splitField(line, '|', 5, c.fyfId, sizeof c.fyfId);
  return c.name[0] != 0;
}
inline int fitLine(const char* date, const float* before, const float* after, char* out, int cap) {
  int o = snprintf(out, cap, "F|%s|", date);
  for (int s = 0; s < 2; s++) {
    const float* v = s ? after : before;
    for (int i = 0; i < CF; i++) {
      char n[16]; numField(v[i], n, sizeof n);
      o += snprintf(out + o, cap > o ? cap - o : 0, "%s%s", n, i < CF - 1 ? ";" : (s ? "\n" : "|"));
    }
  }
  return o;
}
inline bool fitParse(const char* line, char* date, int dcap, float* before, float* after) {
  if (line[0] != 'F' || line[1] != '|') return false;
  splitField(line, '|', 1, date, dcap);
  char part[256], f[16];
  for (int s = 0; s < 2; s++) {
    if (!splitField(line, '|', 2 + s, part, sizeof part)) return false;
    float* v = s ? after : before;
    for (int i = 0; i < CF; i++) { splitField(part, ';', i, f, sizeof f); v[i] = parseNum(f); }
  }
  return true;
}



// ---------- Rolle (FTMS, z. B. Wahoo KICKR CORE 2) ----------
// Indoor Bike Data (0x2AD2) lesen. Gibt false zurück, wenn zu kurz. Werte −1 = nicht enthalten.
inline bool ftmsParse(const unsigned char* b, int n, int& power, int& cadence) {
  power = -1; cadence = -1; if (n < 2) return false;
  int f = b[0] | (b[1] << 8), i = 2;
  if (!(f & 0x01)) i += 2;                                              // Geschwindigkeit
  if (f & 0x02) i += 2;                                                 // Ø Geschwindigkeit
  if (f & 0x04) { if (i + 2 <= n) cadence = (b[i] | (b[i + 1] << 8)) / 2; i += 2; }
  if (f & 0x08) i += 2;                                                 // Ø Trittfrequenz
  if (f & 0x10) i += 3;                                                 // Distanz
  if (f & 0x20) i += 2;                                                 // Widerstand
  if (f & 0x40) { if (i + 2 <= n) power = (short)(b[i] | (b[i + 1] << 8)); i += 2; }
  return true;
}
// Steuerbefehl „Zielleistung“ (Control Point 0x2AD9): 0x05 + Watt (int16, little endian). Begrenzt auf 0..maxW.
inline int ftmsTargetCmd(int watt, int maxW, unsigned char* out) {
  if (watt < 0) watt = 0; if (watt > maxW) watt = maxW;
  out[0] = 0x05; out[1] = (unsigned char)(watt & 0xFF); out[2] = (unsigned char)((watt >> 8) & 0xFF); return 3;
}
// Mittelwert und Schwankung (Standardabweichung)
struct Stat { double n = 0, s = 0, ss = 0; void add(double v) { n++; s += v; ss += v * v; } void clear() { n = s = ss = 0; }
  float mean() const { return n ? (float)(s / n) : NAN; }
  float sd() const { if (n < 2) return NAN; double m = s / n, v = ss / n - m * m; return (float)sqrt(v > 0 ? v : 0); } };
struct RideRes { char label[28]; float w, cad, sdW, sdCad; int target; };

// ---------- Daten für FYF (Tab5 → FYF-App) ----------
// Reihenfolge wie die Messfelder auf dem Tab5; Namen wie in der FYF-App (MK-Schlüssel).
static const char* const FYF_KEYS[CF] = {"saddleHeight", "saddleSetback", "saddleFloor", "barFloor", "drop", "reach",
                                         "barX", "hoodFloor", "crankLength", "saddleTilt", "barRoll", "kneeBDC"};
// Baut das JSON, das die Station an FYF schickt. Nur vorhandene Werte. Gibt Länge zurück, −1 wenn zu klein.
inline int payloadJson(char* out, int cap, const char* ver, const char* when, const char* custName, const char* fyfId,
                       const float* before, const float* after, const char* const* obs, int nObs, int measDone,
                       const RideRes* rr = nullptr, int nRR = 0) {
  int o = 0; char e[128], num[16];
  #define PJ(...) do { int k = snprintf(out + o, cap > o ? cap - o : 0, __VA_ARGS__); if (k < 0 || o + k >= cap) return -1; o += k; } while (0)
  jsonEsc(ver, e, sizeof e); PJ("{\"v\":1,\"src\":\"tab5\",\"ver\":\"%s\",", e);
  jsonEsc(when, e, sizeof e); PJ("\"when\":\"%s\",\"customer\":{\"name\":", e);
  if (custName && *custName) { jsonEsc(custName, e, sizeof e); PJ("\"%s\"", e); } else PJ("null");
  PJ(",\"fyf_id\":");
  if (fyfId && *fyfId) { jsonEsc(fyfId, e, sizeof e); PJ("\"%s\"", e); } else PJ("null");
  PJ("}");
  for (int s = 0; s < 2; s++) {
    const float* v = s ? after : before; bool first = true;
    PJ(",\"%s\":{", s ? "after" : "before");
    for (int i = 0; i < CF; i++) { if (isnan(v[i])) continue; jsonNum(v[i], num, sizeof num); PJ("%s\"%s\":%s", first ? "" : ",", FYF_KEYS[i], num); first = false; }
    PJ("}");
  }
  PJ(",\"obs\":[");
  for (int i = 0; i < nObs; i++) { jsonEsc(obs[i], e, sizeof e); PJ("%s\"%s\"", i ? "," : "", e); }
  PJ("],\"ride_measurements\":%d,\"ride\":[", measDone);
  for (int i = 0; i < nRR; i++) {
    char a[16], b[16], c[16], d2[16]; jsonEsc(rr[i].label, e, sizeof e);
    jsonNum(rr[i].w, a, sizeof a); jsonNum(rr[i].cad, b, sizeof b); jsonNum(rr[i].sdW, c, sizeof c); jsonNum(rr[i].sdCad, d2, sizeof d2);
    PJ("%s{\"label\":\"%s\",\"target\":%d,\"w\":%s,\"cad\":%s,\"sd_w\":%s,\"sd_cad\":%s}", i ? "," : "", e, rr[i].target, a, b, c, d2);
  }
  PJ("]}");
  #undef PJ
  return o;
}

}  // namespace fyf
// ---- Ende fyf_calc.h ----
// ---- Inhalt von fyf_roots.h (eingebaut, damit nur eine Datei nötig ist) ----
// Stammzertifikate (öffentlich, Mozilla-Liste) für die sichere Verbindung zu Supabase/Cloudflare.
// Supabase-Adressen nutzen Zertifikate von Google Trust Services, Let's Encrypt oder SSL.com.
// Kein Geheimnis. Wenn eine Verbindung mit „Zertifikat“ scheitert, hier die passende Wurzel ergänzen.
static const char FYF_ROOTS[] =
  // GTS_Root_R1
  "-----BEGIN CERTIFICATE-----\n"
  "MIIFVzCCAz+gAwIBAgINAgPlk28xsBNJiGuiFzANBgkqhkiG9w0BAQwFADBHMQsw\n"
  "CQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2VzIExMQzEU\n"
  "MBIGA1UEAxMLR1RTIFJvb3QgUjEwHhcNMTYwNjIyMDAwMDAwWhcNMzYwNjIyMDAw\n"
  "MDAwWjBHMQswCQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZp\n"
  "Y2VzIExMQzEUMBIGA1UEAxMLR1RTIFJvb3QgUjEwggIiMA0GCSqGSIb3DQEBAQUA\n"
  "A4ICDwAwggIKAoICAQC2EQKLHuOhd5s73L+UPreVp0A8of2C+X0yBoJx9vaMf/vo\n"
  "27xqLpeXo4xL+Sv2sfnOhB2x+cWX3u+58qPpvBKJXqeqUqv4IyfLpLGcY9vXmX7w\n"
  "Cl7raKb0xlpHDU0QM+NOsROjyBhsS+z8CZDfnWQpJSMHobTSPS5g4M/SCYe7zUjw\n"
  "TcLCeoiKu7rPWRnWr4+wB7CeMfGCwcDfLqZtbBkOtdh+JhpFAz2weaSUKK0Pfybl\n"
  "qAj+lug8aJRT7oM6iCsVlgmy4HqMLnXWnOunVmSPlk9orj2XwoSPwLxAwAtcvfaH\n"
  "szVsrBhQf4TgTM2S0yDpM7xSma8ytSmzJSq0SPly4cpk9+aCEI3oncKKiPo4Zor8\n"
  "Y/kB+Xj9e1x3+naH+uzfsQ55lVe0vSbv1gHR6xYKu44LtcXFilWr06zqkUspzBmk\n"
  "MiVOKvFlRNACzqrOSbTqn3yDsEB750Orp2yjj32JgfpMpf/VjsPOS+C12LOORc92\n"
  "wO1AK/1TD7Cn1TsNsYqiA94xrcx36m97PtbfkSIS5r762DL8EGMUUXLeXdYWk70p\n"
  "aDPvOmbsB4om3xPXV2V4J95eSRQAogB/mqghtqmxlbCluQ0WEdrHbEg8QOB+DVrN\n"
  "VjzRlwW5y0vtOUucxD/SVRNuJLDWcfr0wbrM7Rv1/oFB2ACYPTrIrnqYNxgFlQID\n"
  "AQABo0IwQDAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4E\n"
  "FgQU5K8rJnEaK0gnhS9SZizv8IkTcT4wDQYJKoZIhvcNAQEMBQADggIBAJ+qQibb\n"
  "C5u+/x6Wki4+omVKapi6Ist9wTrYggoGxval3sBOh2Z5ofmmWJyq+bXmYOfg6LEe\n"
  "QkEzCzc9zolwFcq1JKjPa7XSQCGYzyI0zzvFIoTgxQ6KfF2I5DUkzps+GlQebtuy\n"
  "h6f88/qBVRRiClmpIgUxPoLW7ttXNLwzldMXG+gnoot7TiYaelpkttGsN/H9oPM4\n"
  "7HLwEXWdyzRSjeZ2axfG34arJ45JK3VmgRAhpuo+9K4l/3wV3s6MJT/KYnAK9y8J\n"
  "ZgfIPxz88NtFMN9iiMG1D53Dn0reWVlHxYciNuaCp+0KueIHoI17eko8cdLiA6Ef\n"
  "MgfdG+RCzgwARWGAtQsgWSl4vflVy2PFPEz0tv/bal8xa5meLMFrUKTX5hgUvYU/\n"
  "Z6tGn6D/Qqc6f1zLXbBwHSs09dR2CQzreExZBfMzQsNhFRAbd03OIozUhfJFfbdT\n"
  "6u9AWpQKXCBfTkBdYiJ23//OYb2MI3jSNwLgjt7RETeJ9r/tSQdirpLsQBqvFAnZ\n"
  "0E6yove+7u7Y/9waLd64NnHi/Hm3lCXRSHNboTXns5lndcEZOitHTtNCjv0xyBZm\n"
  "2tIMPNuzjsmhDYAPexZ3FL//2wmUspO8IFgV6dtxQ/PeEMMA3KgqlbbC1j+Qa3bb\n"
  "bP6MvPJwNQzcmRk13NfIRmPVNnGuV/u3gm3c\n"
  "-----END CERTIFICATE-----\n"
  // GTS_Root_R3
  "-----BEGIN CERTIFICATE-----\n"
  "MIICCTCCAY6gAwIBAgINAgPluILrIPglJ209ZjAKBggqhkjOPQQDAzBHMQswCQYD\n"
  "VQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2VzIExMQzEUMBIG\n"
  "A1UEAxMLR1RTIFJvb3QgUjMwHhcNMTYwNjIyMDAwMDAwWhcNMzYwNjIyMDAwMDAw\n"
  "WjBHMQswCQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2Vz\n"
  "IExMQzEUMBIGA1UEAxMLR1RTIFJvb3QgUjMwdjAQBgcqhkjOPQIBBgUrgQQAIgNi\n"
  "AAQfTzOHMymKoYTey8chWEGJ6ladK0uFxh1MJ7x/JlFyb+Kf1qPKzEUURout736G\n"
  "jOyxfi//qXGdGIRFBEFVbivqJn+7kAHjSxm65FSWRQmx1WyRRK2EE46ajA2ADDL2\n"
  "4CejQjBAMA4GA1UdDwEB/wQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQW\n"
  "BBTB8Sa6oC2uhYHP0/EqEr24Cmf9vDAKBggqhkjOPQQDAwNpADBmAjEA9uEglRR7\n"
  "VKOQFhG/hMjqb2sXnh5GmCCbn9MN2azTL818+FsuVbu/3ZL3pAzcMeGiAjEA/Jdm\n"
  "ZuVDFhOD3cffL74UOO0BzrEXGhF16b0DjyZ+hOXJYKaV11RZt+cRLInUue4X\n"
  "-----END CERTIFICATE-----\n"
  // GTS_Root_R4
  "-----BEGIN CERTIFICATE-----\n"
  "MIICCTCCAY6gAwIBAgINAgPlwGjvYxqccpBQUjAKBggqhkjOPQQDAzBHMQswCQYD\n"
  "VQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2VzIExMQzEUMBIG\n"
  "A1UEAxMLR1RTIFJvb3QgUjQwHhcNMTYwNjIyMDAwMDAwWhcNMzYwNjIyMDAwMDAw\n"
  "WjBHMQswCQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2Vz\n"
  "IExMQzEUMBIGA1UEAxMLR1RTIFJvb3QgUjQwdjAQBgcqhkjOPQIBBgUrgQQAIgNi\n"
  "AATzdHOnaItgrkO4NcWBMHtLSZ37wWHO5t5GvWvVYRg1rkDdc/eJkTBa6zzuhXyi\n"
  "QHY7qca4R9gq55KRanPpsXI5nymfopjTX15YhmUPoYRlBtHci8nHc8iMai/lxKvR\n"
  "HYqjQjBAMA4GA1UdDwEB/wQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQW\n"
  "BBSATNbrdP9JNqPV2Py1PsVq8JQdjDAKBggqhkjOPQQDAwNpADBmAjEA6ED/g94D\n"
  "9J+uHXqnLrmvT/aDHQ4thQEd0dlq7A/Cr8deVl5c1RxYIigL9zC2L7F8AjEA8GE8\n"
  "p/SgguMh1YQdc4acLa/KNJvxn7kjNuK8YAOdgLOaVsjh4rsUecrNIdSUtUlD\n"
  "-----END CERTIFICATE-----\n"
// fehlt: GlobalSign_Root_CA
  // ISRG_Root_X1
  "-----BEGIN CERTIFICATE-----\n"
  "MIIFazCCA1OgAwIBAgIRAIIQz7DSQONZRGPgu2OCiwAwDQYJKoZIhvcNAQELBQAw\n"
  "TzELMAkGA1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2Vh\n"
  "cmNoIEdyb3VwMRUwEwYDVQQDEwxJU1JHIFJvb3QgWDEwHhcNMTUwNjA0MTEwNDM4\n"
  "WhcNMzUwNjA0MTEwNDM4WjBPMQswCQYDVQQGEwJVUzEpMCcGA1UEChMgSW50ZXJu\n"
  "ZXQgU2VjdXJpdHkgUmVzZWFyY2ggR3JvdXAxFTATBgNVBAMTDElTUkcgUm9vdCBY\n"
  "MTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAK3oJHP0FDfzm54rVygc\n"
  "h77ct984kIxuPOZXoHj3dcKi/vVqbvYATyjb3miGbESTtrFj/RQSa78f0uoxmyF+\n"
  "0TM8ukj13Xnfs7j/EvEhmkvBioZxaUpmZmyPfjxwv60pIgbz5MDmgK7iS4+3mX6U\n"
  "A5/TR5d8mUgjU+g4rk8Kb4Mu0UlXjIB0ttov0DiNewNwIRt18jA8+o+u3dpjq+sW\n"
  "T8KOEUt+zwvo/7V3LvSye0rgTBIlDHCNAymg4VMk7BPZ7hm/ELNKjD+Jo2FR3qyH\n"
  "B5T0Y3HsLuJvW5iB4YlcNHlsdu87kGJ55tukmi8mxdAQ4Q7e2RCOFvu396j3x+UC\n"
  "B5iPNgiV5+I3lg02dZ77DnKxHZu8A/lJBdiB3QW0KtZB6awBdpUKD9jf1b0SHzUv\n"
  "KBds0pjBqAlkd25HN7rOrFleaJ1/ctaJxQZBKT5ZPt0m9STJEadao0xAH0ahmbWn\n"
  "OlFuhjuefXKnEgV4We0+UXgVCwOPjdAvBbI+e0ocS3MFEvzG6uBQE3xDk3SzynTn\n"
  "jh8BCNAw1FtxNrQHusEwMFxIt4I7mKZ9YIqioymCzLq9gwQbooMDQaHWBfEbwrbw\n"
  "qHyGO0aoSCqI3Haadr8faqU9GY/rOPNk3sgrDQoo//fb4hVC1CLQJ13hef4Y53CI\n"
  "rU7m2Ys6xt0nUW7/vGT1M0NPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNV\n"
  "HRMBAf8EBTADAQH/MB0GA1UdDgQWBBR5tFnme7bl5AFzgAiIyBpY9umbbjANBgkq\n"
  "hkiG9w0BAQsFAAOCAgEAVR9YqbyyqFDQDLHYGmkgJykIrGF1XIpu+ILlaS/V9lZL\n"
  "ubhzEFnTIZd+50xx+7LSYK05qAvqFyFWhfFQDlnrzuBZ6brJFe+GnY+EgPbk6ZGQ\n"
  "3BebYhtF8GaV0nxvwuo77x/Py9auJ/GpsMiu/X1+mvoiBOv/2X/qkSsisRcOj/KK\n"
  "NFtY2PwByVS5uCbMiogziUwthDyC3+6WVwW6LLv3xLfHTjuCvjHIInNzktHCgKQ5\n"
  "ORAzI4JMPJ+GslWYHb4phowim57iaztXOoJwTdwJx4nLCgdNbOhdjsnvzqvHu7Ur\n"
  "TkXWStAmzOVyyghqpZXjFaH3pO3JLF+l+/+sKAIuvtd7u+Nxe5AW0wdeRlN8NwdC\n"
  "jNPElpzVmbUq4JUagEiuTDkHzsxHpFKVK7q4+63SM1N95R1NbdWhscdCb+ZAJzVc\n"
  "oyi3B43njTOQ5yOf+1CceWxG1bQVs5ZufpsMljq4Ui0/1lvh+wjChP4kqKOJ2qxq\n"
  "4RgqsahDYVvTH9w7jXbyLeiNdd8XM2w9U/t7y0Ff/9yi0GE44Za4rF2LN9d11TPA\n"
  "mRGunUHBcnWEvgJBQl9nJEiU0Zsnvgc/ubhPgXRR4Xq37Z0j4r7g1SgEEzwxA57d\n"
  "emyPxgcYxn/eR44/KJ4EBs+lVDR3veyJm+kXQ99b21/+jh5Xos1AnX5iItreGCc=\n"
  "-----END CERTIFICATE-----\n"
  // ISRG_Root_X2
  "-----BEGIN CERTIFICATE-----\n"
  "MIICGzCCAaGgAwIBAgIQQdKd0XLq7qeAwSxs6S+HUjAKBggqhkjOPQQDAzBPMQsw\n"
  "CQYDVQQGEwJVUzEpMCcGA1UEChMgSW50ZXJuZXQgU2VjdXJpdHkgUmVzZWFyY2gg\n"
  "R3JvdXAxFTATBgNVBAMTDElTUkcgUm9vdCBYMjAeFw0yMDA5MDQwMDAwMDBaFw00\n"
  "MDA5MTcxNjAwMDBaME8xCzAJBgNVBAYTAlVTMSkwJwYDVQQKEyBJbnRlcm5ldCBT\n"
  "ZWN1cml0eSBSZXNlYXJjaCBHcm91cDEVMBMGA1UEAxMMSVNSRyBSb290IFgyMHYw\n"
  "EAYHKoZIzj0CAQYFK4EEACIDYgAEzZvVn4CDCuwJSvMWSj5cz3es3mcFDR0HttwW\n"
  "+1qLFNvicWDEukWVEYmO6gbf9yoWHKS5xcUy4APgHoIYOIvXRdgKam7mAHf7AlF9\n"
  "ItgKbppbd9/w+kHsOdx1ymgHDB/qo0IwQDAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0T\n"
  "AQH/BAUwAwEB/zAdBgNVHQ4EFgQUfEKWrt5LSDv6kviejM9ti6lyN5UwCgYIKoZI\n"
  "zj0EAwMDaAAwZQIwe3lORlCEwkSHRhtFcP9Ymd70/aTSVaYgLXTWNLxBo1BfASdW\n"
  "tL4ndQavEi51mI38AjEAi/V3bNTIZargCyzuFJ0nN6T5U6VR5CmD1/iQMVtCnwr1\n"
  "/q4AaOeMSQ+2b1tbFfLn\n"
  "-----END CERTIFICATE-----\n"
  // SSL.com_Root_Certification_Authority_RSA
  "-----BEGIN CERTIFICATE-----\n"
  "MIIF3TCCA8WgAwIBAgIIeyyb0xaAMpkwDQYJKoZIhvcNAQELBQAwfDELMAkGA1UE\n"
  "BhMCVVMxDjAMBgNVBAgMBVRleGFzMRAwDgYDVQQHDAdIb3VzdG9uMRgwFgYDVQQK\n"
  "DA9TU0wgQ29ycG9yYXRpb24xMTAvBgNVBAMMKFNTTC5jb20gUm9vdCBDZXJ0aWZp\n"
  "Y2F0aW9uIEF1dGhvcml0eSBSU0EwHhcNMTYwMjEyMTczOTM5WhcNNDEwMjEyMTcz\n"
  "OTM5WjB8MQswCQYDVQQGEwJVUzEOMAwGA1UECAwFVGV4YXMxEDAOBgNVBAcMB0hv\n"
  "dXN0b24xGDAWBgNVBAoMD1NTTCBDb3Jwb3JhdGlvbjExMC8GA1UEAwwoU1NMLmNv\n"
  "bSBSb290IENlcnRpZmljYXRpb24gQXV0aG9yaXR5IFJTQTCCAiIwDQYJKoZIhvcN\n"
  "AQEBBQADggIPADCCAgoCggIBAPkP3aMrfcvQKv7sZ4Wm5y4bunfh4/WvpOz6Sl2R\n"
  "xFdHaxh3a3by/ZPkPQ/CFp4LZsNWlJ4Xg4XOVu/yFv0AYvUiCVToZRdOQbngT0aX\n"
  "qhvIuG5iXmmxX9sqAn78bMrzQdjt0Oj8P2FI7bADFB0QDksZ4LtO7IZl/zbzXmcC\n"
  "C52GVWH9ejjt/uIZALdvoVBidXQ8oPrIJZK0bnoix/geoeOy3ZExqysdBP+lSgQ3\n"
  "6YWkMyv94tZVNHwZpEpox7Ko07fKoZOI68GXvIz5HdkihCR0xwQ9aqkpk8zruFvh\n"
  "/l8lqjRYyMEjVJ0bmBHDOJx+PYZspQ9AhnwC9FwCTyjLrnGfDzrIM/4RJTXq/LrF\n"
  "YD3ZfBjVsqnTdXgDciLKOsMf7yzlLqn6niy2UUb9rwPW6mBo6oUWNmuF6R7As93E\n"
  "JNyAKoFBbZQ+yODJgUEAnl6/f8UImKIYLEJAs/lvOCdLToD0PYFH4Ih86hzOtXVc\n"
  "US4cK38acijnALXRdMbX5J+tB5O2UzU1/Dfkw/ZdFr4hc96SCvigY2q8lpJqPvi8\n"
  "ZVWb3vUNiSYE/CUapiVpy8JtynziWV+XrOvvLsi81xtZPCvM8hnIk2snYxnP/Okm\n"
  "+Mpxm3+T/jRnhE6Z6/yzeAkzcLpmpnbtG3PrGqUNxCITIJRWCk4sbE6x/c+cCbqi\n"
  "M+2HAgMBAAGjYzBhMB0GA1UdDgQWBBTdBAkHovV6fVJTEpKV7jiAJQ2mWTAPBgNV\n"
  "HRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFN0ECQei9Xp9UlMSkpXuOIAlDaZZMA4G\n"
  "A1UdDwEB/wQEAwIBhjANBgkqhkiG9w0BAQsFAAOCAgEAIBgRlCn7Jp0cHh5wYfGV\n"
  "cpNxJK1ok1iOMq8bs3AD/CUrdIWQPXhq9LmLpZc7tRiRux6n+UBbkflVma8eEdBc\n"
  "Hadm47GUBwwyOabqG7B52B2ccETjit3E+ZUfijhDPwGFpUenPUayvOUiaPd7nNgs\n"
  "PgohyC0zrL/FgZkxdMF1ccW+sfAjRfSda/wZY52jvATGGAslu1OJD7OAUN5F7kR/\n"
  "q5R4ZJjT9ijdh9hwZXT7DrkT66cPYakylszeu+1jTBi7qUD3oFRuIIhxdRjqerQ0\n"
  "cuAjJ3dctpDqhiVAq+8zD8ufgr6iIPv2tS0a5sKFsXQP+8hlAqRSAUfdSSLBv9jr\n"
  "a6x+3uxjMxW3IwiPxg+NQVrdjsW5j+VFP3jbutIbQLH+cU0/4IGiul607BXgk90I\n"
  "H37hVZkLId6Tngr75qNJvTYw/ud3sqB1l7UtgYgXZSD32pAAn8lSzDLKNXz1PQ/Y\n"
  "K9f1JmzJBjSWFupwWRoyeXkLtoh/D1JIPb9s2KJELtFOt3JY04kTlf5Eq/jXixtu\n"
  "nLwsoFvVagCvXzfh1foQC5ichucmj87w7G6KVwuA406ywKBjYZC6VWg3dGq2ktuf\n"
  "oYYitmUnDuy2n0Jg5GfCtdpBC8TTi2EbvPofkSvXRAdeuims2cXp71NIWuuA8ShY\n"
  "Ic2wBlX7Jz9TkHCpBB5XJ7k=\n"
  "-----END CERTIFICATE-----\n"
  // SSL.com_Root_Certification_Authority_ECC
  "-----BEGIN CERTIFICATE-----\n"
  "MIICjTCCAhSgAwIBAgIIdebfy8FoW6gwCgYIKoZIzj0EAwIwfDELMAkGA1UEBhMC\n"
  "VVMxDjAMBgNVBAgMBVRleGFzMRAwDgYDVQQHDAdIb3VzdG9uMRgwFgYDVQQKDA9T\n"
  "U0wgQ29ycG9yYXRpb24xMTAvBgNVBAMMKFNTTC5jb20gUm9vdCBDZXJ0aWZpY2F0\n"
  "aW9uIEF1dGhvcml0eSBFQ0MwHhcNMTYwMjEyMTgxNDAzWhcNNDEwMjEyMTgxNDAz\n"
  "WjB8MQswCQYDVQQGEwJVUzEOMAwGA1UECAwFVGV4YXMxEDAOBgNVBAcMB0hvdXN0\n"
  "b24xGDAWBgNVBAoMD1NTTCBDb3Jwb3JhdGlvbjExMC8GA1UEAwwoU1NMLmNvbSBS\n"
  "b290IENlcnRpZmljYXRpb24gQXV0aG9yaXR5IEVDQzB2MBAGByqGSM49AgEGBSuB\n"
  "BAAiA2IABEVuqVDEpiM2nl8ojRfLliJkP9x6jh3MCLOicSS6jkm5BBtHllirLZXI\n"
  "7Z4INcgn64mMU1jrYor+8FsPazFSY0E7ic3s7LaNGdM0B9y7xgZ/wkWV7Mt/qCPg\n"
  "CemB+vNH06NjMGEwHQYDVR0OBBYEFILRhXMw5zUE044CkvvlpNHEIejNMA8GA1Ud\n"
  "EwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAUgtGFczDnNQTTjgKS++Wk0cQh6M0wDgYD\n"
  "VR0PAQH/BAQDAgGGMAoGCCqGSM49BAMCA2cAMGQCMG/n61kRpGDPYbCWe+0F+S8T\n"
  "kdzt5fxQaxFGRrMcIQBiu77D5+jNB5n5DQtdcj7EqgIwH7y6C+IwJPt8bYBVCpk+\n"
  "gA0z5Wajs6O7pdWLjwkspl1+4vAHCGht0nxpbl/f5Wpl\n"
  "-----END CERTIFICATE-----\n"
  // SSL.com_TLS_RSA_Root_CA_2022
  "-----BEGIN CERTIFICATE-----\n"
  "MIIFiTCCA3GgAwIBAgIQb77arXO9CEDii02+1PdbkTANBgkqhkiG9w0BAQsFADBO\n"
  "MQswCQYDVQQGEwJVUzEYMBYGA1UECgwPU1NMIENvcnBvcmF0aW9uMSUwIwYDVQQD\n"
  "DBxTU0wuY29tIFRMUyBSU0EgUm9vdCBDQSAyMDIyMB4XDTIyMDgyNTE2MzQyMloX\n"
  "DTQ2MDgxOTE2MzQyMVowTjELMAkGA1UEBhMCVVMxGDAWBgNVBAoMD1NTTCBDb3Jw\n"
  "b3JhdGlvbjElMCMGA1UEAwwcU1NMLmNvbSBUTFMgUlNBIFJvb3QgQ0EgMjAyMjCC\n"
  "AiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBANCkCXJPQIgSYT41I57u9nTP\n"
  "L3tYPc48DRAokC+X94xI2KDYJbFMsBFMF3NQ0CJKY7uB0ylu1bUJPiYYf7ISf5OY\n"
  "t6/wNr/y7hienDtSxUcZXXTzZGbVXcdotL8bHAajvI9AI7YexoS9UcQbOcGV0ins\n"
  "S657Lb85/bRi3pZ7QcacoOAGcvvwB5cJOYF0r/c0WRFXCsJbwST0MXMwgsadugL3\n"
  "PnxEX4MN8/HdIGkWCVDi1FW24IBydm5MR7d1VVm0U3TZlMZBrViKMWYPHqIbKUBO\n"
  "L9975hYsLfy/7PO0+r4Y9ptJ1O4Fbtk085zx7AGL0SDGD6C1vBdOSHtRwvzpXGk3\n"
  "R2azaPgVKPC506QVzFpPulJwoxJF3ca6TvvC0PeoUidtbnm1jPx7jMEWTO6Af77w\n"
  "dr5BUxIzrlo4QqvXDz5BjXYHMtWrifZOZ9mxQnUjbvPNQrL8VfVThxc7wDNY8VLS\n"
  "+YCk8OjwO4s4zKTGkH8PnP2L0aPP2oOnaclQNtVcBdIKQXTbYxE3waWglksejBYS\n"
  "d66UNHsef8JmAOSqg+qKkK3ONkRN0VHpvB/zagX9wHQfJRlAUW7qglFA35u5CCoG\n"
  "AtUjHBPW6dvbxrB6y3snm/vg1UYk7RBLY0ulBY+6uB0rpvqR4pJSvezrZ5dtmi2f\n"
  "gTIFZzL7SAg/2SW4BCUvAgMBAAGjYzBhMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0j\n"
  "BBgwFoAU+y437uOEeicuzRk1sTN8/9REQrkwHQYDVR0OBBYEFPsuN+7jhHonLs0Z\n"
  "NbEzfP/UREK5MA4GA1UdDwEB/wQEAwIBhjANBgkqhkiG9w0BAQsFAAOCAgEAjYlt\n"
  "hEUY8U+zoO9opMAdrDC8Z2awms22qyIZZtM7QbUQnRC6cm4pJCAcAZli05bg4vsM\n"
  "QtfhWsSWTVTNj8pDU/0quOr4ZcoBwq1gaAafORpR2eCNJvkLTqVTJXojpBzOCBvf\n"
  "R4iyrT7gJ4eLSYwfqUdYe5byiB0YrrPRpgqU+tvT5TgKa3kSM/tKWTcWQA673vWJ\n"
  "DPFs0/dRa1419dvAJuoSc06pkZCmF8NsLzjUo3KUQyxi4U5cMj29TH0ZR6LDSeeW\n"
  "P4+a0zvkEdiLA9z2tmBVGKaBUfPhqBVq6+AL8BQx1rmMRTqoENjwuSfr98t67wVy\n"
  "lrXEj5ZzxOhWc5y8aVFjvO9nHEMaX3cZHxj4HCUp+UmZKbaSPaKDN7EgkaibMOlq\n"
  "bLQjk2UEqxHzDh1TJElTHaE/nUiSEeJ9DU/1172iWD54nR4fK/4huxoTtrEoZP2w\n"
  "AgDHbICivRZQIA9ygV/MlP+7mea6kMvq+cYMwq7FGc4zoWtcu358NFcXrfA/rs3q\n"
  "r5nsLFR+jM4uElZI7xc7P0peYNLcdDa8pUNjyw9bowJWCZ4kLOGGgYz+qxcs+sji\n"
  "Mho6/4UIyYOf8kpIEFR3N+2ivEC+5BB09+Rbu7nzifmPQdjH5FCQNYA+HLhNkNPU\n"
  "98OwoX6EyneSMSy4kLGCenROmxMmtNVQZlR4rmA=\n"
  "-----END CERTIFICATE-----\n"
  // SSL.com_TLS_ECC_Root_CA_2022
  "-----BEGIN CERTIFICATE-----\n"
  "MIICOjCCAcCgAwIBAgIQFAP1q/s3ixdAW+JDsqXRxDAKBggqhkjOPQQDAzBOMQsw\n"
  "CQYDVQQGEwJVUzEYMBYGA1UECgwPU1NMIENvcnBvcmF0aW9uMSUwIwYDVQQDDBxT\n"
  "U0wuY29tIFRMUyBFQ0MgUm9vdCBDQSAyMDIyMB4XDTIyMDgyNTE2MzM0OFoXDTQ2\n"
  "MDgxOTE2MzM0N1owTjELMAkGA1UEBhMCVVMxGDAWBgNVBAoMD1NTTCBDb3Jwb3Jh\n"
  "dGlvbjElMCMGA1UEAwwcU1NMLmNvbSBUTFMgRUNDIFJvb3QgQ0EgMjAyMjB2MBAG\n"
  "ByqGSM49AgEGBSuBBAAiA2IABEUpNXP6wrgjzhR9qLFNoFs27iosU8NgCTWyJGYm\n"
  "acCzldZdkkAZDsalE3D07xJRKF3nzL35PIXBz5SQySvOkkJYWWf9lCcQZIxPBLFN\n"
  "SeR7T5v15wj4A4j3p8OSSxlUgaNjMGEwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSME\n"
  "GDAWgBSJjy+j6CugFFR781a4Jl9nOAuc0DAdBgNVHQ4EFgQUiY8vo+groBRUe/NW\n"
  "uCZfZzgLnNAwDgYDVR0PAQH/BAQDAgGGMAoGCCqGSM49BAMDA2gAMGUCMFXjIlbp\n"
  "15IkWE8elDIPDAI2wv2sdDJO4fscgIijzPvX6yv/N33w7deedWo1dlJF4AIxAMeN\n"
  "b0Igj762TVntd00pxCAgRWSGOlDGxK0tk/UYfXLtqc/ErFc2KAhl3zx5Zn6g6g==\n"
  "-----END CERTIFICATE-----\n"
;
// ---- Ende fyf_roots.h ----
// ---- Inhalt von fyf_wx.h (eingebaut, damit nur eine Datei nötig ist) ----
// FYF Station – Wetter: reine Rechenfunktionen (ohne Arduino), am Rechner testbar.
#include <math.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>

namespace fyf {

// Wetter-Symbole wie bei Bright Sky (DWD)
enum WxIcon { WX_NONE = -1, WX_CLEAR_D = 0, WX_CLEAR_N, WX_PART_D, WX_PART_N, WX_CLOUDY, WX_FOG, WX_WIND, WX_RAIN, WX_SLEET, WX_SNOW, WX_HAIL, WX_THUNDER, WX_N };
inline int wxIconCode(const char* s) {
  static const char* names[WX_N] = {"clear-day", "clear-night", "partly-cloudy-day", "partly-cloudy-night", "cloudy", "fog", "wind",
                                    "rain", "sleet", "snow", "hail", "thunderstorm"};
  if (!s) return WX_NONE;
  for (int i = 0; i < WX_N; i++) if (!strcmp(s, names[i])) return i;
  return WX_NONE;
}
inline const char* wxText(int code) {
  static const char* t[WX_N] = {"Sonnig", "Klar", "Teils bewoelkt", "Teils bewoelkt", "Bewoelkt", "Nebel", "Windig",
                                "Regen", "Schneeregen", "Schnee", "Hagel", "Gewitter"};
  return (code >= 0 && code < WX_N) ? t[code] : "-";
}
inline int wxDayVariant(int code) { return code == WX_CLEAR_N ? WX_CLEAR_D : code == WX_PART_N ? WX_PART_D : code; }
inline int wxSeverity(int code) {
  static const int s[WX_N] = {0, 0, 1, 1, 2, 3, 2, 5, 6, 7, 8, 9};
  return (code >= 0 && code < WX_N) ? s[code] : -1;
}

// Uhrzeit-Text "2026-11-21T14:05:00+01:00" → lokale Felder. Rückgabe false bei Fehler.
inline bool parseIso(const char* s, int& y, int& mo, int& d, int& h, int& mi) {
  if (!s || strlen(s) < 16) return false;
  y = atoi(s); mo = atoi(s + 5); d = atoi(s + 8); h = atoi(s + 11); mi = atoi(s + 14);
  return s[4] == '-' && s[7] == '-' && s[10] == 'T' && y >= 2000 && mo >= 1 && mo <= 12 && d >= 1 && d <= 31 && h >= 0 && h < 24 && mi >= 0 && mi < 60;
}

// Sommerzeit in der EU (tagesgenau): letzter Sonntag im März bis letzter Sonntag im Oktober
inline int lastSunday(int y, int mo) { int dim = daysInMonth(y, mo); int wd = weekdayMon0(y, mo, dim); return dim - ((wd + 1) % 7); }
inline bool isDstEU(int y, int mo, int d) {
  if (mo > 3 && mo < 10) return true;
  if (mo == 3) return d >= lastSunday(y, 3);
  if (mo == 10) return d < lastSunday(y, 10);
  return false;
}
// Sonnenauf- und -untergang (NOAA-Näherung, ca. ±2 Minuten) in Minuten nach Mitternacht, Ortszeit.
// Rückgabe false bei Polartag/-nacht.
inline bool sunTimes(int y, int mo, int d, double lat, double lon, double& riseMin, double& setMin) {
  int N = (int)(daysFromCivil(y, mo, d) - daysFromCivil(y, 1, 1)) + 1;
  double g = 2.0 * M_PI / 365.0 * (N - 1 + 0.5);
  double eqt = 229.18 * (0.000075 + 0.001868 * cos(g) - 0.032077 * sin(g) - 0.014615 * cos(2 * g) - 0.040849 * sin(2 * g));
  double decl = 0.006918 - 0.399912 * cos(g) + 0.070257 * sin(g) - 0.006758 * cos(2 * g) + 0.000907 * sin(2 * g) - 0.002697 * cos(3 * g) + 0.00148 * sin(3 * g);
  double la = lat * M_PI / 180.0, zen = 90.833 * M_PI / 180.0;
  double c = cos(zen) / (cos(la) * cos(decl)) - tan(la) * tan(decl);
  if (c < -1 || c > 1) return false;
  double ha = acos(c) * 180.0 / M_PI;
  double tz = isDstEU(y, mo, d) ? 2.0 : 1.0;
  riseMin = 720 - 4 * (lon + ha) - eqt + tz * 60;
  setMin = 720 - 4 * (lon - ha) - eqt + tz * 60;
  return true;
}

// Windrichtung (Grad, woher der Wind kommt) als Text
inline const char* windDir8(float deg) {
  static const char* n[8] = {"N", "NO", "O", "SO", "S", "SW", "W", "NW"};
  if (isnan(deg)) return "-";
  int i = (int)floorf(fmodf(deg + 22.5f + 360.0f, 360.0f) / 45.0f); return n[i & 7];
}
inline int beaufort(float kmh) {
  static const float lim[12] = {1, 6, 12, 20, 29, 39, 50, 62, 75, 89, 103, 118};
  if (isnan(kmh)) return -1;
  for (int i = 0; i < 12; i++) if (kmh < lim[i]) return i;
  return 12;
}

// Web-Mercator (EPSG:3857) in Metern
inline void mercator(double lat, double lon, double& x, double& y) {
  const double R = 6378137.0;
  x = R * lon * M_PI / 180.0;
  y = R * log(tan(M_PI / 4 + lat * M_PI / 360.0));
}

// Radar: Wert in 0,01 mm pro 5 Minuten → Farbstufe 0 (kein Regen) bis 8
inline int radarLevel(int v) {
  if (v < 1 || v > 30000) return 0;
  float mmh = v * 0.12f;
  static const float lim[7] = {0.5f, 1, 2, 5, 10, 20, 50};
  for (int i = 0; i < 7; i++) if (mmh < lim[i]) return i + 1;
  return 8;
}

// Base64 dekodieren. Rückgabe: Anzahl Bytes, -1 bei Fehler/zu klein.
inline int b64Decode(const char* in, int inLen, uint8_t* out, int cap) {
  int o = 0; uint32_t acc = 0; int bits = 0;
  for (int i = 0; i < inLen; i++) {
    char c = in[i]; int v;
    if (c >= 'A' && c <= 'Z') v = c - 'A'; else if (c >= 'a' && c <= 'z') v = c - 'a' + 26;
    else if (c >= '0' && c <= '9') v = c - '0' + 52; else if (c == '+') v = 62; else if (c == '/') v = 63;
    else if (c == '=') break; else if (c == '\\' && i + 1 < inLen && in[i + 1] == '/') { v = 63; i++; }   // JSON-maskiertes "/"
    else continue;
    acc = (acc << 6) | (uint32_t)v; bits += 6;
    if (bits >= 8) { bits -= 8; if (o >= cap) return -1; out[o++] = (uint8_t)((acc >> bits) & 0xFF); }
  }
  return o;
}

// Bilineare Interpolation zwischen vier Ecken (TL, TR, BL, BR), u/v in 0..1
inline double bilin(double tl, double tr, double bl, double br, double u, double v) {
  return (tl * (1 - u) + tr * u) * (1 - v) + (bl * (1 - u) + br * u) * v;
}
// Vier Eckpunkte (lon/lat) beliebiger Reihenfolge sortieren: TL, TR, BL, BR
inline void sortCorners(const double* lon, const double* lat, int* idx) {
  int o[4] = {0, 1, 2, 3};
  for (int i = 0; i < 4; i++) for (int j = i + 1; j < 4; j++) if (lat[o[j]] > lat[o[i]]) { int t = o[i]; o[i] = o[j]; o[j] = t; }
  // o[0], o[1] oben; o[2], o[3] unten
  idx[0] = lon[o[0]] <= lon[o[1]] ? o[0] : o[1]; idx[1] = idx[0] == o[0] ? o[1] : o[0];
  idx[2] = lon[o[2]] <= lon[o[3]] ? o[2] : o[3]; idx[3] = idx[2] == o[2] ? o[3] : o[2];
}

// Stündliche Vorhersage und Tageswerte
struct WxHour { int y, mo, d, h; float temp, prec, prob, wind; int sun; int icon; };
struct WxDay { int y, mo, d, wd; float tmin, tmax, prec, probMax; int sunMin; int icon; int nh; };
// Stunden eines Tages zusammenfassen. Symbol: schwerstes Wetter, das tagsüber (8–19 Uhr) mindestens 2 Stunden vorkommt,
// sonst das häufigste Tagsymbol.
inline int dayAggregate(const WxHour* hs, int n, int y, int mo, int d, WxDay& out) {
  out = WxDay{y, mo, d, weekdayMon0(y, mo, d), NAN, NAN, 0, NAN, 0, WX_NONE, 0};
  int cnt[WX_N] = {0};
  for (int i = 0; i < n; i++) {
    const WxHour& h = hs[i]; if (h.y != y || h.mo != mo || h.d != d) continue;
    out.nh++;
    if (!isnan(h.temp)) { if (isnan(out.tmin) || h.temp < out.tmin) out.tmin = h.temp; if (isnan(out.tmax) || h.temp > out.tmax) out.tmax = h.temp; }
    if (!isnan(h.prec)) out.prec += h.prec;
    if (!isnan(h.prob) && (isnan(out.probMax) || h.prob > out.probMax)) out.probMax = h.prob;
    if (h.sun > 0) out.sunMin += h.sun;
    if (h.h >= 8 && h.h <= 19 && h.icon >= 0) cnt[wxDayVariant(h.icon)]++;
  }
  int best = WX_NONE, bestSev = -1, most = WX_NONE, mostN = 0;
  for (int c = 0; c < WX_N; c++) {
    if (cnt[c] >= 2 && wxSeverity(c) >= 5 && wxSeverity(c) > bestSev) { best = c; bestSev = wxSeverity(c); }
    if (cnt[c] > mostN) { mostN = cnt[c]; most = c; }
  }
  out.icon = best != WX_NONE ? best : most;
  return out.nh;
}
// DWD-Warnstufe aus "severity"
inline int alertLevel(const char* s) {
  if (!s) return 0;
  static const char* n[4] = {"minor", "moderate", "severe", "extreme"};
  for (int i = 0; i < 4; i++) if (!strcmp(s, n[i])) return i + 1;
  return 0;
}

// Base64 kodieren. Rückgabe: Länge, -1 wenn zu klein.
inline int b64Encode(const uint8_t* in, int n, char* out, int cap) {
  static const char T[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  int o = 0;
  for (int i = 0; i < n; i += 3) {
    uint32_t v = (uint32_t)in[i] << 16 | (i + 1 < n ? (uint32_t)in[i + 1] << 8 : 0) | (i + 2 < n ? in[i + 2] : 0);
    if (o + 4 >= cap) return -1;
    out[o++] = T[(v >> 18) & 63]; out[o++] = T[(v >> 12) & 63];
    out[o++] = i + 1 < n ? T[(v >> 6) & 63] : '='; out[o++] = i + 2 < n ? T[v & 63] : '=';
  }
  out[o] = 0; return o;
}
// Telefonnummer für wa.me: nur Ziffern mit Ländervorwahl ("0157 ..." -> "49157...", "+49 ..." -> "49...")
inline bool phoneIntl(const char* in, char* out, int cap) {
  char d[32]; int n = 0;
  for (const char* p = in; *p && n < 31; p++) if (*p >= '0' && *p <= '9') d[n++] = *p;
  d[n] = 0;
  const char* s = d;
  if (in[0] == '+' || (d[0] == '0' && d[1] == '0')) { if (d[0] == '0') s = d + 2; snprintf(out, cap, "%s", s); }
  else if (d[0] == '0') snprintf(out, cap, "49%s", d + 1);
  else snprintf(out, cap, "%s", d);
  return strlen(out) >= 8 && strlen(out) <= 15;
}
// Einwilligungs-Datei: "EINW|Datum|Daten|Gesundheit|Medien|Auswertung|Erinnerung|Fassung"
struct Consent { bool ok; char date[20]; bool data, health, media, research, remind; char ver[32]; };
inline int consentLine(const Consent& c, char* out, int cap) {
  return snprintf(out, cap, "EINW|%s|%d|%d|%d|%d|%d|%s\n", c.date, c.data, c.health, c.media, c.research, c.remind, c.ver);
}
inline bool consentParse(const char* line, Consent& c) {
  c = Consent{};
  if (strncmp(line, "EINW|", 5)) return false;
  char f[40]; int v[5];
  if (!splitField(line, '|', 1, c.date, sizeof c.date)) return false;
  for (int i = 0; i < 5; i++) { if (!splitField(line, '|', 2 + i, f, sizeof f)) return false; v[i] = atoi(f); }
  c.data = v[0]; c.health = v[1]; c.media = v[2]; c.research = v[3]; c.remind = v[4];
  splitField(line, '|', 7, c.ver, sizeof c.ver);
  for (char* p = c.ver; *p; p++) if (*p == '\n' || *p == '\r') *p = 0;
  c.ok = c.data && c.date[0];
  return c.ok;
}

}  // namespace fyf
// ---- Ende fyf_wx.h ----
static const char* VERSION = "0.4.6";

// ================= Farben =================
static const uint16_t C_BG = 0xF7BE, C_CARD = 0xFFFF, C_TEXT = 0x18E3, C_MUTED = 0x7BEF, C_LINE = 0xDEFB;
static const uint16_t C_ACC = 0xFC00, C_ACC_L = 0xFF1B, C_OK = 0x2D27, C_OK_L = 0xD7FA, C_WARN = 0xD8A3, C_WARN_L = 0xFEDB;
// Uhr (klassisches Zifferblatt: cremefarben, schwarze Ziffern, gebläute Zeiger)
static const uint16_t W_DIAL = 0xFFBC, W_INK = 0x2124, W_BLUE = 0x1A51, W_CASE = 0xC618, W_CASE_D = 0x8C51, W_GUIL = 0xF79A;

// ================= Bildschirme =================
enum Screen { HOME, FLOW, VALUES, ANGLE, LEVEL, RIDE, OBS, SUMMARY, QR, CLOCK, SETTINGS, SETCLOCK,
              CUST, CUSTEDIT, CALC, STOPW, CHECK, CLOUD, WIFILIST, KEYB, SAVER, INFO, GAME, WETTER, SDCARD, CONSENT, FINISH, LINKS };
// Ziel der Bildschirmtastatur (hier oben, weil die Arduino IDE Funktions-Vorab-Deklarationen nach oben setzt)
enum KbTarget { KB_NAME, KB_HEIGHT, KB_INSEAM, KB_BIKE, KB_WIFIPASS, KB_PAIR, KB_WAPHONE, KB_PLACE };
// Hindernis im Mini-Spiel (ebenfalls hier oben wegen der Arduino-Vorab-Deklarationen)
struct GObj { float x; int w, h, type; bool on; };   // type 0 = Hütchen, 1 = Baumstamm, 2 = Münze (h = Höhe über Boden)
// Wetter-Daten (ebenfalls hier oben wegen der Arduino-Vorab-Deklarationen)
struct WxNowT { bool ok; float temp, hum, wind, gust, wdir, press, dew; int icon; int y, mo, d, h, mi; };
struct WxAlertT { int level; char event[48]; char head[120]; char desc[480]; char when[48]; };
struct WxRadarT { int n, W, H, nowI; int fy[48], fmo[48], fd[48], fh[48], fmi[48]; double inv[6]; uint16_t* px; bool ok; };
static Screen screen = HOME;
static bool needFull = true;

// ================= Knöpfe =================
struct Btn { int x, y, w, h; const char* label; int id; uint16_t bg, fg; bool visible; };
static Btn btns[80];
static int nBtns = 0;
static void addBtn(int x, int y, int w, int h, const char* label, int id, uint16_t bg = C_CARD, uint16_t fg = C_TEXT, bool vis = true) {
  if (nBtns < 80) btns[nBtns++] = {x, y, w, h, label, id, bg, fg, vis};
}
static void drawBtn(const Btn& b, const lgfx::IFont* f = &fonts::FreeSansBold18pt7b) {
  if (!b.visible) return;
  auto& d = M5.Display;
  d.fillRoundRect(b.x, b.y, b.w, b.h, 16, b.bg);
  if (b.bg == C_CARD || b.bg == C_BG) d.drawRoundRect(b.x, b.y, b.w, b.h, 16, C_LINE);
  d.setFont(f); d.setTextDatum(middle_center); d.setTextColor(b.fg, b.bg);
  d.drawString(b.label, b.x + b.w / 2, b.y + b.h / 2 + 2);
}
static void drawAllBtns(const lgfx::IFont* f = &fonts::FreeSansBold18pt7b) { for (int i = 0; i < nBtns; i++) drawBtn(btns[i], f); }
static int hitBtn(int x, int y) {
  for (int i = nBtns - 1; i >= 0; i--) { const Btn& b = btns[i]; if (x >= b.x && x < b.x + b.w && y >= b.y && y < b.y + b.h) return b.id; }
  return -1;
}
// Text mit Zeilenumbruch an Wortgrenzen
static void drawWrapped(const char* text, int x, int y, int maxW, int lineH) {
  auto& d = M5.Display; char line[128] = ""; char word[64]; const char* p = text;
  while (*p) {
    int n = 0; while (*p == ' ') p++; while (*p && *p != ' ' && n < 63) word[n++] = *p++; word[n] = 0; if (!n) break;
    char test[192]; snprintf(test, sizeof test, line[0] ? "%s %s" : "%s%s", line, word);
    if (d.textWidth(test) > maxW && line[0]) { d.drawString(line, x, y); y += lineH; snprintf(line, sizeof line, "%s", word); }
    else snprintf(line, sizeof line, "%s", test);
  }
  if (line[0]) d.drawString(line, x, y);
}

// ================= Einstellungen & Speicher =================
static Preferences prefs;
static int bright = 160; static bool sound = true; static bool invertAngle = false; static float angleOffset = 0;
static int saverMin = 5;      // Bildschirmschoner nach x Minuten (0 = aus)
static int activeCust = 0;    // aktiver Kunde (Datei-Nummer), 0 = keiner
static const int NCHK = 12; static uint8_t chk[NCHK];
static void beep(int f = 2200, int ms = 35) { if (sound) M5.Speaker.tone(f, ms); }
static void commaify(char* s) { for (; *s; s++) if (*s == '.') *s = ','; }

// Messfelder (wie in FYF). Winkel-Felder am Ende.
static const int NF = 12;
static const char* F_NAME[NF] = {"Sattelhoehe", "Sattelversatz", "Sattel ueber Boden", "Lenker ueber Boden", "Ueberhoehung",
                                 "Sattel-Lenker", "Lenker vor Tretlager", "Schalthebel ueb. Boden", "Kurbellaenge",
                                 "Sattelneigung", "Lenkerneigung", "Kniewinkel unten"};
static const char* F_UNIT[NF] = {"mm", "mm", "mm", "mm", "mm", "mm", "mm", "mm", "mm", "Grad", "Grad", "Grad"};
static const int ANGLE_FIELDS[3] = {9, 10, 11};
static float vals[2][NF];   // [0]=vorher, [1]=nachher
static int side = 0;        // aktuelle Seite: 0 vorher, 1 nachher

// Geführter Ablauf (wie in FYF)
static const int NS = 12;
static const char* S_NAME[NS] = {"Kunde und Fahrrad", "Ziele und Beschwerden", "Koerperanalyse", "Sitzknochen messen", "Koerpermasse",
                                 "Beweglichkeitstests", "Fahrrad vermessen", "Bewegungsanalyse", "Anpassungen", "Produktempfehlungen",
                                 "Fitting abschliessen", "Bericht erstellen"};
static const char* S_HINT[NS] = {
  "Kunden waehlen oder anlegen (auch aus FYF ladbar). Rad in die Rolle und gerade ausrichten.",
  "Ziel, Beschwerden und Fahrstil erfragen und in der FYF-App eintragen.",
  "Stand, Beinachsen und Fussstellung ansehen. Beobachtungen hier antippen.",
  "Sitzknochenabstand mit dem Messset messen und in der FYF-App eintragen.",
  "Koerpergroesse und Schrittlaenge messen und in der FYF-App eintragen.",
  "Beweglichkeit testen, z. B. Oberschenkelrueckseite. Ergebnis in FYF.",
  "Ausgangswerte messen: Messwerte (VORHER) und Winkelmesser.",
  "Fahrprogramm starten und bei fester Last mit dem iPhone filmen.",
  "Aenderungen am Rad vornehmen, danach im Fahrprogramm 'Nach Aenderung messen'.",
  "Passende Produkte auswaehlen, z. B. Einlagen, Keile oder Sattel.",
  "Endwerte messen (Messwerte NACHHER) und die Uebersicht pruefen.",
  "Werte an FYF senden (oder per QR-Code) und den Bericht in der FYF-App erstellen."};
static const int S_TOOL[NS] = {CUST, -1, OBS, -1, -1, -1, VALUES, RIDE, RIDE, -1, SUMMARY, SUMMARY};
static uint8_t flowSt[NS];   // 0 offen, 1 erledigt, 2 übersprungen
static int flowCur = 0;

// Beobachtungen (Schnell-Notizen, keine Diagnose)
static const int NO = 10;
static const char* O_NAME[NO] = {"Knie links nach innen", "Knie rechts nach innen", "Becken kippt seitlich", "Rutscht nach vorn",
                                 "Ferse tropft stark", "Schultern verspannt", "Haende schlafen ein", "Fuesse schlafen ein",
                                 "Druck am Sattel", "Ruecken sehr rund"};
static uint16_t obsMin[NO];  // Minute des Tages + 1 (0 = nicht gesetzt)

static void keyF(char* k, char c, int i) { snprintf(k, 8, "%c%d", c, i); }
static void loadAll() {
  prefs.begin("fyf", true);
  char k[8];
  for (int s = 0; s < 2; s++) for (int i = 0; i < NF; i++) { keyF(k, s ? 'a' : 'b', i); vals[s][i] = prefs.getFloat(k, NAN); }
  if (prefs.getBytesLength("flow") == NS) prefs.getBytes("flow", flowSt, NS); else memset(flowSt, 0, NS);
  if (prefs.getBytesLength("obs") == sizeof(obsMin)) prefs.getBytes("obs", obsMin, sizeof(obsMin)); else memset(obsMin, 0, sizeof(obsMin));
  bright = prefs.getInt("bri", 160); sound = prefs.getBool("snd", true); invertAngle = prefs.getBool("inv", false);
  angleOffset = prefs.getFloat("aoff", 0); side = prefs.getInt("side", 0);
  saverMin = prefs.getInt("svr", 5); activeCust = prefs.getInt("cust", 0);
  if (prefs.getBytesLength("chk") == NCHK) prefs.getBytes("chk", chk, NCHK); else memset(chk, 0, NCHK);
  prefs.end();
}
static void saveVal(int s, int i) { prefs.begin("fyf", false); char k[8]; keyF(k, s ? 'a' : 'b', i); prefs.putFloat(k, vals[s][i]); prefs.end(); }
static void saveFlow() { prefs.begin("fyf", false); prefs.putBytes("flow", flowSt, NS); prefs.end(); }
static void saveObs() { prefs.begin("fyf", false); prefs.putBytes("obs", obsMin, sizeof(obsMin)); prefs.end(); }
static void saveSettings() {
  prefs.begin("fyf", false); prefs.putInt("bri", bright); prefs.putBool("snd", sound); prefs.putBool("inv", invertAngle);
  prefs.putFloat("aoff", angleOffset); prefs.putInt("side", side); prefs.putInt("svr", saverMin); prefs.putInt("cust", activeCust); prefs.end();
}
static void newFitting() {
  prefs.begin("fyf", false);
  char k[8];
  for (int s = 0; s < 2; s++) for (int i = 0; i < NF; i++) { vals[s][i] = NAN; keyF(k, s ? 'a' : 'b', i); prefs.remove(k); }
  memset(flowSt, 0, NS); memset(obsMin, 0, sizeof(obsMin)); prefs.putBytes("flow", flowSt, NS); prefs.putBytes("obs", obsMin, sizeof(obsMin));
  side = 0; prefs.putInt("side", 0); prefs.end(); flowCur = 0;
}

// ================= Uhrzeit =================
static bool rtcOk = false;
static long long swBase = 0; static uint32_t swMillis = 0;   // Ersatz-Uhr, falls keine RTC
static fyf::DT nowDT() {
  if (rtcOk) {
    auto t = M5.Rtc.getDateTime();
    fyf::DT r{(int)t.date.year, (int)t.date.month, (int)t.date.date, (int)t.time.hours, (int)t.time.minutes, (int)t.time.seconds, 0};
    if (r.y >= 2000 && r.mo >= 1 && r.mo <= 12 && r.d >= 1 && r.d <= 31) { r.wd = fyf::weekdayMon0(r.y, r.mo, r.d); return r; }
  }
  return fyf::fromEpoch(swBase + (millis() - swMillis) / 1000);
}
static void setNow(const fyf::DT& t) {
  if (rtcOk) {
    m5::rtc_datetime_t dt;
    dt.date.year = t.y; dt.date.month = t.mo; dt.date.date = t.d; dt.date.weekDay = (t.wd + 1) % 7;  // 0 = Sonntag
    dt.time.hours = t.h; dt.time.minutes = t.mi; dt.time.seconds = t.s;
    M5.Rtc.setDateTime(dt);
  }
  swBase = fyf::toEpoch(t.y, t.mo, t.d, t.h, t.mi, t.s); swMillis = millis();
  prefs.begin("fyf", false); prefs.putLong64("clk", swBase); prefs.end();
}
static const char* WD_NAME[7] = {"Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"};
static const char* WD_SHORT[7] = {"Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"};
static const char* MO_NAME[12] = {"Januar", "Februar", "Maerz", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"};

// ================= Lagesensor =================
static bool imuOk = false;
static float sLong = 0, sShort = 0, sUp = 0;
static float hist[20]; static int histN = 0, histI = 0;
static void readImu() {
  float ax, ay, az;
  if (!imuOk || !M5.Imu.getAccel(&ax, &ay, &az)) return;
  sLong = fyf::smooth(sLong, fyf::tiltLongDeg(ax, ay, az), 0.15f);
  sShort = fyf::smooth(sShort, fyf::tiltShortDeg(ax, ay, az), 0.15f);
  sUp = fyf::smooth(sUp, fyf::tiltUprightDeg(ax, ay), 0.15f);
  hist[histI] = sLong; histI = (histI + 1) % 20; if (histN < 20) histN++;
}
static bool isSteady() {
  if (histN < 20) return false;
  float mn = hist[0], mx = hist[0];
  for (int i = 1; i < 20; i++) { mn = fminf(mn, hist[i]); mx = fmaxf(mx, hist[i]); }
  return fyf::steady(mn, mx, 0.15f);
}

// ================= Kopfzeile =================
static int lastHeaderMin = -1;
static void drawHeaderRight() {
  auto& d = M5.Display;
  fyf::DT t = nowDT(); lastHeaderMin = t.mi;
  char s[40]; int bat = M5.Power.getBatteryLevel();
  if (bat >= 0) snprintf(s, sizeof s, "%02d:%02d   Akku %d%%", t.h, t.mi, bat); else snprintf(s, sizeof s, "%02d:%02d", t.h, t.mi);
  d.fillRect(d.width() - 330, 20, 320, 50, C_CARD);
  d.setFont(&fonts::FreeSans18pt7b); d.setTextDatum(middle_right); d.setTextColor(C_MUTED, C_CARD);
  d.drawString(s, d.width() - 28, 45);
}
static void drawHeader(const char* title, bool back, bool showSide = false) {
  auto& d = M5.Display;
  d.fillRect(0, 0, d.width(), 90, C_CARD); d.drawFastHLine(0, 90, d.width(), C_LINE);
  d.fillRect(0, 0, 8, 90, C_ACC);
  int x = 30;
  if (back) { addBtn(20, 12, 170, 66, "< Zurueck", 0, C_BG, C_TEXT); drawBtn(btns[nBtns - 1]); x = 210; }
  d.setFont(&fonts::FreeSansBold24pt7b); d.setTextDatum(middle_left); d.setTextColor(C_TEXT, C_CARD);
  d.drawString(title, x, 47);
  if (showSide) { addBtn(d.width() - 560, 15, 210, 60, side ? "NACHHER" : "VORHER", 900, side ? C_OK : C_ACC, 0xFFFF); drawBtn(btns[nBtns - 1]); }
  drawHeaderRight();
}

// ================= Symbole für das Menü =================
static void drawIcon(int id, int cx, int cy, uint16_t c, uint16_t bg) {
  auto& d = M5.Display;
  switch (id) {
    case FLOW:  // Liste mit Haken
      for (int i = 0; i < 3; i++) { int y = cy - 30 + i * 30; d.fillRoundRect(cx - 34, y - 4, 70, 8, 4, c); d.drawLine(cx - 58, y, cx - 52, y + 6, c); d.drawLine(cx - 52, y + 6, cx - 42, y - 6, c); }
      break;
    case VALUES:  // Lineal
      d.drawRoundRect(cx - 55, cy - 18, 110, 36, 6, c);
      for (int i = 0; i < 10; i++) d.drawFastVLine(cx - 45 + i * 10, cy - 18, i % 2 ? 10 : 18, c);
      break;
    case ANGLE:  // Winkel mit Bogen
      d.drawLine(cx - 45, cy + 30, cx + 50, cy + 30, c); d.drawLine(cx - 45, cy + 30, cx + 35, cy - 35, c);
      d.drawArc(cx - 45, cy + 30, 50, 46, 320, 360, c);
      break;
    case LEVEL:  // Blase
      d.drawCircle(cx, cy, 40, c); d.drawCircle(cx, cy, 14, c); d.fillCircle(cx + 10, cy - 6, 9, c);
      break;
    case RIDE:  // Laufrad mit Speichen
      d.drawCircle(cx, cy, 42, c); d.drawCircle(cx, cy, 38, c); d.fillCircle(cx, cy, 7, c);
      for (int i = 0; i < 8; i++) { float a = i * 45 * DEG_TO_RAD; d.drawLine(cx, cy, cx + (int)(cosf(a) * 38), cy + (int)(sinf(a) * 38), c); }
      break;
    case STOPW:  // Stoppuhr
      d.drawCircle(cx, cy + 6, 36, c); d.fillRect(cx - 8, cy - 42, 16, 8, c); d.drawLine(cx, cy + 6, cx + 18, cy - 14, c); d.drawLine(cx, cy + 6, cx, cy - 20, c);
      break;
    case GAME:  // Gamepad
      d.fillRoundRect(cx - 50, cy - 24, 100, 52, 24, c); d.fillRect(cx - 34, cy - 4, 24, 8, bg); d.fillRect(cx - 26, cy - 12, 8, 24, bg);
      d.fillCircle(cx + 20, cy - 4, 6, bg); d.fillCircle(cx + 34, cy + 8, 6, bg);
      break;
    case INFO:  // Schraubenschlüssel
      for (int k = -4; k <= 4; k++) d.drawLine(cx - 30 + k, cy + 30 + k, cx + 14 + k, cy - 14 + k, c);
      d.fillCircle(cx + 22, cy - 22, 20, c); d.fillCircle(cx + 30, cy - 30, 9, bg);
      break;
    case CUST:  // Person
      d.fillCircle(cx, cy - 18, 18, c); d.fillRoundRect(cx - 34, cy + 6, 68, 38, 18, c);
      break;
    case CALC:  // Rechner
      d.drawRoundRect(cx - 32, cy - 42, 64, 84, 8, c); d.fillRect(cx - 22, cy - 32, 44, 16, c);
      for (int i = 0; i < 9; i++) d.fillRect(cx - 22 + (i % 3) * 16, cy - 6 + (i / 3) * 14, 10, 9, c);
      break;
    case CHECK:  // Haken im Kasten
      d.drawRoundRect(cx - 38, cy - 38, 76, 76, 12, c);
      for (int k = -2; k <= 2; k++) { d.drawLine(cx - 22, cy + k, cx - 6, cy + 16 + k, c); d.drawLine(cx - 6, cy + 16 + k, cx + 24, cy - 18 + k, c); }
      break;
    case CLOUD:  // Wolke mit Pfeil
      d.fillCircle(cx - 22, cy + 6, 20, c); d.fillCircle(cx + 2, cy - 10, 26, c); d.fillCircle(cx + 26, cy + 6, 20, c); d.fillRect(cx - 22, cy + 6, 48, 20, c);
      d.fillTriangle(cx + 2, cy - 14, cx - 12, cy + 4, cx + 16, cy + 4, bg); d.fillRect(cx - 3, cy + 2, 10, 18, bg);
      break;
    case OBS:  // Auge
      d.drawEllipse(cx, cy, 50, 26, c); d.fillCircle(cx, cy, 14, c);
      break;
    case SUMMARY:  // QR-Quadrate
      d.drawRect(cx - 42, cy - 42, 30, 30, c); d.drawRect(cx + 12, cy - 42, 30, 30, c); d.drawRect(cx - 42, cy + 12, 30, 30, c);
      d.fillRect(cx - 34, cy - 34, 14, 14, c); d.fillRect(cx + 20, cy - 34, 14, 14, c); d.fillRect(cx - 34, cy + 20, 14, 14, c);
      d.fillRect(cx + 14, cy + 14, 10, 10, c); d.fillRect(cx + 30, cy + 28, 10, 10, c);
      break;
    case CLOCK:  // Uhr
      d.drawCircle(cx, cy, 40, c); d.drawCircle(cx, cy, 36, c); d.drawLine(cx, cy, cx, cy - 26, c); d.drawLine(cx, cy, cx + 18, cy + 8, c); d.fillCircle(cx, cy, 4, c);
      break;
    case WETTER:  // Sonne hinter Wolke
      for (int i = 0; i < 8; i++) { float a = i * 45 * DEG_TO_RAD; d.drawLine(cx - 14 + (int)(cosf(a) * 30), cy - 14 + (int)(sinf(a) * 30), cx - 14 + (int)(cosf(a) * 40), cy - 14 + (int)(sinf(a) * 40), c); }
      d.fillCircle(cx - 14, cy - 14, 22, c); d.fillCircle(cx - 2, cy + 14, 21, bg); d.fillCircle(cx + 20, cy + 4, 25, bg); d.fillRoundRect(cx - 26, cy + 12, 76, 30, 15, bg);
      d.fillCircle(cx - 2, cy + 16, 17, c); d.fillCircle(cx + 20, cy + 6, 21, c); d.fillRoundRect(cx - 22, cy + 16, 68, 24, 12, c);
      break;
    case SDCARD:  // Speicherkarte
      d.fillRoundRect(cx - 30, cy - 40, 60, 80, 8, c); d.fillTriangle(cx + 12, cy - 41, cx + 31, cy - 41, cx + 31, cy - 22, bg);
      for (int i = 0; i < 4; i++) d.fillRect(cx - 20 + i * 11, cy - 32, 6, 16, bg);
      break;
    case SETTINGS:  // Zahnrad
      for (int i = 0; i < 8; i++) { float a = i * 45 * DEG_TO_RAD; d.fillCircle(cx + (int)(cosf(a) * 34), cy + (int)(sinf(a) * 34), 9, c); }
      d.fillCircle(cx, cy, 30, c); d.fillCircle(cx, cy, 12, bg);
      break;
    default: break;
  }
}

// ================= START / MENÜ =================
static int homePage = 0;  // 0 = Fitting, 1 = Mehr
static const int MENU_N[2] = {9, 9};
static const int MENU_ID[2][9] = {{FLOW, CUST, VALUES, ANGLE, LEVEL, RIDE, OBS, SUMMARY, CALC}, {WETTER, STOPW, CHECK, CLOUD, INFO, GAME, CLOCK, SDCARD, SETTINGS}};
static const char* MENU_NAME[2][9] = {{"Ablauf", "Kunden", "Messwerte", "Winkelmesser", "Wasserwaage", "Fahrprogramm", "Beobachtungen", "Uebersicht", "Rechner"},
                                      {"Wetter", "Stoppuhr", "Checkliste", "FYF & WLAN", "Nachschlagen", "Rad-Sprung", "Uhr", "SD-Karte", "Einstellungen"}};
static const char* activeName();   // weiter unten (Kunden)
static void wxHomeSub(char* s, int n);   // weiter unten (Wetter)
static void sdHomeSub(char* s, int n);
static bool cloudPaired();
static bool wifiOn();
static bool swRun = false;
static void flowProgress(int& done, int& total) { done = 0; total = NS; for (int i = 0; i < NS; i++) if (flowSt[i] == 1) done++; }
static void drawHome() {
  auto& d = M5.Display; d.fillScreen(C_BG); nBtns = 0;
  drawHeader("FYF Station", false);
  addBtn(400, 15, 190, 60, "Fitting", 150, homePage == 0 ? C_ACC : C_BG, homePage == 0 ? 0xFFFF : C_TEXT);
  addBtn(600, 15, 190, 60, "Mehr", 151, homePage == 1 ? C_ACC : C_BG, homePage == 1 ? 0xFFFF : C_TEXT);
  drawBtn(btns[nBtns - 2]); drawBtn(btns[nBtns - 1]);
  int W = d.width(), H = d.height(), g = 22, top = 108, cols = 3, rows = MENU_N[homePage] > 6 ? 3 : 2;
  int bw = (W - (cols + 1) * g) / cols, bh = (H - top - rows * g) / rows;
  for (int i = 0; i < MENU_N[homePage]; i++) {
    int id = MENU_ID[homePage][i];
    int x = g + (i % cols) * (bw + g), y = top + (i / cols) * (bh + g);
    bool hi = id == FLOW || id == VALUES || id == CLOUD || id == WETTER;
    uint16_t ibg = hi ? C_ACC_L : C_BG;
    d.fillRoundRect(x, y, bw, bh, 22, C_CARD); d.drawRoundRect(x, y, bw, bh, 22, C_LINE);
    d.fillRoundRect(x + 22, y + bh / 2 - 55, 110, 110, 24, ibg);
    drawIcon(id, x + 77, y + bh / 2, hi ? C_ACC : C_TEXT, ibg);
    d.setFont(&fonts::FreeSansBold18pt7b); d.setTextDatum(middle_left); d.setTextColor(C_TEXT, C_CARD);
    d.drawString(MENU_NAME[homePage][i], x + 152, y + bh / 2 - 14);
    char sub[48] = "";
    if (id == FLOW) { int dn, tt; flowProgress(dn, tt); snprintf(sub, sizeof sub, "%d von %d erledigt", dn, tt); }
    else if (id == VALUES) { int n = 0; for (int k = 0; k < NF; k++) n += !isnan(vals[0][k]) + !isnan(vals[1][k]); snprintf(sub, sizeof sub, "%d Werte erfasst", n); }
    else if (id == CLOCK) { fyf::DT t = nowDT(); snprintf(sub, sizeof sub, "%02d.%02d.%04d", t.d, t.mo, t.y); }
    else if (id == ANGLE || id == LEVEL) snprintf(sub, sizeof sub, "%s", imuOk ? "Lagesensor bereit" : "kein Lagesensor");
    else if (id == CUST) { const char* n = activeName(); char f[24]; fyf::asciiFold(n, f, sizeof f); snprintf(sub, sizeof sub, "%s", n[0] ? f : "kein Kunde gewaehlt"); }
    else if (id == CALC) snprintf(sub, sizeof sub, "Sattel, Kurbel, Vorbau");
    else if (id == INFO) snprintf(sub, sizeof sub, "Drehmomente, Cleats");
    else if (id == GAME) snprintf(sub, sizeof sub, "Mini-Spiel");
    else if (id == STOPW) snprintf(sub, sizeof sub, "%s", swRun ? "laeuft" : "mit Runden");
    else if (id == CHECK) { int n = 0; for (int k = 0; k < NCHK; k++) n += chk[k]; snprintf(sub, sizeof sub, "%d von %d erledigt", n, NCHK); }
    else if (id == CLOUD) snprintf(sub, sizeof sub, "%s, %s", wifiOn() ? "WLAN an" : "offline", cloudPaired() ? "gekoppelt" : "nicht gekoppelt");
    else if (id == WETTER) wxHomeSub(sub, sizeof sub);
    else if (id == SDCARD) sdHomeSub(sub, sizeof sub);
    if (sub[0]) { d.setFont(&fonts::FreeSans12pt7b); d.setTextColor(C_MUTED, C_CARD); d.drawString(sub, x + 152, y + bh / 2 + 24); }
    addBtn(x, y, bw, bh, "", 100 + id, C_CARD, C_TEXT, false);
  }
}

// ================= ABLAUF =================
static void drawFlow() {
  auto& d = M5.Display; d.fillScreen(C_BG); nBtns = 0;
  int dn, tt; flowProgress(dn, tt);
  drawHeader("Gefuehrter Ablauf", true);
  for (int i = 0; i < NS; i++) {
    int y = 104 + i * 50; bool cur = i == flowCur;
    uint16_t bg = cur ? C_ACC_L : C_CARD;
    d.fillRoundRect(20, y, 560, 44, 10, bg);
    uint16_t dot = flowSt[i] == 1 ? C_OK : flowSt[i] == 2 ? C_MUTED : C_LINE;
    d.fillCircle(46, y + 22, 13, dot);
    d.setFont(&fonts::FreeSans12pt7b);
    if (flowSt[i] == 1) { d.drawLine(39, y + 22, 45, y + 28, 0xFFFF); d.drawLine(45, y + 28, 54, y + 15, 0xFFFF); }
    else { char n[4]; snprintf(n, sizeof n, "%d", i + 1); d.setTextDatum(middle_center); d.setTextColor(flowSt[i] == 2 ? 0xFFFF : C_TEXT, dot); d.drawString(n, 46, y + 23); }
    d.setTextDatum(middle_left); d.setTextColor(flowSt[i] == 2 ? C_MUTED : C_TEXT, bg);
    d.drawString(S_NAME[i], 72, y + 23);
    addBtn(20, y, 560, 44, "", 300 + i, bg, C_TEXT, false);
  }
  d.fillRoundRect(610, 104, 650, 26, 13, C_LINE);
  if (dn) d.fillRoundRect(610, 104, 650 * dn / tt, 26, 13, C_OK);
  char p[32]; snprintf(p, sizeof p, "%d von %d erledigt", dn, tt);
  d.setFont(&fonts::FreeSans12pt7b); d.setTextDatum(top_left); d.setTextColor(C_MUTED, C_BG); d.drawString(p, 610, 138);
  d.fillRoundRect(610, 175, 650, 300, 18, C_CARD); d.drawRoundRect(610, 175, 650, 300, 18, C_LINE);
  char hd[40]; snprintf(hd, sizeof hd, "Schritt %d von %d", flowCur + 1, NS);
  d.setFont(&fonts::FreeSans12pt7b); d.setTextColor(C_ACC, C_CARD); d.drawString(hd, 636, 195);
  d.setFont(&fonts::FreeSansBold24pt7b); d.setTextColor(C_TEXT, C_CARD); d.drawString(S_NAME[flowCur], 636, 228);
  d.setFont(&fonts::FreeSans18pt7b); d.setTextColor(C_TEXT, C_CARD); drawWrapped(S_HINT[flowCur], 636, 300, 600, 42);
  int by = 495, H = d.height();
  addBtn(610, by, 210, 90, "< Schritt", 310, C_CARD); addBtn(830, by, 210, 90, "Ueberspringen", 311, C_CARD, C_MUTED);
  addBtn(1050, by, 210, 90, flowSt[flowCur] == 1 ? "Wieder offen" : "Erledigt", 312, C_OK, 0xFFFF);
  if (S_TOOL[flowCur] >= 0) addBtn(610, H - 120, 650, 100, "Werkzeug oeffnen", 313, C_ACC, 0xFFFF);
  else addBtn(610, H - 120, 650, 100, "in der FYF-App erledigen", 314, C_BG, C_MUTED);
  for (int i = 0; i < nBtns; i++) if (btns[i].id >= 310) drawBtn(btns[i]);
}

// ================= MESSWERTE =================
static int curField = 0; static char inBuf[10] = "";
static const char KEYS[12] = {'7', '8', '9', '4', '5', '6', '1', '2', '3', ',', '0', '<'};
static char keyLbl[12][2];
static void fmtVal(char* s, int n, float v, bool sign = false) {
  if (isnan(v)) { snprintf(s, n, "-"); return; }
  snprintf(s, n, sign ? "%+.1f" : "%.1f", v); int L = strlen(s);
  if (L > 2 && s[L - 1] == '0' && s[L - 2] == '.') s[L - 2] = 0;  // 742.0 -> 742
  commaify(s);
}
static void drawValuesList() {
  auto& d = M5.Display;
  d.setFont(&fonts::FreeSans12pt7b);
  d.fillRect(20, 100, 640, 26, C_BG); d.setTextColor(C_MUTED, C_BG); d.setTextDatum(middle_left); d.drawString("Messpunkt", 30, 113);
  d.setTextDatum(middle_right); d.drawString("vorher", 500, 113); d.drawString("nachher", 640, 113);
  for (int i = 0; i < NF; i++) {
    int y = 130 + i * 46; bool sel = i == curField; uint16_t bg = sel ? C_ACC : C_CARD, fg = sel ? 0xFFFF : C_TEXT;
    d.fillRoundRect(20, y, 640, 42, 10, bg);
    d.setTextDatum(middle_left); d.setTextColor(fg, bg); d.drawString(F_NAME[i], 34, y + 22);
    char a[16], b[16]; fmtVal(a, sizeof a, vals[0][i]); fmtVal(b, sizeof b, vals[1][i]);
    d.setTextDatum(middle_right);
    d.setTextColor(sel ? 0xFFFF : (side == 0 ? C_TEXT : C_MUTED), bg); d.drawString(a, 500, y + 22);
    d.setTextColor(sel ? 0xFFFF : (side == 1 ? C_TEXT : C_MUTED), bg); d.drawString(b, 640, y + 22);
  }
}
static void drawValuesInput() {
  auto& d = M5.Display;
  d.fillRoundRect(690, 104, 570, 96, 14, C_CARD); d.drawRoundRect(690, 104, 570, 96, 14, side ? C_OK : C_ACC);
  d.setFont(&fonts::FreeSans12pt7b); d.setTextDatum(top_left); d.setTextColor(C_MUTED, C_CARD);
  char h[60]; snprintf(h, sizeof h, "%s (%s)", F_NAME[curField], side ? "nachher" : "vorher"); d.drawString(h, 708, 112);
  d.setFont(&fonts::FreeSansBold24pt7b); d.setTextDatum(middle_right); d.setTextColor(C_TEXT, C_CARD);
  char s[24]; snprintf(s, sizeof s, "%s %s", inBuf[0] ? inBuf : "_", F_UNIT[curField]); d.drawString(s, 1240, 165);
}
static void drawValues() {
  auto& d = M5.Display; d.fillScreen(C_BG); nBtns = 0;
  drawHeader("Messwerte", true, true);
  for (int i = 0; i < NF; i++) addBtn(20, 130 + i * 46, 640, 42, "", 400 + i, C_CARD, C_TEXT, false);
  int kx = 690, ky = 214, kw = 182, kh = 92, g = 12;
  for (int i = 0; i < 12; i++) { keyLbl[i][0] = KEYS[i]; keyLbl[i][1] = 0; addBtn(kx + (i % 3) * (kw + g), ky + (i / 3) * (kh + g), kw, kh, keyLbl[i], 420 + i); }
  addBtn(kx, d.height() - 92, 3 * kw + 2 * g, 80, "Uebernehmen", 440, C_ACC, 0xFFFF);
  drawAllBtns(&fonts::FreeSansBold24pt7b);
  drawValuesList(); drawValuesInput();
}

// ================= WINKELMESSER =================
static bool angleHold = false; static float heldVal = 0; static int angleMode = 0, angleTgt = 0;
static const char* MODE_NAME[3] = {"Flach: lang", "Flach: kurz", "Hochkant"};
static float rawAngle() { float v = angleMode == 0 ? sLong : angleMode == 1 ? sShort : sUp; return invertAngle ? -v : v; }
static float curAngle() { return angleHold ? heldVal : fyf::round1(rawAngle() - angleOffset); }
static void drawAngle() {
  auto& d = M5.Display; d.fillScreen(C_BG); nBtns = 0;
  drawHeader("Winkelmesser", true, true);
  int W = d.width(), H = d.height();
  addBtn(20, H - 120, 230, 100, "Nullen", 500); addBtn(265, H - 120, 230, 100, angleHold ? "Weiter" : "Halten", 501);
  addBtn(510, H - 120, 260, 100, MODE_NAME[angleMode], 502);
  addBtn(785, H - 120, W - 805, 100, "Speichern", 503, C_ACC, 0xFFFF);
  addBtn(W - 440, 108, 420, 70, F_NAME[ANGLE_FIELDS[angleTgt]], 504, C_CARD, C_ACC);
  drawAllBtns();
  d.setFont(&fonts::FreeSans12pt7b); d.setTextDatum(top_left); d.setTextColor(C_MUTED, C_BG);
  d.drawString("Speichern als (antippen zum Wechseln):", W - 440, 184);
  d.drawString("Erst auf ebener Flaeche 'Nullen', dann auflegen.", 28, 114);
  if (!imuOk) { d.setTextColor(C_WARN, C_BG); d.drawString("Lagesensor nicht gefunden.", 28, 140); }
}
static void drawAngleValue() {
  auto& d = M5.Display; int W = d.width();
  float v = curAngle(); bool st = isSteady();
  M5Canvas c(&d); c.setPsram(true); c.createSprite(W - 40, 330); c.fillSprite(C_BG);
  int cx = (W - 40) / 2;
  c.fillRoundRect(cx - 420, 280, 840, 14, 7, C_LINE); c.fillRect(cx - 2, 270, 4, 34, C_MUTED);
  float p = fmaxf(-1, fminf(1, v / 10.0f));
  c.fillCircle(cx + (int)(p * 410), 287, 16, angleHold ? C_ACC : (fabsf(v) < 0.3f ? C_OK : C_TEXT));
  char s[16]; snprintf(s, sizeof s, "%+.1f", v); commaify(s);
  c.setFont(&fonts::FreeSansBold24pt7b); c.setTextSize(3.4f); c.setTextDatum(middle_center);
  c.setTextColor(angleHold ? C_ACC : (st ? C_OK : C_TEXT), C_BG); c.drawString(s, cx, 120);
  c.setFont(&fonts::FreeSans18pt7b); c.setTextSize(1); c.setTextColor(C_MUTED, C_BG);
  c.drawString(angleHold ? "Grad - gehalten" : (st ? "Grad - ruhig" : "Grad - ruhig halten ..."), cx, 240);
  c.pushSprite(20, 220); c.deleteSprite();
}

// ================= WASSERWAAGE =================
static void drawLevel() { M5.Display.fillScreen(C_BG); nBtns = 0; drawHeader("Wasserwaage", true); }
static void drawLevelValue() {
  auto& d = M5.Display; int H = d.height(), R = 270;
  M5Canvas c(&d); c.setPsram(true); c.createSprite(2 * R + 20, 2 * R + 20); c.fillSprite(C_BG);
  int o = R + 10;
  float x = invertAngle ? -sLong : sLong, y = invertAngle ? -sShort : sShort; bool ok = fabsf(x) < 0.5f && fabsf(y) < 0.5f;
  c.fillCircle(o, o, R, ok ? C_OK_L : C_CARD); c.drawCircle(o, o, R, C_LINE);
  for (int r = 60; r < R; r += 70) c.drawCircle(o, o, r, C_LINE);
  c.drawFastHLine(o - R, o, 2 * R, C_LINE); c.drawFastVLine(o, o - R, 2 * R, C_LINE);
  float px = fmaxf(-1, fminf(1, x / 10.0f)) * (R - 40), py = fmaxf(-1, fminf(1, y / 10.0f)) * (R - 40);
  c.fillCircle(o - (int)px, o + (int)py, 40, ok ? C_OK : C_ACC); c.drawCircle(o - (int)px, o + (int)py, 40, 0xFFFF);
  c.pushSprite(60, 90 + (H - 90 - 2 * o) / 2); c.deleteSprite();
  M5Canvas t(&d); t.setPsram(true); t.createSprite(560, 380); t.fillSprite(C_BG);
  char s[32];
  t.setFont(&fonts::FreeSans18pt7b); t.setTextDatum(top_left); t.setTextColor(C_MUTED, C_BG); t.drawString("Laengs", 0, 20); t.drawString("Quer", 0, 160);
  t.setFont(&fonts::FreeSansBold24pt7b); t.setTextSize(1.6f); t.setTextColor(ok ? C_OK : C_TEXT, C_BG);
  snprintf(s, sizeof s, "%+.1f", fyf::round1(x)); commaify(s); t.drawString(s, 0, 60);
  snprintf(s, sizeof s, "%+.1f", fyf::round1(y)); commaify(s); t.drawString(s, 0, 200);
  t.setTextSize(1); t.setFont(&fonts::FreeSans18pt7b); t.setTextColor(ok ? C_OK : C_MUTED, C_BG); t.drawString(ok ? "gerade" : "Grad", 0, 320);
  t.pushSprite(680, 160); t.deleteSprite();
}

// ================= FAHRPROGRAMM (+ Rollensteuerung KICKR / FTMS) =================
// Rollensteuerung per Bluetooth ist vorbereitet, aber AUS, bis der KICKR-Test auf dem Tab5 geklappt hat.
// Einschalten: die nächste Zeile auf 1 ändern und neu hochladen.
struct Stage { const char* name; uint32_t ms; bool measure; float load; };   // load = Anteil der Mess-Last
static Stage prog[16]; static int progN = 0, progI = 0; static bool progRun = false; static uint32_t stStart = 0, stElapsed = 0; static int measDone = 0;
static int krMess = 150, krMax = 300, metro = 0;           // Mess-Last W, Höchstwert W, Metronom U/min (0 = aus)
static volatile int krPower = -1, krCad = -1; static volatile uint32_t krLast = 0;
static bool krOn = false; static char krName[32] = ""; static int krSent = -1;
static fyf::Stat stW, stC; static fyf::RideRes rideRes[8]; static int nRide = 0;
static void progDefault() {
  progN = 0;
  prog[progN++] = {"Einfahren", 300000, false, 0.8f};
  prog[progN++] = {"Messung", 120000, true, 1.0f};
  prog[progN++] = {"Ausfahren", 120000, false, 0.6f};
  progI = 0; progRun = false; stElapsed = 0; stW.clear(); stC.clear();   // Ergebnisse bleiben bis „Neues Fitting“
}
static void progAfterChange() {
  if (progN + 2 > 16) return;
  int at = (progRun || stElapsed > 0) ? progI + 1 : progI;
  for (int i = progN - 1; i >= at; i--) prog[i + 2] = prog[i];
  prog[at] = {"Eingewoehnen", 60000, false, 1.0f}; prog[at + 1] = {"Messung nach Aenderung", 120000, true, 1.0f}; progN += 2;
}
static uint32_t stMs() { return stElapsed + (progRun ? millis() - stStart : 0); }
static bool krFresh() { return krOn && millis() - krLast < 3000; }
static int stageTarget() { return (progI < progN) ? (int)(krMess * prog[progI].load + 0.5f) : 0; }

#if FYF_KICKR
static BLEUUID FTMS_SVC((uint16_t)0x1826), FTMS_DATA((uint16_t)0x2AD2), FTMS_CP((uint16_t)0x2AD9);
static BLEClient* krClient = nullptr; static BLERemoteCharacteristic* krCp = nullptr; static BLEAdvertisedDevice* krDev = nullptr;
static void krOnData(BLERemoteCharacteristic*, uint8_t* b, size_t n, bool) { int w, c; if (fyf::ftmsParse(b, (int)n, w, c)) { if (w >= 0) krPower = w; if (c >= 0) krCad = c; krLast = millis(); } }
static void krOnCp(BLERemoteCharacteristic*, uint8_t*, size_t, bool) {}
class KrScan : public BLEAdvertisedDeviceCallbacks {
  void onResult(BLEAdvertisedDevice d) override { if (!krDev && d.haveServiceUUID() && d.isAdvertisingService(FTMS_SVC)) { krDev = new BLEAdvertisedDevice(d); BLEDevice::getScan()->stop(); } }
};
class KrConn : public BLEClientCallbacks { void onConnect(BLEClient*) override {} void onDisconnect(BLEClient*) override { krOn = false; krCp = nullptr; } };
static bool krCmd(const uint8_t* b, size_t n) { if (!krOn || !krCp) return false; krCp->writeValue((uint8_t*)b, n, true); return true; }
static void krSetTarget(int w) { if (w == krSent) return; uint8_t o[3]; int n = fyf::ftmsTargetCmd(w, krMax, o); if (krCmd(o, n)) krSent = w; }
static void krRelease() { uint8_t stop[2] = {0x08, 0x01}; krCmd(stop, 2); krSent = -1; }
static bool krConnect() {
  static bool init = false; if (!init) { BLEDevice::init("FYF Station"); init = true; }
  if (krDev) { delete krDev; krDev = nullptr; }
  static KrScan scb; BLEScan* sc = BLEDevice::getScan(); sc->setAdvertisedDeviceCallbacks(&scb); sc->setActiveScan(true); sc->start(10, false);
  if (!krDev) return false;
  static KrConn ccb; if (!krClient) { krClient = BLEDevice::createClient(); krClient->setClientCallbacks(&ccb); }
  if (!krClient->connect(krDev)) return false;
  BLERemoteService* sv = krClient->getService(FTMS_SVC); if (!sv) { krClient->disconnect(); return false; }
  BLERemoteCharacteristic* dc = sv->getCharacteristic(FTMS_DATA); krCp = sv->getCharacteristic(FTMS_CP);
  if (!dc || !krCp) { krClient->disconnect(); return false; }
  dc->registerForNotify(krOnData);
  if (krCp->canIndicate()) krCp->registerForNotify(krOnCp, false);
  snprintf(krName, sizeof krName, "%s", krDev->getName().c_str()); krOn = true;
  uint8_t req = 0x00; krCmd(&req, 1);        // Steuerung anfordern
  uint8_t start = 0x07; krCmd(&start, 1);    // Start
  return true;
}
static void krDisconnect() { if (krOn) krRelease(); if (krClient && krClient->isConnected()) krClient->disconnect(); krOn = false; krCp = nullptr; }
#else
static bool krConnect() { return false; }
static void krSetTarget(int) {}
static void krRelease() {}
static void krDisconnect() {}
#endif
// Last passend zur Stufe setzen; ohne laufendes Programm Last frei
static void krApply() { if (!krOn) return; if (progRun && progI < progN) krSetTarget(stageTarget()); else krRelease(); }

static void drawRide() {
  auto& d = M5.Display; d.fillScreen(C_BG); nBtns = 0;
  drawHeader("Fahrprogramm", true);
  int W = d.width(), H = d.height();
  d.setFont(&fonts::FreeSans12pt7b);
  for (int i = 0; i < progN && i < 7; i++) {
    int y = 108 + i * 50; bool cur = i == progI; uint16_t bg = cur ? (prog[i].measure ? C_OK : C_ACC) : C_CARD, fg = cur ? 0xFFFF : (i < progI ? C_MUTED : C_TEXT);
    d.fillRoundRect(W - 440, y, 420, 44, 10, bg);
    d.setTextDatum(middle_left); d.setTextColor(fg, bg); d.drawString(prog[i].name, W - 424, y + 23);
    char m[24]; snprintf(m, sizeof m, "%d W  %lu:%02lu", (int)(krMess * prog[i].load + 0.5f), (unsigned long)(prog[i].ms / 60000), (unsigned long)(prog[i].ms / 1000 % 60));
    d.setTextDatum(middle_right); d.drawString(m, W - 36, y + 23);
  }
  // Ergebnisse der Messstufen
  int ry = 108 + 7 * 50 + 6;
  d.setTextDatum(top_left); d.setTextColor(C_MUTED, C_BG);
  if (!nRide) d.drawString(FYF_KICKR ? "Ergebnisse erscheinen nach jeder Messung." : "Rolle: Last selbst einstellen.", W - 436, ry);
  for (int i = 0; i < nRide && i < 3; i++) {
    const fyf::RideRes& r = rideRes[nRide - 1 - i]; char s[64], sw[12];
    if (isnan(r.sdW)) snprintf(sw, sizeof sw, "-"); else snprintf(sw, sizeof sw, "%.0f", r.sdW);
    snprintf(s, sizeof s, "%.11s: %.0f W  %.0f U/min  +-%s W", r.label, r.w, r.cad, sw);
    d.setTextColor(C_TEXT, C_BG); d.drawString(s, W - 436, ry + i * 28);
  }
  addBtn(20, H - 120, 230, 100, progRun ? "Pause" : (progI >= progN ? "Neu starten" : "Start"), 600, C_ACC, 0xFFFF);
  addBtn(260, H - 120, 230, 100, "Naechste Stufe", 601);
  addBtn(500, H - 120, 180, 100, "Stopp", 602, C_WARN_L, C_WARN);
  addBtn(690, H - 120, 120, 100, "-10 W", 611); addBtn(820, H - 120, 120, 100, "+10 W", 612);
  addBtn(W - 440, H - 120, 420, 100, "Nach Aenderung messen", 603, C_OK, 0xFFFF);
  static char mlab[20]; if (metro) snprintf(mlab, sizeof mlab, "Takt %d", metro); else snprintf(mlab, sizeof mlab, "Takt aus");
  addBtn(20, 100, 200, 60, mlab, 613, metro ? C_ACC_L : C_CARD, metro ? C_ACC : C_TEXT);
  if (FYF_KICKR) addBtn(230, 100, 300, 60, krOn ? "Rolle trennen" : "Rolle verbinden", 610, krOn ? C_OK_L : C_ACC, krOn ? C_OK : 0xFFFF);
  drawAllBtns();
  d.setFont(&fonts::FreeSans12pt7b); d.setTextDatum(top_left); d.setTextColor(C_MUTED, C_BG);
  char s[96];
  if (!FYF_KICKR) snprintf(s, sizeof s, "Mess-Last %d W an der Rolle einstellen. Rollensteuerung nach KICKR-Test.", krMess);
  else if (krOn) snprintf(s, sizeof s, "%s verbunden - Last wird je Stufe gesetzt (max. %d W).", krName, krMax);
  else snprintf(s, sizeof s, "Mess-Last %d W. Andere Apps (Wahoo, Zwift) vorher schliessen.", krMess);
  d.drawString(s, 545, 116);
}
static void rideFinishStage() {
  if (progI < progN && prog[progI].measure) {
    measDone++;
    if (stW.n >= 5 && nRide < 8) {
      fyf::RideRes& r = rideRes[nRide++];
      snprintf(r.label, sizeof r.label, "%s", prog[progI].name); r.target = stageTarget();
      r.w = stW.mean(); r.cad = stC.mean(); r.sdW = stW.sd(); r.sdCad = stC.sd();
    }
  }
  stW.clear(); stC.clear();
}
static void rideTick() {
  // Messwerte sammeln: nur in Messstufen, nur die letzten 60 Sekunden (Anfahren zählt nicht)
  static uint32_t lastS = 0;
  if (progRun && progI < progN && prog[progI].measure && krFresh() && millis() - lastS >= 1000) {
    lastS = millis();
    if (stMs() + 60000 >= prog[progI].ms && krPower > 0) { stW.add(krPower); if (krCad > 0) stC.add(krCad); }
  }
  // Metronom: ein kurzer Ton je Kurbelumdrehung
  static uint32_t lastB = 0;
  if (metro > 0 && screen == RIDE && millis() - lastB >= 60000UL / metro) { lastB = millis(); beep(3200, 15); }
  if (!progRun || progI >= progN) return;
  if (stMs() >= prog[progI].ms) {
    rideFinishStage();
    progI++; stElapsed = 0; stStart = millis();
    if (progI >= progN) { progRun = false; beep(1600, 700); } else beep(prog[progI].measure ? 2600 : 2000, 400);
    krApply();
    if (screen == RIDE) needFull = true;
  }
}
static void drawRideValue() {
  auto& d = M5.Display; int W = d.width();
  M5Canvas c(&d); c.setPsram(true); c.createSprite(W - 500, 400); c.fillSprite(C_BG);
  int cx = (W - 500) / 2;
  if (progI >= progN) {
    c.setFont(&fonts::FreeSansBold24pt7b); c.setTextDatum(middle_center); c.setTextColor(C_OK, C_BG); c.drawString("Programm beendet", cx, 120);
    char s[40]; snprintf(s, sizeof s, "%d Messung(en) gemacht", measDone); c.setFont(&fonts::FreeSans18pt7b); c.setTextColor(C_MUTED, C_BG); c.drawString(s, cx, 190);
  } else {
    uint32_t tot = prog[progI].ms, el = stMs(); uint32_t rem = el >= tot ? 0 : tot - el;
    c.setFont(&fonts::FreeSans18pt7b); c.setTextDatum(middle_center); c.setTextColor(prog[progI].measure ? C_OK : C_ACC, C_BG);
    char hd[48]; snprintf(hd, sizeof hd, "%s - Soll %d W", prog[progI].name, stageTarget()); c.drawString(hd, cx, 24);
    char s[12]; snprintf(s, sizeof s, "%02lu:%02lu", (unsigned long)(rem / 60000), (unsigned long)(rem / 1000 % 60));
    c.setFont(&fonts::Font7); c.setTextSize(1.8f); c.setTextColor(C_TEXT, C_BG); c.drawString(s, cx, 120);
    c.setTextSize(1);
    c.fillRoundRect(40, 200, W - 580, 18, 9, C_LINE);
    int pw = (int)((W - 580) * fminf(1.0f, (float)el / tot)); if (pw > 0) c.fillRoundRect(40, 200, pw, 18, 9, prog[progI].measure ? C_OK : C_ACC);
    c.setFont(&fonts::FreeSans12pt7b); c.setTextColor(C_MUTED, C_BG); c.drawString(progRun ? "laeuft" : "pausiert", cx, 236);
  }
  // Live-Werte der Rolle
  if (FYF_KICKR) {
    bool f = krFresh(); char s[16];
    c.setFont(&fonts::Font7); c.setTextSize(1.2f); c.setTextDatum(middle_center); c.setTextColor(f ? C_TEXT : C_LINE, C_BG);
    snprintf(s, sizeof s, "%d", f ? (int)krPower : 0); c.drawString(s, cx - 200, 320);
    snprintf(s, sizeof s, "%d", f ? (int)krCad : 0); c.drawString(s, cx + 200, 320);
    c.setTextSize(1); c.setFont(&fonts::FreeSans12pt7b); c.setTextColor(C_MUTED, C_BG);
    c.drawString("Watt", cx - 200, 382); c.drawString("U/min", cx + 200, 382);
  }
  c.pushSprite(20, 170); c.deleteSprite();
}

// ================= BEOBACHTUNGEN =================
static void drawObs() {
  auto& d = M5.Display; d.fillScreen(C_BG); nBtns = 0;
  drawHeader("Beobachtungen", true);
  int W = d.width(), g = 18, bw = (W - 3 * g) / 2, bh = 96;
  for (int i = 0; i < NO; i++) {
    int x = g + (i % 2) * (bw + g), y = 106 + (i / 2) * (bh + 14); bool on = obsMin[i] > 0;
    uint16_t bg = on ? C_ACC : C_CARD, fg = on ? 0xFFFF : C_TEXT;
    d.fillRoundRect(x, y, bw, bh, 16, bg); if (!on) d.drawRoundRect(x, y, bw, bh, 16, C_LINE);
    d.setFont(&fonts::FreeSansBold18pt7b); d.setTextDatum(middle_left); d.setTextColor(fg, bg); d.drawString(O_NAME[i], x + 28, y + bh / 2);
    if (on) { char t[8]; snprintf(t, sizeof t, "%02d:%02d", (obsMin[i] - 1) / 60, (obsMin[i] - 1) % 60); d.setFont(&fonts::FreeSans12pt7b); d.setTextDatum(middle_right); d.drawString(t, x + bw - 24, y + bh / 2); }
    addBtn(x, y, bw, bh, "", 700 + i, bg, fg, false);
  }
  d.setFont(&fonts::FreeSans12pt7b); d.setTextDatum(bottom_left); d.setTextColor(C_MUTED, C_BG);
  d.drawString("Antippen = gesehen (mit Uhrzeit). Nochmal antippen = entfernen. Keine Diagnose.", 20, d.height() - 6);
}

// ================= ÜBERSICHT & QR =================
static void drawSummary() {
  auto& d = M5.Display; d.fillScreen(C_BG); nBtns = 0;
  drawHeader("Uebersicht", true);
  int W = d.width();
  d.fillRoundRect(20, 104, 860, 600, 16, C_CARD);
  d.setFont(&fonts::FreeSans12pt7b); d.setTextColor(C_MUTED, C_CARD);
  d.setTextDatum(middle_left); d.drawString("Messpunkt", 40, 128);
  d.setTextDatum(middle_right); d.drawString("vorher", 560, 128); d.drawString("nachher", 700, 128); d.drawString("Diff.", 850, 128);
  for (int i = 0; i < NF; i++) {
    int y = 150 + i * 45; uint16_t bg = i % 2 == 0 ? C_BG : C_CARD; d.fillRect(30, y, 840, 45, bg);
    d.setTextColor(C_TEXT, bg); d.setTextDatum(middle_left); d.drawString(F_NAME[i], 40, y + 23);
    float df = fyf::diffOrNan(vals[0][i], vals[1][i]);
    char a[16], b[16], c[16]; fmtVal(a, sizeof a, vals[0][i]); fmtVal(b, sizeof b, vals[1][i]); fmtVal(c, sizeof c, df, true);
    d.setTextDatum(middle_right); d.drawString(a, 560, y + 23); d.drawString(b, 700, y + 23);
    d.setTextColor(isnan(df) ? C_MUTED : (df != 0 ? C_ACC : C_OK), bg); d.drawString(c, 850, y + 23);
  }
  int dn, tt; flowProgress(dn, tt); int no = 0; for (int i = 0; i < NO; i++) no += obsMin[i] > 0;
  d.fillRoundRect(900, 104, W - 920, 190, 16, C_CARD);
  d.setFont(&fonts::FreeSans18pt7b); d.setTextDatum(top_left); d.setTextColor(C_TEXT, C_CARD);
  char s[64], f[32];
  fyf::asciiFold(activeName(), f, sizeof f);
  snprintf(s, sizeof s, "Kunde: %s", f[0] ? f : "-"); d.drawString(s, 924, 114);
  snprintf(s, sizeof s, "Ablauf: %d/%d", dn, tt); d.drawString(s, 924, 158);
  snprintf(s, sizeof s, "Beobachtungen: %d", no); d.drawString(s, 924, 202);
  snprintf(s, sizeof s, "Messungen Rolle: %d", measDone); d.drawString(s, 924, 246);
  addBtn(900, 304, W - 920, 76, "An FYF senden", 803, C_ACC, 0xFFFF);
  addBtn(900, 388, W - 920, 76, "Beim Kunden speichern", 802, C_OK, 0xFFFF);
  btns[nBtns - 1].visible = false;
  addBtn(900, 472, W - 920, 76, "Abschluss", 804, C_ACC_L, C_ACC);
  addBtn(900, 556, W - 920, 76, "QR-Code zeigen", 800);
  addBtn(900, 640, W - 920, 70, "Werte bearbeiten", 801);
  drawAllBtns();
  for (int i = 0; i < nBtns; i++) if (btns[i].id == 802) { btns[i].visible = true; drawBtn(btns[i], &fonts::FreeSans18pt7b); }   // langer Text, schmalere Schrift
}
static String qrText() {
  String t = "FYF Station\n";
  fyf::DT n = nowDT(); char h[40]; snprintf(h, sizeof h, "%02d.%02d.%04d %02d:%02d\n", n.d, n.mo, n.y, n.h, n.mi); t += h;
  for (int i = 0; i < NF; i++) {
    if (isnan(vals[0][i]) && isnan(vals[1][i])) continue;
    char a[16], b[16], c[16]; fmtVal(a, sizeof a, vals[0][i]); fmtVal(b, sizeof b, vals[1][i]); fmtVal(c, sizeof c, fyf::diffOrNan(vals[0][i], vals[1][i]), true);
    char line[96]; snprintf(line, sizeof line, "%s: %s > %s (%s) %s\n", F_NAME[i], a, b, c, F_UNIT[i]); t += line;
  }
  bool any = false;
  for (int i = 0; i < NO; i++) if (obsMin[i]) { if (!any) { t += "Beobachtungen:\n"; any = true; } t += "- "; t += O_NAME[i]; t += "\n"; }
  return t;
}
static void drawQr() {
  auto& d = M5.Display; d.fillScreen(C_BG); nBtns = 0;
  drawHeader("QR-Code", true);
  int H = d.height(), sz = H - 130;
  d.fillRoundRect(20, 104, sz + 20, sz + 10, 16, 0xFFFF);
  String q = qrText();
  d.qrcode(q.c_str(), 30, 109, sz, 6);
  int x = sz + 70;
  d.setFont(&fonts::FreeSans18pt7b); d.setTextDatum(top_left); d.setTextColor(C_TEXT, C_BG); d.drawString("So geht's:", x, 120);
  d.setFont(&fonts::FreeSans12pt7b); d.setTextColor(C_MUTED, C_BG);
  d.drawString("1. iPhone-Kamera auf den Code halten", x, 175);
  d.drawString("2. Text antippen und kopieren", x, 210);
  d.drawString("3. In der FYF-App als Notiz einfuegen", x, 245);
  d.drawString("Besser: 'An FYF senden' (FYF & WLAN).", x, 300);
}

// ================= UHR & KALENDER (klassisches Zifferblatt) =================
static int calY = 0, calM = 0; static int lastSec = -1;
static void handPoly(M5Canvas& c, int cx, int cy, float deg, int len, int wid, int tail, uint16_t col) {
  // schwertförmiger Zeiger: spitz, in der Mitte breit, kurzes Gegengewicht
  float a = (deg - 90) * DEG_TO_RAD, nx = cosf(a), ny = sinf(a), px = -ny, py = nx;
  float mx = cx + nx * len * 0.42f, my = cy + ny * len * 0.42f;
  float tx = cx + nx * len, ty = cy + ny * len, bx = cx - nx * tail, by = cy - ny * tail;
  c.fillTriangle((int)tx, (int)ty, (int)(mx + px * wid), (int)(my + py * wid), (int)(mx - px * wid), (int)(my - py * wid), col);
  c.fillTriangle((int)bx, (int)by, (int)(mx + px * wid), (int)(my + py * wid), (int)(mx - px * wid), (int)(my - py * wid), col);
}
static void drawClockFace(const fyf::DT& t, int px = 30, int py = 100, uint16_t bg = C_BG) {
  auto& d = M5.Display;
  const int S = 600, o = S / 2;
  M5Canvas c(&d); c.setPsram(true); c.createSprite(S, S); c.fillSprite(bg);
  // Gehäuse (Stahl) und cremefarbenes Zifferblatt
  c.fillCircle(o, o, 292, W_CASE_D); c.fillCircle(o, o, 286, W_CASE); c.fillCircle(o, o, 270, W_CASE_D); c.fillCircle(o, o, 266, W_DIAL);
  // feines Guilloché-Muster in der Mitte
  for (int r = 30; r < 150; r += 10) c.drawCircle(o, o, r, W_GUIL);
  // Eisenbahn-Minuterie
  c.drawCircle(o, o, 238, W_INK); c.drawCircle(o, o, 224, W_INK);
  for (int m = 0; m < 60; m++) { float a = (m * 6 - 90) * DEG_TO_RAD; c.drawLine(o + (int)(cosf(a) * 224), o + (int)(sinf(a) * 224), o + (int)(cosf(a) * 238), o + (int)(sinf(a) * 238), W_INK); }
  // römische Ziffern
  c.setFont(&fonts::FreeSerif24pt7b); c.setTextDatum(middle_center); c.setTextColor(W_INK, W_DIAL);
  for (int h = 1; h <= 12; h++) { float a = (h * 30 - 90) * DEG_TO_RAD; c.drawString(fyf::roman12(h), o + (int)(cosf(a) * 180), o + (int)(sinf(a) * 180)); }
  // Datum über der VI
  char ds[24]; snprintf(ds, sizeof ds, "%s %d", WD_SHORT[t.wd], t.d);
  c.setFont(&fonts::FreeSerif12pt7b); c.setTextColor(W_INK, W_DIAL); c.drawString(ds, o, o + 100);
  // gebläute Schwertzeiger
  handPoly(c, o, o, fyf::handHour(t.h, t.mi), 135, 11, 26, W_BLUE);
  handPoly(c, o, o, fyf::handMin(t.mi, t.s), 205, 9, 30, W_BLUE);
  float as = (fyf::handSec(t.s) - 90) * DEG_TO_RAD;
  c.drawLine(o - (int)(cosf(as) * 40), o - (int)(sinf(as) * 40), o + (int)(cosf(as) * 222), o + (int)(sinf(as) * 222), W_BLUE);
  c.fillCircle(o, o, 10, W_BLUE); c.fillCircle(o, o, 4, W_CASE);
  c.pushSprite(px, py); c.deleteSprite();
}
static void drawCalendar(const fyf::DT& t) {
  auto& d = M5.Display;
  int X = 670, Y = 105, Wd = 590, cell = 79;
  d.fillRoundRect(X, Y, Wd, 560, 18, W_DIAL); d.drawRoundRect(X, Y, Wd, 560, 18, W_CASE);
  char hd[32]; snprintf(hd, sizeof hd, "%s %d", MO_NAME[calM - 1], calY);
  d.setFont(&fonts::FreeSerif24pt7b); d.setTextDatum(middle_center); d.setTextColor(W_INK, W_DIAL); d.drawString(hd, X + Wd / 2, Y + 45);
  d.setFont(&fonts::FreeSerif12pt7b);
  for (int i = 0; i < 7; i++) { d.setTextColor(i >= 5 ? W_BLUE : C_MUTED, W_DIAL); d.drawString(WD_SHORT[i], X + 18 + cell / 2 + i * cell, Y + 102); }
  d.drawFastHLine(X + 18, Y + 122, Wd - 36, W_CASE);
  int first = fyf::weekdayMon0(calY, calM, 1), dim = fyf::daysInMonth(calY, calM);
  d.setFont(&fonts::FreeSerif18pt7b);
  for (int day = 1; day <= dim; day++) {
    int idx = first + day - 1, cx = X + 18 + cell / 2 + (idx % 7) * cell, cy = Y + 160 + (idx / 7) * 64;
    bool today = calY == t.y && calM == t.mo && day == t.d;
    if (today) { d.fillCircle(cx, cy, 27, W_BLUE); d.setTextColor(W_DIAL, W_BLUE); } else d.setTextColor((idx % 7) >= 5 ? W_BLUE : W_INK, W_DIAL);
    char s[4]; snprintf(s, sizeof s, "%d", day); d.drawString(s, cx, cy);
  }
}
static void drawClock() {
  auto& d = M5.Display; d.fillScreen(C_BG); nBtns = 0;
  drawHeader("Uhr", true);
  fyf::DT t = nowDT(); if (!calY) { calY = t.y; calM = t.mo; }
  drawCalendar(t);
  addBtn(684, 118, 64, 64, "<", 1000, W_DIAL, W_INK); addBtn(1182, 118, 64, 64, ">", 1001, W_DIAL, W_INK);
  addBtn(670, 675, 590, 40, "Heute", 1002, C_BG, W_BLUE);
  drawAllBtns();
  lastSec = -1;
}

// ================= EINSTELLUNGEN =================
static bool confirmNew = false;
static void settingsRow(int y, const char* label, const char* value) {
  auto& d = M5.Display; int W = d.width();
  d.fillRoundRect(20, y, W - 40, 88, 16, C_CARD); d.drawRoundRect(20, y, W - 40, 88, 16, C_LINE);
  d.setFont(&fonts::FreeSansBold18pt7b); d.setTextDatum(middle_left); d.setTextColor(C_TEXT, C_CARD); d.drawString(label, 48, y + 44);
  d.setFont(&fonts::FreeSans18pt7b); d.setTextColor(C_MUTED, C_CARD); d.drawString(value, 400, y + 44);
}
static void drawSettings() {
  auto& d = M5.Display; d.fillScreen(C_BG); nBtns = 0;
  drawHeader("Einstellungen", true);
  int W = d.width();
  char b[16]; snprintf(b, sizeof b, "%d %%", bright * 100 / 255);
  settingsRow(102, "Helligkeit", b); addBtn(W - 300, 114, 120, 64, "-", 1100); addBtn(W - 165, 114, 120, 64, "+", 1101);
  settingsRow(198, "Ton", sound ? "an" : "aus"); addBtn(W - 300, 210, 255, 64, sound ? "ausschalten" : "einschalten", 1102);
  settingsRow(294, "Winkelrichtung", invertAngle ? "umgekehrt" : "normal"); addBtn(W - 300, 306, 255, 64, "umkehren", 1103);
  fyf::DT t = nowDT(); char ts[48]; snprintf(ts, sizeof ts, "%02d.%02d.%04d %02d:%02d%s", t.d, t.mo, t.y, t.h, t.mi, rtcOk ? "" : " (ohne RTC)");
  settingsRow(390, "Uhr", ts); addBtn(W - 300, 402, 255, 64, "stellen", 1104);
  char sv[40]; if (saverMin) snprintf(sv, sizeof sv, "Uhr nach %d Min. ohne Beruehrung", saverMin); else snprintf(sv, sizeof sv, "aus");
  settingsRow(486, "Bildschirmschoner", sv); addBtn(W - 300, 498, 255, 64, "aendern", 1106);
  settingsRow(582, "Neues Fitting", "loescht Werte, Ablauf, Notizen");
  addBtn(W - 300, 594, 255, 64, confirmNew ? "Wirklich?" : "Neu", 1105, confirmNew ? C_WARN : C_WARN_L, confirmNew ? 0xFFFF : C_WARN);
  drawAllBtns();
  d.setFont(&fonts::FreeSans12pt7b); d.setTextDatum(bottom_left); d.setTextColor(C_MUTED, C_BG);
  char inf[96]; snprintf(inf, sizeof inf, "FYF Station v%s (Beta) - Winkelmesser-Genauigkeit ungeprueft - Speicher %s", VERSION, LittleFS.totalBytes() ? "ok" : "fehlt");
  d.drawString(inf, 24, d.height() - 6);
}
static fyf::DT edit;
static void drawSetClock() {
  auto& d = M5.Display; d.fillScreen(C_BG); nBtns = 0;
  drawHeader("Uhr stellen", true);
  const char* lab[5] = {"Tag", "Monat", "Jahr", "Stunde", "Minute"};
  int v[5] = {edit.d, edit.mo, edit.y, edit.h, edit.mi};
  int W = d.width(), cw = (W - 6 * 20) / 5;
  for (int i = 0; i < 5; i++) {
    int x = 20 + i * (cw + 20);
    d.fillRoundRect(x, 110, cw, 380, 18, C_CARD); d.drawRoundRect(x, 110, cw, 380, 18, C_LINE);
    d.setFont(&fonts::FreeSans18pt7b); d.setTextDatum(middle_center); d.setTextColor(C_MUTED, C_CARD); d.drawString(lab[i], x + cw / 2, 140);
    char s[8]; snprintf(s, sizeof s, i == 2 ? "%04d" : "%02d", v[i]);
    d.setFont(&fonts::FreeSansBold24pt7b); d.setTextSize(1.6f); d.setTextColor(C_TEXT, C_CARD); d.drawString(s, x + cw / 2, 300); d.setTextSize(1);
    addBtn(x + 14, 170, cw - 28, 80, "+", 1200 + i * 2); addBtn(x + 14, 395, cw - 28, 80, "-", 1201 + i * 2);
  }
  addBtn(20, d.height() - 120, W - 40, 100, "Speichern", 1210, C_ACC, 0xFFFF);
  drawAllBtns(&fonts::FreeSansBold24pt7b);
}
static void editStep(int f, int dir) {
  if (f == 0) { int m = fyf::daysInMonth(edit.y, edit.mo); edit.d = (edit.d - 1 + dir + m) % m + 1; }
  if (f == 1) { edit.mo = (edit.mo - 1 + dir + 12) % 12 + 1; }
  if (f == 2) { edit.y = constrain(edit.y + dir, 2024, 2099); }
  if (f == 3) { edit.h = (edit.h + dir + 24) % 24; }
  if (f == 4) { edit.mi = (edit.mi + dir + 60) % 60; }
  int m = fyf::daysInMonth(edit.y, edit.mo); if (edit.d > m) edit.d = m;
  edit.wd = fyf::weekdayMon0(edit.y, edit.mo, edit.d);
}

static void go(Screen s);
// ================= NACHSCHLAGEN (Werkstatt) =================
// Typische Werte als Orientierung. Die Angabe auf dem Bauteil bzw. vom Hersteller hat immer Vorrang.
static int infoTab = 0;
static const char* INFO_T[2][10][2] = {
  {{"Vorbau: Lenkerklemmung", "4-6 Nm (ueber Kreuz)"}, {"Vorbau: Gabelschaft-Klemmung", "5-6 Nm"}, {"Sattelstuetze (Carbon)", "5-7 Nm + Montagepaste"},
   {"Sattelgestell-Klemmung", "8-15 Nm, je nach Stuetze"}, {"Pedale", "35-40 Nm"}, {"Kurbel (Shimano HT II, Klemmschr.)", "12-14 Nm"},
   {"Cleat-Schrauben", "5-6 Nm"}, {"Schalt-/Bremsgriff am Lenker", "6-8 Nm"}, {"Flaschenhalter", "2-3 Nm"}, {"Steuersatz-Deckel", "nur Spiel einstellen"}},
  {{"Cleat laengs: Start", "Pedalachse unter/knapp hinter Grosszehengelenk"}, {"Cleat Rotation: Start", "Fuss natuerlich, Ferse leicht innen"},
   {"Cleat-Spiel (Float)", "Shimano gelb 6 Grad, rot 0 Grad"}, {"Sattel: Neigung Start", "waagerecht bis -2 Grad"},
   {"Kniewinkel unten (statisch)", "ca. 25-35 Grad Beugung"}, {"Kniewinkel unten (Video)", "ca. 140-150 Grad Streckung"},
   {"Sattelhoehe aendern", "max. 5 mm pro Schritt"}, {"Mindesteinstecktiefe", "Markierung Stuetze + Rahmen beachten"},
   {"Carbon-Teile", "immer Drehmomentschluessel"}, {"Nach dem Fitting", "alle Schrauben nachpruefen"}}};
static void drawInfo() {
  auto& d = M5.Display; d.fillScreen(C_BG); nBtns = 0;
  drawHeader("Nachschlagen", true);
  addBtn(420, 15, 230, 60, "Drehmomente", 1750, infoTab == 0 ? C_ACC : C_BG, infoTab == 0 ? 0xFFFF : C_TEXT);
  addBtn(660, 15, 230, 60, "Einstellung", 1751, infoTab == 1 ? C_ACC : C_BG, infoTab == 1 ? 0xFFFF : C_TEXT);
  drawAllBtns();
  int W = d.width();
  for (int i = 0; i < 10; i++) {
    int y = 102 + i * 54; uint16_t bg = i % 2 ? C_BG : C_CARD;
    d.fillRect(20, y, W - 40, 54, bg);
    d.setFont(&fonts::FreeSans18pt7b); d.setTextDatum(middle_left); d.setTextColor(C_TEXT, bg); d.drawString(INFO_T[infoTab][i][0], 40, y + 27);
    d.setFont(&fonts::FreeSansBold18pt7b); d.setTextDatum(middle_right); d.drawString(INFO_T[infoTab][i][1], W - 40, y + 27);
  }
  d.setFont(&fonts::FreeSans12pt7b); d.setTextDatum(bottom_left); d.setTextColor(C_WARN, C_BG);
  d.drawString("Typische Werte. Angabe auf dem Bauteil / vom Hersteller hat immer Vorrang.", 24, d.height() - 8);
}

// ================= MINI-SPIEL „Rad-Sprung“ =================
// Antippen = springen (2x = Doppelsprung). Hütchen und Baumstämme überspringen, Münzen sammeln. Rekord bleibt gespeichert.
// Schnell gezeichnet: Hintergrund einmal, pro Bild nur kleine Bereiche (Rad, Hindernisse, Straße, Punkte).
static const uint16_t G_SKY = 0xD6FF, G_GROUND = 0x8C51, G_EDGE = 0x4A69;
static const int GTOP = 100, GGY = 620, GBX = 220;          // Spielfeld oben, Boden (Bildschirm-y), Rad-x
static M5Canvas *gBike = nullptr, *gHud = nullptr, *gObjC[3] = {nullptr, nullptr, nullptr};
static GObj gObj[6]; static float gY = 0, gVy = 0, gSpeed = 0, gDist = 0, gNext = 0, gWheel = 0;
static int gJumps = 0, gCoins = 0, gBest = 0, gLastScore = -1; static bool gOver = false, gStarted = false, gOverShown = false, gMsgCleared = false;
static uint32_t gLastT = 0, gOverAt = 0;
static const int BW = 300, BH = 420, BBOT = 90;             // Rad-Leinwand, Rand unter dem Boden
static const int OW[3] = {44, 110, 34}, OH[3] = {62, 40, 34}, OTRAIL = 80;
static int gScore() { return (int)(gDist / 10) + gCoins * 25; }
static void gameBackground() {
  auto& d = M5.Display;
  d.fillRect(0, GTOP, d.width(), GGY - GTOP, G_SKY);
  d.fillCircle(700, 240, 40, 0xFF60);                                           // Sonne
  for (int k = 0; k < 3; k++) { int cx = 840 + k * 150, cy = 220 + (k % 2) * 30; d.fillCircle(cx, cy, 22, 0xFFFF); d.fillCircle(cx + 26, cy - 8, 28, 0xFFFF); d.fillCircle(cx + 54, cy, 20, 0xFFFF); }
  d.fillRect(0, GGY, d.width(), d.height() - GGY, G_GROUND); d.fillRect(0, GGY, d.width(), 8, G_EDGE);
  gLastScore = -1;
}
static void gameReset() {
  for (auto& o : gObj) o.on = false;
  gY = 0; gVy = 0; gSpeed = 8; gDist = 0; gNext = 600; gJumps = 0; gCoins = 0; gOver = false; gOverShown = false; gStarted = false; gMsgCleared = false; gLastT = millis(); gLastScore = -1;
}
static int objTop(const GObj& o) { return o.type == 2 ? GGY - o.h - o.w - 4 : GGY - o.h - 4; }
static int objHgt(const GObj& o) { return o.type == 2 ? o.w + 8 : o.h + 4; }
static void gameEnter() {
  if (!gBike) { gBike = new M5Canvas(&M5.Display); gBike->setPsram(true); gBike->createSprite(BW, BH); }
  if (!gHud) { gHud = new M5Canvas(&M5.Display); gHud->setPsram(true); gHud->createSprite(440, 60); }
  for (int t = 0; t < 3; t++) if (!gObjC[t]) { gObjC[t] = new M5Canvas(&M5.Display); gObjC[t]->setPsram(true); gObjC[t]->createSprite(OW[t] + OTRAIL, (t == 2 ? OW[t] + 8 : OH[t] + 4)); }
  prefs.begin("fyf", true); gBest = prefs.getInt("gbest", 0); prefs.end();
  gameReset();
}
static void gameJump() {
  if (gOver) { if (millis() - gOverAt > 700) { gameReset(); gameBackground(); } return; }
  gStarted = true;
  if (gJumps < 2) { gVy = gJumps ? 17.5f : 21.0f; gJumps++; beep(gJumps == 1 ? 1900 : 2400, 25); }
}
static void gameSpawn() {
  for (auto& o : gObj) if (!o.on) {
    int r = random(100), t = r < 40 ? 0 : r < 70 ? 1 : 2;
    o = {(float)M5.Display.width(), OW[t], t == 2 ? 150 + (int)random(120) : OH[t], t, true};
    break;
  }
  gNext = 320 + random(380) + gSpeed * 14;
}
// Hindernis in eine Leinwand zeichnen. (x, gy) = linke Kante und Boden in Leinwand-Koordinaten
static void drawObjAt(M5Canvas& c, const GObj& o, int x, int gy) {
  if (o.type == 0) { c.fillTriangle(x, gy, x + o.w / 2, gy - o.h, x + o.w, gy, C_ACC); c.fillRect(x + 8, gy - 30, o.w - 16, 8, 0xFFFF); }
  else if (o.type == 1) { c.fillRoundRect(x, gy - o.h, o.w, o.h, 18, 0x8A22); c.drawCircle(x + o.w - 18, gy - o.h / 2, 12, 0x5100); }
  else { int cy = gy - o.h - o.w / 2; c.fillCircle(x + o.w / 2, cy, o.w / 2, 0xFEA0); c.drawCircle(x + o.w / 2, cy, o.w / 2 - 5, 0xC400); }
}
// Aero-Rennrad mit Fahrer in Aero-Haltung (eigenes Design, ohne Marke). x = Hinterrad-Mitte, y = Boden (Leinwand-Koordinaten)
static void thickLine(M5Canvas& c, int x0, int y0, int x1, int y1, int w, uint16_t col) {
  for (int t = -w / 2; t <= w / 2; t++) { c.drawLine(x0, y0 + t, x1, y1 + t, col); c.drawLine(x0 + t, y0, x1 + t, y1, col); }
}
static void drawBike(M5Canvas& c, int x, int y) {
  const uint16_t FR = 0x2124, AC = C_ACC, TY = 0x0000, RIM = 0x39E7, SK = 0x2A69, SKIN = 0xFE59;
  int R = 36, wy = y - R, wb = 120;
  // Laufräder mit hohen Aero-Felgen
  for (int k = 0; k < 2; k++) {
    int cx = x + k * wb;
    c.fillCircle(cx, wy, R, TY); c.fillCircle(cx, wy, R - 3, RIM); c.fillCircle(cx, wy, R - 13, G_SKY);
    for (int sp = 0; sp < 6; sp++) { float a = gWheel + sp * 1.047f; c.drawLine(cx, wy, cx + (int)(cosf(a) * (R - 13)), wy + (int)(sinf(a) * (R - 13)), 0x7BEF); }
    c.fillCircle(cx, wy, 4, FR);
  }
  int bbx = x + 55, bby = wy + 4;            // Tretlager
  int stx = x + 40, sty = wy - 62;           // Sitzrohr oben
  int htx = x + 98, hty = wy - 58;           // Steuerrohr oben
  int hbx = x + 104, hby = wy - 34;          // Steuerrohr unten
  int ssx = x + 46, ssy = wy - 34;           // tief angesetzte Sitzstreben
  thickLine(c, x, wy, bbx, bby, 4, FR);      // Kettenstrebe
  thickLine(c, x, wy, ssx, ssy, 4, FR);      // Sitzstrebe (tief)
  thickLine(c, bbx, bby, stx, sty, 7, FR);   // Sitzrohr (Aero)
  thickLine(c, stx, sty, htx, hty, 5, FR);   // Oberrohr
  thickLine(c, bbx, bby, hbx, hby, 9, FR);   // Unterrohr (dick)
  thickLine(c, htx, hty, hbx, hby, 8, FR);   // Steuerrohr
  thickLine(c, hbx, hby, x + wb, wy, 6, FR); // Gabel
  thickLine(c, bbx + 10, bby - 8, hbx - 12, hby + 5, 3, AC);   // Akzent-Streifen
  // Sattelstütze, Sattel, Cockpit mit Rennlenker
  thickLine(c, stx, sty, stx - 3, sty - 16, 5, FR); c.fillRoundRect(stx - 18, sty - 22, 32, 6, 3, TY);
  thickLine(c, htx, hty, htx + 16, hty - 3, 5, FR);
  int bx = htx + 16, by = hty - 3;
  thickLine(c, bx, by, bx + 8, by + 4, 3, TY); thickLine(c, bx + 8, by + 4, bx + 8, by + 18, 3, TY); thickLine(c, bx + 8, by + 18, bx, by + 22, 3, TY);
  // Kurbel und Pedale
  float a = gWheel * 0.5f; int px = bbx + (int)(cosf(a) * 20), py = bby + (int)(sinf(a) * 20), qx = bbx - (int)(cosf(a) * 20), qy = bby - (int)(sinf(a) * 20);
  thickLine(c, bbx, bby, px, py, 3, 0x7BEF); c.fillCircle(bbx, bby, 8, FR);
  // Fahrer in Aero-Haltung (Knie per Beinlänge berechnet, damit die Beine echt treten)
  int hx = stx - 2, hipY = sty - 26, shx = htx + 2, shy = hty - 40;
  auto knee = [&](int px2, int py2, int& kx, int& ky) {
    float L1 = 50, L2 = 52, dx = px2 - hx, dy = py2 - hipY, d = sqrtf(dx * dx + dy * dy); if (d > L1 + L2 - 1) d = L1 + L2 - 1; if (d < 1) d = 1;
    float aa = (L1 * L1 - L2 * L2 + d * d) / (2 * d), hh = sqrtf(fmaxf(0, L1 * L1 - aa * aa)), ux = dx / d, uy = dy / d;
    float mx = hx + aa * ux, my = hipY + aa * uy; kx = (int)(mx + hh * -uy * -1); ky = (int)(my + hh * ux * -1);
    if (kx < (int)(mx - hh * -uy * -1)) { kx = (int)(mx - hh * -uy * -1); ky = (int)(my - hh * ux * -1); }
  };
  int k2x, k2y; knee(qx, qy, k2x, k2y);
  thickLine(c, hx, hipY, k2x, k2y, 7, 0x18C3); thickLine(c, k2x, k2y, qx, qy, 5, 0x18C3); c.fillRect(qx - 6, qy - 2, 14, 5, TY);   // hinteres Bein
  thickLine(c, hx, hipY, shx, shy, 9, SK);                                                  // Rumpf flach
  thickLine(c, shx, shy, bx + 4, by - 2, 4, SK);                                            // Arm zum Lenker
  int kx, ky; knee(px, py, kx, ky);
  thickLine(c, hx, hipY, kx, ky, 7, SK); thickLine(c, kx, ky, px, py, 5, SK);                // vorderes Bein
  c.fillRect(px - 6, py - 2, 14, 5, TY);                                                    // Schuh
  int hdx = shx + 12, hdy = shy - 14;
  c.fillCircle(hdx, hdy + 4, 10, SKIN);
  c.fillCircle(hdx, hdy, 13, AC); c.fillTriangle(hdx - 10, hdy - 8, hdx - 30, hdy + 2, hdx - 6, hdy + 8, AC);   // Aero-Helm
  c.fillRect(hdx + 4, hdy + 1, 10, 4, TY);                                                  // Brille
}
static void gameDrawObj(const GObj& o) {
  M5Canvas& c = *gObjC[o.type]; int top = objTop(o);
  c.fillSprite(G_SKY); drawObjAt(c, o, 0, GGY - top);                // rechts davon 80 px Himmel: löscht die alte Stelle
  c.pushSprite(&M5.Display, (int)o.x, top);
}
static void gameClearObj(const GObj& o) { M5.Display.fillRect((int)o.x - 4, objTop(o), o.w + OTRAIL + 8, objHgt(o), G_SKY); }
static void gameHud() {
  int sc = gScore(); if (sc == gLastScore) return; gLastScore = sc;
  M5Canvas& c = *gHud; c.fillSprite(G_SKY); char s[48];
  c.setFont(&fonts::FreeSansBold24pt7b); c.setTextDatum(middle_left); c.setTextColor(C_TEXT, G_SKY);
  snprintf(s, sizeof s, "%d", sc); c.drawString(s, 0, 30);
  c.setFont(&fonts::FreeSans12pt7b); c.setTextDatum(middle_right); c.setTextColor(C_MUTED, G_SKY);
  snprintf(s, sizeof s, "Rekord %d  Muenzen %d", gBest, gCoins); c.drawString(s, 438, 32);
  c.pushSprite(&M5.Display, M5.Display.width() - 470, GTOP + 12);
}
static void gameMessage(const char* a, const char* b, uint16_t col) {
  auto& d = M5.Display; int cx = d.width() / 2 + 120;
  d.fillRoundRect(cx - 300, GTOP + 300, 600, 150, 22, 0xFFFF);
  d.setFont(&fonts::FreeSansBold24pt7b); d.setTextDatum(middle_center); d.setTextColor(col, 0xFFFF); d.drawString(a, cx, GTOP + 345);
  d.setFont(&fonts::FreeSans18pt7b); d.setTextColor(C_MUTED, 0xFFFF); d.drawString(b, cx, GTOP + 405);
}
static void gameDrawBike() {
  M5Canvas& c = *gBike; c.fillSprite(G_SKY);
  int top = GGY - (int)gY - (BH - BBOT); if (top < GTOP) top = GTOP;
  int gIn = GGY - top, left = GBX - 70;
  if (gIn < BH) { c.fillRect(0, gIn, BW, BH - gIn, G_GROUND); c.fillRect(0, gIn, BW, 8, G_EDGE); }
  for (auto& o : gObj) if (o.on && o.x < left + BW && o.x + o.w > left) drawObjAt(c, o, (int)o.x - left, gIn);
  drawBike(c, 70, GGY - (int)gY - top);
  c.pushSprite(&M5.Display, left, top);
}
static void gameTick() {
  if (!gBike) return;
  uint32_t now = millis(); if (now - gLastT < 16) return;
  float dt = (now - gLastT) / 16.7f; if (dt > 4) dt = 4; gLastT = now;
  auto& d = M5.Display;
  if (!gStarted) {
    static uint32_t shown = 0; if (now - shown > 1000) { shown = now; gameDrawBike(); gameHud(); gameMessage("Antippen zum Losfahren", "Tippen = springen, 2x = Doppelsprung", C_TEXT); }
  } else if (!gOver) {
    if (!gMsgCleared) { int cx = d.width() / 2 + 120; d.fillRect(cx - 300, GTOP + 300, 600, 150, G_SKY); gMsgCleared = true; }
    gSpeed = fminf(19.0f, gSpeed + 0.003f * dt); gDist += gSpeed * dt; gWheel += gSpeed * 0.03f * dt;
    gVy -= 1.15f * dt; gY += gVy * dt; if (gY <= 0) { gY = 0; gVy = 0; gJumps = 0; }
    gNext -= gSpeed * dt; if (gNext <= 0) gameSpawn();
    int bx0 = GBX - 30, bx1 = GBX + 140, by1 = GGY - (int)gY, by0 = by1 - 150;
    for (auto& o : gObj) {
      if (!o.on) continue;
      o.x -= gSpeed * dt;
      if (o.x + o.w < -10) { gameClearObj(o); o.on = false; continue; }
      int ox0 = (int)o.x + 6, ox1 = (int)o.x + o.w - 6, oy1 = o.type == 2 ? GGY - o.h : GGY, oy0 = o.type == 2 ? oy1 - o.w : GGY - o.h + 6;
      if (ox1 > bx0 + 20 && ox0 < bx1 - 10 && oy1 > by0 && oy0 < by1 - 4) {
        if (o.type == 2) { gameClearObj(o); o.on = false; gCoins++; beep(3000, 30); }
        else { gOver = true; gOverAt = now; beep(500, 400); if (gScore() > gBest) { gBest = gScore(); prefs.begin("fyf", false); prefs.putInt("gbest", gBest); prefs.end(); } }
      }
    }
    // Hindernisse
    for (auto& o : gObj) if (o.on) gameDrawObj(o);
    // Rad (mit Hindernissen, die gerade darunter sind, damit nichts verschwindet)
    gameDrawBike();
    // Straße (Mittellinie läuft mit)
    int dash = (int)gDist % 140;
    d.fillRect(0, GGY + 40, d.width(), 10, G_GROUND);
    for (int x = -dash; x < d.width(); x += 140) { int x0 = x < 0 ? 0 : x, w = x < 0 ? 70 + x : 70; if (w > 0) d.fillRect(x0, GGY + 40, w, 10, 0xFFFF); }
    gameHud();
  }
  if (gOver && !gOverShown) {
    gOverShown = true; gameHud(); char s[48];
    snprintf(s, sizeof s, "%d Punkte%s - Antippen", gScore(), gScore() >= gBest && gScore() > 0 ? ", Rekord!" : "");
    gameMessage("Sturz!", s, C_WARN);
  }
}
static void drawGame() { M5.Display.fillScreen(C_BG); nBtns = 0; drawHeader("Rad-Sprung", true); gameBackground(); gLastScore = -1; gLastT = millis(); }

// ================= WARTE-HINWEIS =================
static void waitScreen(const char* t) {
  auto& d = M5.Display;
  d.fillRoundRect(340, 270, 600, 180, 24, C_CARD); d.drawRoundRect(340, 270, 600, 180, 24, C_ACC);
  d.setFont(&fonts::FreeSansBold18pt7b); d.setTextDatum(middle_center); d.setTextColor(C_TEXT, C_CARD); d.drawString(t, 640, 345);
  d.setFont(&fonts::FreeSans12pt7b); d.setTextColor(C_MUTED, C_CARD); d.drawString("bitte warten ...", 640, 395);
}

// ================= BILDSCHIRMTASTATUR =================
static KbTarget kbTarget; static char kbBuf[66] = ""; static int kbCap = 40; static char kbTitle[48] = "";
static Screen kbReturn = HOME; static bool kbShift = true, kbSym = false;
static const char* KB_ROWS[2][4] = {{"1234567890", "QWERTZUIOP", "ASDFGHJKL-", "YXCVBNM.,/"},
                                    {"1234567890", "!@#$%&*()+", "=?_:;'\"<>[", "]{}~^|\\`.,"}};
static char kbLbl[40][2];
static void kbDone();
static void openKb(KbTarget t, const char* title, const char* init, int cap, Screen ret) {
  kbTarget = t; snprintf(kbTitle, sizeof kbTitle, "%s", title); fyf::asciiFold(init ? init : "", kbBuf, sizeof kbBuf);
  kbCap = cap < (int)sizeof kbBuf ? cap : (int)sizeof kbBuf; kbBuf[kbCap - 1] = 0; kbReturn = ret;
  kbShift = (t == KB_NAME || t == KB_BIKE || t == KB_PAIR) && !kbBuf[0]; kbSym = false;
  screen = KEYB; needFull = true;
}
static void drawKbText() {
  auto& d = M5.Display; int W = d.width();
  d.fillRoundRect(20, 102, W - 40, 84, 14, C_CARD); d.drawRoundRect(20, 102, W - 40, 84, 14, C_ACC);
  d.setFont(&fonts::FreeSansBold24pt7b); d.setTextDatum(middle_left); d.setTextColor(C_TEXT, C_CARD);
  char s[72]; snprintf(s, sizeof s, "%s_", kbBuf); d.drawString(s, 44, 146);
}
static void drawKeyb() {
  auto& d = M5.Display; d.fillScreen(C_BG); nBtns = 0;
  drawHeader(kbTitle, true);
  int W = d.width(), kw = (W - 40 - 9 * 10) / 10, kh = 88;
  for (int r = 0; r < 4; r++) for (int c = 0; c < 10; c++) {
    int i = r * 10 + c; char ch = KB_ROWS[kbSym][r][c];
    if (!kbSym && !kbShift && ch >= 'A' && ch <= 'Z') ch = (char)tolower(ch);
    kbLbl[i][0] = ch; kbLbl[i][1] = 0;
    addBtn(20 + c * (kw + 10), 200 + r * (kh + 10), kw, kh, kbLbl[i], 2000 + i);
  }
  int y = 200 + 4 * (kh + 10);
  addBtn(20, y, 180, 112 - 12, kbShift ? "abc" : "ABC", 2040, kbShift ? C_ACC_L : C_CARD);
  addBtn(210, y, 160, 100, kbSym ? "ABC" : "#+=", 2041);
  addBtn(380, y, 420, 100, "Leerzeichen", 2042);
  addBtn(810, y, 210, 100, "Loeschen", 2043, C_WARN_L, C_WARN);
  addBtn(1030, y, W - 1050, 100, "OK", 2044, C_ACC, 0xFFFF);
  drawAllBtns();
  drawKbText();
}

// ================= KUNDEN (Dateien /k/<nr>.txt) =================
static bool fsOk = false;
struct CustIdx { int id; char name[40]; };
static CustIdx custs[60]; static int nCust = 0;
static fyf::Customer cur; static int curId = 0;           // im Detail angezeigter Kunde
static fyf::Customer edc; static int editId = 0;          // in Bearbeitung (0 = neu)
static int custPage = 0; static bool confirmDel = false, confirmFollow = false;
static uint32_t lastCustSync = 0; static bool custSynced = false; static char custSyncMsg[120] = "";
struct FitRec { char date[20]; float b[NF], a[NF]; };
static FitRec fits[6]; static int nHist = 0;              // letzte Fittings von cur
static void custPath(char* p, int n, int id) { snprintf(p, n, "/k/%d.txt", id); }
static bool custLoad(int id, fyf::Customer& c, bool withHist) {
  if (!fsOk) return false;
  char p[24]; custPath(p, sizeof p, id); if (!LittleFS.exists(p)) return false;
  File f = LittleFS.open(p, "r"); if (!f) return false;
  String l = f.readStringUntil('\n'); bool ok = fyf::custParse(l.c_str(), c);
  if (withHist) {
    nHist = 0;
    while (f.available()) {
      String h = f.readStringUntil('\n'); FitRec r;
      if (fyf::fitParse(h.c_str(), r.date, sizeof r.date, r.b, r.a)) { if (nHist == 6) { memmove(fits, fits + 1, sizeof(FitRec) * 5); nHist = 5; } fits[nHist++] = r; }
    }
  }
  f.close(); return ok;
}
static bool custSave(int id, const fyf::Customer& c) {
  if (!fsOk || id <= 0) return false;
  char p[24]; custPath(p, sizeof p, id); String rest;
  if (LittleFS.exists(p)) { File f = LittleFS.open(p, "r"); if (f) { f.readStringUntil('\n'); rest = f.readString(); f.close(); } }
  char h[200]; fyf::custHeader(c, h, sizeof h);
  File f = LittleFS.open(p, "w"); if (!f) return false;
  f.print(h); f.print(rest); f.close(); return true;
}
static void nowStamp(char* s, int n) { fyf::DT t = nowDT(); snprintf(s, n, "%02d.%02d.%04d %02d:%02d", t.d, t.mo, t.y, t.h, t.mi); }
static bool custAddFit(int id) {
  if (!fsOk || id <= 0) return false;
  char p[24]; custPath(p, sizeof p, id); if (!LittleFS.exists(p)) return false;
  File f = LittleFS.open(p, "a"); if (!f) return false;
  char date[20], line[320]; nowStamp(date, sizeof date); fyf::fitLine(date, vals[0], vals[1], line, sizeof line);
  f.print(line); f.close(); return true;
}
static void custScan() {
  nCust = 0;
  for (int id = 1; id <= 99 && nCust < 60; id++) {
    fyf::Customer c; if (!custLoad(id, c, false)) continue;
    custs[nCust].id = id; snprintf(custs[nCust].name, sizeof custs[nCust].name, "%s", c.name); nCust++;
  }
  for (int i = 1; i < nCust; i++) { CustIdx k = custs[i]; int j = i - 1; while (j >= 0 && strcasecmp(custs[j].name, k.name) > 0) { custs[j + 1] = custs[j]; j--; } custs[j + 1] = k; }
  bool found = false; for (int i = 0; i < nCust; i++) if (custs[i].id == activeCust) found = true;
  if (!found && activeCust) { activeCust = 0; saveSettings(); }
}
static int custNewId() { for (int id = 1; id <= 99; id++) { char p[24]; custPath(p, sizeof p, id); if (!LittleFS.exists(p)) return id; } return 0; }
static const char* activeName() { for (int i = 0; i < nCust; i++) if (custs[i].id == activeCust) return custs[i].name; return ""; }
static void fmtNum(char* s, int n, float v, const char* unit) { if (isnan(v)) snprintf(s, n, "-"); else { fmtVal(s, n, v); strncat(s, unit, n - strlen(s) - 1); } }

static void drawCust() {
  auto& d = M5.Display; d.fillScreen(C_BG); nBtns = 0;
  drawHeader("Kunden", true);
  int W = d.width(), H = d.height(), per = 9, pages = nCust ? (nCust + per - 1) / per : 1;
  if (custPage >= pages) custPage = pages - 1;
  d.setFont(&fonts::FreeSansBold18pt7b);
  for (int k = 0; k < per; k++) {
    int i = custPage * per + k; if (i >= nCust) break;
    int y = 104 + k * 56; bool sel = custs[i].id == curId; uint16_t bg = sel ? C_ACC : C_CARD;
    d.fillRoundRect(20, y, 520, 50, 10, bg);
    if (custs[i].id == activeCust) d.fillCircle(44, y + 25, 9, sel ? 0xFFFF : C_OK);
    char f[36]; fyf::asciiFold(custs[i].name, f, sizeof f);
    d.setTextDatum(middle_left); d.setTextColor(sel ? 0xFFFF : C_TEXT, bg); d.drawString(f, 64, y + 26);
    addBtn(20, y, 520, 50, "", 1300 + i, bg, C_TEXT, false);
  }
  if (!nCust) { d.setFont(&fonts::FreeSans18pt7b); d.setTextDatum(top_left); d.setTextColor(C_MUTED, C_BG); d.drawString(fsOk ? "Noch keine Kunden." : "Speicher nicht verfuegbar.", 30, 120); }
  addBtn(20, H - 98, 125, 84, "+ Neu", 1370, C_ACC, 0xFFFF);
  addBtn(155, H - 98, 120, 84, "FYF", 1373, cloudPaired() ? C_ACC_L : C_BG, cloudPaired() ? C_ACC : C_MUTED);
  addBtn(285, H - 98, 120, 84, "<", 1371); addBtn(420, H - 98, 120, 84, ">", 1372);
  // Detail
  int X = 560, Wd = W - 580;
  d.fillRoundRect(X, 104, Wd, H - 120, 18, C_CARD); d.drawRoundRect(X, 104, Wd, H - 120, 18, C_LINE);
  if (!curId) {
    d.setFont(&fonts::FreeSans18pt7b); d.setTextDatum(top_left); d.setTextColor(C_MUTED, C_CARD);
    drawWrapped("Links einen Kunden antippen oder mit '+ Neu' anlegen. Kunden aus FYF laden: Mehr > FYF & WLAN.", X + 28, 140, Wd - 56, 40);
  } else {
    char f[40], s[96], a[24], b[24];
    fyf::asciiFold(cur.name, f, sizeof f);
    d.setFont(&fonts::FreeSansBold24pt7b); d.setTextDatum(top_left); d.setTextColor(C_TEXT, C_CARD); d.drawString(f, X + 28, 124);
    d.setFont(&fonts::FreeSans18pt7b); d.setTextColor(C_MUTED, C_CARD);
    fmtNum(a, sizeof a, cur.height, " cm"); fmtNum(b, sizeof b, cur.inseam, " cm");
    snprintf(s, sizeof s, "Groesse %s   Schrittlaenge %s", a, b); d.drawString(s, X + 28, 186);
    fyf::asciiFold(cur.bike, f, sizeof f); snprintf(s, sizeof s, "Rad: %s   %s", f[0] ? f : "-", cur.fyfId[0] ? "(mit FYF verknuepft)" : ""); d.drawString(s, X + 28, 226);
    d.setFont(&fonts::FreeSans12pt7b); d.setTextColor(C_TEXT, C_CARD); d.drawString("Letzte Fittings (Sattelhoehe vorher > nachher):", X + 28, 276);
    d.setTextColor(C_MUTED, C_CARD);
    if (!nHist) d.drawString("noch keine gespeichert", X + 28, 306);
    for (int i = 0; i < nHist && i < 4; i++) {
      const FitRec& r = fits[nHist - 1 - i]; fmtVal(a, sizeof a, r.b[0]); fmtVal(b, sizeof b, r.a[0]);
      snprintf(s, sizeof s, "%s:  %s > %s mm", r.date, a, b); d.drawString(s, X + 28, 306 + i * 30);
    }
    bool act = curId == activeCust;
    addBtn(X + 20, 438, (Wd - 60) / 2, 80, act ? "Ist aktiv" : "Als aktiv waehlen", 1380, act ? C_OK_L : C_OK, act ? C_OK : 0xFFFF);
    addBtn(X + 40 + (Wd - 60) / 2, 438, (Wd - 60) / 2, 80, "Bearbeiten", 1381);
    addBtn(X + 20, 528, (Wd - 60) / 2, 80, confirmFollow ? "Wirklich?" : "Folgefitting", 1382, confirmFollow ? C_ACC : C_CARD, confirmFollow ? 0xFFFF : C_TEXT);
    addBtn(X + 40 + (Wd - 60) / 2, 528, (Wd - 60) / 2, 80, confirmDel ? "Wirklich?" : "Loeschen", 1383, confirmDel ? C_WARN : C_WARN_L, confirmDel ? 0xFFFF : C_WARN);
    { fyf::Consent cs; bool has = consLoad(curId, cs); static char cl[48];
      if (has) snprintf(cl, sizeof cl, "Einwilligung vom %.10s", cs.date); else snprintf(cl, sizeof cl, "Einwilligung fehlt - erfassen");
      addBtn(X + 20, 618, Wd - 40, 80, cl, 1384, has ? C_OK_L : C_ACC_L, has ? C_OK : C_ACC); }
  }
  drawAllBtns();
  if (custSyncMsg[0] && !curId) { d.setFont(&fonts::FreeSans12pt7b); d.setTextDatum(bottom_left); d.setTextColor(C_MUTED, C_CARD); drawWrapped(custSyncMsg, X + 28, H - 80, Wd - 56, 28); }
}
static void drawCustEdit() {
  auto& d = M5.Display; d.fillScreen(C_BG); nBtns = 0;
  drawHeader(editId ? "Kunde bearbeiten" : "Neuer Kunde", true);
  int W = d.width(); char a[24], f[44];
  const char* lab[4] = {"Name", "Koerpergroesse", "Schrittlaenge", "Fahrrad"};
  for (int i = 0; i < 4; i++) {
    int y = 104 + i * 104; const char* v = "";
    if (i == 0) { fyf::asciiFold(edc.name, f, sizeof f); v = f[0] ? f : "(antippen)"; }
    if (i == 1) { fmtNum(a, sizeof a, edc.height, " cm"); v = a; }
    if (i == 2) { fmtNum(a, sizeof a, edc.inseam, " cm"); v = a; }
    if (i == 3) { fyf::asciiFold(edc.bike, f, sizeof f); v = f[0] ? f : "-"; }
    settingsRow(y, lab[i], v); addBtn(W - 300, y + 12, 255, 64, "aendern", 1390 + i);
  }
  addBtn(20, d.height() - 104, W - 40, 90, "Speichern", 1395, edc.name[0] ? C_ACC : C_LINE, 0xFFFF);
  drawAllBtns();
}

// ================= RECHNER =================
static int calcTab = 0; static float cInseam = 80; static int cCrankI = 5;
static float cHta = 73, cL[2] = {100, 100}, cA[2] = {-6, -6}, cS[2] = {20, 20};
static void stepRow(int x, int y, int w, const char* label, const char* val, int idMinus) {
  auto& d = M5.Display;
  d.fillRoundRect(x, y, w, 86, 14, C_CARD); d.drawRoundRect(x, y, w, 86, 14, C_LINE);
  d.setFont(&fonts::FreeSans18pt7b); d.setTextDatum(middle_left); d.setTextColor(C_MUTED, C_CARD); d.drawString(label, x + 22, y + 43);
  d.setFont(&fonts::FreeSansBold18pt7b); d.setTextDatum(middle_right); d.setTextColor(C_TEXT, C_CARD); d.drawString(val, x + w - 210, y + 43);
  addBtn(x + w - 196, y + 10, 88, 66, "-", idMinus); addBtn(x + w - 98, y + 10, 88, 66, "+", idMinus + 1);
}
static void calcEnter() {
  fyf::Customer c; if (activeCust && custLoad(activeCust, c, false) && !isnan(c.inseam)) cInseam = c.inseam;
  float cr = !isnan(vals[1][8]) ? vals[1][8] : vals[0][8];
  if (!isnan(cr)) for (int i = 0; i < fyf::NCRANK; i++) if (fabsf(fyf::CRANKS[i] - cr) < 0.3f) cCrankI = i;
}
static void drawCalc() {
  auto& d = M5.Display; d.fillScreen(C_BG); nBtns = 0;
  drawHeader("Rechner", true);
  addBtn(400, 15, 260, 60, "Sattel & Kurbel", 1500, calcTab == 0 ? C_ACC : C_BG, calcTab == 0 ? 0xFFFF : C_TEXT);
  addBtn(670, 15, 160, 60, "Vorbau", 1501, calcTab == 1 ? C_ACC : C_BG, calcTab == 1 ? 0xFFFF : C_TEXT);
  int W = d.width(), H = d.height(); char v[32], s[96];
  if (calcTab == 0) {
    fmtVal(v, sizeof v, cInseam); strcat(v, " cm"); stepRow(20, 104, 610, "Schrittlaenge", v, 1510);
    fmtVal(v, sizeof v, fyf::CRANKS[cCrankI]); strcat(v, " mm"); stepRow(20, 200, 610, "Kurbellaenge", v, 1512);
    d.fillRoundRect(20, 300, 610, H - 316, 14, C_CARD);
    d.setFont(&fonts::FreeSans12pt7b); d.setTextDatum(top_left); d.setTextColor(C_MUTED, C_CARD);
    drawWrapped("Richtwerte als Startpunkt. Die Sattelhoehe wird im Fitting nach Kniewinkel, Beweglichkeit und Beschwerden eingestellt. Gemessen: Mitte Tretlager bis Satteloberflaeche entlang Sitzrohr.", 40, 318, 570, 30);
    int X = 650, Wd = W - 670;
    d.fillRoundRect(X, 104, Wd, H - 120, 18, C_CARD); d.drawRoundRect(X, 104, Wd, H - 120, 18, C_LINE);
    float lm = fyf::saddleLemond(cInseam), hm = fyf::saddleHamley(cInseam, fyf::CRANKS[cCrankI]), lo, hi; fyf::crankRange(cInseam, lo, hi);
    d.setFont(&fonts::FreeSans18pt7b); d.setTextColor(C_MUTED, C_CARD); d.drawString("Sattelhoehe nach LeMond (0,883 x SL)", X + 26, 126);
    d.setFont(&fonts::FreeSansBold24pt7b); d.setTextColor(C_TEXT, C_CARD); fmtVal(v, sizeof v, lm); snprintf(s, sizeof s, "%s mm", v); d.drawString(s, X + 26, 162);
    d.setFont(&fonts::FreeSans18pt7b); d.setTextColor(C_MUTED, C_CARD); d.drawString("nach Hamley (1,09 x SL - Kurbel)", X + 26, 236);
    d.setFont(&fonts::FreeSansBold24pt7b); d.setTextColor(C_TEXT, C_CARD); fmtVal(v, sizeof v, hm); snprintf(s, sizeof s, "%s mm", v); d.drawString(s, X + 26, 272);
    d.setFont(&fonts::FreeSans18pt7b); d.setTextColor(C_MUTED, C_CARD); d.drawString("Kurbel-Faustregel (20-21,6 % SL)", X + 26, 346);
    char a[16], b[16]; fmtVal(a, sizeof a, lo); fmtVal(b, sizeof b, hi);
    d.setFont(&fonts::FreeSansBold24pt7b); d.setTextColor(C_TEXT, C_CARD); snprintf(s, sizeof s, lo == hi ? "%s mm" : "%s bis %s mm", a, b); d.drawString(s, X + 26, 382);
    float now = !isnan(vals[1][0]) ? vals[1][0] : vals[0][0];
    d.setFont(&fonts::FreeSans18pt7b); d.setTextColor(C_MUTED, C_CARD);
    if (!isnan(now)) { fmtVal(a, sizeof a, now); fmtVal(b, sizeof b, fyf::round1(now - lm), true); snprintf(s, sizeof s, "Gemessen: %s mm (%s zu LeMond)", a, b); d.drawString(s, X + 26, 470); }
    else d.drawString("Noch keine Sattelhoehe gemessen.", X + 26, 470);
    d.setFont(&fonts::FreeSans12pt7b); d.drawString("Schrittlaenge kommt vom aktiven Kunden, wenn eingetragen.", X + 26, H - 60);
  } else {
    fmtVal(v, sizeof v, cHta); strcat(v, " Grad"); stepRow(20, 104, W - 40, "Lenkwinkel des Rahmens", v, 1540);
    const char* col[2] = {"Jetzt", "Neu"};
    for (int k = 0; k < 2; k++) {
      int x = 20 + k * 630, base = k ? 1530 : 1520;
      d.setFont(&fonts::FreeSansBold18pt7b); d.setTextDatum(top_left); d.setTextColor(k ? C_ACC : C_TEXT, C_BG); d.drawString(col[k], x + 6, 198);
      fmtVal(v, sizeof v, cL[k]); strcat(v, " mm"); stepRow(x, 232, 610, "Vorbaulaenge", v, base);
      fmtVal(v, sizeof v, cA[k], true); strcat(v, " Grad"); stepRow(x, 326, 610, "Vorbauwinkel", v, base + 2);
      fmtVal(v, sizeof v, cS[k]); strcat(v, " mm"); stepRow(x, 420, 610, "Spacer darunter", v, base + 4);
    }
    float dx, dy; fyf::stemDelta(cHta, cL[0], cA[0], cS[0], cL[1], cA[1], cS[1], 40, dx, dy);
    d.fillRoundRect(20, 518, W - 40, H - 534, 18, C_ACC_L);
    char a[16], b[16]; fmtVal(a, sizeof a, fabsf(fyf::round1(dx))); fmtVal(b, sizeof b, fabsf(fyf::round1(dy)));
    snprintf(s, sizeof s, "Lenker: %s mm %s, %s mm %s", a, dx >= 0 ? "weiter vorn" : "weiter hinten", b, dy >= 0 ? "hoeher" : "tiefer");
    d.setFont(&fonts::FreeSansBold24pt7b); d.setTextDatum(top_left); d.setTextColor(C_TEXT, C_ACC_L); d.drawString(s, 44, 540);
    d.setFont(&fonts::FreeSans12pt7b); d.setTextColor(C_MUTED, C_ACC_L);
    d.drawString("Gemessen an der Lenkermitte. Vorbau-Klemmhoehe 40 mm angenommen. Winkel: - = abfallend.", 44, 612);
    d.drawString("Ueberhoehung und Sattel-Lenker aendern sich um etwa diese Werte.", 44, 642);
  }
  drawAllBtns();
}
static void calcStep(int id) {
  int dir = (id % 2) ? 1 : -1;
  if (id == 1510 || id == 1511) cInseam = constrain(cInseam + dir * 0.5f, 50.0f, 110.0f);
  else if (id == 1512 || id == 1513) cCrankI = constrain(cCrankI + dir, 0, fyf::NCRANK - 1);
  else if (id == 1540 || id == 1541) cHta = constrain(cHta + dir * 0.5f, 65.0f, 80.0f);
  else if (id >= 1520 && id < 1536) {
    int k = id >= 1530, f = ((id - (k ? 1530 : 1520)) / 2);
    if (f == 0) cL[k] = constrain(cL[k] + dir * 10.0f, 40.0f, 160.0f);
    if (f == 1) cA[k] = constrain(cA[k] + dir * 1.0f, -25.0f, 25.0f);
    if (f == 2) cS[k] = constrain(cS[k] + dir * 5.0f, 0.0f, 60.0f);
  }
}

// ================= STOPPUHR =================
static uint32_t swStart = 0, swAcc = 0, laps[8]; static int nLaps = 0;
static uint32_t swMs() { return swAcc + (swRun ? millis() - swStart : 0); }
static void drawStopw() {
  auto& d = M5.Display; d.fillScreen(C_BG); nBtns = 0;
  drawHeader("Stoppuhr", true);
  int W = d.width(), H = d.height();
  addBtn(20, H - 120, 330, 100, swRun ? "Stopp" : "Start", 1600, swRun ? C_WARN : C_ACC, 0xFFFF);
  addBtn(365, H - 120, 250, 100, "Runde", 1601);
  addBtn(630, H - 120, 250, 100, "Zuruecksetzen", 1602, C_WARN_L, C_WARN);
  drawAllBtns();
  d.fillRoundRect(900, 104, W - 920, H - 120, 18, C_CARD);
  d.setFont(&fonts::FreeSans18pt7b); d.setTextDatum(top_left); d.setTextColor(C_MUTED, C_CARD); d.drawString("Runden", 924, 120);
  char s[32], t[24];
  for (int i = 0; i < nLaps; i++) {
    uint32_t prev = i ? laps[i - 1] : 0; fyf::fmtStopwatch(laps[i] - prev, t, sizeof t);
    snprintf(s, sizeof s, "%d.   %s", i + 1, t); d.setTextColor(C_TEXT, C_CARD); d.drawString(s, 924, 170 + i * 56);
  }
}
static void drawStopwValue() {
  auto& d = M5.Display;
  M5Canvas c(&d); c.setPsram(true); c.createSprite(860, 400); c.fillSprite(C_BG);
  char s[24]; fyf::fmtStopwatch(swMs(), s, sizeof s);
  c.setFont(&fonts::Font7); c.setTextSize(2.2f); c.setTextDatum(middle_center); c.setTextColor(swRun ? C_TEXT : C_MUTED, C_BG);
  for (char* p = s; *p; p++) if (*p == ',') *p = '.';   // Font7 kennt kein Komma
  c.drawString(s, 430, 200);
  c.pushSprite(20, 120); c.deleteSprite();
}

// ================= CHECKLISTE =================
static const char* CHK_NAME[NCHK] = {"Rad sauber, Kette geoelt", "Reifendruck geprueft", "Rad gerade in der Rolle", "Rolle kalibriert",
                                     "Schuhe und Cleats dabei", "Radkleidung dabei", "Messwerkzeug bereit", "Winkelmesser genullt",
                                     "iPhone/Kamera geladen", "Tab5 geladen", "Einwilligung Kunde", "Drehmomentschluessel bereit"};
static void saveChk() { prefs.begin("fyf", false); prefs.putBytes("chk", chk, NCHK); prefs.end(); }
static void drawCheck() {
  auto& d = M5.Display; d.fillScreen(C_BG); nBtns = 0;
  drawHeader("Checkliste", true);
  addBtn(d.width() - 600, 15, 250, 60, "Alles neu", 1710, C_WARN_L, C_WARN); drawBtn(btns[nBtns - 1]);
  int W = d.width(), g = 18, bw = (W - 3 * g) / 2, bh = 88;
  for (int i = 0; i < NCHK; i++) {
    int x = g + (i % 2) * (bw + g), y = 104 + (i / 2) * (bh + 15); bool on = chk[i];
    uint16_t bg = on ? C_OK : C_CARD, fg = on ? 0xFFFF : C_TEXT;
    d.fillRoundRect(x, y, bw, bh, 16, bg); if (!on) d.drawRoundRect(x, y, bw, bh, 16, C_LINE);
    d.drawRoundRect(x + 22, y + bh / 2 - 18, 36, 36, 8, fg);
    if (on) { for (int k = -1; k <= 1; k++) { d.drawLine(x + 29, y + bh / 2 + k, x + 37, y + bh / 2 + 9 + k, fg); d.drawLine(x + 37, y + bh / 2 + 9 + k, x + 52, y + bh / 2 - 10 + k, fg); } }
    d.setFont(&fonts::FreeSansBold18pt7b); d.setTextDatum(middle_left); d.setTextColor(fg, bg); d.drawString(CHK_NAME[i], x + 76, y + bh / 2);
    addBtn(x, y, bw, bh, "", 1720 + i, bg, fg, false);
  }
}

// ================= WLAN & FYF-CLOUD =================
// Öffentliche Projekt-Adresse und öffentlicher Schlüssel (publishable) – stehen genauso in der FYF-Web-App, kein Geheimnis.
// Geschützt wird über die Anmeldung des Geräts (Kopplungscode) und die Zugriffsregeln der Datenbank.
static const char* FYF_URL = "https://tyfilehmrnibtoalwflf.supabase.co";
static const char* FYF_KEY = "sb_publishable_DUIWZF8H-BD-HaBUMvTg-A_pbpz1mgT";
static char wSsid[33] = "", wPass[65] = "", selSsid[33] = "";
static bool wifiInit = false, timeSynced = false, ntpStarted = false;
static char cloudMsg[120] = "";
static char rtok[256] = "", tenant[40] = "", atok[2048] = ""; static uint32_t atokExp = 0;
struct Net { char ssid[33]; int rssi; bool open; };
static Net nets[12]; static int nNets = 0;
static bool cloudPaired() { return rtok[0] && tenant[0]; }
static bool wifiOn() { return wifiInit && WiFi.status() == WL_CONNECTED; }
static void setMsg(const char* m) { snprintf(cloudMsg, sizeof cloudMsg, "%s", m); }
static void loadCloud() {
  prefs.begin("fyf", true);
  prefs.getString("ssid", wSsid, sizeof wSsid); prefs.getString("wpw", wPass, sizeof wPass);
  prefs.getString("rt", rtok, sizeof rtok); prefs.getString("ten", tenant, sizeof tenant);
  prefs.end();
}
static void saveCloud() {
  prefs.begin("fyf", false);
  prefs.putString("ssid", wSsid); prefs.putString("wpw", wPass); prefs.putString("rt", rtok); prefs.putString("ten", tenant);
  prefs.end();
}
static void wifiSetup() {
  if (wifiInit) return;
#ifdef BOARD_SDIO_ESP_HOSTED_CLK
  WiFi.setPins(BOARD_SDIO_ESP_HOSTED_CLK, BOARD_SDIO_ESP_HOSTED_CMD, BOARD_SDIO_ESP_HOSTED_D0, BOARD_SDIO_ESP_HOSTED_D1,
               BOARD_SDIO_ESP_HOSTED_D2, BOARD_SDIO_ESP_HOSTED_D3, BOARD_SDIO_ESP_HOSTED_RESET);
#endif
  WiFi.mode(WIFI_STA); wifiInit = true;
}
static void ntpStart() { if (ntpStarted) return; configTzTime("CET-1CEST,M3.5.0,M10.5.0/3", "pool.ntp.org", "time.google.com"); ntpStarted = true; }
static void ntpPoll() {   // nicht blockierend: übernimmt die Internetzeit, sobald sie da ist
  if (timeSynced || !ntpStarted) return;
  struct tm ti; if (!getLocalTime(&ti, 0) || ti.tm_year + 1900 < 2025) return;
  fyf::DT t{ti.tm_year + 1900, ti.tm_mon + 1, ti.tm_mday, ti.tm_hour, ti.tm_min, ti.tm_sec, 0}; t.wd = fyf::weekdayMon0(t.y, t.mo, t.d);
  setNow(t); timeSynced = true;
}
static bool wifiConnect(uint32_t waitMs) {
  wifiSetup(); if (!wSsid[0]) { setMsg("Kein WLAN eingerichtet."); return false; }
  if (WiFi.status() == WL_CONNECTED) { ntpStart(); return true; }
  WiFi.begin(wSsid, wPass);
  uint32_t t = millis(); while (WiFi.status() != WL_CONNECTED && millis() - t < waitMs) { delay(100); M5.update(); }
  bool ok = WiFi.status() == WL_CONNECTED;
  if (ok) ntpStart(); else setMsg("WLAN-Verbindung fehlgeschlagen. Passwort und Empfang pruefen.");
  return ok;
}
static void wifiScan() {
  wifiSetup(); nNets = 0;
  int n = WiFi.scanNetworks();
  for (int i = 0; i < n && nNets < 12; i++) {
    String s = WiFi.SSID(i); if (!s.length()) continue;
    bool dup = false; for (int k = 0; k < nNets; k++) if (!strcmp(nets[k].ssid, s.c_str())) dup = true; if (dup) continue;
    snprintf(nets[nNets].ssid, sizeof nets[nNets].ssid, "%s", s.c_str()); nets[nNets].rssi = WiFi.RSSI(i);
    nets[nNets].open = WiFi.encryptionType(i) == WIFI_AUTH_OPEN; nNets++;
  }
  WiFi.scanDelete();
  if (n < 0) setMsg("WLAN-Suche fehlgeschlagen.");
}

// HTTPS-Anfrage an Supabase. Antwort landet in httpBuf. Rückgabe: HTTP-Status, negativ bei Verbindungsfehler.
static char* httpBuf = nullptr; static const int HTTP_CAP = 32768;
static int http(bool post, const char* path, const char* body, bool auth) {
  if (!httpBuf) httpBuf = (char*)ps_malloc(HTTP_CAP + 1);
  if (!httpBuf) return -2;
  httpBuf[0] = 0;
  char url[256]; snprintf(url, sizeof url, "%s%s", FYF_URL, path);
  esp_http_client_config_t cfg = {};
  cfg.url = url; cfg.method = post ? HTTP_METHOD_POST : HTTP_METHOD_GET; cfg.timeout_ms = 15000;
  cfg.cert_pem = FYF_ROOTS; cfg.buffer_size = 4096; cfg.buffer_size_tx = 4096;
  esp_http_client_handle_t c = esp_http_client_init(&cfg);
  if (!c) return -3;
  esp_http_client_set_header(c, "apikey", FYF_KEY);
  esp_http_client_set_header(c, "Content-Type", "application/json");
  static char bearer[2100];
  if (auth) { snprintf(bearer, sizeof bearer, "Bearer %s", atok); esp_http_client_set_header(c, "Authorization", bearer); }
  int bl = body ? (int)strlen(body) : 0;
  if (esp_http_client_open(c, bl) != ESP_OK) { esp_http_client_cleanup(c); return -1; }
  for (int w = 0, r2; w < bl; w += r2) { r2 = esp_http_client_write(c, body + w, bl - w); if (r2 <= 0) { esp_http_client_close(c); esp_http_client_cleanup(c); return -1; } }
  esp_http_client_fetch_headers(c);
  int st = esp_http_client_get_status_code(c), n = 0, r;
  while (n < HTTP_CAP && (r = esp_http_client_read(c, httpBuf + n, HTTP_CAP - n)) > 0) n += r;
  httpBuf[n] = 0;
  esp_http_client_close(c); esp_http_client_cleanup(c);
  return st;
}
static void httpErr(const char* what, int st) {
  char m[48] = ""; if (httpBuf && st > 0) fyf::jsonGet(httpBuf, "message", m, sizeof m);
  if (st < 0) snprintf(cloudMsg, sizeof cloudMsg, "%s: keine sichere Verbindung (WLAN oder Zertifikat).", what);
  else if (st == 404) snprintf(cloudMsg, sizeof cloudMsg, "%s: FYF-Datenbank kennt die Station noch nicht (station.sql).", what);
  else snprintf(cloudMsg, sizeof cloudMsg, "%s: Fehler %d %s", what, st, m);
}
static bool takeSession() {
  char v[16];
  if (!fyf::jsonGet(httpBuf, "access_token", atok, sizeof atok) || !atok[0]) return false;
  fyf::jsonGet(httpBuf, "refresh_token", rtok, sizeof rtok);
  int exp = fyf::jsonGet(httpBuf, "expires_in", v, sizeof v) ? atoi(v) : 3600;
  atokExp = millis() + (uint32_t)(exp > 300 ? exp - 120 : 180) * 1000UL;
  saveCloud(); return true;
}
static bool cloudToken() {
  if (atok[0] && (int32_t)(atokExp - millis()) > 0) return true;
  if (!cloudPaired()) { setMsg("Nicht mit FYF gekoppelt."); return false; }
  char body[320]; snprintf(body, sizeof body, "{\"refresh_token\":\"%s\"}", rtok);
  int st = http(true, "/auth/v1/token?grant_type=refresh_token", body, false);
  if (st == 200 && takeSession()) return true;
  if (st == 400 || st == 401) setMsg("Kopplung abgelaufen. Bitte 'Kopplung loesen' und neu koppeln.");
  else httpErr("Anmeldung", st);
  atok[0] = 0; return false;
}
static void cloudPair(const char* code) {
  waitScreen("Kopple mit FYF");
  if (!wifiConnect(15000)) return;
  atok[0] = 0; rtok[0] = 0; tenant[0] = 0;
  int st = http(true, "/auth/v1/signup", "{\"data\":{},\"gotrue_meta_security\":{}}", false);
  if (st != 200 || !takeSession()) {
    if (st == 422 || st == 400 || st == 403) setMsg("Anonyme Anmeldung ist in Supabase aus (Authentication > Allow anonymous sign-ins).");
    else httpErr("Anmeldung", st);
    rtok[0] = 0; saveCloud(); return;
  }
  char e[40], body[160]; fyf::jsonEsc(code, e, sizeof e);
  snprintf(body, sizeof body, "{\"p_code\":\"%s\",\"p_label\":\"FYF Station Tab5\"}", e);
  st = http(true, "/rest/v1/rpc/pair_redeem", body, true);
  const char* q = httpBuf ? strchr(httpBuf, '"') : nullptr;
  if (st == 200 && q) {
    const char* q2 = strchr(q + 1, '"');
    int L = q2 ? (int)(q2 - q - 1) : 0; if (L > 0 && L < (int)sizeof tenant) { memcpy(tenant, q + 1, L); tenant[L] = 0; }
  }
  if (!tenant[0]) {
    if (st == 200) setMsg("Code falsch oder abgelaufen. In FYF einen neuen Code erzeugen.");
    else if (httpBuf && strstr(httpBuf, "FYF_RATE")) setMsg("Zu viele Versuche. 10 Minuten warten.");
    else httpErr("Koppeln", st);
    rtok[0] = 0; atok[0] = 0; saveCloud(); return;
  }
  saveCloud(); setMsg("Gekoppelt. Das Tab5 steht in FYF im Team als 'Geraet: FYF Station Tab5'.");
}
static void cloudUnpair() { rtok[0] = 0; tenant[0] = 0; atok[0] = 0; saveCloud(); setMsg("Kopplung geloest. In FYF unter Team das Geraet entfernen."); }
static void cloudLoadCustomers() {
  waitScreen("Lade Kunden aus FYF");
  if (!wifiConnect(15000) || !cloudToken()) return;
  char body[96]; snprintf(body, sizeof body, "{\"p_tenant\":\"%s\"}", tenant);
  int st = http(true, "/rest/v1/rpc/station_customers", body, true);
  if (st != 200) { httpErr("Kunden laden", st); return; }
  // vorhandene Verknüpfungen merken
  static char ids[60][40]; static int idNum[60]; int nIds = 0;
  for (int i = 0; i < nCust; i++) { fyf::Customer c; if (custLoad(custs[i].id, c, false) && c.fyfId[0] && nIds < 60) { snprintf(ids[nIds], 40, "%s", c.fyfId); idNum[nIds++] = custs[i].id; } }
  int added = 0, updated = 0, full = 0; const char* p = httpBuf; char id[40], nm[40], h[16], sl[16];
  while ((p = fyf::jsonGet(p, "id", id, sizeof id))) {
    p = fyf::jsonGet(p, "name", nm, sizeof nm); if (!p) break;
    p = fyf::jsonGet(p, "height", h, sizeof h); if (!p) break;
    p = fyf::jsonGet(p, "inseam", sl, sizeof sl); if (!p) break;
    if (!nm[0]) continue;
    int num = 0; for (int k = 0; k < nIds; k++) if (!strcmp(ids[k], id)) num = idNum[k];
    fyf::Customer c{}; bool isNew = !num;
    if (num) custLoad(num, c, false);
    else { num = custNewId(); if (!num) { full++; continue; } c.height = NAN; c.inseam = NAN; snprintf(c.fyfId, sizeof c.fyfId, "%s", id); }
    snprintf(c.name, sizeof c.name, "%s", nm);
    float fh = fyf::parseNum(h), fs = fyf::parseNum(sl);
    if (!isnan(fh)) c.height = fh;
    if (!isnan(fs)) c.inseam = fs;
    if (custSave(num, c)) { if (isNew) added++; else updated++; }
  }
  custScan();
  snprintf(cloudMsg, sizeof cloudMsg, "Kunden aus FYF: %d neu, %d aktualisiert%s.", added, updated, full ? ", Speicher voll (max. 99)" : "");
}
// Kunden aus FYF holen: automatisch beim Öffnen von „Kunden“ (höchstens alle 2 Minuten, nur mit WLAN) oder per Knopf „FYF“.
static void custSyncFromFyf(bool manual) {
  if (!cloudPaired()) { if (manual) snprintf(custSyncMsg, sizeof custSyncMsg, "Nicht mit FYF gekoppelt: Mehr > FYF & WLAN > Mit FYF koppeln."); return; }
  if (!manual && (!wifiOn() || (custSynced && millis() - lastCustSync < 120000UL))) return;
  cloudMsg[0] = 0; cloudLoadCustomers();
  lastCustSync = millis(); custSynced = true;
  snprintf(custSyncMsg, sizeof custSyncMsg, "%s", cloudMsg);
}
static bool consAppend(int id, char* payload, int cap);   // weiter unten (Einwilligung)
static void cloudSend() {
  waitScreen("Sende an FYF");
  if (!wifiConnect(15000) || !cloudToken()) return;
  fyf::Customer c{}; c.name[0] = 0; c.fyfId[0] = 0; if (activeCust) custLoad(activeCust, c, false);
  const char* ob[NO]; int nOb = 0; for (int i = 0; i < NO; i++) if (obsMin[i]) ob[nOb++] = O_NAME[i];
  fyf::DT t = nowDT(); char when[24]; snprintf(when, sizeof when, "%04d-%02d-%02dT%02d:%02d", t.y, t.mo, t.d, t.h, t.mi);
  const int PCAP = 48000;   // mit Unterschrift (PNG als Base64) deutlich größer als früher
  static char* payload = nullptr; static char* body = nullptr;
  if (!payload) payload = (char*)ps_malloc(PCAP); if (!body) body = (char*)ps_malloc(PCAP + 200);
  if (!payload || !body) { setMsg("Zu wenig Speicher."); return; }
  if (fyf::payloadJson(payload, PCAP, VERSION, when, c.name, c.fyfId, vals[0], vals[1], ob, nOb, measDone, rideRes, nRide) < 0) { setMsg("Zu viele Daten."); return; }
  bool withCons = consAppend(activeCust, payload, PCAP);
  snprintf(body, PCAP + 200, "{\"p_tenant\":\"%s\",\"p_payload\":%s}", tenant, payload);
  int st = http(true, "/rest/v1/rpc/station_push", body, true);
  if (st != 200 && st != 204) { httpErr("Senden", st); return; }
  setMsg(withCons ? "Gesendet mit Einwilligung. In FYF: Fitting > 'Werte vom Tab5 holen'." : "Gesendet. In FYF: Fitting oeffnen > 'Werte vom Tab5 holen'.");
}
static void drawCloud() {
  auto& d = M5.Display; d.fillScreen(C_BG); nBtns = 0;
  drawHeader("FYF & WLAN", true);
  int W = d.width(), H = d.height(), cw = (W - 60) / 2; char s[96], f[40];
  bool on = wifiOn();
  // WLAN
  d.fillRoundRect(20, 104, cw, 470, 18, C_CARD); d.drawRoundRect(20, 104, cw, 470, 18, C_LINE);
  d.setFont(&fonts::FreeSansBold24pt7b); d.setTextDatum(top_left); d.setTextColor(C_TEXT, C_CARD); d.drawString("WLAN", 46, 122);
  d.setFont(&fonts::FreeSans18pt7b); d.setTextColor(on ? C_OK : C_MUTED, C_CARD);
  fyf::asciiFold(wSsid, f, sizeof f);
  if (on) snprintf(s, sizeof s, "Verbunden: %s", f); else if (wSsid[0]) snprintf(s, sizeof s, "Nicht verbunden (%s)", f); else snprintf(s, sizeof s, "Noch kein WLAN eingerichtet");
  d.drawString(s, 46, 186);
  d.setTextColor(C_MUTED, C_CARD);
  if (on) { snprintf(s, sizeof s, "IP %s", WiFi.localIP().toString().c_str()); d.drawString(s, 46, 226); }
  d.drawString(timeSynced ? "Uhrzeit aus dem Internet uebernommen" : "Uhrzeit: wird mit WLAN gestellt", 46, 266);
  addBtn(40, 330, cw - 40, 70, "WLAN waehlen", 1900, C_ACC, 0xFFFF);
  addBtn(40, 410, (cw - 50) / 2, 70, "Verbinden", 1901);
  addBtn(50 + (cw - 50) / 2, 410, (cw - 50) / 2, 70, "Vergessen", 1902, C_WARN_L, C_WARN);
  // FYF
  int X = 40 + cw;
  d.fillRoundRect(X, 104, cw, 470, 18, C_CARD); d.drawRoundRect(X, 104, cw, 470, 18, C_LINE);
  d.setFont(&fonts::FreeSansBold24pt7b); d.setTextColor(C_TEXT, C_CARD); d.drawString("FYF-App", X + 26, 122);
  d.setFont(&fonts::FreeSans18pt7b); d.setTextColor(cloudPaired() ? C_OK : C_MUTED, C_CARD);
  d.drawString(cloudPaired() ? "Gekoppelt mit deinem Laden" : "Nicht gekoppelt", X + 26, 186);
  d.setFont(&fonts::FreeSans12pt7b); d.setTextColor(C_MUTED, C_CARD);
  if (!cloudPaired()) { d.drawString("Code in FYF: Mehr > Cloud-Speicherung >", X + 26, 232); d.drawString("'Weiteres Geraet verbinden'", X + 26, 260); }
  else { d.drawString("Kunden laden, Fitting senden. In FYF im", X + 26, 232); d.drawString("Fitting 'Werte vom Tab5 holen' tippen.", X + 26, 260); }
  if (!cloudPaired()) addBtn(X + 20, 330, cw - 40, 70, "Mit FYF koppeln", 1910, C_ACC, 0xFFFF);
  else {
    addBtn(X + 20, 330, cw - 40, 70, "Fitting an FYF senden", 1912, C_ACC, 0xFFFF);
    addBtn(X + 20, 410, cw - 40, 70, "Kunden aus FYF laden", 1911);
    addBtn(X + 20, 490, cw - 40, 70, "Kopplung loesen", 1913, C_WARN_L, C_WARN);
  }
  drawAllBtns();
  if (cloudMsg[0]) {
    d.fillRoundRect(20, 590, W - 40, H - 606, 16, C_ACC_L);
    d.setFont(&fonts::FreeSans18pt7b); d.setTextDatum(top_left); d.setTextColor(C_TEXT, C_ACC_L); drawWrapped(cloudMsg, 44, 604, W - 88, 36);
  }
}
static void drawWifiList() {
  auto& d = M5.Display; d.fillScreen(C_BG); nBtns = 0;
  drawHeader("WLAN waehlen", true);
  addBtn(d.width() - 600, 15, 250, 60, "Neu suchen", 1820); drawBtn(btns[nBtns - 1]);
  int W = d.width(), cw = (W - 60) / 2;
  if (!nNets) { d.setFont(&fonts::FreeSans18pt7b); d.setTextDatum(top_left); d.setTextColor(C_MUTED, C_BG); d.drawString("Keine Netze gefunden. 'Neu suchen' antippen.", 30, 120); }
  for (int i = 0; i < nNets; i++) {
    int x = 20 + (i % 2) * (cw + 20), y = 104 + (i / 2) * 98; char f[40], s[24];
    d.fillRoundRect(x, y, cw, 86, 14, C_CARD); d.drawRoundRect(x, y, cw, 86, 14, C_LINE);
    fyf::asciiFold(nets[i].ssid, f, sizeof f);
    d.setFont(&fonts::FreeSansBold18pt7b); d.setTextDatum(middle_left); d.setTextColor(C_TEXT, C_CARD); d.drawString(f, x + 22, y + 43);
    int bars = nets[i].rssi > -55 ? 4 : nets[i].rssi > -67 ? 3 : nets[i].rssi > -78 ? 2 : 1;
    for (int b = 0; b < 4; b++) d.fillRect(x + cw - 120 + b * 14, y + 58 - b * 10, 10, 10 + b * 10, b < bars ? C_OK : C_LINE);
    snprintf(s, sizeof s, "%s", nets[i].open ? "offen" : ""); d.setFont(&fonts::FreeSans12pt7b); d.setTextDatum(middle_right); d.setTextColor(C_MUTED, C_CARD); d.drawString(s, x + cw - 136, y + 43);
    addBtn(x, y, cw, 86, "", 1800 + i, C_CARD, C_TEXT, false);
  }
}

// ================= BILDSCHIRMSCHONER (Uhr) =================
static uint32_t lastTouch = 0; static Screen saverReturn = HOME;
static void drawSaver() { M5.Display.fillScreen(W_INK); nBtns = 0; lastSec = -1; }
static void drawSaverValue(const fyf::DT& t) {
  auto& d = M5.Display;
  drawClockFace(t, 40, 60, W_INK);
  M5Canvas c(&d); c.setPsram(true); c.createSprite(560, 420); c.fillSprite(W_INK);
  char s[40];
  c.setFont(&fonts::FreeSerif24pt7b); c.setTextDatum(top_left); c.setTextColor(W_DIAL, W_INK); c.setTextSize(2.4f);
  snprintf(s, sizeof s, "%02d:%02d", t.h, t.mi); c.drawString(s, 0, 40);
  c.setTextSize(1); c.setFont(&fonts::FreeSerif18pt7b); c.setTextColor(W_CASE, W_INK);
  c.drawString(WD_NAME[t.wd], 4, 200);
  snprintf(s, sizeof s, "%d. %s %d", t.d, MO_NAME[t.mo - 1], t.y); c.drawString(s, 4, 250);
  c.setFont(&fonts::FreeSans12pt7b); c.setTextColor(C_MUTED, W_INK); c.drawString("Antippen zum Weiterarbeiten", 4, 380);
  c.pushSprite(700, 130); c.deleteSprite();
}

// ================= WETTERSTATION (DWD über Bright Sky) =================
// Daten: Deutscher Wetterdienst (DWD), abgerufen über api.brightsky.dev (kostenlos, ohne Schlüssel).
// Karte: BKG TopPlusOpen, einmal geladen und auf der SD-Karte gespeichert (Offline-Nutzung laut BKG erlaubt).
// Netz läuft in einer eigenen Aufgabe (wxTask), damit Uhr, Symbole und Radar-Film flüssig bleiben.
static const double WX_LAT = 49.5969, WX_LON = 11.0722;   // Uttenreuth
static const int WX_MW = 720, WX_MH = 630;                // Kartenbereich links oben
static const double WX_MPP = 200.0;                       // Mercator-Meter pro Bildpunkt (ca. 130 m echt)
static const int WX_RDIST = 50000;                        // Radar: 50 km zu jeder Seite
static const int WX_GMAX = 121;                           // größtes Radar-Raster (Bildpunkte je Seite)
static const char* WX_MAPFILE = "/FYF/karte.png";
static const char* WX_MAPMETA = "/FYF/karte.txt";
static const char* WX_MAPVER = "BKG-web_grau-720x630-200";
#define WXRGB(r, g, b) ((uint16_t)((((r) & 0xF8) << 8) | (((g) & 0xFC) << 3) | ((b) >> 3)))
static const uint16_t WX_BG = WXRGB(9, 24, 48), WX_PANEL = WXRGB(13, 32, 62), WX_CARD = WXRGB(20, 46, 86), WX_LINE = WXRGB(40, 74, 124);
static const uint16_t WX_TEXT = WXRGB(236, 244, 255), WX_MUTED = WXRGB(140, 168, 208), WX_ACC = WXRGB(80, 180, 255), WX_SUN = WXRGB(255, 204, 80);
static const uint16_t WX_CLOUD = WXRGB(214, 228, 246), WX_CLOUD_D = WXRGB(128, 152, 190), WX_DROP = WXRGB(96, 178, 255), WX_MOON = WXRGB(250, 240, 200);
static const uint16_t WX_FC = WXRGB(78, 120, 176);   // Vorhersage-Teil der Zeitleiste
static const uint8_t WX_RCOL[9][3] = {{0, 0, 0}, {170, 225, 255}, {110, 190, 255}, {50, 140, 240}, {30, 95, 215}, {60, 60, 190}, {130, 60, 205}, {200, 60, 180}, {245, 80, 120}};
static const uint8_t WX_RALPHA[9] = {0, 120, 150, 175, 195, 210, 220, 230, 240};
static const uint16_t WX_ALCOL[5] = {WX_CARD, WXRGB(240, 205, 60), WXRGB(245, 150, 35), WXRGB(225, 55, 50), WXRGB(150, 40, 175)};

// gemeinsame Daten (Netz-Aufgabe schreibt, Bildschirm liest; Zugriff über wxLock)
static WxNowT wxNow{}; static fyf::WxHour wxHours[110]; static int wxNH = 0; static WxAlertT wxAl[4]; static int wxNA = 0;
static bool wxFcOk = false, wxAlOk = false;
static WxRadarT wxRad[2]; static volatile int wxRCur = -1;
static SemaphoreHandle_t wxLock = nullptr, sdLock = nullptr;
static volatile bool wxDNow = false, wxDFc = false, wxDAl = false, wxDRad = false, wxDMap = false, wxForce = false, wxMapWanted = false;
static volatile uint32_t wxRadarUntil = 0;
static char wxStat[100] = "Warte auf WLAN ...";
static bool sdOk = false;

// ---------- Netz (läuft in wxTask) ----------
static char* wxBuf = nullptr; static const int WX_CAP = 1800000;
static int wxGet(const char* url, int& len) {
  len = 0; if (!wxBuf) return -2;
  esp_http_client_config_t cfg = {};
  cfg.url = url; cfg.method = HTTP_METHOD_GET; cfg.timeout_ms = 20000; cfg.buffer_size = 8192; cfg.buffer_size_tx = 2048;
  cfg.user_agent = "FYF-Station/0.4.3 (M5Stack Tab5)";
#if WX_BUNDLE
  cfg.crt_bundle_attach = esp_crt_bundle_attach;
#else
  cfg.cert_pem = FYF_ROOTS;
#endif
  esp_http_client_handle_t c = esp_http_client_init(&cfg);
  if (!c) return -3;
  if (esp_http_client_open(c, 0) != ESP_OK) { esp_http_client_cleanup(c); return -1; }
  esp_http_client_fetch_headers(c);
  int st = esp_http_client_get_status_code(c), r;
  while (len < WX_CAP && (r = esp_http_client_read(c, wxBuf + len, WX_CAP - len)) > 0) len += r;
  wxBuf[len] = 0;
  esp_http_client_close(c); esp_http_client_cleanup(c);
  return st;
}
static void wxErr(const char* what, int st) {
  if (st < 0) snprintf(wxStat, sizeof wxStat, "%s: keine sichere Verbindung (WLAN/Zertifikat)", what);
  else snprintf(wxStat, sizeof wxStat, "%s: Fehler %d", what, st);
}
static void wxLocalNow(int& y, int& mo, int& d, int& h, int& mi) {
  time_t t = time(nullptr); struct tm l; localtime_r(&t, &l);
  y = l.tm_year + 1900; mo = l.tm_mon + 1; d = l.tm_mday; h = l.tm_hour; mi = l.tm_min;
}
static float wxNum(const char* p, const char* key) { char v[24]; return fyf::jsonGet(p, key, v, sizeof v) ? fyf::parseNum(v) : NAN; }
static bool wxFetchNow() {
  char url[200]; int len;
  snprintf(url, sizeof url, "https://api.brightsky.dev/current_weather?lat=%.4f&lon=%.4f&tz=Europe/Berlin", WX_LAT, WX_LON);
  int st = wxGet(url, len);
  if (st != 200) { wxErr("Wetter", st); return false; }
  const char* w = strstr(wxBuf, "\"weather\""); if (!w) { wxErr("Wetter", 0); return false; }
  WxNowT n{}; char v[32];
  n.temp = wxNum(w, "temperature"); n.hum = wxNum(w, "relative_humidity");
  n.wind = wxNum(w, "wind_speed_10"); if (isnan(n.wind)) n.wind = wxNum(w, "wind_speed_30");
  n.gust = wxNum(w, "wind_gust_speed_10"); if (isnan(n.gust)) n.gust = wxNum(w, "wind_gust_speed_30");
  n.wdir = wxNum(w, "wind_direction_10"); if (isnan(n.wdir)) n.wdir = wxNum(w, "wind_direction_30");
  n.press = wxNum(w, "pressure_msl"); n.dew = wxNum(w, "dew_point");
  n.icon = fyf::wxIconCode(fyf::jsonGet(w, "icon", v, sizeof v) ? v : "");
  if (fyf::jsonGet(w, "timestamp", v, sizeof v)) fyf::parseIso(v, n.y, n.mo, n.d, n.h, n.mi);
  n.ok = !isnan(n.temp);
  xSemaphoreTake(wxLock, portMAX_DELAY); wxNow = n; xSemaphoreGive(wxLock);
  wxDNow = true; return n.ok;
}
static bool wxFetchFc() {
  int y, mo, d, h, mi; wxLocalNow(y, mo, d, h, mi);
  long day = fyf::daysFromCivil(y, mo, d); int y2, mo2, d2; fyf::civilFromDays(day + 4, y2, mo2, d2);
  char url[220]; int len;
  snprintf(url, sizeof url, "https://api.brightsky.dev/weather?lat=%.4f&lon=%.4f&date=%04d-%02d-%02d&last_date=%04d-%02d-%02d&tz=Europe/Berlin",
           WX_LAT, WX_LON, y, mo, d, y2, mo2, d2);
  int st = wxGet(url, len);
  if (st != 200) { wxErr("Vorhersage", st); return false; }
  static fyf::WxHour hs[110]; int n = 0;
  char* end = strstr(wxBuf, "\"sources\""); if (!end) end = wxBuf + len;
  char* p = strstr(wxBuf, "\"timestamp\"");
  while (p && p < end && n < 110) {
    char* q = strstr(p + 11, "\"timestamp\""); if (!q || q > end) q = end;
    char keep = *q; *q = 0;
    char v[32]; fyf::WxHour r{};
    if (fyf::jsonGet(p, "timestamp", v, sizeof v) && fyf::parseIso(v, r.y, r.mo, r.d, r.h, mi)) {
      r.temp = wxNum(p, "temperature"); r.prec = wxNum(p, "precipitation"); r.prob = wxNum(p, "precipitation_probability");
      r.wind = wxNum(p, "wind_speed"); float s = wxNum(p, "sunshine"); r.sun = isnan(s) ? 0 : (int)s;
      r.icon = fyf::wxIconCode(fyf::jsonGet(p, "icon", v, sizeof v) ? v : "");
      hs[n++] = r;
    }
    *q = keep; p = q < end ? q : nullptr;
  }
  if (!n) { wxErr("Vorhersage", 0); return false; }
  xSemaphoreTake(wxLock, portMAX_DELAY); memcpy(wxHours, hs, sizeof(fyf::WxHour) * n); wxNH = n; wxFcOk = true; xSemaphoreGive(wxLock);
  wxDFc = true; return true;
}
static void wxWhen(const char* on, const char* ex, char* out, int cap) {
  int y, mo, d, h, mi, y2, mo2, d2, h2, mi2;
  bool a = fyf::parseIso(on, y, mo, d, h, mi), b = fyf::parseIso(ex, y2, mo2, d2, h2, mi2);
  if (a && b) snprintf(out, cap, "%s %02d:%02d bis %s %02d:%02d", WD_SHORT[fyf::weekdayMon0(y, mo, d)], h, mi, WD_SHORT[fyf::weekdayMon0(y2, mo2, d2)], h2, mi2);
  else if (a) snprintf(out, cap, "ab %s %02d:%02d", WD_SHORT[fyf::weekdayMon0(y, mo, d)], h, mi);
  else out[0] = 0;
}
static bool wxFetchAlerts() {
  char url[200]; int len;
  snprintf(url, sizeof url, "https://api.brightsky.dev/alerts?lat=%.4f&lon=%.4f&tz=Europe/Berlin", WX_LAT, WX_LON);
  int st = wxGet(url, len);
  if (st != 200) { wxErr("Warnungen", st); return false; }
  static WxAlertT a[4]; int n = 0;
  char* end = strstr(wxBuf, "\"location\""); if (!end) end = wxBuf + len;
  char* p = strstr(wxBuf, "\"alert_id\"");
  while (p && p < end) {
    char* q = strstr(p + 10, "\"alert_id\""); if (!q || q > end) q = end;
    char keep = *q; *q = 0;
    WxAlertT r{}; char v[48], on[32] = "", ex[32] = "", raw[480];
    if (fyf::jsonGet(p, "status", v, sizeof v) && !strcmp(v, "actual")) {
      r.level = fyf::alertLevel(fyf::jsonGet(p, "severity", v, sizeof v) ? v : "");
      if (fyf::jsonGet(p, "event_de", raw, sizeof raw)) { fyf::asciiFold(raw, r.event, sizeof r.event); for (char* c = r.event; *c; c++) *c = (char)toupper((unsigned char)*c); }
      if (fyf::jsonGet(p, "headline_de", raw, sizeof raw)) fyf::asciiFold(raw, r.head, sizeof r.head);
      if (fyf::jsonGet(p, "description_de", raw, sizeof raw)) fyf::asciiFold(raw, r.desc, sizeof r.desc);
      fyf::jsonGet(p, "onset", on, sizeof on); fyf::jsonGet(p, "expires", ex, sizeof ex);
      wxWhen(on, ex, r.when, sizeof r.when);
      if (r.event[0]) {
        if (n < 4) a[n++] = r;
        else { int lo = 0; for (int i = 1; i < 4; i++) if (a[i].level < a[lo].level) lo = i; if (r.level > a[lo].level) a[lo] = r; }
      }
    }
    *q = keep; p = q < end ? q : nullptr;
  }
  for (int i = 1; i < n; i++) { WxAlertT k = a[i]; int j = i - 1; while (j >= 0 && a[j].level < k.level) { a[j + 1] = a[j]; j--; } a[j + 1] = k; }
  xSemaphoreTake(wxLock, portMAX_DELAY); memcpy(wxAl, a, sizeof(WxAlertT) * n); wxNA = n; wxAlOk = true; xSemaphoreGive(wxLock);
  wxDAl = true; return true;
}
static bool wxRadarAlloc(WxRadarT& r) {
  if (!r.px) r.px = (uint16_t*)ps_malloc(sizeof(uint16_t) * 48 * WX_GMAX * WX_GMAX);
  return r.px != nullptr;
}
static bool wxFetchRadar() {
  int wi = wxRCur == 0 ? 1 : 0; WxRadarT& R = wxRad[wi];
  if (!wxRadarAlloc(R)) { snprintf(wxStat, sizeof wxStat, "Radar: zu wenig Speicher"); return false; }
  char d0[24], d1[24], url[300]; int len;
  time_t now = time(nullptr); struct tm g;
  time_t a = now - 75 * 60; gmtime_r(&a, &g); strftime(d0, sizeof d0, "%Y-%m-%dT%H:%M:00Z", &g);
  time_t b = now + 125 * 60; gmtime_r(&b, &g); strftime(d1, sizeof d1, "%Y-%m-%dT%H:%M:00Z", &g);
  snprintf(url, sizeof url, "https://api.brightsky.dev/radar?lat=%.4f&lon=%.4f&distance=%d&format=bytes&tz=Europe/Berlin&date=%s&last_date=%s",
           WX_LAT, WX_LON, WX_RDIST, d0, d1);
  int st = wxGet(url, len);
  if (st != 200) { wxErr("Radar", st); return false; }
  // Raster-Größe (bbox: oben, links, unten, rechts; Ränder inklusive) und Eckpunkte
  int W = 0, H = 0;
  const char* bb = strstr(wxBuf, "\"bbox\"");
  if (bb && (bb = strchr(bb, '['))) { int t, l, bo, ri; if (sscanf(bb, "[%d,%d,%d,%d]", &t, &l, &bo, &ri) == 4 || sscanf(bb, "[ %d , %d , %d , %d ]", &t, &l, &bo, &ri) == 4) { W = ri - l + 1; H = bo - t + 1; } }
  double lon[4], lat[4]; int nc = 0;
  const char* co = strstr(wxBuf, "\"coordinates\"");
  if (co) {
    const char* p = strchr(co, '[');
    while (p && nc < 4) {
      p = strchr(p + 1, '['); if (!p) break;
      char* e; double x = strtod(p + 1, &e); if (e == p + 1) continue;
      const char* c2 = strchr(e, ','); if (!c2) break; double y = strtod(c2 + 1, &e);
      lon[nc] = x; lat[nc] = y; nc++; p = e;
    }
  }
  if (nc < 4) { snprintf(wxStat, sizeof wxStat, "Radar: Eckpunkte fehlen"); return false; }
  // Bilder lesen
  int n = 0; const char* p = wxBuf; const int maxB = WX_GMAX * WX_GMAX * 2;
  static uint8_t* tmp = nullptr; if (!tmp) tmp = (uint8_t*)ps_malloc(maxB + 16);
  if (!tmp) return false;
  while (n < 48 && (p = strstr(p, "\"timestamp\""))) {
    char ts[32]; const char* q = fyf::jsonGet(p, "timestamp", ts, sizeof ts); if (!q) break;
    const char* pp = strstr(q, "\"precipitation_5\""); if (!pp) break;
    const char* s = strchr(pp + 17, '"'); if (!s) break; s++;
    const char* e = strchr(s, '"'); if (!e) break;
    int nb = fyf::b64Decode(s, (int)(e - s), tmp, maxB);
    p = e + 1;
    if (nb <= 0) continue;
    if (!W || !H) { int side = (int)lroundf(sqrtf(nb / 2.0f)); W = H = side; }
    if (W * H * 2 != nb || W > WX_GMAX || H > WX_GMAX) continue;
    int mi;
    if (!fyf::parseIso(ts, R.fy[n], R.fmo[n], R.fd[n], R.fh[n], mi)) continue;
    R.fmi[n] = mi;
    uint16_t* dst = R.px + (size_t)n * W * H;
    for (int i = 0; i < W * H; i++) dst[i] = (uint16_t)(tmp[2 * i] | (tmp[2 * i + 1] << 8));   // 2-Byte-Zahlen, little endian
    n++;
  }
  if (!n) { snprintf(wxStat, sizeof wxStat, "Radar: keine Bilder"); return false; }
  // Bildschirm-Abbildung: Raster (i, j) -> Karte (x, y) über die Ecken TL, TR, BL (fast affin bei 50 km)
  int ix[4]; fyf::sortCorners(lon, lat, ix);
  double mx0, my0; fyf::mercator(WX_LAT, WX_LON, mx0, my0);
  double sx[4], sy[4];
  for (int k = 0; k < 4; k++) { double mx, my; fyf::mercator(lat[ix[k]], lon[ix[k]], mx, my); sx[k] = (mx - mx0) / WX_MPP + WX_MW / 2.0; sy[k] = (my0 - my) / WX_MPP + WX_MH / 2.0; }
  // Raster -> Bildschirm: P = TL + i*a + j*b ; umkehren
  double ax = (sx[1] - sx[0]) / W, ay = (sy[1] - sy[0]) / W, bx = (sx[2] - sx[0]) / H, by = (sy[2] - sy[0]) / H;
  double det = ax * by - ay * bx; if (fabs(det) < 1e-9) return false;
  R.inv[0] = by / det; R.inv[1] = -bx / det; R.inv[2] = -ay / det; R.inv[3] = ax / det; R.inv[4] = sx[0]; R.inv[5] = sy[0];
  // Jetzt-Bild: letztes Bild, das nicht in der Zukunft liegt
  int y, mo, d, h, mn; wxLocalNow(y, mo, d, h, mn); long long nowE = fyf::toEpoch(y, mo, d, h, mn, 0);
  R.nowI = 0; for (int k = 0; k < n; k++) if (fyf::toEpoch(R.fy[k], R.fmo[k], R.fd[k], R.fh[k], R.fmi[k], 0) <= nowE) R.nowI = k;
  R.n = n; R.W = W; R.H = H; R.ok = true;
  xSemaphoreTake(wxLock, portMAX_DELAY); wxRCur = wi; xSemaphoreGive(wxLock);
  wxDRad = true; return true;
}
static void wxMapBbox(double& x0, double& y0, double& x1, double& y1) {
  double mx, my; fyf::mercator(WX_LAT, WX_LON, mx, my);
  x0 = mx - WX_MW / 2.0 * WX_MPP; x1 = mx + WX_MW / 2.0 * WX_MPP; y0 = my - WX_MH / 2.0 * WX_MPP; y1 = my + WX_MH / 2.0 * WX_MPP;
}
static bool wxFetchMap() {
  if (!sdOk) { snprintf(wxStat, sizeof wxStat, "Karte: keine SD-Karte"); return false; }
  double x0, y0, x1, y1; wxMapBbox(x0, y0, x1, y1);
  char url[400]; int len;
  snprintf(url, sizeof url, "https://sgx.geodatenzentrum.de/wms_topplus_open?SERVICE=WMS&VERSION=1.1.1&REQUEST=GetMap&LAYERS=web_grau&STYLES="
           "&SRS=EPSG:3857&BBOX=%.1f,%.1f,%.1f,%.1f&WIDTH=%d&HEIGHT=%d&FORMAT=image/png", x0, y0, x1, y1, WX_MW, WX_MH);
  int st = wxGet(url, len);
  if (st != 200 || len < 1000 || memcmp(wxBuf, "\x89PNG", 4)) { if (st == 200) snprintf(wxStat, sizeof wxStat, "Karte: Antwort ist kein Bild"); else wxErr("Karte", st); return false; }
  int y, mo, d, h, mi; wxLocalNow(y, mo, d, h, mi);
  bool ok = false;
  xSemaphoreTake(sdLock, portMAX_DELAY);
  if (!SD.exists("/FYF")) SD.mkdir("/FYF");
  File f = SD.open(WX_MAPFILE, FILE_WRITE);
  if (f) { ok = (int)f.write((const uint8_t*)wxBuf, len) == len; f.close(); }
  if (ok) { File m = SD.open(WX_MAPMETA, FILE_WRITE); if (m) { m.printf("%s|%d\n", WX_MAPVER, y); m.close(); } }
  xSemaphoreGive(sdLock);
  if (!ok) { snprintf(wxStat, sizeof wxStat, "Karte: Schreiben auf SD fehlgeschlagen"); return false; }
  wxDMap = true; return true;
}
static void wxTask(void*) {
  uint32_t tNow = 0, tFc = 0, tAl = 0, tRad = 0; bool okNow = false, okFc = false, okAl = false, okRad = false;
  wxBuf = (char*)ps_malloc(WX_CAP + 1);
  for (;;) {
    vTaskDelay(pdMS_TO_TICKS(1000));
    if (!wifiOn() || !timeSynced) { if (!wifiOn()) snprintf(wxStat, sizeof wxStat, "Kein WLAN: Mehr > FYF & WLAN"); continue; }
    uint32_t ms = millis(); bool f = wxForce; wxForce = false;
    bool any = false;
    if (f || !okNow || ms - tNow > 600000UL) { okNow = wxFetchNow(); tNow = okNow ? ms : ms - 540000UL; any = true; }
    if (f || !okAl || ms - tAl > 300000UL) { okAl = wxFetchAlerts(); tAl = okAl ? ms : ms - 240000UL; any = true; }
    if (f || !okFc || ms - tFc > 3600000UL) { okFc = wxFetchFc(); tFc = okFc ? ms : ms - 3540000UL; any = true; }
    if ((int32_t)(wxRadarUntil - ms) > 0 && (f || !okRad || ms - tRad > 300000UL)) { okRad = wxFetchRadar(); tRad = okRad ? ms : ms - 240000UL; any = true; }
    if (wxMapWanted) { wxMapWanted = false; any = true; if (!wxFetchMap()) {} }
    if (any && okNow && okFc && okAl) { int y, mo, d, h, mi; wxLocalNow(y, mo, d, h, mi); snprintf(wxStat, sizeof wxStat, "DWD-Daten von %02d:%02d", h, mi); }
  }
}

// ---------- SD-Karte ----------
static void sdScan();
static void sdStart() {
  if (!sdLock) sdLock = xSemaphoreCreateMutex();
  xSemaphoreTake(sdLock, portMAX_DELAY);
  SD.end();
  SPI.begin(43, 39, 44, 42);                 // Tab5: SCK 43, MISO 39, MOSI 44, CS 42 (wie im M5Stack-Beispiel)
  sdOk = SD.begin(42, SPI, 25000000) && SD.cardType() != CARD_NONE;
  if (sdOk && !SD.exists("/FYF")) SD.mkdir("/FYF");
  if (sdOk) sdScan();
  xSemaphoreGive(sdLock);
}
static bool wxMapOnSd() {
  if (!sdOk) return false;
  xSemaphoreTake(sdLock, portMAX_DELAY);
  bool ok = SD.exists(WX_MAPFILE) && SD.exists(WX_MAPMETA);
  if (ok) { File m = SD.open(WX_MAPMETA, FILE_READ); String l = m ? m.readStringUntil('\n') : String(""); if (m) m.close(); ok = l.startsWith(WX_MAPVER); }
  xSemaphoreGive(sdLock);
  return ok;
}
static int wxMapYear() {
  int y = 0; if (!sdOk) return 0;
  xSemaphoreTake(sdLock, portMAX_DELAY);
  File m = SD.open(WX_MAPMETA, FILE_READ); if (m) { String l = m.readStringUntil('\n'); m.close(); int p = l.indexOf('|'); if (p > 0) y = l.substring(p + 1).toInt(); }
  xSemaphoreGive(sdLock);
  return y;
}

// ---------- Zeichnen: Karte & Radar ----------
static M5Canvas* wxMap = nullptr;   // Grundkarte (blau eingefärbt)
static M5Canvas* wxFr = nullptr;    // Bild = Karte + Radar
static bool wxMapReal = false; static int wxMapY = 0;
static int wxFrame = 0; static bool wxPlay = true; static uint32_t wxLastFrame = 0, wxLastAnim = 0; static int wxLastMin = -1;
static bool wxAlertOpen = false;
static inline uint16_t wxSwap(uint16_t c) { return (uint16_t)((c >> 8) | (c << 8)); }
static void wxToScreen(double lat, double lon, int& x, int& y) {
  double mx0, my0, mx, my; fyf::mercator(WX_LAT, WX_LON, mx0, my0); fyf::mercator(lat, lon, mx, my);
  x = (int)lround((mx - mx0) / WX_MPP + WX_MW / 2.0); y = (int)lround((my0 - my) / WX_MPP + WX_MH / 2.0);
}
// Ersatzkarte ohne SD: dunkelblau mit Orten (Lage ungefähr)
static void wxFallbackMap(M5Canvas& c) {
  c.fillSprite(WX_BG);
  for (int x = 0; x < WX_MW; x += 60) c.drawFastVLine(x, 0, WX_MH, WXRGB(16, 36, 66));
  for (int y = 0; y < WX_MH; y += 60) c.drawFastHLine(0, y, WX_MW, WXRGB(16, 36, 66));
  static const struct { const char* n; double la, lo; } P[] = {{"Erlangen", 49.5897, 11.0120}, {"Nuernberg", 49.4521, 11.0767}, {"Fuerth", 49.4771, 10.9887},
    {"Forchheim", 49.7197, 11.0581}, {"Herzogenaurach", 49.5675, 10.8856}, {"Lauf", 49.5103, 11.2772}, {"Eckental", 49.5869, 11.2156},
    {"Graefenberg", 49.6443, 11.2496}, {"Hoechstadt", 49.7056, 10.8131}, {"Schwabach", 49.3290, 11.0236}};
  c.setFont(&fonts::FreeSans9pt7b); c.setTextDatum(middle_left);
  for (auto& p : P) { int x, y; wxToScreen(p.la, p.lo, x, y); c.fillCircle(x, y, 4, WX_MUTED); c.setTextColor(WX_MUTED); c.drawString(p.n, x + 8, y); }
}
static void wxTint(M5Canvas& c) {   // graue Karte -> dunkelblau (hell/dunkel umgekehrt, Schrift wird hell)
  uint16_t* b = (uint16_t*)c.getBuffer(); if (!b) return;
  static uint16_t lut[64]; static bool lutOk = false;
  if (!lutOk) { for (int i = 0; i < 64; i++) { float L = i * 255.0f / 63, t = fminf(1, fmaxf(0, (250 - L) / 170.0f)); t = powf(t, 0.9f);
      lut[i] = wxSwap(WXRGB((int)(8 + t * 172), (int)(22 + t * 182), (int)(46 + t * 194))); } lutOk = true; }
  for (int i = 0; i < WX_MW * WX_MH; i++) {
    uint16_t v = wxSwap(b[i]); int r = (v >> 11) << 3, g = ((v >> 5) & 63) << 2, bl = (v & 31) << 3;
    int L = (r * 77 + g * 151 + bl * 28) >> 8; b[i] = lut[L >> 2];
  }
}
static void wxLoadMap() {
  if (!wxMap) { wxMap = new M5Canvas(&M5.Display); wxMap->setPsram(true); wxMap->setColorDepth(16); wxMap->createSprite(WX_MW, WX_MH); }
  if (!wxFr) { wxFr = new M5Canvas(&M5.Display); wxFr->setPsram(true); wxFr->setColorDepth(16); wxFr->createSprite(WX_MW, WX_MH); }
  wxMapReal = false;
  if (wxMapOnSd()) {
    xSemaphoreTake(sdLock, portMAX_DELAY);
    File f = SD.open(WX_MAPFILE, FILE_READ); size_t n = f ? f.size() : 0; uint8_t* buf = n ? (uint8_t*)ps_malloc(n) : nullptr;
    if (buf && (size_t)f.read(buf, n) == n) { wxMap->fillSprite(0xFFFF); wxMapReal = wxMap->drawPng(buf, n, 0, 0); }
    if (f) f.close(); if (buf) free(buf);
    xSemaphoreGive(sdLock);
    if (wxMapReal) { wxTint(*wxMap); wxMapY = wxMapYear(); }
  }
  if (!wxMapReal) wxFallbackMap(*wxMap);
  // Entfernungsringe 10 und 25 km um Uttenreuth
  int cx = WX_MW / 2, cy = WX_MH / 2; double kmPx = 1000.0 / (WX_MPP * cos(WX_LAT * M_PI / 180));
  for (int r : {10, 25, 40}) { int rp = (int)(r * kmPx); for (int a = 0; a < 360; a += 4) { float t = a * DEG_TO_RAD; wxMap->drawPixel(cx + (int)(cosf(t) * rp), cy + (int)(sinf(t) * rp), WXRGB(90, 130, 190)); } }
}
static void wxBlendRadar(const WxRadarT& R, int f) {
  uint16_t* b = (uint16_t*)wxFr->getBuffer(); if (!b || f < 0 || f >= R.n) return;
  static uint8_t lv[WX_GMAX * WX_GMAX];
  const uint16_t* px = R.px + (size_t)f * R.W * R.H; bool any = false;
  for (int k = 0; k < R.W * R.H; k++) { lv[k] = (uint8_t)fyf::radarLevel(px[k]); any |= lv[k] != 0; }
  if (!any) return;
  // Festkomma 16.16: Raster-Index je Bildpunkt schrittweise (der P4 rechnet double nur langsam)
  const int32_t di = (int32_t)lround(R.inv[0] * 65536.0), dj = (int32_t)lround(R.inv[2] * 65536.0);
  for (int y = 0; y < WX_MH; y++) {
    double dy = y + 0.5 - R.inv[5], dx = 0.5 - R.inv[4];
    int32_t fi = (int32_t)lround((R.inv[0] * dx + R.inv[1] * dy) * 65536.0), fj = (int32_t)lround((R.inv[2] * dx + R.inv[3] * dy) * 65536.0);
    uint16_t* row = b + y * WX_MW;
    for (int x = 0; x < WX_MW; x++, fi += di, fj += dj) {
      int i = fi >> 16, j = fj >> 16;
      if ((unsigned)i >= (unsigned)R.W || (unsigned)j >= (unsigned)R.H) continue;
      int l = lv[j * R.W + i]; if (!l) continue;
      uint16_t v = wxSwap(row[x]); int a = WX_RALPHA[l];
      int r = (v >> 11) << 3, g = ((v >> 5) & 63) << 2, bl = (v & 31) << 3;
      r = (r * (255 - a) + WX_RCOL[l][0] * a) >> 8; g = (g * (255 - a) + WX_RCOL[l][1] * a) >> 8; bl = (bl * (255 - a) + WX_RCOL[l][2] * a) >> 8;
      row[x] = wxSwap(WXRGB(r, g, bl));
    }
  }
}
static void wxDrawRadar() {
  if (!wxMap) wxLoadMap();
  memcpy(wxFr->getBuffer(), wxMap->getBuffer(), (size_t)WX_MW * WX_MH * 2);
  auto& c = *wxFr;
  char s[64] = "";
  xSemaphoreTake(wxLock, portMAX_DELAY);
  int cur = wxRCur;
  if (cur >= 0 && wxRad[cur].ok) {
    const WxRadarT& R = wxRad[cur];
    if (wxFrame >= R.n) wxFrame = R.n - 1;
    wxBlendRadar(R, wxFrame);
    int dm = (int)((fyf::toEpoch(R.fy[wxFrame], R.fmo[wxFrame], R.fd[wxFrame], R.fh[wxFrame], R.fmi[wxFrame], 0) -
                    fyf::toEpoch(R.fy[R.nowI], R.fmo[R.nowI], R.fd[R.nowI], R.fh[R.nowI], R.fmi[R.nowI], 0)) / 60);
    if (dm > 0) snprintf(s, sizeof s, "%02d:%02d  Vorhersage +%d min", R.fh[wxFrame], R.fmi[wxFrame], dm);
    else if (dm == 0) snprintf(s, sizeof s, "%02d:%02d  Radar jetzt", R.fh[wxFrame], R.fmi[wxFrame]);
    else snprintf(s, sizeof s, "%02d:%02d  Radar %d min", R.fh[wxFrame], R.fmi[wxFrame], dm);
  }
  xSemaphoreGive(wxLock);
  // Uttenreuth
  int ux = WX_MW / 2, uy = WX_MH / 2;
  c.fillCircle(ux, uy, 9, WX_TEXT); c.fillCircle(ux, uy, 5, WX_ACC);
  c.setFont(&fonts::FreeSansBold12pt7b); c.setTextDatum(middle_left); c.setTextColor(WX_TEXT); c.drawString("Uttenreuth", ux + 14, uy - 2);
  // Zeit-Schild oben rechts
  c.setFont(&fonts::FreeSansBold12pt7b);
  if (!s[0]) snprintf(s, sizeof s, "%s", wifiOn() ? "Radar wird geladen ..." : "Radar: kein WLAN");
  int tw = c.textWidth(s) + 28;
  c.fillRoundRect(WX_MW - tw - 12, 14, tw, 46, 12, WX_PANEL); c.drawRoundRect(WX_MW - tw - 12, 14, tw, 46, 12, WX_LINE);
  c.setTextDatum(middle_center); c.setTextColor(WX_TEXT); c.drawString(s, WX_MW - 12 - tw / 2, 38);
  // Zurück-Knopf (im Bild, damit er beim Film nicht verschwindet)
  c.fillRoundRect(14, 14, 170, 60, 14, WX_PANEL); c.drawRoundRect(14, 14, 170, 60, 14, WX_LINE);
  c.setFont(&fonts::FreeSansBold18pt7b); c.setTextColor(WX_TEXT); c.drawString("< Zurueck", 99, 45);
  // Quellen
  c.setFont(&fonts::FreeSans9pt7b); c.setTextDatum(bottom_right);
  char q[80];
  if (wxMapReal) snprintf(q, sizeof q, "Karte (c) BKG (%d) dl-de/by-2-0  |  Radar: DWD", wxMapY ? wxMapY : 2026);
  else snprintf(q, sizeof q, "Ersatzkarte (Orte ungefaehr)  |  Radar: DWD");
  int qw = c.textWidth(q) + 16; c.fillRect(WX_MW - qw, WX_MH - 24, qw, 24, WX_BG); c.setTextColor(WX_MUTED); c.drawString(q, WX_MW - 8, WX_MH - 4);
  // Legende unten links
  c.setTextDatum(middle_left);
  c.fillRect(0, WX_MH - 24, 250, 24, WX_BG);
  for (int k = 1; k <= 8; k++) c.fillRect(8 + (k - 1) * 18, WX_MH - 18, 16, 12, WXRGB(WX_RCOL[k][0], WX_RCOL[k][1], WX_RCOL[k][2]));
  c.setTextColor(WX_MUTED); c.drawString("leicht > stark", 158, WX_MH - 12);
  c.pushSprite(0, 0);
}
// Zeitleiste unter dem Radar
static const int TL_X = 110, TL_W = 500, TL_Y = 650;
static void wxDrawTimeline() {
  auto& d = M5.Display;
  d.fillRect(0, WX_MH, WX_MW, 720 - WX_MH, WX_PANEL);
  d.drawFastHLine(0, WX_MH, WX_MW, WX_LINE);
  // Play/Pause
  d.fillRoundRect(14, WX_MH + 12, 80, 66, 14, WX_CARD);
  if (wxPlay) { d.fillRect(40, WX_MH + 28, 10, 34, WX_TEXT); d.fillRect(58, WX_MH + 28, 10, 34, WX_TEXT); }
  else d.fillTriangle(42, WX_MH + 26, 42, WX_MH + 64, 72, WX_MH + 45, WX_TEXT);
  // Neu laden
  d.fillRoundRect(626, WX_MH + 12, 80, 66, 14, WX_CARD);
  d.drawArc(666, WX_MH + 45, 18, 13, 40, 330, WX_TEXT); d.fillTriangle(672, WX_MH + 22, 688, WX_MH + 32, 672, WX_MH + 40, WX_TEXT);
  xSemaphoreTake(wxLock, portMAX_DELAY);
  int cur = wxRCur;
  if (cur >= 0 && wxRad[cur].ok && wxRad[cur].n > 1) {
    const WxRadarT& R = wxRad[cur]; int n = R.n;
    float sw = (float)TL_W / n;
    for (int k = 0; k < n; k++) {
      int x = TL_X + (int)(k * sw); int w = (int)((k + 1) * sw) - (int)(k * sw) - 1; if (w < 1) w = 1;
      d.fillRect(x, TL_Y, w, 22, k > R.nowI ? WX_FC : WX_LINE);
      if (R.fmi[k] == 0) {
        char h[6]; snprintf(h, sizeof h, "%02d", R.fh[k]);
        d.drawFastVLine(x, TL_Y + 24, 8, WX_MUTED); d.setFont(&fonts::FreeSans9pt7b); d.setTextDatum(top_center); d.setTextColor(WX_MUTED, WX_PANEL); d.drawString(h, x, TL_Y + 34);
      }
    }
    int nx = TL_X + (int)((R.nowI + 0.5f) * sw);
    d.fillTriangle(nx - 7, TL_Y - 10, nx + 7, TL_Y - 10, nx, TL_Y - 1, WX_TEXT);
    d.setFont(&fonts::FreeSans9pt7b); d.setTextDatum(bottom_center); d.setTextColor(WX_TEXT, WX_PANEL); d.drawString("jetzt", nx, TL_Y - 10);
    int kx = TL_X + (int)((wxFrame + 0.5f) * sw);
    d.fillRoundRect(kx - 6, TL_Y - 4, 12, 30, 5, WX_ACC); d.drawRoundRect(kx - 6, TL_Y - 4, 12, 30, 5, WX_TEXT);
    d.setTextDatum(top_right); d.setTextColor(WX_FC, WX_PANEL); d.drawString("Vorhersage", TL_X + TL_W, TL_Y + 50);
  } else {
    d.setFont(&fonts::FreeSans12pt7b); d.setTextDatum(middle_left); d.setTextColor(WX_MUTED, WX_PANEL); d.drawString(wxStat, TL_X, WX_MH + 45);
  }
  xSemaphoreGive(wxLock);
}

// ---------- Zeichnen: bewegte Wettersymbole ----------
static void wxCloud(LovyanGFX& c, float cx, float cy, float w, uint16_t col) {
  c.fillCircle((int)(cx - w * 0.24f), (int)(cy + w * 0.04f), (int)(w * 0.2f), col);
  c.fillCircle((int)(cx + w * 0.02f), (int)(cy - w * 0.1f), (int)(w * 0.27f), col);
  c.fillCircle((int)(cx + w * 0.26f), (int)(cy + w * 0.06f), (int)(w * 0.18f), col);
  c.fillRoundRect((int)(cx - w * 0.44f), (int)(cy + w * 0.02f), (int)(w * 0.88f), (int)(w * 0.22f), (int)(w * 0.11f), col);
}
static void wxSun(LovyanGFX& c, float cx, float cy, float r, float ph) {
  float rot = ph * 0.6f, pulse = 1 + 0.08f * sinf(ph * 3);
  for (int k = 0; k < 8; k++) {
    float a = rot + k * (float)M_PI / 4;
    c.drawWideLine(cx + cosf(a) * r * 1.3f, cy + sinf(a) * r * 1.3f, cx + cosf(a) * r * 1.3f * pulse * 1.35f, cy + sinf(a) * r * 1.3f * pulse * 1.35f, fmaxf(1.5f, r * 0.11f), WX_SUN);
  }
  c.fillCircle((int)cx, (int)cy, (int)r, WX_SUN);
}
static void wxMoon(LovyanGFX& c, float cx, float cy, float r, uint16_t bg, float ph) {
  c.fillCircle((int)cx, (int)cy, (int)r, WX_MOON); c.fillCircle((int)(cx + r * 0.45f), (int)(cy - r * 0.3f), (int)(r * 0.85f), bg);
  for (int k = 0; k < 3; k++) { float tw = 0.5f + 0.5f * sinf(ph * 2.5f + k * 2.1f); int sr = (int)(1 + tw * r * 0.09f);
    c.fillCircle((int)(cx + r * (0.9f + 0.35f * k)), (int)(cy - r * (0.9f - 0.55f * k)), sr, WX_MOON); }
}
static void wxDrops(LovyanGFX& c, float cx, float top, float w, float h, float ph, int kind) {   // kind 0 Regen, 1 Schnee, 2 Schneeregen, 3 Hagel
  for (int k = 0; k < 5; k++) {
    float x = cx - w * 0.36f + k * w * 0.18f;
    float sp = kind == 1 ? 0.35f : kind == 3 ? 1.4f : 0.9f;
    float t = fmodf(ph * sp + k * 0.37f, 1.0f), y = top + t * h;
    int kk = kind == 2 ? (k & 1) : kind;
    if (kk == 0) c.drawWideLine(x, y, x - w * 0.04f, y + w * 0.11f, fmaxf(1.2f, w * 0.025f), WX_DROP);
    else if (kk == 1) { float sx = x + sinf(ph * 2 + k) * w * 0.04f; int r = (int)fmaxf(2, w * 0.035f);
      c.drawLine((int)(sx - r), (int)y, (int)(sx + r), (int)y, WX_TEXT); c.drawLine((int)sx, (int)(y - r), (int)sx, (int)(y + r), WX_TEXT);
      c.drawLine((int)(sx - r * 0.7f), (int)(y - r * 0.7f), (int)(sx + r * 0.7f), (int)(y + r * 0.7f), WX_TEXT); c.drawLine((int)(sx - r * 0.7f), (int)(y + r * 0.7f), (int)(sx + r * 0.7f), (int)(y - r * 0.7f), WX_TEXT); }
    else c.fillCircle((int)x, (int)y, (int)fmaxf(2, w * 0.035f), WX_TEXT);
  }
}
// Symbol in eine Leinwand zeichnen. s = Größe (Breite) in Bildpunkten, ph = Zeit in Sekunden (für die Bewegung)
static void wxIcon(LovyanGFX& c, int code, float cx, float cy, float s, float ph, uint16_t bg) {
  float drift = sinf(ph * 0.8f) * s * 0.03f;
  switch (code) {
    case fyf::WX_CLEAR_D: wxSun(c, cx, cy, s * 0.22f, ph); break;
    case fyf::WX_CLEAR_N: wxMoon(c, cx - s * 0.08f, cy + s * 0.04f, s * 0.26f, bg, ph); break;
    case fyf::WX_PART_D: wxSun(c, cx - s * 0.14f, cy - s * 0.12f, s * 0.16f, ph); wxCloud(c, cx + s * 0.08f + drift, cy + s * 0.12f, s * 0.62f, WX_CLOUD); break;
    case fyf::WX_PART_N: wxMoon(c, cx - s * 0.14f, cy - s * 0.12f, s * 0.18f, bg, ph); wxCloud(c, cx + s * 0.08f + drift, cy + s * 0.12f, s * 0.62f, WX_CLOUD); break;
    case fyf::WX_CLOUDY: wxCloud(c, cx - s * 0.12f - drift, cy - s * 0.1f, s * 0.55f, WX_CLOUD_D); wxCloud(c, cx + s * 0.08f + drift, cy + s * 0.08f, s * 0.7f, WX_CLOUD); break;
    case fyf::WX_FOG:
      wxCloud(c, cx, cy - s * 0.16f, s * 0.6f, WX_CLOUD_D);
      for (int k = 0; k < 3; k++) { float o = sinf(ph * 1.2f + k) * s * 0.06f; c.fillRoundRect((int)(cx - s * 0.36f + o), (int)(cy + s * (0.1f + k * 0.12f)), (int)(s * 0.72f), (int)fmaxf(3, s * 0.06f), (int)fmaxf(1, s * 0.03f), WX_CLOUD); }
      break;
    case fyf::WX_WIND:
      for (int k = 0; k < 3; k++) { float o = fmodf(ph * 0.6f + k * 0.33f, 1.0f) * s * 0.2f - s * 0.1f, y = cy - s * 0.18f + k * s * 0.18f, L = s * (0.55f - k * 0.08f);
        c.drawWideLine(cx - s * 0.36f + o, y, cx - s * 0.36f + o + L, y, fmaxf(1.5f, s * 0.03f), WX_CLOUD);
        c.drawCircle((int)(cx - s * 0.36f + o + L + s * 0.02f), (int)(y - s * 0.05f), (int)fmaxf(2, s * 0.05f), WX_CLOUD); }
      break;
    case fyf::WX_RAIN: case fyf::WX_SLEET: case fyf::WX_SNOW: case fyf::WX_HAIL: {
      int kind = code == fyf::WX_RAIN ? 0 : code == fyf::WX_SNOW ? 1 : code == fyf::WX_SLEET ? 2 : 3;
      wxDrops(c, cx, cy + s * 0.1f, s * 0.7f, s * 0.36f, ph, kind);
      wxCloud(c, cx + drift, cy - s * 0.12f, s * 0.75f, WX_CLOUD); break; }
    case fyf::WX_THUNDER: {
      wxDrops(c, cx, cy + s * 0.1f, s * 0.7f, s * 0.36f, ph, 0);
      float t = fmodf(ph, 2.4f); bool fl = t < 0.12f || (t > 0.25f && t < 0.33f);
      uint16_t bc = fl ? WXRGB(255, 240, 140) : WX_SUN;
      float bx = cx + s * 0.02f, by = cy + s * 0.02f;
      c.fillTriangle((int)(bx + s * 0.06f), (int)(by - s * 0.04f), (int)(bx - s * 0.1f), (int)(by + s * 0.2f), (int)(bx + s * 0.02f), (int)(by + s * 0.17f), bc);
      c.fillTriangle((int)(bx + s * 0.02f), (int)(by + s * 0.13f), (int)(bx + s * 0.12f), (int)(by + s * 0.13f), (int)(bx - s * 0.06f), (int)(by + s * 0.4f), bc);
      wxCloud(c, cx + drift, cy - s * 0.12f, s * 0.75f, fl ? WX_CLOUD : WX_CLOUD_D); break; }
    default: c.setFont(&fonts::FreeSansBold18pt7b); c.setTextDatum(middle_center); c.setTextColor(WX_MUTED); c.drawString("?", (int)cx, (int)cy); break;
  }
}
static void wxDeg(LovyanGFX& d, int x, int y, int r, uint16_t col) { d.drawCircle(x, y, r, col); d.drawCircle(x, y, r - 1, col); if (r > 5) d.drawCircle(x, y, r - 2, col); }
static void wxFmt1(char* s, int n, float v) { if (isnan(v)) snprintf(s, n, "-"); else { snprintf(s, n, "%.1f", v); commaify(s); } }

// ---------- Zeichnen: rechte Seite ----------
static const int PX = 734, PW = 534;
static WxNowT wxSnapNow; static fyf::WxDay wxSnapDays[5]; static int wxSnapND = 0; static fyf::WxHour wxSnapH[6]; static int wxSnapNH = 0; static fyf::WxDay wxSnapToday;
static WxAlertT wxSnapAl[4]; static int wxSnapNA = 0;
static void wxSnapshot() {
  fyf::DT t = nowDT();
  xSemaphoreTake(wxLock, portMAX_DELAY);
  wxSnapNow = wxNow; wxSnapNA = wxNA; memcpy(wxSnapAl, wxAl, sizeof wxAl);
  fyf::dayAggregate(wxHours, wxNH, t.y, t.mo, t.d, wxSnapToday);
  wxSnapND = 0; long day = fyf::daysFromCivil(t.y, t.mo, t.d);
  for (int k = 1; k <= 3; k++) { int y, mo, d; fyf::civilFromDays(day + k, y, mo, d); fyf::WxDay dd; if (fyf::dayAggregate(wxHours, wxNH, y, mo, d, dd) >= 12) wxSnapDays[wxSnapND++] = dd; }
  // nächste Stunden (alle 2 Std.)
  wxSnapNH = 0; long long nowE = fyf::toEpoch(t.y, t.mo, t.d, t.h, 0, 0);
  for (int i = 0; i < wxNH && wxSnapNH < 6; i++) {
    const fyf::WxHour& h = wxHours[i]; long long e = fyf::toEpoch(h.y, h.mo, h.d, h.h, 0, 0);
    if (e > nowE && ((h.h - t.h + 24) % 2) == 1) wxSnapH[wxSnapNH++] = h;
  }
  xSemaphoreGive(wxLock);
}
static void wxDrawClock() {
  auto& d = M5.Display; fyf::DT t = nowDT(); wxLastMin = t.mi;
  d.fillRect(PX, 8, PW, 104, WX_BG);
  char s[48]; snprintf(s, sizeof s, "%02d:%02d", t.h, t.mi);
  d.setFont(&fonts::FreeSansBold24pt7b); d.setTextSize(2.1f); d.setTextDatum(top_left); d.setTextColor(WX_TEXT, WX_BG); d.drawString(s, PX, 14); d.setTextSize(1);
  d.setFont(&fonts::FreeSansBold18pt7b); d.setTextDatum(top_right); d.drawString(WD_NAME[t.wd], PX + PW, 18);
  snprintf(s, sizeof s, "%d. %s", t.d, MO_NAME[t.mo - 1]); d.setFont(&fonts::FreeSans18pt7b); d.setTextColor(WX_MUTED, WX_BG); d.drawString(s, PX + PW, 56);
  d.setFont(&fonts::FreeSans12pt7b); d.drawString("Uttenreuth", PX + PW, 92);
}
static void wxDrawAlertBar() {
  auto& d = M5.Display; int y = 118, h = 50;
  d.fillRect(PX, y, PW, h, WX_BG);
  d.setFont(&fonts::FreeSansBold12pt7b); d.setTextDatum(middle_left);
  if (wxSnapNA > 0) {
    const WxAlertT& a = wxSnapAl[0]; uint16_t bg = WX_ALCOL[a.level], fg = a.level <= 2 ? WX_BG : WX_TEXT;
    d.fillRoundRect(PX, y, PW, h, 12, bg);
    char s[60]; snprintf(s, sizeof s, "%s", a.event);
    for (char* p = s; *p; p++) *p = (char)toupper((unsigned char)*p);
    while (d.textWidth(s) > PW - 150 && strlen(s) > 4) { s[strlen(s) - 4] = 0; strcat(s, "..."); }
    d.setTextColor(fg, bg); d.drawString(s, PX + 16, y + h / 2);
    d.setFont(&fonts::FreeSans12pt7b); d.setTextDatum(middle_right);
    char r[24]; if (wxSnapNA > 1) snprintf(r, sizeof r, "+%d  Mehr >", wxSnapNA - 1); else snprintf(r, sizeof r, "Mehr >");
    d.drawString(r, PX + PW - 14, y + h / 2);
  } else {
    d.fillRoundRect(PX, y, PW, h, 12, WX_PANEL);
    d.setTextColor(WX_MUTED, WX_PANEL); d.setFont(&fonts::FreeSans12pt7b);
    d.drawString(wxAlOk ? "Keine Wetterwarnung des DWD fuer Uttenreuth" : "Warnungen: noch keine Daten", PX + 16, y + h / 2);
  }
}
static void wxDrawNow() {
  auto& d = M5.Display; int y = 176;
  d.fillRect(PX, y, PW, 172, WX_BG);
  const WxNowT& n = wxSnapNow;
  if (!n.ok) {
    d.setFont(&fonts::FreeSansBold18pt7b); d.setTextDatum(top_left); d.setTextColor(WX_TEXT, WX_BG); d.drawString("Lade Wetter ...", PX, y + 20);
    d.setFont(&fonts::FreeSans12pt7b); d.setTextColor(WX_MUTED, WX_BG); drawWrapped(wxStat, PX, y + 70, PW, 30);
    return;
  }
  char s[32]; wxFmt1(s, sizeof s, n.temp);
  int tx = PX + 186;
  d.setFont(&fonts::FreeSansBold24pt7b); d.setTextSize(2.2f); d.setTextDatum(top_left); d.setTextColor(WX_TEXT, WX_BG); d.drawString(s, tx, y + 6);
  int w = d.textWidth(s); d.setTextSize(1); wxDeg(d, tx + w + 14, y + 22, 9, WX_TEXT);
  d.setFont(&fonts::FreeSansBold18pt7b); d.drawString("C", tx + w + 28, y + 12);
  d.setFont(&fonts::FreeSans18pt7b); d.setTextColor(WX_ACC, WX_BG); d.drawString(fyf::wxText(n.icon), tx, y + 96);
  char m[64]; snprintf(m, sizeof m, "Messung %02d:%02d Uhr", n.h, n.mi);
  if (!isnan(n.press)) { char p[16]; snprintf(p, sizeof p, "  |  %d hPa", (int)lroundf(n.press)); strncat(m, p, sizeof m - strlen(m) - 1); }
  d.setFont(&fonts::FreeSans12pt7b); d.setTextColor(WX_MUTED, WX_BG); d.drawString(m, tx, y + 138);
}
static void wxTile(int x, int y, int w, int h, const char* title) {
  auto& d = M5.Display; d.fillRoundRect(x, y, w, h, 14, WX_CARD);
  d.setFont(&fonts::FreeSans9pt7b); d.setTextDatum(top_left); d.setTextColor(WX_MUTED, WX_CARD); d.drawString(title, x + 12, y + 8);
}
static void wxDrawArrow(int cx, int cy, float deg, int r, uint16_t col, uint16_t bg) {   // Pfeil zeigt, wohin der Wind weht
  auto& d = M5.Display; d.fillCircle(cx, cy, r + 3, bg); d.drawCircle(cx, cy, r + 2, WX_LINE);
  if (isnan(deg)) return;
  float a = (deg + 180 - 90) * DEG_TO_RAD, nx = cosf(a), ny = sinf(a), px = -ny, py = nx;
  d.fillTriangle((int)(cx + nx * r), (int)(cy + ny * r), (int)(cx - nx * r * 0.5f + px * r * 0.5f), (int)(cy - ny * r * 0.5f + py * r * 0.5f),
                 (int)(cx - nx * r * 0.5f - px * r * 0.5f), (int)(cy - ny * r * 0.5f - py * r * 0.5f), col);
  d.fillTriangle((int)(cx - nx * r * 0.2f), (int)(cy - ny * r * 0.2f), (int)(cx - nx * r * 0.5f + px * r * 0.5f), (int)(cy - ny * r * 0.5f + py * r * 0.5f),
                 (int)(cx - nx * r * 0.5f - px * r * 0.5f), (int)(cy - ny * r * 0.5f - py * r * 0.5f), bg);
}
static float wxWindWobble = 0;
static void wxDrawTiles() {
  auto& d = M5.Display; int y = 356, h = 110, tw = (PW - 20) / 3; const WxNowT& n = wxSnapNow; char s[40], s2[48];
  d.fillRect(PX, y, PW, h, WX_BG);
  // Wind
  wxTile(PX, y, tw, h, "WIND");
  if (isnan(n.wind)) snprintf(s, sizeof s, "-"); else snprintf(s, sizeof s, "%d km/h", (int)lroundf(n.wind));
  d.setFont(&fonts::FreeSansBold18pt7b); d.setTextDatum(top_left); d.setTextColor(WX_TEXT, WX_CARD); d.drawString(s, PX + 12, y + 32);
  if (isnan(n.gust)) snprintf(s2, sizeof s2, "%s", fyf::windDir8(n.wdir)); else snprintf(s2, sizeof s2, "%s, Boeen %d", fyf::windDir8(n.wdir), (int)lroundf(n.gust));
  d.setFont(&fonts::FreeSans12pt7b); d.setTextColor(WX_MUTED, WX_CARD); d.drawString(s2, PX + 12, y + 74);
  wxDrawArrow(PX + tw - 28, y + 24, n.wdir, 14, WX_ACC, WX_CARD);
  // Feuchte
  int x2 = PX + tw + 10; wxTile(x2, y, tw, h, "FEUCHTE");
  if (isnan(n.hum)) snprintf(s, sizeof s, "-"); else snprintf(s, sizeof s, "%d %%", (int)lroundf(n.hum));
  d.setFont(&fonts::FreeSansBold18pt7b); d.setTextColor(WX_TEXT, WX_CARD); d.drawString(s, x2 + 12, y + 32);
  char dp[16]; wxFmt1(dp, sizeof dp, n.dew); snprintf(s2, sizeof s2, "Taupunkt %s", dp);
  d.setFont(&fonts::FreeSans12pt7b); d.setTextColor(WX_MUTED, WX_CARD); d.drawString(s2, x2 + 12, y + 74);
  d.fillCircle(x2 + tw - 26, y + 30, 9, WX_DROP); d.fillTriangle(x2 + tw - 34, y + 26, x2 + tw - 18, y + 26, x2 + tw - 26, y + 10, WX_DROP);
  // Sonne
  int x3 = PX + 2 * (tw + 10); wxTile(x3, y, tw, h, "SONNE");
  fyf::DT t = nowDT(); double r, st;
  if (fyf::sunTimes(t.y, t.mo, t.d, WX_LAT, WX_LON, r, st)) {
    int ri = (int)lround(r), si = (int)lround(st);
    snprintf(s, sizeof s, "%02d:%02d", ri / 60, ri % 60); d.setFont(&fonts::FreeSansBold12pt7b); d.setTextColor(WX_TEXT, WX_CARD); d.drawString(s, x3 + 40, y + 34);
    snprintf(s, sizeof s, "%02d:%02d", si / 60, si % 60); d.drawString(s, x3 + 40, y + 62);
    d.fillTriangle(x3 + 14, y + 50, x3 + 30, y + 50, x3 + 22, y + 38, WX_SUN); d.fillTriangle(x3 + 14, y + 66, x3 + 30, y + 66, x3 + 22, y + 78, WX_CLOUD_D);
  }
  if (wxSnapToday.nh) { char hs[16]; wxFmt1(hs, sizeof hs, wxSnapToday.sunMin / 60.0f); snprintf(s2, sizeof s2, "heute %s Std.", hs); d.setFont(&fonts::FreeSans9pt7b); d.setTextColor(WX_MUTED, WX_CARD); d.drawString(s2, x3 + 12, y + 88); }
}
static void wxDrawToday() {
  auto& d = M5.Display; int y = 474, h = 116;
  d.fillRoundRect(PX, y, PW, h, 14, WX_PANEL);
  d.setFont(&fonts::FreeSansBold12pt7b); d.setTextDatum(top_left); d.setTextColor(WX_TEXT, WX_PANEL); d.drawString("HEUTE", PX + 14, y + 8);
  if (wxSnapToday.nh) {
    char a[16], b[16], s[80]; snprintf(a, sizeof a, "%d", (int)lroundf(wxSnapToday.tmin)); snprintf(b, sizeof b, "%d", (int)lroundf(wxSnapToday.tmax));
    char p[16]; wxFmt1(p, sizeof p, wxSnapToday.prec);
    snprintf(s, sizeof s, "Min %s  Max %s  Regen %s mm", a, b, p);
    d.setFont(&fonts::FreeSans12pt7b); d.setTextColor(WX_MUTED, WX_PANEL); d.setTextDatum(top_right); d.drawString(s, PX + PW - 14, y + 9);
  }
  if (!wxSnapNH) { d.setFont(&fonts::FreeSans12pt7b); d.setTextDatum(top_left); d.setTextColor(WX_MUTED, WX_PANEL); d.drawString(wxFcOk ? "keine Stunden mehr heute" : "Vorhersage wird geladen ...", PX + 14, y + 50); return; }
  int sw = (PW - 20) / 6;
  M5Canvas ic(&d); ic.setPsram(true); ic.createSprite(44, 44);
  for (int i = 0; i < wxSnapNH; i++) {
    const fyf::WxHour& hr = wxSnapH[i]; int x = PX + 10 + i * sw;
    char s[16]; snprintf(s, sizeof s, "%02d Uhr", hr.h);
    d.setFont(&fonts::FreeSans9pt7b); d.setTextDatum(top_center); d.setTextColor(WX_MUTED, WX_PANEL); d.drawString(s, x + sw / 2, y + 36);
    ic.fillSprite(WX_PANEL); wxIcon(ic, hr.icon, 22, 22, 44, 0, WX_PANEL); ic.pushSprite(x + sw / 2 - 40, y + 58);
    snprintf(s, sizeof s, "%d", (int)lroundf(hr.temp)); d.setFont(&fonts::FreeSansBold12pt7b); d.setTextDatum(middle_left); d.setTextColor(WX_TEXT, WX_PANEL);
    d.drawString(s, x + sw / 2 + 6, y + 72); wxDeg(d, x + sw / 2 + 8 + d.textWidth(s) + 3, y + 64, 3, WX_TEXT);
    if (!isnan(hr.prob) && hr.prob >= 20) { snprintf(s, sizeof s, "%d%%", (int)lroundf(hr.prob)); d.setFont(&fonts::FreeSans9pt7b); d.setTextColor(WX_DROP, WX_PANEL); d.drawString(s, x + sw / 2 + 6, y + 96); }
  }
  ic.deleteSprite();
}
static M5Canvas* wxIcBig = nullptr; static M5Canvas* wxIcDay = nullptr;
static void wxDrawDays(float ph, bool full) {
  auto& d = M5.Display; int y = 598, h = 116, cw = (PW - 20) / 3;
  if (!wxIcDay) { wxIcDay = new M5Canvas(&d); wxIcDay->setPsram(true); wxIcDay->createSprite(84, 84); }
  for (int k = 0; k < 3; k++) {
    int x = PX + k * (cw + 10);
    if (full) {
      d.fillRoundRect(x, y, cw, h, 14, WX_CARD);
      if (k >= wxSnapND) { d.setFont(&fonts::FreeSans12pt7b); d.setTextDatum(middle_center); d.setTextColor(WX_MUTED, WX_CARD); d.drawString("-", x + cw / 2, y + h / 2); continue; }
      const fyf::WxDay& dd = wxSnapDays[k]; char s[32];
      snprintf(s, sizeof s, "%s %d.%d.", WD_SHORT[dd.wd], dd.d, dd.mo);
      d.setFont(&fonts::FreeSansBold12pt7b); d.setTextDatum(top_left); d.setTextColor(WX_TEXT, WX_CARD); d.drawString(s, x + 12, y + 8);
      snprintf(s, sizeof s, "%d", (int)lroundf(dd.tmax)); d.setFont(&fonts::FreeSansBold18pt7b); d.setTextDatum(top_right); d.drawString(s, x + cw - 14, y + 40);
      snprintf(s, sizeof s, "%d", (int)lroundf(dd.tmin)); d.setFont(&fonts::FreeSans12pt7b); d.setTextColor(WX_MUTED, WX_CARD); d.drawString(s, x + cw - 14, y + 74);
      if (!isnan(dd.probMax) && dd.probMax >= 20) { snprintf(s, sizeof s, "%d%%", (int)lroundf(dd.probMax)); d.setFont(&fonts::FreeSans9pt7b); d.setTextColor(WX_DROP, WX_CARD); d.setTextDatum(top_left); d.drawString(s, x + 12, y + 96); }
    }
    if (k < wxSnapND) { wxIcDay->fillSprite(WX_CARD); wxIcon(*wxIcDay, wxSnapDays[k].icon, 42, 42, 76, ph + k * 0.7f, WX_CARD); wxIcDay->pushSprite(x + 8, y + 26); }
  }
}
static void wxDrawBigIcon(float ph) {
  if (!wxIcBig) { wxIcBig = new M5Canvas(&M5.Display); wxIcBig->setPsram(true); wxIcBig->createSprite(176, 168); }
  wxIcBig->fillSprite(WX_BG);
  if (wxSnapNow.ok) wxIcon(*wxIcBig, wxSnapNow.icon, 88, 84, 168, ph, WX_BG);
  wxIcBig->pushSprite(PX - 6, 178);
}
static void wxDrawAlertDetail() {
  auto& d = M5.Display; int x = PX - 10, y = 110, w = PW + 20, h = 604;
  d.fillRoundRect(x, y, w, h, 18, WX_PANEL); d.drawRoundRect(x, y, w, h, 18, WX_LINE);
  int yy = y + 16;
  for (int i = 0; i < wxSnapNA && yy < y + h - 80; i++) {
    const WxAlertT& a = wxSnapAl[i];
    d.fillRoundRect(x + 14, yy, w - 28, 40, 10, WX_ALCOL[a.level]);
    d.setFont(&fonts::FreeSansBold12pt7b); d.setTextDatum(middle_left); d.setTextColor(a.level <= 2 ? WX_BG : WX_TEXT, WX_ALCOL[a.level]); d.drawString(a.event, x + 26, yy + 20);
    yy += 48; d.setFont(&fonts::FreeSans12pt7b); d.setTextDatum(top_left); d.setTextColor(WX_TEXT, WX_PANEL); d.drawString(a.when, x + 20, yy); yy += 30;
    if (i == 0) { d.setFont(&fonts::FreeSans12pt7b); d.setTextColor(WX_MUTED, WX_PANEL);
      // eigener Umbruch mit Höhenbegrenzung
      char line[128] = ""; const char* p = a.desc; int lines = 0;
      while (*p && lines < 9) {
        char word[64]; int n = 0; while (*p == ' ' || *p == '\n') p++; while (*p && *p != ' ' && *p != '\n' && n < 63) word[n++] = *p++; word[n] = 0; if (!n) break;
        char test[200]; snprintf(test, sizeof test, line[0] ? "%s %s" : "%s%s", line, word);
        if (d.textWidth(test) > w - 40 && line[0]) { d.drawString(line, x + 20, yy); yy += 28; lines++; snprintf(line, sizeof line, "%s", word); } else snprintf(line, sizeof line, "%s", test);
      }
      if (line[0] && lines < 9) { d.drawString(line, x + 20, yy); yy += 28; }
      yy += 10; }
  }
  d.setFont(&fonts::FreeSans9pt7b); d.setTextDatum(bottom_left); d.setTextColor(WX_MUTED, WX_PANEL); d.drawString("Quelle: Deutscher Wetterdienst. Antippen zum Schliessen.", x + 20, y + h - 12);
}
static void wxDrawPanel() {
  wxSnapshot();
  if (wxAlertOpen) { wxDrawClock(); wxDrawAlertDetail(); return; }
  wxDrawClock(); wxDrawAlertBar(); wxDrawNow(); wxDrawTiles(); wxDrawToday(); wxDrawDays(millis() / 1000.0f, true); wxDrawBigIcon(millis() / 1000.0f);
}
static void drawWx() {
  auto& d = M5.Display; d.fillScreen(WX_BG); nBtns = 0;
  wxRadarUntil = millis() + 180000UL;
  if (sdOk && !wxMapOnSd() && wifiOn()) wxMapWanted = true;
  if (!wxMap) wxLoadMap();
  xSemaphoreTake(wxLock, portMAX_DELAY); if (wxRCur >= 0) wxFrame = wxRad[wxRCur].nowI; xSemaphoreGive(wxLock);
  wxDrawRadar(); wxDrawTimeline(); wxDrawPanel();
  addBtn(14, 14, 170, 60, "", 0, C_CARD, C_TEXT, false);
  addBtn(14, WX_MH + 12, 80, 66, "", 2500, C_CARD, C_TEXT, false);
  addBtn(626, WX_MH + 12, 80, 66, "", 2501, C_CARD, C_TEXT, false);
  addBtn(TL_X - 10, WX_MH + 2, TL_W + 20, 86, "", 2510, C_CARD, C_TEXT, false);
  addBtn(PX, 118, PW, 50, "", 2502, C_CARD, C_TEXT, false);
  if (wxAlertOpen) addBtn(PX - 10, 110, PW + 20, 604, "", 2503, C_CARD, C_TEXT, false);
  wxLastFrame = millis(); wxLastAnim = 0;
}
static int lastTapX = 0;
static void wxScrub(int x) {
  xSemaphoreTake(wxLock, portMAX_DELAY); int n = wxRCur >= 0 ? wxRad[wxRCur].n : 0; xSemaphoreGive(wxLock);
  if (n < 1) return;
  int f = (int)((x - TL_X) * n / (float)TL_W); f = constrain(f, 0, n - 1);
  if (f != wxFrame) { wxFrame = f; wxDrawRadar(); wxDrawTimeline(); }
}
static void wxTick() {
  uint32_t ms = millis();
  wxRadarUntil = ms + 180000UL;
  if (wxDMap) { wxDMap = false; wxLoadMap(); wxDrawRadar(); }
  if (wxDRad) { wxDRad = false; xSemaphoreTake(wxLock, portMAX_DELAY); if (wxRCur >= 0 && !wxPlay) wxFrame = wxRad[wxRCur].nowI; xSemaphoreGive(wxLock); wxDrawRadar(); wxDrawTimeline(); }
  if (wxDNow || wxDFc || wxDAl) { wxDNow = wxDFc = wxDAl = false; wxDrawPanel(); }
  // Ziehen auf der Zeitleiste
  auto t = M5.Touch.getDetail();
  if (t.isPressed() && t.y > WX_MH && t.x > TL_X - 10 && t.x < TL_X + TL_W + 10) { wxPlay = false; wxScrub(t.x); }
  // Radar-Film
  if (wxPlay) {
    xSemaphoreTake(wxLock, portMAX_DELAY); int n = wxRCur >= 0 ? wxRad[wxRCur].n : 0; xSemaphoreGive(wxLock);
    if (n > 1 && ms - wxLastFrame > (uint32_t)(wxFrame == n - 1 ? 1800 : 380)) { wxLastFrame = ms; wxFrame = (wxFrame + 1) % n; wxDrawRadar(); wxDrawTimeline(); }
  }
  // bewegte Symbole
  if (!wxAlertOpen && ms - wxLastAnim > 90) { wxLastAnim = ms; float ph = ms / 1000.0f; wxDrawBigIcon(ph); wxDrawDays(ph, false); }
  fyf::DT n = nowDT();
  if (n.mi != wxLastMin) { wxDrawClock(); if (n.mi % 10 == 0 && !wxAlertOpen) wxDrawPanel(); }
}

// ---------- SICHERUNG auf SD-Karte ----------
static char sdMsg[120] = ""; static bool sdAuto = true; static char sdSel[24] = ""; static bool sdConfirm = false;
static char sdList[6][24]; static int sdN = 0; static char sdLast[24] = "";
static uint64_t sdFreeB = 0, sdTotalB = 0;
static int consCopyAll(fs::FS& from, const char* fromDir, fs::FS& to, const char* toDir);
static bool fsCopy(fs::FS& a, const char* pa, fs::FS& b, const char* pb) {
  File src = a.open(pa, "r"); if (!src) return false;
  File dst = b.open(pb, "w"); if (!dst) { src.close(); return false; }
  uint8_t buf[512]; bool ok = true; int r;
  while ((r = src.read(buf, sizeof buf)) > 0) if ((int)dst.write(buf, r) != r) { ok = false; break; }
  src.close(); dst.close(); return ok;
}
static void sdScan() {   // Sicherungen auflisten (neueste zuerst) – sdLock muss gehalten werden
  sdN = 0; sdLast[0] = 0;
  char all[60][24]; int na = 0;
  File dir = SD.open("/FYF/Sicherung");
  if (dir && dir.isDirectory()) {
    File e; while ((e = dir.openNextFile()) && na < 60) { if (e.isDirectory()) { const char* nm = e.name(); const char* sl = strrchr(nm, '/'); snprintf(all[na++], 24, "%s", sl ? sl + 1 : nm); } e.close(); }
    dir.close();
  }
  for (int i = 1; i < na; i++) { char k[24]; memcpy(k, all[i], 24); int j = i - 1; while (j >= 0 && strcmp(all[j], k) < 0) { memcpy(all[j + 1], all[j], 24); j--; } memcpy(all[j + 1], k, 24); }
  for (int i = 0; i < na && sdN < 6; i++) memcpy(sdList[sdN++], all[i], 24);
  if (na) memcpy(sdLast, all[0], 24);
  // älter als die 10 neuesten: löschen
  for (int i = 10; i < na; i++) {
    char p[64];
    for (const char* sub : {"k", "e"}) {
      snprintf(p, sizeof p, "/FYF/Sicherung/%s/%s", all[i], sub);
      File kd = SD.open(p); if (kd) { File e; while ((e = kd.openNextFile())) { char fp[96]; snprintf(fp, sizeof fp, "%s/%s", p, strrchr(e.name(), '/') ? strrchr(e.name(), '/') + 1 : e.name()); e.close(); SD.remove(fp); } kd.close(); }
      SD.rmdir(p);
    }
    snprintf(p, sizeof p, "/FYF/Sicherung/%s/aktuell.txt", all[i]); SD.remove(p);
    snprintf(p, sizeof p, "/FYF/Sicherung/%s", all[i]); SD.rmdir(p);
  }
  sdTotalB = SD.totalBytes(); sdFreeB = sdTotalB - SD.usedBytes();
}
static void sdNice(const char* nm, char* out, int cap) {   // "2026-11-21_0115" -> "21.11.2026 01:15"
  if (strlen(nm) >= 15) snprintf(out, cap, "%.2s.%.2s.%.4s %.2s:%.2s%s", nm + 8, nm + 5, nm, nm + 11, nm + 13, nm[15] ? " (vorher)" : "");
  else snprintf(out, cap, "%s", nm);
}
static bool sdBackup(const char* suffix) {
  if (!sdOk) { snprintf(sdMsg, sizeof sdMsg, "Keine SD-Karte erkannt."); return false; }
  if (!fsOk) { snprintf(sdMsg, sizeof sdMsg, "Interner Speicher fehlt."); return false; }
  fyf::DT t = nowDT(); char nm[24], base[64], p[96];
  snprintf(nm, sizeof nm, "%04d-%02d-%02d_%02d%02d%s", t.y, t.mo, t.d, t.h, t.mi, suffix ? suffix : "");
  snprintf(base, sizeof base, "/FYF/Sicherung/%s", nm);
  xSemaphoreTake(sdLock, portMAX_DELAY);
  if (!SD.exists("/FYF")) SD.mkdir("/FYF");
  if (!SD.exists("/FYF/Sicherung")) SD.mkdir("/FYF/Sicherung");
  SD.mkdir(base); snprintf(p, sizeof p, "%s/k", base); SD.mkdir(p);
  int nk = 0; bool ok = true;
  for (int id = 1; id <= 99; id++) {
    char lp[24]; custPath(lp, sizeof lp, id); if (!LittleFS.exists(lp)) continue;
    snprintf(p, sizeof p, "%s/k/%d.txt", base, id);
    if (fsCopy(LittleFS, lp, SD, p)) nk++; else ok = false;
  }
  // Einwilligungen mit Unterschrift
  snprintf(p, sizeof p, "%s/e", base); SD.mkdir(p); int ne = consCopyAll(LittleFS, "/e", SD, p);
  // laufendes Fitting und Einstellungen (ohne WLAN-Passwort und Kopplung)
  snprintf(p, sizeof p, "%s/aktuell.txt", base);
  File f = SD.open(p, FILE_WRITE);
  if (f) {
    char line[320]; f.printf("FYF-Sicherung|%s|%02d.%02d.%04d %02d:%02d\n", VERSION, t.d, t.mo, t.y, t.h, t.mi);
    fyf::fitLine("aktuell", vals[0], vals[1], line, sizeof line); f.print(line);
    f.print("FLOW|"); for (int i = 0; i < NS; i++) f.print((int)flowSt[i]); f.print("\n");
    f.print("OBS|"); for (int i = 0; i < NO; i++) f.printf("%u%s", obsMin[i], i < NO - 1 ? ";" : "\n");
    f.print("CHK|"); for (int i = 0; i < NCHK; i++) f.print((int)chk[i]); f.print("\n");
    f.printf("SET|%d|%d|%d|%.2f|%d|%d|%d\n", bright, sound, invertAngle, angleOffset, side, saverMin, activeCust);
    f.close();
  } else ok = false;
  sdScan();
  xSemaphoreGive(sdLock);
  if (ok) { char n2[32]; sdNice(nm, n2, sizeof n2); snprintf(sdMsg, sizeof sdMsg, "Gesichert: %d Kunden mit Fittings, %d Einwilligungen, laufendes Fitting (%s).", nk, ne, n2);
    prefs.begin("fyf", false); prefs.putInt("bkday", t.y * 10000 + t.mo * 100 + t.d); prefs.end(); }
  else snprintf(sdMsg, sizeof sdMsg, "Sicherung unvollstaendig. SD-Karte pruefen.");
  return ok;
}
static bool sdRestore(const char* nm) {
  if (!sdOk || !fsOk) { snprintf(sdMsg, sizeof sdMsg, "SD-Karte oder interner Speicher fehlt."); return false; }
  char base[64], p[96]; snprintf(base, sizeof base, "/FYF/Sicherung/%s", nm);
  xSemaphoreTake(sdLock, portMAX_DELAY);
  snprintf(p, sizeof p, "%s/aktuell.txt", base); bool there = SD.exists(p);
  xSemaphoreGive(sdLock);
  if (!there) { snprintf(sdMsg, sizeof sdMsg, "Sicherung unvollstaendig, nichts geaendert."); return false; }
  char keep[24]; snprintf(keep, sizeof keep, "%s", nm);
  if (!sdBackup("v")) { snprintf(sdMsg, sizeof sdMsg, "Vorab-Sicherung fehlgeschlagen, nichts geaendert."); return false; }   // Stand vorher sichern
  xSemaphoreTake(sdLock, portMAX_DELAY);
  // Kunden ersetzen
  for (int id = 1; id <= 99; id++) { char lp[24]; custPath(lp, sizeof lp, id); if (LittleFS.exists(lp)) LittleFS.remove(lp); }
  for (int id = 1; id <= 99; id++) consRemove(id);
  if (!LittleFS.exists("/e")) LittleFS.mkdir("/e");
  snprintf(p, sizeof p, "%s/e", base); consCopyAll(SD, p, LittleFS, "/e");
  int nk = 0; bool ok = true;
  for (int id = 1; id <= 99; id++) {
    snprintf(p, sizeof p, "%s/k/%d.txt", base, id); if (!SD.exists(p)) continue;
    char lp[24]; custPath(lp, sizeof lp, id); if (fsCopy(SD, p, LittleFS, lp)) nk++; else ok = false;
  }
  // laufendes Fitting & Einstellungen
  snprintf(p, sizeof p, "%s/aktuell.txt", base);
  File f = SD.open(p, FILE_READ);
  while (f && f.available()) {
    String l = f.readStringUntil('\n'); const char* s = l.c_str(); char fld[24];
    if (s[0] == 'F' && s[1] == '|') { char dt[20]; float b[NF], a[NF]; if (fyf::fitParse(s, dt, sizeof dt, b, a)) for (int i = 0; i < NF; i++) { vals[0][i] = b[i]; vals[1][i] = a[i]; saveVal(0, i); saveVal(1, i); } }
    else if (!strncmp(s, "FLOW|", 5)) { for (int i = 0; i < NS && s[5 + i]; i++) flowSt[i] = (uint8_t)(s[5 + i] - '0') % 3; saveFlow(); }
    else if (!strncmp(s, "OBS|", 4)) { for (int i = 0; i < NO; i++) { fyf::splitField(s + 4, ';', i, fld, sizeof fld); obsMin[i] = (uint16_t)atoi(fld); } saveObs(); }
    else if (!strncmp(s, "CHK|", 4)) { for (int i = 0; i < NCHK && s[4 + i]; i++) chk[i] = s[4 + i] == '1'; saveChk(); }
    else if (!strncmp(s, "SET|", 4)) {
      int v[7] = {bright, sound, invertAngle, 0, side, saverMin, activeCust}; float ao = angleOffset;
      for (int i = 0; i < 7; i++) if (fyf::splitField(s, '|', i + 1, fld, sizeof fld) && fld[0]) { if (i == 3) ao = (float)atof(fld); else v[i] = atoi(fld); }
      bright = constrain(v[0], 20, 255); sound = v[1]; invertAngle = v[2]; angleOffset = ao; side = v[4] ? 1 : 0; saverMin = v[5]; activeCust = v[6];
      saveSettings(); M5.Display.setBrightness(bright);
    }
  }
  if (f) f.close(); else ok = false;
  xSemaphoreGive(sdLock);
  custScan();
  char n2[32]; sdNice(keep, n2, sizeof n2);
  if (ok) snprintf(sdMsg, sizeof sdMsg, "Zurueckgeholt: %s, %d Kunden. Der Stand davor ist als '(vorher)' gesichert.", n2, nk);
  else snprintf(sdMsg, sizeof sdMsg, "Teilweise zurueckgeholt (%d Kunden). Stand davor ist gesichert.", nk);
  return ok;
}
static void sdAutoBackup() {   // einmal am Tag, wenn SD-Karte steckt
  static uint32_t lastTry = 0;
  if (!sdAuto || !sdOk || !fsOk || millis() - lastTry < 60000UL || millis() < 20000UL) return;
  lastTry = millis();
  fyf::DT t = nowDT(); if (t.y < 2025) return;
  prefs.begin("fyf", true); int last = prefs.getInt("bkday", 0); prefs.end();
  if (last == t.y * 10000 + t.mo * 100 + t.d) return;
  sdBackup(nullptr);
}
static void drawSd() {
  auto& d = M5.Display; d.fillScreen(C_BG); nBtns = 0;
  drawHeader("SD-Karte", true);
  int W = d.width(); char s[96];
  if (sdOk) { xSemaphoreTake(sdLock, portMAX_DELAY); sdScan(); xSemaphoreGive(sdLock); }
  if (sdOk) snprintf(s, sizeof s, "erkannt, %.1f von %.1f GB frei", sdFreeB / 1e9, sdTotalB / 1e9); else snprintf(s, sizeof s, "nicht erkannt (FAT32, Kontakte zum Bildschirm)");
  settingsRow(102, "SD-Karte", s); addBtn(W - 300, 114, 255, 64, "pruefen", 2600);
  if (sdLast[0]) { char n2[32]; sdNice(sdLast, n2, sizeof n2); snprintf(s, sizeof s, "letzte: %s", n2); } else snprintf(s, sizeof s, "noch keine");
  settingsRow(198, "Sicherung", s); addBtn(W - 300, 210, 255, 64, "Jetzt sichern", 2601, C_ACC, 0xFFFF);
  settingsRow(294, "Auto-Sicherung", sdAuto ? "taeglich an" : "aus"); addBtn(W - 300, 306, 255, 64, sdAuto ? "ausschalten" : "einschalten", 2602);
  bool mp = wxMapOnSd(); if (mp) snprintf(s, sizeof s, "gespeichert (BKG %d)", wxMapYear()); else snprintf(s, sizeof s, "fehlt - wird mit WLAN geladen");
  settingsRow(390, "Radar-Karte", s); addBtn(W - 300, 402, 255, 64, mp ? "neu laden" : "laden", 2603);
  d.setFont(&fonts::FreeSansBold18pt7b); d.setTextDatum(top_left); d.setTextColor(C_TEXT, C_BG); d.drawString("Zurueckholen", 28, 494);
  d.setFont(&fonts::FreeSans12pt7b); d.setTextColor(C_MUTED, C_BG); d.drawString("ersetzt Kunden + laufendes Fitting (Stand davor wird gesichert)", 290, 500);
  for (int i = 0; i < sdN && i < 4; i++) {
    int x = 20 + (i % 2) * ((W - 50) / 2 + 10), y = 536 + (i / 2) * 72, w = (W - 50) / 2;
    bool sel = sdConfirm && !strcmp(sdSel, sdList[i]);
    char n2[32]; sdNice(sdList[i], n2, sizeof n2);
    static char lbl[4][48]; snprintf(lbl[i], sizeof lbl[i], sel ? "Wirklich %s?" : "%s", n2);
    addBtn(x, y, w, 62, lbl[i], 2610 + i, sel ? C_WARN : C_CARD, sel ? 0xFFFF : C_TEXT);
  }
  drawAllBtns();
  if (!sdN) { d.setFont(&fonts::FreeSans12pt7b); d.setTextDatum(top_left); d.setTextColor(C_MUTED, C_BG); d.drawString(sdOk ? "Noch keine Sicherung auf der Karte." : "SD-Karte einstecken und 'pruefen' tippen.", 28, 548); }
  if (sdMsg[0]) { d.setFont(&fonts::FreeSans12pt7b); d.setTextDatum(bottom_left); d.setTextColor(C_ACC, C_BG); d.drawString(sdMsg, 24, d.height() - 6); }
}
static void sdTap(int id) {
  if (id == 2600) { waitScreen("Pruefe SD-Karte"); sdStart(); snprintf(sdMsg, sizeof sdMsg, "%s", sdOk ? "SD-Karte bereit." : "Keine SD-Karte erkannt. FAT32 formatiert? Richtig herum?"); sdConfirm = false; needFull = true; }
  else if (id == 2601) { waitScreen("Sichere auf SD-Karte"); sdBackup(nullptr); sdConfirm = false; needFull = true; }
  else if (id == 2602) { sdAuto = !sdAuto; prefs.begin("fyf", false); prefs.putBool("bkauto", sdAuto); prefs.end(); needFull = true; }
  else if (id == 2603) { if (!sdOk) snprintf(sdMsg, sizeof sdMsg, "Keine SD-Karte."); else if (!wifiOn()) snprintf(sdMsg, sizeof sdMsg, "Kein WLAN: Mehr > FYF & WLAN."); else { wxMapWanted = true; snprintf(sdMsg, sizeof sdMsg, "Karte wird im Hintergrund geladen (ca. 1 MB). Danach im Wetter sichtbar."); } needFull = true; }
  else if (id >= 2610 && id < 2614) {
    int i = id - 2610; if (i >= sdN) return;
    if (sdConfirm && !strcmp(sdSel, sdList[i])) { char nm[24]; snprintf(nm, sizeof nm, "%s", sdList[i]); waitScreen("Hole Sicherung zurueck"); sdRestore(nm); sdConfirm = false; }
    else { snprintf(sdSel, sizeof sdSel, "%s", sdList[i]); sdConfirm = true; }
    needFull = true;
  }
}
static void wxTap(int id) {
  if (id == 2500) { wxPlay = !wxPlay; wxLastFrame = millis(); wxDrawTimeline(); }
  else if (id == 2501) { wxForce = true; snprintf(wxStat, sizeof wxStat, "Aktualisiere ..."); wxDrawTimeline(); }
  else if (id == 2510) { wxPlay = false; wxScrub(lastTapX); }
  else if (id == 2502) { if (wxSnapNA) { wxAlertOpen = true; needFull = true; } }
  else if (id == 2503) { wxAlertOpen = false; needFull = true; }
}
static void wxStart() {   // in setup()
  wxLock = xSemaphoreCreateMutex();
  prefs.begin("fyf", true); sdAuto = prefs.getBool("bkauto", true); prefs.end();
  sdStart();
  xTaskCreatePinnedToCore(wxTask, "wetter", 16384, nullptr, 1, nullptr, 0);
}
static void wxHomeSub(char* s, int n) {
  WxNowT w; if (!wxLock) { snprintf(s, n, "DWD-Radar und Vorhersage"); return; }
  xSemaphoreTake(wxLock, portMAX_DELAY); w = wxNow; xSemaphoreGive(wxLock);
  if (w.ok) { char t[12]; wxFmt1(t, sizeof t, w.temp); snprintf(s, n, "%s Grad, %s", t, fyf::wxText(w.icon)); }
  else snprintf(s, n, "%s", wifiOn() ? "wird geladen ..." : "braucht WLAN");
}
static void sdHomeSub(char* s, int n) {
  if (!sdOk) { snprintf(s, n, "keine Karte erkannt"); return; }
  if (sdLast[0]) { char t[32]; sdNice(sdLast, t, sizeof t); snprintf(s, n, "Sicherung %s", t); } else snprintf(s, n, "noch keine Sicherung");
}

// ================= EINWILLIGUNG & ABSCHLUSS =================
// Einwilligung je Kunde: /e/<nr>.txt (Häkchen, Datum) und /e/<nr>.png (Unterschrift). Text wie in der FYF-App ("Muster 3"), gekürzt.
static const char* CONSENT_VER = "Muster 3 (Tab5)";
static const char* CONSENT_TXT[] = {
  "Wer: FYF Fit your Frame, Uttenreuth.",
  "Wofuer: Wir speichern deine Angaben, um dein Rad an dich anzupassen, das Ergebnis zu dokumentieren und bei Nachkontrollen zu vergleichen.",
  "Welche Daten: Name, Koerpermasse, Fahrrad- und Einstellungsdaten. Nur wenn du rechts zustimmst: Beschwerden und Koerpercheck (Gesundheitsdaten, Art. 9 DSGVO) sowie Fotos und Videos von dir auf dem Rad.",
  "Wie lange: bis du die Loeschung verlangst, laengstens 3 Jahre nach dem letzten Termin.",
  "Deine Rechte: Auskunft, Berichtigung, Loeschung, Einschraenkung, Datenuebertragbarkeit und Beschwerde bei einer Datenschutzbehoerde. Du kannst jederzeit widerrufen, bis dahin bleibt die Verarbeitung rechtmaessig.",
  "Freiwillig: Ohne Gesundheitsangaben ist ein Fitting moeglich, aber weniger genau.",
  "Hinweis: Das Bikefitting ist keine medizinische Untersuchung und ersetzt keinen Arzt."};
static const char* CONSENT_OPT[5] = {"Fitting-Daten speichern (noetig)", "Beschwerden & Koerpercheck", "Fotos & Videos auf dem Rad", "Anonyme Auswertung", "Jaehrliche Service-Erinnerung"};
static const int SG_X = 712, SG_Y = 424, SG_W = 548, SG_H = 186;
static fyf::Consent cons{}; static bool consHave = false; static bool consEdit = false; static bool consOpt[5] = {true, false, false, false, false};
static M5Canvas* sigC = nullptr; static bool sigDrawn = false; static int sigLX = -1, sigLY = -1; static bool consConfirmDel = false;
static char consMsg[96] = "";
static void consPath(char* p, int n, int id, const char* ext) { snprintf(p, n, "/e/%d.%s", id, ext); }
static bool consLoad(int id, fyf::Consent& c) {
  c = fyf::Consent{}; if (!fsOk || id <= 0) return false;
  char p[24]; consPath(p, sizeof p, id, "txt"); if (!LittleFS.exists(p)) return false;
  File f = LittleFS.open(p, "r"); if (!f) return false;
  String l = f.readStringUntil('\n'); f.close();
  return fyf::consentParse(l.c_str(), c);
}
// Einwilligung (mit Unterschrift als PNG) an den FYF-Eintrag anhängen: ...]} -> ...],"consent":{...}}
static bool consAppend(int id, char* payload, int cap) {
  fyf::Consent c; if (!consLoad(id, c)) return false;
  char p[24]; consPath(p, sizeof p, id, "png");
  File f = LittleFS.open(p, "r"); if (!f) return false;
  size_t n = f.size(); uint8_t* png = (n && n < 30000) ? (uint8_t*)ps_malloc(n) : nullptr;
  bool rd = png && (size_t)f.read(png, n) == n; f.close();
  if (!rd) { if (png) free(png); return false; }
  int L = (int)strlen(payload); if (L < 2 || payload[L - 1] != '}') { free(png); return false; }
  char head[220];
  int hn = snprintf(head, sizeof head, ",\"consent\":{\"data\":true,\"date\":\"%s\",\"health\":%s,\"media\":%s,\"research\":%s,\"remind\":%s,\"version\":\"%s\",\"sig\":\"data:image/png;base64,",
                    c.date, c.health ? "true" : "false", c.media ? "true" : "false", c.research ? "true" : "false", c.remind ? "true" : "false", c.ver);
  int need = L - 1 + hn + ((int)n + 2) / 3 * 4 + 4;
  if (need >= cap) { free(png); return false; }
  memcpy(payload + L - 1, head, hn);
  int bn = fyf::b64Encode(png, (int)n, payload + L - 1 + hn, cap - (L - 1 + hn));
  free(png);
  if (bn < 0) { payload[L - 1] = '}'; payload[L] = 0; return false; }
  strcat(payload, "\"}}");
  return true;
}
static void consRemove(int id) {
  char p[24]; consPath(p, sizeof p, id, "txt"); if (LittleFS.exists(p)) LittleFS.remove(p);
  consPath(p, sizeof p, id, "png"); if (LittleFS.exists(p)) LittleFS.remove(p);
}
static void sigClear() {
  if (!sigC) { sigC = new M5Canvas(&M5.Display); sigC->setPsram(true); sigC->setColorDepth(16); sigC->createSprite(SG_W, SG_H); }
  sigC->fillSprite(0xFFFF); sigDrawn = false; sigLX = -1;
}
static void consOpen(int id) {
  consHave = consLoad(id, cons); consEdit = !consHave; consConfirmDel = false; consMsg[0] = 0;
  for (int i = 0; i < 5; i++) consOpt[i] = i == 0;
  sigClear(); go(CONSENT);
}
static bool consSave(int id) {
  if (!fsOk || id <= 0) return false;
  if (!LittleFS.exists("/e")) LittleFS.mkdir("/e");
  size_t len = 0; void* png = sigC->createPng(&len, 0, 0, SG_W, SG_H);
  if (!png || !len) { if (png) free(png); return false; }
  char p[24]; bool ok = false;
  consPath(p, sizeof p, id, "png");
  File f = LittleFS.open(p, "w"); if (f) { ok = f.write((const uint8_t*)png, len) == len; f.close(); }
  free(png);
  if (!ok) return false;
  fyf::Consent c{}; nowStamp(c.date, sizeof c.date);
  c.data = true; c.health = consOpt[1]; c.media = consOpt[2]; c.research = consOpt[3]; c.remind = consOpt[4];
  snprintf(c.ver, sizeof c.ver, "%s", CONSENT_VER); c.ok = true;
  char line[120]; fyf::consentLine(c, line, sizeof line);
  consPath(p, sizeof p, id, "txt");
  f = LittleFS.open(p, "w"); if (!f) return false;
  f.print(line); f.close();
  cons = c; consHave = true; return true;
}
static void drawCheckRow(int y, int i, bool on, bool active) {
  auto& d = M5.Display; int x = 712, w = 548, h = 54;
  uint16_t bg = on ? C_OK_L : C_CARD;
  d.fillRoundRect(x, y, w, h, 12, bg); d.drawRoundRect(x, y, w, h, 12, on ? C_OK : C_LINE);
  d.fillRoundRect(x + 12, y + 11, 32, 32, 6, on ? C_OK : 0xFFFF); d.drawRoundRect(x + 12, y + 11, 32, 32, 6, on ? C_OK : C_MUTED);
  if (on) { d.drawWideLine(x + 19, y + 28, x + 26, y + 36, 3, 0xFFFF); d.drawWideLine(x + 26, y + 36, x + 38, y + 18, 3, 0xFFFF); }
  d.setFont(&fonts::FreeSans12pt7b); d.setTextDatum(middle_left); d.setTextColor(on || active ? C_TEXT : C_MUTED, bg); d.drawString(CONSENT_OPT[i], x + 58, y + h / 2);
  if (active) addBtn(x, y, w, h, "", 1500 + i, bg, C_TEXT, false);
}
static void drawConsent() {
  auto& d = M5.Display; d.fillScreen(C_BG); nBtns = 0;
  drawHeader("Einwilligung", true);
  char f[40], s[96]; fyf::asciiFold(cur.name, f, sizeof f);
  // links: Text
  d.fillRoundRect(20, 104, 676, 604, 16, C_CARD); d.drawRoundRect(20, 104, 676, 604, 16, C_LINE);
  d.setFont(&fonts::FreeSansBold18pt7b); d.setTextDatum(top_left); d.setTextColor(C_TEXT, C_CARD);
  d.drawString("Datenverarbeitung beim Bikefitting", 40, 118);
  d.setFont(&fonts::FreeSans12pt7b); d.setTextColor(C_TEXT, C_CARD);
  int y = 164;
  for (unsigned i = 0; i < sizeof CONSENT_TXT / sizeof CONSENT_TXT[0]; i++) {
    // Zeilen zählen, damit die Absätze untereinander passen
    char line[128] = ""; const char* p = CONSENT_TXT[i]; char word[64];
    while (*p) {
      int n = 0; while (*p == ' ') p++; while (*p && *p != ' ' && n < 63) word[n++] = *p++; word[n] = 0; if (!n) break;
      char test[192]; snprintf(test, sizeof test, line[0] ? "%s %s" : "%s%s", line, word);
      if (d.textWidth(test) > 636 && line[0]) { d.drawString(line, 40, y); y += 25; snprintf(line, sizeof line, "%s", word); } else snprintf(line, sizeof line, "%s", test);
    }
    if (line[0]) { d.drawString(line, 40, y); y += 25; }
    y += 9;
  }
  // rechts: Häkchen und Unterschrift
  bool edit = consEdit;
  for (int i = 0; i < 5; i++) {
    bool on = edit ? consOpt[i] : (i == 0 ? cons.data : i == 1 ? cons.health : i == 2 ? cons.media : i == 3 ? cons.research : cons.remind);
    drawCheckRow(104 + i * 60, i, on, edit && i > 0);
    if (edit && i == 0) addBtn(712, 104, 548, 54, "", 1500, C_OK_L, C_TEXT, false);
  }
  d.setFont(&fonts::FreeSans12pt7b); d.setTextDatum(top_left); d.setTextColor(C_TEXT, C_BG);
  if (edit) snprintf(s, sizeof s, "Unterschrift %s:", f[0] ? f : "Kunde"); else snprintf(s, sizeof s, "Erteilt am %s von %s", cons.date, f);
  d.drawString(s, SG_X, 400);
  d.fillRoundRect(SG_X - 2, SG_Y - 2, SG_W + 4, SG_H + 4, 10, C_LINE);
  if (edit) { sigC->pushSprite(SG_X, SG_Y); d.drawFastHLine(SG_X + 20, SG_Y + SG_H - 40, SG_W - 40, C_LINE); }
  else {
    d.fillRect(SG_X, SG_Y, SG_W, SG_H, 0xFFFF);
    char p[24]; consPath(p, sizeof p, curId, "png");
    File fl = LittleFS.open(p, "r"); size_t n = fl ? fl.size() : 0; uint8_t* buf = n ? (uint8_t*)ps_malloc(n) : nullptr;
    if (buf && (size_t)fl.read(buf, n) == n) d.drawPng(buf, n, SG_X, SG_Y);
    if (fl) fl.close(); if (buf) free(buf);
  }
  int by = 622, bh = 86;
  if (edit) {
    bool can = consOpt[0] && sigDrawn;
    addBtn(SG_X, by, 170, bh, "Leeren", 1510, C_WARN_L, C_WARN);
    addBtn(SG_X + 182, by, SG_W - 182, bh, "Einwilligen", 1511, can ? C_ACC : C_LINE, 0xFFFF);
  } else {
    addBtn(SG_X, by, 260, bh, consConfirmDel ? "Wirklich?" : "Widerrufen", 1512, consConfirmDel ? C_WARN : C_WARN_L, consConfirmDel ? 0xFFFF : C_WARN);
    addBtn(SG_X + 272, by, SG_W - 272, bh, "Neu erfassen", 1513);
  }
  drawAllBtns();
  if (consMsg[0]) { d.setFont(&fonts::FreeSans12pt7b); d.setTextDatum(bottom_left); d.setTextColor(C_WARN, C_BG); d.drawString(consMsg, SG_X, 396); }
}
static void consentTick() {   // Unterschrift mit dem Finger
  if (!consEdit || !sigC) return;
  auto t = M5.Touch.getDetail();
  bool in = t.isPressed() && t.x >= SG_X && t.x < SG_X + SG_W && t.y >= SG_Y && t.y < SG_Y + SG_H;
  if (!in) { sigLX = -1; return; }
  int x = t.x - SG_X, y = t.y - SG_Y;
  if (sigLX < 0) { sigC->fillCircle(x, y, 2, C_TEXT); M5.Display.fillCircle(t.x, t.y, 2, C_TEXT); }
  else { sigC->drawWideLine(sigLX, sigLY, x, y, 2.4f, C_TEXT); M5.Display.drawWideLine(SG_X + sigLX, SG_Y + sigLY, t.x, t.y, 2.4f, C_TEXT); }
  sigLX = x; sigLY = y; lastTouch = millis();
  if (!sigDrawn) { sigDrawn = true; if (consOpt[0]) { for (int i = 0; i < nBtns; i++) if (btns[i].id == 1511) { btns[i].bg = C_ACC; drawBtn(btns[i]); } } }
}
static void consentTap(int id) {
  if (id >= 1500 && id < 1505 && consEdit) { int i = id - 1500; consOpt[i] = !consOpt[i]; consMsg[0] = 0; needFull = true; }
  else if (id == 1510) { sigClear(); needFull = true; }
  else if (id == 1511) {
    if (!consOpt[0]) snprintf(consMsg, sizeof consMsg, "Ohne Zustimmung zur Speicherung kein Fitting mit FYF.");
    else if (!sigDrawn) snprintf(consMsg, sizeof consMsg, "Bitte im weissen Feld unterschreiben.");
    else if (consSave(curId)) { consEdit = false; beep(2600, 200); snprintf(consMsg, sizeof consMsg, "%s", ""); }
    else snprintf(consMsg, sizeof consMsg, "Speichern fehlgeschlagen.");
    needFull = true;
  }
  else if (id == 1512) {
    if (!consConfirmDel) consConfirmDel = true;
    else { consRemove(curId); consHave = false; consConfirmDel = false; go(CUST); return; }
    needFull = true;
  }
  else if (id == 1513) { consEdit = true; for (int i = 0; i < 5; i++) consOpt[i] = i == 0; sigClear(); needFull = true; }
}

// ---------- Abschluss für den Kunden (QR-Codes) ----------
static char waPhone[20] = "4915751806152";                     // WhatsApp (Google-Profil FYF Fit your Frame)
static char gPlace[40] = "ChIJ3d-EEsb7oUcRzhA5o5V5Ie0";         // Google Place-ID FYF Fit your Frame, Uttenreuth
static const char* PASS_URL = "https://8s7wnktjyv-blip.github.io/bikefitting/rad.html#meine";
static void linksLoad() {
  prefs.begin("fyf", true);
  if (prefs.getBytesLength("wa")) prefs.getString("wa", waPhone, sizeof waPhone);
  if (prefs.getBytesLength("gplace")) prefs.getString("gplace", gPlace, sizeof gPlace);
  prefs.end();
}
static void linksSave() { prefs.begin("fyf", false); prefs.putString("wa", waPhone); prefs.putString("gplace", gPlace); prefs.end(); }
static void finCard(int x, const char* url, const char* title, const char* text, uint16_t col) {
  auto& d = M5.Display; int y = 196, w = 400, h = 512;
  d.fillRoundRect(x, y, w, h, 20, C_CARD); d.drawRoundRect(x, y, w, h, 20, C_LINE);
  d.fillRoundRect(x, y, w, 12, 6, col);
  d.fillRoundRect(x + 40, y + 30, 320, 320, 12, 0xFFFF);
  if (url && url[0]) d.qrcode(url, x + 50, y + 40, 300, 1);
  else { d.setFont(&fonts::FreeSans12pt7b); d.setTextDatum(middle_center); d.setTextColor(C_MUTED, 0xFFFF); d.drawString("Link fehlt", x + w / 2, y + 190); }
  d.setFont(&fonts::FreeSansBold18pt7b); d.setTextDatum(top_center); d.setTextColor(C_TEXT, C_CARD); d.drawString(title, x + w / 2, y + 368);
  d.setFont(&fonts::FreeSans12pt7b); d.setTextColor(C_MUTED, C_CARD);
  d.setTextDatum(top_left);
  // zweizeilig, mittig
  char l1[80] = "", l2[80] = ""; const char* p = text; char word[40];
  while (*p) {
    int n = 0; while (*p == ' ') p++; while (*p && *p != ' ' && n < 39) word[n++] = *p++; word[n] = 0; if (!n) break;
    char* tgt = l2[0] ? l2 : l1; char test[128]; snprintf(test, sizeof test, tgt[0] ? "%s %s" : "%s%s", tgt, word);
    if (tgt == l1 && d.textWidth(test) > w - 40) snprintf(l2, sizeof l2, "%s", word); else snprintf(tgt, 80, "%s", test);
  }
  d.setTextDatum(top_center); d.drawString(l1, x + w / 2, y + 418); if (l2[0]) d.drawString(l2, x + w / 2, y + 446);
}
static void drawFinish() {
  auto& d = M5.Display; d.fillScreen(C_BG); nBtns = 0;
  drawHeader("Abschluss", true);
  char f[40], s[80]; fyf::asciiFold(activeName(), f, sizeof f);
  char* sp = strchr(f, ' '); if (sp) *sp = 0;   // nur Vorname
  snprintf(s, sizeof s, f[0] ? "Danke, %s!" : "Danke!%s", f);
  d.setFont(&fonts::FreeSansBold24pt7b); d.setTextDatum(top_left); d.setTextColor(C_TEXT, C_BG); d.drawString(s, 24, 104);
  d.setFont(&fonts::FreeSans18pt7b); d.setTextColor(C_MUTED, C_BG); d.drawString("Code mit der Handy-Kamera scannen.", 24, 152);
  char gurl[96], wurl[160];
  snprintf(gurl, sizeof gurl, "%s%s", gPlace[0] ? "https://search.google.com/local/writereview?placeid=" : "", gPlace);
  if (waPhone[0]) snprintf(wurl, sizeof wurl, "https://wa.me/%s?text=Hallo%%20FYF%%2C%%20ich%%20hatte%%20ein%%20Bikefitting%%20bei%%20euch.", waPhone); else wurl[0] = 0;
  finCard(20, gurl, "Google-Bewertung", "Wir freuen uns ueber deine ehrliche Bewertung.", C_ACC);
  finCard(440, PASS_URL, "Dein Fahrradpass", "Deine Einstellungen und Arbeiten am Rad - kostenlos.", C_OK);
  finCard(860, wurl, "WhatsApp", "Fragen oder Nachkontrolle? Schreib uns.", 0x2589);
  addBtn(1060, 104, 200, 70, "Links", 1600);
  drawAllBtns();
}
static void drawLinks() {
  auto& d = M5.Display; d.fillScreen(C_BG); nBtns = 0;
  drawHeader("Abschluss-Links", true);
  int W = d.width(); char s[64];
  snprintf(s, sizeof s, "+%s", waPhone);
  settingsRow(104, "WhatsApp-Nummer", waPhone[0] ? s : "-"); addBtn(W - 300, 116, 255, 64, "aendern", 1610);
  settingsRow(204, "Google Place-ID", gPlace[0] ? gPlace : "-"); addBtn(W - 300, 216, 255, 64, "aendern", 1611);
  settingsRow(304, "Fahrradpass", "FYF Pass (rad.html)");
  d.setFont(&fonts::FreeSans12pt7b); d.setTextDatum(top_left); d.setTextColor(C_MUTED, C_BG);
  drawWrapped("Place-ID: Sie steht in Google Maps beim Unternehmensprofil oder ueber den 'Place ID Finder' von Google. Voreingestellt ist FYF Fit your Frame, Uttenreuth.", 28, 420, W - 56, 30);
  drawAllBtns();
}

// ---------- Hilfen für Sicherung ----------
static int consCopyAll(fs::FS& from, const char* fromDir, fs::FS& to, const char* toDir) {   // /e/<nr>.txt|png kopieren
  int n = 0;
  for (int id = 1; id <= 99; id++) for (int k = 0; k < 2; k++) {
    char a[64], b[64]; const char* ext = k ? "png" : "txt";
    snprintf(a, sizeof a, "%s/%d.%s", fromDir, id, ext); if (!from.exists(a)) continue;
    snprintf(b, sizeof b, "%s/%d.%s", toDir, id, ext); if (fsCopy(from, a, to, b)) n += k == 0;
  }
  return n;
}

// ================= KUNDE / WLAN / KOPPELN: Tastatur fertig =================
static void kbDone() {
  char t[66]; snprintf(t, sizeof t, "%s", kbBuf);
  for (char* p = t; *p; p++) if (*p == ',') *p = '.';
  switch (kbTarget) {
    case KB_NAME: { char* p = kbBuf; while (*p == ' ') p++; int L = strlen(p); while (L && p[L - 1] == ' ') p[--L] = 0; snprintf(edc.name, sizeof edc.name, "%s", p); go(CUSTEDIT); break; }
    case KB_HEIGHT: { float v = fyf::parseNum(t); edc.height = (v >= 100 && v <= 230) ? fyf::round1(v) : NAN; go(CUSTEDIT); break; }
    case KB_INSEAM: { float v = fyf::parseNum(t); edc.inseam = (v >= 40 && v <= 120) ? fyf::round1(v) : NAN; go(CUSTEDIT); break; }
    case KB_BIKE: snprintf(edc.bike, sizeof edc.bike, "%s", kbBuf); go(CUSTEDIT); break;
    case KB_WIFIPASS:
      snprintf(wSsid, sizeof wSsid, "%s", selSsid); snprintf(wPass, sizeof wPass, "%s", kbBuf); saveCloud();
      waitScreen("Verbinde mit WLAN"); wifiSetup(); WiFi.disconnect(); if (wifiConnect(15000)) setMsg("WLAN verbunden. Uhrzeit wird automatisch gestellt.");
      go(CLOUD); break;
    case KB_PAIR: cloudPair(kbBuf); go(CLOUD); break;
    case KB_WAPHONE: { char ph[20]; if (!kbBuf[0]) waPhone[0] = 0; else if (fyf::phoneIntl(kbBuf, ph, sizeof ph)) snprintf(waPhone, sizeof waPhone, "%s", ph); linksSave(); go(LINKS); break; }
    case KB_PLACE: { char* p = kbBuf; while (*p == ' ') p++; snprintf(gPlace, sizeof gPlace, "%s", p); linksSave(); go(LINKS); break; }
  }
}

// ================= Steuerung =================
static void go(Screen s) { screen = s; needFull = true; confirmNew = false; confirmDel = false; confirmFollow = false; }

static void onTap(int id) {
  if (screen == GAME && id != 0) { gameJump(); return; }
  if (id < 0) return;
  beep();
  if (id == 0) {
    Screen b = HOME;
    if (screen == SETCLOCK) b = SETTINGS; else if (screen == QR || screen == FINISH) b = SUMMARY; else if (screen == CUSTEDIT || screen == CONSENT) b = CUST;
    else if (screen == LINKS) b = FINISH;
    else if (screen == KEYB) b = kbReturn; else if (screen == WIFILIST) b = CLOUD;
    go(b); return;
  }
  if (id == 900) { side = 1 - side; saveSettings(); needFull = true; return; }
  if (id == 150 || id == 151) { homePage = id - 150; needFull = true; return; }
  if (id >= 100 && id < 150) {
    int t = id - 100;
    if (t == CLOCK) { fyf::DT n = nowDT(); calY = n.y; calM = n.mo; }
    if (t == VALUES) inBuf[0] = 0;
    if (t == CUST) { custSyncFromFyf(false); curId = activeCust; if (curId) custLoad(curId, cur, true); }
    if (t == CALC) calcEnter();
    if (t == GAME) gameEnter();
    go((Screen)t); return;
  }
  switch (screen) {
    case FLOW:
      if (id >= 300 && id < 300 + NS) { flowCur = id - 300; needFull = true; }
      else if (id == 310) { if (flowCur > 0) flowCur--; needFull = true; }
      else if (id == 311) { flowSt[flowCur] = 2; saveFlow(); if (flowCur < NS - 1) flowCur++; needFull = true; }
      else if (id == 312) { flowSt[flowCur] = flowSt[flowCur] == 1 ? 0 : 1; saveFlow(); if (flowSt[flowCur] == 1 && flowCur < NS - 1) flowCur++; beep(2600, 120); needFull = true; }
      else if (id == 313) { if (flowCur == 10) { side = 1; saveSettings(); } if (flowCur == 6) { side = 0; saveSettings(); } if (S_TOOL[flowCur] >= 0) go((Screen)S_TOOL[flowCur]); }
      break;
    case VALUES:
      if (id >= 400 && id < 400 + NF) { curField = id - 400; inBuf[0] = 0; drawValuesList(); drawValuesInput(); }
      else if (id >= 420 && id < 432) { fyf::keypadInput(inBuf, sizeof inBuf, KEYS[id - 420]); drawValuesInput(); }
      else if (id == 440) {
        float v = fyf::parseComma(inBuf);
        if (!isnan(v)) { vals[side][curField] = v; saveVal(side, curField); inBuf[0] = 0; if (curField < NF - 1) curField++; beep(2600, 120); drawValuesList(); drawValuesInput(); }
      }
      break;
    case ANGLE:
      if (id == 500) { angleOffset = rawAngle(); saveSettings(); beep(2600, 120); }
      else if (id == 501) { heldVal = fyf::round1(rawAngle() - angleOffset); angleHold = !angleHold; needFull = true; }
      else if (id == 502) { angleMode = (angleMode + 1) % 3; needFull = true; }
      else if (id == 503) { int f = ANGLE_FIELDS[angleTgt]; vals[side][f] = curAngle(); saveVal(side, f); beep(2600, 200); }
      else if (id == 504) { angleTgt = (angleTgt + 1) % 3; needFull = true; }
      break;
    case RIDE:
      if (id == 600) {
        if (progI >= progN) progDefault();
        if (progRun) { stElapsed += millis() - stStart; progRun = false; } else { stStart = millis(); progRun = true; }
        krApply(); needFull = true;
      } else if (id == 601) { if (progI < progN) { rideFinishStage(); progI++; stElapsed = 0; stStart = millis(); if (progI >= progN) progRun = false; } krApply(); needFull = true; }
      else if (id == 602) { progRun = false; krRelease(); progDefault(); needFull = true; }
      else if (id == 603) { if (progI >= progN) { progN = 0; progI = 0; stElapsed = 0; } progAfterChange(); needFull = true; }
      else if (id == 610) { if (krOn) krDisconnect(); else { waitScreen("Suche Rolle (10 s)"); if (!krConnect()) { waitScreen("Keine Rolle verbunden"); delay(1500); } else krApply(); } needFull = true; }
      else if (id == 611) { krMess = max(50, krMess - 10); krSent = -1; krApply(); needFull = true; }
      else if (id == 612) { krMess = min(krMax, krMess + 10); krSent = -1; krApply(); needFull = true; }
      else if (id == 613) { metro = metro == 0 ? 80 : metro >= 95 ? 0 : metro + 5; needFull = true; }
      break;
    case OBS:
      if (id >= 700 && id < 700 + NO) { int i = id - 700; if (obsMin[i]) obsMin[i] = 0; else { fyf::DT n = nowDT(); obsMin[i] = n.h * 60 + n.mi + 1; } saveObs(); needFull = true; }
      break;
    case SUMMARY:
      if (id == 800) go(QR); else if (id == 801) go(VALUES); else if (id == 804) go(FINISH);
      else if (id == 802) {
        if (!activeCust) { curId = 0; go(CUST); }
        else if (custAddFit(activeCust)) { beep(2600, 200); waitScreen("Beim Kunden gespeichert"); delay(900); needFull = true; }
      } else if (id == 803) {
        if (!cloudPaired()) { setMsg("Erst mit FYF koppeln."); go(CLOUD); }
        else { cloudSend(); go(CLOUD); }
      }
      break;
    case CUST:
      if (id >= 1300 && id < 1360) { int i = id - 1300; if (i < nCust) { curId = custs[i].id; custLoad(curId, cur, true); } confirmDel = confirmFollow = false; needFull = true; }
      else if (id == 1370) { editId = 0; memset(&edc, 0, sizeof edc); edc.height = NAN; edc.inseam = NAN; go(CUSTEDIT); }
      else if (id == 1371) { if (custPage > 0) custPage--; needFull = true; }
      else if (id == 1372) { custPage++; needFull = true; }
      else if (id == 1373) { custSyncFromFyf(true); curId = 0; needFull = true; }
      else if (id == 1380 && curId) { activeCust = curId; saveSettings(); beep(2600, 120); needFull = true; }
      else if (id == 1381 && curId) { editId = curId; edc = cur; go(CUSTEDIT); }
      else if (id == 1382 && curId) {
        if (!confirmFollow) { confirmFollow = true; confirmDel = false; needFull = true; break; }
        newFitting(); progDefault(); nRide = 0; measDone = 0;
        if (nHist) { const FitRec& r = fits[nHist - 1]; for (int i = 0; i < NF; i++) { vals[0][i] = !isnan(r.a[i]) ? r.a[i] : r.b[i]; saveVal(0, i); } }
        activeCust = curId; side = 0; saveSettings(); confirmFollow = false; beep(2600, 200); go(VALUES);
      } else if (id == 1384 && curId) { consOpen(curId); return;
      } else if (id == 1383 && curId) {
        if (!confirmDel) { confirmDel = true; confirmFollow = false; needFull = true; break; }
        char p[24]; custPath(p, sizeof p, curId); LittleFS.remove(p); consRemove(curId);
        if (activeCust == curId) { activeCust = 0; saveSettings(); }
        curId = 0; confirmDel = false; custScan(); needFull = true;
      }
      break;
    case CUSTEDIT:
      if (id == 1390) openKb(KB_NAME, "Name", edc.name, 38, CUSTEDIT);
      else if (id == 1391) { char v[16] = ""; if (!isnan(edc.height)) fmtVal(v, sizeof v, edc.height); openKb(KB_HEIGHT, "Koerpergroesse in cm", v, 7, CUSTEDIT); kbSym = false; }
      else if (id == 1392) { char v[16] = ""; if (!isnan(edc.inseam)) fmtVal(v, sizeof v, edc.inseam); openKb(KB_INSEAM, "Schrittlaenge in cm", v, 7, CUSTEDIT); }
      else if (id == 1393) openKb(KB_BIKE, "Fahrrad", edc.bike, 38, CUSTEDIT);
      else if (id == 1395 && edc.name[0]) {
        int nid = editId ? editId : custNewId();
        if (nid && custSave(nid, edc)) { custScan(); curId = nid; custLoad(curId, cur, true); if (!activeCust) { activeCust = nid; saveSettings(); } beep(2600, 200); go(CUST); }
        else { waitScreen("Speichern fehlgeschlagen"); delay(1200); needFull = true; }
      }
      break;
    case KEYB:
      if (id >= 2000 && id < 2040) {
        char ch = kbLbl[id - 2000][0];
        if (fyf::textInput(kbBuf, kbCap, ch)) {
          if (kbShift && isalpha((unsigned char)ch) && (kbTarget == KB_NAME || kbTarget == KB_BIKE)) { kbShift = false; needFull = true; }
          else drawKbText();
        }
      }
      else if (id == 2040) { kbShift = !kbShift; needFull = true; }
      else if (id == 2041) { kbSym = !kbSym; needFull = true; }
      else if (id == 2042) { if (fyf::textInput(kbBuf, kbCap, ' ')) drawKbText(); }
      else if (id == 2043) { if (fyf::textInput(kbBuf, kbCap, '\b')) drawKbText(); }
      else if (id == 2044) kbDone();
      break;
    case INFO:
      if (id == 1750 || id == 1751) { infoTab = id - 1750; needFull = true; }
      break;
    case CALC:
      if (id == 1500 || id == 1501) { calcTab = id - 1500; needFull = true; }
      else if (id >= 1510 && id < 1550) { calcStep(id); needFull = true; }
      break;
    case STOPW:
      if (id == 1600) { if (swRun) { swAcc += millis() - swStart; swRun = false; } else { swStart = millis(); swRun = true; } needFull = true; }
      else if (id == 1601) { if (swRun && nLaps < 8) { laps[nLaps++] = swMs(); needFull = true; } }
      else if (id == 1602) { swRun = false; swAcc = 0; nLaps = 0; needFull = true; }
      break;
    case CHECK:
      if (id >= 1720 && id < 1720 + NCHK) { chk[id - 1720] ^= 1; saveChk(); needFull = true; }
      else if (id == 1710) { memset(chk, 0, NCHK); saveChk(); needFull = true; }
      break;
    case CLOUD:
      if (id == 1900) { waitScreen("Suche WLAN"); wifiScan(); go(WIFILIST); }
      else if (id == 1901) { waitScreen("Verbinde mit WLAN"); if (wifiConnect(15000)) setMsg("WLAN verbunden."); needFull = true; }
      else if (id == 1902) { WiFi.disconnect(true); wSsid[0] = 0; wPass[0] = 0; saveCloud(); setMsg("WLAN vergessen."); needFull = true; }
      else if (id == 1910) openKb(KB_PAIR, "Kopplungscode aus FYF", "", 12, CLOUD);
      else if (id == 1911) { cloudLoadCustomers(); needFull = true; }
      else if (id == 1912) { cloudSend(); needFull = true; }
      else if (id == 1913) { cloudUnpair(); needFull = true; }
      break;
    case WIFILIST:
      if (id == 1820) { waitScreen("Suche WLAN"); wifiScan(); needFull = true; }
      else if (id >= 1800 && id < 1812) {
        int i = id - 1800; if (i >= nNets) break;
        snprintf(selSsid, sizeof selSsid, "%s", nets[i].ssid);
        if (nets[i].open) { kbBuf[0] = 0; kbTarget = KB_WIFIPASS; kbDone(); }
        else { char t[48], f[36]; fyf::asciiFold(selSsid, f, sizeof f); snprintf(t, sizeof t, "Passwort: %s", f); openKb(KB_WIFIPASS, t, "", 64, WIFILIST); kbShift = false; }
      }
      break;
    case CLOCK:
      if (id == 1000) { if (--calM < 1) { calM = 12; calY--; } needFull = true; }
      else if (id == 1001) { if (++calM > 12) { calM = 1; calY++; } needFull = true; }
      else if (id == 1002) { fyf::DT n = nowDT(); calY = n.y; calM = n.mo; needFull = true; }
      break;
    case SETTINGS:
      if (id == 1100) { bright = max(20, bright - 25); M5.Display.setBrightness(bright); saveSettings(); needFull = true; }
      else if (id == 1101) { bright = min(255, bright + 25); M5.Display.setBrightness(bright); saveSettings(); needFull = true; }
      else if (id == 1102) { sound = !sound; saveSettings(); needFull = true; }
      else if (id == 1103) { invertAngle = !invertAngle; angleOffset = -angleOffset; saveSettings(); needFull = true; }
      else if (id == 1104) { edit = nowDT(); go(SETCLOCK); }
      else if (id == 1105) { if (confirmNew) { newFitting(); progDefault(); nRide = 0; measDone = 0; confirmNew = false; beep(1800, 300); } else confirmNew = true; needFull = true; }
      else if (id == 1106) { saverMin = saverMin == 0 ? 2 : saverMin == 2 ? 5 : saverMin == 5 ? 10 : 0; saveSettings(); needFull = true; }
      break;
    case WETTER: wxTap(id); break;
    case CONSENT: consentTap(id); break;
    case FINISH: if (id == 1600) go(LINKS); break;
    case LINKS:
      if (id == 1610) openKb(KB_WAPHONE, "WhatsApp-Nummer mit Vorwahl", waPhone, 20, LINKS);
      else if (id == 1611) openKb(KB_PLACE, "Google Place-ID", gPlace, 40, LINKS);
      break;
    case SDCARD: sdTap(id); break;
    case SETCLOCK:
      if (id >= 1200 && id < 1210) { editStep((id - 1200) / 2, (id - 1200) % 2 ? -1 : 1); needFull = true; }
      else if (id == 1210) { edit.s = 0; setNow(edit); beep(2600, 200); go(SETTINGS); }
      break;
    default: break;
  }
}

void setup() {
  auto cfg = M5.config();
  M5.begin(cfg);
  M5.Display.setRotation(1);   // quer
  loadAll();
  M5.Display.setBrightness(bright);
  M5.Speaker.setVolume(120);
  imuOk = M5.Imu.isEnabled();
  rtcOk = M5.Rtc.isEnabled();
  prefs.begin("fyf", true); swBase = prefs.getLong64("clk", fyf::toEpoch(2026, 1, 1, 12, 0, 0)); prefs.end();
  swMillis = millis();
  progDefault();
  fsOk = LittleFS.begin(true);
  if (fsOk && !LittleFS.exists("/k")) LittleFS.mkdir("/k");
  custScan();
  loadCloud();
  if (wSsid[0]) { wifiSetup(); WiFi.begin(wSsid, wPass); }   // verbindet im Hintergrund, stellt dann die Uhr
  wxStart();   // Wetter (eigene Aufgabe) und SD-Karte
  linksLoad();
  lastTouch = millis();
}

void loop() {
  M5.update();
  readImu();
  rideTick();
  auto t = M5.Touch.getDetail();
  if (t.wasPressed()) {
    lastTouch = millis();
    lastTapX = t.x;
    if (screen == SAVER) go(saverReturn); else onTap(hitBtn(t.x, t.y));
  }
  if (screen != SAVER && saverMin > 0 && !progRun && !swRun && !metro && screen != GAME && screen != WETTER && millis() - lastTouch > (uint32_t)saverMin * 60000UL) { saverReturn = screen; go(SAVER); }
  // Uhrzeit aus dem Internet, sobald WLAN steht (nicht blockierend)
  static uint32_t lastNet = 0;
  if (millis() - lastNet > 1000) { lastNet = millis(); if (wifiOn()) { ntpStart(); ntpPoll(); } }

  static uint32_t lastDraw = 0;
  if (needFull) {
    needFull = false;
    switch (screen) {
      case HOME: drawHome(); break;
      case FLOW: drawFlow(); break;
      case VALUES: drawValues(); break;
      case ANGLE: drawAngle(); break;
      case LEVEL: drawLevel(); break;
      case RIDE: drawRide(); break;
      case OBS: drawObs(); break;
      case SUMMARY: drawSummary(); break;
      case QR: drawQr(); break;
      case CLOCK: drawClock(); break;
      case SETTINGS: drawSettings(); break;
      case SETCLOCK: drawSetClock(); break;
      case CUST: drawCust(); break;
      case CUSTEDIT: drawCustEdit(); break;
      case CALC: drawCalc(); break;
      case STOPW: drawStopw(); break;
      case CHECK: drawCheck(); break;
      case CLOUD: drawCloud(); break;
      case WIFILIST: drawWifiList(); break;
      case KEYB: drawKeyb(); break;
      case SAVER: drawSaver(); break;
      case INFO: drawInfo(); break;
      case GAME: drawGame(); break;
      case WETTER: drawWx(); break;
      case SDCARD: drawSd(); break;
      case CONSENT: drawConsent(); break;
      case FINISH: drawFinish(); break;
      case LINKS: drawLinks(); break;
    }
    lastDraw = 0;
  }
  if (screen == GAME && !needFull) gameTick();
  if (screen == WETTER && !needFull) wxTick();
  if (screen == CONSENT && !needFull) consentTick();
  if (screen == HOME || screen == WETTER || screen == SAVER) sdAutoBackup();
  if (millis() - lastDraw > 120) {   // ca. 8 Mal pro Sekunde
    lastDraw = millis();
    if (screen == ANGLE) drawAngleValue();
    else if (screen == LEVEL) drawLevelValue();
    else if (screen == RIDE) drawRideValue();
    else if (screen == STOPW) drawStopwValue();
    else if (screen == CLOCK) { fyf::DT n = nowDT(); if (n.s != lastSec) { lastSec = n.s; drawClockFace(n); } }
    else if (screen == SAVER) { fyf::DT n = nowDT(); if (n.s != lastSec) { lastSec = n.s; drawSaverValue(n); } }
    fyf::DT n = nowDT(); if (n.mi != lastHeaderMin && screen != SAVER && screen != GAME && screen != WETTER) drawHeaderRight();
  }
  delay(8);
}
