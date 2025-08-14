#!/usr/bin/env bash
# =====================================================
# Rofi Wallpaper Selector - duke pan's i3 Rice
# Beautiful wallpaper selection interface
# =====================================================

set -euo pipefail

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
COLLECTIONS_DIR="$WALLPAPER_DIR/Collections"
CACHE_DIR="$HOME/.cache/wallpaper-manager"
PREVIEW_DIR="$CACHE_DIR/previews"
FAVORITES_FILE="$CACHE_DIR/favorites.txt"

# Create directories
mkdir -p "$PREVIEW_DIR"

# Generate preview thumbnails
generate_preview() {
    local wallpaper="$1"
    local preview_file="$PREVIEW_DIR/$(basename "$wallpaper" .${wallpaper##*.}).jpg"
    
    if [[ ! -f "$preview_file" ]]; then
        convert "$wallpaper" -resize 200x150^ -gravity center -extent 200x150 "$preview_file" 2>/dev/null || return 1
    fi
    
    echo "$preview_file"
}

# Get wallpaper list with previews
get_wallpaper_list() {
    local collection="${1:-all}"
    local search_dir="$WALLPAPER_DIR"
    
    if [[ "$collection" != "all" && -d "$COLLECTIONS_DIR/$collection" ]]; then
        search_dir="$COLLECTIONS_DIR/$collection"
    fi
    
    find "$search_dir" -type f $$ -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" -o -name "*.webp" $$ | while read -r wallpaper; do
        local preview=$(generate_preview "$wallpaper")
        local name=$(basename "$wallpaper")
        local is_favorite=""
        
        if grep -q "$wallpaper" "$FAVORITES_FILE" 2>/dev/null; then
            is_favorite="⭐ "
        fi
        
        echo -en "$is_favorite$name\x00icon\x1f$preview\x00info\x1f$wallpaper\n"
    done
}

# Main menu
show_main_menu() {
    local options=(
        "🎨 Browse All Wallpapers"
        "⭐ Favorites"
        "🌅 Morning Collection"
        "🌇 Evening Collection"
        "🌙 Night Collection"
        "🌧️ Rain Collection"
        "❄️ Snow Collection"
        "🌸 Spring Collection"
        "☀️ Summer Collection"
        "🍂 Autumn Collection"
        "❄️ Winter Collection"
        "🏙️ City Collection"
        "🌲 Forest Collection"
        "🌊 Ocean Collection"
        "⛰️ Mountain Collection"
        "🚀 Space Collection"
        "🎮 Cyberpunk Collection"
        "📐 Minimal Collection"
        "🎭 Retro Collection"
        "🎲 Random Wallpaper"
        "⚙️ Settings"
    )
    
    printf '%s\n' "${options[@]}" | rofi -dmenu -i -p "duke pan's Wallpaper Selector" \
        -theme ~/.config/rofi/themes/wallpaper-selector.rasi \
        -kb-custom-1 "Alt+f" -kb-custom-2 "Alt+r" -kb-custom-3 "Alt+s"
}

# Collection browser
browse_collection() {
    local collection="$1"
    local display_name="$2"
    
    local selected=$(get_wallpaper_list "$collection" | rofi -dmenu -i -p "$display_name" \
        -theme ~/.config/rofi/themes/wallpaper-browser.rasi \
        -kb-custom-1 "Alt+f" -kb-custom-2 "Alt+r" -kb-custom-3 "Alt+d" \
        -show-icons -columns 3)
    
    if [[ -n "$selected" ]]; then
        local wallpaper_path=$(echo "$selected" | cut -d$'\x00' -f3 | cut -d$'\x1f' -f2)
        
        case $? in
            0) # Enter pressed - set wallpaper
                ~/.local/bin/wallpaper-manager.sh set "$wallpaper_path"
                ;;
            10) # Alt+f - add to favorites
                ~/.local/bin/wallpaper-manager.sh favorite "$wallpaper_path"
                notify-send "Added to Favorites" "$(basename "$wallpaper_path")"
                ;;
            11) # Alt+r - rate wallpaper
                rate_wallpaper_dialog "$wallpaper_path"
                ;;
            12) # Alt+d - delete wallpaper
                delete_wallpaper_dialog "$wallpaper_path"
                ;;
        esac
    fi
}

# Rate wallpaper dialog
rate_wallpaper_dialog() {
    local wallpaper="$1"
    local rating=$(echo -e "⭐ 1 Star\n⭐⭐ 2 Stars\n⭐⭐⭐ 3 Stars\n⭐⭐⭐⭐ 4 Stars\n⭐⭐⭐⭐⭐ 5 Stars" | \
        rofi -dmenu -i -p "Rate $(basename "$wallpaper")" \
        -theme ~/.config/rofi/themes/rating-dialog.rasi)
    
    if [[ -n "$rating" ]]; then
        local stars=$(echo "$rating" | grep -o "⭐" | wc -l)
        ~/.local/bin/wallpaper-manager.sh rate "$wallpaper" "$stars"
        notify-send "Wallpaper Rated" "$(basename "$wallpaper"): $stars stars"
    fi
}

# Delete wallpaper dialog
delete_wallpaper_dialog() {
    local wallpaper="$1"
    local confirm=$(echo -e "Yes\nNo" | rofi -dmenu -i -p "Delete $(basename "$wallpaper")?" \
        -theme ~/.config/rofi/themes/confirm-dialog.rasi)
    
    if [[ "$confirm" == "Yes" ]]; then
        rm -f "$wallpaper"
        rm -f "${wallpaper%.*}.meta"
        notify-send "Wallpaper Deleted" "$(basename "$wallpaper")"
    fi
}

