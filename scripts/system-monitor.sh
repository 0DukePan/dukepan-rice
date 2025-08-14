#!/usr/bin/env bash

# =====================================================
# Advanced System Monitor for i3 Rice
# Comprehensive system monitoring with intelligent alerts
# =====================================================

set -euo pipefail

# Configuration
CONFIG_DIR="$HOME/.config/system-monitor"
CACHE_DIR="$HOME/.cache/system-monitor"
LOG_FILE="$CACHE_DIR/system-monitor.log"
ALERT_FILE="$CACHE_DIR/alerts.json"
HISTORY_FILE="$CACHE_DIR/history.json"

# Thresholds
CPU_WARNING=70
CPU_CRITICAL=85
MEMORY_WARNING=80
MEMORY_CRITICAL=90
DISK_WARNING=85
DISK_CRITICAL=95
TEMP_WARNING=70
TEMP_CRITICAL=80
LOAD_WARNING=2.0
LOAD_CRITICAL=4.0

# Colors for output
declare -A COLORS=(
    ["normal"]="#cdd6f4"
    ["warning"]="#f9e2af"
    ["critical"]="#f38ba8"
    ["good"]="#a6e3a1"
    ["info"]="#89b4fa"
)

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Initialize system
init_system() {
    mkdir -p "$CONFIG_DIR" "$CACHE_DIR"
    
    if [[ ! -f "$CONFIG_DIR/config" ]]; then
        cat > "$CONFIG_DIR/config" << 'EOF'
# System Monitor Configuration
ENABLE_NOTIFICATIONS=true
ENABLE_LOGGING=true
ENABLE_HISTORY=true
HISTORY_RETENTION_DAYS=7
ALERT_COOLDOWN=300
MONITOR_INTERVAL=5
ENABLE_NETWORK_MONITORING=true
ENABLE_PROCESS_MONITORING=true
ENABLE_SERVICE_MONITORING=true
CRITICAL_SERVICES=("NetworkManager" "systemd-logind" "dbus" "pulseaudio")
EOF
    fi
    
    source "$CONFIG_DIR/config"
    
    # Initialize history file
    if [[ ! -f "$HISTORY_FILE" ]]; then
        echo "[]" > "$HISTORY_FILE"
    fi
    
    # Initialize alerts file
    if [[ ! -f "$ALERT_FILE" ]]; then
        echo "{}" > "$ALERT_FILE"
    fi
}

# Get CPU usage
get_cpu_usage() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')
    echo "${cpu_usage:-0}"
}

# Get memory usage
get_memory_usage() {
    local mem_info=$(free | grep Mem)
    local total=$(echo "$mem_info" | awk '{print $2}')
    local used=$(echo "$mem_info" | awk '{print $3}')
    local percentage=$(echo "scale=1; $used * 100 / $total" | bc)
    echo "${percentage:-0}"
}

# Get disk usage
get_disk_usage() {
    local path="${1:-/}"
    local usage=$(df "$path" | tail -1 | awk '{print $5}' | sed 's/%//')
    echo "${usage:-0}"
}

