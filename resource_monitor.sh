#!/usr/bin/env bash

set -u

INTERVAL="${1:-1}"
OUTPUT="${2:-system_usage.csv}"

if ! [[ "$INTERVAL" =~ ^[0-9]+([.][0-9]+)?$ ]] ||
   ! awk -v i="$INTERVAL" 'BEGIN { exit !(i > 0) }'; then
    echo "Usage: $0 [interval_seconds] [output_csv]"
    exit 1
fi

read_cpu() {
    local cpu user nice system idle iowait irq softirq steal rest

    read -r cpu user nice system idle iowait irq softirq steal rest \
        < /proc/stat

    CPU_TOTAL=$((user + nice + system + idle + iowait + irq + softirq + steal))
    CPU_IDLE=$((idle + iowait))
}

read_memory() {
    local total available

    total=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
    available=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)

    RAM_USED_MB=$(awk -v t="$total" -v a="$available" \
        'BEGIN { printf "%.2f", (t-a)/1024 }')

    RAM_PERCENT=$(awk -v t="$total" -v a="$available" \
        'BEGIN { printf "%.2f", 100*(t-a)/t }')
}

read_cpu
PREV_TOTAL=$CPU_TOTAL
PREV_IDLE=$CPU_IDLE

START=$(date +%s)

echo "timestamp,elapsed_seconds,cpu_percent,ram_used_mb,ram_percent" \
> "$OUTPUT"

echo "Monitoring started. Press Ctrl+C to stop."
echo "Writing measurements to $OUTPUT"

while true; do
    sleep "$INTERVAL"

    NOW=$(date +%s)
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    read_cpu

    TOTAL_DELTA=$((CPU_TOTAL - PREV_TOTAL))
    IDLE_DELTA=$((CPU_IDLE - PREV_IDLE))

    CPU_PERCENT=$(awk -v t="$TOTAL_DELTA" -v i="$IDLE_DELTA" \
        'BEGIN {
            if (t > 0) printf "%.2f", 100*(t-i)/t
            else printf "0.00"
        }')

    PREV_TOTAL=$CPU_TOTAL
    PREV_IDLE=$CPU_IDLE

    read_memory

    ELAPSED=$((NOW - START))

    printf '%s,%s,%s,%s,%s\n' \
        "$TIMESTAMP" "$ELAPSED" "$CPU_PERCENT" \
        "$RAM_USED_MB" "$RAM_PERCENT" >> "$OUTPUT"

    printf '\rElapsed: %ss | CPU: %s%% | RAM: %s MB (%s%%)   ' \
        "$ELAPSED" "$CPU_PERCENT" "$RAM_USED_MB" "$RAM_PERCENT"
done
