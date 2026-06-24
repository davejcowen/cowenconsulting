# cowensoftware.com

Static one-page marketing site for Cowen Consulting. Plain HTML/CSS/JS in a
single `index.html` — no build step, no framework, no dependencies.

It is hosted on the **same IONOS VPS** as mydishdynasty.com but is **completely
independent**: its own GitHub repo, its own Nginx server block, its own web
root (`/var/www/cowensoftware`), and its own Cloudflare zone. It does not touch
the Docker stack and is not part of any mydishdynasty deploy.

```
repo (this)  ──push──▶  GitHub  ──git pull──▶  /var/www/cowensoftware on the VPS
                                                 ▲
browser ──HTTPS──▶ Cloudflare ──HTTP :80──▶ host Nginx (cowensoftware.conf) ┘
```

## Files

| Path | Purpose |
|---|---|
| `index.html` | The entire site. |
| `deploy/cowensoftware.conf` | Nginx server block → install at `/etc/nginx/conf.d/cowensoftware.conf` on the VPS. |
| `deploy/deploy.sh` | One-command redeploy on the VPS (git pull + `nginx -t` + reload). |

## Edit / update the site

1. Edit `index.html` locally (open it in a browser to preview — it's just a file).
2. `git add -A && git commit -m "..." && git push`
3. On the VPS: `ssh dishdynasty-prod` then `/var/www/cowensoftware/deploy/deploy.sh`

That's the whole loop. The change is live in seconds (Cloudflare may edge-cache
fonts/assets; the HTML is set to a 5-minute max-age).

---

## One-time prod setup (runbook)

Two halves: **DNS at Cloudflare** (operator does this in the dashboard — it
needs registrar + Cloudflare access) and the **VPS side** (clone + Nginx).

### A. DNS — Cloudflare (operator, in the dashboard)

1. Cloudflare dashboard → **Add a site** → `cowensoftware.com` → **Free** plan.
2. Cloudflare gives you two nameservers. At the domain's **registrar**, set the
   nameservers to those two. (Propagation: minutes to a few hours.)
3. Cloudflare → **DNS → Records**, add:

   | Type | Name | Content | Proxy |
   |---|---|---|---|
   | A | `cowensoftware.com` | `216.250.127.150` | **Proxied** (🧡) |
   | A | `www` | `216.250.127.150` | **Proxied** (🧡) |

4. Cloudflare → **SSL/TLS → Overview** → **Flexible** (matches mydishdynasty's
   origin, which serves plain HTTP on :80). This gives the site free HTTPS with
   no cert work on the box.

> The orange-cloud proxy is what supplies SSL and hides the origin IP. Leave it on.

### B. VPS — clone + wire up Nginx (one time)

```bash
ssh dishdynasty-prod

# 1. Create the web root (dish-owned so deploys don't need sudo to pull).
sudo mkdir -p /var/www/cowensoftware
sudo chown dish:dish /var/www/cowensoftware

# 2. Clone this repo INTO the web root.
git clone https://github.com/davejcowen/cowenconsulting.git /var/www/cowensoftware

# 3. Install the Nginx server block (separate file — does NOT touch
#    mydishdynasty.conf).
sudo cp /var/www/cowensoftware/deploy/cowensoftware.conf /etc/nginx/conf.d/cowensoftware.conf

# 4. Validate the WHOLE nginx config, then reload (zero downtime).
sudo nginx -t
sudo systemctl reload nginx

# 5. Make the deploy script executable.
chmod +x /var/www/cowensoftware/deploy/deploy.sh
```

This is a **public** repo, so the clone/pull above works anonymously over
HTTPS — no deploy key or token needed on the VPS.

### C. Verify

```bash
# On the VPS — Nginx answers for the new host before DNS even propagates:
curl -s -H 'Host: cowensoftware.com' http://127.0.0.1/ | head -5     # → the HTML

# From anywhere, once DNS + Cloudflare are live:
curl -I https://cowensoftware.com                                    # → HTTP/2 200, server: cloudflare
```

If `curl -I` fails with an SSL error, DNS hasn't propagated yet or the SSL/TLS
mode isn't Flexible.

---

## Notes / boundaries

- **No firewall change needed** — the site shares port 80 (and 443 via
  Cloudflare); Nginx routes by Host header.
- **Independent uptime caveat:** same box as mydishdynasty, so if the VPS is
  down (or rebooting), this site is down too. Fine for a marketing page.
- **Backups:** the source of truth is this GitHub repo. The mydishdynasty
  nightly offsite backup does **not** cover `/var/www/cowensoftware` — but it
  doesn't need to, because everything here is in git. To restore: re-clone.
- **SSL mode:** stays on Cloudflare **Flexible**. If mydishdynasty later moves
  to Full (strict), this site would need its own Cloudflare Origin CA cert for
  `cowensoftware.com` (a separate apex domain isn't covered by the
  `*.mydishdynasty.com` origin cert).
