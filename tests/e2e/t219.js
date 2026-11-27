// v.221: Software – Seiten „Service-Erinnerung“ und „Marktplatz-Artikel“ öffnen und prüfen.
// Geprüft über die Oberfläche: die Software hält ihre Daten nicht global, daher kein Zugriff auf S/save.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
  const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE'});
  await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:setupLater',String(Date.now())); }catch(e){} });
  const q=await c.newPage(); q.on('pageerror',e=>errs.push('software: '+e.message)); await q.goto(BASE+'/index.html'); await q.waitForTimeout(2400);
  const nav=async id=>{ await q.evaluate(id=>{ const n=[...document.querySelectorAll(`[data-nav="${id}"]`)].pop(); if(n) n.click(); },id); await q.waitForTimeout(700); };
  const txt=async()=>await q.evaluate(()=>document.body.innerText.replace(/\s+/g,' '));
  await nav('werkstatt'); await nav('erinnerung');
  let t=await txt(); log('1 Service-Erinnerung:',t.slice(0,160));
  if(!/Service-Erinnerung/.test(t)) bad('Seite Service-Erinnerung fehlt');
  if(!/Rundmail per WhatsApp|Service-Intervall|kein Rad mit Fahrradpass/.test(t)) bad('Inhalt der Seite fehlt');
  if(!/Einwilligung|Fahrradpass/.test(t)) bad('Erklärung fehlt');
  await nav('marktartikel');
  t=await txt(); log('2 Marktplatz-Artikel:',t.slice(0,120));
  if(!/Marktplatz-Artikel/.test(t)) bad('Seite Marktplatz-Artikel fehlt');
  const add=await q.locator('[data-act="artNew"]').count(); log('3 Knopf Artikel anlegen:',add); if(!add) bad('Knopf „Artikel anlegen“ fehlt');
  else { await q.click('[data-act="artNew"]'); await q.waitForTimeout(700); t=await txt();
    if(!/Kategorie/.test(t)||!/Laufräder/.test(t)) bad('Kategorien im Formular fehlen');
    if(!/Anbieter im Marktplatz/.test(t)) bad('Anbieter-Feld im Formular fehlt'); }
  const ov=await q.evaluate(()=>document.documentElement.scrollWidth>innerWidth+1); if(ov) bad('Querscroll');
  // Rundgang durch die Software: jede Seite muss ohne JS-Fehler aufgehen und Inhalt zeigen
  for(const id of ['dashboard','werkstatt','kunden','fitting','geometrie','preise','lager','rechnungen','termine','portal','berichte','koerper','vermessung','fahrwerk','motion','verlauf','followup','qualitaet','produktdb','wissen','messmittel','netz','boerse','academy','betrieb','auftritte','erinnerung','marktartikel','mehr']){
    const before=errs.length;
    await nav(id);
    const p=await q.evaluate(()=>{ const t=(document.body.innerText||'').replace(/\s+/g,' ').trim(); return {len:t.length,txt:t.slice(0,60)}; });
    if(errs.length>before) bad('JS-Fehler auf '+id);
    if(p.len<40) bad('Seite '+id+' bleibt leer');
  }
  log('4 Rundgang fertig, Seiten geprüft: 29');
  log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
