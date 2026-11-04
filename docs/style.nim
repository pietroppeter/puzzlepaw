## Page CSS: a "maiolica" theme. Cream glazed paper, cobalt ink and six tile glazes,
## one per letter. Inlined in place of nimib's default theme (only Google Fonts is external).
const pageStyle* = """
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Playfair+Display:ital,wght@0,700;0,900;1,700&family=Karla:wght@400;600;700&family=JetBrains+Mono:wght@400;600&display=swap" rel="stylesheet">
<style>
:root{
  --paper:#f6eedc; --card:#fffaf0; --ink:#1b2a41; --muted:#6c6450; --line:#e2d5b8;
  --cobalt:#2f5d9e; --terra:#c8553d; --limone:#e9b52f; --oliva:#6f8a2e; --acqua:#2f9c95; --melanzana:#7d3c6b;
  --rosa:#d6246e;
  --band:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='28' height='28' viewBox='0 0 28 28'%3E%3Crect width='28' height='28' fill='%23fffaf0'/%3E%3Cpath d='M14 2 C18 8 20 10 26 14 C20 18 18 20 14 26 C10 20 8 18 2 14 C8 10 10 8 14 2Z' fill='%232f5d9e'/%3E%3Ccircle cx='14' cy='14' r='3.2' fill='%23e9b52f'/%3E%3Ccircle cx='0' cy='0' r='4' fill='%23c8553d'/%3E%3Ccircle cx='28' cy='0' r='4' fill='%23c8553d'/%3E%3Ccircle cx='0' cy='28' r='4' fill='%23c8553d'/%3E%3Ccircle cx='28' cy='28' r='4' fill='%23c8553d'/%3E%3C/svg%3E");
}
*{box-sizing:border-box}
[hidden]{display:none!important}
:root{padding:env(safe-area-inset-top,0) env(safe-area-inset-right,0) env(safe-area-inset-bottom,0) env(safe-area-inset-left,0)}
html{background:var(--paper)}
body{margin:0 auto;max-width:760px;padding:0 16px 60px;color:var(--ink);
  font:17px/1.6 Karla,system-ui,sans-serif;background:var(--paper)}
body::before{content:"";display:block;height:28px;margin:0 -16px;background:var(--band) repeat-x;border-bottom:3px solid var(--ink)}
header,footer .nb-box{display:flex;justify-content:space-between;align-items:center;gap:10px;flex-wrap:wrap;font-size:13px;color:var(--muted);padding:12px 0}
header{border-bottom:1px solid var(--line);font-family:"JetBrains Mono",monospace}
footer .nb-box{border-top:1px solid var(--line);margin-top:40px}
header a, footer a{color:var(--muted)}
h1,h2,h3{font-family:"Playfair Display",Georgia,serif;line-height:1.08;letter-spacing:-.01em}
h1{font-size:clamp(44px,10vw,76px);font-weight:900;margin:26px 0 4px}
h1 .tile{display:inline-block;width:.92em;height:.92em;line-height:.92em;text-align:center;border-radius:.16em;color:#fff;
  border:3px solid var(--ink);font-size:.82em;margin-right:.04em;vertical-align:.04em;box-shadow:inset 0 .2em 0 rgba(255,255,255,.18)}
h2{font-size:30px;font-weight:700;margin:52px 0 10px;padding-top:18px;border-top:2px solid var(--ink)}
h2 .num{font-family:"JetBrains Mono",monospace;font-size:13px;color:var(--terra);display:block;margin-bottom:6px;letter-spacing:.1em}
a{color:var(--cobalt);text-decoration-thickness:1px;text-underline-offset:3px}
p code, li code{font:14.5px "JetBrains Mono",monospace;background:#efe3c6;padding:1px 5px;border-radius:4px}
.lede{font-size:20px;color:#36405a;font-family:"Playfair Display",Georgia,serif;font-style:italic;margin-top:4px}
pre{margin:14px 0;overflow-x:auto;border-radius:10px}
pre code{display:block;padding:14px 16px;font:13.2px/1.55 "JetBrains Mono",monospace;background:var(--card);border:1px solid var(--line);border-radius:10px;color:#24283a}
pre.nb-output, pre samp{display:block;padding:12px 16px;font:13px/1.5 "JetBrains Mono",monospace;background:var(--ink);color:#f3ead4;border-radius:10px;white-space:pre;overflow-x:auto}
details{margin:14px 0;border:1px dashed #c9b98f;border-radius:10px;padding:4px 12px;background:var(--card)}
details summary{cursor:pointer;font-family:"JetBrains Mono",monospace;font-size:13px;color:var(--muted);padding:6px 0}
/* game */
.game{margin:18px 0 8px}
.picker{display:flex;flex-wrap:wrap;gap:8px;margin:0 0 12px}
.btn{font:700 13px "JetBrains Mono",monospace;border:2px solid var(--ink);background:var(--card);color:var(--ink);
  border-radius:999px;padding:6px 14px;cursor:pointer;box-shadow:2px 2px 0 var(--ink)}
.btn.on{background:var(--ink);color:var(--card)}
.btn:active{transform:translate(2px,2px);box-shadow:none}
.clues{display:flex;flex-wrap:wrap;gap:10px 14px;justify-content:center;margin:6px 0 12px;min-height:46px}
.clue{display:flex;align-items:center;gap:6px;padding:6px 10px 6px 6px;border-radius:12px;background:var(--card);
  border:2px solid var(--ink);box-shadow:3px 3px 0 var(--ink);cursor:default;transition:transform .2s}
.clue:hover,.clue.focus{transform:translateY(-2px)}
.clue .n{width:26px;height:26px;border-radius:50%;color:#fff;font:700 14px "JetBrains Mono",monospace;display:grid;place-items:center}
.clue .l{width:26px;height:30px;border-radius:6px;display:grid;place-items:center;font:700 19px "Playfair Display",serif;
  border:1.5px dashed #b9aa82;color:#b9aa82;transition:background .25s,color .25s}
.clue .l.on{border:1.5px solid var(--ink);color:#fff}
.clue.done{background:#fff3c9}
.clue .ok{font-size:18px;width:18px;text-align:center;color:var(--oliva);font-weight:700}
.stage{position:relative;background:var(--card);border:3px solid var(--ink);border-radius:18px;box-shadow:6px 6px 0 var(--ink);padding:6px;overflow:hidden}
.stage svg.d2{display:block;overflow:visible;width:100%;height:auto;touch-action:none;user-select:none;-webkit-user-select:none}
.stage svg text{font-family:Karla,sans-serif}
.stage svg .glyph{font-family:"Playfair Display",Georgia,serif;font-weight:900}
.stage svg .mono{font-family:"JetBrains Mono",monospace}
.item{transition:transform .34s cubic-bezier(.2,.9,.25,1)}
.item.grab{cursor:grab}
.item.lifted{transition:none;cursor:grabbing;filter:drop-shadow(0 10px 8px rgba(27,42,65,.35))}
.item.lifted > *{transform:scale(1.12)}
.ghosts,.overlay{pointer-events:none}
.ghosts .target{fill:none;stroke:var(--ink);stroke-width:3;stroke-dasharray:6 5;opacity:.55}
.ghosts .land{fill:var(--rosa);opacity:.5}
.ghosts .tether{stroke:var(--rosa);stroke-width:2;stroke-dasharray:4 4}
.ghost-toggle{position:absolute;right:12px;bottom:6px;font:12px "JetBrains Mono",monospace;color:var(--muted);cursor:pointer;user-select:none}
.ghost-toggle input{accent-color:var(--rosa);vertical-align:-2px}
.status{display:flex;flex-wrap:wrap;gap:8px;align-items:center;justify-content:space-between;margin:14px 0}
.status .meta{font:600 13px "JetBrains Mono",monospace;color:var(--muted)}
.status .meta b{color:var(--ink)}
.status .acts{display:flex;gap:8px;flex-wrap:wrap}
.banner{position:absolute;left:50%;top:38%;transform:translate(-50%,-50%) scale(.6);opacity:0;pointer-events:none;
  background:var(--ink);color:#fff;border-radius:16px;padding:14px 26px;text-align:center;border:3px solid var(--limone);
  box-shadow:6px 6px 0 var(--terra);transition:all .45s cubic-bezier(.2,1.4,.4,1);white-space:nowrap}
.banner b{display:block;font:900 42px "Playfair Display",serif}
.banner span{font:600 13px "JetBrains Mono",monospace;color:#f3ead4}
.stage.won .banner{opacity:1;transform:translate(-50%,-50%) scale(1)}
.confetti{position:absolute;inset:0;pointer-events:none;overflow:hidden}
.confetti i{position:absolute;left:var(--x);top:-30px;width:18px;height:18px;border-radius:4px;border:1.5px solid var(--ink);
  font:900 11px/15px "Playfair Display",serif;color:#fff;text-align:center;font-style:normal;
  animation:fall var(--t) cubic-bezier(.3,.6,.6,1) var(--d) forwards}
@keyframes fall{to{transform:translate(var(--dx),720px) rotate(var(--r))}}
.rules{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin:16px 0}
@media (max-width:640px){.rules{grid-template-columns:1fr}}
.rules div{background:var(--card);border:2px solid var(--ink);border-radius:12px;padding:10px 12px;font-size:15px;line-height:1.45}
.rules b{font:700 12px "JetBrains Mono",monospace;color:var(--terra);display:block;letter-spacing:.08em;margin-bottom:2px}
.spoiler svg{width:100%;max-width:360px;display:block;margin:8px auto}
p code, li code{overflow-wrap:anywhere}
@media (max-width:560px){
  header span:nth-child(2){display:none}
  .lede{font-size:17px}
  .clues{gap:8px}
  .clue{gap:3px;padding:4px 6px 4px 4px;box-shadow:2px 2px 0 var(--ink)}
  .clue .n{width:21px;height:21px;font-size:12px}
  .clue .l{width:19px;height:24px;font-size:15px;border-radius:5px}
  .stage{box-shadow:4px 4px 0 var(--ink);border-radius:14px;padding:2px}
  .banner b{font-size:32px}
}
#source{display:none}
footer button{font:600 12px "JetBrains Mono",monospace;border:1.5px solid var(--ink);background:var(--card);border-radius:999px;padding:4px 12px;cursor:pointer}
footer hr{display:none}
</style>
"""

