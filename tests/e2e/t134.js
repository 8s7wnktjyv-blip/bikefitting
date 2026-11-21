// v.134: Bestellvorschlag zieht offene Bestellungen ab – zweimal „Aus Bestellvorschlag anlegen“ erzeugt keine Doppelbestellung.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const p=await (await b.newContext({...devices['iPhone 13'],locale:'de-DE'})).newPage(); p.on('pageerror',e=>errs.push(e.message)); await p.goto(BASE+'/index.html'); await p.waitForTimeout(1500);
 const E=f=>p.evaluate(f);
 await E(()=>{ const S=window.__fitframe.S(); S.suppliers=[{id:'s1',name:'Großhandel A'}]; S.purchaseOrders=[]; S.inventory=[{sku:'K1',name:'Kette 11-fach',stock:1,min:4,ek:20,supplierId:'s1'},{sku:'B1',name:'Bremsbeläge',stock:10,min:2,ek:8,supplierId:'s1'}]; window.__fitframe.save(); const F=window.__fitframe.T118; F.ui().route='lager'; F.render(); });
 await p.waitForTimeout(300); let t=await E(()=>document.body.innerText); const m1=/Kette 11-fach[^\n]*\n?[^\n]*?(\d+) Stk\./.exec(t); log('1 Vorschlag Kette:',m1&&m1[1]); if(!m1||m1[1]!=='7') bad('Vorschlag Kette 7 Stk. erwartet');
 await E(()=>window.__fitframe.T118.ACT.poFromSuggest()); await E(()=>window.__fitframe.T118.closeDrawer()); await p.waitForTimeout(300);
 const n1=await E(()=>window.__fitframe.S().purchaseOrders.length); log('2 Bestellungen nach 1. Klick:',n1); if(n1!==1) bad('1 Bestellung erwartet');
 t=await E(()=>document.body.innerText); log('3 Hinweis schon bestellt:',/schon bestellt/.test(t),'Knopf weg:',!/Aus Bestellvorschlag anlegen/.test(t)); if(!/schon bestellt/.test(t)) bad('Hinweis fehlt');
 const sug=await E(()=>Object.keys(window.__fitframe.orderSuggest()).length); log('4 Vorschlag danach leer:',sug===0); if(sug!==0) bad('Vorschlag nicht leer');
 // Teillieferung: 3 von 7 erhalten (4 unterwegs), Bestand 0, Mindestbestand 6 → Vorschlag = 6*2-0-4 = 8
 await E(()=>{ const S=window.__fitframe.S(); const po=S.purchaseOrders[0]; po.status='teil'; po.lines[0].recv=3; S.inventory[0].stock=0; S.inventory[0].min=6; window.__fitframe.save(); });
 const s2=await E(()=>{ const g=window.__fitframe.orderSuggest(); return (g.s1||[]).map(x=>x.sku+':'+x.need+' (bestellt '+x.onOrder+')'); }); log('5 nach Teillieferung und Verbrauch:',JSON.stringify(s2)); if(JSON.stringify(s2)!=='["K1:8 (bestellt 4)"]') bad('Rechnung mit offener Restmenge');
 const ov=await E(()=>document.documentElement.scrollWidth>innerWidth+1); if(ov) bad('Querscroll');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
