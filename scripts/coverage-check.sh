#!/usr/bin/env bash
# Usage: scripts/coverage-check.sh <kcov-output-dir> <min-percent>
# Fails if line coverage of in-scope shell scripts is below <min-percent>.
# kcov only reports scripts that ran, so in-scope scripts missing from the report
# count as 0% (their non-blank, non-comment lines are all uncovered).
# Scope: tracked *.sh under scripts/ and labs/, minus tests/coverage-exclude.txt.
set -euo pipefail

dir="${1:?kcov output dir}"
min="${2:?minimum percent}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

# kcov writes a per-run report under <dir>/bats.<hash>/ and, for multiple runs, kcov-merged/.
report="$(find "$dir" -path '*kcov-merged*' -name cobertura.xml 2>/dev/null | head -1 || true)"
[[ -n "$report" ]] || report="$(find "$dir" -name cobertura.xml 2>/dev/null | head -1 || true)"

git ls-files --cached --others --exclude-standard 'scripts/*.sh' 'labs/*.sh' \
  | grep -vxF -f <(sed -e 's/[[:space:]]*#.*//' -e '/^$/d' tests/coverage-exclude.txt 2>/dev/null) \
  | python3 -c '
import sys, re, xml.etree.ElementTree as ET
report, minimum = sys.argv[1], float(sys.argv[2])
scope = [l.strip() for l in sys.stdin if l.strip()]
hits = {}
if report:
    for cls in ET.parse(report).iter("class"):
        fn = cls.get("filename")
        lines = cls.findall("lines/line")
        hits[fn] = (sum(1 for l in lines if int(l.get("hits")) > 0), len(lines))
covered = total = 0
rows = []
for path in scope:
    match = next((v for k, v in hits.items() if path.endswith(k) or k.endswith(path)), None)
    if match is None:
        n = sum(1 for l in open(path) if l.strip() and not l.lstrip().startswith("#"))
        match = (0, n)
    covered += match[0]; total += match[1]
    rows.append((match[0] / match[1] * 100 if match[1] else 100.0, path))
pct = covered / total * 100 if total else 0.0
for p, path in sorted(rows):
    if p < minimum:
        print(f"  {p:5.1f}%  {path}")
status = "PASS" if pct >= minimum and total else "FAIL"
print(f"coverage: {pct:.1f}% (min {minimum:g}) {status}")
sys.exit(0 if status == "PASS" else 1)
' "$report" "$min"
