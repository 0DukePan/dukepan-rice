#!/usr/bin/env bash

# =====================================================
# Battery Optimization System for i3 Rice
# Intelligent power management and battery health
# =====================================================

set -euo pipefail

# Configuration
CONFIG_DIR="$HOME/.config/battery-optimizer"
CACHE_DIR="$HOME/.cache/battery-optimizer"
LOG_FILE="$CACHE_DIR/battery-optimizer.log"
PROFILES_DIR="$CONFIG_DIR/profiles"

# Battery thresholds
BATTERY_LOW=20
BATTERY_CRITICAL=10
BATTERY_HIGH=80
BATTERY_FULL=95

# Power profiles
declare -A POWER_PROFILES=(
    ["performance"]="Performance Mode"
    ["balanced"]="Balanced Mode"
    ["power-saver"]="Power Saver Mode"
    ["custom"]="Custom Profile"
)

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Initialize system
init_system() {
    mkdir -p "$CONFIG_DIR" "$CACHE_DIR" "$PROFILES_DIR"
    
    if [[ ! -f "$CONFIG_DIR/config" ]]; then
        cat > "$CONFIG_DIR/config" << 'EOF'
# Battery Optimizer Configuration
ENABLE_AUTO_OPTIMIZATION=true
ENABLE_NOTIFICATIONS=true
ENABLE_ADAPTIVE_BRIGHTNESS=true
ENABLE_CPU_SCALING=true
ENABLE_WIFI_POWER_SAVE=true
AUTO_SUSPEND_ON_LOW=true
AUTO_HIBERNATE_ON_CRITICAL=true
BRIGHTNESS_STEP=10
CPU_GOVERNOR_AC="performance"
CPU_GOVERNOR_BATTERY="powersave"
WIFI_POWER_SAVE_LEVEL=2
EOF
    fi
    
    source "$CONFIG_DIR/config"
    
    # Create default profiles
    create_default_profiles
}

# Create default power profiles
create_default_profiles() {
    # Performance profile
    cat > "$PROFILES_DIR/performance.conf" << 'EOF'
# Performance Profile
CPU_GOVERNOR="performance"
CPU_MIN_FREQ="100%"
CPU_MAX_FREQ="100%"
GPU_POWER_LIMIT="100%"
BRIGHTNESS_LEVEL="100%"
WIFI_POWER_SAVE="off"
BLUETOOTH_POWER_SAVE="off"
USB_AUTOSUSPEND="off"
DISK_APM_LEVEL="254"
SCREEN_TIMEOUT="never"
EOF
    
    # Balanced profile
    cat > "$PROFILES_DIR/balanced.conf" << 'EOF'
# Balanced Profile
CPU_GOVERNOR="ondemand"
CPU_MIN_FREQ="20%"
CPU_MAX_FREQ="100%"
GPU_POWER_LIMIT="80%"
BRIGHTNESS_LEVEL="auto"
WIFI_POWER_SAVE="on"
BLUETOOTH_POWER_SAVE="on"
USB_AUTOSUSPEND="on"
DISK_APM_LEVEL="128"
SCREEN_TIMEOUT="10m"
EOF
    
    # Power saver profile
    cat > "$PROFILES_DIR/power-saver.conf" << 'EOF'
# Power Saver Profile
CPU_GOVERNOR="powersave"
CPU_MIN_FREQ="20%"
CPU_MAX_FREQ="50%"
GPU_POWER_LIMIT="50%"
BRIGHTNESS_LEVEL="30%"
WIFI_POWER_SAVE="on"
BLUETOOTH_POWER_SAVE="on"
USB_AUTOSUSPEND="on"
DISK_APM_LEVEL="1"
SCREEN_TIMEOUT="5m"
EOF
}

