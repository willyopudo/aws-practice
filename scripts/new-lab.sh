#!/usr/bin/env bash
# Start a new lab from the template.
#   ./scripts/new-lab.sh s3-static-site
set -euo pipefail

name="${1:-}"
if [[ -z "$name" ]]; then
  echo "usage: ./scripts/new-lab.sh <lab-name>   e.g. s3-static-site" >&2
  exit 1
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Next sequence number, zero-padded.
n=$(find "$root/labs" -maxdepth 1 -type d -name '[0-9][0-9]-*' | wc -l | tr -d ' ')
seq=$(printf "%02d" $((n + 1)))
dir="$root/labs/${seq}-${name}"

if [[ -e "$dir" ]]; then
  echo "✗ $dir already exists" >&2
  exit 1
fi

cp -R "$root/labs/_template" "$dir"
# Substitute the lab name into the template placeholders.
find "$dir" -type f -print0 | xargs -0 sed -i '' "s/__LAB_NAME__/${seq}-${name}/g"

echo "✓ Created labs/${seq}-${name}"
echo
echo "  cd labs/${seq}-${name}"
echo "  terraform init"
echo "  terraform plan"
