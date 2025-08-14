#!/usr/bin/env bash
# =====================================================
# Screenshot Manager - Ultimate i3 Rice
# Advanced screenshot tools with editing and sharing
# =====================================================

set -euo pipefail

# Configuration
SCREENSHOTS_DIR="$HOME/Pictures/Screenshots"
CACHE_DIR="$HOME/.cache/screenshot-manager"
CONFIG_FILE="$HOME/.config/screenshot-manager.conf"
LOG_FILE="$CACHE_DIR/screenshot.log"

# Create directories
mkdir -p "$SCREENSHOTS_DIR" "$CACHE_DIR"

# Default configuration
cat > "$CONFIG_FILE" 2>/dev/null << 'EOF' || true
# Screenshot Manager Configuration
DEFAULT_FORMAT="png"
QUALITY=95
AUTO_UPLOAD=false
UPLOAD_SERVICE="imgur"
NOTIFICATION_ENABLED=true
SOUND_ENABLED=true
WATERMARK_ENABLED=false
WATERMARK_TEXT="Made with i3 Rice"
EDITOR_ENABLED=true
PREFERRED_EDITOR="gimp"
EOF

# Source configuration
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Play sound effect
play_sound() {
    if [[ "$SOUND_ENABLED" == "true" ]]; then
        if command -v paplay >/dev/null; then
            paplay /usr/share/sounds/freedesktop/stereo/camera-shutter.oga 2>/dev/null &
        elif command -v aplay >/dev/null; then
            aplay /usr/share/sounds/alsa/Front_Left.wav 2>/dev/null &
        fi
    fi
}

# Generate filename
generate_filename() {
    local prefix="$1"
    local timestamp
    timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
    echo "$SCREENSHOTS_DIR/${prefix}_${timestamp}.$DEFAULT_FORMAT"
}

# Add watermark
add_watermark() {
    local file="$1"
    
    if [[ "$WATERMARK_ENABLED" == "true" ]] && command -v convert >/dev/null; then
        local temp_file="${file%.${DEFAULT_FORMAT}}_temp.${DEFAULT_FORMAT}"
        
        convert "$file" \
            -gravity SouthEast \
            -pointsize 20 \
            -fill white \
            -stroke black \
            -strokewidth 1 \
            -annotate +10+10 "$WATERMARK_TEXT" \
            "$temp_file"
        
        mv "$temp_file" "$file"
        log "Added watermark to $file"
    fi
}

# Upload to service
upload_screenshot() {
    local file="$1"
    local url=""
    
    if [[ "$AUTO_UPLOAD" == "true" ]]; then
        case "$UPLOAD_SERVICE" in
            "imgur")
                if command -v curl >/dev/null; then
                    url=$(curl -s -X POST \
                        -H "Authorization: Client-ID YOUR_IMGUR_CLIENT_ID" \
                        -F "image=@$file" \
                        https://api.imgur.com/3/image | \
                        jq -r '.data.link' 2>/dev/null || echo "")
                fi
                ;;
            "0x0")
                if command -v curl >/dev/null; then
                    url=$(curl -s -F "file=@$file" https://0x0.st || echo "")
                fi
                ;;
            "transfer")
                if command -v curl >/dev/null; then
                    url=$(curl -s --upload-file "$file" \
                        "https://transfer.sh/$(basename "$file")" || echo "")
                fi
                ;;
        esac
        
        if [[ -n "$url" ]]; then
            echo "$url" | xclip -selection clipboard
            log "Uploaded screenshot: $url"
            
            if [[ "$NOTIFICATION_ENABLED" == "true" ]]; then
                notify-send "Screenshot Uploaded" \
                    "URL copied to clipboard: $url" \
                    -i "$file" -t 5000
            fi
        fi
    fi
}

