#!/usr/bin/env bash
# =====================================================
# Theme Manager - Ultimate i3 Rice
# Dynamic theme switching with pywal integration
# =====================================================

set -euo pipefail

# Configuration
THEMES_DIR="$HOME/.config/themes"
WALLPAPERS_DIR="$HOME/.config/wallpapers"
CACHE_DIR="$HOME/.cache/theme-manager"
CONFIG_FILE="$HOME/.config/theme-manager.conf"
LOG_FILE="$CACHE_DIR/theme.log"

# Create directories
mkdir -p "$THEMES_DIR" "$WALLPAPERS_DIR" "$CACHE_DIR"

# Default configuration
cat > "$CONFIG_FILE" 2>/dev/null << 'EOF' || true
# Theme Manager Configuration
CURRENT_THEME="catppuccin-mocha"
AUTO_WALLPAPER=true
PYWAL_INTEGRATION=true
GTK_THEME_SYNC=true
ICON_THEME_SYNC=true
NOTIFICATION_ENABLED=true
BACKUP_CONFIGS=true
EOF

# Source configuration
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Available themes
declare -A THEMES=(
    ["catppuccin-mocha"]="#1e1e2e,#cdd6f4,#cba6f7,#89b4fa,#a6e3a1,#f38ba8"
    ["catppuccin-latte"]="#eff1f5,#4c4f69,#8839ef,#1e66f5,#40a02b,#d20f39"
    ["catppuccin-frappe"]="#303446,#c6d0f5,#ca9ee6,#8caaee,#a6d189,#e78284"
    ["catppuccin-macchiato"]="#24273a,#cad3f5,#c6a0f6,#8aadf4,#a6da95,#ed8796"
    ["nord"]="#2e3440,#d8dee9,#88c0d0,#5e81ac,#a3be8c,#bf616a"
    ["gruvbox-dark"]="#282828,#ebdbb2,#d3869b,#83a598,#b8bb26,#fb4934"
    ["gruvbox-light"]="#fbf1c7,#3c3836,#d3869b,#458588,#98971a,#cc241d"
    ["dracula"]="#282a36,#f8f8f2,#bd93f9,#8be9fd,#50fa7b,#ff5555"
    ["tokyo-night"]="#1a1b26,#c0caf5,#bb9af7,#7aa2f7,#9ece6a,#f7768e"
    ["one-dark"]="#282c34,#abb2bf,#c678dd,#61afef,#98c379,#e06c75"
)

# Backup current configuration
backup_configs() {
    if [[ "$BACKUP_CONFIGS" == "true" ]]; then
        local backup_dir="$CACHE_DIR/backup-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$backup_dir"
        
        # Backup key configuration files
        [[ -f "$HOME/.config/i3/config" ]] && cp "$HOME/.config/i3/config" "$backup_dir/"
        [[ -f "$HOME/.config/polybar/config.ini" ]] && cp "$HOME/.config/polybar/config.ini" "$backup_dir/"
        [[ -f "$HOME/.config/rofi/config.rasi" ]] && cp "$HOME/.config/rofi/config.rasi" "$backup_dir/"
        [[ -f "$HOME/.config/alacritty/alacritty.toml" ]] && cp "$HOME/.config/alacritty/alacritty.toml" "$backup_dir/"
        [[ -f "$HOME/.config/dunst/dunstrc" ]] && cp "$HOME/.config/dunst/dunstrc" "$backup_dir/"
        
        log "Backed up configurations to $backup_dir"
    fi
}

