#!/usr/bin/env bash
# =====================================================
# Advanced Note-Taking System for duke pan's i3 rice
# Markdown support with sync capabilities and search
# =====================================================

set -euo pipefail

# Configuration
NOTES_DIR="$HOME/Documents/Notes"
NOTES_CONFIG="$HOME/.config/notes/config.conf"
NOTES_CACHE="$HOME/.cache/notes"
SYNC_LOG="$NOTES_CACHE/sync.log"
SEARCH_INDEX="$NOTES_CACHE/search_index"

# Colors (Catppuccin Mocha)
declare -A COLORS=(
    [primary]="#cba6f7"
    [secondary]="#89b4fa"
    [success]="#a6e3a1"
    [warning]="#f9e2af"
    [error]="#f38ba8"
    [text]="#cdd6f4"
    [surface]="#313244"
    [base]="#1e1e2e"
)

# Create directories
mkdir -p "$NOTES_DIR" "$NOTES_CACHE" "$(dirname "$NOTES_CONFIG")"

# Initialize configuration
init_config() {
    if [[ ! -f "$NOTES_CONFIG" ]]; then
        cat > "$NOTES_CONFIG" << 'EOF'
# Notes Configuration for duke pan
EDITOR="alacritty -e nvim"
SYNC_ENABLED=true
SYNC_REMOTE=""
SYNC_INTERVAL=300
AUTO_BACKUP=true
BACKUP_COUNT=10
MARKDOWN_PREVIEW=true
SEARCH_FUZZY=true
TAGS_ENABLED=true
ENCRYPTION_ENABLED=false
EOF
    fi
    source "$NOTES_CONFIG"
}

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$SYNC_LOG"
}

# Notification function
notify() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"
    local icon="${4:-text-editor}"
    
    notify-send -u "$urgency" -i "$icon" -a "Notes" "$title" "$message"
}

# Create new note
create_note() {
    local title="$1"
    local category="${2:-general}"
    local template="${3:-default}"
    
    # Sanitize filename
    local filename=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')
    local filepath="$NOTES_DIR/$category/${filename}.md"
    
    # Create category directory
    mkdir -p "$NOTES_DIR/$category"
    
    # Create note from template
    case "$template" in
        "meeting")
            cat > "$filepath" << EOF
# $title

**Date:** $(date '+%Y-%m-%d')
**Time:** $(date '+%H:%M')
**Attendees:** 

## Agenda
- 

## Notes


## Action Items
- [ ] 

## Follow-up


---
*Created by duke pan's notes system*
EOF
            ;;
        "project")
            cat > "$filepath" << EOF
# $title

**Status:** Planning
**Priority:** Medium
**Due Date:** 
**Tags:** #project

## Overview


## Goals
- 

## Tasks
- [ ] 

## Resources


## Notes


---
*Created by duke pan's notes system*
EOF
            ;;
        "daily")
            cat > "$filepath" << EOF
# Daily Note - $(date '+%Y-%m-%d')

## Today's Goals
- 

## Completed
- [ ] 

## Notes


## Tomorrow
- 

---
*Created by duke pan's notes system*
EOF
            ;;
        *)
            cat > "$filepath" << EOF
# $title

**Created:** $(date '+%Y-%m-%d %H:%M')
**Tags:** 

## Content


---
*Created by duke pan's notes system*
EOF
            ;;
    esac
    
    log "Created note: $filepath"
    notify "Note Created" "Created: $title"
    
    # Open in editor
    if [[ -n "${EDITOR:-}" ]]; then
        $EDITOR "$filepath"
    fi
    
    # Update search index
    update_search_index
}

# List notes
list_notes() {
    local category="${1:-}"
    local format="${2:-simple}"
    
    local find_path="$NOTES_DIR"
    if [[ -n "$category" ]]; then
        find_path="$NOTES_DIR/$category"
    fi
    
    if [[ ! -d "$find_path" ]]; then
        echo "No notes found"
        return
    fi
    
    case "$format" in
        "detailed")
            find "$find_path" -name "*.md" -type f | while read -r file; do
                local title=$(head -n1 "$file" | sed 's/^# //')
                local modified=$(date -r "$file" '+%Y-%m-%d %H:%M')
                local size=$(du -h "$file" | cut -f1)
                local category=$(basename "$(dirname "$file")")
                echo "[$category] $title ($size, $modified)"
            done | sort
            ;;
        "tree")
            tree "$NOTES_DIR" -I "*.tmp|*.bak"
            ;;
        *)
            find "$find_path" -name "*.md" -type f | while read -r file; do
                local title=$(head -n1 "$file" | sed 's/^# //')
                local category=$(basename "$(dirname "$file")")
                echo "[$category] $title"
            done | sort
            ;;
    esac
}

