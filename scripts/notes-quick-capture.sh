#!/usr/bin/env bash
# =====================================================
# Quick Note Capture for duke pan's i3 rice
# Instant note creation with minimal friction
# =====================================================

set -euo pipefail

NOTES_DIR="$HOME/Documents/Notes/quick"
mkdir -p "$NOTES_DIR"

# Quick capture dialog
quick_note=$(rofi -dmenu -p "Quick Note" -theme-str "
    window { width: 600px; height: 200px; }
    entry { placeholder: \"Type your quick note here...\"; }
")

if [[ -n "$quick_note" ]]; then
    # Create timestamped note
    timestamp=$(date '+%Y%m%d-%H%M%S')
    filename="$NOTES_DIR/quick-$timestamp.md"
    
    cat > "$filename" << EOF
# Quick Note - $(date '+%Y-%m-%d %H:%M')

$quick_note

---
*Quick capture by duke pan's notes system*
EOF
    
    notify-send -u low -i text-editor "Quick Note" "Note saved successfully"
    
    # Ask if user wants to expand the note
    if rofi -dmenu -p "Expand note?" -theme-str "window { width: 300px; }" <<< $'Yes\nNo' | grep -q "Yes"; then
        alacritty -e nvim "$filename"
    fi
fi