# Get battery information
get_battery_info() {
    local battery_path="/sys/class/power_supply/BAT0"
    
    if [[ ! -d "$battery_path" ]]; then
        echo "No battery found"
        return 1
    fi
    
    local capacity=$(cat "$battery_path/capacity" 2>/dev/null || echo "0")
    local status=$(cat "$battery_path/status" 2>/dev/null || echo "Unknown")
    local health=$(cat "$battery_path/health" 2>/dev/null || echo "Unknown")
    local voltage=$(cat "$battery_path/voltage_now" 2>/dev/null || echo "0")
    local current=$(cat "$battery_path/current_now" 2>/dev/null || echo "0")
    
    # Calculate power consumption
    local power=0
    if [[ $voltage -gt 0 ]] && [[ $current -gt 0 ]]; then
        power=$(echo "scale=2; $voltage * $current / 1000000000000" | bc)
    fi
    
    echo "$capacity:$status:$health:$power"
}

# Get AC adapter status
get_ac_status() {
    local ac_path="/sys/class/power_supply/ADP1"
    
    if [[ -f "$ac_path/online" ]]; then
        local online=$(cat "$ac_path/online")
        if [[ "$online" == "1" ]]; then
            echo "connected"
        else
            echo "disconnected"
        fi
    else
        echo "unknown"
    fi
}

# Apply power profile
apply_profile() {
    local profile="$1"
    local profile_file="$PROFILES_DIR/$profile.conf"
    
    if [[ ! -f "$profile_file" ]]; then
        log "Profile not found: $profile"
        return 1
    fi
    
    log "Applying power profile: $profile"
    source "$profile_file"
    
    # Apply CPU governor
    if [[ -n "${CPU_GOVERNOR:-}" ]]; then
        apply_cpu_governor "$CPU_GOVERNOR"
    fi
    
    # Apply CPU frequency scaling
    if [[ -n "${CPU_MIN_FREQ:-}" ]] && [[ -n "${CPU_MAX_FREQ:-}" ]]; then
        apply_cpu_frequency "$CPU_MIN_FREQ" "$CPU_MAX_FREQ"
    fi
    
    # Apply brightness
    if [[ -n "${BRIGHTNESS_LEVEL:-}" ]]; then
        apply_brightness "$BRIGHTNESS_LEVEL"
    fi
    
    # Apply WiFi power save
    if [[ -n "${WIFI_POWER_SAVE:-}" ]]; then
        apply_wifi_power_save "$WIFI_POWER_SAVE"
    fi
    
    # Apply USB autosuspend
    if [[ -n "${USB_AUTOSUSPEND:-}" ]]; then
        apply_usb_autosuspend "$USB_AUTOSUSPEND"
    fi
    
    # Apply disk power management
    if [[ -n "${DISK_APM_LEVEL:-}" ]]; then
        apply_disk_apm "$DISK_APM_LEVEL"
    fi
    
    # Update current profile
    echo "$profile" > "$CACHE_DIR/current_profile"
    
    log "Power profile applied: $profile"
    
    if [[ "$ENABLE_NOTIFICATIONS" == "true" ]] && command -v notify-send &>/dev/null; then
        notify-send -i "battery" "Power Profile" "Applied ${POWER_PROFILES[$profile]}"
    fi
}

# Apply CPU governor
apply_cpu_governor() {
    local governor="$1"
    
    if [[ ! -d "/sys/devices/system/cpu/cpu0/cpufreq" ]]; then
        return
    fi
    
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if [[ -w "$cpu" ]]; then
            echo "$governor" | sudo tee "$cpu" >/dev/null
        fi
    done
    
    log "CPU governor set to: $governor"
}

