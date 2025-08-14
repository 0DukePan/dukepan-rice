#!/usr/bin/env bash

# =====================================================
# Network Monitor and Management for i3 Rice
# Intelligent network monitoring and optimization
# =====================================================

set -euo pipefail

# Configuration
CONFIG_DIR="$HOME/.config/network-monitor"
CACHE_DIR="$HOME/.cache/network-monitor"
LOG_FILE="$CACHE_DIR/network-monitor.log"
SPEED_HISTORY="$CACHE_DIR/speed_history.json"

# Network thresholds
SPEED_WARNING=1.0  # MB/s
SPEED_CRITICAL=0.1  # MB/s
PING_WARNING=100   # ms
PING_CRITICAL=500  # ms
PACKET_LOSS_WARNING=5  # %
PACKET_LOSS_CRITICAL=20  # %

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Initialize system
init_system() {
    mkdir -p "$CONFIG_DIR" "$CACHE_DIR"
    
    if [[ ! -f "$CONFIG_DIR/config" ]]; then
        cat > "$CONFIG_DIR/config" << 'EOF'
# Network Monitor Configuration
ENABLE_MONITORING=true
ENABLE_NOTIFICATIONS=true
ENABLE_AUTO_RECONNECT=true
ENABLE_VPN_MONITORING=true
MONITOR_INTERVAL=5
PING_HOSTS=("8.8.8.8" "1.1.1.1" "google.com")
SPEED_TEST_INTERVAL=300
AUTO_SWITCH_INTERFACE=true
PREFERRED_INTERFACE_ORDER=("eth0" "wlan0" "enp0s25" "wlp3s0")
EOF
    fi
    
    source "$CONFIG_DIR/config"
    
    # Initialize speed history
    if [[ ! -f "$SPEED_HISTORY" ]]; then
        echo "[]" > "$SPEED_HISTORY"
    fi
}

# Get active network interfaces
get_active_interfaces() {
    ip link show | grep -E "state UP" | awk -F': ' '{print $2}' | grep -v lo
}

# Get interface information
get_interface_info() {
    local interface="$1"
    
    # Get IP address
    local ip=$(ip addr show "$interface" 2>/dev/null | grep -E "inet " | awk '{print $2}' | cut -d'/' -f1 | head -1)
    
    # Get interface type
    local type="unknown"
    if [[ "$interface" =~ ^(eth|enp) ]]; then
        type="ethernet"
    elif [[ "$interface" =~ ^(wlan|wlp) ]]; then
        type="wifi"
    elif [[ "$interface" =~ ^(tun|tap) ]]; then
        type="vpn"
    fi
    
    # Get connection status
    local status="down"
    if ip link show "$interface" | grep -q "state UP"; then
        status="up"
    fi
    
    echo "$ip:$type:$status"
}

# Get network speed
get_network_speed() {
    local interface="$1"
    local duration="${2:-1}"
    
    local rx_file="/sys/class/net/$interface/statistics/rx_bytes"
    local tx_file="/sys/class/net/$interface/statistics/tx_bytes"
    
    if [[ ! -f "$rx_file" ]] || [[ ! -f "$tx_file" ]]; then
        echo "0 0"
        return
    fi
    
    local rx1=$(cat "$rx_file")
    local tx1=$(cat "$tx_file")
    
    sleep "$duration"
    
    local rx2=$(cat "$rx_file")
    local tx2=$(cat "$tx_file")
    
    local rx_speed=$(echo "scale=2; ($rx2 - $rx1) / $duration / 1024 / 1024" | bc)
    local tx_speed=$(echo "scale=2; ($tx2 - $tx1) / $duration / 1024 / 1024" | bc)
    
    echo "$rx_speed $tx_speed"
}

# Test network connectivity
test_connectivity() {
    local host="${1:-8.8.8.8}"
    local count="${2:-3}"
    
    local ping_result=$(ping -c "$count" -W 2 "$host" 2>/dev/null || echo "")
    
    if [[ -z "$ping_result" ]]; then
        echo "unreachable:0:100"
        return
    fi
    
    # Parse ping results
    local avg_time=$(echo "$ping_result" | grep "rtt min/avg/max" | awk -F'/' '{print $5}')
    local packet_loss=$(echo "$ping_result" | grep "packet loss" | awk '{print $6}' | sed 's/%//')
    
    if [[ -z "$avg_time" ]]; then
        avg_time="0"
    fi
    
    if [[ -z "$packet_loss" ]]; then
        packet_loss="100"
    fi
    
    echo "reachable:$avg_time:$packet_loss"
}

# Get WiFi information
get_wifi_info() {
    local interface="$1"
    
    if ! command -v iwconfig &>/dev/null; then
        echo "unknown:0:unknown"
        return
    fi
    
    local wifi_info=$(iwconfig "$interface" 2>/dev/null || echo "")
    
    if [[ -z "$wifi_info" ]]; then
        echo "unknown:0:unknown"
        return
    fi
    
    # Parse WiFi information
    local ssid=$(echo "$wifi_info" | grep -o 'ESSID:"[^"]*"' | cut -d'"' -f2)
    local signal=$(echo "$wifi_info" | grep -o 'Signal level=[^[:space:]]*' | awk -F'=' '{print $2}' | sed 's/dBm//')
    local frequency=$(echo "$wifi_info" | grep -o 'Frequency:[^[:space:]]*' | awk -F':' '{print $2}')
    
    echo "${ssid:-unknown}:${signal:-0}:${frequency:-unknown}"
}