## Extra rules for the solver explainer's browser lab.
const extraStyle* = """
<style>
.lab{background:var(--card);border:3px solid var(--ink);border-radius:18px;box-shadow:6px 6px 0 var(--ink);padding:14px;margin:18px 0}
.lab .row{display:flex;gap:8px;margin:10px 0;flex-wrap:wrap;align-items:center}
.lab input#code{flex:1;min-width:0;font:13px "JetBrains Mono",monospace;padding:8px 10px;border:2px solid var(--ink);border-radius:10px;background:#fff;color:var(--ink)}
.lab .opts{font:13px "JetBrains Mono",monospace;color:var(--muted);gap:16px}
.lab .opts input{accent-color:var(--cobalt);vertical-align:-2px}
.verdict{font:600 14px "JetBrains Mono",monospace;color:var(--muted);margin:8px 0 12px}
.verdict b{font:900 26px "Playfair Display",serif;margin-right:6px;vertical-align:-3px}
.verdict .one{color:var(--oliva)} .verdict .many{color:var(--cobalt)} .verdict .bad{color:var(--terra)}
.cgrid{display:grid;grid-template-columns:repeat(6,1fr);border:3px solid var(--ink);border-radius:8px;overflow:hidden;max-width:420px;margin:0 auto;background:#fff}
.cell{position:relative;aspect-ratio:1;border-right:1px solid var(--line);border-bottom:1px solid var(--line);display:grid;place-items:center}
.cell:nth-child(6n){border-right:none}
.cell.bx{border-right:3px solid var(--ink)}
.cell.by{border-bottom:3px solid var(--ink)}
.cell:nth-last-child(-n+6){border-bottom:none}
.cell i, .words i{position:absolute;left:3px;top:3px;width:16px;height:16px;border-radius:50%;color:#fff;font:700 10px/16px "JetBrains Mono",monospace;text-align:center;font-style:normal}
.cell i + i{left:21px}
.cell .given{font:900 clamp(20px,6vw,30px) "Playfair Display",serif;color:var(--ink);cursor:pointer;text-decoration:underline 2px var(--terra);text-underline-offset:4px}
.cell .forced{font:700 clamp(20px,6vw,30px) "Playfair Display",serif;color:var(--oliva)}
.cell .marks{display:grid;grid-template-columns:repeat(3,1fr);gap:0 2px;width:84%;margin-top:8px}
.cell .marks a{font:600 clamp(10px,2.8vw,13px)/1.5 "JetBrains Mono",monospace;color:var(--cobalt);text-align:center;cursor:pointer;border-radius:4px}
.cell .marks a:hover{background:#efe3c6}
.words{display:flex;flex-wrap:wrap;gap:8px 16px;justify-content:center;margin:12px 0 2px;font:700 15px "JetBrains Mono",monospace}
.words span{position:relative;padding-left:22px}
.words i{top:2px;left:0}
</style>
"""
