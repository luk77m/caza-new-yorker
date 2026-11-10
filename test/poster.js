const {A}=require('./run.js'); const {FLOORS,TS}=A;
function inp(o){ return Object.assign({mx:0,my:0,run:false,aim:false,aimX:0,aimY:0,fire:false,interactHeld:false},o||{}); }
function place(e,fl,tx,ty){ e.floor=fl; e.x=(tx+.5)*TS; e.y=(ty+.5)*TS; e.path=null; e.pathKey=null; e.goal=null; }
const w=A.newWorld({role:'runner',hunters:1,runners:3,minutes:12,seed:3});
const h=w.ents.find(e=>e.role==='hunter'); w.ents.forEach(e=>{ if(e.type==='bot') e.type='frozen'; }); w.ents.filter(e=>e.role==='civil').forEach(e=>e.alive=false);
place(h,5,20,19);
w.wanted[h.outfit.id]=true;
w.dispatch.push({t:w.time+1,floor:1,x:22,y:20,done:false});
for(let t=0;t<3;t+=0.05) A.step(w,0.05,inp());
console.log('posters tras llegar la policía:',w.posters.length, w.posters[0]&&w.posters[0].state, 'activos:',Object.keys(w.posterActive).length);
const wd=FLOORS[3].wards[0]; place(h,3,wd.stand.x,wd.stand.y); h.type='human'; w.human=h; w.ents.filter(e=>e.role==='runner').forEach(e=>e.type='frozen');
let ok1=false; A.step(w,0.05,inp({interactHeld:true}));
for(let t=0;t<3.4;t+=0.05) A.step(w,0.05,inp({interactHeld:true}));
for(let t=0;t<0.3;t+=0.05) A.step(w,0.05,inp());
console.log('tras cambiar de traje:',w.posters.length, w.posters[0]&&w.posters[0].state);
for(let t=0;t<6.5;t+=0.05) A.step(w,0.05,inp());
console.log('6 s después:',w.posters.length);
