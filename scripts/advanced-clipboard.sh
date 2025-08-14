#!/usr/bin/env bash

# =====================================================
# Advanced Clipboard Manager for i3 Rice
# Intelligent clipboard with search, categories, and sync
# =====================================================

set -euo pipefail

# Configuration
CONFIG_DIR="$HOME/.config/advanced-clipboard"
CACHE_DIR="$HOME/.cache/advanced-clipboard"
LOG_FILE="$CACHE_DIR/clipboard.log"
CLIPBOARD_FILE="$CACHE_DIR/clipboard.json"
FAVORITES_FILE="$CACHE_DIR/favorites.json"

# Settings
MAX_ENTRIES=100
MAX_ENTRY_LENGTH=1000
ENABLE_IMAGES=true
ENABLE_SYNC=false
ENABLE_ENCRYPTION=false
MONITOR_INTERVAL=1

# Categories
declare -A CATEGORIES=(
    ["text"]="📝"
    ["url"]="🔗"
    ["email"]="📧"
    ["phone"]="📞"
    ["code"]="💻"
    ["password"]="🔒"
    ["image"]="🖼️"
    ["file"]="📁"
    ["other"]="📋"
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
# Advanced Clipboard Configuration
ENABLE_CLIPBOARD_MANAGER=true
ENABLE_HISTORY=true
ENABLE_SEARCH=true
ENABLE_CATEGORIES=true
ENABLE_FAVORITES=true
ENABLE_IMAGES=true
ENABLE_SYNC=false
ENABLE_ENCRYPTION=false
MAX_ENTRIES=100
MAX_ENTRY_LENGTH=1000
MONITOR_INTERVAL=1
BLACKLIST_APPS=("keepassxc" "bitwarden" "lastpass")
EOF
    fi
    
    source "$CONFIG_DIR/config"
    
    # Initialize clipboard files
    if [[ ! -f "$CLIPBOARD_FILE" ]]; then
        echo "[]" > "$CLIPBOARD_FILE"
    fi
    
    if [[ ! -f "$FAVORITES_FILE" ]]; then
        echo "[]" > "$FAVORITES_FILE"
    fi
}

