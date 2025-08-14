#!/usr/bin/env bash

# =====================================================
# Clipboard Manager Script - Perfect i3 Rice
# Advanced clipboard management with history and search
# =====================================================

# Configuration
CLIPBOARD_DIR="$HOME/.cache/clipboard"
CLIPBOARD_FILE="$CLIPBOARD_DIR/history"
MAX_ENTRIES=100
MAX_LENGTH=100
ROFI_THEME="$HOME/.config/rofi/themes/launcher.rasi"

# Colors (Catppuccin Mocha)
COLOR_BG="#1e1e2e"
COLOR_FG="#cdd6f4"
COLOR_ACTIVE="#cba6f7"

# Create clipboard directory
mkdir -p "$CLIPBOARD_DIR"

# Initialize clipboard file if it doesn't exist
[[ ! -f "$CLIPBOARD_FILE" ]] && touch "$CLIPBOARD_FILE"

# Function to add entry to clipboard history
add_to_history() {
    local content="$1"
    
    # Skip empty content
    [[ -z "$content" ]] && return
    
    # Skip if content is too long
    [[ ${#content} -gt 1000 ]] && return
    
    # Remove existing entry if it exists
    grep -v "^$content$" "$CLIPBOARD_FILE" > "${CLIPBOARD_FILE}.tmp" 2>/dev/null || true
    mv "${CLIPBOARD_FILE}.tmp" "$CLIPBOARD_FILE"
    
    # Add new entry at the top
    echo "$content" | cat - "$CLIPBOARD_FILE" > "${CLIPBOARD_FILE}.tmp"
    mv "${CLIPBOARD_FILE}.tmp" "$CLIPBOARD_FILE"
    
    # Limit number of entries
    head -n "$MAX_ENTRIES" "$CLIPBOARD_FILE" > "${CLIPBOARD_FILE}.tmp"
    mv "${CLIPBOARD_FILE}.tmp" "$CLIPBOARD_FILE"
}

# Function to get clipboard content
get_clipboard() {
    if command -v xclip >/dev/null 2>&1; then
        xclip -selection clipboard -o 2>/dev/null
    elif command -v xsel >/dev/null 2>&1; then
        xsel --clipboard --output 2>/dev/null
    fi
}

# Function to set clipboard content
set_clipboard() {
    local content="$1"
    
    if command -v xclip >/dev/null 2>&1; then
        echo -n "$content" | xclip -selection clipboard
    elif command -v xsel >/dev/null 2>&1; then
        echo -n "$content" | xsel --clipboard --input
    fi
}

# Function to format entry for display
format_entry() {
    local entry="$1"
    local display_entry="$entry"
    
    # Replace newlines with spaces
    display_entry=$(echo "$display_entry" | tr '\n' ' ')
    
    # Truncate if too long
    if [[ ${#display_entry} -gt $MAX_LENGTH ]]; then
        display_entry="${display_entry:0:$((MAX_LENGTH-3))}..."
    fi
    
    echo "$display_entry"
}

# Function to show clipboard history
show_history() {
    if [[ ! -s "$CLIPBOARD_FILE" ]]; then
        echo "No clipboard history" | rofi -dmenu -i -p "Clipboard" \
            -theme "$ROFI_THEME" \
            -theme-str "listview { lines: 1; }"
        return
    fi
    
    # Create formatted entries
    local entries=()
    local original_entries=()
    
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            entries+=("$(format_entry "$line")")
            original_entries+=("$line")
        fi
    done < "$CLIPBOARD_FILE"
    
    # Show rofi menu
    local chosen_index=-1
    local chosen_display=""
    
    for i in "${!entries[@]}"; do
        echo "$i: ${entries[$i]}"
    done | rofi -dmenu -i -p "Clipboard History" \
        -theme "$ROFI_THEME" \
        -format 'i' \
        -theme-str "listview { lines: 10; }" | {
        read -r chosen_index
        
        if [[ $chosen_index -ge 0 && $chosen_index -lt ${#original_entries[@]} ]]; then
            local selected_content="${original_entries[$chosen_index]}"
            set_clipboard "$selected_content"
            
            # Move selected entry to top
            add_to_history "$selected_content"
            
            # Show notification
            if command -v notify-send >/dev/null 2>&1; then
                local preview=$(format_entry "$selected_content")
                notify-send "Clipboard" "Copied: $preview"
            fi
        fi
    }
}

# Function to clear clipboard history
clear_history() {
    local confirm=$(echo -e "Yes\nNo" | rofi -dmenu -i -p "Clear clipboard history?" \
        -theme "$ROFI_THEME" \
        -theme-str "listview { lines: 2; }")
    
    if [[ "$confirm" == "Yes" ]]; then
        > "$CLIPBOARD_FILE"
        if command -v notify-send >/dev/null 2>&1; then
            notify-send "Clipboard" "History cleared"
        fi
    fi
}

# Function to monitor clipboard changes
monitor_clipboard() {
    local last_content=""
    
    while true; do
        local current_content=$(get_clipboard)
        
        if [[ -n "$current_content" && "$current_content" != "$last_content" ]]; then
            add_to_history "$current_content"
            last_content="$current_content"
        fi
        
        sleep 1
    done
}

# Function to search clipboard history
search_history() {
    if [[ ! -s "$CLIPBOARD_FILE" ]]; then
        echo "No clipboard history" | rofi -dmenu -i -p "Search Clipboard" \
            -theme "$ROFI_THEME"
        return
    fi
    
    # Get search query
    local query=$(echo "" | rofi -dmenu -i -p "Search clipboard:" \
        -theme "$ROFI_THEME")
    
    [[ -z "$query" ]] && return
    
    # Search and display results
    local results=()
    local original_entries=()
    
    while IFS= read -r line; do
        if [[ -n "$line" && "$line" == *"$query"* ]]; then
            results+=("$(format_entry "$line")")
            original_entries+=("$line")
        fi
    done < "$CLIPBOARD_FILE"
    
    if [[ ${#results[@]} -eq 0 ]]; then
        echo "No results found" | rofi -dmenu -i -p "Search Results" \
            -theme "$ROFI_THEME"
        return
    fi
    
    # Show results
    local chosen=""
    for i in "${!results[@]}"; do
        echo "${results[$i]}"
    done | rofi -dmenu -i -p "Search Results" \
        -theme "$ROFI_THEME" | {
        read -r chosen
        
        # Find original content
        for i in "${!results[@]}"; do
            if [[ "${results[$i]}" == "$chosen" ]]; then
                local selected_content="${original_entries[$i]}"
                set_clipboard "$selected_content"
                add_to_history "$selected_content"
                
                if command -v notify-send >/dev/null 2>&1; then
                    notify-send "Clipboard" "Copied: $(format_entry "$selected_content")"
                fi
                break
            fi
        done
    }
}

# Function to show clipboard menu
show_menu() {
    local options=(
        " Show History"
        " Search History"
        " Clear History"
        " Current Clipboard"
        " Start Monitor"
        " Stop Monitor"
    )
    
    local chosen=$(printf '%s\n' "${options[@]}" | rofi -dmenu -i -p "Clipboard Manager" \
        -theme "$ROFI_THEME")
    
    case "$chosen" in
        " Show History")
            show_history
            ;;
        " Search History")
            search_history
            ;;
        " Clear History")
            clear_history
            ;;
        " Current Clipboard")
            local current=$(get_clipboard)
            if [[ -n "$current" ]]; then
                echo "$current" | rofi -dmenu -i -p "Current Clipboard" \
                    -theme "$ROFI_THEME"
            else
                echo "Clipboard is empty" | rofi -dmenu -i -p "Current Clipboard" \
                    -theme "$ROFI_THEME"
            fi
            ;;
        " Start Monitor")
            if ! pgrep -f "clipboard-manager.sh.*monitor" >/dev/null; then
                "$0" --monitor &
                if command -v notify-send >/dev/null 2>&1; then
                    notify-send "Clipboard Manager" "Monitoring started"
                fi
            else
                if command -v notify-send >/dev/null 2>&1; then
                    notify-send "Clipboard Manager" "Already monitoring"
                fi
            fi
            ;;
        " Stop Monitor")
            pkill -f "clipboard-manager.sh.*monitor"
            if command -v notify-send >/dev/null 2>&1; then
                notify-send "Clipboard Manager" "Monitoring stopped"
            fi
            ;;
    esac
}

# Main function
main() {
    case "${1:-}" in
        --help|-h)
            echo "Clipboard Manager Script"
            echo "Usage: $0 [options]"
            echo
            echo "Options:"
            echo "  --help, -h     Show this help message"
            echo "  --history      Show clipboard history"
            echo "  --search       Search clipboard history"
            echo "  --clear        Clear clipboard history"
            echo "  --monitor      Start monitoring clipboard changes"
            echo "  --add TEXT     Add text to clipboard history"
            echo "  --menu         Show clipboard menu (default)"
            echo
            exit 0
            ;;
        --history)
            show_history
            ;;
        --search)
            search_history
            ;;
        --clear)
            clear_history
            ;;
        --monitor)
            monitor_clipboard
            ;;
        --add)
            shift
            add_to_history "$*"
            ;;
        --menu|*)
            show_menu
            ;;
    esac
}

main "$@"
