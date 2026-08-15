const page = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="LocalClaw is a secure, self-hosted OpenClaw workstation for people who want their AI close, private, and under their control.">
  <meta name="theme-color" content="#07121f">
  <title>LocalClaw - Coming soon</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;700&family=Space+Grotesk:wght@500;600;700&display=swap" rel="stylesheet">
  <style>
    :root{--ink:#eef3ff;--navy:#07101d;--paper:#f4f8f5;--teal:#7cf4d2;--amber:#f3ca63;--cyan:#28b8e6;--muted:#9fb2c2;--line:#d8e6e2}
    *{box-sizing:border-box}
    html{scroll-behavior:smooth}
    body{margin:0;min-height:100vh;overflow-x:hidden;font-family:"DM Sans",system-ui,sans-serif;color:var(--ink);background:radial-gradient(circle at 50% -15%,#14263d 0%,#0b1523 42%,#050b14 100%)}
    body:before{content:"";position:fixed;inset:0;background:radial-gradient(circle at 50% 12%,rgba(124,244,210,.12),transparent 28%),radial-gradient(circle at 72% 18%,rgba(40,184,230,.08),transparent 24%),radial-gradient(circle at 18% 78%,rgba(243,202,99,.08),transparent 22%);pointer-events:none}
    .dot-field{position:fixed;inset:0;overflow:hidden;pointer-events:none;isolation:isolate}
    .dot{position:absolute;left:0;top:0;width:var(--size);height:var(--size);border-radius:50%;opacity:0;mix-blend-mode:screen;background:radial-gradient(circle at 30% 30%,rgba(255,255,255,.98) 0%,hsla(var(--hue),95%,68%,.92) 34%,hsla(var(--hue),95%,54%,.18) 68%,transparent 72%);box-shadow:0 0 0 1px hsla(var(--hue),95%,70%,.12),0 0 24px hsla(var(--hue),95%,62%,.34);animation:drift var(--duration) ease-in-out infinite;animation-delay:var(--delay);will-change:transform,opacity}
    @keyframes drift{0%{transform:translate3d(var(--x1),var(--y1),0) scale(.65);opacity:0}10%{opacity:.95}42%{transform:translate3d(var(--x2),var(--y2),0) scale(1)}78%{opacity:.9}100%{transform:translate3d(var(--x3),var(--y3),0) scale(.78);opacity:0}}
    .shell{position:relative;z-index:1;min-height:100vh;display:grid;place-items:center;padding:32px}
    .card{width:min(1100px,100%);display:grid;grid-template-columns:1.08fr .92fr;gap:34px;align-items:center}
    .eyebrow{display:inline-flex;align-items:center;gap:10px;text-transform:uppercase;letter-spacing:.18em;font-size:11px;font-weight:700;color:#179fb7}
    .pulse{width:8px;height:8px;border-radius:50%;background:#45d8b4;box-shadow:0 0 0 6px rgba(69,216,180,.18)}
    h1{font-family:"Space Grotesk",system-ui,sans-serif;font-size:clamp(54px,7vw,92px);line-height:.96;letter-spacing:-.07em;margin:18px 0 18px}
    h1 em{font-style:normal;color:#159fb7}
    .lede{max-width:42rem;font-size:18px;line-height:1.65;color:#536a75;margin:0}
    .actions{display:flex;gap:16px;flex-wrap:wrap;margin:30px 0 26px}
    .button,.link{display:inline-flex;align-items:center;gap:12px;border-radius:999px;text-decoration:none;font-weight:700}
    .button{padding:14px 20px;background:var(--amber);color:var(--ink);box-shadow:0 10px 24px rgba(243,202,99,.28)}
    .link{padding:14px 0;color:var(--ink)}
    .link span{color:#159fb7}
    .chips{display:flex;flex-wrap:wrap;gap:10px}
    .chip{display:inline-flex;align-items:center;gap:9px;padding:10px 14px;border:1px solid rgba(17,29,42,.09);background:rgba(255,255,255,.72);border-radius:999px;color:#2e4756;font-size:13px;backdrop-filter:blur(12px)}
    .stack-strip{margin-top:22px;padding-top:18px;border-top:1px solid rgba(255,255,255,.08);display:flex;flex-wrap:wrap;gap:10px;align-items:center}
    .stack-strip .label{font-size:12px;text-transform:uppercase;letter-spacing:.16em;color:#90a6b7;margin-right:8px}
    .brand-pill{display:inline-flex;align-items:center;gap:10px;padding:10px 14px;border-radius:999px;border:1px solid rgba(124,244,210,.14);background:rgba(10,18,30,.72);color:#e7eef5;font-size:13px;backdrop-filter:blur(12px)}
    .service-icon{width:18px;height:18px;display:inline-flex;align-items:center;justify-content:center;flex:none}
    .service-icon svg{display:block;width:18px;height:18px}
    .icon-openclaw{color:#72f1d0}
    .icon-vault{color:#f3ca63}
    .icon-cloudflare{color:#ff8d4d}
    .icon-github{color:#dce5ee}
    .icon-age{color:#7be4bc}
    .terminal{position:relative;background:linear-gradient(180deg,#0d1f31,#0b1724);border-radius:18px;padding:16px;box-shadow:0 25px 60px rgba(8,18,30,.18);transform:rotate(1.8deg)}
    .terminal:before{content:"";position:absolute;inset:-1px;border-radius:18px;padding:1px;background:linear-gradient(145deg,rgba(124,244,210,.6),rgba(243,202,99,.22),rgba(40,184,230,.28));-webkit-mask:linear-gradient(#fff 0 0) content-box,linear-gradient(#fff 0 0);-webkit-mask-composite:xor;mask-composite:exclude;pointer-events:none}
    .chrome{display:flex;align-items:center;gap:8px;padding:2px 2px 14px;color:#8ea1ab}
    .lamp{width:9px;height:9px;border-radius:50%}
    .red{background:#ff756d}.yellow{background:#f3ca63}.green{background:#6edcb0}
    .title{margin-left:8px;font-size:12px;letter-spacing:.08em;text-transform:uppercase;opacity:.8}
    .body{background:linear-gradient(180deg,rgba(255,255,255,.02),rgba(255,255,255,0));border:1px solid rgba(124,244,210,.12);border-radius:14px;padding:24px}
    .line{font-family:"Space Grotesk",system-ui,sans-serif;font-size:14px;line-height:1.9;color:#d5e5e2}
    .line.muted{color:#6d8795}
    .line.good{color:#93e5c4}
    .line.good span{color:#45d8b4;margin-right:8px}
    .footer-note{margin-top:18px;font-size:12px;color:#8ca0a8;letter-spacing:.03em}
    @media (max-width: 900px){.card{grid-template-columns:1fr}.terminal{transform:none}.shell{padding:20px}}
    @media (max-width: 540px){body{overflow:auto}.body{padding:18px}.lede{font-size:17px}.chip{font-size:12px}}
  </style>
</head>
<body>
  <div class="dot-field" aria-hidden="true">
    <span class="dot" style="--x1:-4vw;--y1:18vh;--x2:22vw;--y2:32vh;--x3:18vw;--y3:92vh;--size:6px;--duration:18s;--delay:-2s;--hue:180"></span>
    <span class="dot" style="--x1:112vw;--y1:72vh;--x2:74vw;--y2:42vh;--x3:50vw;--y3:10vh;--size:4px;--duration:22s;--delay:-8s;--hue:35"></span>
    <span class="dot" style="--x1:18vw;--y1:-6vh;--x2:36vw;--y2:18vh;--x3:58vw;--y3:48vh;--size:5px;--duration:20s;--delay:-5s;--hue:188"></span>
    <span class="dot" style="--x1:30vw;--y1:108vh;--x2:44vw;--y2:58vh;--x3:70vw;--y3:74vh;--size:7px;--duration:24s;--delay:-13s;--hue:160"></span>
    <span class="dot" style="--x1:44vw;--y1:4vh;--x2:60vw;--y2:24vh;--x3:84vw;--y3:14vh;--size:4px;--duration:19s;--delay:-7s;--hue:42"></span>
    <span class="dot" style="--x1:55vw;--y1:104vh;--x2:72vw;--y2:56vh;--x3:90vw;--y3:86vh;--size:6px;--duration:21s;--delay:-11s;--hue:178"></span>
    <span class="dot" style="--x1:66vw;--y1:-8vh;--x2:80vw;--y2:34vh;--x3:97vw;--y3:20vh;--size:5px;--duration:23s;--delay:-4s;--hue:31"></span>
    <span class="dot" style="--x1:78vw;--y1:98vh;--x2:88vw;--y2:34vh;--x3:62vw;--y3:58vh;--size:4px;--duration:17s;--delay:-9s;--hue:170"></span>
    <span class="dot" style="--x1:2vw;--y1:58vh;--x2:18vw;--y2:38vh;--x3:36vw;--y3:18vh;--size:3px;--duration:14s;--delay:-3s;--hue:190"></span>
    <span class="dot" style="--x1:22vw;--y1:14vh;--x2:38vw;--y2:30vh;--x3:50vw;--y3:6vh;--size:3px;--duration:16s;--delay:-10s;--hue:46"></span>
    <span class="dot" style="--x1:60vw;--y1:52vh;--x2:68vw;--y2:16vh;--x3:82vw;--y3:40vh;--size:3px;--duration:15s;--delay:-6s;--hue:174"></span>
    <span class="dot" style="--x1:86vw;--y1:22vh;--x2:70vw;--y2:76vh;--x3:92vw;--y3:96vh;--size:5px;--duration:26s;--delay:-14s;--hue:38"></span>
    <span class="dot" style="--x1:12vw;--y1:96vh;--x2:24vw;--y2:60vh;--x3:8vw;--y3:24vh;--size:4px;--duration:25s;--delay:-12s;--hue:202"></span>
    <span class="dot" style="--x1:92vw;--y1:8vh;--x2:78vw;--y2:22vh;--x3:56vw;--y3:4vh;--size:4px;--duration:28s;--delay:-18s;--hue:22"></span>
  </div>
  <main class="shell">
    <section class="card">
      <div>
        <div class="eyebrow"><span class="pulse"></span> Coming soon · local first</div>
        <h1>Coming soon.<br><em>Your AI.</em><br>Your machine.</h1>
        <p class="lede">LocalClaw is a secure, self-hosted OpenClaw workstation for people who want their agent, secrets, and working context to stay close, inspectable, and under their control.</p>
        <div class="actions">
          <a class="button" href="https://github.com/cjwelle/localclaw">Read the source <span aria-hidden="true">↗</span></a>
          <a class="link" href="https://github.com/cjwelle/localclaw"><span>Watch on GitHub</span></a>
        </div>
        <div class="chips">
          <span class="chip">Loopback-first</span>
          <span class="chip">Foreground-only</span>
          <span class="chip">Secrets stay local</span>
        </div>
        <div class="stack-strip" aria-label="Built on services">
          <span class="label">Built on</span>
          <span class="brand-pill"><span class="service-icon icon-openclaw" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none"><path d="M12 2.5c4.1 0 7.5 3.4 7.5 7.5S16.1 17.5 12 17.5 4.5 14.1 4.5 10 7.9 2.5 12 2.5Z" stroke="currentColor" stroke-width="1.6"/><path d="M8.4 13.9c1.2-1.3 2.4-2 3.6-2s2.4.7 3.6 2" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/><path d="M11.3 7.9h1.4" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg></span> OpenClaw</span>
          <span class="brand-pill"><span class="service-icon icon-vault" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none"><path d="M12 2.8 19.2 6v6.2c0 4.7-3.1 7.8-7.2 9.1-4.1-1.3-7.2-4.4-7.2-9.1V6L12 2.8Z" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/><path d="M12 8.2v7.6" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/><circle cx="12" cy="10.4" r="1.3" fill="currentColor"/></svg></span> Vault</span>
          <span class="brand-pill"><span class="service-icon icon-cloudflare" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none"><path d="M8.2 16.7h11.1a3.2 3.2 0 0 0 0-6.4 4.7 4.7 0 0 0-9.2-.9 3.8 3.8 0 0 0-1.9 7.3Z" fill="currentColor"/><path d="M7 16.7h13" stroke="currentColor" stroke-width="1.1" stroke-linecap="round"/></svg></span> Cloudflare</span>
          <span class="brand-pill"><span class="service-icon icon-github" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none"><path d="M12 2.8a9.2 9.2 0 0 0-2.9 17.9c.5.1.7-.2.7-.5v-1.8c-2.8.6-3.3-1.2-3.3-1.2-.4-1-.9-1.2-.9-1.2-.8-.6.1-.6.1-.6.9.1 1.3.9 1.3.9.8 1.3 2 .9 2.5.7.1-.6.3-.9.5-1.1-2.2-.2-4.6-1.1-4.6-4.8 0-1.1.4-2 .9-2.7-.1-.2-.4-1.1.1-2.3 0 0 .8-.3 2.8 1a9.9 9.9 0 0 1 5.1 0c2-1.3 2.8-1 2.8-1 .5 1.2.2 2.1.1 2.3.6.7.9 1.6.9 2.7 0 3.7-2.4 4.5-4.6 4.8.3.3.5.8.5 1.6v2.4c0 .3.2.6.7.5A9.2 9.2 0 0 0 12 2.8Z" fill="currentColor"/></svg></span> GitHub</span>
          <span class="brand-pill"><span class="service-icon icon-age" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none"><path d="M7.5 18.2 15.9 5.8" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/><path d="M8.8 7.3h5.2L12.1 12h2.7" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/><path d="M14.9 18.2h2.6" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg></span> age</span>
        </div>
      </div>
      <div class="terminal" aria-label="LocalClaw preview">
        <div class="chrome">
          <span class="lamp red"></span>
          <span class="lamp yellow"></span>
          <span class="lamp green"></span>
          <span class="title">localclaw / coming-soon</span>
        </div>
        <div class="body">
          <div class="line muted">$ localclaw setup</div>
          <div class="line good"><span>✓</span> Vault sealed until needed</div>
          <div class="line good"><span>✓</span> Secrets stay on this machine</div>
          <div class="line good"><span>✓</span> Gateway bound to loopback</div>
          <div class="line muted" style="margin-top:12px">More to come: the install flow, the safety model, and the day-to-day operator experience.</div>
          <div class="footer-note">Private by design · self-hosted by choice · built to be inspected</div>
        </div>
      </div>
    </section>
  </main>
</body>
</html>`;

export default {
  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname !== '/' && url.pathname !== '/index.html') {
      return new Response('Not found', {
        status: 404,
        headers: { 'content-type': 'text/plain; charset=utf-8' },
      });
    }

    return new Response(page, {
      headers: {
        'content-type': 'text/html; charset=utf-8',
        'cache-control': 'public, max-age=300',
      },
    });
  },
};
