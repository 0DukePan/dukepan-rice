#!/usr/bin/env bash

# =====================================================
# Modern Notification Center for i3 Rice
# Mobile-style notification management with actions
# =====================================================

set -euo pipefail

# Configuration
CONFIG_DIR="$HOME/.config/notification-center"
CACHE_DIR="$HOME/.cache/notification-center"
LOG_FILE="$CACHE_DIR/notifications.log"
NOTIFICATIONS_FILE="$CACHE_DIR/notifications.json"
HISTORY_FILE="$CACHE_DIR/history.json"

# Notification settings
MAX_NOTIFICATIONS=50
HISTORY_RETENTION_DAYS=7
NOTIFICATION_TIMEOUT=5000
ENABLE_SOUND=true
ENABLE_VIBRATION=false
ENABLE_ACTIONS=true

# Colors (Catppuccin Mocha)
declare -A COLORS=(
    ["background"]="#1e1e2e"
    ["surface"]="#313244"
    ["overlay"]="#6c7086"
    ["text"]="#cdd6f4"
    ["subtext"]="#bac2de"
    ["primary"]="#cba6f7"
    ["success"]="#a6e3a1"
    ["warning"]="#f9e2af"
    ["error"]="#f38ba8"
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
# Notification Center Configuration
ENABLE_NOTIFICATION_CENTER=true
ENABLE_PERSISTENT_NOTIFICATIONS=true
ENABLE_NOTIFICATION_GROUPING=true
ENABLE_DO_NOT_DISTURB=false
ENABLE_PRIORITY_FILTERING=true
MAX_NOTIFICATIONS=50
NOTIFICATION_TIMEOUT=5000
ENABLE_SOUND=true
SOUND_FILE="/usr/share/sounds/freedesktop/stereo/message-new-instant.oga"
ENABLE_ACTIONS=true
ENABLE_RICH_NOTIFICATIONS=true
EOF
    fi
    
    source "$CONFIG_DIR/config"
    
    # Initialize notification files
    if [[ ! -f "$NOTIFICATIONS_FILE" ]]; then
        echo "[]" > "$NOTIFICATIONS_FILE"
    fi
    
    if [[ ! -f "$HISTORY_FILE" ]]; then
        echo "[]" > "$HISTORY_FILE"
    fi
}

# Add notification
add_notification() {
    local app_name="$1"
    local summary="$2"
    local body="$3"
    local urgency="${4:-normal}"
    local icon="${5:-dialog-information}"
    local actions="${6:-}"
    local timeout="${7:-$NOTIFICATION_TIMEOUT}"
    
    local timestamp=$(date +%s)
    local id=$(date +%s%N | cut -b1-13)
    
    # Create notification object
    local notification=$(jq -n \
        --arg id "$id" \
        --arg timestamp "$timestamp" \
        --arg app_name "$app_name" \
        --arg summary "$summary" \
        --arg body "$body" \
        --arg urgency "$urgency" \
        --arg icon "$icon" \
        --arg actions "$actions" \
        --arg timeout "$timeout" \
        --arg read "false" \
        '{
            id: $id,
            timestamp: $timestamp | tonumber,
            app_name: $app_name,
            summary: $summary,
            body: $body,
            urgency: $urgency,
            icon: $icon,
            actions: $actions,
            timeout: $timeout | tonumber,
            read: $read | test("true")
        }')
    
    # Add to notifications
    local notifications=$(cat "$NOTIFICATIONS_FILE")
    echo "$notifications" | jq ". += [$notification]" > "$NOTIFICATIONS_FILE"
    
    # Limit notifications
    echo "$notifications" | jq "if length > $MAX_NOTIFICATIONS then .[1:] else . end" > "$NOTIFICATIONS_FILE"
    
    # Add to history
    local history=$(cat "$HISTORY_FILE")
    echo "$history" | jq ". += [$notification]" > "$HISTORY_FILE"
    
    # Clean old history
    local cutoff=$((timestamp - (HISTORY_RETENTION_DAYS * 86400)))
    echo "$history" | jq "map(select(.timestamp > $cutoff))" > "$HISTORY_FILE"
    
    # Play sound if enabled
    if [[ "$ENABLE_SOUND" == "true" ]] && [[ -n "${SOUND_FILE:-}" ]] && [[ -f "$SOUND_FILE" ]]; then
        paplay "$SOUND_FILE" 2>/dev/null &
    fi
    
    log "Added notification: $app_name - $summary"
    echo "$id"
}

