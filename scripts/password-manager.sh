#!/usr/bin/env bash
# =====================================================
# Advanced Password Manager for duke pan's i3 rice
# Secure password management with biometric unlock
# =====================================================

set -euo pipefail

# Configuration
PASS_STORE_DIR="${PASSWORD_STORE_DIR:-$HOME/.password-store}"
CONFIG_DIR="$HOME/.config/password-manager"
CACHE_DIR="$HOME/.cache/password-manager"
CONFIG_FILE="$CONFIG_DIR/config.conf"
SESSION_FILE="$CACHE_DIR/session"
BIOMETRIC_CACHE="$CACHE_DIR/biometric"

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
mkdir -p "$CONFIG_DIR" "$CACHE_DIR"

# Initialize configuration
init_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Password Manager Configuration for duke pan
BIOMETRIC_ENABLED=true
BIOMETRIC_DEVICE="/dev/input/by-id/usb-fingerprint-reader"
SESSION_TIMEOUT=900
AUTO_CLEAR_CLIPBOARD=30
BACKUP_ENABLED=true
BACKUP_LOCATION="$HOME/Backups/passwords"
SYNC_ENABLED=false
SYNC_REMOTE=""
GENERATE_LENGTH=20
GENERATE_SYMBOLS=true
GENERATE_NUMBERS=true
SHOW_PASSWORDS=false
ROFI_THEME="password-manager"
EOF
    fi
    source "$CONFIG_FILE"
}

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$CACHE_DIR/manager.log"
}

# Notification function
notify() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"
    local icon="${4:-dialog-password}"
    
    notify-send -u "$urgency" -i "$icon" -a "Password Manager" "$title" "$message"
}

# Check if pass is initialized
check_pass_init() {
    if [[ ! -d "$PASS_STORE_DIR" ]]; then
        notify "Setup Required" "Password store not initialized" "critical"
        return 1
    fi
    return 0
}

# Biometric authentication
biometric_auth() {
    if [[ "$BIOMETRIC_ENABLED" != "true" ]]; then
        return 1
    fi
    
    # Check if biometric device exists
    if [[ ! -e "$BIOMETRIC_DEVICE" ]]; then
        log "Biometric device not found: $BIOMETRIC_DEVICE"
        return 1
    fi
    
    # Check cached biometric session
    if [[ -f "$BIOMETRIC_CACHE" ]]; then
        local cache_time=$(stat -c %Y "$BIOMETRIC_CACHE")
        local current_time=$(date +%s)
        local age=$((current_time - cache_time))
        
        if [[ $age -lt $SESSION_TIMEOUT ]]; then
            return 0
        fi
    fi
    
    # Perform biometric authentication
    if command -v fprintd-verify >/dev/null; then
        if fprintd-verify 2>/dev/null; then
            touch "$BIOMETRIC_CACHE"
            log "Biometric authentication successful"
            return 0
        else
            log "Biometric authentication failed"
            return 1
        fi
    fi
    
    return 1
}

