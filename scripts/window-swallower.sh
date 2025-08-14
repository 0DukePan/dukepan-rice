#!/usr/bin/env bash

# =====================================================
# Smart Window Swallowing for i3
# Hide terminal windows when launching GUI applications
# =====================================================

set -euo pipefail

# Configuration
CONFIG_FILE="$HOME/.config/window-swallowing/config"
CACHE_DIR="$HOME/.cache/window-swallowing"
LOG_FILE="$CACHE_DIR/swallowing.log"
SWALLOW_MAP_FILE="$CACHE_DIR/swallow_map"

# Default configuration
ENABLE_SWALLOWING=true
SWALLOW_TERMINALS=("alacritty" "kitty" "gnome-terminal" "xterm" "urxvt")
SWALLOW_EXCEPTIONS=("vim" "nvim" "emacs" "nano" "htop" "btop" "ranger" "mc")
RESTORE_ON_CLOSE=true
NOTIFICATION_ENABLED=false

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Initialize system
init_system() {
    mkdir -p "$(dirname "$CONFIG_FILE")" "$CACHE_DIR"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Window Swallowing Configuration
ENABLE_SWALLOWING=true
SWALLOW_TERMINALS=("alacritty" "kitty" "gnome-terminal" "xterm" "urxvt")
SWALLOW_EXCEPTIONS=("vim" "nvim" "emacs" "nano" "htop" "btop" "ranger" "mc")
RESTORE_ON_CLOSE=true
NOTIFICATION_ENABLED=false
SWALLOW_DELAY=0.5
AUTO_RESTORE_TIMEOUT=30
EOF
    fi
    
    source "$CONFIG_FILE"
    
    # Initialize swallow map
    touch "$SWALLOW_MAP_FILE"
}

# Check if window should be swallowed
should_swallow() {
    local parent_class="$1"
    local child_class="$2"
    local child_title="$3"
    
    # Check if swallowing is enabled
    if [[ "$ENABLE_SWALLOWING" != "true" ]]; then
        return 1
    fi
    
    # Check if parent is a terminal
    local is_terminal=false
    for terminal in "${SWALLOW_TERMINALS[@]}"; do
        if [[ "$parent_class" =~ $terminal ]]; then
            is_terminal=true
            break
        fi
    done
    
    if [[ "$is_terminal" != "true" ]]; then
        return 1
    fi
    
    # Check exceptions
    for exception in "${SWALLOW_EXCEPTIONS[@]}"; do
        if [[ "$child_class" =~ $exception ]] || [[ "$child_title" =~ $exception ]]; then
            return 1
        fi
    done
    
    return 0
}

# Get window information
get_window_info() {
    local window_id="$1"
    i3-msg -t get_tree | jq -r "
        .. | 
        select(.window? == $window_id) | 
        \"\(.window_properties.class // \"unknown\"):\(.window_properties.instance // \"unknown\"):\(.name // \"untitled\")\""
}

# Get parent window
get_parent_window() {
    local window_id="$1"
    
    # Get process info
    local pid=$(xprop -id "$window_id" _NET_WM_PID 2>/dev/null | cut -d' ' -f3)
    if [[ -z "$pid" ]]; then
        return 1
    fi
    
    # Get parent process
    local ppid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    if [[ -z "$ppid" ]]; then
        return 1
    fi
    
    # Find window with parent PID
    local parent_window=$(xwininfo -root -tree | grep -E "0x[0-9a-f]+" | while read line; do
        local win_id=$(echo "$line" | grep -o "0x[0-9a-f]\+" | head -1)
        local win_pid=$(xprop -id "$win_id" _NET_WM_PID 2>/dev/null | cut -d' ' -f3)
        if [[ "$win_pid" == "$ppid" ]]; then
            echo "$win_id"
            break
        fi
    done)
    
    echo "$parent_window"
}

# Swallow window
swallow_window() {
    local parent_id="$1"
    local child_id="$2"
    
    log "Swallowing: parent=$parent_id, child=$child_id"
    
    # Hide parent window
    i3-msg "[id=\"$parent_id\"] move to scratchpad" &>/dev/null
    
    # Record swallow relationship
    echo "$child_id:$parent_id:$(date +%s)" >> "$SWALLOW_MAP_FILE"
    
    # Send notification if enabled
    if [[ "$NOTIFICATION_ENABLED" == "true" ]] && command -v notify-send &>/dev/null; then
        notify-send -t 2000 "Window Swallowed" "Terminal hidden for GUI application"
    fi
}

# Restore swallowed window
restore_window() {
    local child_id="$1"
    
    # Find parent window
    local parent_info=$(grep "^$child_id:" "$SWALLOW_MAP_FILE" | tail -1)
    if [[ -z "$parent_info" ]]; then
        return 1
    fi
    
    local parent_id=$(echo "$parent_info" | cut -d':' -f2)
    
    log "Restoring: parent=$parent_id, child=$child_id"
    
    # Restore parent window
    i3-msg "[id=\"$parent_id\"] scratchpad show" &>/dev/null
    
    # Remove from swallow map
    sed -i "/^$child_id:/d" "$SWALLOW_MAP_FILE"
    
    # Send notification if enabled
    if [[ "$NOTIFICATION_ENABLED" == "true" ]] && command -v notify-send &>/dev/null; then
        notify-send -t 2000 "Window Restored" "Terminal window restored"
    fi
}

