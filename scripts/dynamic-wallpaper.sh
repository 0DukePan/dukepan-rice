#!/usr/bin/env bash

# =====================================================
# Dynamic Wallpaper System with Pywal Integration
# Intelligent Color Theme Management for i3 Rice
# =====================================================

set -euo pipefail

# Configuration
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
CACHE_DIR="$HOME/.cache/wallpapers"
CONFIG_FILE="$HOME/.config/dynamic-wallpaper/config"
LOG_FILE="$HOME/.cache/dynamic-wallpaper.log"
LOCK_FILE="/tmp/dynamic-wallpaper.lock"

# Color schemes and timing
declare -A TIME_SCHEMES=(
    ["dawn"]="06:00"
    ["morning"]="09:00"
    ["noon"]="12:00"
    ["afternoon"]="15:00"
    ["evening"]="18:00"
    ["night"]="21:00"
    ["midnight"]="00:00"
)

declare -A WEATHER_SCHEMES=(
    ["clear"]="bright sunny"
    ["cloudy"]="moody overcast"
    ["rain"]="dark stormy"
    ["snow"]="white winter"
    ["fog"]="misty atmospheric"
)

# Logging functions
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "$LOG_FILE" >&2
}

# Initialize system
init_system() {
    mkdir -p "$CACHE_DIR" "$(dirname "$CONFIG_FILE")" "$(dirname "$LOG_FILE")"
    
    # Create default config if not exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Dynamic Wallpaper Configuration
ENABLE_TIME_BASED=true
ENABLE_WEATHER_BASED=true
ENABLE_PYWAL=true
ENABLE_ANIMATIONS=true
TRANSITION_DURATION=2
UPDATE_INTERVAL=300
WEATHER_API_KEY=""
LOCATION="auto"
FALLBACK_WALLPAPER="catppuccin-evening-sky.png"
BLUR_STRENGTH=10
ANIMATION_TYPE="fade"
COLOR_TEMPERATURE_ADJUSTMENT=true
ADAPTIVE_BRIGHTNESS=true
NOTIFICATION_ENABLED=true
EOF
    fi
    
    source "$CONFIG_FILE"
}

# Lock mechanism to prevent multiple instances
acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid=$(cat "$LOCK_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log "Another instance is running (PID: $pid)"
            exit 1
        else
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
    trap 'rm -f "$LOCK_FILE"; exit' EXIT INT TERM
}

# Install dependencies if missing
check_dependencies() {
    local deps=("python3-pip" "imagemagick" "jq" "curl" "feh" "nitrogen")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "${dep%%-*}" &> /dev/null && ! dpkg -l | grep -q "$dep"; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "Installing missing dependencies: ${missing_deps[*]}"
        sudo apt update && sudo apt install -y "${missing_deps[@]}"
    fi
    
    # Install pywal if not present
    if ! command -v wal &> /dev/null; then
        log "Installing pywal..."
        pip3 install --user pywal
        export PATH="$HOME/.local/bin:$PATH"
    fi
    
    # Install additional Python packages
    pip3 install --user requests pillow colorthief
}

# Get current weather information
get_weather() {
    local weather_data=""
    local location="$LOCATION"
    
    # Auto-detect location if needed
    if [[ "$location" == "auto" ]]; then
        location=$(curl -s "http://ip-api.com/json/" | jq -r '.city' 2>/dev/null || echo "London")
    fi
    
    # Try multiple weather APIs
    if [[ -n "$WEATHER_API_KEY" ]]; then
        # OpenWeatherMap API
        weather_data=$(curl -s "http://api.openweathermap.org/data/2.5/weather?q=$location&appid=$WEATHER_API_KEY" 2>/dev/null || echo "")
        if [[ -n "$weather_data" ]] && echo "$weather_data" | jq -e '.weather[0].main' &>/dev/null; then
            echo "$weather_data" | jq -r '.weather[0].main' | tr '[:upper:]' '[:lower:]'
            return
        fi
    fi
    
    # Fallback to wttr.in
    weather_data=$(curl -s "wttr.in/$location?format=%C" 2>/dev/null || echo "")
    if [[ -n "$weather_data" ]]; then
        case "$weather_data" in
            *"Clear"*|*"Sunny"*) echo "clear" ;;
            *"Cloud"*|*"Overcast"*) echo "cloudy" ;;
            *"Rain"*|*"Drizzle"*|*"Shower"*) echo "rain" ;;
            *"Snow"*|*"Sleet"*) echo "snow" ;;
            *"Fog"*|*"Mist"*) echo "fog" ;;
            *) echo "clear" ;;
        esac
    else
        echo "clear"
    fi
}

