#!/usr/bin/env bash
# =====================================================
# Media Control Script - Ultimate i3 Rice
# Advanced media player integration with album art
# =====================================================

set -euo pipefail

# Configuration
CACHE_DIR="$HOME/.cache/polybar-media"
ALBUM_ART_DIR="$CACHE_DIR/album-art"
CONFIG_FILE="$HOME/.config/polybar/media-config.conf"
LOG_FILE="$CACHE_DIR/media.log"

# Create directories
mkdir -p "$CACHE_DIR" "$ALBUM_ART_DIR"

# Default configuration
cat > "$CONFIG_FILE" 2>/dev/null << 'EOF' || true
# Media Control Configuration
MAX_TITLE_LENGTH=30
MAX_ARTIST_LENGTH=25
SHOW_ALBUM_ART=true
NOTIFICATION_ENABLED=true
SCROBBLE_ENABLED=false
PREFERRED_PLAYER="spotify"
EOF

# Source configuration
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Get active player
get_active_player() {
    local players
    players=$(playerctl -l 2>/dev/null | head -1)
    
    if [[ -n "$players" ]]; then
        # Prefer specific player if configured
        if [[ "$PREFERRED_PLAYER" != "" ]] && echo "$players" | grep -q "$PREFERRED_PLAYER"; then
            echo "$PREFERRED_PLAYER"
        else
            echo "$players" | head -1
        fi
    else
        echo ""
    fi
}

# Get player status
get_player_status() {
    local player="$1"
    playerctl -p "$player" status 2>/dev/null || echo "Stopped"
}

# Get track info
get_track_info() {
    local player="$1"
    local title artist album
    
    title=$(playerctl -p "$player" metadata title 2>/dev/null || echo "Unknown")
    artist=$(playerctl -p "$player" metadata artist 2>/dev/null || echo "Unknown")
    album=$(playerctl -p "$player" metadata album 2>/dev/null || echo "Unknown")
    
    # Truncate if too long
    title=${title:0:$MAX_TITLE_LENGTH}
    artist=${artist:0:$MAX_ARTIST_LENGTH}
    
    echo "$title|$artist|$album"
}