# Search notes
search_notes() {
    local query="$1"
    local search_type="${2:-content}"
    
    case "$search_type" in
        "title")
            find "$NOTES_DIR" -name "*.md" -type f | while read -r file; do
                local title=$(head -n1 "$file" | sed 's/^# //')
                if echo "$title" | grep -qi "$query"; then
                    local category=$(basename "$(dirname "$file")")
                    echo "[$category] $title"
                fi
            done
            ;;
        "tags")
            grep -r "Tags:.*$query" "$NOTES_DIR" --include="*.md" | while IFS: read -r file _; do
                local title=$(head -n1 "$file" | sed 's/^# //')
                local category=$(basename "$(dirname "$file")")
                echo "[$category] $title"
            done
            ;;
        *)
            if [[ "$SEARCH_FUZZY" == "true" ]]; then
                grep -r -i "$query" "$NOTES_DIR" --include="*.md" | while IFS: read -r file _; do
                    local title=$(head -n1 "$file" | sed 's/^# //')
                    local category=$(basename "$(dirname "$file")")
                    echo "[$category] $title"
                done | sort -u
            else
                grep -r "$query" "$NOTES_DIR" --include="*.md" | while IFS: read -r file _; do
                    local title=$(head -n1 "$file" | sed 's/^# //')
                    local category=$(basename "$(dirname "$file")")
                    echo "[$category] $title"
                done | sort -u
            fi
            ;;
    esac
}

# Update search index
update_search_index() {
    log "Updating search index..."
    
    find "$NOTES_DIR" -name "*.md" -type f | while read -r file; do
        local title=$(head -n1 "$file" | sed 's/^# //')
        local category=$(basename "$(dirname "$file")")
        local content=$(cat "$file")
        local modified=$(date -r "$file" '+%s')
        
        echo "$file|$title|$category|$modified|$content"
    done > "$SEARCH_INDEX"
    
    log "Search index updated"
}

# Sync notes
sync_notes() {
    if [[ "$SYNC_ENABLED" != "true" || -z "$SYNC_REMOTE" ]]; then
        log "Sync not configured"
        return 1
    fi
    
    log "Starting notes sync..."
    
    cd "$NOTES_DIR"
    
    # Initialize git if needed
    if [[ ! -d ".git" ]]; then
        git init
        git remote add origin "$SYNC_REMOTE"
    fi
    
    # Commit changes
    git add .
    if git diff --staged --quiet; then
        log "No changes to sync"
        return 0
    fi
    
    git commit -m "Auto-sync notes - $(date '+%Y-%m-%d %H:%M:%S')"
    
    # Push to remote
    if git push origin main 2>/dev/null; then
        log "Notes synced successfully"
        notify "Notes Sync" "Successfully synced to remote" "low"
        return 0
    else
        log "Sync failed"
        notify "Sync Error" "Failed to sync notes" "critical"
        return 1
    fi
}

# Backup notes
backup_notes() {
    if [[ "$AUTO_BACKUP" != "true" ]]; then
        return 0
    fi
    
    local backup_dir="$NOTES_CACHE/backups"
    local backup_file="$backup_dir/notes-backup-$(date '+%Y%m%d-%H%M%S').tar.gz"
    
    mkdir -p "$backup_dir"
    
    tar -czf "$backup_file" -C "$(dirname "$NOTES_DIR")" "$(basename "$NOTES_DIR")"
    
    log "Created backup: $backup_file"
    
    # Clean old backups
    find "$backup_dir" -name "notes-backup-*.tar.gz" -type f | sort -r | tail -n +$((BACKUP_COUNT + 1)) | xargs rm -f
}