# Get system temperature
get_temperature() {
    local temp=0
    
    # Try different temperature sources
    if command -v sensors &>/dev/null; then
        temp=$(sensors 2>/dev/null | grep -E "Core|temp" | head -1 | awk '{print $3}' | sed 's/+//;s/°C//' | cut -d'.' -f1)
    elif [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
        temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        temp=$((temp / 1000))
    fi
    
    echo "${temp:-0}"
}

# Get system load
get_system_load() {
    local load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    echo "${load:-0}"
}

# Get network usage
get_network_usage() {
    local interface="${1:-$(ip route | grep default | awk '{print $5}' | head -1)}"
    
    if [[ -z "$interface" ]]; then
        echo "0 0"
        return
    fi
    
    local rx_bytes=$(cat "/sys/class/net/$interface/statistics/rx_bytes" 2>/dev/null || echo "0")
    local tx_bytes=$(cat "/sys/class/net/$interface/statistics/tx_bytes" 2>/dev/null || echo "0")
    
    # Convert to MB/s (simplified)
    local rx_mb=$(echo "scale=2; $rx_bytes / 1024 / 1024" | bc)
    local tx_mb=$(echo "scale=2; $tx_bytes / 1024 / 1024" | bc)
    
    echo "$rx_mb $tx_mb"
}

# Get process information
get_top_processes() {
    local count="${1:-5}"
    ps aux --sort=-%cpu | head -n $((count + 1)) | tail -n +2 | while read line; do
        local user=$(echo "$line" | awk '{print $1}')
        local pid=$(echo "$line" | awk '{print $2}')
        local cpu=$(echo "$line" | awk '{print $3}')
        local mem=$(echo "$line" | awk '{print $4}')
        local command=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/[[:space:]]*$//')
        
        echo "$pid:$user:$cpu:$mem:$command"
    done
}

# Check service status
check_service_status() {
    local service="$1"
    if systemctl is-active --quiet "$service"; then
        echo "active"
    else
        echo "inactive"
    fi
}

# Get system information summary
get_system_summary() {
    local cpu=$(get_cpu_usage)
    local memory=$(get_memory_usage)
    local disk=$(get_disk_usage "/")
    local temp=$(get_temperature)
    local load=$(get_system_load)
    
    # Determine status colors
    local cpu_color="${COLORS[normal]}"
    local mem_color="${COLORS[normal]}"
    local disk_color="${COLORS[normal]}"
    local temp_color="${COLORS[normal]}"
    
    # CPU color
    if (( $(echo "$cpu >= $CPU_CRITICAL" | bc -l) )); then
        cpu_color="${COLORS[critical]}"
    elif (( $(echo "$cpu >= $CPU_WARNING" | bc -l) )); then
        cpu_color="${COLORS[warning]}"
    else
        cpu_color="${COLORS[good]}"
    fi
    
    # Memory color
    if (( $(echo "$memory >= $MEMORY_CRITICAL" | bc -l) )); then
        mem_color="${COLORS[critical]}"
    elif (( $(echo "$memory >= $MEMORY_WARNING" | bc -l) )); then
        mem_color="${COLORS[warning]}"
    else
        mem_color="${COLORS[good]}"
    fi
    
    # Disk color
    if (( disk >= DISK_CRITICAL )); then
        disk_color="${COLORS[critical]}"
    elif (( disk >= DISK_WARNING )); then
        disk_color="${COLORS[warning]}"
    else
        disk_color="${COLORS[good]}"
    fi
    
    # Temperature color
    if (( temp >= TEMP_CRITICAL )); then
        temp_color="${COLORS[critical]}"
    elif (( temp >= TEMP_WARNING )); then
        temp_color="${COLORS[warning]}"
    else
        temp_color="${COLORS[good]}"
    fi
    
    echo "CPU: ${cpu}% | MEM: ${memory}% | DISK: ${disk}% | TEMP: ${temp}°C"
}

# Record system metrics to history
record_metrics() {
    local timestamp=$(date +%s)
    local cpu=$(get_cpu_usage)
    local memory=$(get_memory_usage)
    local disk=$(get_disk_usage "/")
    local temp=$(get_temperature)
    local load=$(get_system_load)
    
    # Create metrics object
    local metrics=$(jq -n \
        --arg timestamp "$timestamp" \
        --arg cpu "$cpu" \
        --arg memory "$memory" \
        --arg disk "$disk" \
        --arg temp "$temp" \
        --arg load "$load" \
        '{
            timestamp: $timestamp | tonumber,
            cpu: $cpu | tonumber,
            memory: $memory | tonumber,
            disk: $disk | tonumber,
            temperature: $temp | tonumber,
            load: $load | tonumber
        }')
    
    # Add to history
    local history=$(cat "$HISTORY_FILE")
    echo "$history" | jq ". += [$metrics]" > "$HISTORY_FILE"
    
    # Clean old history (keep last 7 days)
    local cutoff=$((timestamp - (HISTORY_RETENTION_DAYS * 86400)))
    echo "$history" | jq "map(select(.timestamp > $cutoff))" > "$HISTORY_FILE"
}

# Check for alerts
check_alerts() {
    local cpu=$(get_cpu_usage)
    local memory=$(get_memory_usage)
    local disk=$(get_disk_usage "/")
    local temp=$(get_temperature)
    local load=$(get_system_load)
    local current_time=$(date +%s)
    
    # Load existing alerts
    local alerts=$(cat "$ALERT_FILE")
    
    # Check CPU
    if (( $(echo "$cpu >= $CPU_CRITICAL" | bc -l) )); then
        send_alert "cpu_critical" "Critical CPU Usage" "CPU usage is at ${cpu}%" "critical"
    elif (( $(echo "$cpu >= $CPU_WARNING" | bc -l) )); then
        send_alert "cpu_warning" "High CPU Usage" "CPU usage is at ${cpu}%" "warning"
    fi
    
    # Check Memory
    if (( $(echo "$memory >= $MEMORY_CRITICAL" | bc -l) )); then
        send_alert "memory_critical" "Critical Memory Usage" "Memory usage is at ${memory}%" "critical"
    elif (( $(echo "$memory >= $MEMORY_WARNING" | bc -l) )); then
        send_alert "memory_warning" "High Memory Usage" "Memory usage is at ${memory}%" "warning"
    fi
    
    # Check Disk
    if (( disk >= DISK_CRITICAL )); then
        send_alert "disk_critical" "Critical Disk Usage" "Disk usage is at ${disk}%" "critical"
    elif (( disk >= DISK_WARNING )); then
        send_alert "disk_warning" "High Disk Usage" "Disk usage is at ${disk}%" "warning"
    fi
    
    # Check Temperature
    if (( temp >= TEMP_CRITICAL )); then
        send_alert "temp_critical" "Critical Temperature" "System temperature is ${temp}°C" "critical"
    elif (( temp >= TEMP_WARNING )); then
        send_alert "temp_warning" "High Temperature" "System temperature is ${temp}°C" "warning"
    fi
    
    # Check critical services
    for service in "${CRITICAL_SERVICES[@]}"; do
        local status=$(check_service_status "$service")
        if [[ "$status" != "active" ]]; then
            send_alert "service_${service}" "Service Down" "Critical service $service is not running" "critical"
        fi
    done
}

# Send alert with cooldown
send_alert() {
    local alert_id="$1"
    local title="$2"
    local message="$3"
    local severity="$4"
    local current_time=$(date +%s)
    
    # Check cooldown
    local alerts=$(cat "$ALERT_FILE")
    local last_alert=$(echo "$alerts" | jq -r ".\"$alert_id\" // 0")
    
    if (( current_time - last_alert < ALERT_COOLDOWN )); then
        return
    fi
    
    # Send notification
    if [[ "$ENABLE_NOTIFICATIONS" == "true" ]] && command -v notify-send &>/dev/null; then
        local icon="dialog-warning"
        local urgency="normal"
        
        case "$severity" in
            "critical")
                icon="dialog-error"
                urgency="critical"
                ;;
            "warning")
                icon="dialog-warning"
                urgency="normal"
                ;;
        esac
        
        notify-send -i "$icon" -u "$urgency" "$title" "$message"
    fi
    
    # Log alert
    log "ALERT [$severity] $title: $message"
    
    # Update alert timestamp
    echo "$alerts" | jq ".\"$alert_id\" = $current_time" > "$ALERT_FILE"
}

