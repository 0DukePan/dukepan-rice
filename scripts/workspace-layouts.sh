#!/usr/bin/env bash

# =====================================================
# Intelligent Workspace Layout Manager for i3
# Automatic Window Arrangement and Smart Layouts
# =====================================================

set -euo pipefail

# Configuration
CONFIG_DIR="$HOME/.config/workspace-layouts"
LAYOUTS_DIR="$CONFIG_DIR/layouts"
CACHE_DIR="$HOME/.cache/workspace-layouts"
LOG_FILE="$CACHE_DIR/workspace-layouts.log"

# Workspace definitions with purposes
declare -A WORKSPACE_PURPOSES=(
    [1]="terminal"
    [2]="browser"
    [3]="development"
    [4]="communication"
    [5]="media"
    [6]="design"
    [7]="documents"
    [8]="monitoring"
    [9]="gaming"
    [10]="misc"
)

# Layout templates
declare -A LAYOUT_TEMPLATES=(
    ["terminal"]="split-h:terminal,terminal,terminal"
    ["browser"]="single:browser"
    ["development"]="split-v:editor,terminal"
    ["communication"]="split-h:chat,email"
    ["media"]="single:media-player"
    ["design"]="split-v:design-tool,file-manager"
    ["documents"]="single:document-editor"
    ["monitoring"]="grid:htop,system-monitor,logs,network"
    ["gaming"]="single:game"
    ["misc"]="auto"
)

# Application categories
declare -A APP_CATEGORIES=(
    # Terminals
    ["alacritty"]="terminal"
    ["kitty"]="terminal"
    ["gnome-terminal"]="terminal"
    ["xterm"]="terminal"
    
    # Browsers
    ["firefox"]="browser"
    ["chromium"]="browser"
    ["google-chrome"]="browser"
    ["brave"]="browser"
    
    # Development
    ["code"]="editor"
    ["vim"]="editor"
    ["emacs"]="editor"
    ["atom"]="editor"
    ["sublime_text"]="editor"
    
    # Communication
    ["discord"]="chat"
    ["telegram"]="chat"
    ["slack"]="chat"
    ["thunderbird"]="email"
    ["evolution"]="email"
    
    # Media
    ["vlc"]="media-player"
    ["mpv"]="media-player"
    ["spotify"]="media-player"
    ["rhythmbox"]="media-player"
    
    # Design
    ["gimp"]="design-tool"
    ["inkscape"]="design-tool"
    ["blender"]="design-tool"
    ["krita"]="design-tool"
    
    # File managers
    ["thunar"]="file-manager"
    ["nautilus"]="file-manager"
    ["dolphin"]="file-manager"
    
    # System monitoring
    ["htop"]="system-monitor"
    ["btop"]="system-monitor"
    ["gnome-system-monitor"]="system-monitor"
)

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "$LOG_FILE" >&2
}

# Initialize system
init_system() {
    mkdir -p "$CONFIG_DIR" "$LAYOUTS_DIR" "$CACHE_DIR"
    
    # Create default configuration
    if [[ ! -f "$CONFIG_DIR/config" ]]; then
        cat > "$CONFIG_DIR/config" << 'EOF'
# Workspace Layout Manager Configuration
ENABLE_AUTO_LAYOUT=true
ENABLE_SMART_GAPS=true
ENABLE_FOCUS_FOLLOWS_MOUSE=true
ENABLE_WORKSPACE_SWITCHING=true
LAYOUT_TRANSITION_DELAY=0.2
SMART_RESIZE_ENABLED=true
REMEMBER_LAYOUTS=true
AUTO_SAVE_LAYOUTS=true
NOTIFICATION_ENABLED=true
EOF
    fi
    
    source "$CONFIG_DIR/config"
}

# Get current workspace
get_current_workspace() {
    i3-msg -t get_workspaces | jq -r '.[] | select(.focused==true).name' | grep -o '[0-9]*'
}

