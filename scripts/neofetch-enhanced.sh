#!/usr/bin/env bash

# =====================================================
# Enhanced Neofetch Script for Pop!_OS i3 Rice
# Adds dynamic information and beautiful formatting
# =====================================================

set -euo pipefail

# Colors (Catppuccin Mocha)
readonly ROSEWATER='\033[38;2;245;224;220m'
readonly FLAMINGO='\033[38;2;242;205;205m'
readonly PINK='\033[38;2;245;194;231m'
readonly MAUVE='\033[38;2;203;166;247m'
readonly RED='\033[38;2;243;139;168m'
readonly MAROON='\033[38;2;235;160;172m'
readonly PEACH='\033[38;2;250;179;135m'
readonly YELLOW='\033[38;2;249;226;175m'
readonly GREEN='\033[38;2;166;227;161m'
readonly TEAL='\033[38;2;148;226;213m'
readonly SKY='\033[38;2;137;220;235m'
readonly SAPPHIRE='\033[38;2;116;199;236m'
readonly BLUE='\033[38;2;137;180;250m'
readonly LAVENDER='\033[38;2;180;190;254m'
readonly TEXT='\033[38;2;205;214;244m'
readonly SUBTEXT1='\033[38;2;186;194;222m'
readonly RESET='\033[0m'

# Configuration
readonly CONFIG_DIR="$HOME/.config/neofetch"
readonly CACHE_DIR="$HOME/.cache/neofetch"
readonly LOG_FILE="$CACHE_DIR/neofetch.log"

# Create directories
mkdir -p "$CONFIG_DIR" "$CACHE_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Enhanced system information gathering
get_enhanced_info() {
    local info_file="$CACHE_DIR/system_info.json"
    
    # Gather comprehensive system information
    {
        echo "{"
        echo "  \"timestamp\": \"$(date -Iseconds)\","
        echo "  \"uptime_seconds\": $(cat /proc/uptime | cut -d' ' -f1),"
        echo "  \"load_average\": \"$(cat /proc/loadavg | cut -d' ' -f1-3)\","
        echo "  \"cpu_count\": $(nproc),"
        echo "  \"memory_total\": $(grep MemTotal /proc/meminfo | awk '{print $2}'),"
        echo "  \"memory_available\": $(grep MemAvailable /proc/meminfo | awk '{print $2}'),"
        echo "  \"disk_usage\": \"$(df -h / | tail -1 | awk '{print $5}')\","
        echo "  \"network_interface\": \"$(ip route | grep default | awk '{print $5}' | head -1)\","
        
        # GPU information
        if command -v nvidia-smi >/dev/null 2>&1; then
            echo "  \"gpu_temp\": \"$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)\","
            echo "  \"gpu_usage\": \"$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits)\","
        fi
        
        # Battery information
        if [[ -d "/sys/class/power_supply/BAT0" ]]; then
            echo "  \"battery_capacity\": \"$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 'N/A')\","
            echo "  \"battery_status\": \"$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo 'N/A')\","
        fi
        
        # i3 workspace information
        if command -v i3-msg >/dev/null 2>&1; then
            echo "  \"i3_workspaces\": $(i3-msg -t get_workspaces | jq -c '[.[] | {name: .name, focused: .focused}]'),"
            echo "  \"i3_windows\": $(i3-msg -t get_tree | jq '[.. | objects | select(.window_type=="normal")] | length'),"
        fi
        
        echo "  \"end\": true"
        echo "}"
    } > "$info_file"
    
    log "Enhanced system information gathered"
}

# Create dynamic ASCII art based on system status
create_dynamic_ascii() {
    local ascii_file="$CACHE_DIR/dynamic_ascii.txt"
    local battery_level=100
    
    # Get battery level if available
    if [[ -f "/sys/class/power_supply/BAT0/capacity" ]]; then
        battery_level=$(cat /sys/class/power_supply/BAT0/capacity)
    fi
    
    # Create ASCII art with battery indicator
    {
        echo "${MAUVE}             //////////////"
        echo "${MAUVE}         /////////////////////  ${YELLOW}Battery: ${battery_level}%"
        echo "${MAUVE}      ///////${PEACH}*767${MAUVE}////////////////"
        echo "${MAUVE}    //////${PEACH}7676767676*${MAUVE}//////////////"
        echo "${MAUVE}   /////${PEACH}767676767676767${MAUVE}////////////"
        echo "${MAUVE}  /////${PEACH}76767676767676767${MAUVE}///////////"
        echo "${MAUVE} //////${PEACH}767676767676767676${MAUVE}//////////"
        echo "${MAUVE}////////${PEACH}76767676767676767${MAUVE}/////////"
        echo "${MAUVE}//////////${PEACH}7676767676767${MAUVE}/////////"
        echo "${MAUVE}///////////${PEACH}76767676767${MAUVE}////////"
        echo "${MAUVE}////////////${PEACH}767676767${MAUVE}///////"
        echo "${MAUVE}//////////////${PEACH}76767${MAUVE}/////"
        echo "${MAUVE}///////////////${PEACH}767${MAUVE}///"
        echo "${MAUVE}////////////////${PEACH}7${MAUVE}//"
        echo "${MAUVE}/////////////////"
        echo "${RESET}"
    } > "$ascii_file"
    
    log "Dynamic ASCII art created"
}