# Apply theme colors
apply_theme_colors() {
    local theme_name="$1"
    local colors="${THEMES[$theme_name]}"
    
    IFS=',' read -ra COLOR_ARRAY <<< "$colors"
    local bg="${COLOR_ARRAY[0]}"
    local fg="${COLOR_ARRAY[1]}"
    local primary="${COLOR_ARRAY[2]}"
    local secondary="${COLOR_ARRAY[3]}"
    local success="${COLOR_ARRAY[4]}"
    local error="${COLOR_ARRAY[5]}"
    
    # Update i3 configuration
    if [[ -f "$HOME/.config/i3/config" ]]; then
        sed -i "s/set \$bg .*/set \$bg $bg/" "$HOME/.config/i3/config"
        sed -i "s/set \$fg .*/set \$fg $fg/" "$HOME/.config/i3/config"
        sed -i "s/set \$primary .*/set \$primary $primary/" "$HOME/.config/i3/config"
        sed -i "s/set \$secondary .*/set \$secondary $secondary/" "$HOME/.config/i3/config"
    fi
    
    # Update Polybar configuration
    if [[ -f "$HOME/.config/polybar/config.ini" ]]; then
        sed -i "s/background = .*/background = $bg/" "$HOME/.config/polybar/config.ini"
        sed -i "s/foreground = .*/foreground = $fg/" "$HOME/.config/polybar/config.ini"
        sed -i "s/primary = .*/primary = $primary/" "$HOME/.config/polybar/config.ini"
        sed -i "s/secondary = .*/secondary = $secondary/" "$HOME/.config/polybar/config.ini"
    fi
    
    # Update Rofi theme
    local rofi_theme="$HOME/.config/rofi/themes/current.rasi"
    cat > "$rofi_theme" << EOF
* {
    background: $bg;
    foreground: $fg;
    primary: $primary;
    secondary: $secondary;
    success: $success;
    error: $error;
}
EOF
    
    # Update Alacritty colors
    if [[ -f "$HOME/.config/alacritty/alacritty.toml" ]]; then
        cat >> "$HOME/.config/alacritty/alacritty.toml" << EOF

[colors.primary]
background = "$bg"
foreground = "$fg"

[colors.normal]
black = "$bg"
red = "$error"
green = "$success"
yellow = "#f9e2af"
blue = "$secondary"
magenta = "$primary"
cyan = "#94e2d5"
white = "$fg"
EOF
    fi
    
    log "Applied theme colors for $theme_name"
}

# Generate wallpaper with pywal
generate_pywal_theme() {
    local wallpaper="$1"
    
    if [[ "$PYWAL_INTEGRATION" == "true" ]] && command -v wal >/dev/null; then
        wal -i "$wallpaper" -n -q
        
        # Source pywal colors
        source "$HOME/.cache/wal/colors.sh"
        
        # Update theme with pywal colors
        THEMES["pywal"]="$background,$foreground,$color5,$color4,$color2,$color1"
        
        log "Generated pywal theme from $wallpaper"
    fi
}

# Set wallpaper
set_wallpaper() {
    local wallpaper="$1"
    
    if [[ -f "$wallpaper" ]]; then
        # Set with nitrogen
        if command -v nitrogen >/dev/null; then
            nitrogen --set-zoom-fill "$wallpaper"
        fi
        
        # Set with feh as fallback
        if command -v feh >/dev/null; then
            feh --bg-fill "$wallpaper"
        fi
        
        # Generate pywal theme if enabled
        if [[ "$PYWAL_INTEGRATION" == "true" ]]; then
            generate_pywal_theme "$wallpaper"
        fi
        
        log "Set wallpaper: $wallpaper"
    fi
}

# Sync GTK theme
sync_gtk_theme() {
    local theme_name="$1"
    
    if [[ "$GTK_THEME_SYNC" == "true" ]]; then
        case "$theme_name" in
            "catppuccin-"*)
                gsettings set org.gnome.desktop.interface gtk-theme "Catppuccin-Mocha-Standard-Mauve-Dark"
                ;;
            "nord")
                gsettings set org.gnome.desktop.interface gtk-theme "Nordic"
                ;;
            "gruvbox-"*)
                gsettings set org.gnome.desktop.interface gtk-theme "Gruvbox-Dark"
                ;;
            "dracula")
                gsettings set org.gnome.desktop.interface gtk-theme "Dracula"
                ;;
            *)
                gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
                ;;
        esac
        
        log "Synced GTK theme for $theme_name"
    fi
}

# Sync icon theme
sync_icon_theme() {
    local theme_name="$1"
    
    if [[ "$ICON_THEME_SYNC" == "true" ]]; then
        case "$theme_name" in
            "catppuccin-"*)
                gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"
                ;;
            "nord")
                gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"
                ;;
            "gruvbox-"*)
                gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"
                ;;
            *)
                gsettings set org.gnome.desktop.interface icon-theme "Papirus"
                ;;
        esac
        
        log "Synced icon theme for $theme_name"
    fi
}

