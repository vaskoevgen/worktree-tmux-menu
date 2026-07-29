#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >"${FZF_TEST_ARGS_LOG:?}"

options=()
while IFS= read -r option; do
  options+=("$option")
done
printf '%s\n' "${options[@]}" >"${FZF_TEST_INPUT_LOG:?}"

if [[ "${FZF_TEST_CANCEL:-0}" == "1" ]]; then
  exit 130
fi

requested_path="${FZF_TEST_MATCH_PATH:-}"
if [[ -n "${FZF_TEST_CHOICES_FILE:-}" ]]; then
  call_number=1
  if [[ -s "${FZF_TEST_STATE_FILE:?}" ]]; then
    call_number="$(<"$FZF_TEST_STATE_FILE")"
    call_number=$((call_number + 1))
  fi
  printf '%s\n' "$call_number" >"$FZF_TEST_STATE_FILE"
  requested_path="$(sed -n "${call_number}p" "$FZF_TEST_CHOICES_FILE")"
fi
if [[ "$requested_path" == "CANCEL" ]]; then
  exit 130
fi

if [[ -n "$requested_path" ]]; then
  for option in "${options[@]}"; do
    if [[ "${option#*$'\t'}" == "$requested_path" ]]; then
      printf '%s\n' "$option"
      exit 0
    fi
  done
  printf 'fake-fzf: path not found: %s\n' "$requested_path" >&2
  exit 2
fi

selection="${FZF_TEST_SELECTION:-1}"
[[ "$selection" =~ ^[0-9]+$ ]]
((selection >= 1 && selection <= ${#options[@]}))
printf '%s\n' "${options[$((selection - 1))]}"