# Show notification
show_notification() {
    local file="$1"
    local action="$2"
    
    if [[ "$NOTIFICATION_ENABLED" == "true" ]]; then
        notify-send "Screenshot $action" \
            "Saved to: $(basename "$file")" \
            -i "$file" -t 3000 \
            --action="edit=Edit" \
            --action="copy=Copy to Clipboard" \
            --action="upload=Upload" \
            --action="delete=Delete"
    fi
}

# Handle notification actions
handle_notification_action() {
    local file="$1"
    local action="$2"
    
    case "$action" in
        "edit")
            edit_screenshot "$file"
            ;;
        "copy")
            copy_to_clipboard "$file"
            ;;
        "upload")
            upload_screenshot "$file"
            ;;
        "delete")
            rm "$file"
            notify-send "Screenshot Deleted" "$(basename "$file")" -t 2000
            ;;
    esac
}

# Copy to clipboard
copy_to_clipboard() {
    local file="$1"
    
    if command -v xclip >/dev/null; then
        xclip -selection clipboard -t image/png -i "$file"
        log "Copied screenshot to clipboard: $file"
        
        if [[ "$NOTIFICATION_ENABLED" == "true" ]]; then
            notify-send "Screenshot Copied" \
                "Image copied to clipboard" -t 2000
        fi
    fi
}

# Edit screenshot
edit_screenshot() {
    local file="$1"
    
    if [[ "$EDITOR_ENABLED" == "true" ]]; then
        case "$PREFERRED_EDITOR" in
            "gimp")
                command -v gimp >/dev/null && gimp "$file" &
                ;;
            "krita")
                command -v krita >/dev/null && krita "$file" &
                ;;
            "pinta")
                command -v pinta >/dev/null && pinta "$file" &
                ;;
            *)
                # Try to find any available image editor
                if command -v gimp >/dev/null; then
                    gimp "$file" &
                elif command -v krita >/dev/null; then
                    krita "$file" &
                elif command -v pinta >/dev/null; then
                    pinta "$file" &
                fi
                ;;
        esac
        
        log "Opened screenshot in editor: $file"
    fi
}

# Full screen screenshot
screenshot_full() {
    local filename
    filename=$(generate_filename "fullscreen")
    
    if command -v flameshot >/dev/null; then
        flameshot full -p "$SCREENSHOTS_DIR" -d 1000
    elif command -v maim >/dev/null; then
        maim "$filename"
    elif command -v scrot >/dev/null; then
        scrot "$filename"
    else
        echo "Error: No screenshot tool found (flameshot, maim, or scrot required)"
        exit 1
    fi
    
    if [[ -f "$filename" ]]; then
        play_sound
        add_watermark "$filename"
        show_notification "$filename" "Taken"
        upload_screenshot "$filename"
        log "Full screen screenshot: $filename"
    fi
}

# Area selection screenshot
screenshot_area() {
    local filename
    filename=$(generate_filename "area")
    
    if command -v flameshot >/dev/null; then
        flameshot gui -p "$SCREENSHOTS_DIR"
    elif command -v maim >/dev/null; then
        maim -s "$filename"
    elif command -v scrot >/dev/null; then
        scrot -s "$filename"
    else
        echo "Error: No screenshot tool found (flameshot, maim, or scrot required)"
        exit 1
    fi
    
    if [[ -f "$filename" ]]; then
        play_sound
        add_watermark "$filename"
        show_notification "$filename" "Taken"
        upload_screenshot "$filename"
        log "Area screenshot: $filename"
    fi
}

# Window screenshot
screenshot_window() {
    local filename
    filename=$(generate_filename "window")
    
    if command -v flameshot >/dev/null; then
        # Flameshot doesn't have direct window capture, use area selection
        flameshot gui -p "$SCREENSHOTS_DIR"
    elif command -v maim >/dev/null; then
        maim -i "$(xdotool getactivewindow)" "$filename"
    elif command -v scrot >/dev/null; then
        scrot -u "$filename"
    else
        echo "Error: No screenshot tool found (flameshot, maim, or scrot required)"
        exit 1
    fi
    
    if [[ -f "$filename" ]]; then
        play_sound
        add_watermark "$filename"
        show_notification "$filename" "Taken"
        upload_screenshot "$filename"
        log "Window screenshot: $filename"
    fi
}

