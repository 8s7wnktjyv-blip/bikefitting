// v.246 Pass: mehrere Bilder je Rad (erstes = Titelbild, Galerie im Foto-Menü),
// fertige Anzeige für eBay Kleinanzeigen (Titel höchstens 65 Zeichen, Kopier-Knöpfe),
// Bilder und Verkaufsunterlage als JPG bereitstellen.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE'}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); }catch(e){} });
 const q=await c.newPage(); q.on('pageerror',e=>errs.push(e.message));
 await q.goto(BASE+'/rad.html#meine&cfg='+cfg); await q.waitForTimeout(800);
 await q.click('#regb'); await q.fill('#rb','Canyon'); await q.fill('#rm','Grail'); await q.fill('#rf','S'+Math.floor(Math.random()*1e6)); await q.check('#rx'); await q.click('#rg button.btn:not(#rfscan)'); await q.waitForTimeout(1400);
 const code=await q.evaluate(()=>((mine()[0]||{}).code)||''); if(!code){ bad('Rad angelegt'); log('Fehler:',errs); await b.close(); process.exit(1); }
 // zwei Bilder ablegen, wie nach zwei Fotos
 await q.evaluate(c=>{ const mk=t=>{ const cv=document.createElement('canvas'); cv.width=600; cv.height=450; const g=cv.getContext('2d'); g.fillStyle=t; g.fillRect(0,0,600,450); g.fillStyle='#111'; g.fillRect(60,60,480,330); return cv.toDataURL('image/jpeg',.8); };
   localStorage.setItem('fyfpass:imgs:'+c,JSON.stringify([mk('#eeeeee'),mk('#dddddd')])); location.hash='#c='+c; },code);
 await q.waitForTimeout(1500);
 const hero=await q.evaluate(c=>({img:!!document.querySelector('.hero .bikepic img'),badge:(document.querySelector('.hero .bikepic span')||{}).textContent||'',count:photosGet(c).length,same:photoGet(c)===photosGet(c)[0]}),code);
 log('Rad:',JSON.stringify(hero)); if(!hero.img) bad('Titelbild im Rad'); if(hero.count!==2) bad('zwei Bilder gespeichert'); if(!/2 Bilder/.test(hero.badge)) bad('Anzahl am Rad'); if(!hero.same) bad('erstes Bild ist Titelbild');
 // Foto-Menü: Galerie mit beiden Bildern, je Bild Löschen und Zuschneiden
 await q.click('.hero #photo'); await q.waitForTimeout(600);
 const gal=await q.evaluate(()=>({imgs:document.querySelectorAll('.sheet img').length,del:document.querySelectorAll('.sheet [data-del]').length,edit:document.querySelectorAll('.sheet [data-edit]').length,main:document.querySelectorAll('.sheet [data-main]').length}));
 log('Galerie:',JSON.stringify(gal)); if(gal.imgs<2) bad('Galerie zeigt beide Bilder'); if(gal.del!==2) bad('je Bild Löschen'); if(gal.edit!==2) bad('je Bild Zuschneiden'); if(gal.main<1) bad('Als Titelbild wählbar');
 await q.click('.sheet [data-a="x"]'); await q.waitForTimeout(400);
 // Verkaufen: Kleinanzeigen-Karte
 await q.evaluate(()=>TOOLFN.sell(mine()[0].code)); await q.waitForTimeout(800);
 const sell=await q.evaluate(()=>({title:((document.querySelector('#kaT')||{}).value)||'',note:(document.querySelector('#kaTn')||{}).textContent||'',all:!!document.querySelector('#kaAll'),cp:!!document.querySelector('#kaCp'),cb:!!document.querySelector('#kaCb'),imgs:(document.querySelector('#kaImgs')||{}).textContent||'',imgsOff:!!(document.querySelector('#kaImgs')||{}).disabled,card:!!document.querySelector('#kaCard'),shots:!!document.querySelector('#kaShots'),link:(document.querySelector('.tpage a[href*="kleinanzeigen.de"]')||{}).href||''}));
 log('Kleinanzeigen:',JSON.stringify(sell)); if(!sell.title) bad('Titel vorbelegt'); if(sell.title.length>65) bad('Titel höchstens 65 Zeichen'); if(!/65 Zeichen/.test(sell.note)) bad('Zeichen-Zähler'); if(!sell.all||!sell.cp||!sell.cb) bad('Kopier-Knöpfe'); if(!/2 Bilder/.test(sell.imgs)) bad('Bilder-Knopf nennt Anzahl'); if(sell.imgsOff) bad('Bilder-Knopf bedienbar'); if(!sell.card) bad('Anzeige als Bild'); if(!sell.shots) bad('Verkaufsunterlage als Bilder'); if(!/kleinanzeigen\.de/.test(sell.link)) bad('Link zu Kleinanzeigen');
 // Titel ändern bleibt gespeichert
 await q.fill('#kaT','Canyon Grail CF SL 7 · Gr. M · Gravel'); await q.waitForTimeout(300);
 const saved=await q.evaluate(()=>({store:((X(mine()[0].code).sell)||{}).kaTitle||'',counter:(document.querySelector('#kaTn')||{}).textContent||''}));
 log('Titel gespeichert:',JSON.stringify(saved)); if(!/Grail CF SL/.test(saved.store)) bad('Titel gespeichert'); if(!/\/ 65/.test(saved.counter)) bad('Zähler zählt mit');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
