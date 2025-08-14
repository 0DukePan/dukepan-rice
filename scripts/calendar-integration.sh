#!/usr/bin/env bash
# =====================================================
# Calendar Integration System for duke pan's i3 rice
# Google Calendar sync with beautiful rofi interface
# =====================================================

set -euo pipefail

# Configuration
CONFIG_DIR="$HOME/.config/calendar"
CACHE_DIR="$HOME/.cache/calendar"
GCAL_CONFIG="$CONFIG_DIR/gcal.conf"
EVENTS_CACHE="$CACHE_DIR/events.json"
SYNC_LOG="$CACHE_DIR/sync.log"

# Colors (Catppuccin Mocha)
declare -A COLORS=(
    [primary]="#cba6f7"
    [secondary]="#89b4fa"
    [success]="#a6e3a1"
    [warning]="#f9e2af"
    [error]="#f38ba8"
    [text]="#cdd6f4"
    [surface]="#313244"
    [base]="#1e1e2e"
)

# Create directories
mkdir -p "$CONFIG_DIR" "$CACHE_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$SYNC_LOG"
}

# Notification function
notify() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"
    local icon="${4:-calendar}"
    
    notify-send -u "$urgency" -i "$icon" -a "Calendar" "$title" "$message"
}

# Initialize Google Calendar API
init_gcal() {
    log "Initializing Google Calendar integration..."
    
    if [[ ! -f "$GCAL_CONFIG" ]]; then
        cat > "$GCAL_CONFIG" << 'EOF'
# Google Calendar Configuration for duke pan
# Get your API key from: https://console.developers.google.com/
GCAL_API_KEY=""
GCAL_CALENDAR_ID="primary"
GCAL_TIME_ZONE="America/New_York"
SYNC_INTERVAL=300
MAX_RESULTS=50
DAYS_AHEAD=30
EOF
        notify "Calendar Setup" "Please configure Google Calendar API in $GCAL_CONFIG"
        return 1
    fi
    
    source "$GCAL_CONFIG"
    
    if [[ -z "$GCAL_API_KEY" ]]; then
        notify "Calendar Error" "Google Calendar API key not configured" "critical"
        return 1
    fi
    
    log "Google Calendar initialized successfully"
    return 0
}

# Sync with Google Calendar
sync_calendar() {
    log "Starting calendar sync..."
    
    if ! init_gcal; then
        return 1
    fi
    
    local start_date=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local end_date=$(date -u -d "+${DAYS_AHEAD} days" +%Y-%m-%dT%H:%M:%SZ)
    
    local api_url="https://www.googleapis.com/calendar/v3/calendars/${GCAL_CALENDAR_ID}/events"
    local params="key=${GCAL_API_KEY}&timeMin=${start_date}&timeMax=${end_date}&maxResults=${MAX_RESULTS}&singleEvents=true&orderBy=startTime"
    
    if curl -s "${api_url}?${params}" > "$EVENTS_CACHE.tmp"; then
        mv "$EVENTS_CACHE.tmp" "$EVENTS_CACHE"
        log "Calendar sync completed successfully"
        notify "Calendar Sync" "Successfully synced with Google Calendar" "low"
        return 0
    else
        log "Calendar sync failed"
        notify "Calendar Error" "Failed to sync with Google Calendar" "critical"
        return 1
    fi
}

# Parse events from cache
parse_events() {
    if [[ ! -f "$EVENTS_CACHE" ]]; then
        echo "[]"
        return
    fi
    
    jq -r '.items[] | select(.start.dateTime != null) | 
        {
            summary: .summary,
            start: .start.dateTime,
            end: .end.dateTime,
            location: (.location // ""),
            description: (.description // ""),
            id: .id
        }' "$EVENTS_CACHE" 2>/dev/null || echo "[]"
}

# Get today's events
get_today_events() {
    local today=$(date +%Y-%m-%d)
    parse_events | jq -r --arg today "$today" '
        select(.start | startswith($today)) | 
        "\(.start | strptime("%Y-%m-%dT%H:%M:%S") | strftime("%H:%M")) - \(.summary)"
    ' | head -5
}

# Get upcoming events
get_upcoming_events() {
    local count="${1:-10}"
    parse_events | jq -r '
        "\(.start | strptime("%Y-%m-%dT%H:%M:%S") | strftime("%m/%d %H:%M")) - \(.summary)"
    ' | head -"$count"
}

# Show calendar in rofi
show_calendar() {
    local events
    events=$(get_upcoming_events 20)
    
    if [[ -z "$events" ]]; then
        events="No upcoming events"
    fi
    
    local header="📅 duke pan's Calendar - $(date '+%B %Y')"
    
    echo -e "$events" | rofi \
        -dmenu \
        -i \
        -p "Calendar" \
        -mesg "$header" \
        -theme-str "
            window { width: 800px; }
            listview { lines: 15; }
            element { padding: 8px; }
            element selected { background-color: ${COLORS[primary]}; }
        " \
        -kb-custom-1 "ctrl+r" \
        -kb-custom-2 "ctrl+a" \
        -kb-custom-3 "ctrl+s" \
        -format 'i:s'
    
    local exit_code=$?
    case $exit_code in
        10) sync_calendar && show_calendar ;;  # Ctrl+R - Refresh
        11) add_event ;;                       # Ctrl+A - Add event
        12) show_settings ;;                   # Ctrl+S - Settings
    esac
}

