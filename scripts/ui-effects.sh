#!/usr/bin/env bash

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"
CACHE_DIR="$HOME/.cache/i3-rice"
LOG_FILE="$CACHE_DIR/ui-effects.log"

# Colors (Catppuccin Mocha)
declare -A COLORS=(
    [base]="#1e1e2e"
    [mantle]="#181825"
    [crust]="#11111b"
    [text]="#cdd6f4"
    [subtext0]="#a6adc8"
    [subtext1]="#bac2de"
    [surface0]="#313244"
    [surface1]="#45475a"
    [surface2]="#585b70"
    [overlay0]="#6c7086"
    [overlay1]="#7f849c"
    [overlay2]="#9399b2"
    [blue]="#89b4fa"
    [lavender]="#b4befe"
    [sapphire]="#74c7ec"
    [sky]="#89dceb"
    [teal]="#94e2d5"
    [green]="#a6e3a1"
    [yellow]="#f9e2af"
    [peach]="#fab387"
    [maroon]="#eba0ac"
    [red]="#f38ba8"
    [mauve]="#cba6f7"
    [pink]="#f5c2e7"
    [flamingo]="#f2cdcd"
    [rosewater]="#f5e0dc"
)

# Ensure directories exist
mkdir -p "$CACHE_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Apply window focus effects
apply_focus_effects() {
    log "Applying window focus effects..."
    
    # Create focus indicator script
    cat > "$CACHE_DIR/focus-indicator.sh" << 'EOF'
#!/bin/bash
# Window focus indicator with smooth transitions

FOCUSED_BORDER="${COLORS[lavender]}"
UNFOCUSED_BORDER="${COLORS[overlay0]}"

i3-msg -t subscribe -m '["window"]' | while read -r event; do
    # Parse window focus events
    if echo "$event" | jq -e '.change == "focus"' > /dev/null; then
        WINDOW_ID=$(echo "$event" | jq -r '.container.window')
        
        # Apply smooth border transition
        xprop -id "$WINDOW_ID" -f _PICOM_SHADOW 32c -set _PICOM_SHADOW 1
        
        # Trigger polybar update for focused window info
        polybar-msg hook window-title 1 2>/dev/null || true
    fi
done &
EOF
    
    chmod +x "$CACHE_DIR/focus-indicator.sh"
    "$CACHE_DIR/focus-indicator.sh" &
    
    log "Focus effects applied successfully"
}

# Apply hover effects for polybar
apply_hover_effects() {
    log "Applying hover effects for polybar..."
    
    # Create hover effect CSS for polybar modules
    cat > "$CONFIG_DIR/polybar/hover-effects.css" << EOF
/* Polybar hover effects */
.module {
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
    border-radius: 8px;
    padding: 4px 8px;
}

.module:hover {
    background-color: ${COLORS[surface1]};
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
}

.module-battery:hover {
    background-color: ${COLORS[green]};
    color: ${COLORS[base]};
}

.module-network:hover {
    background-color: ${COLORS[blue]};
    color: ${COLORS[base]};
}

.module-volume:hover {
    background-color: ${COLORS[mauve]};
    color: ${COLORS[base]};
}

.module-date:hover {
    background-color: ${COLORS[peach]};
    color: ${COLORS[base]};
}
EOF
    
    log "Hover effects applied successfully"
}

# Apply notification animations
apply_notification_effects() {
    log "Applying notification animations..."
    
    # Create notification animation script
    cat > "$CACHE_DIR/notification-animator.sh" << 'EOF'
#!/bin/bash
# Advanced notification animations

NOTIFICATION_SOUND="/usr/share/sounds/freedesktop/stereo/message-new-instant.oga"

# Monitor dunst notifications
dbus-monitor "interface='org.freedesktop.Notifications'" | while read -r line; do
    if echo "$line" | grep -q "member=Notify"; then
        # Play subtle notification sound
        if [[ -f "$NOTIFICATION_SOUND" ]]; then
            pactl set-sink-volume @DEFAULT_SINK@ 30% 2>/dev/null
            paplay "$NOTIFICATION_SOUND" 2>/dev/null &
        fi
        
        # Trigger visual feedback
        notify-send -t 100 -u low "" 2>/dev/null || true
    fi
done &
EOF
    
    chmod +x "$CACHE_DIR/notification-animator.sh"
    "$CACHE_DIR/notification-animator.sh" &
    
    log "Notification effects applied successfully"
}