# Show notes in rofi
show_notes_menu() {
    local notes
    notes=$(list_notes "" "simple")
    
    if [[ -z "$notes" ]]; then
        notes="No notes found"
    fi
    
    local header="📝 duke pan's Notes - $(find "$NOTES_DIR" -name "*.md" | wc -l) notes"
    
    local choice
    choice=$(echo -e "$notes" | rofi \
        -dmenu \
        -i \
        -p "Notes" \
        -mesg "$header" \
        -theme-str "
            window { width: 900px; }
            listview { lines: 20; }
            element { padding: 8px; }
            element selected { background-color: ${COLORS[primary]}; }
        " \
        -kb-custom-1 "ctrl+n" \
        -kb-custom-2 "ctrl+s" \
        -kb-custom-3 "ctrl+f" \
        -kb-custom-4 "ctrl+b" \
        -kb-custom-5 "ctrl+r" \
        -format 'i:s')
    
    local exit_code=$?
    case $exit_code in
        10) create_note_dialog ;;      # Ctrl+N - New note
        11) search_dialog ;;           # Ctrl+S - Search
        12) find_dialog ;;             # Ctrl+F - Find
        13) backup_notes ;;            # Ctrl+B - Backup
        14) sync_notes ;;              # Ctrl+R - Sync
        0)
            if [[ -n "$choice" && "$choice" != "No notes found" ]]; then
                open_note "$choice"
            fi
            ;;
    esac
}

# Create note dialog
create_note_dialog() {
    local title
    title=$(echo "" | rofi -dmenu -p "Note Title" -theme-str "window { width: 500px; }")
    
    if [[ -z "$title" ]]; then
        return
    fi
    
    local categories=("general" "work" "personal" "projects" "meetings" "ideas" "daily")
    local category
    category=$(printf '%s\n' "${categories[@]}" | rofi -dmenu -p "Category")
    
    if [[ -z "$category" ]]; then
        category="general"
    fi
    
    local templates=("default" "meeting" "project" "daily")
    local template
    template=$(printf '%s\n' "${templates[@]}" | rofi -dmenu -p "Template")
    
    if [[ -z "$template" ]]; then
        template="default"
    fi
    
    create_note "$title" "$category" "$template"
}

# Search dialog
search_dialog() {
    local query
    query=$(echo "" | rofi -dmenu -p "Search Query" -theme-str "window { width: 500px; }")
    
    if [[ -z "$query" ]]; then
        return
    fi
    
    local search_types=("content" "title" "tags")
    local search_type
    search_type=$(printf '%s\n' "${search_types[@]}" | rofi -dmenu -p "Search Type")
    
    if [[ -z "$search_type" ]]; then
        search_type="content"
    fi
    
    local results
    results=$(search_notes "$query" "$search_type")
    
    if [[ -z "$results" ]]; then
        notify "Search Results" "No notes found matching: $query"
        return
    fi
    
    local choice
    choice=$(echo -e "$results" | rofi -dmenu -p "Search Results" -theme-str "window { width: 800px; }")
    
    if [[ -n "$choice" ]]; then
        open_note "$choice"
    fi
}