# Get VPN status
get_vpn_status() {
    local vpn_interfaces=$(ip link show | grep -E "(tun|tap)" | awk -F': ' '{print $2}' || echo "")
    
    if [[ -z "$vpn_interfaces" ]]; then
        echo "disconnected:none:0.0.0.0"
        return
    fi
    
    local vpn_interface=$(echo "$vpn_interfaces" | head -1)
    local vpn_ip=$(ip addr show "$vpn_interface" 2>/dev/null | grep -E "inet " | awk '{print $2}' | cut -d'/' -f1 | head -1)
    
    echo "connected:$vpn_interface:${vpn_ip:-0.0.0.0}"
}

# Record network metrics
record_metrics() {
    local timestamp=$(date +%s)
    local active_interfaces=($(get_active_interfaces))
    
    for interface in "${active_interfaces[@]}"; do
        local speed_info=$(get_network_speed "$interface" 1)
        local rx_speed=$(echo "$speed_info" | awk '{print $1}')
        local tx_speed=$(echo "$speed_info" | awk '{print $2}')
        
        # Create metrics object
        local metrics=$(jq -n \
            --arg timestamp "$timestamp" \
            --arg interface "$interface" \
            --arg rx_speed "$rx_speed" \
            --arg tx_speed "$tx_speed" \
            '{
                timestamp: $timestamp | tonumber,
                interface: $interface,
                rx_speed: $rx_speed | tonumber,
                tx_speed: $tx_speed | tonumber
            }')
        
        # Add to history
        local history=$(cat "$SPEED_HISTORY")
        echo "$history" | jq ". += [$metrics]" > "$SPEED_HISTORY"
    done
    
    # Clean old history (keep last 24 hours)
    local cutoff=$((timestamp - 86400))
    local history=$(cat "$SPEED_HISTORY")
    echo "$history" | jq "map(select(.timestamp > $cutoff))" > "$SPEED_HISTORY"
}

