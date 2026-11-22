// v.152: Pass – Rad-Karte als Bild (1080×1350), Teilen/Speichern liefert JPG, ohne Pass-Code; erreichbar über „Mehr“ und Ziele.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE',acceptDownloads:true}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); }catch(e){} });
 const q=await c.newPage(); q.on('pageerror',e=>errs.push('pass: '+e.message)); await q.goto(BASE+'/rad.html#meine&cfg='+cfg); await q.waitForTimeout(700);
 await q.click('#regb'); await q.fill('#rb','Canyon'); await q.fill('#rm','Grail CF 7'); await q.fill('#rf','K'+Date.now()%100000); await q.check('#rx'); await q.click('#rg button.btn:not(#rfscan)'); await q.waitForTimeout(1300);
 const code=await q.evaluate(()=>mine()[0].code); await q.evaluate(c=>{ const o=X(c); o.km=4321; Xset(c,o); location.hash='#c='+c; },code); await q.waitForTimeout(1500);
 await q.evaluate(()=>{ const d=document.querySelector('[data-tmore]'); if(d) d.open=true; }); if(!await q.locator('[data-tool="card"]').count()) bad('Kachel Rad-Karte fehlt');
 await q.click('[data-tool="card"]'); await q.waitForTimeout(1200);
 const im=await q.evaluate(()=>{ const i=[...document.querySelectorAll('.tpage .bcard-img')].pop(); return i?{w:i.naturalWidth,h:i.naturalHeight}:null; }); log('1 Bild:',JSON.stringify(im)); if(!im||im.w!==1080||im.h!==1350) bad('Bildgröße');
 const [dl]=await Promise.all([q.waitForEvent('download',{timeout:5000}).catch(()=>null),q.click('.tpage #bcShare')]); log('2 Datei:',dl?dl.suggestedFilename():'KEINE'); if(!dl||!/\.jpg$/.test(dl.suggestedFilename())) bad('Kein JPG');
 await q.evaluate(()=>{ document.querySelectorAll('.tpage').forEach(t=>t.remove()); document.body.style.overflow=''; });
 await q.click('.gl-goal'); await q.waitForTimeout(400); await q.click('.tpage [data-gl="2000"]'); await q.waitForTimeout(300); const gb=await q.locator('.tpage #glCard').count(); log('3 Knopf auf Ziel-Seite nach Neuzeichnen:',gb); if(!gb) bad('Teilen-Knopf auf Ziel-Seite');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
