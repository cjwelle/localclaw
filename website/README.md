# LocalClaw landing page

The canonical source repository is [github.com/cjwelle/localclaw](https://github.com/cjwelle/localclaw).

The site copy mirrors the project docs: LocalClaw supports three session modes
and Vault is optional to preinstall because the guided installer can provision
it for Vault-backed sessions.

A lightweight, dependency-free one-page site for [localclaw.bot](https://localclaw.bot).

## Recommended hosting: Cloudflare Pages

Cloudflare Pages is the best fit for this site: the static hosting plan has a
free tier, custom domains, automatic HTTPS, and can deploy directly from a
GitHub repository. There is no server to patch and no runtime to maintain.

1. Put this directory in a GitHub repository, or publish it from the existing
   project as a dedicated `website/` directory.
2. In Cloudflare, open **Workers & Pages → Create application → Pages → Connect
   to Git**.
3. Select the repository and set the build configuration to:
   - Framework preset: **None**
   - Build command: **leave blank**
   - Output directory: `/`
4. Deploy the site.
5. In the Pages project, open **Custom domains**, add `localclaw.bot`, and
   follow Cloudflare's DNS instructions. Add `www.localclaw.bot` too if you
   want that hostname redirected or served.

The included `CNAME` file also makes the intended hostname explicit for hosts
that use it. Cloudflare Pages will manage TLS after the DNS record is active.

## Other inexpensive options

- **GitHub Pages:** free for a public repository and also supports custom
  domains. Good if the site lives in GitHub already.
- **Netlify:** has a free static-site tier and an easy drag-and-drop/deploy-
  from-Git workflow. It is more tooling than this page needs but a convenient
  fallback.
- **Vercel:** has a free personal tier, though Cloudflare Pages or GitHub Pages
  is simpler for a plain static landing page.

For the current page, choose Cloudflare Pages unless you specifically want the
site hosted alongside the source on GitHub Pages. Confirm current plan limits
and terms on the provider's pricing page before committing to a commercial
deployment.

## Local preview

From this directory:

```sh
python3 -m http.server 8080
```

Then open <http://localhost:8080>. The page is plain HTML/CSS/SVG and needs no
build step.

## Brand direction

The visual system is techy but warm: deep navy for trust and terminal surfaces,
teal for local connectivity, and a small amber accent for human action. The
logo is an inline-friendly SVG at `assets/logo.svg`, combining a soft claw
shape with a glowing local node.