# Mark notification as read
mark_read() {
    local notification_id="$1"
    
    local notifications=$(cat "$NOTIFICATIONS_FILE")
    echo "$notifications" | jq "map(if .id == \"$notification_id\" then .read = true else . end)" > "$NOTIFICATIONS_FILE"
    
    log "Marked notification as read: $notification_id"
}

# Remove notification
remove_notification() {
    local notification_id="$1"
    
    local notifications=$(cat "$NOTIFICATIONS_FILE")
    echo "$notifications" | jq "map(select(.id != \"$notification_id\"))" > "$NOTIFICATIONS_FILE"
    
    log "Removed notification: $notification_id"
}

# Clear all notifications
clear_all() {
    echo "[]" > "$NOTIFICATIONS_FILE"
    log "Cleared all notifications"
}

# Get notification count
get_notification_count() {
    local notifications=$(cat "$NOTIFICATIONS_FILE")
    local total=$(echo "$notifications" | jq 'length')
    local unread=$(echo "$notifications" | jq 'map(select(.read == false)) | length')
    
    echo "$unread/$total"
}

# Format notification for display
format_notification() {
    local notification="$1"
    local format="${2:-full}"
    
    local app_name=$(echo "$notification" | jq -r '.app_name')
    local summary=$(echo "$notification" | jq -r '.summary')
    local body=$(echo "$notification" | jq -r '.body')
    local timestamp=$(echo "$notification" | jq -r '.timestamp')
    local urgency=$(echo "$notification" | jq -r '.urgency')
    local read=$(echo "$notification" | jq -r '.read')
    local id=$(echo "$notification" | jq -r '.id')
    
    # Format timestamp
    local time_str=$(date -d "@$timestamp" '+%H:%M')
    local date_str=$(date -d "@$timestamp" '+%m/%d')
    
    # Choose icon based on urgency
    local urgency_icon=""
    case "$urgency" in
        "critical") urgency_icon="🔴" ;;
        "normal") urgency_icon="🔵" ;;
        "low") urgency_icon="⚪" ;;
    esac
    
    # Read indicator
    local read_indicator=""
    if [[ "$read" == "false" ]]; then
        read_indicator="●"
    else
        read_indicator="○"
    fi
    
    case "$format" in
        "brief")
            echo "$read_indicator $app_name: $summary"
            ;;
        "full")
            echo "$read_indicator $urgency_icon $app_name - $summary"
            if [[ -n "$body" ]] && [[ "$body" != "null" ]]; then
                echo "   $body"
            fi
            echo "   $time_str $date_str | ID: $id"
            ;;
        "rofi")
            local display_text="$read_indicator $app_name: $summary"
            if [[ ${#display_text} -gt 60 ]]; then
                display_text="${display_text:0:57}..."
            fi
            echo "$display_text"
            ;;
    esac
}

# Show notification center
show_notification_center() {
    local notifications=$(cat "$NOTIFICATIONS_FILE")
    local count=$(echo "$notifications" | jq 'length')
    
    if [[ $count -eq 0 ]]; then
        echo "No notifications" | rofi -dmenu -i -p "Notification Center" \
            -theme ~/.config/rofi/themes/notification-center.rasi \
            -mesg "No notifications to display"
        return
    fi
    
    # Create menu options
    local options=""
    local notification_ids=()
    
    # Add header with count
    local unread_count=$(echo "$notifications" | jq 'map(select(.read == false)) | length')
    options+="📱 Notifications ($unread_count unread)\n"
    options+="🗑️ Clear All\n"
    options+="📖 Mark All Read\n"
    options+="📜 Show History\n"
    options+="⚙️ Settings\n"
    options+="---\n"
    
    # Add notifications (newest first)
    echo "$notifications" | jq -r '.[] | @base64' | tac | while read -r notification_b64; do
        local notification=$(echo "$notification_b64" | base64 -d)
        local formatted=$(format_notification "$notification" "rofi")
        local id=$(echo "$notification" | jq -r '.id')
        
        options+="$formatted\n"
        notification_ids+=("$id")
    done
    
    # Show rofi menu
    local chosen=$(echo -e "${options%\\n}" | rofi -dmenu -i -p "Notification Center" \
        -theme ~/.config/rofi/themes/notification-center.rasi \
        -kb-custom-1 "Alt+d" \
        -kb-custom-2 "Alt+r" \
        -kb-custom-3 "Alt+c")
    
    # Handle selection
    case "$chosen" in
        "📱 Notifications"*)
            return
            ;;
        "🗑️ Clear All")
            if confirm_action "Clear all notifications?"; then
                clear_all
                notify-send "Notification Center" "All notifications cleared"
            fi
            ;;
        "📖 Mark All Read")
            mark_all_read
            notify-send "Notification Center" "All notifications marked as read"
            ;;
        "📜 Show History")
            show_history
            ;;
        "⚙️ Settings")
            show_settings
            ;;
        "---"|"")
            return
            ;;
        *)
            # Handle notification selection
            handle_notification_selection "$chosen"
            ;;
    esac
}

