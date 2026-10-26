#!/usr/bin/env bash

BUILD_STEP=0
BUILD_TOTAL=5

run_build_step() {
  local label="$1"
  shift
  BUILD_STEP=$((BUILD_STEP + 1))
  BUILD_LABELS[BUILD_STEP]="$label"

  local log_file
  log_file="$(mktemp)"
  local step_percent=$(((BUILD_STEP - 1) * 100 / BUILD_TOTAL))
  local filled=$((step_percent / 5))
  local empty=$((20 - filled))
  local bar="$(printf '%*s' "$filled" '' | tr ' ' '=')$(printf '%*s' "$empty" '')"
  local pid status elapsed=0 frame=0 started=$SECONDS
  local spinner='|/-\\'

  printf '\r[%d/%d] [%s] %3d%% %s ' "$BUILD_STEP" "$BUILD_TOTAL" "$bar" "$step_percent" "$label"

  "$@" >"$log_file" 2>&1 &
  pid=$!
  if [[ -t 1 ]]; then
    while kill -0 "$pid" 2>/dev/null; do
      printf '\r[%d/%d] [%s] %3d%% %s %c %02d:%02d' \
        "$BUILD_STEP" "$BUILD_TOTAL" "$bar" "$step_percent" "$label" \
        "${spinner:frame%4:1}" "$((elapsed / 60))" "$((elapsed % 60))"
      sleep 0.2
      elapsed=$((SECONDS - started))
      frame=$((frame + 1))
    done
  fi

  if wait "$pid"; then
    status=0
  else
    status=$?
  fi

  if [[ -s "$log_file" ]]; then cat "$log_file"; fi
  rm -f "$log_file"
  if [[ "$status" -ne 0 ]]; then
    if [[ -t 1 ]]; then printf '\r'; fi
    printf 'Build step failed: %s\n' "$label" >&2
    return "$status"
  fi

  if [[ "$BUILD_STEP" -eq "$BUILD_TOTAL" ]]; then
    local done_percent=$((BUILD_STEP * 100 / BUILD_TOTAL))
    local done_filled=$((done_percent / 5))
    local done_empty=$((20 - done_filled))
    local done_bar="$(printf '%*s' "$done_filled" '' | tr ' ' '=')$(printf '%*s' "$done_empty" '')"
    printf '\r[%d/%d] [%s] %3d%% Build complete (%02d:%02d)\n' \
      "$BUILD_TOTAL" "$BUILD_TOTAL" "$done_bar" "$done_percent" \
      "$((elapsed / 60))" "$((elapsed % 60))"
  fi
}