# Delayed screenshot
screenshot_delayed() {
    local delay="${1:-5}"
    local filename
    filename=$(generate_filename "delayed")
    
    notify-send "Screenshot Delayed" \
        "Taking screenshot in $delay seconds..." -t "$((delay * 1000))"
    
    sleep "$delay"
    
    if command -v flameshot >/dev/null; then
        flameshot full -p "$SCREENSHOTS_DIR"
    elif command -v maim >/dev/null; then
        maim "$filename"
    elif command -v scrot >/dev/null; then
        scrot "$filename"
    fi
    
    if [[ -f "$filename" ]]; then
        play_sound
        add_watermark "$filename"
        show_notification "$filename" "Taken"
        upload_screenshot "$filename"
        log "Delayed screenshot: $filename"
    fi
}

# Screen recording
record_screen() {
    local filename
    filename=$(generate_filename "recording")
    filename="${filename%.$DEFAULT_FORMAT}.mp4"
    
    if command -v ffmpeg >/dev/null; then
        notify-send "Screen Recording" "Recording started. Press Ctrl+C to stop." -t 3000
        
        ffmpeg -f x11grab -s "$(xdpyinfo | grep dimensions | awk '{print $2}')" \
            -i :0.0 -r 30 -c:v libx264 -preset fast -crf 23 "$filename"
        
        if [[ -f "$filename" ]]; then
            notify-send "Screen Recording" \
                "Recording saved: $(basename "$filename")" \
                -t 3000
            log "Screen recording: $filename"
        fi
    else
        echo "Error: ffmpeg required for screen recording"
        exit 1
    fi
}

# Clean old screenshots
clean_old_screenshots() {
    local days="${1:-30}"
    
    find "$SCREENSHOTS_DIR" -type f -mtime "+$days" -delete
    log "Cleaned screenshots older than $days days"
    
    if [[ "$NOTIFICATION_ENABLED" == "true" ]]; then
        notify-send "Screenshot Cleanup" \
            "Removed screenshots older than $days days" -t 2000
    fi
}

# Show screenshot gallery
show_gallery() {
    if command -v feh >/dev/null; then
        feh "$SCREENSHOTS_DIR" &
    elif command -v eog >/dev/null; then
        eog "$SCREENSHOTS_DIR" &
    elif command -v gwenview >/dev/null; then
        gwenview "$SCREENSHOTS_DIR" &
    else
        xdg-open "$SCREENSHOTS_DIR"
    fi
}

# Main function
main() {
    case "${1:-area}" in
        "full"|"fullscreen")
            screenshot_full
            ;;
        "area"|"selection")
            screenshot_area
            ;;
        "window")
            screenshot_window
            ;;
        "delayed")
            screenshot_delayed "${2:-5}"
            ;;
        "record")
            record_screen
            ;;
        "gallery")
            show_gallery
            ;;
        "clean")
            clean_old_screenshots "${2:-30}"
            ;;
        "config")
            ${EDITOR:-nano} "$CONFIG_FILE"
            ;;
        *)
            echo "Usage: $0 {full|area|window|delayed|record|gallery|clean|config}"
            echo ""
            echo "Commands:"
            echo "  full                Take fullscreen screenshot"
            echo "  area                Take area selection screenshot"
            echo "  window              Take active window screenshot"
            echo "  delayed [seconds]   Take delayed screenshot (default: 5s)"
            echo "  record              Start screen recording"
            echo "  gallery             Open screenshot gallery"
            echo "  clean [days]        Clean old screenshots (default: 30 days)"
            echo "  config              Edit configuration"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
