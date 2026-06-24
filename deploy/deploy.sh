#!/usr/bin/env bash
# Deploy the latest cowensoftware.com static site on the prod VPS.
#
# Run this AS THE dish USER ON THE VPS after the one-time setup in README.md:
#   ssh dishdynasty-prod
#   /var/www/cowensoftware/deploy/deploy.sh
#
# It is a pure static-file pull: no Docker, no build step, no impact on the
# mydishdynasty stack. `nginx -t` is run before the reload so a bad config can
# never take the box down.
set -euo pipefail

SITE_DIR=/var/www/cowensoftware

echo "→ Pulling latest into ${SITE_DIR}"
git -C "${SITE_DIR}" pull --ff-only

# Re-sync the nginx vhost in case it changed in the repo, then validate+reload.
if ! sudo cmp -s "${SITE_DIR}/deploy/cowensoftware.conf" /etc/nginx/conf.d/cowensoftware.conf; then
  echo "→ nginx vhost changed — updating /etc/nginx/conf.d/cowensoftware.conf"
  sudo cp "${SITE_DIR}/deploy/cowensoftware.conf" /etc/nginx/conf.d/cowensoftware.conf
fi

echo "→ Validating nginx config"
sudo nginx -t

echo "→ Reloading nginx"
sudo systemctl reload nginx

echo "✓ cowensoftware.com deployed @ $(git -C "${SITE_DIR}" rev-parse --short HEAD)"