# Get time-based theme
get_time_theme() {
    local current_hour=$(date +%H)
    local current_time=$(date +%H:%M)
    
    # Determine time period
    if [[ "$current_hour" -ge 6 && "$current_hour" -lt 9 ]]; then
        echo "dawn"
    elif [[ "$current_hour" -ge 9 && "$current_hour" -lt 12 ]]; then
        echo "morning"
    elif [[ "$current_hour" -ge 12 && "$current_hour" -lt 15 ]]; then
        echo "noon"
    elif [[ "$current_hour" -ge 15 && "$current_hour" -lt 18 ]]; then
        echo "afternoon"
    elif [[ "$current_hour" -ge 18 && "$current_hour" -lt 21 ]]; then
        echo "evening"
    elif [[ "$current_hour" -ge 21 || "$current_hour" -lt 3 ]]; then
        echo "night"
    else
        echo "midnight"
    fi
}

# Find best matching wallpaper
find_wallpaper() {
    local time_theme="$1"
    local weather_condition="$2"
    local search_terms=()
    
    # Build search terms based on conditions
    if [[ "$ENABLE_TIME_BASED" == "true" ]]; then
        search_terms+=("$time_theme")
    fi
    
    if [[ "$ENABLE_WEATHER_BASED" == "true" ]]; then
        search_terms+=("${WEATHER_SCHEMES[$weather_condition]:-}")
    fi
    
    # Search for wallpapers matching criteria
    local candidates=()
    
    # First, try exact matches
    for term in "${search_terms[@]}"; do
        if [[ -n "$term" ]]; then
            while IFS= read -r -d '' file; do
                candidates+=("$file")
            done < <(find "$WALLPAPER_DIR" -type f $$ -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" $$ -iname "*$term*" -print0 2>/dev/null)
        fi
    done
    
    # If no matches, get all wallpapers
    if [[ ${#candidates[@]} -eq 0 ]]; then
        while IFS= read -r -d '' file; do
            candidates+=("$file")
        done < <(find "$WALLPAPER_DIR" -type f $$ -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" $$ -print0 2>/dev/null)
    fi
    
    # Select random wallpaper from candidates
    if [[ ${#candidates[@]} -gt 0 ]]; then
        local random_index=$((RANDOM % ${#candidates[@]}))
        echo "${candidates[$random_index]}"
    else
        # Fallback wallpaper
        local fallback="$WALLPAPER_DIR/$FALLBACK_WALLPAPER"
        if [[ -f "$fallback" ]]; then
            echo "$fallback"
        else
            log_error "No wallpapers found and fallback doesn't exist"
            return 1
        fi
    fi
}

# Apply color temperature adjustment
adjust_color_temperature() {
    local wallpaper="$1"
    local time_theme="$2"
    local output_file="$CACHE_DIR/$(basename "$wallpaper" .${wallpaper##*.})_adjusted.${wallpaper##*.}"
    
    if [[ "$COLOR_TEMPERATURE_ADJUSTMENT" != "true" ]]; then
        echo "$wallpaper"
        return
    fi
    
    local temperature_adjustment=""
    case "$time_theme" in
        "dawn"|"evening") temperature_adjustment="-modulate 100,110,95" ;;  # Warmer
        "morning"|"afternoon") temperature_adjustment="-modulate 100,105,100" ;;  # Slightly warm
        "noon") temperature_adjustment="-modulate 100,100,105" ;;  # Slightly cool
        "night"|"midnight") temperature_adjustment="-modulate 90,95,90" ;;  # Darker, warmer
    esac
    
    if [[ -n "$temperature_adjustment" ]]; then
        if convert "$wallpaper" $temperature_adjustment "$output_file" 2>/dev/null; then
            echo "$output_file"
        else
            echo "$wallpaper"
        fi
    else
        echo "$wallpaper"
    fi
}

# Apply adaptive brightness
adjust_brightness() {
    local wallpaper="$1"
    local time_theme="$2"
    local output_file="$CACHE_DIR/$(basename "$wallpaper" .${wallpaper##*.})_brightness.${wallpaper##*.}"
    
    if [[ "$ADAPTIVE_BRIGHTNESS" != "true" ]]; then
        echo "$wallpaper"
        return
    fi
    
    local brightness_adjustment=""
    case "$time_theme" in
        "dawn") brightness_adjustment="-brightness-contrast 10x5" ;;
        "morning"|"noon") brightness_adjustment="-brightness-contrast 5x10" ;;
        "afternoon") brightness_adjustment="-brightness-contrast 0x5" ;;
        "evening") brightness_adjustment="-brightness-contrast -5x0" ;;
        "night"|"midnight") brightness_adjustment="-brightness-contrast -15x-5" ;;
    esac
    
    if [[ -n "$brightness_adjustment" ]]; then
        if convert "$wallpaper" $brightness_adjustment "$output_file" 2>/dev/null; then
            echo "$output_file"
        else
            echo "$wallpaper"
        fi
    else
        echo "$wallpaper"
    fi
}

# Generate pywal colors
generate_colors() {
    local wallpaper="$1"
    
    if [[ "$ENABLE_PYWAL" != "true" ]] || ! command -v wal &> /dev/null; then
        return
    fi
    
    log "Generating color scheme from wallpaper..."
    
    # Generate colors with pywal
    wal -i "$wallpaper" -n -q
    
    # Apply colors to various applications
    apply_colors_to_applications
}

# Apply generated colors to applications
apply_colors_to_applications() {
    local colors_file="$HOME/.cache/wal/colors.sh"
    
    if [[ ! -f "$colors_file" ]]; then
        return
    fi
    
    source "$colors_file"
    
    # Update i3 colors
    if [[ -f "$HOME/.config/i3/config" ]]; then
        sed -i "s/set \$bg .*/set \$bg $background/" "$HOME/.config/i3/config"
        sed -i "s/set \$fg .*/set \$fg $foreground/" "$HOME/.config/i3/config"
        sed -i "s/set \$accent .*/set \$accent $color1/" "$HOME/.config/i3/config"
        i3-msg reload &>/dev/null || true
    fi
    
    # Update polybar colors
    if [[ -f "$HOME/.config/polybar/config.ini" ]]; then
        sed -i "s/background = .*/background = $background/" "$HOME/.config/polybar/config.ini"
        sed -i "s/foreground = .*/foreground = $foreground/" "$HOME/.config/polybar/config.ini"
        sed -i "s/primary = .*/primary = $color1/" "$HOME/.config/polybar/config.ini"
        pkill -USR1 polybar &>/dev/null || true
    fi
    
    # Update rofi colors
    if [[ -f "$HOME/.config/rofi/themes/dynamic.rasi" ]]; then
        cat > "$HOME/.config/rofi/themes/dynamic.rasi" << EOF
* {
    background: $background;
    foreground: $foreground;
    accent: $color1;
    urgent: $color9;
    selected: $color2;
}
EOF
    fi
    
    # Update terminal colors
    if [[ -f "$HOME/.config/alacritty/alacritty.toml" ]]; then
        # Create dynamic color scheme for Alacritty
        cat > "$HOME/.config/alacritty/colors-dynamic.toml" << EOF
[colors.primary]
background = "$background"
foreground = "$foreground"

[colors.normal]
black = "$color0"
red = "$color1"
green = "$color2"
yellow = "$color3"
blue = "$color4"
magenta = "$color5"
cyan = "$color6"
white = "$color7"

[colors.bright]
black = "$color8"
red = "$color9"
green = "$color10"
yellow = "$color11"
blue = "$color12"
magenta = "$color13"
cyan = "$color14"
white = "$color15"
EOF
    fi
}

# Set wallpaper with animation
set_wallpaper() {
    local wallpaper="$1"
    local animation_type="${ANIMATION_TYPE:-fade}"
    
    log "Setting wallpaper: $(basename "$wallpaper")"
    
    case "$animation_type" in
        "fade")
            # Create fade transition
            if command -v feh &> /dev/null; then
                feh --bg-fill "$wallpaper" &
            else
                nitrogen --set-zoom-fill "$wallpaper" &
            fi
            ;;
        "slide")
            # Slide transition (requires custom implementation)
            if command -v feh &> /dev/null; then
                feh --bg-fill "$wallpaper" &
            else
                nitrogen --set-zoom-fill "$wallpaper" &
            fi
            ;;
        *)
            # Direct set
            if command -v nitrogen &> /dev/null; then
                nitrogen --set-zoom-fill "$wallpaper"
                nitrogen --save
            elif command -v feh &> /dev/null; then
                feh --bg-fill "$wallpaper"
            fi
            ;;
    esac
    
    # Update wallpaper cache
    echo "$wallpaper" > "$CACHE_DIR/current_wallpaper"
}

