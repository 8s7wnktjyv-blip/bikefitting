// v.200: „Helfer in der Nähe“ mit Karte (Leaflet/OSM): Pins für Luft, Schlauch-Automat, Laden; Filter wirkt auf Karte; „Panne unterwegs?“ aus Werkstätten öffnet direkt die Helfer.
// Leaflet kommt im Test aus tests/e2e/fixtures/leaflet (Netz gesperrt), Kacheln als graue Fläche.
const {chromium,devices}=require('playwright'); const fs=require('fs'); const path=require('path'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url'); const F=path.join(__dirname,'fixtures','leaflet');
 const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE',geolocation:{latitude:48.137,longitude:11.575},permissions:['geolocation']}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); }catch(e){} });
 const q=await c.newPage(); q.on('pageerror',e=>errs.push(e.message));
 await q.route(/cdnjs\.cloudflare\.com\/.*leaflet\.min\.js/,r=>r.fulfill({contentType:'application/javascript',body:fs.readFileSync(path.join(F,'leaflet.js'))}));
 await q.route(/cdnjs\.cloudflare\.com\/.*leaflet\.min\.css/,r=>r.fulfill({contentType:'text/css',body:fs.readFileSync(path.join(F,'leaflet.css'))}));
 const png=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mN4/w8AAn8B9kCw5qYAAAAASUVORK5CYII=','base64');
 await q.route(/tile\.openstreetmap\.org/,r=>r.fulfill({contentType:'image/png',body:png}));
 await q.route(/overpass/,r=>r.fulfill({contentType:'application/json',body:JSON.stringify({elements:[{type:'node',id:1,lat:48.138,lon:11.576,tags:{amenity:'compressed_air'}},{type:'node',id:2,lat:48.139,lon:11.579,tags:{amenity:'vending_machine',vending:'bicycle_tube'}},{type:'node',id:3,lat:48.14,lon:11.57,tags:{shop:'bicycle',name:'Radl Test'}}]})}));
 await q.goto(BASE+'/finder.html#w=1&cfg='+cfg); await q.waitForTimeout(1500); await q.click('a.nr-help'); await q.waitForTimeout(1500);
 const t=await q.evaluate(()=>{ const p=[...document.querySelectorAll('.tpage')].pop(); return p?p.innerText:''; }); if(!/Helfer in der Nähe/.test(t)) bad('Panne unterwegs öffnet Helfer');
 await q.click('[data-nr="go"]'); await q.waitForTimeout(2500);
 let r=await q.evaluate(()=>({map:!!document.querySelector('.nr-map .leaflet-container, .nr-map.leaflet-container'),pins:document.querySelectorAll('.nr-map .nr-pin').length,list:document.querySelectorAll('.nr').length}));
 log('Karte:',JSON.stringify(r)); if(!r.map) bad('Karte sichtbar'); if(r.pins!==3) bad('3 Pins'); if(r.list!==3) bad('Liste bleibt');
 await q.screenshot({path:'/tmp/t200.png'});
 await q.click('[data-nf="tube"]'); await q.waitForTimeout(800); r=await q.evaluate(()=>({pins:document.querySelectorAll('.nr-map .nr-pin').length,list:document.querySelectorAll('.nr').length})); log('Filter Schlauch:',JSON.stringify(r)); if(r.pins!==1||r.list!==1) bad('Filter wirkt auf Karte');
 await q.click('.nr-map .nr-pin'); await q.waitForTimeout(500); const pop=await q.evaluate(()=>{ const p=document.querySelector('.leaflet-popup-content'); return p?p.innerText:''; }); log('Popup:',pop.replace(/\n/g,' | ')); if(!/Schlauch-Automat/.test(pop)||!/Route/.test(pop)) bad('Pin zeigt Name und Route');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
