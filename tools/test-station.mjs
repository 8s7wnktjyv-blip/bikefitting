// Prüft die Übernahme von Tab5-Werten (FYF Station) ins Fitting.
// Aufruf: node tools/test-station.mjs
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const html = readFileSync(fileURLToPath(new URL('../index.html', import.meta.url)), 'utf8');
const m = html.match(/\/\* STATION-START \*\/([\s\S]*?)\/\* STATION-END \*\//);
if (!m) { console.error('STATION-Block nicht gefunden'); process.exit(1); }
const mv = (key, value, method, source, unc) => ({ key, value, method, source: source || 'gemessen', unc: unc ?? null, time: '' });
const F = new Function('mv', m[1] + '; return { stValues, stInfo, stApplyTo, stRide, ST_KEYS };')(mv);

let fail = 0, n = 0;
const ok = (c, msg) => { n++; if (!c) { fail++; console.error('FEHLER:', msg); } };
const eq = (a, b, msg) => ok(JSON.stringify(a) === JSON.stringify(b), `${msg}: ${JSON.stringify(a)} statt ${JSON.stringify(b)}`);

// Gleiche Schlüssel und Reihenfolge wie in der Firmware (fyf_calc.h FYF_KEYS)
let fw = '';
try { fw = readFileSync(fileURLToPath(new URL('../../FYF-Station-Tab5/FYF_Station/fyf_calc.h', import.meta.url)), 'utf8'); } catch (e) {}
if (fw) { const k = fw.match(/FYF_KEYS\[CF\] = \{([^}]*)\}/); eq(k && JSON.parse('[' + k[1] + ']'), F.ST_KEYS, 'Schlüssel wie Firmware'); }

// Beispiel genau so, wie die Firmware es sendet (aus test_calc.cpp)
const p = { v: 1, src: 'tab5', ver: '0.3', when: '2026-11-20T18:30', customer: { name: 'Lena Hoffmann', fyf_id: 'c1' },
  before: { saddleHeight: 728, saddleTilt: -1.5, drop: -12 }, after: { saddleHeight: 736, kneeBDC: 143 }, obs: ['Knie links "innen"', 'Druck am Sattel'], ride_measurements: 1 };
eq(F.stValues(p), { before: { saddleHeight: 728, drop: -12, saddleTilt: -1.5 }, after: { saddleHeight: 736, kneeBDC: 143 } }, 'Werte lesen');
// Unsinn wird ignoriert
eq(F.stValues({ before: { saddleHeight: '728', reach: NaN, saddleTilt: 99, hack: 5, kneeBDC: 400 }, after: [1, 2] }), { before: {}, after: {} }, 'ungültige Werte');
eq(F.stValues(null), { before: {}, after: {} }, 'leer');
const info = F.stInfo({ id: 7, payload: p, created_at: '2026-11-20T17:31:00Z' });
eq([info.id, info.when, info.name, info.fyfId, info.nb, info.na, info.obs.length], [7, '2026-11-20 18:30', 'Lena Hoffmann', 'c1', 3, 2, 2], 'Info');
eq(F.stInfo({ payload: { customer: 'x', obs: [1, 'a'] } }).obs, ['a'], 'Info robust');
// Übernehmen
const s = { before: { saddleHeight: { key: 'saddleHeight', value: 700, method: 'Laser-Wasserwaage' } }, after: {}, notes: 'alt' };
const cnt = F.stApplyTo(s, p, '20.11.2026 18:40');
eq(cnt, 5, 'Anzahl übernommen');
eq([s.before.saddleHeight.value, s.before.saddleHeight.method, s.before.saddleHeight.from], [728, 'Laser-Wasserwaage', 'Tab5'], 'Methode bleibt, Wert neu');
eq(s.before.saddleTilt.method, 'Digitaler Winkelmesser', 'Winkel-Methode');
eq(s.after.kneeBDC.method, 'Goniometer', 'Knie-Methode');
eq(s.after.saddleHeight.method, 'Maßband', 'Standard-Methode');
ok(s.notes.startsWith('alt\n\n[Tab5-Beobachtungen, 20.11.2026 18:40]\n- Knie links "innen"\n- Druck am Sattel'), 'Beobachtungen in Notizen');
const s2 = { before: {}, after: {} }; eq(F.stApplyTo(s2, {}, 'x'), 0, 'nichts zu übernehmen'); ok(!('notes' in s2), 'keine leeren Notizen');

// Rollen-Ergebnisse (Firmware v0.4)
{
  const pr = { ride: [{ label: 'Messung', target: 150, w: 150.4, cad: 88.2, sd_w: 6.1, sd_cad: 2 }, { label: 'x', w: null }, { label: 'Messung nach Aenderung', target: 150, w: 151, cad: null, sd_w: null }] };
  eq(F.stRide(pr).length, 2, 'Rolle: ungültige Zeile weg');
  const s3 = { before: {}, after: {} }; F.stApplyTo(s3, pr, 'T');
  ok(s3.notes === '[Tab5-Rolle, T]\n- Messung: Ø 150 W (Soll 150 W), 88 U/min, Schwankung ±6 W\n- Messung nach Aenderung: Ø 151 W (Soll 150 W), Trittfrequenz –', 'Rolle in Notizen: ' + s3.notes);
  eq(F.stRide({ ride: 'x' }), [], 'Rolle robust');
}
console.log(`${n} Prüfungen, ${fail} Fehler`);
process.exit(fail ? 1 : 0);