# Handle notification selection
handle_notification_selection() {
    local chosen="$1"
    
    # Find the notification by matching the display text
    local notifications=$(cat "$NOTIFICATIONS_FILE")
    local selected_notification=""
    
    echo "$notifications" | jq -r '.[] | @base64' | while read -r notification_b64; do
        local notification=$(echo "$notification_b64" | base64 -d)
        local formatted=$(format_notification "$notification" "rofi")
        
        if [[ "$formatted" == "$chosen" ]]; then
            selected_notification="$notification"
            break
        fi
    done
    
    if [[ -n "$selected_notification" ]]; then
        show_notification_details "$selected_notification"
    fi
}

# Show notification details
show_notification_details() {
    local notification="$1"
    local id=$(echo "$notification" | jq -r '.id')
    local app_name=$(echo "$notification" | jq -r '.app_name')
    local summary=$(echo "$notification" | jq -r '.summary')
    local body=$(echo "$notification" | jq -r '.body')
    local timestamp=$(echo "$notification" | jq -r '.timestamp')
    local actions=$(echo "$notification" | jq -r '.actions')
    
    # Format details
    local details=""
    details+="App: $app_name\n"
    details+="Title: $summary\n"
    if [[ -n "$body" ]] && [[ "$body" != "null" ]]; then
        details+="Message: $body\n"
    fi
    details+="Time: $(date -d "@$timestamp" '+%Y-%m-%d %H:%M:%S')\n"
    details+="---\n"
    details+="📖 Mark as Read\n"
    details+="🗑️ Delete\n"
    details+="↩️ Back"
    
    # Add actions if available
    if [[ -n "$actions" ]] && [[ "$actions" != "null" ]] && [[ "$actions" != "" ]]; then
        details+="\n---\n$actions"
    fi
    
    local chosen=$(echo -e "$details" | rofi -dmenu -i -p "Notification Details" \
        -theme ~/.config/rofi/themes/notification-center.rasi)
    
    case "$chosen" in
        "📖 Mark as Read")
            mark_read "$id"
            show_notification_center
            ;;
        "🗑️ Delete")
            remove_notification "$id"
            show_notification_center
            ;;
        "↩️ Back")
            show_notification_center
            ;;
    esac
}

# Mark all notifications as read
mark_all_read() {
    local notifications=$(cat "$NOTIFICATIONS_FILE")
    echo "$notifications" | jq 'map(.read = true)' > "$NOTIFICATIONS_FILE"
    log "Marked all notifications as read"
}

# Show notification history
show_history() {
    local history=$(cat "$HISTORY_FILE")
    local count=$(echo "$history" | jq 'length')
    
    if [[ $count -eq 0 ]]; then
        echo "No history" | rofi -dmenu -i -p "Notification History" \
            -theme ~/.config/rofi/themes/notification-center.rasi \
            -mesg "No notification history available"
        return
    fi
    
    # Create history display
    local options="📜 Notification History ($count total)\n"
    options+="🗑️ Clear History\n"
    options+="↩️ Back\n"
    options+="---\n"
    
    # Add history items (newest first)
    echo "$history" | jq -r '.[] | @base64' | tac | head -20 | while read -r notification_b64; do
        local notification=$(echo "$notification_b64" | base64 -d)
        local formatted=$(format_notification "$notification" "brief")
        options+="$formatted\n"
    done
    
    local chosen=$(echo -e "${options%\\n}" | rofi -dmenu -i -p "Notification History" \
        -theme ~/.config/rofi/themes/notification-center.rasi)
    
    case "$chosen" in
        "🗑️ Clear History")
            if confirm_action "Clear notification history?"; then
                echo "[]" > "$HISTORY_FILE"
                notify-send "Notification Center" "History cleared"
            fi
            show_history
            ;;
        "↩️ Back")
            show_notification_center
            ;;
    esac
}

