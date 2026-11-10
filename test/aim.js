const {A}=require('./run.js'); const {TS}=A; let fails=0;
function ok(c,m){ console.log((c?'OK   ':'FAIL ')+m); if(!c) fails++; }
function inp(o){ return Object.assign({mx:0,my:0,run:false,aim:false,aimX:0,aimY:0,fire:false,interactHeld:false},o||{}); }
function place(e,fl,tx,ty){ e.floor=fl; e.x=(tx+.5)*TS; e.y=(ty+.5)*TS; e.path=null; e.pathKey=null; e.goal=null; }
function trial(dist){
  const w=A.newWorld({role:'hunter',hunters:1,runners:2,minutes:12,seed:11}); const h=w.human;
  w.ents.forEach(e=>{ if(e.type==='bot') e.type='frozen'; });
  const civ=w.ents.filter(e=>e.role==='civil'&&e.floor===1);
  civ.forEach(e=>{ e.alive=false; });
  const g=civ[0]; g.alive=true; g.ai.wait=99;
  place(h,1,16,19); place(g,1,16+dist,19);
  h.sus=0; let t=0; for(;t<3;t+=0.05) A.step(w,0.05,inp({aim:true,aimX:h.x+10,aimY:h.y}));
  return h.sus;
}
const s2=trial(2), s5=trial(5), s6=trial(6.5), s9=trial(9);
console.log('sus tras 3 s apuntando -> a 2 casillas',s2.toFixed(1),'· 5:',s5.toFixed(1),'· 6.5:',s6.toFixed(1),'· 9:',s9.toFixed(1));
ok(s2>25,'a 2 casillas la sospecha sube rápido');
ok(s2>s5&&s5>s6,'cuanto más cerca, más rápido');
ok(s6>0,'a 6,5 casillas todavía se nota');
ok(s9===0,'a 9 casillas no se nota');
process.exit(fails?1:0);