# Reload applications
reload_applications() {
    # Reload i3
    i3-msg reload >/dev/null 2>&1 || true
    
    # Restart Polybar
    pkill polybar || true
    sleep 1
    "$HOME/.config/polybar/launch.sh" &
    
    # Restart Dunst
    pkill dunst || true
    dunst &
    
    # Restart Picom
    pkill picom || true
    sleep 1
    picom --experimental-backends --config "$HOME/.config/picom/picom.conf" &
    
    log "Reloaded applications"
}

# Apply complete theme
apply_theme() {
    local theme_name="$1"
    local wallpaper="${2:-}"
    
    if [[ ! "${THEMES[$theme_name]+isset}" ]]; then
        echo "Error: Theme '$theme_name' not found"
        echo "Available themes: ${!THEMES[*]}"
        exit 1
    fi
    
    log "Applying theme: $theme_name"
    
    # Backup current configuration
    backup_configs
    
    # Apply theme colors
    apply_theme_colors "$theme_name"
    
    # Set wallpaper if provided
    if [[ -n "$wallpaper" ]] && [[ -f "$wallpaper" ]]; then
        set_wallpaper "$wallpaper"
    elif [[ "$AUTO_WALLPAPER" == "true" ]]; then
        # Find matching wallpaper
        local auto_wallpaper
        auto_wallpaper=$(find "$WALLPAPERS_DIR" -name "*$theme_name*" -type f | head -1)
        if [[ -n "$auto_wallpaper" ]]; then
            set_wallpaper "$auto_wallpaper"
        fi
    fi
    
    # Sync system themes
    sync_gtk_theme "$theme_name"
    sync_icon_theme "$theme_name"
    
    # Update current theme in config
    sed -i "s/CURRENT_THEME=.*/CURRENT_THEME=\"$theme_name\"/" "$CONFIG_FILE"
    
    # Reload applications
    reload_applications
    
    # Show notification
    if [[ "$NOTIFICATION_ENABLED" == "true" ]]; then
        notify-send "Theme Manager" "Applied theme: $theme_name" -t 3000
    fi
    
    log "Successfully applied theme: $theme_name"
}

# List available themes
list_themes() {
    echo "Available themes:"
    for theme in "${!THEMES[@]}"; do
        if [[ "$theme" == "$CURRENT_THEME" ]]; then
            echo "* $theme (current)"
        else
            echo "  $theme"
        fi
    done
}

# Random theme
random_theme() {
    local themes_array=(${!THEMES[@]})
    local random_theme="${themes_array[RANDOM % ${#themes_array[@]}]}"
    apply_theme "$random_theme"
}

# Time-based theme switching
time_based_theme() {
    local hour
    hour=$(date +%H)
    
    if [[ $hour -ge 6 && $hour -lt 18 ]]; then
        # Daytime - light theme
        apply_theme "catppuccin-latte"
    else
        # Nighttime - dark theme
        apply_theme "catppuccin-mocha"
    fi
}

# Main function
main() {
    case "${1:-list}" in
        "apply")
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 apply <theme_name> [wallpaper]"
                exit 1
            fi
            apply_theme "$2" "${3:-}"
            ;;
        "list")
            list_themes
            ;;
        "random")
            random_theme
            ;;
        "time-based")
            time_based_theme
            ;;
        "current")
            echo "Current theme: $CURRENT_THEME"
            ;;
        "config")
            ${EDITOR:-nano} "$CONFIG_FILE"
            ;;
        "reload")
            reload_applications
            ;;
        *)
            echo "Usage: $0 {apply|list|random|time-based|current|config|reload}"
            echo ""
            echo "Commands:"
            echo "  apply <theme> [wallpaper]  Apply a specific theme"
            echo "  list                       List available themes"
            echo "  random                     Apply a random theme"
            echo "  time-based                 Apply theme based on time of day"
            echo "  current                    Show current theme"
            echo "  config                     Edit configuration"
            echo "  reload                     Reload applications"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
