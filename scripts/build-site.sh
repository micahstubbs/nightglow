#!/bin/bash
# Build the nightglow.io static site into site/dist: compile TypeScript,
# then copy the static files. Usage: scripts/build-site.sh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p site/dist
rsync -a --delete --exclude js/ --exclude package.json \
  site/index.html site/styles.css site/assets site/dist/
[ -f site/CNAME ] && cp site/CNAME site/dist/CNAME
node_modules/.bin/tsc -p site
cp site/package.json site/dist/js/package.json
echo "Built site/dist ($(find site/dist -type f | wc -l | tr -d ' ') files)"
