// Holt „Helfer in der Nähe“ (Fahrradläden, Reparatur-Stationen, Luft, Schlauch-Automaten, E-Bike-Laden, Krankenhäuser, Polizei)
// für Deutschland, Österreich, Schweiz (+ Grenzgebiet) aus OpenStreetMap (Overpass) und legt sie als 1°×1°-Kacheln in helfer/ ab.
// Läuft wöchentlich per GitHub-Aktion „Helfer-Daten aktualisieren“. Daten © OpenStreetMap-Mitwirkende, ODbL.
// Schlägt ein Gebiet fehl, bleiben dessen alte Dateien erhalten (nichts geht verloren).
import fs from 'node:fs'; import path from 'node:path';
const OUT='helfer', BBOX=[45,5,56,18];                 // Süd, West, Nord, Ost (ganze Grad)
const SERVERS=['https://overpass-api.de/api/interpreter','https://overpass.private.coffee/api/interpreter','https://overpass.kumi.systems/api/interpreter'];
const Q=`nwr[shop=bicycle];nwr[amenity=bicycle_repair_station];nwr[amenity=compressed_air];nwr["vending"~"bicycle_tube"];nwr[amenity=charging_station][bicycle=yes];nwr[amenity=hospital];nwr[amenity=police];`;
const kind=t=>t.shop==='bicycle'?'shop':t.amenity==='bicycle_repair_station'?'station':t.amenity==='compressed_air'?'air':/bicycle_tube/.test(t.vending||'')?'tube':t.amenity==='charging_station'?'charge':t.amenity==='hospital'?'hospital':t.amenity==='police'?'police':'';
const sleep=ms=>new Promise(r=>setTimeout(r,ms)); const r5=x=>Math.round(x*1e5)/1e5;
async function ask(s,w,n,e){ const q=`[out:json][timeout:170][bbox:${s},${w},${n},${e}];(${Q});out center tags;`; let wait=15000;
  for(let i=0;i<9&&Date.now()-T0<DEADLINE;i++){ const u=SERVERS[i%SERVERS.length]; try{ const ac=new AbortController(); const tm=setTimeout(()=>ac.abort(),200000);
      const res=await fetch(u,{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded','User-Agent':'FYF-Fahrradpass-Helferdaten/1.0 (woechentlich)'},body:'data='+encodeURIComponent(q),signal:ac.signal}); clearTimeout(tm);
      if(!res.ok) throw new Error('HTTP '+res.status); const j=await res.json(); if(!Array.isArray(j.elements)) throw new Error('leer'); if(j.remark&&/error|timed out/i.test(j.remark)) throw new Error(j.remark); return j.elements; }
    catch(e){ console.log(`  ${s},${w}: Versuch ${i+1} an ${new URL(u).host} fehlgeschlagen (${e.message}), warte ${wait/1000} s`); await sleep(wait); wait=Math.min(wait*2,240000); } }
  return null; }
const T0=Date.now(), DEADLINE=125*60000;   // danach keine neuen Gebiete mehr anfangen (Aktion hat 150 min)
fs.mkdirSync(OUT,{recursive:true}); const stand=new Date().toISOString().slice(0,10); let ok=0, bad=[];
for(let s=BBOX[0]; s<BBOX[2]; s+=2) for(let w=BBOX[1]; w<BBOX[3]; w+=2){ const n=Math.min(s+2,BBOX[2]), e=Math.min(w+2,BBOX[3]);
  if(Date.now()-T0>DEADLINE){ bad.push(`${s}_${w}`); continue; }
  console.log(`Gebiet ${s}–${n} N, ${w}–${e} O …`); const el=await ask(s,w,n,e); if(!el){ bad.push(`${s}_${w}`); continue; }
  const T={}; for(let a=s;a<n;a++) for(let b=w;b<e;b++) T[`${a}_${b}`]=[];
  for(const x of el){ const t=x.tags||{}, k=kind(t), la=x.lat??x.center?.lat, lo=x.lon??x.center?.lon; if(!k||la==null) continue; const key=`${Math.floor(la)}_${Math.floor(lo)}`; if(!T[key]) continue;
    const adr=[t['addr:street']&&(t['addr:street']+(t['addr:housenumber']?' '+t['addr:housenumber']:'')),t['addr:city']].filter(Boolean).join(', ');
    T[key].push([k,r5(la),r5(lo),(t.name||t.operator||'').slice(0,80),adr.slice(0,90),(t.opening_hours||'').slice(0,90)]); }
  for(const [key,p] of Object.entries(T)){ const f=path.join(OUT,key+'.json'); if(p.length) fs.writeFileSync(f,JSON.stringify({v:1,stand,p})); else if(fs.existsSync(f)) fs.unlinkSync(f); }
  ok++; console.log(`  ${el.length} Orte`); await sleep(5000); }
const tiles=fs.readdirSync(OUT).filter(f=>/^\d+_\d+\.json$/.test(f)).map(f=>f.replace('.json','')).sort();
const old=fs.existsSync(path.join(OUT,'index.json'))?JSON.parse(fs.readFileSync(path.join(OUT,'index.json'),'utf8')):{};
if(!ok&&!tiles.length){ console.log('Kein Gebiet geladen – Abbruch ohne Änderung.'); process.exit(1); }
fs.writeFileSync(path.join(OUT,'index.json'),JSON.stringify({v:1,stand:ok?stand:(old.stand||stand),bbox:BBOX,tiles,offen:bad,quelle:'© OpenStreetMap-Mitwirkende, ODbL'}));
console.log(`Fertig: ${ok} Gebiete neu, ${bad.length} fehlgeschlagen (${bad.join(' ')||'–'}), ${tiles.length} Kacheln.`);
