#!/usr/bin/env node
// Drive the running app through a scripted user journey and take screenshots.
//
//   node scripts/cdp-drive.js scripts/scenarios/smoke.json
//   BASE=http://localhost:8002 OUT=/tmp/shots node scripts/cdp-drive.js <steps.json>
//
// Each {"ctx": name} step opens (or switches to) a separate headless Chrome with
// its own profile, i.e. its own Lamdera session, so one script can play several
// users. Other steps act on the current ctx:
//   {"size":[w,h]}  {"goto":"/path","delay":ms}  {"click":"#css"}  {"type":["#css","text"]}
//   {"select":["#css","value"]}  {"eval":"js expr"}  {"wait":ms}  {"shot":"name","full":true}
// Screenshots land in $OUT (default /tmp/trailpost-shots) and their paths are printed.
// A step whose selector isn't found prints "missing <selector>" on stderr.
//
// Gotcha: under `lamdera live` the backend runs inside a browser tab (the
// "leader"). If that tab does a full reload (`goto`), clients can lose their
// connection and session. Start every script with a leader ctx that loads "/"
// once and is never used again; see scripts/scenarios/*.json.
const { spawn } = require('child_process');
const http = require('http'); const fs = require('fs');
const WebSocket = require('ws');
if (!process.argv[2]) { console.error('usage: node scripts/cdp-drive.js <steps.json>'); process.exit(1); }
const steps = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const base = process.env.BASE || 'http://localhost:8011';
const out = process.env.OUT || '/tmp/trailpost-shots';
fs.mkdirSync(out, { recursive: true });
const sleep = ms => new Promise(r => setTimeout(r, ms));
const procs = [];
const getJ = (port, p) => new Promise((res, rej) => http.get(`http://localhost:${port}${p}`, r => { let b=''; r.on('data',c=>b+=c); r.on('end',()=>res(JSON.parse(b))); }).on('error', rej));
(async () => {
  const ctxs = {}; let cur; let n = 0;
  async function useCtx(name) {
    if (!ctxs[name]) {
      const port = 9400 + (n++);
      procs.push(spawn('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
        ['--headless=new','--disable-gpu','--hide-scrollbars',`--remote-debugging-port=${port}`,'--user-data-dir=/tmp/trailpost-drive-'+process.pid+'-'+name,'about:blank'],{stdio:'ignore'}));
      let tabs; for (let i=0;i<60;i++){ try { tabs = await getJ(port,'/json'); if (tabs.find(t=>t.type==='page')) break; } catch(e){} await sleep(200); }
      const tab = tabs.find(t=>t.type==='page');
      const ws = new WebSocket(tab.webSocketDebuggerUrl); await new Promise(r=>ws.on('open',r));
      let id=0; const pending={};
      ws.on('message', m => { const d=JSON.parse(m); if (d.id && pending[d.id]) { pending[d.id](d); delete pending[d.id]; } });
      const sendFn = (method, params={}) => new Promise(r => { const i=++id; pending[i]=r; ws.send(JSON.stringify({id:i,method,params})); });
      await sendFn('Page.enable');
      ctxs[name] = { send: sendFn, ws };
    }
    cur = ctxs[name];
  }
  const send = (method, params={}) => cur.send(method, params);
  const ev = async (expr) => { const r = await send('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true }); if (r.result.exceptionDetails) throw new Error(JSON.stringify(r.result.exceptionDetails)); return r.result.result.value; };
  let width = 1280, height = 900;
  await useCtx('default');
  for (const s of steps) {
    if (s.ctx) await useCtx(s.ctx);
    if (s.size) { width = s.size[0]; height = s.size[1]; }
    if (s.goto) { await send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:width<600}); await send('Page.navigate', { url: base + s.goto }); await sleep(s.delay || 4000); }
    if (s.click) { const ok = await ev(`(()=>{const e=document.querySelector(${JSON.stringify(s.click)}); if(!e) return false; e.click(); return true})()`); if (!ok) console.error('missing', s.click); await sleep(s.delay || 600); }
    if (s.type) { const ok = await ev(`(()=>{const e=document.querySelector(${JSON.stringify(s.type[0])}); if(!e) return false; const proto = e.tagName==='TEXTAREA'?HTMLTextAreaElement.prototype:HTMLInputElement.prototype; Object.getOwnPropertyDescriptor(proto,'value').set.call(e, ${JSON.stringify(s.type[1])}); e.dispatchEvent(new Event('input',{bubbles:true})); return true})()`); if (!ok) console.error('missing', s.type[0]); await sleep(s.delay || 300); }
    if (s.select) { await ev(`(()=>{const e=document.querySelector(${JSON.stringify(s.select[0])}); e.value=${JSON.stringify(s.select[1])}; e.dispatchEvent(new Event('input',{bubbles:true}));})()`); await sleep(300); }
    if (s.eval) console.log(JSON.stringify(await ev(s.eval)));
    if (s.wait) await sleep(s.wait);
    if (s.shot) {
      await send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:width<600}); await sleep(400);
      let clip;
      if (s.full) { const h = await ev('document.documentElement.scrollHeight'); clip = {x:0,y:0,width,height:Math.min(h, 4000),scale:1}; }
      const r = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: !!s.full, ...(clip?{clip}:{}) });
      const f = `${out}/${s.shot}.png`; fs.writeFileSync(f, Buffer.from(r.result.data, 'base64')); console.log(f);
    }
  }
  Object.values(ctxs).forEach(c=>c.ws.close()); procs.forEach(p=>p.kill()); process.exit(0);
})().catch(e => { console.error(e); procs.forEach(p=>p.kill()); process.exit(1); });