# Master password authentication
master_auth() {
    local password
    password=$(rofi -dmenu -password -p "Master Password" -theme-str "
        window { width: 400px; }
        entry { placeholder: \"Enter master password...\"; }
    ")
    
    if [[ -z "$password" ]]; then
        return 1
    fi
    
    # Test password with a dummy operation
    if echo "test" | gpg --batch --yes --passphrase "$password" --symmetric --cipher-algo AES256 -o /dev/null 2>/dev/null; then
        echo "$password" > "$SESSION_FILE"
        chmod 600 "$SESSION_FILE"
        log "Master password authentication successful"
        return 0
    else
        notify "Authentication Failed" "Invalid master password" "critical"
        return 1
    fi
}

# Authenticate user
authenticate() {
    # Check existing session
    if [[ -f "$SESSION_FILE" ]]; then
        local session_time=$(stat -c %Y "$SESSION_FILE")
        local current_time=$(date +%s)
        local age=$((current_time - session_time))
        
        if [[ $age -lt $SESSION_TIMEOUT ]]; then
            return 0
        else
            rm -f "$SESSION_FILE"
        fi
    fi
    
    # Try biometric first
    if biometric_auth; then
        touch "$SESSION_FILE"
        return 0
    fi
    
    # Fall back to master password
    return master_auth
}

# List passwords
list_passwords() {
    if ! check_pass_init; then
        return 1
    fi
    
    find "$PASS_STORE_DIR" -name "*.gpg" -type f | \
        sed "s|$PASS_STORE_DIR/||g" | \
        sed 's|\.gpg$||g' | \
        sort
}

# Search passwords
search_passwords() {
    local query="$1"
    list_passwords | grep -i "$query"
}

# Get password
get_password() {
    local entry="$1"
    local show_password="${2:-false}"
    
    if ! authenticate; then
        return 1
    fi
    
    local password
    password=$(pass show "$entry" 2>/dev/null | head -n1)
    
    if [[ -z "$password" ]]; then
        notify "Error" "Password not found: $entry" "critical"
        return 1
    fi
    
    if [[ "$show_password" == "true" || "$SHOW_PASSWORDS" == "true" ]]; then
        echo "$password" | rofi -dmenu -p "Password for $entry" -theme-str "
            window { width: 500px; }
            entry { placeholder: \"Password (click to copy)\"; }
        "
    else
        # Copy to clipboard
        echo "$password" | xclip -selection clipboard
        notify "Password Copied" "Password for $entry copied to clipboard"
        
        # Auto-clear clipboard
        if [[ "$AUTO_CLEAR_CLIPBOARD" -gt 0 ]]; then
            (sleep "$AUTO_CLEAR_CLIPBOARD" && echo "" | xclip -selection clipboard) &
        fi
    fi
    
    log "Retrieved password for: $entry"
}

# Generate password
generate_password() {
    local length="${1:-$GENERATE_LENGTH}"
    local use_symbols="${2:-$GENERATE_SYMBOLS}"
    local use_numbers="${3:-$GENERATE_NUMBERS}"
    
    local chars="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    
    if [[ "$use_numbers" == "true" ]]; then
        chars="${chars}0123456789"
    fi
    
    if [[ "$use_symbols" == "true" ]]; then
        chars="${chars}!@#$%^&*()_+-=[]{}|;:,.<>?"
    fi
    
    local password=""
    for ((i=0; i<length; i++)); do
        password="${password}${chars:$((RANDOM % ${#chars})):1}"
    done
    
    echo "$password"
}

# Add password
add_password() {
    local entry="$1"
    local password="$2"
    local generate="${3:-false}"
    
    if ! authenticate; then
        return 1
    fi
    
    if [[ "$generate" == "true" ]]; then
        password=$(generate_password)
    fi
    
    if [[ -z "$password" ]]; then
        password=$(rofi -dmenu -password -p "Password for $entry" -theme-str "
            window { width: 500px; }
            entry { placeholder: \"Enter password...\"; }
        ")
    fi
    
    if [[ -z "$password" ]]; then
        return 1
    fi
    
    # Add additional fields
    local username
    username=$(rofi -dmenu -p "Username (optional)" -theme-str "window { width: 400px; }")
    
    local url
    url=$(rofi -dmenu -p "URL (optional)" -theme-str "window { width: 400px; }")
    
    local notes
    notes=$(rofi -dmenu -p "Notes (optional)" -theme-str "window { width: 400px; }")
    
    # Create password entry
    local entry_content="$password"
    if [[ -n "$username" ]]; then
        entry_content="$entry_content
username: $username"
    fi
    if [[ -n "$url" ]]; then
        entry_content="$entry_content
url: $url"
    fi
    if [[ -n "$notes" ]]; then
        entry_content="$entry_content
notes: $notes"
    fi
    
    echo "$entry_content" | pass insert -m "$entry"
    
    notify "Password Added" "Added password for: $entry"
    log "Added password for: $entry"
}

# Edit password
edit_password() {
    local entry="$1"
    
    if ! authenticate; then
        return 1
    fi
    
    pass edit "$entry"
    log "Edited password for: $entry"
}

# Delete password
delete_password() {
    local entry="$1"
    
    if ! authenticate; then
        return 1
    fi
    
    local confirm
    confirm=$(echo -e "Yes\nNo" | rofi -dmenu -p "Delete $entry?" -theme-str "window { width: 400px; }")
    
    if [[ "$confirm" == "Yes" ]]; then
        pass rm "$entry"
        notify "Password Deleted" "Deleted password for: $entry"
        log "Deleted password for: $entry"
    fi
}

# Show password manager menu
show_password_menu() {
    if ! check_pass_init; then
        setup_password_store
        return
    fi
    
    local passwords
    passwords=$(list_passwords)
    
    if [[ -z "$passwords" ]]; then
        passwords="No passwords stored"
    fi
    
    local header="🔐 duke pan's Password Manager - $(echo "$passwords" | wc -l) entries"
    
    local choice
    choice=$(echo -e "$passwords" | rofi \
        -dmenu \
        -i \
        -p "Passwords" \
        -mesg "$header" \
        -theme-str "
            window { width: 800px; }
            listview { lines: 15; }
            element { padding: 8px; }
            element selected { background-color: ${COLORS[primary]}; }
        " \
        -kb-custom-1 "ctrl+n" \
        -kb-custom-2 "ctrl+g" \
        -kb-custom-3 "ctrl+s" \
        -kb-custom-4 "ctrl+b" \
        -kb-custom-5 "ctrl+e" \
        -kb-custom-6 "ctrl+d" \
        -kb-custom-7 "ctrl+f" \
        -format 'i:s')
    
    local exit_code=$?
    case $exit_code in
        10) add_password_dialog ;;         # Ctrl+N - New password
        11) generate_password_dialog ;;    # Ctrl+G - Generate password
        12) search_dialog ;;               # Ctrl+S - Search
        13) backup_passwords ;;            # Ctrl+B - Backup
        14) edit_password "$choice" ;;     # Ctrl+E - Edit
        15) delete_password "$choice" ;;   # Ctrl+D - Delete
        16) find_dialog ;;                 # Ctrl+F - Find
        0)
            if [[ -n "$choice" && "$choice" != "No passwords stored" ]]; then
                password_actions_menu "$choice"
            fi
            ;;
    esac
}

