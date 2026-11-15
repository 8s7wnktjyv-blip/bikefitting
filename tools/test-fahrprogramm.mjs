// Prüft Auslesen und Steuern der Rolle (FTMS) und den Ablauf des Fitting-Fahrprogramms.
// Aufruf: node tools/test-fahrprogramm.mjs
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const html = readFileSync(fileURLToPath(new URL('../index.html', import.meta.url)), 'utf8');
const m = html.match(/\/\* RIDE-CALC-START \*\/([\s\S]*?)\/\* RIDE-CALC-END \*\//);
if (!m) { console.error('RIDE-CALC-Block nicht gefunden'); process.exit(1); }
const F = new Function(m[1] + '; return { ftmsParse, ftmsTarget, ridePlan, rideAfterChange, rideAvg };')();

let fail = 0, n = 0;
const ok = (c, msg) => { n++; if (!c) { fail++; console.error('FEHLER:', msg); } };
const eq = (a, b, msg) => ok(JSON.stringify(a) === JSON.stringify(b), `${msg}: ${JSON.stringify(a)} statt ${JSON.stringify(b)}`);
const le16 = v => [v & 255, (v >> 8) & 255];

// Indoor Bike Data: Flags Geschwindigkeit (bit0=0 → vorhanden), Trittfrequenz (bit2), Leistung (bit6)
{
  const flags = 0b0100_0100; // bit2 + bit6, Geschwindigkeit vorhanden
  const b = [...le16(flags), ...le16(3250), ...le16(176), ...le16(152)];
  eq(F.ftmsParse(b), { speed: 32.5, cad: 88, power: 152 }, 'Geschwindigkeit, Trittfrequenz, Leistung');
}
{ // mit Durchschnittsgeschwindigkeit (bit1), Distanz (bit4, 3 Byte), Widerstand (bit5) dazwischen
  const flags = 0b0111_0110;
  const b = [...le16(flags), ...le16(3000), ...le16(2900), ...le16(180), 10, 0, 0, ...le16(20), ...le16(201)];
  eq(F.ftmsParse(b), { speed: 30, cad: 90, power: 201 }, 'mit zusätzlichen Feldern');
}
{ // „More Data“ gesetzt (bit0=1): keine Geschwindigkeit
  const b = [...le16(0b0100_0001), ...le16(250)];
  eq(F.ftmsParse(b), { power: 250 }, 'nur Leistung');
}
{ // negative Leistung (sint16)
  const b = [...le16(0b0100_0001), ...le16(65536 - 5)];
  eq(F.ftmsParse(b).power, -5, 'negative Leistung');
}
ok(F.ftmsParse([1]) === null, 'zu kurze Daten → null');
{ const r = F.ftmsParse([...le16(0b0100_0100), ...le16(3000)]); ok(r.power == null && r.cad == null, 'abgeschnittene Daten ohne Absturz'); }

// Zielleistung setzen: OpCode 0x05, sint16 Watt little-endian, begrenzt
eq(F.ftmsTarget(150), [5, 150, 0], 'Ziel 150 W');
eq(F.ftmsTarget(300), [5, 44, 1], 'Ziel 300 W');
eq(F.ftmsTarget(-20), [5, 0, 0], 'negativ → 0 W');
eq(F.ftmsTarget(5000), [5, 208, 7], 'über 2000 W → 2000 W');

// Programm
{
  const p = F.ridePlan(150, 300);
  eq(p.map(s => s.k), ['warm', 'mess', 'cool'], 'Stufen');
  eq(p.map(s => s.w), [120, 150, 100], 'Watt der Stufen');
  ok(p.every(s => s.sec > 0), 'Dauer > 0');
  eq(F.ridePlan(400, 300)[1].w, 300, 'Mess-Last auf Höchstwert begrenzt');
  eq(F.ridePlan(10, 300)[1].w, 50, 'Mess-Last mindestens 50 W');
  eq(F.rideAfterChange(160).map(s => [s.k, s.w]), [['warm', 160], ['mess', 160]], 'Nach Änderung');
}

// Mittelwerte: nur wenn getreten wird (über 20 U/min) und Leistung vorhanden
{
  const a = F.rideAvg([{ power: 148, cad: 88 }, { power: 152, cad: 90 }, { power: 0, cad: 0 }, { power: null, cad: 85 }]);
  eq(a, { power: 150, cad: 89, n: 2 }, 'Mittelwerte ohne Stillstand');
  ok(F.rideAvg([]) === null && F.rideAvg([{ power: 0, cad: 0 }]) === null, 'ohne Treten kein Mittelwert');
}

console.log(fail ? `${fail} von ${n} Prüfungen fehlgeschlagen` : `Alle ${n} Prüfungen bestanden`);
process.exit(fail ? 1 : 0);