# Settings menu
show_settings() {
    local options=(
        "📥 Download Collections"
        "🔄 Organize Wallpapers"
        "📊 View Statistics"
        "🧹 Clean Cache"
        "⚙️ Edit Configuration"
        "🔄 Regenerate Previews"
    )
    
    local selected=$(printf '%s\n' "${options[@]}" | rofi -dmenu -i -p "Wallpaper Settings" \
        -theme ~/.config/rofi/themes/settings-menu.rasi)
    
    case "$selected" in
        "📥 Download Collections")
            download_collections_menu
            ;;
        "🔄 Organize Wallpapers")
            ~/.local/bin/wallpaper-manager.sh organize
            notify-send "Wallpapers Organized" "Collections updated"
            ;;
        "📊 View Statistics")
            ~/.local/bin/wallpaper-manager.sh stats | rofi -dmenu -i -p "Statistics" \
                -theme ~/.config/rofi/themes/stats-display.rasi
            ;;
        "🧹 Clean Cache")
            rm -rf "$CACHE_DIR/previews"
            mkdir -p "$PREVIEW_DIR"
            notify-send "Cache Cleaned" "Preview cache cleared"
            ;;
        "⚙️ Edit Configuration")
            alacritty -e nano ~/.config/wallpaper-manager/config
            ;;
        "🔄 Regenerate Previews")
            rm -rf "$PREVIEW_DIR"
            mkdir -p "$PREVIEW_DIR"
            notify-send "Previews Cleared" "Will regenerate on next browse"
            ;;
    esac
}

# Download collections menu
download_collections_menu() {
    local sources=("catppuccin" "nord" "gruvbox" "dracula" "tokyo-night" "minimalist" "anime" "nature")
    local options=()
    
    for source in "${sources[@]}"; do
        options+=("📥 Download $source")
    done
    options+=("📥 Download All Collections")
    
    local selected=$(printf '%s\n' "${options[@]}" | rofi -dmenu -i -p "Download Collections" \
        -theme ~/.config/rofi/themes/download-menu.rasi)
    
    if [[ "$selected" == "📥 Download All Collections" ]]; then
        ~/.local/bin/wallpaper-manager.sh download-all &
        notify-send "Downloading Collections" "All collections downloading in background"
    elif [[ "$selected" =~ "📥 Download " ]]; then
        local source=$(echo "$selected" | sed 's/📥 Download //')
        ~/.local/bin/wallpaper-manager.sh download "$source" &
        notify-send "Downloading Collection" "$source collection downloading"
    fi
}

# Main execution
main() {
    case "${1:-menu}" in
        "menu")
            while true; do
                local choice=$(show_main_menu)
                
                case "$choice" in
                    "🎨 Browse All Wallpapers")
                        browse_collection "all" "All Wallpapers"
                        ;;
                    "⭐ Favorites")
                        browse_collection "favorites" "Favorite Wallpapers"
                        ;;
                    "🌅 Morning Collection")
                        browse_collection "morning" "Morning Wallpapers"
                        ;;
                    "🌇 Evening Collection")
                        browse_collection "evening" "Evening Wallpapers"
                        ;;
                    "🌙 Night Collection")
                        browse_collection "night" "Night Wallpapers"
                        ;;
                    "🌧️ Rain Collection")
                        browse_collection "rain" "Rain Wallpapers"
                        ;;
                    "❄️ Snow Collection")
                        browse_collection "snow" "Snow Wallpapers"
                        ;;
                    "🌸 Spring Collection")
                        browse_collection "spring" "Spring Wallpapers"
                        ;;
                    "☀️ Summer Collection")
                        browse_collection "summer" "Summer Wallpapers"
                        ;;
                    "🍂 Autumn Collection")
                        browse_collection "autumn" "Autumn Wallpapers"
                        ;;
                    "❄️ Winter Collection")
                        browse_collection "winter" "Winter Wallpapers"
                        ;;
                    "🏙️ City Collection")
                        browse_collection "city" "City Wallpapers"
                        ;;
                    "🌲 Forest Collection")
                        browse_collection "forest" "Forest Wallpapers"
                        ;;
                    "🌊 Ocean Collection")
                        browse_collection "ocean" "Ocean Wallpapers"
                        ;;
                    "⛰️ Mountain Collection")
                        browse_collection "mountain" "Mountain Wallpapers"
                        ;;
                    "🚀 Space Collection")
                        browse_collection "space" "Space Wallpapers"
                        ;;
                    "🎮 Cyberpunk Collection")
                        browse_collection "cyberpunk" "Cyberpunk Wallpapers"
                        ;;
                    "📐 Minimal Collection")
                        browse_collection "minimal" "Minimal Wallpapers"
                        ;;
                    "🎭 Retro Collection")
                        browse_collection "retro" "Retro Wallpapers"
                        ;;
                    "🎲 Random Wallpaper")
                        ~/.local/bin/wallpaper-manager.sh random
                        break
                        ;;
                    "⚙️ Settings")
                        show_settings
                        ;;
                    "")
                        break
                        ;;
                esac
            done
            ;;
        *)
            echo "Usage: $0 [menu]"
            ;;
    esac
}

main "$@"