# Send notification
send_notification() {
    local title="$1"
    local message="$2"
    local icon="${3:-preferences-desktop-wallpaper}"
    
    if [[ "$NOTIFICATION_ENABLED" == "true" ]] && command -v notify-send &> /dev/null; then
        notify-send -i "$icon" "$title" "$message" -t 3000
    fi
}

# Main wallpaper update function
update_wallpaper() {
    local force_update="${1:-false}"
    
    # Check if update is needed
    if [[ "$force_update" != "true" ]]; then
        local last_update_file="$CACHE_DIR/last_update"
        if [[ -f "$last_update_file" ]]; then
            local last_update=$(cat "$last_update_file")
            local current_time=$(date +%s)
            local time_diff=$((current_time - last_update))
            
            if [[ $time_diff -lt $UPDATE_INTERVAL ]]; then
                log "Update not needed yet (last update: ${time_diff}s ago)"
                return
            fi
        fi
    fi
    
    # Get current conditions
    local time_theme=$(get_time_theme)
    local weather_condition="clear"
    
    if [[ "$ENABLE_WEATHER_BASED" == "true" ]]; then
        weather_condition=$(get_weather)
    fi
    
    log "Current conditions: time=$time_theme, weather=$weather_condition"
    
    # Find appropriate wallpaper
    local wallpaper
    if ! wallpaper=$(find_wallpaper "$time_theme" "$weather_condition"); then
        log_error "Failed to find suitable wallpaper"
        return 1
    fi
    
    # Apply adjustments
    wallpaper=$(adjust_color_temperature "$wallpaper" "$time_theme")
    wallpaper=$(adjust_brightness "$wallpaper" "$time_theme")
    
    # Set wallpaper
    set_wallpaper "$wallpaper"
    
    # Generate color scheme
    if [[ "$ENABLE_PYWAL" == "true" ]]; then
        generate_colors "$wallpaper"
    fi
    
    # Update timestamp
    date +%s > "$CACHE_DIR/last_update"
    
    # Send notification
    send_notification "Wallpaper Updated" "Theme: $time_theme | Weather: $weather_condition"
    
    log "Wallpaper update completed successfully"
}

