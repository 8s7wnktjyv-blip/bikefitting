// v.127: Dominiks Canyon Grail CF 7 hat in den festen Demodaten das Pedalsystem „Shimano SPD“.
// Vorhandene Daten: nur nachtragen, wenn das Feld leer ist – ein eingetragener Wert bleibt immer erhalten.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765'; const KEY='fitframe-demo-v3';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); let bad=0;
 const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE'}); const p=await c.newPage(); p.on('pageerror',e=>errs.push(e.message)); p.on('dialog',d=>d.accept());
 const grail=()=>p.evaluate(K=>{ const S=JSON.parse(localStorage.getItem(K)||'{}'); const cu=(S.customers||[]).find(x=>/dominik böhm/i.test(x.name||'')); const bk=cu&&(S.bikes||[]).filter(x=>x.customerId===cu.id&&/Grail/.test(x.model||'')); return bk&&bk.length?{n:bk.length,pedal:bk[0].pedal,size:bk[0].size,model:bk[0].model}:null; },KEY);
 const setOld=(pedal)=>p.evaluate(([K,v])=>{ const S=JSON.parse(localStorage.getItem(K)); delete S.fixPedal1; const cu=S.customers.find(x=>/dominik böhm/i.test(x.name)); S.bikes.filter(x=>x.customerId===cu.id&&/Grail/.test(x.model||'')).forEach(x=>{ x.pedal=v; }); localStorage.setItem(K,JSON.stringify(S)); },[KEY,pedal]);
 await p.goto(BASE+'/index.html'); await p.waitForTimeout(1500);
 let g=await grail(); log('1 Frischer Start:',JSON.stringify(g)); if(!g||g.pedal!=='Shimano SPD'||g.size!=='M'||g.model!=='Grail CF 7') { bad++; log('  FEHLT: SPD/M/Grail CF 7'); }
 await setOld(''); await p.reload(); await p.waitForTimeout(1500);
 g=await grail(); log('2 Alter Stand ohne Pedal:',JSON.stringify(g)); if(!g||g.pedal!=='Shimano SPD'){ bad++; log('  FEHLT: Nachtrag'); }
 await setOld('Look Keo'); await p.reload(); await p.waitForTimeout(1500);
 g=await grail(); log('3 Eigener Wert bleibt:',JSON.stringify(g)); if(!g||g.pedal!=='Look Keo'){ bad++; log('  FEHLT: eigener Wert überschrieben'); }
 if(g&&g.n!==1){ bad++; log('  FEHLT: Rad doppelt angelegt'); }
 if(bad) errs.push(bad+' Prüfung(en) fehlgeschlagen');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
