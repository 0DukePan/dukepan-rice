#!/usr/bin/env bash
# =====================================================
# Ultimate Wallpaper Manager - duke pan's i3 Rice
# Advanced wallpaper collection and management system
# =====================================================

set -euo pipefail

# Configuration
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
COLLECTIONS_DIR="$WALLPAPER_DIR/Collections"
CACHE_DIR="$HOME/.cache/wallpaper-manager"
CONFIG_FILE="$HOME/.config/wallpaper-manager/config"
LOG_FILE="$CACHE_DIR/wallpaper-manager.log"
FAVORITES_FILE="$CACHE_DIR/favorites.txt"
HISTORY_FILE="$CACHE_DIR/history.txt"

# Wallpaper sources and collections
declare -A WALLPAPER_SOURCES=(
    ["catppuccin"]="https://github.com/catppuccin/wallpapers/archive/main.zip"
    ["nord"]="https://github.com/linuxdotexe/nordic-wallpapers/archive/master.zip"
    ["gruvbox"]="https://github.com/AngelJumbo/gruvbox-wallpapers/archive/main.zip"
    ["dracula"]="https://github.com/dracula/wallpapers/archive/master.zip"
    ["tokyo-night"]="https://github.com/enkia/tokyo-night-vscode-theme/raw/master/static/tokyo-night.png"
    ["minimalist"]="https://github.com/dharmx/walls/archive/main.zip"
    ["anime"]="https://github.com/Gingeh/wallpapers/archive/main.zip"
    ["nature"]="https://github.com/D3Ext/aesthetic-wallpapers/archive/main.zip"
)

declare -A COLLECTION_THEMES=(
    ["morning"]="bright sunny dawn light warm golden"
    ["afternoon"]="clear blue sky bright daylight"
    ["evening"]="sunset orange pink purple warm"
    ["night"]="dark blue purple black stars moon"
    ["rain"]="stormy cloudy dark moody wet"
    ["snow"]="white winter cold ice crystal"
    ["spring"]="green nature flowers bloom fresh"
    ["summer"]="bright colorful vibrant warm"
    ["autumn"]="orange red yellow leaves fall"
    ["winter"]="cold blue white snow ice"
    ["minimal"]="simple clean geometric abstract"
    ["cyberpunk"]="neon purple pink blue futuristic"
    ["space"]="galaxy stars nebula cosmic universe"
    ["forest"]="trees green nature woods peaceful"
    ["ocean"]="blue water waves sea peaceful"
    ["mountain"]="peaks landscape scenic nature"
    ["city"]="urban skyline buildings lights"
    ["retro"]="vintage 80s synthwave neon"
)

# Initialize system
init_system() {
    mkdir -p "$WALLPAPER_DIR" "$COLLECTIONS_DIR" "$CACHE_DIR" "$(dirname "$CONFIG_FILE")"
    
    # Create collections directories
    for theme in "${!COLLECTION_THEMES[@]}"; do
        mkdir -p "$COLLECTIONS_DIR/$theme"
    done
    
    # Create default config
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Wallpaper Manager Configuration - duke pan's setup
AUTO_DOWNLOAD=true
QUALITY_FILTER=true
MIN_RESOLUTION="1920x1080"
MAX_FILE_SIZE="10M"
SUPPORTED_FORMATS="jpg,jpeg,png,webp"
ENABLE_AI_TAGGING=true
ENABLE_DUPLICATE_DETECTION=true
ENABLE_SMART_COLLECTIONS=true
NOTIFICATION_ENABLED=true
BACKUP_ENABLED=true
COMPRESSION_ENABLED=false
WALLPAPER_RATING_SYSTEM=true
AUTO_ORGANIZE=true
SYNC_WITH_CLOUD=false
CLOUD_PROVIDER=""
CLOUD_PATH=""
EOF
    fi
    
    source "$CONFIG_FILE"
    
    # Initialize files
    touch "$FAVORITES_FILE" "$HISTORY_FILE"
}

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] duke pan's wallpaper manager: $*" | tee -a "$LOG_FILE"
}

