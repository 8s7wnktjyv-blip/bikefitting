// Prüft die Rechnung der Foto-Messung (fotoCalc in index.html) mit erfundenen, exakt bekannten Rädern.
// Aufruf: node tools/test-foto-messung.mjs
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const html = readFileSync(fileURLToPath(new URL('../index.html', import.meta.url)), 'utf8');
const m = html.match(/\/\* FOTO-CALC-START \*\/([\s\S]*?)\/\* FOTO-CALC-END \*\//);
if (!m) { console.error('FOTO-CALC-Block nicht gefunden'); process.exit(1); }
const { fotoCalc, FM_KEYS } = new Function(m[1] + '; return { fotoCalc, FM_KEYS };')();

let fail = 0, n = 0;
const ok = (cond, msg) => { n++; if (!cond) { fail++; console.error('FEHLER:', msg); } };
const near = (a, b, tol, msg) => ok(a != null && Math.abs(a - b) <= tol, `${msg}: ${a} statt ${b} (±${tol})`);

// Echtes Rad in mm: Tretlager = (0,0), x nach vorn, y nach oben
const ys = 740 * Math.sin(73 * Math.PI / 180), xs = -740 * Math.cos(73 * Math.PI / 180);
const W = {
  bb: [0, 0], floor: [0, -280], saddle: [xs, ys], tip: [-60, ys], bar: [430, 600], hood: [520, 590],
  refA: [-100, 450], refB: [-100 + 300 * Math.cos(0.1), 450 + 300 * Math.sin(0.1)], // 300 mm, leicht schräg am Oberrohr
  h1: [-600, -100], h2: [700, -100]
};
const expect = {
  saddleHeight: 740, saddleSetback: 60, barX: 430, drop: ys - 600, reach: Math.hypot(490, 584 - ys),
  bbHeight: 280, saddleFloor: 280 + ys, barFloor: 880, hoodFloor: 870, hoodX: 520, saddleToHood: Math.hypot(580, 590 - ys)
};

// Erzeugt Bildpunkte: Maßstab mmPerPx, Rad schaut nach links oder rechts, Kamera um rotDeg gedreht
function photo({ mmPerPx = 0.5, faceLeft = false, rotDeg = 0, off = [900, 1100] }) {
  const t = rotDeg * Math.PI / 180, c = Math.cos(t), s = Math.sin(t), P = {};
  for (const [k, [x, y]] of Object.entries(W)) {
    const u = (faceLeft ? -x : x) / mmPerPx, v = -y / mmPerPx; // Bild: y nach unten
    P[k] = { x: off[0] + u * c - v * s, y: off[1] + u * s + v * c };
  }
  return P;
}

for (const faceLeft of [false, true]) {
  for (const rotDeg of [0, 3, -4]) {
    for (const mmPerPx of [0.4, 0.8]) {
      const R = fotoCalc(photo({ mmPerPx, faceLeft, rotDeg }), 300, { imgW: 2000, tapPx: 3 });
      const tag = `${faceLeft ? 'links' : 'rechts'}, ${rotDeg}°, ${mmPerPx} mm/px`;
      ok(R, `Ergebnis fehlt (${tag})`);
      for (const k of FM_KEYS) near(R.vals[k], expect[k], 1, `${k} (${tag})`);
      near(R.rotDeg, rotDeg, 0.1, `Drehung erkannt (${tag})`);
      ok(R.unc >= 3, `Unsicherheit mindestens 3 mm (${tag})`);
    }
  }
}

// Ohne Laserlinie und schiefes Bild: muss warnen, Werte weichen ab
{
  const P = photo({ rotDeg: 3 }); delete P.h1; delete P.h2;
  const R = fotoCalc(P, 300, { imgW: 2000 });
  ok(R.warn.some(w => /Laserlinie/.test(w)), 'Warnung ohne Laserlinie fehlt');
  ok(Math.abs(R.vals.saddleSetback - 60) > 5, 'Schiefes Bild ohne Laserlinie sollte erkennbar abweichen (Test der Testdaten)');
}
// Pflichtpunkte fehlen → kein Ergebnis
{ const P = photo({}); delete P.tip; ok(fotoCalc(P, 300, {}) === null, 'Ohne Sattelspitze darf es kein Ergebnis geben'); }
// Ungültige Länge des Messzeichens
ok(fotoCalc(photo({}), 0, {}) === null, 'Länge 0 darf kein Ergebnis geben');
// Ohne Boden und Schalthebel: nur die übrigen Werte
{ const P = photo({}); delete P.floor; delete P.hood; const R = fotoCalc(P, 300, {});
  ok(R.vals.bbHeight == null && R.vals.saddleFloor == null && R.vals.hoodX == null, 'Ohne Boden/Schalthebel keine Höhen über Boden');
  near(R.vals.saddleHeight, 740, 1, 'Sattelhöhe ohne Boden'); }
// Kleines Messzeichen → Warnung
{ const R = fotoCalc(photo({ mmPerPx: 2 }), 300, { imgW: 2000 }); ok(R.warn.some(w => /klein/.test(w)), 'Warnung „Messzeichen klein“ fehlt'); }
// Falsche Länge des Messzeichens → Sattelhöhe unplausibel
{ const R = fotoCalc(photo({}), 100, { imgW: 2000 }); ok(R.warn.some(w => /unplausibel/.test(w)), 'Plausibilitätswarnung fehlt'); }

console.log(fail ? `${fail} von ${n} Prüfungen fehlgeschlagen` : `Alle ${n} Prüfungen bestanden`);
process.exit(fail ? 1 : 0);