# Show settings
show_settings() {
    local options=""
    options+="⚙️ Notification Settings\n"
    options+="🔔 Enable/Disable Notifications\n"
    options+="🔕 Do Not Disturb Mode\n"
    options+="🔊 Sound Settings\n"
    options+="🎨 Theme Settings\n"
    options+="↩️ Back"
    
    local chosen=$(echo -e "$options" | rofi -dmenu -i -p "Settings" \
        -theme ~/.config/rofi/themes/notification-center.rasi)
    
    case "$chosen" in
        "🔔 Enable/Disable Notifications")
            toggle_notifications
            ;;
        "🔕 Do Not Disturb Mode")
            toggle_dnd_mode
            ;;
        "🔊 Sound Settings")
            toggle_sound
            ;;
        "↩️ Back")
            show_notification_center
            ;;
    esac
}

# Toggle notifications
toggle_notifications() {
    if [[ "$ENABLE_NOTIFICATION_CENTER" == "true" ]]; then
        sed -i 's/ENABLE_NOTIFICATION_CENTER=true/ENABLE_NOTIFICATION_CENTER=false/' "$CONFIG_DIR/config"
        notify-send "Notification Center" "Notifications disabled"
    else
        sed -i 's/ENABLE_NOTIFICATION_CENTER=false/ENABLE_NOTIFICATION_CENTER=true/' "$CONFIG_DIR/config"
        notify-send "Notification Center" "Notifications enabled"
    fi
}

# Toggle do not disturb mode
toggle_dnd_mode() {
    if [[ "$ENABLE_DO_NOT_DISTURB" == "true" ]]; then
        sed -i 's/ENABLE_DO_NOT_DISTURB=true/ENABLE_DO_NOT_DISTURB=false/' "$CONFIG_DIR/config"
        notify-send "Notification Center" "Do Not Disturb disabled"
    else
        sed -i 's/ENABLE_DO_NOT_DISTURB=false/ENABLE_DO_NOT_DISTURB=true/' "$CONFIG_DIR/config"
        notify-send "Notification Center" "Do Not Disturb enabled"
    fi
}

# Toggle sound
toggle_sound() {
    if [[ "$ENABLE_SOUND" == "true" ]]; then
        sed -i 's/ENABLE_SOUND=true/ENABLE_SOUND=false/' "$CONFIG_DIR/config"
        notify-send "Notification Center" "Notification sounds disabled"
    else
        sed -i 's/ENABLE_SOUND=false/ENABLE_SOUND=true/' "$CONFIG_DIR/config"
        notify-send "Notification Center" "Notification sounds enabled"
    fi
}

# Confirm action
confirm_action() {
    local message="$1"
    local options="Yes\nNo"
    
    local chosen=$(echo -e "$options" | rofi -dmenu -i -p "$message" \
        -theme ~/.config/rofi/themes/notification-center.rasi)
    
    [[ "$chosen" == "Yes" ]]
}