# Download wallpaper collections
download_collections() {
    local source_name="$1"
    
    if [[ ! "${WALLPAPER_SOURCES[$source_name]+isset}" ]]; then
        log "Error: Unknown wallpaper source '$source_name'"
        return 1
    fi
    
    local url="${WALLPAPER_SOURCES[$source_name]}"
    local temp_dir=$(mktemp -d)
    local download_dir="$COLLECTIONS_DIR/$source_name"
    
    mkdir -p "$download_dir"
    
    log "Downloading $source_name wallpaper collection..."
    
    case "$url" in
        *.zip)
            if curl -L "$url" -o "$temp_dir/collection.zip"; then
                cd "$temp_dir"
                unzip -q collection.zip
                find . -type f $$ -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" $$ -exec cp {} "$download_dir/" \;
                log "Downloaded and extracted $source_name collection"
            else
                log "Failed to download $source_name collection"
                return 1
            fi
            ;;
        *.png|*.jpg|*.jpeg)
            if curl -L "$url" -o "$download_dir/$(basename "$url")"; then
                log "Downloaded single wallpaper from $source_name"
            else
                log "Failed to download wallpaper from $source_name"
                return 1
            fi
            ;;
    esac
    
    rm -rf "$temp_dir"
    
    # Process downloaded wallpapers
    process_wallpapers "$download_dir"
}