# Apply CPU frequency scaling
apply_cpu_frequency() {
    local min_freq="$1"
    local max_freq="$2"
    
    # Get available frequencies
    local freq_file="/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies"
    if [[ ! -f "$freq_file" ]]; then
        return
    fi
    
    local frequencies=($(cat "$freq_file"))
    local min_available=${frequencies[0]}
    local max_available=${frequencies[-1]}
    
    # Calculate target frequencies
    local target_min=$min_available
    local target_max=$max_available
    
    if [[ "$min_freq" != "auto" ]]; then
        local min_percent=$(echo "$min_freq" | sed 's/%//')
        target_min=$(echo "scale=0; $min_available + ($max_available - $min_available) * $min_percent / 100" | bc)
    fi
    
    if [[ "$max_freq" != "auto" ]]; then
        local max_percent=$(echo "$max_freq" | sed 's/%//')
        target_max=$(echo "scale=0; $min_available + ($max_available - $min_available) * $max_percent / 100" | bc)
    fi
    
    # Apply frequencies
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_min_freq; do
        if [[ -w "$cpu" ]]; then
            echo "$target_min" | sudo tee "$cpu" >/dev/null
        fi
    done
    
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do
        if [[ -w "$cpu" ]]; then
            echo "$target_max" | sudo tee "$cpu" >/dev/null
        fi
    done
    
    log "CPU frequency range set: $target_min - $target_max"
}

# Apply brightness setting
apply_brightness() {
    local brightness="$1"
    
    if ! command -v brightnessctl &>/dev/null; then
        return
    fi
    
    case "$brightness" in
        "auto")
            # Implement auto brightness based on time of day
            local hour=$(date +%H)
            if (( hour >= 6 && hour < 18 )); then
                brightnessctl set 80%
            else
                brightnessctl set 40%
            fi
            ;;
        *"%")
            brightnessctl set "$brightness"
            ;;
        *)
            brightnessctl set "$brightness%"
            ;;
    esac
    
    log "Brightness set to: $brightness"
}

# Apply WiFi power save
apply_wifi_power_save() {
    local power_save="$1"
    local interface=$(iw dev | awk '$1=="Interface"{print $2}' | head -1)
    
    if [[ -z "$interface" ]]; then
        return
    fi
    
    case "$power_save" in
        "on")
            sudo iw dev "$interface" set power_save on 2>/dev/null || true
            ;;
        "off")
            sudo iw dev "$interface" set power_save off 2>/dev/null || true
            ;;
    esac
    
    log "WiFi power save set to: $power_save"
}

# Apply USB autosuspend
apply_usb_autosuspend() {
    local autosuspend="$1"
    
    case "$autosuspend" in
        "on")
            echo 'auto' | sudo tee /sys/bus/usb/devices/*/power/control >/dev/null 2>&1 || true
            ;;
        "off")
            echo 'on' | sudo tee /sys/bus/usb/devices/*/power/control >/dev/null 2>&1 || true
            ;;
    esac
    
    log "USB autosuspend set to: $autosuspend"
}

# Apply disk APM level
apply_disk_apm() {
    local apm_level="$1"
    
    # Find SATA drives
    for disk in /dev/sd*; do
        if [[ -b "$disk" ]] && [[ ! "$disk" =~ [0-9]$ ]]; then
            sudo hdparm -B "$apm_level" "$disk" >/dev/null 2>&1 || true
        fi
    done
    
    log "Disk APM level set to: $apm_level"
}

