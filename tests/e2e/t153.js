// v.153: Werkstatt-Tafel – Ziehen „Angenommen“→„In Arbeit“ nur wenn erlaubt, „In Arbeit“→„Wartet auf Teile“, zurück; verbotener Sprung bleibt.
const {chromium}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const p=await (await b.newContext({viewport:{width:1600,height:900},locale:'de-DE'})).newPage(); p.on('pageerror',e=>errs.push(e.message)); p.on('dialog',d=>d.accept('Kette'));
 await p.goto(BASE+'/index.html'); await p.waitForTimeout(1500);
 const ids=await p.evaluate(()=>{ const S=window.__fitframe.S(); const w=S.workshop; w[0].status='Angenommen'; delete w[0].wait; w[1].status='Freigabe ausstehend'; delete w[1].wait; w[2].status='In Arbeit'; delete w[2].wait; window.__fitframe.save(); const F=window.__fitframe.T118; F.ui().route='tafel'; F.render(); return [w[0].id,w[1].id,w[2].id]; }); await p.waitForTimeout(300);
 const drag=async(id,col)=>{ await p.dragAndDrop(`[data-tfid="${id}"]`,`.tf-col.tf-${col}`); await p.waitForTimeout(400); };
 const st=id=>p.evaluate(id=>{ const w=window.__fitframe.S().workshop.find(x=>x.id===id); return w.status+(w.wait?'+wait':''); },id);
 await drag(ids[0],'arbeit'); let s0=await st(ids[0]); log('1 Angenommen → In Arbeit (Kostenvoranschlag nicht überspringen):',s0); if(s0!=='Angenommen') bad('Schritt übersprungen');
 await drag(ids[1],'arbeit'); let s1=await st(ids[1]); log('2 Freigabe ausstehend → In Arbeit:',s1); if(s1!=='In Arbeit') bad('Weiterschalten per Ziehen (wie Weiter-Knopf)');
 await drag(ids[2],'teile'); let s2=await st(ids[2]); log('3 In Arbeit → Teile:',s2); if(!/wait/.test(s2)) bad('Wartet auf Teile per Ziehen');
 await drag(ids[2],'arbeit'); s2=await st(ids[2]); log('4 Teile → In Arbeit:',s2); if(/wait/.test(s2)) bad('Teile sind da per Ziehen');
 await drag(ids[2],'neu'); s2=await st(ids[2]); log('5 verbotener Rücksprung:',s2); if(s2!=='In Arbeit') bad('Rücksprung darf nicht gehen');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
