#!/usr/bin/env bash
set -euo pipefail

endpoints_file=${1:-docs/public-endpoints.json}

if [[ ! -f "$endpoints_file" ]]; then
  echo "::error::Endpoint file not found: $endpoints_file"
  exit 1
fi

failures=0

while IFS= read -r row; do
  name=$(jq -r '.name' <<<"$row")
  url=$(jq -r '.url' <<<"$row")
  expected_status=$(jq -r '.expected_status' <<<"$row")
  require_hsts=$(jq -r '.require_hsts' <<<"$row")
  min_tls=$(jq -r '.min_tls_version' <<<"$row")
  host=$(jq -r '.url' <<<"$row" | sed -E 's#^https://([^/:]+).*#\1#')

  echo "==> Checking $name ($url)"

  headers=$(curl -sSIL --max-time 20 "$url")
  status=$(curl -sSIL -o /dev/null -w '%{http_code}' --max-time 20 "$url")

  if [[ "$status" != "$expected_status" ]]; then
    echo "::error::$name returned HTTP $status; expected $expected_status"
    failures=$((failures + 1))
  fi

  if [[ "$require_hsts" == "true" ]] && ! grep -qi '^strict-transport-security:' <<<"$headers"; then
    echo "::error::$name is missing Strict-Transport-Security"
    failures=$((failures + 1))
  fi

  protocol=$(curl -sSIL -o /dev/null -w '%{http_version}' --max-time 20 "$url")
  echo "$name: HTTP $status, protocol $protocol"

  if [[ "$min_tls" != "1.2" ]]; then
    echo "::error::$name declares unsupported minimum TLS version $min_tls; this check currently enforces TLS 1.2"
    failures=$((failures + 1))
  else
    if openssl s_client -brief -tls1_2 -connect "$host:443" -servername "$host" </dev/null 2>&1 | grep -q '^CONNECTION ESTABLISHED'; then
      echo "$name accepts TLS 1.2"
    else
      echo "::error::$name did not negotiate TLS 1.2"
      failures=$((failures + 1))
    fi
  fi

  if openssl s_client -brief -tls1_1 -connect "$host:443" -servername "$host" </dev/null 2>&1 | grep -q '^CONNECTION ESTABLISHED'; then
    echo "::error::$name still accepts TLS 1.1"
    failures=$((failures + 1))
  else
    echo "$name rejects TLS 1.1"
  fi

  expiry=$(echo | openssl s_client -servername "$host" -connect "$host:443" 2>/dev/null \
    | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)

  if [[ -z "$expiry" ]]; then
    echo "::error::$name certificate could not be validated"
    failures=$((failures + 1))
  else
    expiry_epoch=$(date -d "$expiry" +%s)
    now_epoch=$(date +%s)
    days_left=$(( (expiry_epoch - now_epoch) / 86400 ))

    echo "$name certificate expires in $days_left days"

    if (( days_left < 14 )); then
      echo "::error::$name certificate expires in $days_left days"
      failures=$((failures + 1))
    fi
  fi
done < <(jq -c '.endpoints[]' "$endpoints_file")

exit "$failures"