# Password actions menu
password_actions_menu() {
    local entry="$1"
    
    local actions=(
        "📋 Copy Password"
        "👁️ Show Password"
        "📝 Edit Entry"
        "🗑️ Delete Entry"
        "ℹ️ Show Details"
        "🔄 Generate New"
    )
    
    local choice
    choice=$(printf '%s\n' "${actions[@]}" | rofi -dmenu -p "Actions for $entry")
    
    case "$choice" in
        "📋 Copy Password")
            get_password "$entry" false
            ;;
        "👁️ Show Password")
            get_password "$entry" true
            ;;
        "📝 Edit Entry")
            edit_password "$entry"
            ;;
        "🗑️ Delete Entry")
            delete_password "$entry"
            ;;
        "ℹ️ Show Details")
            show_password_details "$entry"
            ;;
        "🔄 Generate New")
            local new_password
            new_password=$(generate_password)
            add_password "$entry" "$new_password"
            ;;
    esac
}

# Show password details
show_password_details() {
    local entry="$1"
    
    if ! authenticate; then
        return 1
    fi
    
    local details
    details=$(pass show "$entry" 2>/dev/null)
    
    if [[ -z "$details" ]]; then
        notify "Error" "Password not found: $entry" "critical"
        return 1
    fi
    
    # Hide the actual password
    local safe_details
    safe_details=$(echo "$details" | sed '1s/.*/[PASSWORD HIDDEN]/')
    
    echo -e "$safe_details" | rofi -dmenu -p "Details for $entry" -theme-str "
        window { width: 600px; }
        listview { lines: 10; }
    "
}

# Add password dialog
add_password_dialog() {
    local entry
    entry=$(rofi -dmenu -p "Entry Name" -theme-str "window { width: 500px; }")
    
    if [[ -z "$entry" ]]; then
        return
    fi
    
    local method
    method=$(echo -e "Enter Password\nGenerate Password" | rofi -dmenu -p "Password Method")
    
    case "$method" in
        "Enter Password")
            add_password "$entry" "" false
            ;;
        "Generate Password")
            add_password "$entry" "" true
            ;;
    esac
}