# Apply loading indicators
apply_loading_indicators() {
    log "Applying loading indicators..."
    
    # Create loading spinner for rofi
    cat > "$CONFIG_DIR/rofi/loading-spinner.rasi" << EOF
/* Loading spinner for rofi */
@import "themes/launcher.rasi"

window {
    width: 200px;
    height: 100px;
}

mainbox {
    children: [message];
}

message {
    background-color: ${COLORS[base]};
    text-color: ${COLORS[text]};
    padding: 20px;
    border-radius: 15px;
}

textbox {
    text-color: ${COLORS[mauve]};
    font: "JetBrainsMono Nerd Font 14";
    horizontal-align: 0.5;
    vertical-align: 0.5;
}
EOF
    
    # Create progress bar component
    cat > "$CACHE_DIR/progress-bar.sh" << 'EOF'
#!/bin/bash
# Animated progress bar component

show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    
    printf "\r["
    printf "%*s" $filled | tr ' ' '█'
    printf "%*s" $((width - filled)) | tr ' ' '░'
    printf "] %d%%" $percentage
}

# Example usage for system operations
for i in $(seq 1 100); do
    show_progress $i 100
    sleep 0.05
done
echo
EOF
    
    chmod +x "$CACHE_DIR/progress-bar.sh"
    
    log "Loading indicators applied successfully"
}

# Apply glassmorphism effects
apply_glassmorphism() {
    log "Applying glassmorphism effects..."
    
    # Update picom config for glassmorphism
    if [[ -f "$CONFIG_DIR/picom/picom.conf" ]]; then
        # Backup original config
        cp "$CONFIG_DIR/picom/picom.conf" "$CONFIG_DIR/picom/picom.conf.backup"
        
        # Add glassmorphism settings
        cat >> "$CONFIG_DIR/picom/picom.conf" << EOF

#################################
#       Glassmorphism           #
#################################

# Enhanced blur for glassmorphism effect
blur-method = "dual_kawase";
blur-strength = 12;
blur-background = true;
blur-background-frame = true;
blur-background-fixed = true;

# Glassmorphism opacity rules
opacity-rule = [
    "85:class_g = 'Rofi'",
    "90:class_g = 'Alacritty' && focused",
    "80:class_g = 'Alacritty' && !focused",
    "95:class_g = 'firefox' && focused",
    "85:class_g = 'firefox' && !focused"
];
EOF
    fi
    
    log "Glassmorphism effects applied successfully"
}

# Main execution
main() {
    log "Starting UI effects enhancement..."
    
    apply_focus_effects
    apply_hover_effects
    apply_notification_effects
    apply_loading_indicators
    apply_glassmorphism
    
    # Restart compositor to apply changes
    pkill picom 2>/dev/null || true
    sleep 1
    picom --experimental-backends --config "$CONFIG_DIR/picom/picom.conf" &
    
    log "UI effects enhancement completed successfully!"
    
    # Show completion notification
    notify-send "UI Effects" "Perfect i3 rice UI enhancements applied!" \
        -i preferences-desktop-theme -t 3000
}

# Handle script arguments
case "${1:-}" in
    "focus") apply_focus_effects ;;
    "hover") apply_hover_effects ;;
    "notifications") apply_notification_effects ;;
    "loading") apply_loading_indicators ;;
    "glass") apply_glassmorphism ;;
    *) main ;;
esac