# Detect content type
detect_content_type() {
    local content="$1"
    
    # URL detection
    if [[ "$content" =~ ^https?:// ]]; then
        echo "url"
        return
    fi
    
    # Email detection
    if [[ "$content" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo "email"
        return
    fi
    
    # Phone number detection
    if [[ "$content" =~ ^[\+]?[1-9]?[0-9]{7,15}$ ]]; then
        echo "phone"
        return
    fi
    
    # Code detection (simple heuristics)
    if [[ "$content" =~ (function|class|import|export|const|let|var|def|public|private) ]]; then
        echo "code"
        return
    fi
    
    # Password detection (heuristic)
    if [[ ${#content} -ge 8 ]] && [[ ${#content} -le 50 ]] && [[ "$content" =~ [A-Z] ]] && [[ "$content" =~ [a-z] ]] && [[ "$content" =~ [0-9] ]]; then
        echo "password"
        return
    fi
    
    # File path detection
    if [[ "$content" =~ ^(/|~|\./) ]]; then
        echo "file"
        return
    fi
    
    # Default to text
    echo "text"
}

# Add clipboard entry
add_entry() {
    local content="$1"
    local source="${2:-manual}"
    local timestamp=$(date +%s)
    local id=$(date +%s%N | cut -b1-13)
    
    # Skip if content is too long
    if [[ ${#content} -gt $MAX_ENTRY_LENGTH ]]; then
        log "Content too long, skipping: ${#content} characters"
        return
    fi
    
    # Skip empty content
    if [[ -z "$content" ]] || [[ "$content" =~ ^[[:space:]]*$ ]]; then
        return
    fi
    
    # Detect content type
    local content_type=$(detect_content_type "$content")
    
    # Create entry
    local entry=$(jq -n \
        --arg id "$id" \
        --arg timestamp "$timestamp" \
        --arg content "$content" \
        --arg content_type "$content_type" \
        --arg source "$source" \
        --arg favorite "false" \
        '{
            id: $id,
            timestamp: $timestamp | tonumber,
            content: $content,
            content_type: $content_type,
            source: $source,
            favorite: $favorite | test("true"),
            usage_count: 0
        }')
    
    # Load existing entries
    local entries=$(cat "$CLIPBOARD_FILE")
    
    # Check for duplicates
    local duplicate=$(echo "$entries" | jq --arg content "$content" 'map(select(.content == $content)) | length > 0')
    
    if [[ "$duplicate" == "true" ]]; then
        # Update timestamp of existing entry
        echo "$entries" | jq --arg content "$content" --arg timestamp "$timestamp" \
            'map(if .content == $content then .timestamp = ($timestamp | tonumber) else . end)' > "$CLIPBOARD_FILE"
        return
    fi
    
    # Add new entry
    echo "$entries" | jq ". += [$entry]" > "$CLIPBOARD_FILE"
    
    # Limit entries
    echo "$entries" | jq "if length > $MAX_ENTRIES then .[1:] else . end" > "$CLIPBOARD_FILE"
    
    log "Added clipboard entry: $content_type - ${content:0:50}..."
}

# Get clipboard entries
get_entries() {
    local filter="${1:-all}"
    local search="${2:-}"
    
    local entries=$(cat "$CLIPBOARD_FILE")
    
    # Apply category filter
    if [[ "$filter" != "all" ]]; then
        entries=$(echo "$entries" | jq --arg filter "$filter" 'map(select(.content_type == $filter))')
    fi
    
    # Apply search filter
    if [[ -n "$search" ]]; then
        entries=$(echo "$entries" | jq --arg search "$search" 'map(select(.content | test($search; "i")))')
    fi
    
    # Sort by timestamp (newest first)
    echo "$entries" | jq 'sort_by(.timestamp) | reverse'
}

# Format entry for display
format_entry() {
    local entry="$1"
    local format="${2:-brief}"
    
    local content=$(echo "$entry" | jq -r '.content')
    local content_type=$(echo "$entry" | jq -r '.content_type')
    local timestamp=$(echo "$entry" | jq -r '.timestamp')
    local favorite=$(echo "$entry" | jq -r '.favorite')
    local usage_count=$(echo "$entry" | jq -r '.usage_count')
    
    # Get category icon
    local icon="${CATEGORIES[$content_type]:-📋}"
    
    # Favorite indicator
    local fav_indicator=""
    if [[ "$favorite" == "true" ]]; then
        fav_indicator="⭐"
    fi
    
    # Format timestamp
    local time_str=$(date -d "@$timestamp" '+%H:%M')
    
    case "$format" in
        "brief")
            local display_content="$content"
            if [[ ${#display_content} -gt 60 ]]; then
                display_content="${display_content:0:57}..."
            fi
            echo "$fav_indicator$icon $display_content"
            ;;
        "detailed")
            echo "$fav_indicator$icon [$content_type] $content"
            echo "   Time: $time_str | Used: $usage_count times"
            ;;
        "rofi")
            local display_content="$content"
            # Replace newlines with spaces for rofi
            display_content=$(echo "$display_content" | tr '\n' ' ')
            if [[ ${#display_content} -gt 80 ]]; then
                display_content="${display_content:0:77}..."
            fi
            echo "$fav_indicator$icon $display_content"
            ;;
    esac
}

# Show clipboard manager
show_clipboard_manager() {
    local entries=$(get_entries)
    local count=$(echo "$entries" | jq 'length')
    
    if [[ $count -eq 0 ]]; then
        echo "No clipboard history" | rofi -dmenu -i -p "Clipboard Manager" \
            -theme ~/.config/rofi/themes/clipboard.rasi \
            -mesg "No clipboard entries available"
        return
    fi
    
    # Create menu options
    local options=""
    options+="📋 Clipboard Manager ($count entries)\n"
    options+="🔍 Search\n"
    options+="⭐ Favorites\n"
    options+="📝 Categories\n"
    options+="🗑️ Clear History\n"
    options+="⚙️ Settings\n"
    options+="---\n"
    
    # Add recent entries
    echo "$entries" | jq -r '.[:20] | .[] | @base64' | while read -r entry_b64; do
        local entry=$(echo "$entry_b64" | base64 -d)
        local formatted=$(format_entry "$entry" "rofi")
        options+="$formatted\n"
    done
    
    # Show rofi menu
    local chosen=$(echo -e "${options%\\n}" | rofi -dmenu -i -p "Clipboard Manager" \
        -theme ~/.config/rofi/themes/clipboard.rasi \
        -kb-custom-1 "Alt+f" \
        -kb-custom-2 "Alt+d" \
        -kb-custom-3 "Alt+s")
    
    # Handle selection
    case "$chosen" in
        "📋 Clipboard Manager"*)
            return
            ;;
        "🔍 Search")
            show_search
            ;;
        "⭐ Favorites")
            show_favorites
            ;;
        "📝 Categories")
            show_categories
            ;;
        "🗑️ Clear History")
            if confirm_action "Clear clipboard history?"; then
                echo "[]" > "$CLIPBOARD_FILE"
                notify-send "Clipboard Manager" "History cleared"
            fi
            ;;
        "⚙️ Settings")
            show_settings
            ;;
        "---"|"")
            return
            ;;
        *)
            # Handle entry selection
            handle_entry_selection "$chosen"
            ;;
    esac
}

# Handle entry selection
handle_entry_selection() {
    local chosen="$1"
    
    # Find the entry by matching the display text
    local entries=$(get_entries)
    local selected_entry=""
    
    echo "$entries" | jq -r '.[] | @base64' | while read -r entry_b64; do
        local entry=$(echo "$entry_b64" | base64 -d)
        local formatted=$(format_entry "$entry" "rofi")
        
        if [[ "$formatted" == "$chosen" ]]; then
            selected_entry="$entry"
            break
        fi
    done
    
    if [[ -n "$selected_entry" ]]; then
        copy_to_clipboard "$selected_entry"
    fi
}

# Copy entry to clipboard
copy_to_clipboard() {
    local entry="$1"
    local content=$(echo "$entry" | jq -r '.content')
    local id=$(echo "$entry" | jq -r '.id')
    
    # Copy to clipboard
    echo -n "$content" | xclip -selection clipboard
    
    # Update usage count
    local entries=$(cat "$CLIPBOARD_FILE")
    echo "$entries" | jq --arg id "$id" \
        'map(if .id == $id then .usage_count += 1 else . end)' > "$CLIPBOARD_FILE"
    
    log "Copied to clipboard: ${content:0:50}..."
    
    # Show notification
    notify-send "Clipboard Manager" "Copied to clipboard" -t 2000
}

# Show search interface
show_search() {
    local search_term=$(echo "" | rofi -dmenu -i -p "Search clipboard:" \
        -theme ~/.config/rofi/themes/clipboard.rasi)
    
    if [[ -n "$search_term" ]]; then
        local results=$(get_entries "all" "$search_term")
        local count=$(echo "$results" | jq 'length')
        
        if [[ $count -eq 0 ]]; then
            echo "No results found" | rofi -dmenu -i -p "Search Results" \
                -theme ~/.config/rofi/themes/clipboard.rasi \
                -mesg "No entries match your search"
            return
        fi
        
        # Show search results
        local options="🔍 Search Results ($count found)\n---\n"
        
        echo "$results" | jq -r '.[] | @base64' | while read -r entry_b64; do
            local entry=$(echo "$entry_b64" | base64 -d)
            local formatted=$(format_entry "$entry" "rofi")
            options+="$formatted\n"
        done
        
        local chosen=$(echo -e "${options%\\n}" | rofi -dmenu -i -p "Search Results" \
            -theme ~/.config/rofi/themes/clipboard.rasi)
        
        if [[ "$chosen" != "🔍 Search Results"* ]] && [[ "$chosen" != "---" ]] && [[ -n "$chosen" ]]; then
            handle_entry_selection "$chosen"
        fi
    fi
}

# Show favorites
show_favorites() {
    local favorites=$(cat "$FAVORITES_FILE")
    local count=$(echo "$favorites" | jq 'length')
    
    if [[ $count -eq 0 ]]; then
        echo "No favorites" | rofi -dmenu -i -p "Favorites" \
            -theme ~/.config/rofi/themes/clipboard.rasi \
            -mesg "No favorite entries saved"
        return
    fi
    
    # Show favorites
    local options="⭐ Favorites ($count saved)\n---\n"
    
    echo "$favorites" | jq -r '.[] | @base64' | while read -r entry_b64; do
        local entry=$(echo "$entry_b64" | base64 -d)
        local formatted=$(format_entry "$entry" "rofi")
        options+="$formatted\n"
    done
    
    local chosen=$(echo -e "${options%\\n}" | rofi -dmenu -i -p "Favorites" \
        -theme ~/.config/rofi/themes/clipboard.rasi)
    
    if [[ "$chosen" != "⭐ Favorites"* ]] && [[ "$chosen" != "---" ]] && [[ -n "$chosen" ]]; then
        handle_entry_selection "$chosen"
    fi
}

# Show categories
show_categories() {
    local options="📝 Categories\n---\n"
    
    for category in "${!CATEGORIES[@]}"; do
        local icon="${CATEGORIES[$category]}"
        local count=$(get_entries "$category" | jq 'length')
        options+="$icon $category ($count)\n"
    done
    
    local chosen=$(echo -e "${options%\\n}" | rofi -dmenu -i -p "Categories" \
        -theme ~/.config/rofi/themes/clipboard.rasi)
    
    # Extract category from selection
    local category=$(echo "$chosen" | awk '{print $2}')
    
    if [[ -n "$category" ]] && [[ "$category" != "Categories" ]]; then
        show_category_entries "$category"
    fi
}

# Show entries for specific category
show_category_entries() {
    local category="$1"
    local entries=$(get_entries "$category")
    local count=$(echo "$entries" | jq 'length')
    local icon="${CATEGORIES[$category]:-📋}"
    
    if [[ $count -eq 0 ]]; then
        echo "No $category entries" | rofi -dmenu -i -p "$icon $category" \
            -theme ~/.config/rofi/themes/clipboard.rasi \
            -mesg "No entries in this category"
        return
    fi
    
    # Show category entries
    local options="$icon $category ($count entries)\n---\n"
    
    echo "$entries" | jq -r '.[] | @base64' | while read -r entry_b64; do
        local entry=$(echo "$entry_b64" | base64 -d)
        local formatted=$(format_entry "$entry" "rofi")
        options+="$formatted\n"
    done
    
    local chosen=$(echo -e "${options%\\n}" | rofi -dmenu -i -p "$icon $category" \
        -theme ~/.config/rofi/themes/clipboard.rasi)
    
    if [[ "$chosen" != "$icon $category"* ]] && [[ "$chosen" != "---" ]] && [[ -n "$chosen" ]]; then
        handle_entry_selection "$chosen"
    fi
}

# Show settings
show_settings() {
    local options=""
    options+="⚙️ Clipboard Settings\n"
    options+="🔄 Toggle Monitoring\n"
    options+="📊 Show Statistics\n"
    options+="🗑️ Clear All Data\n"
    options+="📤 Export Data\n"
    options+="📥 Import Data\n"
    options+="↩️ Back"
    
    local chosen=$(echo -e "$options" | rofi -dmenu -i -p "Settings" \
        -theme ~/.config/rofi/themes/clipboard.rasi)
    
    case "$chosen" in
        "🔄 Toggle Monitoring")
            toggle_monitoring
            ;;
        "📊 Show Statistics")
            show_statistics
            ;;
        "🗑️ Clear All Data")
            if confirm_action "Clear all clipboard data?"; then
                echo "[]" > "$CLIPBOARD_FILE"
                echo "[]" > "$FAVORITES_FILE"
                notify-send "Clipboard Manager" "All data cleared"
            fi
            ;;
        "↩️ Back")
            show_clipboard_manager
            ;;
    esac
}

# Monitor clipboard
monitor_clipboard() {
    log "Starting clipboard monitor..."
    
    local last_content=""
    
    while true; do
        if [[ "$ENABLE_CLIPBOARD_MANAGER" == "true" ]]; then
            local current_content=$(xclip -selection clipboard -o 2>/dev/null || echo "")
            
            if [[ -n "$current_content" ]] && [[ "$current_content" != "$last_content" ]]; then
                add_entry "$current_content" "clipboard"
                last_content="$current_content"
            fi
        fi
        
        sleep "$MONITOR_INTERVAL"
    done
}

# Confirm action
confirm_action() {
    local message="$1"
    local options="Yes\nNo"
    
    local chosen=$(echo -e "$options" | rofi -dmenu -i -p "$message" \
        -theme ~/.config/rofi/themes/clipboard.rasi)
    
    [[ "$chosen" == "Yes" ]]
}

# Create clipboard theme
create_theme() {
    local theme_file="$HOME/.config/rofi/themes/clipboard.rasi"
    mkdir -p "$(dirname "$theme_file")"
    
    cat > "$theme_file" << 'EOF'
* {
    background: #1e1e2e;
    background-alt: #313244;
    foreground: #cdd6f4;
    selected: #cba6f7;
    active: #a6e3a1;
    urgent: #f38ba8;
    border: #6c7086;
}

window {
    transparency: "real";
    location: center;
    anchor: center;
    fullscreen: false;
    width: 600px;
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
    str: "📋";
    background-color: transparent;
    text-color: inherit;
    font: "JetBrainsMono Nerd Font 14";
}

listview {
    enabled: true;
    columns: 1;
    lines: 15;
    cycle: true;
    dynamic: true;
    scrollbar: true;
    layout: vertical;
    reverse: false;
    fixed-height: true;
    fixed-columns: true;
    spacing: 3px;
    margin: 0px;
    padding: 0px;
    border: 0px solid;
    border-radius: 0px;
    border-color: @border;
    background-color: transparent;
    text-color: @foreground;
    cursor: "default";
}

element {
    enabled: true;
    spacing: 8px;
    margin: 0px;
    padding: 8px;
    border: 0px solid;
    border-radius: 6px;
    border-color: @border;
    background-color: transparent;
    text-color: @foreground;
    cursor: pointer;
}

element selected.normal {
    background-color: @selected;
    text-color: @background;
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
EOF
}

# Main function
main() {
    init_system
    create_theme
    
    case "${1:-show}" in
        "show")
            show_clipboard_manager
            ;;
        "monitor")
            monitor_clipboard
            ;;
        "add")
            add_entry "${2:-}" "${3:-manual}"
            ;;
        "clear")
            echo "[]" > "$CLIPBOARD_FILE"
            ;;
        "help"|"--help")
            cat << EOF
Advanced Clipboard Manager - Intelligent clipboard with categories

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    show        Show clipboard manager (default)
    monitor     Start clipboard monitoring
    add         Add entry to clipboard
    clear       Clear clipboard history
    help        Show this help

Examples:
    $0 show                     # Show clipboard manager
    $0 monitor                  # Start monitoring daemon
    $0 add "text content"       # Add entry manually
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