# Create notification center theme
create_theme() {
    local theme_file="$HOME/.config/rofi/themes/notification-center.rasi"
    mkdir -p "$(dirname "$theme_file")"
    
    cat > "$theme_file" << EOF
* {
    background: ${COLORS[background]};
    background-alt: ${COLORS[surface]};
    foreground: ${COLORS[text]};
    selected: ${COLORS[primary]};
    active: ${COLORS[success]};
    urgent: ${COLORS[error]};
    border: ${COLORS[overlay]};
}

window {
    transparency: "real";
    location: center;
    anchor: center;
    fullscreen: false;
    width: 500px;
    x-offset: 0px;
    y-offset: 0px;
    enabled: true;
    margin: 0px;
    padding: 0px;
    border: 2px solid;
    border-radius: 12px;
    border-color: @border;
    cursor: "default";
    background-color: @background;
}

mainbox {
    enabled: true;
    spacing: 10px;
    margin: 0px;
    padding: 20px;
    border: 0px solid;
    border-radius: 0px;
    border-color: @border;
    background-color: transparent;
    children: [ "inputbar", "message", "listview" ];
}

inputbar {
    enabled: true;
    spacing: 10px;
    margin: 0px;
    padding: 10px;
    border: 0px solid;
    border-radius: 8px;
    border-color: @border;
    background-color: @background-alt;
    text-color: @foreground;
    children: [ "textbox-prompt-colon", "prompt" ];
}

prompt {
    enabled: true;
    background-color: transparent;
    text-color: inherit;
    font: "JetBrainsMono Nerd Font Bold 12";
}

textbox-prompt-colon {
    enabled: true;
    expand: false;
    str: "🔔";
    background-color: transparent;
    text-color: inherit;
    font: "JetBrainsMono Nerd Font 14";
}

message {
    enabled: true;
    margin: 0px;
    padding: 10px;
    border: 0px solid;
    border-radius: 8px;
    border-color: @border;
    background-color: @background-alt;
    text-color: @foreground;
}

textbox {
    background-color: transparent;
    text-color: inherit;
    vertical-align: 0.5;
    horizontal-align: 0.0;
    font: "JetBrainsMono Nerd Font 10";
}

listview {
    enabled: true;
    columns: 1;
    lines: 12;
    cycle: true;
    dynamic: true;
    scrollbar: true;
    layout: vertical;
    reverse: false;
    fixed-height: true;
    fixed-columns: true;
    spacing: 5px;
    margin: 0px;
    padding: 0px;
    border: 0px solid;
    border-radius: 0px;
    border-color: @border;
    background-color: transparent;
    text-color: @foreground;
    cursor: "default";
}

scrollbar {
    width: 4px;
    border: 0px;
    border-radius: 10px;
    background-color: @background-alt;
    handle-color: @selected;
    handle-width: 8px;
    padding: 0px;
}

element {
    enabled: true;
    spacing: 10px;
    margin: 0px;
    padding: 10px;
    border: 0px solid;
    border-radius: 8px;
    border-color: @border;
    background-color: transparent;
    text-color: @foreground;
    cursor: pointer;
}

element normal.normal {
    background-color: transparent;
    text-color: @foreground;
}

element selected.normal {
    background-color: @selected;
    text-color: @background;
}

element alternate.normal {
    background-color: transparent;
    text-color: @foreground;
}

element-text {
    background-color: transparent;
    text-color: inherit;
    highlight: inherit;
    cursor: inherit;
    vertical-align: 0.5;
    horizontal-align: 0.0;
    font: "JetBrainsMono Nerd Font 10";
}

element-icon {
    background-color: transparent;
    text-color: inherit;
    size: 24px;
    cursor: inherit;
}
EOF
}

# Monitor dunst notifications
monitor_dunst() {
    if ! command -v dunstctl &>/dev/null; then
        log "dunstctl not found, cannot monitor notifications"
        return 1
    fi
    
    log "Starting dunst notification monitor..."
    
    # Monitor dunst for new notifications
    dunstctl subscribe | while read -r line; do
        if [[ "$line" =~ "displayed" ]]; then
            # Get the latest notification from dunst
            local notification_info=$(dunstctl history | head -1)
            
            if [[ -n "$notification_info" ]]; then
                # Parse notification (this is simplified)
                local app_name="Unknown"
                local summary="New notification"
                local body=""
                
                # Add to notification center
                add_notification "$app_name" "$summary" "$body" "normal"
            fi
        fi
    done
}

# Get notification status for polybar
get_status() {
    local count=$(get_notification_count)
    local unread=$(echo "$count" | cut -d'/' -f1)
    
    if [[ $unread -gt 0 ]]; then
        echo "🔔 $unread"
    else
        echo "🔔"
    fi
}

# Main function
main() {
    init_system
    create_theme
    
    case "${1:-show}" in
        "show")
            show_notification_center
            ;;
        "add")
            add_notification "${2:-System}" "${3:-Notification}" "${4:-}" "${5:-normal}"
            ;;
        "clear")
            clear_all
            ;;
        "count")
            get_notification_count
            ;;
        "status")
            get_status
            ;;
        "monitor")
            monitor_dunst
            ;;
        "help"|"--help")
            cat << EOF
Notification Center - Modern notification management

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    show        Show notification center (default)
    add         Add notification
    clear       Clear all notifications
    count       Get notification count
    status      Get status for polybar
    monitor     Monitor dunst notifications
    help        Show this help

Examples:
    $0 show                     # Show notification center
    $0 add "App" "Title" "Body" # Add notification
    $0 status                   # Get status for polybar
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