# Generate password dialog
generate_password_dialog() {
    local length
    length=$(echo -e "12\n16\n20\n24\n32" | rofi -dmenu -p "Password Length")
    
    if [[ -z "$length" ]]; then
        length=20
    fi
    
    local use_symbols
    use_symbols=$(echo -e "Yes\nNo" | rofi -dmenu -p "Include Symbols?")
    use_symbols=$([ "$use_symbols" = "Yes" ] && echo "true" || echo "false")
    
    local use_numbers
    use_numbers=$(echo -e "Yes\nNo" | rofi -dmenu -p "Include Numbers?")
    use_numbers=$([ "$use_numbers" = "Yes" ] && echo "true" || echo "false")
    
    local password
    password=$(generate_password "$length" "$use_symbols" "$use_numbers")
    
    echo "$password" | rofi -dmenu -p "Generated Password" -theme-str "
        window { width: 600px; }
        entry { placeholder: \"Click to copy to clipboard\"; }
    "
    
    echo "$password" | xclip -selection clipboard
    notify "Password Generated" "Generated password copied to clipboard"
}

# Search dialog
search_dialog() {
    local query
    query=$(rofi -dmenu -p "Search Passwords" -theme-str "window { width: 500px; }")
    
    if [[ -z "$query" ]]; then
        return
    fi
    
    local results
    results=$(search_passwords "$query")
    
    if [[ -z "$results" ]]; then
        notify "Search Results" "No passwords found matching: $query"
        return
    fi
    
    local choice
    choice=$(echo -e "$results" | rofi -dmenu -p "Search Results")
    
    if [[ -n "$choice" ]]; then
        password_actions_menu "$choice"
    fi
}

# Backup passwords
backup_passwords() {
    if [[ "$BACKUP_ENABLED" != "true" ]]; then
        notify "Backup Disabled" "Backup is not enabled in configuration"
        return 1
    fi
    
    local backup_dir="$BACKUP_LOCATION"
    local backup_file="$backup_dir/passwords-backup-$(date '+%Y%m%d-%H%M%S').tar.gz.gpg"
    
    mkdir -p "$backup_dir"
    
    if tar -czf - -C "$(dirname "$PASS_STORE_DIR")" "$(basename "$PASS_STORE_DIR")" | \
       gpg --symmetric --cipher-algo AES256 --output "$backup_file"; then
        notify "Backup Complete" "Passwords backed up to $backup_file"
        log "Created backup: $backup_file"
    else
        notify "Backup Failed" "Failed to create password backup" "critical"
        return 1
    fi
}

# Setup password store
setup_password_store() {
    local options=(
        "🔧 Initialize New Store"
        "📥 Import Existing Store"
        "🔑 Setup GPG Key"
        "📖 Help"
    )
    
    local choice
    choice=$(printf '%s\n' "${options[@]}" | rofi -dmenu -p "Password Store Setup")
    
    case "$choice" in
        "🔧 Initialize New Store")
            init_new_store
            ;;
        "📥 Import Existing Store")
            import_store
            ;;
        "🔑 Setup GPG Key")
            setup_gpg_key
            ;;
        "📖 Help")
            show_help
            ;;
    esac
}

# Initialize new password store
init_new_store() {
    local email
    email=$(rofi -dmenu -p "GPG Email" -theme-str "window { width: 500px; }")
    
    if [[ -n "$email" ]]; then
        pass init "$email"
        notify "Store Initialized" "Password store initialized with $email"
        log "Initialized password store with $email"
    fi
}

# Setup GPG key
setup_gpg_key() {
    alacritty -e bash -c "
        echo 'Setting up GPG key for duke pan...'
        gpg --full-generate-key
        echo 'GPG key setup complete. Press any key to continue...'
        read -n 1
    "
}

# Show help
show_help() {
    local help_text="🔐 Password Manager Help

Keyboard Shortcuts:
• Ctrl+N: Add new password
• Ctrl+G: Generate password
• Ctrl+S: Search passwords
• Ctrl+B: Backup passwords
• Ctrl+E: Edit selected entry
• Ctrl+D: Delete selected entry

Features:
• Biometric authentication
• Secure password generation
• Automatic clipboard clearing
• Encrypted backups
• Search and organization

Setup:
1. Install 'pass' and 'gpg'
2. Generate GPG key
3. Initialize password store
4. Configure biometric device (optional)

For more help, visit: https://www.passwordstore.org/"
    
    echo -e "$help_text" | rofi -dmenu -p "Help" -theme-str "
        window { width: 800px; }
        listview { lines: 20; }
    "
}

# Main function
main() {
    init_config
    
    case "${1:-menu}" in
        "get")
            get_password "${2:-}" "${3:-false}"
            ;;
        "add")
            add_password "${2:-}" "${3:-}" "${4:-false}"
            ;;
        "list")
            list_passwords
            ;;
        "search")
            search_passwords "${2:-}"
            ;;
        "generate")
            generate_password "${2:-20}" "${3:-true}" "${4:-true}"
            ;;
        "backup")
            backup_passwords
            ;;
        "setup")
            setup_password_store
            ;;
        "menu")
            show_password_menu
            ;;
        *)
            echo "Usage: $0 {get|add|list|search|generate|backup|setup|menu}"
            exit 1
            ;;
    esac
}

main "$@"