# Process and organize wallpapers
process_wallpapers() {
    local source_dir="$1"
    local processed_count=0
    
    log "Processing wallpapers in $source_dir..."
    
    find "$source_dir" -type f $$ -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" $$ | while read -r wallpaper; do
        # Quality filter
        if [[ "$QUALITY_FILTER" == "true" ]]; then
            local resolution=$(identify -format "%wx%h" "$wallpaper" 2>/dev/null || echo "0x0")
            local width=${resolution%x*}
            local height=${resolution#*x}
            local min_width=${MIN_RESOLUTION%x*}
            local min_height=${MIN_RESOLUTION#*x}
            
            if [[ $width -lt $min_width || $height -lt $min_height ]]; then
                log "Skipping low resolution wallpaper: $(basename "$wallpaper") ($resolution)"
                rm -f "$wallpaper"
                continue
            fi
        fi
        
        # File size filter
        if [[ "$MAX_FILE_SIZE" != "" ]]; then
            local file_size=$(du -h "$wallpaper" | cut -f1)
            # Simple size comparison (this is basic, could be improved)
            if [[ ${#file_size} -gt 4 ]]; then
                log "Skipping large file: $(basename "$wallpaper") ($file_size)"
                rm -f "$wallpaper"
                continue
            fi
        fi
        
        # Auto-organize into themed collections
        if [[ "$AUTO_ORGANIZE" == "true" ]]; then
            organize_wallpaper "$wallpaper"
        fi
        
        # Generate metadata
        generate_metadata "$wallpaper"
        
        ((processed_count++))
    done
    
    log "Processed $processed_count wallpapers"
}

# Organize wallpaper into themed collections
organize_wallpaper() {
    local wallpaper="$1"
    local filename=$(basename "$wallpaper" | tr '[:upper:]' '[:lower:]')
    local moved=false
    
    # Check filename for theme keywords
    for theme in "${!COLLECTION_THEMES[@]}"; do
        local keywords="${COLLECTION_THEMES[$theme]}"
        for keyword in $keywords; do
            if [[ "$filename" == *"$keyword"* ]]; then
                local theme_dir="$COLLECTIONS_DIR/$theme"
                mkdir -p "$theme_dir"
                cp "$wallpaper" "$theme_dir/"
                log "Organized $(basename "$wallpaper") into $theme collection"
                moved=true
                break 2
            fi
        done
    done
    
    # If not categorized, analyze colors for theme detection
    if [[ "$moved" == "false" && "$ENABLE_AI_TAGGING" == "true" ]]; then
        analyze_and_categorize "$wallpaper"
    fi
}

# Analyze wallpaper colors and categorize
analyze_and_categorize() {
    local wallpaper="$1"
    
    # Extract dominant colors using ImageMagick
    local colors=$(convert "$wallpaper" -resize 50x50! -colors 5 -format "%c" histogram:info: 2>/dev/null | head -5)
    
    # Simple color-based categorization
    if echo "$colors" | grep -qi "blue\|cyan"; then
        cp "$wallpaper" "$COLLECTIONS_DIR/ocean/"
        log "Auto-categorized $(basename "$wallpaper") as ocean theme (blue dominant)"
    elif echo "$colors" | grep -qi "green"; then
        cp "$wallpaper" "$COLLECTIONS_DIR/forest/"
        log "Auto-categorized $(basename "$wallpaper") as forest theme (green dominant)"
    elif echo "$colors" | grep -qi "orange\|red\|yellow"; then
        cp "$wallpaper" "$COLLECTIONS_DIR/autumn/"
        log "Auto-categorized $(basename "$wallpaper") as autumn theme (warm colors)"
    elif echo "$colors" | grep -qi "purple\|pink"; then
        cp "$wallpaper" "$COLLECTIONS_DIR/evening/"
        log "Auto-categorized $(basename "$wallpaper") as evening theme (purple/pink)"
    else
        cp "$wallpaper" "$COLLECTIONS_DIR/minimal/"
        log "Auto-categorized $(basename "$wallpaper") as minimal theme (neutral colors)"
    fi
}

# Generate wallpaper metadata
generate_metadata() {
    local wallpaper="$1"
    local metadata_file="${wallpaper%.*}.meta"
    
    if [[ -f "$metadata_file" ]]; then
        return
    fi
    
    local resolution=$(identify -format "%wx%h" "$wallpaper" 2>/dev/null || echo "unknown")
    local file_size=$(du -h "$wallpaper" | cut -f1)
    local colors=$(convert "$wallpaper" -colors 8 -format "%c" histogram:info: 2>/dev/null | head -3 | cut -d' ' -f4 | tr '\n' ',' | sed 's/,$//')
    local checksum=$(md5sum "$wallpaper" | cut -d' ' -f1)
    
    cat > "$metadata_file" << EOF
# Wallpaper Metadata - duke pan's collection
filename=$(basename "$wallpaper")
resolution=$resolution
file_size=$file_size
dominant_colors=$colors
checksum=$checksum
added_date=$(date '+%Y-%m-%d %H:%M:%S')
rating=0
views=0
last_used=never
tags=
notes=
EOF
    
    log "Generated metadata for $(basename "$wallpaper")"
}

# Smart wallpaper selection
smart_select() {
    local criteria="$1"
    local collection_dir=""
    local candidates=()
    
    case "$criteria" in
        "time-based")
            local hour=$(date +%H)
            if [[ $hour -ge 6 && $hour -lt 12 ]]; then
                collection_dir="$COLLECTIONS_DIR/morning"
            elif [[ $hour -ge 12 && $hour -lt 18 ]]; then
                collection_dir="$COLLECTIONS_DIR/afternoon"
            elif [[ $hour -ge 18 && $hour -lt 22 ]]; then
                collection_dir="$COLLECTIONS_DIR/evening"
            else
                collection_dir="$COLLECTIONS_DIR/night"
            fi
            ;;
        "weather-based")
            local weather=$(curl -s "wttr.in/?format=%C" | tr '[:upper:]' '[:lower:]')
            case "$weather" in
                *rain*|*storm*) collection_dir="$COLLECTIONS_DIR/rain" ;;
                *snow*) collection_dir="$COLLECTIONS_DIR/snow" ;;
                *clear*|*sunny*) collection_dir="$COLLECTIONS_DIR/morning" ;;
                *) collection_dir="$COLLECTIONS_DIR/minimal" ;;
            esac
            ;;
        "mood-based")
            # Simple mood detection based on system activity
            local load=$(uptime | awk '{print $10}' | sed 's/,//')
            if (( $(echo "$load > 2.0" | bc -l) )); then
                collection_dir="$COLLECTIONS_DIR/cyberpunk"  # High activity = energetic
            else
                collection_dir="$COLLECTIONS_DIR/minimal"    # Low activity = calm
            fi
            ;;
        "seasonal")
            local month=$(date +%m)
            case "$month" in
                03|04|05) collection_dir="$COLLECTIONS_DIR/spring" ;;
                06|07|08) collection_dir="$COLLECTIONS_DIR/summer" ;;
                09|10|11) collection_dir="$COLLECTIONS_DIR/autumn" ;;
                12|01|02) collection_dir="$COLLECTIONS_DIR/winter" ;;
            esac
            ;;
        *)
            collection_dir="$COLLECTIONS_DIR/$criteria"
            ;;
    esac
    
    # Find candidates
    if [[ -d "$collection_dir" ]]; then
        while IFS= read -r -d '' file; do
            candidates+=("$file")
        done < <(find "$collection_dir" -type f $$ -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" -o -name "*.webp" $$ -print0)
    fi
    
    # Fallback to all wallpapers if no candidates
    if [[ ${#candidates[@]} -eq 0 ]]; then
        while IFS= read -r -d '' file; do
            candidates+=("$file")
        done < <(find "$WALLPAPER_DIR" -type f $$ -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" -o -name "*.webp" $$ -print0)
    fi
    
    # Select based on rating and usage history
    if [[ ${#candidates[@]} -gt 0 ]]; then
        local selected_wallpaper=""
        local best_score=0
        
        for wallpaper in "${candidates[@]}"; do
            local score=0
            local metadata_file="${wallpaper%.*}.meta"
            
            if [[ -f "$metadata_file" ]]; then
                local rating=$(grep "^rating=" "$metadata_file" | cut -d'=' -f2)
                local views=$(grep "^views=" "$metadata_file" | cut -d'=' -f2)
                local last_used=$(grep "^last_used=" "$metadata_file" | cut -d'=' -f2)
                
                # Calculate score (higher rating, lower recent usage)
                score=$((rating * 10))
                if [[ "$last_used" != "never" ]]; then
                    local days_since=$(( ($(date +%s) - $(date -d "$last_used" +%s)) / 86400 ))
                    score=$((score + days_since))
                fi
                score=$((score - views))
            else
                score=$((RANDOM % 100))
            fi
            
            if [[ $score -gt $best_score ]]; then
                best_score=$score
                selected_wallpaper="$wallpaper"
            fi
        done
        
        echo "$selected_wallpaper"
    fi
}

# Set wallpaper and update metadata
set_wallpaper() {
    local wallpaper="$1"
    
    if [[ ! -f "$wallpaper" ]]; then
        log "Error: Wallpaper file not found: $wallpaper"
        return 1
    fi
    
    # Set wallpaper using multiple methods
    if command -v nitrogen &> /dev/null; then
        nitrogen --set-zoom-fill "$wallpaper"
        nitrogen --save
    elif command -v feh &> /dev/null; then
        feh --bg-fill "$wallpaper"
    fi
    
    # Update metadata
    local metadata_file="${wallpaper%.*}.meta"
    if [[ -f "$metadata_file" ]]; then
        sed -i "s/^last_used=.*/last_used=$(date '+%Y-%m-%d %H:%M:%S')/" "$metadata_file"
        local views=$(grep "^views=" "$metadata_file" | cut -d'=' -f2)
        sed -i "s/^views=.*/views=$((views + 1))/" "$metadata_file"
    fi
    
    # Add to history
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $(basename "$wallpaper")" >> "$HISTORY_FILE"
    
    # Trigger pywal if available
    if command -v wal &> /dev/null; then
        wal -i "$wallpaper" -n -q
    fi
    
    log "Set wallpaper: $(basename "$wallpaper")"
    
    if [[ "$NOTIFICATION_ENABLED" == "true" ]]; then
        notify-send "duke pan's Wallpaper Manager" "Set wallpaper: $(basename "$wallpaper")" -t 3000
    fi
}

# Add wallpaper to favorites
add_favorite() {
    local wallpaper="$1"
    
    if ! grep -q "$wallpaper" "$FAVORITES_FILE"; then
        echo "$wallpaper" >> "$FAVORITES_FILE"
        log "Added to favorites: $(basename "$wallpaper")"
        
        # Update rating
        local metadata_file="${wallpaper%.*}.meta"
        if [[ -f "$metadata_file" ]]; then
            local rating=$(grep "^rating=" "$metadata_file" | cut -d'=' -f2)
            sed -i "s/^rating=.*/rating=$((rating + 1))/" "$metadata_file"
        fi
    fi
}

# Rate wallpaper
rate_wallpaper() {
    local wallpaper="$1"
    local rating="$2"
    
    if [[ $rating -lt 1 || $rating -gt 5 ]]; then
        log "Error: Rating must be between 1 and 5"
        return 1
    fi
    
    local metadata_file="${wallpaper%.*}.meta"
    if [[ -f "$metadata_file" ]]; then
        sed -i "s/^rating=.*/rating=$rating/" "$metadata_file"
        log "Rated $(basename "$wallpaper"): $rating stars"
    fi
}

# Show wallpaper statistics
show_stats() {
    echo "duke pan's Wallpaper Collection Statistics"
    echo "========================================"
    echo
    
    local total_wallpapers=$(find "$WALLPAPER_DIR" -type f $$ -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" -o -name "*.webp" $$ | wc -l)
    local total_collections=$(find "$COLLECTIONS_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)
    local favorites_count=$(wc -l < "$FAVORITES_FILE")
    local history_count=$(wc -l < "$HISTORY_FILE")
    
    echo "Total wallpapers: $total_wallpapers"
    echo "Collections: $total_collections"
    echo "Favorites: $favorites_count"
    echo "History entries: $history_count"
    echo
    
    echo "Collection breakdown:"
    for collection in "$COLLECTIONS_DIR"/*; do
        if [[ -d "$collection" ]]; then
            local count=$(find "$collection" -type f $$ -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" -o -name "*.webp" $$ | wc -l)
            echo "  $(basename "$collection"): $count wallpapers"
        fi
    done
    
    echo
    echo "Top rated wallpapers:"
    find "$WALLPAPER_DIR" -name "*.meta" -exec grep -l "rating=[4-5]" {} \; | head -5 | while read -r meta; do
        local wallpaper="${meta%.*}"
        local rating=$(grep "^rating=" "$meta" | cut -d'=' -f2)
        echo "  $(basename "$wallpaper") - $rating stars"
    done
}

# Main CLI interface
main() {
    case "${1:-help}" in
        "download")
            init_system
            if [[ $# -lt 2 ]]; then
                echo "Available sources: ${!WALLPAPER_SOURCES[*]}"
                echo "Usage: $0 download <source_name>"
                exit 1
            fi
            download_collections "$2"
            ;;
        "download-all")
            init_system
            for source in "${!WALLPAPER_SOURCES[@]}"; do
                download_collections "$source"
            done
            ;;
        "set")
            init_system
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 set <wallpaper_path>"
                exit 1
            fi
            set_wallpaper "$2"
            ;;
        "smart-set")
            init_system
            local criteria="${2:-time-based}"
            local wallpaper=$(smart_select "$criteria")
            if [[ -n "$wallpaper" ]]; then
                set_wallpaper "$wallpaper"
            else
                log "No suitable wallpaper found for criteria: $criteria"
            fi
            ;;
        "favorite")
            init_system
            if [[ $# -lt 2 ]]; then
                echo "Usage: $0 favorite <wallpaper_path>"
                exit 1
            fi
            add_favorite "$2"
            ;;
        "rate")
            init_system
            if [[ $# -lt 3 ]]; then
                echo "Usage: $0 rate <wallpaper_path> <rating_1-5>"
                exit 1
            fi
            rate_wallpaper "$2" "$3"
            ;;
        "stats")
            init_system
            show_stats
            ;;
        "organize")
            init_system
            process_wallpapers "$WALLPAPER_DIR"
            ;;
        "random")
            init_system
            local wallpaper=$(smart_select "minimal")
            if [[ -n "$wallpaper" ]]; then
                set_wallpaper "$wallpaper"
            fi
            ;;
        "help"|*)
            cat << EOF
duke pan's Ultimate Wallpaper Manager

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    download <source>       Download wallpaper collection
    download-all           Download all available collections
    set <path>             Set specific wallpaper
    smart-set <criteria>   Set wallpaper based on criteria
    favorite <path>        Add wallpaper to favorites
    rate <path> <1-5>      Rate wallpaper
    stats                  Show collection statistics
    organize               Organize existing wallpapers
    random                 Set random wallpaper
    help                   Show this help

Smart selection criteria:
    time-based, weather-based, mood-based, seasonal
    Or any collection name: ${!COLLECTION_THEMES[*]}

Available sources: ${!WALLPAPER_SOURCES[*]}
EOF
            ;;
    esac
}

# Execute main function
main "$@"