# Download album art
download_album_art() {
    local player="$1"
    local art_url art_file
    
    art_url=$(playerctl -p "$player" metadata mpris:artUrl 2>/dev/null || echo "")
    
    if [[ -n "$art_url" ]]; then
        art_file="$ALBUM_ART_DIR/$(echo "$art_url" | md5sum | cut -d' ' -f1).jpg"
        
        if [[ ! -f "$art_file" ]]; then
            if [[ "$art_url" =~ ^file:// ]]; then
                # Local file
                cp "${art_url#file://}" "$art_file" 2>/dev/null || true
            else
                # Remote URL
                curl -s "$art_url" -o "$art_file" 2>/dev/null || true
            fi
        fi
        
        echo "$art_file"
    fi
}

# Show notification with album art
show_notification() {
    local title="$1" artist="$2" album="$3" art_file="$4" status="$5"
    
    if [[ "$NOTIFICATION_ENABLED" == "true" ]] && command -v notify-send >/dev/null; then
        local icon_arg=""
        if [[ -f "$art_file" ]]; then
            icon_arg="-i $art_file"
        fi
        
        notify-send $icon_arg "Now $status" "$title\nby $artist\nfrom $album" -t 3000
    fi
}

# Control functions
play_pause() {
    local player
    player=$(get_active_player)
    
    if [[ -n "$player" ]]; then
        playerctl -p "$player" play-pause
        local status
        status=$(get_player_status "$player")
        
        if [[ "$status" == "Playing" ]]; then
            local track_info art_file
            track_info=$(get_track_info "$player")
            IFS='|' read -r title artist album <<< "$track_info"
            
            if [[ "$SHOW_ALBUM_ART" == "true" ]]; then
                art_file=$(download_album_art "$player")
            fi
            
            show_notification "$title" "$artist" "$album" "$art_file" "Playing"
        fi
    fi
}

next_track() {
    local player
    player=$(get_active_player)
    
    if [[ -n "$player" ]]; then
        playerctl -p "$player" next
        sleep 0.5
        
        local track_info art_file
        track_info=$(get_track_info "$player")
        IFS='|' read -r title artist album <<< "$track_info"
        
        if [[ "$SHOW_ALBUM_ART" == "true" ]]; then
            art_file=$(download_album_art "$player")
        fi
        
        show_notification "$title" "$artist" "$album" "$art_file" "Playing"
    fi
}

previous_track() {
    local player
    player=$(get_active_player)
    
    if [[ -n "$player" ]]; then
        playerctl -p "$player" previous
        sleep 0.5
        
        local track_info art_file
        track_info=$(get_track_info "$player")
        IFS='|' read -r title artist album <<< "$track_info"
        
        if [[ "$SHOW_ALBUM_ART" == "true" ]]; then
            art_file=$(download_album_art "$player")
        fi
        
        show_notification "$title" "$artist" "$album" "$art_file" "Playing"
    fi
}

# Volume control
volume_up() {
    local player
    player=$(get_active_player)
    
    if [[ -n "$player" ]]; then
        playerctl -p "$player" volume 0.1+
    fi
}

volume_down() {
    local player
    player=$(get_active_player)
    
    if [[ -n "$player" ]]; then
        playerctl -p "$player" volume 0.1-
    fi
}

# Get current playing info for polybar
get_current_info() {
    local player status track_info position duration
    player=$(get_active_player)
    
    if [[ -z "$player" ]]; then
        echo "No player active"
        return
    fi
    
    status=$(get_player_status "$player")
    
    if [[ "$status" == "Stopped" ]]; then
        echo "Stopped"
        return
    fi
    
    track_info=$(get_track_info "$player")
    IFS='|' read -r title artist album <<< "$track_info"
    
    # Get position and duration
    position=$(playerctl -p "$player" position 2>/dev/null | cut -d. -f1 || echo "0")
    duration=$(playerctl -p "$player" metadata mpris:length 2>/dev/null || echo "0")
    
    # Convert microseconds to seconds for duration
    if [[ "$duration" -gt 1000000 ]]; then
        duration=$((duration / 1000000))
    fi
    
    # Format time
    pos_min=$((position / 60))
    pos_sec=$((position % 60))
    dur_min=$((duration / 60))
    dur_sec=$((duration % 60))
    
    # Status icon
    local status_icon
    case "$status" in
        "Playing") status_icon="▶" ;;
        "Paused") status_icon="⏸" ;;
        *) status_icon="⏹" ;;
    esac
    
    # Format output
    if [[ "$duration" -gt 0 ]]; then
        printf "%s %s - %s [%02d:%02d/%02d:%02d]" \
            "$status_icon" "$title" "$artist" \
            "$pos_min" "$pos_sec" "$dur_min" "$dur_sec"
    else
        printf "%s %s - %s" "$status_icon" "$title" "$artist"
    fi
}

# Show detailed info
show_detailed_info() {
    local player track_info art_file
    player=$(get_active_player)
    
    if [[ -z "$player" ]]; then
        notify-send "Media Player" "No active player found"
        return
    fi
    
    track_info=$(get_track_info "$player")
    IFS='|' read -r title artist album <<< "$track_info"
    
    if [[ "$SHOW_ALBUM_ART" == "true" ]]; then
        art_file=$(download_album_art "$player")
    fi
    
    local status
    status=$(get_player_status "$player")
    
    show_notification "$title" "$artist" "$album" "$art_file" "$status"
}

# Scrobble to Last.fm (if enabled)
scrobble_track() {
    if [[ "$SCROBBLE_ENABLED" == "true" ]] && command -v lastfm-scrobbler >/dev/null; then
        local player track_info
        player=$(get_active_player)
        
        if [[ -n "$player" ]]; then
            track_info=$(get_track_info "$player")
            IFS='|' read -r title artist album <<< "$track_info"
            
            lastfm-scrobbler "$artist" "$title" "$album" &
        fi
    fi
}

# Cleanup old album art
cleanup_album_art() {
    find "$ALBUM_ART_DIR" -type f -mtime +7 -delete 2>/dev/null || true
}

# Main function
main() {
    case "${1:-info}" in
        "play-pause"|"toggle")
            play_pause
            ;;
        "next")
            next_track
            ;;
        "previous"|"prev")
            previous_track
            ;;
        "volume-up")
            volume_up
            ;;
        "volume-down")
            volume_down
            ;;
        "info")
            get_current_info
            ;;
        "detailed")
            show_detailed_info
            ;;
        "scrobble")
            scrobble_track
            ;;
        "cleanup")
            cleanup_album_art
            ;;
        "config")
            ${EDITOR:-nano} "$CONFIG_FILE"
            ;;
        *)
            echo "Usage: $0 {play-pause|next|previous|volume-up|volume-down|info|detailed|scrobble|cleanup|config}"
            exit 1
            ;;
    esac
}

# Run cleanup on startup
cleanup_album_art

# Execute main function
main "$@"
