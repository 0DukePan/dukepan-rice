#!/usr/bin/env bash

# =====================================================
# System Monitor Script for Polybar - Perfect i3 Rice
# Advanced system monitoring with notifications
# =====================================================

# Configuration
CACHE_DIR="$HOME/.cache/polybar"
CACHE_FILE="$CACHE_DIR/system_monitor"
CACHE_DURATION=5  # seconds
NOTIFY_THRESHOLD_CPU=80
NOTIFY_THRESHOLD_MEM=85
NOTIFY_THRESHOLD_TEMP=70

# Colors (Catppuccin Mocha)
COLOR_NORMAL="#a6e3a1"
COLOR_WARNING="#f9e2af"
COLOR_CRITICAL="#f38ba8"

# Create cache directory
mkdir -p "$CACHE_DIR"

# Function to get CPU usage
get_cpu_usage() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *$$[0-9.]*$$%* id.*/\1/" | awk '{print 100 - $1}')
    printf "%.0f" "$cpu_usage"
}

# Function to get memory usage
get_memory_usage() {
    local mem_info=$(free | grep Mem)
    local total=$(echo "$mem_info" | awk '{print $2}')
    local used=$(echo "$mem_info" | awk '{print $3}')
    local percentage=$((used * 100 / total))
    echo "$percentage"
}

# Function to get temperature
get_temperature() {
    local temp=""
    
    # Try different temperature sources
    if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
        temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        temp=$((temp / 1000))
    elif command -v sensors >/dev/null 2>&1; then
        temp=$(sensors | grep -E "Core 0|Package id 0" | head -1 | grep -o "+[0-9]*" | head -1 | tr -d '+')
    fi
    
    echo "${temp:-0}"
}

# Function to get disk usage
get_disk_usage() {
    df / | awk 'NR==2 {print $5}' | tr -d '%'
}

# Function to get network speed
get_network_speed() {
    local interface=$(ip route | grep default | awk '{print $5}' | head -1)
    
    if [[ -n "$interface" && -f "/sys/class/net/$interface/statistics/rx_bytes" ]]; then
        local rx_bytes=$(cat "/sys/class/net/$interface/statistics/rx_bytes")
        local tx_bytes=$(cat "/sys/class/net/$interface/statistics/tx_bytes")
        
        # Store current values for next calculation
        local prev_file="/tmp/network_${interface}_prev"
        local current_time=$(date +%s)
        
        if [[ -f "$prev_file" ]]; then
            local prev_data=$(cat "$prev_file")
            local prev_rx=$(echo "$prev_data" | cut -d' ' -f1)
            local prev_tx=$(echo "$prev_data" | cut -d' ' -f2)
            local prev_time=$(echo "$prev_data" | cut -d' ' -f3)
            
            local time_diff=$((current_time - prev_time))
            if [[ $time_diff -gt 0 ]]; then
                local rx_speed=$(((rx_bytes - prev_rx) / time_diff))
                local tx_speed=$(((tx_bytes - prev_tx) / time_diff))
                
                # Convert to human readable format
                local rx_human=$(numfmt --to=iec-i --suffix=B/s "$rx_speed")
                local tx_human=$(numfmt --to=iec-i --suffix=B/s "$tx_speed")
                
                echo "↓$rx_human ↑$tx_human"
            fi
        fi
        
        # Store current values
        echo "$rx_bytes $tx_bytes $current_time" > "$prev_file"
    fi
}

# Function to send notification
send_notification() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"
    
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u "$urgency" "$title" "$message"
    fi
}

# Function to check thresholds and notify
check_thresholds() {
    local cpu="$1"
    local mem="$2"
    local temp="$3"
    
    # CPU threshold
    if [[ $cpu -gt $NOTIFY_THRESHOLD_CPU ]]; then
        send_notification "High CPU Usage" "CPU usage is at ${cpu}%" "critical"
    fi
    
    # Memory threshold
    if [[ $mem -gt $NOTIFY_THRESHOLD_MEM ]]; then
        send_notification "High Memory Usage" "Memory usage is at ${mem}%" "critical"
    fi
    
    # Temperature threshold
    if [[ $temp -gt $NOTIFY_THRESHOLD_TEMP ]]; then
        send_notification "High Temperature" "CPU temperature is at ${temp}°C" "critical"
    fi
}