# Get workspace windows
get_workspace_windows() {
    local workspace="$1"
    i3-msg -t get_tree | jq -r "
        .. | 
        select(.type? == \"workspace\" and .name? == \"$workspace\") | 
        .. | 
        select(.window? != null) | 
        \"\(.window_properties.class // \"unknown\"):\(.window_properties.instance // \"unknown\"):\(.name // \"untitled\")\""
}

# Detect application category
detect_app_category() {
    local app_class="$1"
    local app_instance="$2"
    local window_title="$3"
    
    # Convert to lowercase for matching
    app_class=$(echo "$app_class" | tr '[:upper:]' '[:lower:]')
    app_instance=$(echo "$app_instance" | tr '[:upper:]' '[:lower:]')
    
    # Check direct matches first
    if [[ -n "${APP_CATEGORIES[$app_class]:-}" ]]; then
        echo "${APP_CATEGORIES[$app_class]}"
        return
    fi
    
    if [[ -n "${APP_CATEGORIES[$app_instance]:-}" ]]; then
        echo "${APP_CATEGORIES[$app_instance]}"
        return
    fi
    
    # Check partial matches
    case "$app_class" in
        *terminal*|*term*) echo "terminal" ;;
        *browser*|*firefox*|*chrome*) echo "browser" ;;
        *editor*|*code*|*vim*) echo "editor" ;;
        *chat*|*discord*|*telegram*) echo "chat" ;;
        *mail*|*thunder*) echo "email" ;;
        *media*|*player*|*vlc*|*spotify*) echo "media-player" ;;
        *design*|*gimp*|*inkscape*) echo "design-tool" ;;
        *file*|*manager*|*thunar*) echo "file-manager" ;;
        *monitor*|*htop*|*system*) echo "system-monitor" ;;
        *game*|*steam*) echo "game" ;;
        *) echo "unknown" ;;
    esac
}

# Apply layout to workspace
apply_layout() {
    local workspace="$1"
    local layout_type="$2"
    local windows=("${@:3}")
    
    log "Applying $layout_type layout to workspace $workspace"
    
    # Focus workspace
    i3-msg "workspace $workspace" &>/dev/null
    
    case "$layout_type" in
        "single")
            # Single window layout - maximize
            if [[ ${#windows[@]} -gt 0 ]]; then
                i3-msg "layout tabbed" &>/dev/null
            fi
            ;;
        "split-h")
            # Horizontal split
            i3-msg "layout splith" &>/dev/null
            ;;
        "split-v")
            # Vertical split
            i3-msg "layout splitv" &>/dev/null
            ;;
        "grid")
            # Grid layout for multiple windows
            if [[ ${#windows[@]} -gt 2 ]]; then
                i3-msg "layout splitv" &>/dev/null
                sleep 0.1
                i3-msg "split h" &>/dev/null
            else
                i3-msg "layout splith" &>/dev/null
            fi
            ;;
        "tabbed")
            # Tabbed layout
            i3-msg "layout tabbed" &>/dev/null
            ;;
        "stacked")
            # Stacked layout
            i3-msg "layout stacking" &>/dev/null
            ;;
        *)
            # Auto layout based on window count
            local window_count=${#windows[@]}
            if [[ $window_count -eq 1 ]]; then
                i3-msg "layout tabbed" &>/dev/null
            elif [[ $window_count -eq 2 ]]; then
                i3-msg "layout splith" &>/dev/null
            elif [[ $window_count -le 4 ]]; then
                i3-msg "layout splitv" &>/dev/null
                sleep 0.1
                i3-msg "split h" &>/dev/null
            else
                i3-msg "layout tabbed" &>/dev/null
            fi
            ;;
    esac
    
    # Apply smart gaps
    if [[ "$ENABLE_SMART_GAPS" == "true" ]]; then
        apply_smart_gaps "$workspace" "${#windows[@]}"
    fi
}

# Apply smart gaps based on window count
apply_smart_gaps() {
    local workspace="$1"
    local window_count="$2"
    
    if [[ $window_count -eq 1 ]]; then
        # No gaps for single window
        i3-msg "workspace $workspace; gaps inner current set 0; gaps outer current set 0" &>/dev/null
    elif [[ $window_count -eq 2 ]]; then
        # Small gaps for two windows
        i3-msg "workspace $workspace; gaps inner current set 5; gaps outer current set 5" &>/dev/null
    else
        # Normal gaps for multiple windows
        i3-msg "workspace $workspace; gaps inner current set 15; gaps outer current set 15" &>/dev/null
    fi
}