# Performance monitoring
monitor_performance() {
    local perf_file="$CACHE_DIR/performance.log"
    
    {
        echo "=== Performance Monitor - $(date) ==="
        echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
        echo "Memory Usage: $(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')"
        echo "Load Average: $(cat /proc/loadavg | cut -d' ' -f1-3)"
        echo "Disk I/O: $(iostat -d 1 1 | tail -n +4 | awk '{print $4 " " $5}' | head -1)"
        echo "Network: $(cat /proc/net/dev | grep $(ip route | grep default | awk '{print $5}' | head -1) | awk '{print $2 " " $10}')"
        echo ""
    } >> "$perf_file"
    
    # Keep only last 100 entries
    tail -n 500 "$perf_file" > "$perf_file.tmp" && mv "$perf_file.tmp" "$perf_file"
    
    log "Performance data logged"
}

# Weather integration
get_weather_info() {
    local weather_file="$CACHE_DIR/weather.json"
    local weather_cache_time=1800  # 30 minutes
    
    # Check if cache is still valid
    if [[ -f "$weather_file" ]] && [[ $(($(date +%s) - $(stat -c %Y "$weather_file"))) -lt $weather_cache_time ]]; then
        return 0
    fi
    
    # Get weather data
    if command -v curl >/dev/null 2>&1; then
        curl -s "wttr.in/?format=j1" > "$weather_file" 2>/dev/null || {
            log "Failed to fetch weather data"
            return 1
        }
        log "Weather data updated"
    fi
}

# System health check
health_check() {
    local health_file="$CACHE_DIR/health_status.txt"
    local warnings=()
    
    # Check disk space
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $disk_usage -gt 90 ]]; then
        warnings+=("High disk usage: ${disk_usage}%")
    fi
    
    # Check memory usage
    local mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    if [[ $mem_usage -gt 90 ]]; then
        warnings+=("High memory usage: ${mem_usage}%")
    fi
    
    # Check CPU temperature
    if [[ -f "/sys/class/thermal/thermal_zone0/temp" ]]; then
        local cpu_temp=$(($(cat /sys/class/thermal/thermal_zone0/temp) / 1000))
        if [[ $cpu_temp -gt 80 ]]; then
            warnings+=("High CPU temperature: ${cpu_temp}°C")
        fi
    fi
    
    # Check load average
    local load_avg=$(cat /proc/loadavg | cut -d' ' -f1)
    local cpu_count=$(nproc)
    if (( $(echo "$load_avg > $cpu_count * 2" | bc -l) )); then
        warnings+=("High system load: $load_avg")
    fi
    
    # Write health status
    {
        echo "=== System Health Check - $(date) ==="
        if [[ ${#warnings[@]} -eq 0 ]]; then
            echo "${GREEN}✓ All systems normal${RESET}"
        else
            echo "${RED}⚠ Warnings detected:${RESET}"
            printf '%s\n' "${warnings[@]}"
        fi
        echo ""
    } > "$health_file"
    
    log "Health check completed with ${#warnings[@]} warnings"
}

# Main execution
main() {
    log "Starting enhanced neofetch"
    
    # Gather system information
    get_enhanced_info
    
    # Create dynamic ASCII
    create_dynamic_ascii
    
    # Monitor performance
    monitor_performance
    
    # Get weather (background)
    get_weather_info &
    
    # Health check
    health_check
    
    # Run neofetch with custom config
    if [[ -f "$CONFIG_DIR/config.conf" ]]; then
        neofetch --config "$CONFIG_DIR/config.conf"
    else
        neofetch
    fi
    
    # Display additional information
    echo ""
    echo "${LAVENDER}╭─────────────────────────────────────────╮${RESET}"
    echo "${LAVENDER}│${RESET}           ${MAUVE}System Status${RESET}                ${LAVENDER}│${RESET}"
    echo "${LAVENDER}├─────────────────────────────────────────┤${RESET}"
    
    # Display health status
    if [[ -f "$CACHE_DIR/health_status.txt" ]]; then
        cat "$CACHE_DIR/health_status.txt" | head -5
    fi
    
    echo "${LAVENDER}╰─────────────────────────────────────────╯${RESET}"
    
    log "Enhanced neofetch completed"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