# Function to get color based on value and thresholds
get_color() {
    local value="$1"
    local warning_threshold="$2"
    local critical_threshold="$3"
    
    if [[ $value -gt $critical_threshold ]]; then
        echo "$COLOR_CRITICAL"
    elif [[ $value -gt $warning_threshold ]]; then
        echo "$COLOR_WARNING"
    else
        echo "$COLOR_NORMAL"
    fi
}

# Function to format output
format_output() {
    local cpu="$1"
    local mem="$2"
    local temp="$3"
    local disk="$4"
    local network="$5"
    
    local cpu_color=$(get_color "$cpu" 60 80)
    local mem_color=$(get_color "$mem" 70 85)
    local temp_color=$(get_color "$temp" 60 70)
    local disk_color=$(get_color "$disk" 80 90)
    
    case "${1:-summary}" in
        cpu)
            echo "%{F$cpu_color} ${cpu}%%{F-}"
            ;;
        memory)
            echo "%{F$mem_color} ${mem}%%{F-}"
            ;;
        temperature)
            echo "%{F$temp_color} ${temp}°C%{F-}"
            ;;
        disk)
            echo "%{F$disk_color} ${disk}%%{F-}"
            ;;
        network)
            if [[ -n "$network" ]]; then
                echo " $network"
            else
                echo " N/A"
            fi
            ;;
        summary)
            echo "%{F$cpu_color} ${cpu}%%{F-} %{F$mem_color} ${mem}%%{F-} %{F$temp_color} ${temp}°C%{F-}"
            ;;
        detailed)
            echo "%{F$cpu_color} ${cpu}%%{F-} %{F$mem_color} ${mem}%%{F-} %{F$temp_color} ${temp}°C%{F-} %{F$disk_color} ${disk}%%{F-}"
            ;;
    esac
}

# Function to show detailed system info
show_detailed_info() {
    local info=""
    info+="System Information\n"
    info+="==================\n"
    info+="CPU Usage: $(get_cpu_usage)%\n"
    info+="Memory Usage: $(get_memory_usage)%\n"
    info+="Temperature: $(get_temperature)°C\n"
    info+="Disk Usage: $(get_disk_usage)%\n"
    info+="Load Average: $(uptime | awk -F'load average:' '{print $2}')\n"
    info+="Uptime: $(uptime -p)\n"
    
    if command -v rofi >/dev/null 2>&1; then
        echo -e "$info" | rofi -dmenu -i -p "System Info" \
            -theme-str "window { width: 400px; }" \
            -theme-str "listview { lines: 10; }" \
            -theme "$HOME/.config/rofi/themes/launcher.rasi"
    else
        echo -e "$info"
    fi
}

# Function to check if cache is valid
is_cache_valid() {
    if [[ -f "$CACHE_FILE" ]]; then
        local cache_time=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
        local current_time=$(date +%s)
        local age=$((current_time - cache_time))
        
        if [[ $age -lt $CACHE_DURATION ]]; then
            return 0
        fi
    fi
    return 1
}

# Main function
main() {
    local mode="${1:-summary}"
    
    # Check cache for non-interactive modes
    if [[ "$mode" != "detailed" && "$mode" != "--click" ]] && is_cache_valid; then
        local cached_data=$(cat "$CACHE_FILE")
        format_output $cached_data "$mode"
        return 0
    fi
    
    # Gather system information
    local cpu=$(get_cpu_usage)
    local mem=$(get_memory_usage)
    local temp=$(get_temperature)
    local disk=$(get_disk_usage)
    local network=$(get_network_speed)
    
    # Save to cache
    echo "$cpu $mem $temp $disk $network" > "$CACHE_FILE"
    
    # Check thresholds
    check_thresholds "$cpu" "$mem" "$temp"
    
    # Handle different modes
    case "$mode" in
        --click|--detailed)
            show_detailed_info
            ;;
        *)
            format_output "$cpu" "$mem" "$temp" "$disk" "$network" "$mode"
            ;;
    esac
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "System Monitor Script for Polybar"
        echo "Usage: $0 [mode]"
        echo
        echo "Modes:"
        echo "  summary     Show CPU, Memory, Temperature (default)"
        echo "  detailed    Show all metrics"
        echo "  cpu         Show only CPU usage"
        echo "  memory      Show only memory usage"
        echo "  temperature Show only temperature"
        echo "  disk        Show only disk usage"
        echo "  network     Show only network speed"
        echo "  --click     Show detailed info dialog"
        echo
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