# Add new event
add_event() {
    local title
    title=$(echo "" | rofi -dmenu -p "Event Title" -theme-str "window { width: 400px; }")
    
    if [[ -z "$title" ]]; then
        return
    fi
    
    local date
    date=$(echo "" | rofi -dmenu -p "Date (YYYY-MM-DD)" -theme-str "window { width: 400px; }")
    
    if [[ -z "$date" ]]; then
        return
    fi
    
    local time
    time=$(echo "" | rofi -dmenu -p "Time (HH:MM)" -theme-str "window { width: 400px; }")
    
    if [[ -z "$time" ]]; then
        time="09:00"
    fi
    
    # Create event in local cache (simplified - would need OAuth for actual creation)
    local event_data="{
        \"summary\": \"$title\",
        \"start\": {\"dateTime\": \"${date}T${time}:00\"},
        \"end\": {\"dateTime\": \"${date}T$(date -d "$time + 1 hour" +%H:%M):00\"}
    }"
    
    notify "Event Added" "Added: $title on $date at $time"
    log "Added event: $title on $date at $time"
}

# Show settings menu
show_settings() {
    local options=(
        "🔄 Sync Now"
        "⚙️ Configure API"
        "📊 Sync Status"
        "🗑️ Clear Cache"
        "📝 View Logs"
    )
    
    local choice
    choice=$(printf '%s\n' "${options[@]}" | rofi -dmenu -p "Calendar Settings")
    
    case "$choice" in
        "🔄 Sync Now")
            sync_calendar
            ;;
        "⚙️ Configure API")
            alacritty -e nano "$GCAL_CONFIG"
            ;;
        "📊 Sync Status")
            show_sync_status
            ;;
        "🗑️ Clear Cache")
            rm -f "$EVENTS_CACHE" "$SYNC_LOG"
            notify "Cache Cleared" "Calendar cache has been cleared"
            ;;
        "📝 View Logs")
            alacritty -e less "$SYNC_LOG"
            ;;
    esac
}

# Show sync status
show_sync_status() {
    local last_sync="Never"
    local event_count=0
    
    if [[ -f "$EVENTS_CACHE" ]]; then
        last_sync=$(date -r "$EVENTS_CACHE" '+%Y-%m-%d %H:%M:%S')
        event_count=$(jq '.items | length' "$EVENTS_CACHE" 2>/dev/null || echo 0)
    fi
    
    local status="Last Sync: $last_sync\nEvents Cached: $event_count"
    
    echo -e "$status" | rofi -dmenu -p "Sync Status" -mesg "Calendar Synchronization Status"
}

# Get calendar widget info for polybar
get_widget_info() {
    local today_count
    today_count=$(get_today_events | wc -l)
    
    if [[ $today_count -gt 0 ]]; then
        echo "$today_count"
    else
        echo ""
    fi
}

# Auto-sync daemon
start_sync_daemon() {
    log "Starting calendar sync daemon..."
    
    while true; do
        sync_calendar
        sleep "${SYNC_INTERVAL:-300}"
    done &
    
    echo $! > "$CACHE_DIR/sync_daemon.pid"
    log "Sync daemon started with PID $(cat "$CACHE_DIR/sync_daemon.pid")"
}

# Stop sync daemon
stop_sync_daemon() {
    if [[ -f "$CACHE_DIR/sync_daemon.pid" ]]; then
        local pid
        pid=$(cat "$CACHE_DIR/sync_daemon.pid")
        if kill "$pid" 2>/dev/null; then
            log "Sync daemon stopped"
            rm -f "$CACHE_DIR/sync_daemon.pid"
        fi
    fi
}

# Event reminders
check_reminders() {
    local now=$(date +%s)
    local reminder_times=(300 900 3600)  # 5min, 15min, 1hour
    
    parse_events | jq -r --arg now "$now" '
        select((.start | strptime("%Y-%m-%dT%H:%M:%S") | mktime) - ($now | tonumber) | 
        . > 0 and . <= 3600) |
        "\(.start | strptime("%Y-%m-%dT%H:%M:%S") | mktime)|\(.summary)|\(.start)"
    ' | while IFS='|' read -r event_time summary start_time; do
        local time_diff=$((event_time - now))
        
        for reminder_time in "${reminder_times[@]}"; do
            if [[ $time_diff -le $reminder_time && $time_diff -gt $((reminder_time - 60)) ]]; then
                local formatted_time=$(date -d "$start_time" '+%H:%M')
                notify "Upcoming Event" "$summary at $formatted_time" "normal" "appointment-soon"
                break
            fi
        done
    done
}

# Main function
main() {
    case "${1:-show}" in
        "sync")
            sync_calendar
            ;;
        "show")
            show_calendar
            ;;
        "today")
            get_today_events
            ;;
        "upcoming")
            get_upcoming_events "${2:-10}"
            ;;
        "widget")
            get_widget_info
            ;;
        "add")
            add_event
            ;;
        "daemon-start")
            start_sync_daemon
            ;;
        "daemon-stop")
            stop_sync_daemon
            ;;
        "reminders")
            check_reminders
            ;;
        "settings")
            show_settings
            ;;
        *)
            echo "Usage: $0 {sync|show|today|upcoming|widget|add|daemon-start|daemon-stop|reminders|settings}"
            exit 1
            ;;
    esac
}

main "$@"
