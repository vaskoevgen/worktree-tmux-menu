#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"${WT_TEST_LOG:?}"

selected_path=""
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "-C" ]]; then
    selected_path="$2"
    shift 2
  else
    shift
  fi
done

printf '{"path":"%s"}\n' "${selected_path:?}"
