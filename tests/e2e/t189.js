// v.189: Ausweis-Angaben im Diebstahl-Bereich (nur lokal), im Anzeige-Blatt, nie im Verkaufstext.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE'}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); }catch(e){} });
 const q=await c.newPage(); q.on('pageerror',e=>errs.push(e.message)); await q.goto(BASE+'/rad.html#meine&cfg='+cfg); await q.waitForTimeout(700);
 await q.click('#regb'); await q.fill('#rb','Canyon'); await q.fill('#rm','Grail'); await q.fill('#rf','S'+Math.floor(Math.random()*1e6)); await q.check('#rx'); await q.click('#rg button.btn:not(#rfscan)'); await q.waitForTimeout(1300);
 const code=await q.evaluate(()=>mine()[0].code); await q.evaluate(c=>{ location.hash='#c='+c; },code); await q.waitForTimeout(1600);
 await q.evaluate(c=>TOOLFN.theft(c),code); await q.waitForTimeout(400);
 await q.click('[data-idf] summary'); await q.fill('#idf_loc','unten am Tretlager'); await q.fill('#idf_cod','ADFC ER-123-456'); await q.fill('#idf_holder','Max Muster'); await q.click('[data-idfs]'); await q.waitForTimeout(200);
 const st=await q.evaluate(c=>X(c).idf,code); log('gespeichert:',JSON.stringify(st)); if(!st||st.cod!=='ADFC ER-123-456'||st.holder!=='Max Muster') bad('Speichern');
 const n=await q.evaluate(()=>document.querySelector('[data-idf] summary .muted').textContent); if(n!=='3 von 5') bad('Zähler');
 await q.click('#thSheet'); await q.waitForTimeout(900); const t=await q.evaluate(()=>{ const f=document.querySelector('.docv iframe'); return f&&f.contentDocument?f.contentDocument.body.innerText:''; }); log('Anzeige-Blatt hat Codierung:',/ADFC ER-123-456/.test(t),'Position:',/unten am Tretlager/.test(t)); if(!/ADFC ER-123-456/.test(t)||!/Halter\/in \(falls abweichend\)\s*Max Muster/.test(t)) bad('Anzeige-Blatt');
 const leak=await q.evaluate(c=>{ try{ return JSON.stringify(Pof(c)).includes('ER-123'); }catch(e){ return false; } },code); if(leak) bad('darf nicht im öffentlichen Pass stehen');
 // Foto im Vollbild
 await q.evaluate(()=>{ document.querySelectorAll('.docv,.tpage').forEach(x=>x.remove()); document.body.style.overflow=''; });
 await q.evaluate(c=>{ const cv=document.createElement('canvas'); cv.width=800; cv.height=600; const g=cv.getContext('2d'); g.fillStyle='#456'; g.fillRect(0,0,800,600); localStorage.setItem('fyfpass:img:'+c,cv.toDataURL('image/jpeg')); location.hash='#meine'; },code); await q.waitForTimeout(500); await q.evaluate(c=>{ location.hash='#c='+c; },code); await q.waitForTimeout(1500);
 await q.click('.hero .bikepic img'); await q.waitForTimeout(300); let lb=await q.evaluate(()=>!!document.querySelector('.lbx')); log('Vollbild offen:',lb); if(!lb) bad('Foto antippen öffnet Vollbild');
 const box=await q.evaluate(()=>{ const r=document.querySelector('.lbx-stage').getBoundingClientRect(); return {x:r.left+r.width/2,y:r.top+r.height/2}; });
 await q.mouse.click(box.x,box.y); await q.waitForTimeout(60); await q.mouse.click(box.x,box.y); await q.waitForTimeout(300);
 const tf=await q.evaluate(()=>document.querySelector('.lbx img').style.transform); log('nach Doppeltippen:',tf); if(!/scale\(2\.5\)/.test(tf)) bad('Doppeltippen zoomt');
 await q.keyboard.press('Escape'); await q.waitForTimeout(200); lb=await q.evaluate(()=>!!document.querySelector('.lbx')); if(lb) bad('Esc schließt');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
