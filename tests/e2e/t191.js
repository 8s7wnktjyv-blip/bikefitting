// v.191: Helfer in der Nähe – Standort (gerundet) → OpenStreetMap-Abfrage (hier simuliert) → Liste nach Entfernung, Filter, Route-Link; Einstieg in „Problem lösen“.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE',geolocation:{latitude:49.59876,longitude:11.00412},permissions:['geolocation']}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); }catch(e){} });
 let sent='';
 await c.route('https://overpass-api.de/**',async rt=>{ sent=decodeURIComponent((rt.request().postData()||'').replace(/^data=/,'')); await rt.fulfill({status:200,contentType:'application/json',body:JSON.stringify({elements:[
  {type:'node',lat:49.6000,lon:11.0050,tags:{shop:'bicycle',name:'Radladen Test','addr:street':'Hauptstraße','addr:housenumber':'1',opening_hours:'Mo-Fr 10:00-18:00'}},
  {type:'node',lat:49.5990,lon:11.0045,tags:{amenity:'compressed_air'}},
  {type:'way',center:{lat:49.6100,lon:11.0200},tags:{amenity:'police',name:'Polizeiinspektion Test'}},
  {type:'node',lat:49.5992,lon:11.0040,tags:{amenity:'bicycle_repair_station'}},
  {type:'node',lat:49.6,lon:11.0,tags:{amenity:'bench'}}]})}); });
 const q=await c.newPage(); q.on('pageerror',e=>errs.push(e.message)); await q.goto(BASE+'/rad.html#meine&cfg='+cfg); await q.waitForTimeout(700);
 await q.click('#regb'); await q.fill('#rb','Canyon'); await q.fill('#rm','Grail'); await q.fill('#rf','S'+Math.floor(Math.random()*1e6)); await q.check('#rx'); await q.click('#rg button.btn:not(#rfscan)'); await q.waitForTimeout(1300);
 const code=await q.evaluate(()=>mine()[0].code); await q.evaluate(c=>{ location.hash='#c='+c; },code); await q.waitForTimeout(1500);
 const tool=await q.evaluate(()=>!!document.querySelector('[data-tool="near"]')); if(!tool) bad('Werkzeug unter Mehr Funktionen');
 await q.evaluate(c=>TOOLFN.help(c),code); await q.waitForTimeout(400); await q.click('[data-nrgo]'); await q.waitForTimeout(300);
 await q.click('[data-nr="go"]'); await q.waitForTimeout(1200);
 log('gesendet gerundet:',/around:3000,49\.599,11\.004\)/.test(sent)); if(!/around:3000,49\.599,11\.004\)/.test(sent)) bad('Standort gerundet');
 let r=await q.evaluate(()=>[...document.querySelectorAll('.tpage .nr')].map(a=>[a.querySelector('b').textContent,a.querySelector('.nr-d').firstChild.textContent,a.getAttribute('href')])); log(JSON.stringify(r));
 if(r.length!==4) bad('4 Treffer (Bank ignoriert)'); if(r[0]&&r[0][0]!=='Reparatur-Station') bad('nächster zuerst'); if(!r.some(x=>x[0]==='Radladen Test')) bad('Name');
 if(r[0]&&!/maps\.apple\.com\/\?daddr=49\.5992,11\.004/.test(r[0][2])) bad('Route-Link');
 await q.click('.tpage [data-nf="police"]'); await q.waitForTimeout(150); r=await q.evaluate(()=>[...document.querySelectorAll('.tpage .nr b')].map(b=>b.textContent)); log('Filter Polizei:',JSON.stringify(r)); if(r.length!==1||r[0]!=='Polizeiinspektion Test') bad('Filter');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