# Analyze workspace and suggest layout
analyze_workspace() {
    local workspace="$1"
    local windows_info
    
    # Get window information
    mapfile -t windows_info < <(get_workspace_windows "$workspace")
    
    if [[ ${#windows_info[@]} -eq 0 ]]; then
        echo "empty"
        return
    fi
    
    # Analyze window types
    local categories=()
    local window_count=${#windows_info[@]}
    
    for window_info in "${windows_info[@]}"; do
        IFS=':' read -r app_class app_instance window_title <<< "$window_info"
        local category=$(detect_app_category "$app_class" "$app_instance" "$window_title")
        categories+=("$category")
    done
    
    # Determine best layout based on categories and count
    local unique_categories=($(printf '%s\n' "${categories[@]}" | sort -u))
    local category_count=${#unique_categories[@]}
    
    if [[ $window_count -eq 1 ]]; then
        echo "single"
    elif [[ $category_count -eq 1 ]]; then
        # All windows are same category
        case "${unique_categories[0]}" in
            "terminal") echo "split-h" ;;
            "browser"|"editor") echo "tabbed" ;;
            "system-monitor") echo "grid" ;;
            *) echo "auto" ;;
        esac
    elif [[ $window_count -eq 2 ]]; then
        # Two different categories
        if [[ " ${categories[*]} " =~ " editor " ]] && [[ " ${categories[*]} " =~ " terminal " ]]; then
            echo "split-v"  # Editor on top, terminal below
        else
            echo "split-h"
        fi
    elif [[ $window_count -le 4 ]]; then
        echo "grid"
    else
        echo "tabbed"
    fi
}

# Save current layout
save_layout() {
    local workspace="$1"
    local layout_name="${2:-workspace-$workspace-$(date +%s)}"
    
    # Get current workspace tree
    local workspace_tree=$(i3-msg -t get_tree | jq "
        .. | 
        select(.type? == \"workspace\" and .name? == \"$workspace\")")
    
    # Save layout
    echo "$workspace_tree" > "$LAYOUTS_DIR/$layout_name.json"
    
    # Save metadata
    cat > "$LAYOUTS_DIR/$layout_name.meta" << EOF
name=$layout_name
workspace=$workspace
created=$(date)
window_count=$(echo "$workspace_tree" | jq '[.. | select(.window? != null)] | length')
layout_type=$(echo "$workspace_tree" | jq -r '.layout // "unknown"')
EOF
    
    log "Layout saved: $layout_name"
}

# Load saved layout
load_layout() {
    local layout_name="$1"
    local target_workspace="${2:-$(get_current_workspace)}"
    
    if [[ ! -f "$LAYOUTS_DIR/$layout_name.json" ]]; then
        log_error "Layout not found: $layout_name"
        return 1
    fi
    
    log "Loading layout: $layout_name to workspace $target_workspace"
    
    # This is a simplified version - full layout restoration would require
    # more complex i3 tree manipulation
    local layout_type=$(jq -r '.layout // "splith"' "$LAYOUTS_DIR/$layout_name.json")
    
    i3-msg "workspace $target_workspace; layout $layout_type" &>/dev/null
}

# Auto-arrange current workspace
auto_arrange() {
    local workspace="${1:-$(get_current_workspace)}"
    
    if [[ "$ENABLE_AUTO_LAYOUT" != "true" ]]; then
        return
    fi
    
    log "Auto-arranging workspace $workspace"
    
    # Get current windows
    local windows_info
    mapfile -t windows_info < <(get_workspace_windows "$workspace")
    
    if [[ ${#windows_info[@]} -eq 0 ]]; then
        log "No windows in workspace $workspace"
        return
    fi
    
    # Analyze and apply best layout
    local suggested_layout=$(analyze_workspace "$workspace")
    apply_layout "$workspace" "$suggested_layout" "${windows_info[@]}"
    
    # Save layout if auto-save is enabled
    if [[ "$AUTO_SAVE_LAYOUTS" == "true" ]]; then
        save_layout "$workspace" "auto-$workspace-$(date +%Y%m%d-%H%M%S)"
    fi
    
    # Send notification
    if [[ "$NOTIFICATION_ENABLED" == "true" ]] && command -v notify-send &>/dev/null; then
        notify-send -i "preferences-desktop" "Workspace Arranged" \
            "Applied $suggested_layout layout to workspace $workspace"
    fi
}

# Monitor workspace changes
monitor_workspaces() {
    log "Starting workspace monitor..."
    
    # Subscribe to i3 events
    i3-msg -t subscribe -m '["workspace","window"]' | while read -r event; do
        local event_type=$(echo "$event" | jq -r '.change // empty')
        
        case "$event_type" in
            "focus"|"init")
                local workspace=$(echo "$event" | jq -r '.current.name // empty' | grep -o '[0-9]*')
                if [[ -n "$workspace" ]]; then
                    sleep "$LAYOUT_TRANSITION_DELAY"
                    auto_arrange "$workspace"
                fi
                ;;
            "new"|"close"|"move")
                local workspace=$(get_current_workspace)
                sleep "$LAYOUT_TRANSITION_DELAY"
                auto_arrange "$workspace"
                ;;
        esac
    done
}

# Apply workspace-specific settings
apply_workspace_settings() {
    local workspace="$1"
    local purpose="${WORKSPACE_PURPOSES[$workspace]:-misc}"
    
    case "$purpose" in
        "terminal")
            # Terminal workspace settings
            i3-msg "workspace $workspace; focus_follows_mouse yes" &>/dev/null
            ;;
        "browser")
            # Browser workspace settings
            i3-msg "workspace $workspace; focus_follows_mouse no" &>/dev/null
            ;;
        "development")
            # Development workspace settings
            i3-msg "workspace $workspace; focus_follows_mouse yes" &>/dev/null
            ;;
        "media")
            # Media workspace settings - no gaps for fullscreen
            i3-msg "workspace $workspace; gaps inner current set 0; gaps outer current set 0" &>/dev/null
            ;;
    esac
}

