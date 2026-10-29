#!/bin/sh
# tv-deadt — disable Samsung TV advertising and telemetry daemons.
# Runtime only: a reboot restores everything on its own.
# Usage: tv-deadt [status|harden|restore] [--no-acr]
set -u
STATE=/opt/tv-deadt/state

UNITS_ADS="adagent-service pisa-service"
UNITS_TELEMETRY="scs-agent sp-kpi devicetracker stability-monitor emergency-log-transmitter issue_report_agent abnormal_user_behavior org.tizen.tv.tagpro-service-tv"
UNITS_ACR="contents-recognition-service csf-content-engine"

acr=1; mode=status
for a in "$@"; do
  case "$a" in
    --no-acr) acr=0 ;;
    status|harden|restore) mode=$a ;;
    *) echo "unknown argument: $a" >&2; exit 2 ;;
  esac
done

units() {
  if [ "$acr" = 1 ]; then echo "$UNITS_ADS $UNITS_TELEMETRY $UNITS_ACR"
  else echo "$UNITS_ADS $UNITS_TELEMETRY"; fi
}

case "$mode" in
status)
  printf '%-42s %s\n' UNIT STATE
  for u in $(units); do printf '%-42s %s\n' "$u" "$(systemctl is-active "$u" 2>/dev/null)"; done
  ;;
harden)
  mkdir -p /opt/tv-deadt || exit 1
  : > "$STATE"
  for u in $(units); do
    [ "$(systemctl is-active "$u" 2>/dev/null)" = active ] && echo "$u" >> "$STATE"
    systemctl stop --no-block "$u" 2>/dev/null
  done
  # a few of these take >5s to wind down, so give them a moment before reporting
  sleep 5
  echo "was running: $(wc -l < "$STATE") units (saved to $STATE)"
  echo "now active:  $(for u in $(units); do systemctl is-active "$u" 2>/dev/null | grep -qx active && echo "$u"; done | tr '\n' ' ')"
  echo "failed:      $(systemctl --failed --no-pager --plain 2>/dev/null | grep -c failed)"
  echo "reboot to undo."
  ;;
restore)
  n=0
  if [ -f "$STATE" ]; then
    while read -r u; do
      [ -n "$u" ] || continue
      systemctl start --no-block "$u" 2>/dev/null && n=$((n+1))
    done < "$STATE"
  fi
  echo "restarted $n units"
  ;;
esac