# Find dialog
find_dialog() {
    local categories
    categories=$(find "$NOTES_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)
    
    local category
    category=$(echo -e "$categories" | rofi -dmenu -p "Browse Category")
    
    if [[ -n "$category" ]]; then
        local notes
        notes=$(list_notes "$category" "simple")
        
        local choice
        choice=$(echo -e "$notes" | rofi -dmenu -p "Notes in $category")
        
        if [[ -n "$choice" ]]; then
            open_note "$choice"
        fi
    fi
}

# Open note
open_note() {
    local note_info="$1"
    local category=$(echo "$note_info" | sed 's/^\[$$[^]]*$$\].*/\1/')
    local title=$(echo "$note_info" | sed 's/^\[[^]]*\] //')
    
    # Find the actual file
    local file
    file=$(find "$NOTES_DIR/$category" -name "*.md" -type f | while read -r f; do
        local file_title=$(head -n1 "$f" | sed 's/^# //')
        if [[ "$file_title" == "$title" ]]; then
            echo "$f"
            break
        fi
    done)
    
    if [[ -n "$file" && -f "$file" ]]; then
        log "Opening note: $file"
        
        if [[ -n "${EDITOR:-}" ]]; then
            $EDITOR "$file"
        else
            alacritty -e nvim "$file"
        fi
        
        # Update search index after editing
        update_search_index
    else
        notify "Error" "Note not found: $title" "critical"
    fi
}

# Export notes
export_notes() {
    local format="${1:-html}"
    local output_dir="$NOTES_CACHE/exports"
    
    mkdir -p "$output_dir"
    
    case "$format" in
        "html")
            find "$NOTES_DIR" -name "*.md" -type f | while read -r file; do
                local basename=$(basename "$file" .md)
                local category=$(basename "$(dirname "$file")")
                local output_file="$output_dir/${category}-${basename}.html"
                
                if command -v pandoc >/dev/null; then
                    pandoc "$file" -o "$output_file" --standalone --css=style.css
                else
                    # Simple markdown to HTML conversion
                    markdown "$file" > "$output_file" 2>/dev/null || cp "$file" "$output_file"
                fi
            done
            ;;
        "pdf")
            if command -v pandoc >/dev/null; then
                find "$NOTES_DIR" -name "*.md" -type f | while read -r file; do
                    local basename=$(basename "$file" .md)
                    local category=$(basename "$(dirname "$file")")
                    local output_file="$output_dir/${category}-${basename}.pdf"
                    pandoc "$file" -o "$output_file"
                done
            else
                notify "Export Error" "pandoc required for PDF export" "critical"
                return 1
            fi
            ;;
    esac
    
    notify "Export Complete" "Notes exported to $output_dir"
    log "Exported notes to $output_dir in $format format"
}

# Statistics
show_stats() {
    local total_notes=$(find "$NOTES_DIR" -name "*.md" -type f | wc -l)
    local total_categories=$(find "$NOTES_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)
    local total_size=$(du -sh "$NOTES_DIR" | cut -f1)
    local recent_notes=$(find "$NOTES_DIR" -name "*.md" -type f -mtime -7 | wc -l)
    
    local stats="📊 Notes Statistics

Total Notes: $total_notes
Categories: $total_categories
Total Size: $total_size
Recent (7 days): $recent_notes

Top Categories:"
    
    find "$NOTES_DIR" -mindepth 2 -name "*.md" -type f | while read -r file; do
        basename "$(dirname "$file")"
    done | sort | uniq -c | sort -nr | head -5 | while read -r count category; do
        stats="$stats
  $category: $count notes"
    done
    
    echo -e "$stats" | rofi -dmenu -p "Statistics" -mesg "duke pan's Notes Statistics"
}

# Auto-sync daemon
start_sync_daemon() {
    if [[ "$SYNC_ENABLED" != "true" ]]; then
        return 0
    fi
    
    log "Starting notes sync daemon..."
    
    while true; do
        sync_notes
        backup_notes
        sleep "${SYNC_INTERVAL:-300}"
    done &
    
    echo $! > "$NOTES_CACHE/sync_daemon.pid"
    log "Sync daemon started with PID $(cat "$NOTES_CACHE/sync_daemon.pid")"
}

# Stop sync daemon
stop_sync_daemon() {
    if [[ -f "$NOTES_CACHE/sync_daemon.pid" ]]; then
        local pid
        pid=$(cat "$NOTES_CACHE/sync_daemon.pid")
        if kill "$pid" 2>/dev/null; then
            log "Sync daemon stopped"
            rm -f "$NOTES_CACHE/sync_daemon.pid"
        fi
    fi
}

# Main function
main() {
    init_config
    
    case "${1:-menu}" in
        "create")
            create_note "${2:-New Note}" "${3:-general}" "${4:-default}"
            ;;
        "list")
            list_notes "${2:-}" "${3:-simple}"
            ;;
        "search")
            search_notes "${2:-}" "${3:-content}"
            ;;
        "sync")
            sync_notes
            ;;
        "backup")
            backup_notes
            ;;
        "export")
            export_notes "${2:-html}"
            ;;
        "stats")
            show_stats
            ;;
        "daemon-start")
            start_sync_daemon
            ;;
        "daemon-stop")
            stop_sync_daemon
            ;;
        "index")
            update_search_index
            ;;
        "menu")
            show_notes_menu
            ;;
        *)
            echo "Usage: $0 {create|list|search|sync|backup|export|stats|daemon-start|daemon-stop|index|menu}"
            exit 1
            ;;
    esac
}

main "$@"
