// v.209 (Punkt 17, Stufe 1): Händlerfinder zeigt unter den FYF-Partnern „Weitere Fahrradläden in der Nähe“ aus OpenStreetMap –
// klar getrennt („Kein FYF-Partner · Daten von OpenStreetMap“), ohne Anfrage-Formular; Standort oder Ort/PLZ (Nominatim, gemockt);
// zuerst vorab geladene Kacheln (keine Live-Anfrage), Doppelte zu FYF-Partnern ausgeblendet, Umkreis umschaltbar, Englisch, hell/dunkel ohne Querscrollen.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 const idx={v:1,stand:'2026-11-23',bbox:[45,5,56,18],tiles:['49_10','49_11']};
 const tiles={'49_11':{v:1,stand:'2026-11-23',p:[['shop',49.59,11.005,'Radhaus Erlangen','Hauptstr. 1, Erlangen','Mo-Fr 10:00-18:00','+49 9131 123456','radhaus-test.de','n1'],['shop',49.595,11.01,'Bikes Muster GmbH','Nürnberger Str. 5, Erlangen','','','','n2'],['air',49.59,11.0,'','',''],['shop',49.6,11.02,'Alter Eintrag','Weg 2, Erlangen',''],['shop',49.65,11.2,'Weit weg Rad','','']]},
  '49_10':{v:1,stand:'2026-11-23',p:[['shop',49.59,10.99,'Zweirad West','Westweg 3, Erlangen','','','javascript:alert(1)','n3']]}};
 const prof=[{slug:'muster',name:'Bike Muster',street:'Nürnberger Str. 5',zip:'91052',city:'Erlangen',services:['Werkstatt'],partner:true,certified:false,features:['pass']}];
 const run=async(opts={})=>{ const c=await b.newContext({...devices['iPhone 13'],locale:opts.en?'en-GB':'de-DE',geolocation:{latitude:49.5912,longitude:11.0034},permissions:['geolocation']});
   await c.addInitScript(([th,en])=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:finderIntro','1'); if(th) localStorage.setItem('fyfpass:theme',th); if(en) localStorage.setItem('fyfpass:lang','en'); }catch(e){} },[opts.theme||'',opts.en?1:0]);
   const q=await c.newPage(); q.on('pageerror',e=>errs.push(e.message)); const n={live:0,geo:0};
   await c.route('**/helfer/index.json',r=>r.fulfill({contentType:'application/json',body:JSON.stringify(idx)}));
   await c.route(/helfer\/(49_1[01])\.json/,r=>{ const k=r.request().url().match(/(49_1[01])\.json/)[1]; r.fulfill({contentType:'application/json',body:JSON.stringify(tiles[k])}); });
   await c.route(/\/rest\/v1\/dealer_profiles/,r=>r.fulfill({contentType:'application/json',body:JSON.stringify(prof)}));
   await c.route(/overpass|kumi|coffee/,r=>{ n.live++; r.fulfill({contentType:'application/json',body:JSON.stringify({elements:[{type:'node',id:7,lat:41.901,lon:12.501,tags:{shop:'bicycle',name:'Bici Roma',phone:'+39 06 1234567'}}]})}); });
   await c.route(/nominatim/,r=>{ n.geo++; const u=r.request().url(); const rom=/roma/i.test(decodeURIComponent(u)); const none=/xyzort/i.test(decodeURIComponent(u)); r.fulfill({contentType:'application/json',body:JSON.stringify(none?[]:[rom?{lat:'41.9',lon:'12.5',display_name:'Roma, Lazio, Italia'}:{lat:'49.5897',lon:'11.0039',display_name:'Erlangen, Mittelfranken, Bayern'}])}); });
   await q.goto(BASE+'/finder.html#w=1&cfg='+cfg); await q.waitForTimeout(1300); return {c,q,n}; };
 const names=q=>q.evaluate(()=>[...document.querySelectorAll('#osm .osm-c b')].map(x=>x.textContent));
 // 1) Standort → Vorab-Daten, keine Live-Anfrage, Doppelter ausgeblendet, Umkreis beachtet, Kennzeichen, Knöpfe
 let {c,q,n}=await run();
 if(!(await q.locator('#osm').count())) bad('Bereich „Weitere Fahrradläden“');
 const before=await q.evaluate(()=>document.getElementById('osm').innerText); if(!/Weitere Fahrradläden in der Nähe/.test(before)||!/OpenStreetMap-Mitwirkende/.test(before)) bad('Titel und Quellenangabe');
 if(n.live||n.geo) bad('nichts ohne Knopfdruck abfragen');
 await q.click('[data-osm="geo"]'); await q.waitForTimeout(1200); let L=await names(q); log('Standort:',JSON.stringify(L),JSON.stringify(n));
 if(n.live) bad('keine Live-Anfrage im Gebiet'); if(!L.includes('Radhaus Erlangen')||!L.includes('Zweirad West')||!L.includes('Alter Eintrag')) bad('Läden aus Vorab-Daten (auch alte Kacheln ohne Telefon)');
 if(L.includes('Bikes Muster GmbH')) bad('Doppelter zum FYF-Partner ausgeblendet'); if(L.includes('Weit weg Rad')) bad('Umkreis 5 km');
 if(L[0]!=='Radhaus Erlangen') bad('nach Entfernung sortiert');
 const card=await q.evaluate(()=>{ const c=[...document.querySelectorAll('#osm .osm-c')].find(x=>/Radhaus/.test(x.innerText)); return {t:c.innerText,links:[...c.querySelectorAll('a')].map(a=>a.getAttribute('href'))}; });
 if(!/Kein FYF-Partner/i.test(card.t)) bad('Kennzeichen „Kein FYF-Partner“'); if(!card.links.some(h=>/^https:\/\/maps\.apple\.com\/\?daddr=49\.59,11\.005/.test(h))) bad('Route');
 if(!card.links.includes('tel:+499131123456')) bad('Anrufen'); if(!card.links.includes('https://radhaus-test.de')) bad('Website');
 const west=await q.evaluate(()=>[...document.querySelectorAll('#osm .osm-c')].find(x=>/Zweirad West/.test(x.innerText)).innerHTML); if(/javascript:/i.test(west)) bad('unsichere Website-Adresse nicht als Link');
 if(await q.locator('#osm form#inq, #osm textarea').count()) bad('kein Anfrage-Formular bei OSM-Läden');
 if(!/Stand 23\.11\.2026/.test(await q.locator('#osm').innerText())) bad('Stand der Daten');
 await q.click('[data-osmr="25000"]'); await q.waitForTimeout(900); L=await names(q); if(!L.includes('Weit weg Rad')) bad('Umkreis 25 km'); log('25 km:',L.length);
 // Partner-Suche tippen lässt Ergebnis stehen
 await q.fill('#q','Erl'); await q.waitForTimeout(400); if(!(await names(q)).length) bad('Ergebnis bleibt beim Tippen in der Partner-Suche');
 const sc=await q.evaluate(()=>document.documentElement.scrollWidth>innerWidth+1); if(sc) bad('kein Querscrollen (hell)');
 await q.locator('#osm').scrollIntoViewIfNeeded(); await q.screenshot({path:'/tmp/t209-hell.png'});
 // 2) Ort außerhalb des Gebiets → Nominatim + live; unbekannter Ort → Hinweis
 await q.fill('#osmq','Roma'); await q.click('#osm .osm-f button'); await q.waitForTimeout(1300); L=await names(q); log('Roma:',JSON.stringify(L),JSON.stringify(n));
 if(!n.geo||!n.live||!L.includes('Bici Roma')) bad('Ortssuche + Live-Abfrage außerhalb');
 if(!/bei Roma/.test(await q.locator('#osm').innerText())) bad('Ort in der Zusammenfassung');
 const g0=n.geo; await q.fill('#osmq','Roma'); await q.click('#osm .osm-f button'); await q.waitForTimeout(800); if(n.geo!==g0) bad('Ortssuche im Browser zwischengespeichert');
 await q.fill('#osmq','xyzort'); await q.click('#osm .osm-f button'); await q.waitForTimeout(800); if(!/nicht gefunden/.test(await q.locator('#osm').innerText())) bad('Hinweis bei unbekanntem Ort');
 await c.close();
 // 3) Overpass gestört außerhalb → Hinweis + Nochmal
 ({c,q,n}=await run()); await c.unroute(/overpass|kumi|coffee/); await c.route(/overpass|kumi|coffee/,r=>r.fulfill({status:504,body:'at capacity'}));
 await q.fill('#osmq','Roma'); await q.click('#osm .osm-f button'); await q.waitForTimeout(1500); if(!(await q.locator('[data-osm="retry"]').count())) bad('Nochmal suchen bei Störung'); await c.close();
 // 4) dunkel + Englisch
 ({c,q,n}=await run({theme:'dark',en:1})); await q.waitForTimeout(600); await q.click('[data-osm="geo"]'); await q.waitForTimeout(1500);
 const en=await q.locator('#osm').innerText(); log('EN:',en.slice(0,160).replace(/\n/g,' | '));
 if(!/More bike shops nearby/.test(en)||!/Not an FYF partner/i.test(en)||/Weitere Fahrradläden|Kein FYF-Partner/.test(en)) bad('Englisch');
 if(await q.evaluate(()=>document.documentElement.scrollWidth>innerWidth+1)) bad('kein Querscrollen (dunkel)');
 await q.locator('#osm').scrollIntoViewIfNeeded(); await q.screenshot({path:'/tmp/t209-dunkel.png'}); await c.close();
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