# Generate system report
generate_report() {
    local output_file="${1:-$HOME/system-report-$(date +%Y%m%d-%H%M%S).txt}"
    
    cat > "$output_file" << EOF
System Monitor Report
Generated: $(date)
====================

System Information:
- Hostname: $(hostname)
- Kernel: $(uname -r)
- Uptime: $(uptime -p)
- Load Average: $(uptime | awk -F'load average:' '{print $2}')

Current Metrics:
- CPU Usage: $(get_cpu_usage)%
- Memory Usage: $(get_memory_usage)%
- Disk Usage: $(get_disk_usage "/")%
- Temperature: $(get_temperature)°C

Top Processes:
$(get_top_processes 10 | while IFS=':' read -r pid user cpu mem command; do
    printf "  PID: %-8s User: %-10s CPU: %-6s%% MEM: %-6s%% CMD: %s\n" "$pid" "$user" "$cpu" "$mem" "$command"
done)

Service Status:
$(for service in "${CRITICAL_SERVICES[@]}"; do
    local status=$(check_service_status "$service")
    printf "  %-20s: %s\n" "$service" "$status"
done)

Network Interfaces:
$(ip addr show | grep -E "^[0-9]+:" | awk '{print $2}' | tr -d ':' | while read interface; do
    local status=$(ip link show "$interface" | grep -o "state [A-Z]*" | awk '{print $2}')
    printf "  %-15s: %s\n" "$interface" "$status"
done)

Disk Usage:
$(df -h | grep -E "^/dev" | while read line; do
    echo "  $line"
done)

Recent History (last 24 hours):
$(cat "$HISTORY_FILE" | jq -r '.[] | select(.timestamp > (now - 86400)) | "\(.timestamp | strftime("%H:%M:%S")): CPU=\(.cpu)% MEM=\(.memory)% TEMP=\(.temperature)°C"' | tail -20)
EOF
    
    echo "Report generated: $output_file"
}