# Monitor window events
monitor_windows() {
    log "Starting window swallowing monitor..."
    
    # Subscribe to i3 window events
    i3-msg -t subscribe -m '["window"]' | while read -r event; do
        local event_type=$(echo "$event" | jq -r '.change')
        local window_id=$(echo "$event" | jq -r '.container.window // empty')
        
        if [[ -z "$window_id" ]] || [[ "$window_id" == "null" ]]; then
            continue
        fi
        
        case "$event_type" in
            "new")
                # New window created
                sleep "${SWALLOW_DELAY:-0.5}"
                
                # Get window info
                local window_info=$(get_window_info "$window_id")
                if [[ -z "$window_info" ]]; then
                    continue
                fi
                
                IFS=':' read -r child_class child_instance child_title <<< "$window_info"
                
                # Get parent window
                local parent_id=$(get_parent_window "$window_id")
                if [[ -z "$parent_id" ]]; then
                    continue
                fi
                
                # Get parent info
                local parent_info=$(get_window_info "$parent_id")
                if [[ -z "$parent_info" ]]; then
                    continue
                fi
                
                IFS=':' read -r parent_class parent_instance parent_title <<< "$parent_info"
                
                # Check if should swallow
                if should_swallow "$parent_class" "$child_class" "$child_title"; then
                    swallow_window "$parent_id" "$window_id"
                fi
                ;;
            "close")
                # Window closed - restore if it was swallowed
                if [[ "$RESTORE_ON_CLOSE" == "true" ]]; then
                    restore_window "$window_id"
                fi
                ;;
        esac
    done
}

# Toggle swallowing
toggle_swallowing() {
    if [[ "$ENABLE_SWALLOWING" == "true" ]]; then
        ENABLE_SWALLOWING=false
        log "Window swallowing disabled"
        notify-send -t 3000 "Window Swallowing" "Disabled"
    else
        ENABLE_SWALLOWING=true
        log "Window swallowing enabled"
        notify-send -t 3000 "Window Swallowing" "Enabled"
    fi
    
    # Update config file
    sed -i "s/ENABLE_SWALLOWING=.*/ENABLE_SWALLOWING=$ENABLE_SWALLOWING/" "$CONFIG_FILE"
}

# Show status
show_status() {
    echo "Window Swallowing Status"
    echo "======================="
    echo "Enabled: $ENABLE_SWALLOWING"
    echo "Terminals: ${SWALLOW_TERMINALS[*]}"
    echo "Exceptions: ${SWALLOW_EXCEPTIONS[*]}"
    echo
    
    if [[ -f "$SWALLOW_MAP_FILE" ]]; then
        local active_swallows=$(wc -l < "$SWALLOW_MAP_FILE")
        echo "Active swallows: $active_swallows"
        
        if [[ $active_swallows -gt 0 ]]; then
            echo "Swallowed windows:"
            while IFS=':' read -r child parent timestamp; do
                echo "  Child: $child, Parent: $parent, Time: $(date -d @$timestamp)"
            done < "$SWALLOW_MAP_FILE"
        fi
    fi
}

# Cleanup old entries
cleanup_swallow_map() {
    if [[ ! -f "$SWALLOW_MAP_FILE" ]]; then
        return
    fi
    
    local temp_file=$(mktemp)
    local current_time=$(date +%s)
    local timeout="${AUTO_RESTORE_TIMEOUT:-30}"
    
    while IFS=':' read -r child parent timestamp; do
        local age=$((current_time - timestamp))
        
        # Check if windows still exist
        if xwininfo -id "$child" &>/dev/null && xwininfo -id "$parent" &>/dev/null; then
            # Keep if within timeout
            if [[ $age -lt $timeout ]]; then
                echo "$child:$parent:$timestamp" >> "$temp_file"
            else
                # Auto-restore old swallows
                restore_window "$child"
            fi
        fi
    done < "$SWALLOW_MAP_FILE"
    
    mv "$temp_file" "$SWALLOW_MAP_FILE"
}

# Main function
main() {
    init_system
    
    case "${1:-monitor}" in
        "monitor"|"--daemon")
            monitor_windows
            ;;
        "toggle")
            toggle_swallowing
            ;;
        "status")
            show_status
            ;;
        "cleanup")
            cleanup_swallow_map
            ;;
        "restore")
            if [[ -n "${2:-}" ]]; then
                restore_window "$2"
            else
                echo "Usage: $0 restore WINDOW_ID"
                exit 1
            fi
            ;;
        "help"|"--help")
            cat << EOF
Window Swallowing Manager

Usage: $0 [COMMAND]

Commands:
    monitor     Start monitoring (default)
    toggle      Toggle swallowing on/off
    status      Show current status
    cleanup     Clean up old entries
    restore ID  Restore specific window
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
