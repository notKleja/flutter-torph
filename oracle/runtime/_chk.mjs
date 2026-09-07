import http from "node:http"; import fs from "node:fs"; import path from "node:path";
import puppeteer from "puppeteer-core";
const HERE="/Users/kleja/flutter-torph/oracle/runtime";
const DIST="/Users/kleja/flutter-torph/upstream/torph/packages/torph/dist";
const MIME={".html":"text/html",".js":"text/javascript",".mjs":"text/javascript"};
const server=http.createServer((req,res)=>{let rel=req.url.split("?")[0]; if(rel==="/")rel="/index.html";
 const f=rel.startsWith("/dist/")?path.join(DIST,rel.slice(6)):path.join(HERE,rel);
 if(!fs.existsSync(f)){res.writeHead(404).end();return;} res.writeHead(200,{"Content-Type":MIME[path.extname(f)]||"text/plain"}); fs.createReadStream(f).pipe(res);});
await new Promise(r=>server.listen(0,"127.0.0.1",r)); const port=server.address().port;
const b=await puppeteer.launch({executablePath:"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",headless:true});
const p=await b.newPage(); await p.setViewport({width:1200,height:700});
await p.goto(`http://127.0.0.1:${port}/`); await p.waitForFunction(()=>window.__ready&&window.Torph);
const out=await p.evaluate(async()=>{
  const res=[];
  for(const align of ["left","center","right"]){
    await window.__H.mount({page:{fontFamily:"Menlo",fontSize:20,textAlign:align},options:{}});
    await window.__H.applyUpdate("hello");
    const root=window.__H.root;
    const rootTA=getComputedStyle(root).textAlign;
    const holderTA=getComputedStyle(root.parentElement).textAlign;
    const natural=[...root.children].filter(c=>!c.hasAttribute("torph-sr")).map(c=>[c.getAttribute("torph-id"),Math.round((c.getBoundingClientRect().left-root.getBoundingClientRect().left)*100)/100]);
    // now pin narrow and re-read
    root.style.width="30px"; void root.offsetWidth;
    const pinned=[...root.children].filter(c=>!c.hasAttribute("torph-sr")).map(c=>[c.getAttribute("torph-id"),Math.round((c.getBoundingClientRect().left-root.getBoundingClientRect().left)*100)/100]);
    // and pin wide
    root.style.width="300px"; void root.offsetWidth;
    const wide=[...root.children].filter(c=>!c.hasAttribute("torph-sr")).map(c=>[c.getAttribute("torph-id"),Math.round((c.getBoundingClientRect().left-root.getBoundingClientRect().left)*100)/100]);
    root.style.width="";
    res.push({align,rootTA,holderTA,natural,pinned30:pinned,pinned300:wide});
  }
  return res;
});
console.log(JSON.stringify(out,null,1));
await b.close(); server.close();
