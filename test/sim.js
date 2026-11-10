const {A}=require('./run.js');
const res={hunters:0,runners:0}; const reasons={}; let n=0, errs=0; const times=[]; const st={kills:0,civ:0,calls:0,tasks:0,police:0,reports:0,arrests:0,forced:0,quota:0};
const cfgs=[{hunters:2,runners:4},{hunters:1,runners:3},{hunters:2,runners:2},{hunters:1,runners:4}];
const t0=Date.now();
for(let seed=1;seed<=(+process.env.N||48);seed++){
  const cfg=cfgs[seed%cfgs.length];
  let w;
  try{
    w=A.newWorld({role:'none',hunters:cfg.hunters,runners:cfg.runners,minutes:12,seed});
    let steps=0, sawPolice=false;
    while(!w.over && steps<20000){ A.step(w,0.05,null); steps++; if(w.ents.some(e=>e.role==='police')) sawPolice=true; }
    if(!w.over){ console.log('seed',seed,'NO END after',w.time); errs++; continue; }
    res[w.over.winner]++; reasons[w.over.reason]=(reasons[w.over.reason]||0)+1; times.push(w.time);
    st.kills+=w.stats.kills; st.civ+=w.stats.civKills; st.calls+=w.stats.calls; st.tasks+=w.stats.tasks; st.reports+=w.stats.reports; st.arrests+=w.stats.arrests; st.forced+=w.stats.forced; st.quota+=w.quota; if(sawPolice) st.police++;
  }catch(e){ errs++; console.log('seed',seed,'ERROR',e.stack.split('\n').slice(0,4).join(' | ')); }
  n++;
}
times.sort((a,b)=>a-b);
console.log('games',n,'errors',errs,'wins',res,'ms',Date.now()-t0);
console.log('reasons',reasons);
console.log('end time min/med/max (s):',Math.round(times[0]),Math.round(times[times.length>>1]),Math.round(times[times.length-1]));
console.log('totals',st);