# Check network health
check_network_health() {
    local issues=()
    
    # Check connectivity
    for host in "${PING_HOSTS[@]}"; do
        local connectivity=$(test_connectivity "$host" 3)
        IFS=':' read -r status avg_time packet_loss <<< "$connectivity"
        
        if [[ "$status" == "unreachable" ]]; then
            issues+=("Host $host is unreachable")
        elif (( $(echo "$avg_time > $PING_CRITICAL" | bc -l) )); then
            issues+=("High ping to $host: ${avg_time}ms")
        elif (( $(echo "$packet_loss > $PACKET_LOSS_CRITICAL" | bc -l) )); then
            issues+=("High packet loss to $host: ${packet_loss}%")
        fi
    done
    
    # Check interface speeds
    local active_interfaces=($(get_active_interfaces))
    for interface in "${active_interfaces[@]}"; do
        local speed_info=$(get_network_speed "$interface" 2)
        local rx_speed=$(echo "$speed_info" | awk '{print $1}')
        local tx_speed=$(echo "$speed_info" | awk '{print $2}')
        
        if (( $(echo "$rx_speed < $SPEED_CRITICAL && $tx_speed < $SPEED_CRITICAL" | bc -l) )); then
            issues+=("Very low network speed on $interface")
        fi
    done
    
    # Return issues
    if [[ ${#issues[@]} -gt 0 ]]; then
        printf '%s\n' "${issues[@]}"
        return 1
    else
        echo "Network health: OK"
        return 0
    fi
}

# Auto-reconnect network
auto_reconnect() {
    local interface="$1"
    local interface_info=$(get_interface_info "$interface")
    IFS=':' read -r ip type status <<< "$interface_info"
    
    log "Attempting to reconnect $interface..."
    
    case "$type" in
        "wifi")
            # Try to reconnect WiFi
            sudo ip link set "$interface" down
            sleep 2
            sudo ip link set "$interface" up
            sleep 5
            
            # Try to reconnect to known networks
            if command -v nmcli &>/dev/null; then
                nmcli device connect "$interface" || true
            fi
            ;;
        "ethernet")
            # Reset ethernet interface
            sudo ip link set "$interface" down
            sleep 2
            sudo ip link set "$interface" up
            sleep 5
            
            # Request new DHCP lease
            if command -v dhclient &>/dev/null; then
                sudo dhclient "$interface" || true
            fi
            ;;
    esac
    
    log "Reconnection attempt completed for $interface"
}

# Monitor network
monitor_network() {
    log "Starting network monitor..."
    
    local last_check=0
    
    while true; do
        local current_time=$(date +%s)
        
        # Record metrics
        record_metrics
        
        # Check health periodically
        if (( current_time - last_check >= 60 )); then
            if ! check_network_health >/dev/null; then
                log "Network issues detected"
                
                if [[ "$ENABLE_AUTO_RECONNECT" == "true" ]]; then
                    local active_interfaces=($(get_active_interfaces))
                    for interface in "${active_interfaces[@]}"; do
                        auto_reconnect "$interface"
                    done
                fi
                
                if [[ "$ENABLE_NOTIFICATIONS" == "true" ]] && command -v notify-send &>/dev/null; then
                    notify-send -i "network-error" "Network Issues" "Network connectivity problems detected"
                fi
            fi
            
            last_check=$current_time
        fi
        
        sleep "$MONITOR_INTERVAL"
    done
}

# Show network status
show_status() {
    echo "Network Monitor Status"
    echo "====================="
    echo
    
    # Show active interfaces
    echo "Active Interfaces:"
    local active_interfaces=($(get_active_interfaces))
    
    for interface in "${active_interfaces[@]}"; do
        local interface_info=$(get_interface_info "$interface")
        IFS=':' read -r ip type status <<< "$interface_info"
        
        echo "  $interface ($type): $ip"
        
        # Show WiFi details if applicable
        if [[ "$type" == "wifi" ]]; then
            local wifi_info=$(get_wifi_info "$interface")
            IFS=':' read -r ssid signal frequency <<< "$wifi_info"
            echo "    SSID: $ssid, Signal: ${signal}dBm, Frequency: $frequency"
        fi
        
        # Show current speed
        local speed_info=$(get_network_speed "$interface" 1)
        local rx_speed=$(echo "$speed_info" | awk '{print $1}')
        local tx_speed=$(echo "$speed_info" | awk '{print $2}')
        echo "    Speed: ↓${rx_speed}MB/s ↑${tx_speed}MB/s"
    done
    
    echo
    
    # Show VPN status
    local vpn_status=$(get_vpn_status)
    IFS=':' read -r vpn_state vpn_interface vpn_ip <<< "$vpn_status"
    echo "VPN Status: $vpn_state"
    if [[ "$vpn_state" == "connected" ]]; then
        echo "  Interface: $vpn_interface"
        echo "  IP: $vpn_ip"
    fi
    
    echo
    
    # Show connectivity test
    echo "Connectivity Test:"
    for host in "${PING_HOSTS[@]}"; do
        local connectivity=$(test_connectivity "$host" 3)
        IFS=':' read -r status avg_time packet_loss <<< "$connectivity"
        
        if [[ "$status" == "reachable" ]]; then
            echo "  $host: ${avg_time}ms (${packet_loss}% loss)"
        else
            echo "  $host: unreachable"
        fi
    done
}

# Generate network report
generate_report() {
    local output_file="${1:-$HOME/network-report-$(date +%Y%m%d-%H%M%S).txt}"
    
    cat > "$output_file" << EOF
Network Monitor Report
Generated: $(date)
======================

$(show_status)

Network Health Check:
$(check_network_health 2>&1)

Recent Speed History (last hour):
$(cat "$SPEED_HISTORY" | jq -r '.[] | select(.timestamp > (now - 3600)) | "\(.timestamp | strftime("%H:%M:%S")) \(.interface): ↓\(.rx_speed)MB/s ↑\(.tx_speed)MB/s"' | tail -20)

Network Configuration:
$(ip addr show)

Routing Table:
$(ip route show)

DNS Configuration:
$(cat /etc/resolv.conf)
EOF
    
    echo "Network report generated: $output_file"
}

# Main function
main() {
    init_system
    
    case "${1:-status}" in
        "status")
            show_status
            ;;
        "monitor")
            monitor_network
            ;;
        "health")
            check_network_health
            ;;
        "reconnect")
            if [[ -n "${2:-}" ]]; then
                auto_reconnect "$2"
            else
                echo "Usage: $0 reconnect INTERFACE"
                exit 1
            fi
            ;;
        "report")
            generate_report "${2:-}"
            ;;
        "speed")
            local interface="${2:-$(get_active_interfaces | head -1)}"
            if [[ -n "$interface" ]]; then
                echo "Testing speed on $interface..."
                local speed_info=$(get_network_speed "$interface" 5)
                local rx_speed=$(echo "$speed_info" | awk '{print $1}')
                local tx_speed=$(echo "$speed_info" | awk '{print $2}')
                echo "Download: ${rx_speed} MB/s"
                echo "Upload: ${tx_speed} MB/s"
            else
                echo "No active network interface found"
            fi
            ;;
        "help"|"--help")
            cat << EOF
Network Monitor - Intelligent Network Management

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    status      Show network status (default)
    monitor     Start network monitoring daemon
    health      Check network health
    reconnect   Reconnect specific interface
    report      Generate network report
    speed       Test network speed
    help        Show this help

Examples:
    $0 status               # Show current network status
    $0 monitor              # Start monitoring daemon
    $0 reconnect wlan0      # Reconnect WiFi interface
    $0 speed eth0           # Test speed on ethernet
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
