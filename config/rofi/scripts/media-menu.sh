#!/usr/bin/env bash
# =====================================================
# Media Menu Script - Ultimate i3 Rice
# Comprehensive media control interface
# =====================================================

set -euo pipefail

# Configuration
CACHE_DIR="$HOME/.cache/rofi-media"
THEME="$HOME/.config/rofi/themes/media-menu.rasi"

# Create cache directory
mkdir -p "$CACHE_DIR"

# Get all available players
get_players() {
    playerctl -l 2>/dev/null || echo ""
}

# Get player status with icon
get_player_status() {
    local player="$1"
    local status
    status=$(playerctl -p "$player" status 2>/dev/null || echo "Stopped")
    
    case "$status" in
        "Playing") echo "▶ $player (Playing)" ;;
        "Paused") echo "⏸ $player (Paused)" ;;
        *) echo "⏹ $player (Stopped)" ;;
    esac
}

# Get current track info
get_track_info() {
    local player="$1"
    local title artist
    
    title=$(playerctl -p "$player" metadata title 2>/dev/null || echo "Unknown")
    artist=$(playerctl -p "$player" metadata artist 2>/dev/null || echo "Unknown")
    
    echo "$title - $artist"
}

# Generate menu options
generate_menu() {
    local players
    players=$(get_players)
    
    if [[ -z "$players" ]]; then
        echo "🎵 No media players found"
        return
    fi
    
    # Player controls
    echo "🎵 Media Players"
    echo "───────────────────"
    
    while IFS= read -r player; do
        [[ -n "$player" ]] || continue
        
        local status track_info
        status=$(get_player_status "$player")
        track_info=$(get_track_info "$player")
        
        echo "$status"
        echo "   🎵 $track_info"
        echo "   ⏮ Previous"
        echo "   ⏯ Play/Pause"
        echo "   ⏭ Next"
        echo "   🔊 Volume Up"
        echo "   🔉 Volume Down"
        echo "   ℹ Show Info"
        echo "───────────────────"
    done <<< "$players"
    
    # Global controls
    echo ""
    echo "🎛 Global Controls"
    echo "───────────────────"
    echo "🔄 Refresh Players"
    echo "📱 Open Spotify"
    echo "🎧 Open Music Player"
    echo "🎬 Open Video Player"
    echo "📻 Open Radio"
    echo "⚙ Media Settings"
}

# Handle menu selection
handle_selection() {
    local selection="$1"
    local players
    players=$(get_players)
    
    case "$selection" in
        *"Previous")
            local player
            player=$(echo "$players" | head -1)
            [[ -n "$player" ]] && playerctl -p "$player" previous
            ;;
        *"Play/Pause")
            local player
            player=$(echo "$players" | head -1)
            [[ -n "$player" ]] && playerctl -p "$player" play-pause
            ;;
        *"Next")
            local player
            player=$(echo "$players" | head -1)
            [[ -n "$player" ]] && playerctl -p "$player" next
            ;;
        *"Volume Up")
            local player
            player=$(echo "$players" | head -1)
            [[ -n "$player" ]] && playerctl -p "$player" volume 0.1+
            ;;
        *"Volume Down")
            local player
            player=$(echo "$players" | head -1)
            [[ -n "$player" ]] && playerctl -p "$player" volume 0.1-
            ;;
        *"Show Info")
            "$HOME/.config/polybar/scripts/media-control.sh" detailed
            ;;
        *"Refresh Players")
            exec "$0"
            ;;
        *"Open Spotify")
            command -v spotify >/dev/null && spotify &
            ;;
        *"Open Music Player")
            if command -v rhythmbox >/dev/null; then
                rhythmbox &
            elif command -v clementine >/dev/null; then
                clementine &
            elif command -v audacious >/dev/null; then
                audacious &
            fi
            ;;
        *"Open Video Player")
            if command -v vlc >/dev/null; then
                vlc &
            elif command -v mpv >/dev/null; then
                mpv &
            fi
            ;;
        *"Open Radio")
            if command -v radio-tray >/dev/null; then
                radio-tray &
            elif command -v gradio >/dev/null; then
                gradio &
            fi
            ;;
        *"Media Settings")
            pavucontrol &
            ;;
    esac
}

# Main execution
main() {
    local menu_options selection
    
    menu_options=$(generate_menu)
    
    selection=$(echo "$menu_options" | rofi -dmenu -i \
        -p "🎵 Media Control" \
        -theme "$THEME" \
        -markup-rows \
        -no-custom)
    
    if [[ -n "$selection" ]]; then
        handle_selection "$selection"
    fi
}

# Execute main function
main "$@"