# Smart window resizing
smart_resize() {
    local direction="$1"
    local amount="${2:-10}"
    
    if [[ "$SMART_RESIZE_ENABLED" != "true" ]]; then
        return
    fi
    
    # Get current window info
    local focused_window=$(i3-msg -t get_tree | jq -r '.. | select(.focused? == true)')
    local parent_layout=$(echo "$focused_window" | jq -r '.parent.layout // "splith"')
    
    # Adjust resize direction based on parent layout
    case "$parent_layout" in
        "splith")
            case "$direction" in
                "left") i3-msg "resize shrink width $amount px or $amount ppt" ;;
                "right") i3-msg "resize grow width $amount px or $amount ppt" ;;
                "up"|"down") i3-msg "resize grow height $amount px or $amount ppt" ;;
            esac
            ;;
        "splitv")
            case "$direction" in
                "up") i3-msg "resize shrink height $amount px or $amount ppt" ;;
                "down") i3-msg "resize grow height $amount px or $amount ppt" ;;
                "left"|"right") i3-msg "resize grow width $amount px or $amount ppt" ;;
            esac
            ;;
        *)
            # Default resize
            i3-msg "resize $direction $amount px or $amount ppt"
            ;;
    esac
}

# Show workspace layout status
show_status() {
    echo "Workspace Layout Manager Status"
    echo "==============================="
    echo
    
    local current_workspace=$(get_current_workspace)
    echo "Current workspace: $current_workspace"
    echo "Workspace purpose: ${WORKSPACE_PURPOSES[$current_workspace]:-unknown}"
    
    # Show window information
    local windows_info
    mapfile -t windows_info < <(get_workspace_windows "$current_workspace")
    echo "Windows: ${#windows_info[@]}"
    
    for window_info in "${windows_info[@]}"; do
        IFS=':' read -r app_class app_instance window_title <<< "$window_info"
        local category=$(detect_app_category "$app_class" "$app_instance" "$window_title")
        echo "  - $app_class ($category): $window_title"
    done
    
    echo
    echo "Suggested layout: $(analyze_workspace "$current_workspace")"
    
    # Show saved layouts
    echo
    echo "Saved layouts:"
    if [[ -d "$LAYOUTS_DIR" ]]; then
        for layout_file in "$LAYOUTS_DIR"/*.meta; do
            if [[ -f "$layout_file" ]]; then
                local layout_name=$(basename "$layout_file" .meta)
                echo "  - $layout_name"
            fi
        done
    fi
}

# CLI interface
show_help() {
    cat << EOF
Workspace Layout Manager - Intelligent Window Arrangement

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    arrange [WORKSPACE]     Auto-arrange workspace (current if not specified)
    monitor                 Monitor workspaces and auto-arrange
    save [NAME]             Save current workspace layout
    load NAME [WORKSPACE]   Load saved layout
    status                  Show current workspace status
    resize DIRECTION [AMOUNT] Smart resize in direction
    config                  Edit configuration

Options:
    --help, -h              Show this help message

Examples:
    $0 arrange              # Arrange current workspace
    $0 arrange 3            # Arrange workspace 3
    $0 monitor              # Start monitoring mode
    $0 save dev-layout      # Save current layout as 'dev-layout'
    $0 load dev-layout 3    # Load 'dev-layout' to workspace 3
    $0 resize left 20       # Smart resize left by 20px
EOF
}

# Main function
main() {
    init_system
    
    case "${1:-arrange}" in
        "arrange")
            auto_arrange "${2:-}"
            ;;
        "monitor")
            monitor_workspaces
            ;;
        "save")
            save_layout "$(get_current_workspace)" "$2"
            ;;
        "load")
            if [[ -z "${2:-}" ]]; then
                echo "Error: Layout name required"
                exit 1
            fi
            load_layout "$2" "${3:-}"
            ;;
        "resize")
            if [[ -z "${2:-}" ]]; then
                echo "Error: Direction required (left/right/up/down)"
                exit 1
            fi
            smart_resize "$2" "${3:-10}"
            ;;
        "status")
            show_status
            ;;
        "config")
            ${EDITOR:-nano} "$CONFIG_DIR/config"
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

main "$@"
