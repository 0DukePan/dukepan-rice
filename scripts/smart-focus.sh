#!/usr/bin/env bash

# =====================================================
# Smart Focus Management for i3
# Intelligent focus follows mouse with context awareness
# =====================================================

set -euo pipefail

# Configuration
CONFIG_FILE="$HOME/.config/smart-focus/config"
CACHE_DIR="$HOME/.cache/smart-focus"
LOG_FILE="$CACHE_DIR/smart-focus.log"

# Default settings
ENABLE_SMART_FOCUS=true
FOCUS_DELAY=150
EXCLUDE_FLOATING=false
EXCLUDE_FULLSCREEN=true
EXCLUDE_CLASSES=("rofi" "dunst" "polybar")
WORKSPACE_AWARE=true
MOUSE_THRESHOLD=5
FOCUS_TIMEOUT=1000

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Initialize system
init_system() {
    mkdir -p "$(dirname "$CONFIG_FILE")" "$CACHE_DIR"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Smart Focus Configuration
ENABLE_SMART_FOCUS=true
FOCUS_DELAY=150
EXCLUDE_FLOATING=false
EXCLUDE_FULLSCREEN=true
EXCLUDE_CLASSES=("rofi" "dunst" "polybar")
WORKSPACE_AWARE=true
MOUSE_THRESHOLD=5
FOCUS_TIMEOUT=1000
EOF
    fi
    
    source "$CONFIG_FILE"
}

# Get window under cursor
get_window_under_cursor() {
    local cursor_info=$(xdotool getmouselocation --shell)
    eval "$cursor_info"
    
    local window_id=$(xdotool getwindowfocus)
    echo "$window_id"
}

# Check if window should be focused
should_focus_window() {
    local window_id="$1"
    
    if [[ "$ENABLE_SMART_FOCUS" != "true" ]]; then
        return 1
    fi
    
    # Get window info from i3
    local window_info=$(i3-msg -t get_tree | jq -r "
        .. | 
        select(.window? == $window_id) | 
        \"\(.window_properties.class // \"unknown\"):\(.floating // \"auto\"):\(.fullscreen_mode // 0)\"")
    
    if [[ -z "$window_info" ]]; then
        return 1
    fi
    
    IFS=':' read -r window_class floating fullscreen <<< "$window_info"
    
    # Check exclusions
    for excluded_class in "${EXCLUDE_CLASSES[@]}"; do
        if [[ "$window_class" =~ $excluded_class ]]; then
            return 1
        fi
    done
    
    # Check floating exclusion
    if [[ "$EXCLUDE_FLOATING" == "true" ]] && [[ "$floating" != "auto" ]]; then
        return 1
    fi
    
    # Check fullscreen exclusion
    if [[ "$EXCLUDE_FULLSCREEN" == "true" ]] && [[ "$fullscreen" != "0" ]]; then
        return 1
    fi
    
    return 0
}

# Focus window with delay
focus_window_delayed() {
    local window_id="$1"
    local delay="$2"
    
    # Kill any existing focus timer
    pkill -f "smart-focus-timer-$window_id" 2>/dev/null || true
    
    # Start new timer
    (
        sleep "$(echo "scale=3; $delay/1000" | bc)"
        
        # Check if mouse is still over window
        local current_window=$(get_window_under_cursor)
        if [[ "$current_window" == "$window_id" ]]; then
            if should_focus_window "$window_id"; then
                i3-msg "[id=\"$window_id\"] focus" &>/dev/null
                log "Focused window: $window_id"
            fi
        fi
    ) &
    
    # Tag the process for identification
    echo $! > "/tmp/smart-focus-timer-$window_id"
}

# Monitor mouse movement
monitor_mouse() {
    log "Starting smart focus monitor..."
    
    local last_window=""
    local last_x=0
    local last_y=0
    
    while true; do
        # Get current cursor position and window
        local cursor_info=$(xdotool getmouselocation --shell)
        eval "$cursor_info"
        
        local current_window=$(xdotool getwindowfocus)
        
        # Calculate mouse movement
        local dx=$((X - last_x))
        local dy=$((Y - last_y))
        local movement=$(echo "sqrt($dx*$dx + $dy*$dy)" | bc -l)
        
        # Check if mouse moved significantly
        if (( $(echo "$movement > $MOUSE_THRESHOLD" | bc -l) )); then
            # Check if window changed
            if [[ "$current_window" != "$last_window" ]]; then
                if should_focus_window "$current_window"; then
                    focus_window_delayed "$current_window" "$FOCUS_DELAY"
                fi
                last_window="$current_window"
            fi
            
            last_x=$X
            last_y=$Y
        fi
        
        sleep 0.05  # 50ms polling interval
    done
}

# Toggle smart focus
toggle_smart_focus() {
    if [[ "$ENABLE_SMART_FOCUS" == "true" ]]; then
        ENABLE_SMART_FOCUS=false
        log "Smart focus disabled"
        
        # Kill any running timers
        pkill -f "smart-focus-timer" 2>/dev/null || true
        
        # Disable i3 focus follows mouse
        i3-msg "focus_follows_mouse no" &>/dev/null
        
        notify-send -t 3000 "Smart Focus" "Disabled"
    else
        ENABLE_SMART_FOCUS=true
        log "Smart focus enabled"
        
        notify-send -t 3000 "Smart Focus" "Enabled"
    fi
    
    # Update config file
    sed -i "s/ENABLE_SMART_FOCUS=.*/ENABLE_SMART_FOCUS=$ENABLE_SMART_FOCUS/" "$CONFIG_FILE"
}

# Show status
show_status() {
    echo "Smart Focus Status"
    echo "=================="
    echo "Enabled: $ENABLE_SMART_FOCUS"
    echo "Focus delay: ${FOCUS_DELAY}ms"
    echo "Exclude floating: $EXCLUDE_FLOATING"
    echo "Exclude fullscreen: $EXCLUDE_FULLSCREEN"
    echo "Excluded classes: ${EXCLUDE_CLASSES[*]}"
    echo "Mouse threshold: ${MOUSE_THRESHOLD}px"
    
    # Show current window info
    local current_window=$(get_window_under_cursor)
    if [[ -n "$current_window" ]]; then
        echo
        echo "Current window: $current_window"
        
        local window_info=$(i3-msg -t get_tree | jq -r "
            .. | 
            select(.window? == $current_window) | 
            \"Class: \(.window_properties.class // \"unknown\"), Title: \(.name // \"untitled\")\"")
        echo "$window_info"
    fi
}

# Main function
main() {
    init_system
    
    case "${1:-monitor}" in
        "monitor"|"--daemon")
            monitor_mouse
            ;;
        "toggle")
            toggle_smart_focus
            ;;
        "status")
            show_status
            ;;
        "focus")
            if [[ -n "${2:-}" ]]; then
                focus_window_delayed "$2" 0
            else
                echo "Usage: $0 focus WINDOW_ID"
                exit 1
            fi
            ;;
        "help"|"--help")
            cat << EOF
Smart Focus Manager

Usage: $0 [COMMAND]

Commands:
    monitor     Start monitoring (default)
    toggle      Toggle smart focus on/off
    status      Show current status
    focus ID    Focus specific window
    help        Show this help

Configuration: $CONFIG_FILE
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
