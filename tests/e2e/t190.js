// v.190: Rad-Karte teilen in Dunkel / Hell / Sticker (PNG mit Transparenz), Auswahl bleibt gespeichert.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE'}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); }catch(e){} });
 const q=await c.newPage(); q.on('pageerror',e=>errs.push(e.message)); await q.goto(BASE+'/rad.html#meine&cfg='+cfg); await q.waitForTimeout(700);
 await q.click('#regb'); await q.fill('#rb','Canyon'); await q.fill('#rm','Grail'); await q.fill('#rf','S'+Math.floor(Math.random()*1e6)); await q.check('#rx'); await q.click('#rg button.btn:not(#rfscan)'); await q.waitForTimeout(1300);
 const code=await q.evaluate(()=>mine()[0].code); await q.evaluate(c=>{ location.hash='#c='+c; },code); await q.waitForTimeout(1500);
 await q.evaluate(c=>TOOLFN.card(c),code); await q.waitForTimeout(900);
 let r=await q.evaluate(()=>({n:document.querySelectorAll('.tpage [data-bcs]').length,on:(document.querySelector('.tpage [data-bcs].on')||{}).textContent,img:/^data:image\/jpeg/.test((document.querySelector('.tpage .bcard-img')||{}).src||'')})); log('Start:',JSON.stringify(r)); if(r.n!==3||r.on!=='Dunkel'||!r.img) bad('Start Dunkel');
 await q.click('.tpage [data-bcs="sticker"]'); await q.waitForTimeout(900);
 r=await q.evaluate(async()=>{ const s=document.querySelector('.tpage .bcard-img').src; const im=new Image(); im.src=s; await im.decode(); const cv=document.createElement('canvas'); cv.width=im.width; cv.height=im.height; const g=cv.getContext('2d'); g.drawImage(im,0,0); return {png:/^data:image\/png/.test(s),corner:g.getImageData(5,5,1,1).data[3],w:im.width,h:im.height,saved:localStorage.getItem('fyfpass:cardStyle')}; }); log('Sticker:',JSON.stringify(r));
 if(!r.png||r.corner!==0||r.w!==r.h) bad('Sticker transparent und quadratisch'); if(!/sticker/.test(r.saved||'')) bad('Auswahl gespeichert');
 await q.click('.tpage [data-bcs="light"]'); await q.waitForTimeout(900); r=await q.evaluate(async()=>{ const s=document.querySelector('.tpage .bcard-img').src; const im=new Image(); im.src=s; await im.decode(); const cv=document.createElement('canvas'); cv.width=im.width; cv.height=im.height; const g=cv.getContext('2d'); g.drawImage(im,0,0); const d=g.getImageData(540,1300,1,1).data; return d[0]+d[1]+d[2]; }); log('Hell Helligkeit unten:',r); if(r<600) bad('Hell ist hell');
 // Wünsch dir was
 await q.evaluate(()=>{ document.querySelectorAll('.tpage').forEach(x=>x.remove()); document.body.style.overflow=''; location.hash='#meine'; }); await q.waitForTimeout(1300);
 await q.click('[data-wish] summary'); await q.waitForTimeout(150); const nW=await q.evaluate(()=>document.querySelectorAll('[data-wish] [data-wk]').length); if(nW<4) bad('Wunschliste');
 await q.click('[data-wish] [data-wk="push"]'); await q.waitForTimeout(150);
 r=await q.evaluate(()=>({btn:document.querySelector('[data-wish] [data-wk="push"]').textContent,note:document.querySelector('[data-wish] summary .cl-note').textContent,ls:localStorage.getItem('fyfpass:wish'),hit:localStorage.getItem('fyfpass:hit:wunsch_push')})); log('Wunsch:',JSON.stringify(r));
 if(r.btn!=='✓ Gewünscht'||r.note!=='1 gewählt'||!/push/.test(r.ls||'')||!r.hit) bad('Wunsch zählt');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