# Daemon mode
run_daemon() {
    log "Starting dynamic wallpaper daemon..."
    
    while true; do
        update_wallpaper
        sleep "$UPDATE_INTERVAL"
    done
}

# CLI interface
show_help() {
    cat << EOF
Dynamic Wallpaper System - Intelligent Theme Management

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    update          Update wallpaper based on current conditions
    daemon          Run in daemon mode (continuous updates)
    force-update    Force immediate wallpaper update
    status          Show current status and configuration
    config          Edit configuration file
    install         Install and configure the system
    uninstall       Remove the system

Options:
    --help, -h      Show this help message
    --verbose, -v   Enable verbose logging
    --quiet, -q     Suppress output

Examples:
    $0 update                    # Update wallpaper once
    $0 daemon                    # Run continuously
    $0 force-update              # Force immediate update
    $0 status                    # Show current status

Configuration file: $CONFIG_FILE
Log file: $LOG_FILE
EOF
}

# Show current status
show_status() {
    echo "Dynamic Wallpaper System Status"
    echo "==============================="
    echo
    
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        echo "Configuration:"
        echo "  Time-based themes: $ENABLE_TIME_BASED"
        echo "  Weather-based themes: $ENABLE_WEATHER_BASED"
        echo "  Pywal integration: $ENABLE_PYWAL"
        echo "  Animations: $ENABLE_ANIMATIONS"
        echo "  Update interval: ${UPDATE_INTERVAL}s"
        echo
    fi
    
    if [[ -f "$CACHE_DIR/current_wallpaper" ]]; then
        local current_wallpaper=$(cat "$CACHE_DIR/current_wallpaper")
        echo "Current wallpaper: $(basename "$current_wallpaper")"
    fi
    
    if [[ -f "$CACHE_DIR/last_update" ]]; then
        local last_update=$(cat "$CACHE_DIR/last_update")
        local current_time=$(date +%s)
        local time_diff=$((current_time - last_update))
        echo "Last update: ${time_diff}s ago"
    fi
    
    echo
    echo "Current conditions:"
    echo "  Time theme: $(get_time_theme)"
    echo "  Weather: $(get_weather)"
    
    # Check if daemon is running
    if pgrep -f "dynamic-wallpaper.sh daemon" &>/dev/null; then
        echo "  Daemon: Running"
    else
        echo "  Daemon: Not running"
    fi
}