# Monitor daemon
run_daemon() {
    log "Starting system monitor daemon..."
    
    while true; do
        if [[ "$ENABLE_HISTORY" == "true" ]]; then
            record_metrics
        fi
        
        check_alerts
        
        sleep "$MONITOR_INTERVAL"
    done
}

# Show detailed system information
show_detailed_info() {
    echo "System Monitor - Detailed Information"
    echo "===================================="
    echo
    
    echo "Current Metrics:"
    echo "  CPU Usage: $(get_cpu_usage)%"
    echo "  Memory Usage: $(get_memory_usage)%"
    echo "  Disk Usage (root): $(get_disk_usage "/")%"
    echo "  Temperature: $(get_temperature)°C"
    echo "  Load Average: $(get_system_load)"
    echo
    
    echo "Network Usage:"
    local net_usage=$(get_network_usage)
    echo "  RX: $(echo "$net_usage" | awk '{print $1}') MB"
    echo "  TX: $(echo "$net_usage" | awk '{print $2}') MB"
    echo
    
    echo "Top 5 Processes (by CPU):"
    get_top_processes 5 | while IFS=':' read -r pid user cpu mem command; do
        printf "  PID: %-8s CPU: %-6s%% MEM: %-6s%% CMD: %s\n" "$pid" "$cpu" "$mem" "$(echo "$command" | cut -c1-40)"
    done
    echo
    
    echo "Critical Services:"
    for service in "${CRITICAL_SERVICES[@]}"; do
        local status=$(check_service_status "$service")
        printf "  %-20s: %s\n" "$service" "$status"
    done
}

# Handle click events
handle_click() {
    case "${1:-left}" in
        "left")
            # Show detailed info in rofi
            show_detailed_info | rofi -dmenu -i -p "System Monitor" -theme ~/.config/rofi/themes/launcher.rasi
            ;;
        "right")
            # Generate and open report
            local report_file="/tmp/system-report-$(date +%Y%m%d-%H%M%S).txt"
            generate_report "$report_file"
            alacritty -e less "$report_file"
            ;;
        "middle")
            # Open system monitor
            gnome-system-monitor &
            ;;
    esac
}

# Main function
main() {
    init_system
    
    case "${1:-summary}" in
        "summary")
            get_system_summary
            ;;
        "daemon")
            run_daemon
            ;;
        "report")
            generate_report "${2:-}"
            ;;
        "detailed"|"info")
            show_detailed_info
            ;;
        "alerts")
            check_alerts
            ;;
        "--click")
            handle_click "${2:-left}"
            ;;
        "help"|"--help")
            cat << EOF
System Monitor - Advanced System Monitoring

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    summary     Show system summary (default)
    daemon      Run monitoring daemon
    report      Generate system report
    detailed    Show detailed information
    alerts      Check for alerts
    --click     Handle click events

Examples:
    $0 summary          # Show brief system status
    $0 daemon           # Start monitoring daemon
    $0 report ~/report.txt  # Generate report to file
    $0 --click left     # Handle left click
EOF
            ;;
        *)
            echo "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

main "$@"
