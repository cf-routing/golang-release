#!/usr/bin/env bash

set -euo pipefail

version_number="$(cat version/version)"

pushd "input_repo/$SOURCE_PATH"

current_json="$(trivy filesystem . --severity "$SEVERITY" --security-checks vuln --format json | jq "(if .Results then .Results else [] end) | map(.Vulnerabilities) | flatten | map(select(. != null)) | unique_by(.VulnerabilityID)")"
current_list=$(echo "$current_json" | jq -r "map(.VulnerabilityID) | sort | join(\"\\n\")")


git checkout "v${version_number}"
previous_json="$(trivy filesystem . --severity "$SEVERITY" --security-checks vuln --format json | jq "(if .Results then .Results else [] end) | map(.Vulnerabilities) | flatten | map(select(. != null)) | unique_by(.VulnerabilityID)")"
previous_list=$(echo "$previous_json" | jq -r "map(.VulnerabilityID) | sort | join(\"\\n\")")

popd

patched_cves="$(comm -13 <(echo "$current_list") <(echo "$previous_list"))"

if [ -z "$patched_cves" ]; then
  echo "" > patched_cves/patched-cves.txt
  echo "{}" > patched_cves/patched-cves.json
  echo "" > patched_cves/release-notes.md
  echo "No fixed CVEs detected"
  exit 1
fi

cve_ids=""
for cve_id in $patched_cves; do
  cve_ids="$cve_ids,\"$cve_id\""
done
cve_ids="${cve_ids:1}"

patched_json="$(echo "$previous_json" | jq "map(select(.VulnerabilityID == ($cve_ids)))")"
release_notes="
### Fixed CVEs:

$(echo "$patched_json" | jq -r "map(\"* \" + .VulnerabilityID + \": \" + if .Title then .Title else .Description end) | sort | join(\"\n\")")
"

echo "$release_notes"

echo "$patched_cves" > patched_cves/patched-cves.txt
echo "$patched_json" > patched_cves/patched-cves.json
echo "$release_notes" > patched_cves/release-notes.md