# Install system
install_system() {
    log "Installing dynamic wallpaper system..."
    
    check_dependencies
    init_system
    
    # Create systemd user service
    mkdir -p ~/.config/systemd/user
    cat > ~/.config/systemd/user/dynamic-wallpaper.service << EOF
[Unit]
Description=Dynamic Wallpaper System
After=graphical-session.target

[Service]
Type=simple
ExecStart=$HOME/.local/bin/dynamic-wallpaper.sh daemon
Restart=always
RestartSec=10
Environment=DISPLAY=:0

[Install]
WantedBy=default.target
EOF
    
    # Install script to user bin
    cp "$0" ~/.local/bin/dynamic-wallpaper.sh
    chmod +x ~/.local/bin/dynamic-wallpaper.sh
    
    # Enable and start service
    systemctl --user daemon-reload
    systemctl --user enable dynamic-wallpaper.service
    systemctl --user start dynamic-wallpaper.service
    
    log "Dynamic wallpaper system installed and started"
    send_notification "System Installed" "Dynamic wallpaper system is now active"
}

# Uninstall system
uninstall_system() {
    log "Uninstalling dynamic wallpaper system..."
    
    # Stop and disable service
    systemctl --user stop dynamic-wallpaper.service 2>/dev/null || true
    systemctl --user disable dynamic-wallpaper.service 2>/dev/null || true
    
    # Remove files
    rm -f ~/.config/systemd/user/dynamic-wallpaper.service
    rm -f ~/.local/bin/dynamic-wallpaper.sh
    rm -rf ~/.config/dynamic-wallpaper
    rm -rf ~/.cache/wallpapers
    
    systemctl --user daemon-reload
    
    log "Dynamic wallpaper system uninstalled"
}

# Main function
main() {
    case "${1:-update}" in
        "update")
            init_system
            check_dependencies
            acquire_lock
            update_wallpaper
            ;;
        "force-update")
            init_system
            check_dependencies
            acquire_lock
            update_wallpaper true
            ;;
        "daemon")
            init_system
            check_dependencies
            acquire_lock
            run_daemon
            ;;
        "status")
            init_system
            show_status
            ;;
        "config")
            init_system
            ${EDITOR:-nano} "$CONFIG_FILE"
            ;;
        "install")
            install_system
            ;;
        "uninstall")
            uninstall_system
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            echo "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
