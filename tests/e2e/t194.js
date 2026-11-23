// v.194: „Laufräder säubern“ – Hintergrund-Pinsel entfernt Himmel zwischen den Speichen, Speichen bleiben; Rückgängig; Original gesichert.
const {chromium,devices}=require('playwright'); const BASE='http://localhost:8765';
(async()=>{ const b=await chromium.launch(); const errs=[]; const log=(...a)=>console.log(...a); const bad=m=>{ errs.push(m); log('  FEHLT: '+m); };
 const cfg=Buffer.from(JSON.stringify({u:BASE,k:'sb_publishable_TESTKEY_1234567890abc'})).toString('base64url');
 const c=await b.newContext({...devices['iPhone 13'],locale:'de-DE'}); await c.addInitScript(()=>{ try{ localStorage.setItem('fyfpass:intro','1'); localStorage.setItem('fyfpass:setupLater',String(Date.now())); }catch(e){} });
 const q=await c.newPage(); q.on('pageerror',e=>errs.push(e.message)); await q.goto(BASE+'/rad.html#meine&cfg='+cfg); await q.waitForTimeout(700);
 await q.click('#regb'); await q.fill('#rb','Canyon'); await q.fill('#rm','Grail'); await q.fill('#rf','S'+Math.floor(Math.random()*1e6)); await q.check('#rx'); await q.click('#rg button.btn:not(#rfscan)'); await q.waitForTimeout(1300);
 const code=await q.evaluate(()=>mine()[0].code);
 // freigestelltes Rad mit "Himmel" in den Laufrädern (wie beim iPhone)
 await q.evaluate(c=>{ const cv=document.createElement('canvas'); cv.width=1200; cv.height=900; const g=cv.getContext('2d');
   const wheel=(x,y)=>{ g.fillStyle='#a9c4e0'; g.beginPath(); g.arc(x,y,200,0,7); g.fill(); g.strokeStyle='#222'; g.lineWidth=4; for(let i=0;i<16;i++){ const a=i/16*6.283; g.beginPath(); g.moveTo(x,y); g.lineTo(x+200*Math.cos(a),y+200*Math.sin(a)); g.stroke(); } g.strokeStyle='#1a1a1a'; g.lineWidth=30; g.beginPath(); g.arc(x,y,210,0,7); g.stroke(); };
   wheel(330,560); wheel(870,560); g.fillStyle='rgba(0,0,0,.15)'; g.fillRect(0,0,2,2); g.fillRect(1198,898,2,2); g.strokeStyle='#8a96a3'; g.lineWidth=34; g.beginPath(); g.moveTo(330,560); g.lineTo(560,560); g.lineTo(480,300); g.lineTo(330,560); g.moveTo(480,300); g.lineTo(780,310); g.lineTo(560,560); g.moveTo(780,310); g.lineTo(870,560); g.stroke();
   localStorage.setItem('fyfpass:imgt:'+c,cv.toDataURL('image/png')); localStorage.setItem('fyfpass:img:'+c,cv.toDataURL('image/jpeg')); location.hash='#c='+c; },code);
 await q.waitForTimeout(1600);
 const btn=await q.evaluate(()=>!!document.querySelector('.hero .st-wheel')); log('Knopf im Foto:',btn); if(!btn) bad('Knopf Laufräder säubern');
 await q.click('.hero .st-wheel'); await q.waitForTimeout(600); if(!await q.evaluate(()=>!!document.querySelector('.sheet.wcl'))) bad('Werkzeug öffnet');
 // Wisch über das linke Laufrad (Bildkoordinaten -> Bildschirm)
 const box=await q.evaluate(()=>{ const r=document.querySelector('.wcc').getBoundingClientRect(); return {x:r.left,y:r.top,w:r.width,h:r.height}; });
 const P=(ix,iy)=>[box.x+ix/1200*box.w, box.y+iy/900*box.h]; // Bild füllt die Leinwand (gleiches Format)
 const pathPts=[[230,500],[260,620],[300,520],[350,640],[390,500],[420,600],[300,470],[250,560]];
 let p=P(...pathPts[0]); await q.mouse.move(p[0],p[1]); await q.mouse.down(); for(const pt of pathPts.slice(1)){ p=P(...pt); await q.mouse.move(p[0],p[1],{steps:8}); } await q.mouse.up(); await q.waitForTimeout(200);
 await q.screenshot({path:'/tmp/claude-0/ov/wheel_tool.png'});
 await q.click('.sheet.wcl [data-a="ok"]'); await q.waitForTimeout(800);
 const r=await q.evaluate(async c=>{ const im=new Image(); im.src=localStorage.getItem('fyfpass:imgt:'+c); await im.decode(); const cv=document.createElement('canvas'); cv.width=im.width; cv.height=im.height; const g=cv.getContext('2d'); g.drawImage(im,0,0);
   const a=(x,y)=>g.getImageData(x,y,1,1).data[3]; let sky=0, n=0; for(let k=0;k<60;k++){ const ang=k/60*6.283+0.2, rr=60+k%5*20, x=Math.round(330+rr*Math.cos(ang)), y=Math.round(560+rr*Math.sin(ang)); const d=g.getImageData(x,y,1,1).data; if(d[0]>120&&d[2]>180){ n++; } else if(d[3]===0) sky++; }
   const spoke=a(330+100,560); const tyre=a(330+210,560); const frame=a(480,300); const right=a(870+100,560+30);
   return {removed:sky,leftover:n,spoke,tyre,frame,right,backup:!!(await IDB.get('imgt0:'+c))}; },code);
 log(JSON.stringify(r)); if(r.removed<35) bad('Himmel im Laufrad entfernt'); if(r.spoke<200) bad('Speiche bleibt'); if(r.tyre<200) bad('Reifen bleibt'); if(r.frame<200) bad('Rahmen bleibt'); if(r.right<200) bad('anderes Laufrad unberührt'); if(!r.backup) bad('Original gesichert');
 log('Fehler:',errs.length?errs:'keine'); await b.close(); process.exit(errs.length?1:0); })();