# Monitor battery and auto-optimize
monitor_battery() {
    log "Starting battery monitor..."
    
    local last_profile=""
    local last_ac_status=""
    
    while true; do
        local battery_info=$(get_battery_info)
        local ac_status=$(get_ac_status)
        
        if [[ "$battery_info" == "No battery found" ]]; then
            sleep 30
            continue
        fi
        
        IFS=':' read -r capacity status health power <<< "$battery_info"
        
        # Auto-optimize based on AC status
        if [[ "$ENABLE_AUTO_OPTIMIZATION" == "true" ]]; then
            local target_profile=""
            
            if [[ "$ac_status" == "connected" ]]; then
                target_profile="performance"
            else
                if (( capacity <= BATTERY_CRITICAL )); then
                    target_profile="power-saver"
                elif (( capacity <= BATTERY_LOW )); then
                    target_profile="power-saver"
                else
                    target_profile="balanced"
                fi
            fi
            
            if [[ "$target_profile" != "$last_profile" ]]; then
                apply_profile "$target_profile"
                last_profile="$target_profile"
            fi
        fi
        
        # Handle critical battery
        if (( capacity <= BATTERY_CRITICAL )) && [[ "$status" == "Discharging" ]]; then
            if [[ "$AUTO_HIBERNATE_ON_CRITICAL" == "true" ]]; then
                log "Critical battery level, hibernating..."
                systemctl hibernate
            fi
        elif (( capacity <= BATTERY_LOW )) && [[ "$status" == "Discharging" ]]; then
            if [[ "$AUTO_SUSPEND_ON_LOW" == "true" ]]; then
                log "Low battery level, suspending..."
                systemctl suspend
            fi
        fi
        
        # Send notifications
        if [[ "$ENABLE_NOTIFICATIONS" == "true" ]] && command -v notify-send &>/dev/null; then
            if (( capacity <= BATTERY_CRITICAL )) && [[ "$status" == "Discharging" ]]; then
                notify-send -u critical -i "battery-caution" "Critical Battery" "Battery at ${capacity}%"
            elif (( capacity <= BATTERY_LOW )) && [[ "$status" == "Discharging" ]]; then
                notify-send -u normal -i "battery-low" "Low Battery" "Battery at ${capacity}%"
            fi
        fi
        
        last_ac_status="$ac_status"
        sleep 30
    done
}

# Show battery status
show_status() {
    local battery_info=$(get_battery_info)
    local ac_status=$(get_ac_status)
    
    if [[ "$battery_info" == "No battery found" ]]; then
        echo "No battery detected"
        return
    fi
    
    IFS=':' read -r capacity status health power <<< "$battery_info"
    
    echo "Battery Optimizer Status"
    echo "======================="
    echo "Battery Level: ${capacity}%"
    echo "Status: $status"
    echo "Health: $health"
    echo "Power Consumption: ${power}W"
    echo "AC Adapter: $ac_status"
    echo
    
    if [[ -f "$CACHE_DIR/current_profile" ]]; then
        local current_profile=$(cat "$CACHE_DIR/current_profile")
        echo "Current Profile: ${POWER_PROFILES[$current_profile]}"
    fi
    
    echo
    echo "Available Profiles:"
    for profile in "${!POWER_PROFILES[@]}"; do
        echo "  $profile: ${POWER_PROFILES[$profile]}"
    done
}

# Main function
main() {
    init_system
    
    case "${1:-status}" in
        "status")
            show_status
            ;;
        "monitor")
            monitor_battery
            ;;
        "profile")
            if [[ -n "${2:-}" ]]; then
                apply_profile "$2"
            else
                echo "Usage: $0 profile [performance|balanced|power-saver|custom]"
                exit 1
            fi
            ;;
        "auto")
            # Auto-select profile based on current conditions
            local battery_info=$(get_battery_info)
            local ac_status=$(get_ac_status)
            
            if [[ "$ac_status" == "connected" ]]; then
                apply_profile "performance"
            else
                IFS=':' read -r capacity status health power <<< "$battery_info"
                if (( capacity <= BATTERY_LOW )); then
                    apply_profile "power-saver"
                else
                    apply_profile "balanced"
                fi
            fi
            ;;
        "help"|"--help")
            cat << EOF
Battery Optimizer - Intelligent Power Management

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    status      Show battery and power status
    monitor     Start battery monitoring daemon
    profile     Apply specific power profile
    auto        Auto-select optimal profile
    help        Show this help

Profiles:
    performance - Maximum performance (AC recommended)
    balanced    - Balance between performance and battery
    power-saver - Maximum battery life
    custom      - User-defined profile

Examples:
    $0 status               # Show current status
    $0 profile balanced     # Apply balanced profile
    $0 monitor              # Start monitoring daemon
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
