const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url'); const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE'}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); }catch(e){} }); const p=await c.newPage(); const errs=[]; p.on('pageerror',e=>errs.push(e.message));
 await p.goto(BASE+'/rad.html#meine&cfg='+cfg); await p.waitForTimeout(700); await p.click('#regb'); await p.fill('#rb','Cube'); await p.fill('#rm','Attain'); await p.fill('#rf','K'+Date.now()%100000); await p.check('#rx'); await p.click('#rg button.btn:not(#rfscan)'); await p.waitForTimeout(1200);
 const code=await p.evaluate(()=>mine()[0].code); await p.evaluate(c=>{ location.hash='#c='+c; },code); await p.waitForTimeout(1200);
 const rows=await p.evaluate(()=>[...document.querySelectorAll('.health [data-hk]')].map(e=>e.dataset.hk)); console.log('antippbar:',rows.join(' | '));
 const res={};
 for(const n of rows){ await p.evaluate(()=>{ document.querySelectorAll('.tpage').forEach(t=>t.remove()); const d=document.querySelector('.health'); if(d) d.open=true; });
   await p.locator(`.health [data-hk="${n}"]`).click(); await p.waitForTimeout(450);
   res[n]=await p.evaluate(()=>{ const t=[...document.querySelectorAll('.tpage')].pop(); if(!t) return 'KEIN FENSTER'; const h=t.innerText.replace('‹ Zurück','').replace(/\s+/g,' ').slice(0,40); const wb=t.querySelector('[data-wearbox] details'); return h+(wb?(' · Messung offen:'+wb.open):''); }); }
 console.log(JSON.stringify(res,null,1));
 // Kettenmessung eintragen -> Bericht
 await p.evaluate(()=>{ document.querySelectorAll('.tpage').forEach(t=>t.remove()); }); await p.locator('.health [data-hk="Verschleiß (Kette)"]').click({force:true}); await p.waitForTimeout(500);
 await p.fill('#wrV','0,6 %'); await p.click('#wrS'); await p.waitForTimeout(600);
 const kette=await p.evaluate(c=>healthReport(c).F.find(f=>f[0]==='Verschleiß (Kette)'),code); console.log('Kette:',JSON.stringify(kette));
 await p.evaluate(()=>{ document.querySelectorAll('.tpage').forEach(t=>t.remove()); }); await p.evaluate(c=>{ location.hash='#c='+c+'&x=1'; },code); await p.waitForTimeout(1000);
 console.log('Bericht-Zeile:', await p.evaluate(()=>{ const r=document.querySelector('.health [data-hk="Verschleiß (Kette)"]'); return r?r.textContent.replace(/\s+/g,' '):'-'; }));
 
 // fremdes Rad: nicht antippbar
 console.log('fremd antippbar:', await p.evaluate(c=>{ const h=healthHtml.toString(); return /data-hk/.test(healthHtml('ZZZZZZ'))?'JA':'nein'; },code));
 console.log('Fehler:',errs.length?errs:'keine'); await b.close(); })();
