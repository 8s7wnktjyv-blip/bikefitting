// v.130: Werkstatt-Tafel – Spalten stimmen, Weiter-Knopf, „Teile sind da“, Karte öffnet Auftrag, Zurück; Handy und großer Bildschirm.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const run=async(name,opt)=>{ const c=await b.newContext(opt); const p=await c.newPage(); p.on('pageerror',e=>errs.push(name+': '+e.message)); p.on('dialog',d=>d.accept('Bremsbeläge'));
  await p.goto(BASE+'/index.html#werkstatt'); await p.waitForTimeout(1500);
  const E=src=>p.evaluate(src);
  await E(()=>{ const S=window.__fitframe.S(); const w=S.workshop.find(x=>x.status==='In Arbeit'); if(w){ w.wait={at:'2026-11-20',note:'Kette'}; } window.__fitframe.save(); });
  await p.evaluate(()=>{ const F=window.__fitframe.T118; F.ui().route='werkstatt'; F.render(); }); await p.waitForTimeout(300);
  if(!await p.locator('#view [data-nav="tafel"]').count()) bad(name+': Knopf Werkstatt-Tafel fehlt');
  await p.click('#view [data-nav="tafel"]'); await p.waitForTimeout(500);
  const cnt=await E(()=>[...document.querySelectorAll('.tf-col')].map(c=>c.querySelectorAll('.tf-card').length));
  const exp=await E(()=>{ const S=window.__fitframe.S(); const o=S.workshop.filter(w=>!['Übergeben','Storniert'].includes(w.status)); return [o.filter(w=>!w.wait&&['Angenommen','Kostenvoranschlag','Freigabe ausstehend'].includes(w.status)).length,o.filter(w=>!w.wait&&w.status==='In Arbeit').length,o.filter(w=>w.wait).length,o.filter(w=>!w.wait&&w.status==='Abholbereit').length]; });
  log(name,'1 Spalten',JSON.stringify(cnt),'erwartet',JSON.stringify(exp)); if(JSON.stringify(cnt)!==JSON.stringify(exp)) bad(name+': Spalten falsch');
  const ov=await E(()=>document.documentElement.scrollWidth>innerWidth+1); log(name,'2 Querscroll:',ov); if(ov) bad(name+': Querscroll');
  const cols=await E(()=>getComputedStyle(document.querySelector('.tafel')).gridTemplateColumns.split(' ').length); log(name,'2b Spalten nebeneinander:',cols);
  // Weiter-Knopf
  const nb=p.locator('[data-act="tafelNext"]').first(); if(await nb.count()){ const id=await nb.getAttribute('data-id'); const before=await E(`window.__fitframe.S().workshop.find(x=>x.id==='${id}').status`); await nb.click(); await p.waitForTimeout(400);
    const after=await E(`window.__fitframe.S().workshop.find(x=>x.id==='${id}').status`); const still=await E(()=>document.querySelector('.tafel')!==null); const drawer=await E(()=>!!document.querySelector('#overlay .drawer'));
    log(name,'3 Weiter:',before,'→',after,'Tafel bleibt:',still,'Fenster zu:',!drawer); if(before===after||!still||drawer) bad(name+': Weiter-Knopf'); } else bad(name+': kein Weiter-Knopf');
  // Teile sind da
  const pb=p.locator('[data-act="tafelParts"]').first(); if(await pb.count()){ const id=await pb.getAttribute('data-id'); await pb.click(); await p.waitForTimeout(400); const w=await E(`!!window.__fitframe.S().workshop.find(x=>x.id==='${id}').wait`); log(name,'4 Teile sind da → wartet noch:',w); if(w) bad(name+': Teile sind da'); } else bad(name+': kein Teile-Knopf');
  // Karte öffnet Auftrag, Zurück
  await p.locator('.tf-main').first().click(); await p.waitForTimeout(400); const dr=await E(()=>!!document.querySelector('#overlay .drawer')); log(name,'5 Karte öffnet Auftrag:',dr); if(!dr) bad(name+': Karte öffnet nicht');
  await E(()=>window.__fitframe.T118.closeDrawer()); await p.click('#view [data-nav="werkstatt"]'); await p.waitForTimeout(400); const back=await E(()=>window.__fitframe.T118.ui().route); log(name,'6 Zurück:',back); if(back!=='werkstatt') bad(name+': Zurück');
  await c.close(); };
 await run('iPhone',{...devices['iPhone 13'],locale:'de-DE'}); await run('Bildschirm',{viewport:{width:1600,height:900}});
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
