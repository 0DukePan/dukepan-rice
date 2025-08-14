#!/usr/bin/env bash

# =====================================================
# Enhanced Power Menu Script - Perfect i3 Rice
# Advanced power management with confirmations and system info
# =====================================================

# Configuration
ROFI_THEME="$HOME/.config/rofi/themes/powermenu.rasi"
CONFIRM_ACTIONS=true
SHOW_SYSTEM_INFO=true
LOCK_COMMAND="i3lock-fancy"
SUSPEND_COMMAND="systemctl suspend"
HIBERNATE_COMMAND="systemctl hibernate"
REBOOT_COMMAND="systemctl reboot"
SHUTDOWN_COMMAND="systemctl poweroff"

# Colors (Catppuccin Mocha)
COLOR_BG="#1e1e2e"
COLOR_FG="#cdd6f4"
COLOR_URGENT="#f38ba8"
COLOR_ACTIVE="#cba6f7"
COLOR_SUCCESS="#a6e3a1"
COLOR_WARNING="#f9e2af"

# Icons
ICON_LOCK=""
ICON_LOGOUT=""
ICON_SUSPEND="⏾"
ICON_HIBERNATE="⏼"
ICON_REBOOT=""
ICON_SHUTDOWN=""
ICON_CANCEL=""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get system information
get_system_info() {
    local info=""
    
    # Uptime
    if command_exists uptime; then
        local uptime_info=$(uptime -p 2>/dev/null || uptime | sed 's/.*up //' | sed 's/,.*//')
        info+="Uptime: $uptime_info\n"
    fi
    
    # Battery status (if available)
    if [[ -d /sys/class/power_supply/BAT* ]]; then
        local battery_level=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1)
        local battery_status=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1)
        if [[ -n "$battery_level" ]]; then
            info+="Battery: $battery_level% ($battery_status)\n"
        fi
    fi
    
    # Load average
    if [[ -f /proc/loadavg ]]; then
        local load=$(cut -d' ' -f1-3 /proc/loadavg)
        info+="Load: $load\n"
    fi
    
    # Memory usage
    if command_exists free; then
        local mem_info=$(free -h | awk 'NR==2{printf "Memory: %s/%s (%.1f%%)", $3,$2,$3*100/$2}')
        info+="$mem_info\n"
    fi
    
    # Disk usage
    if command_exists df; then
        local disk_info=$(df -h / | awk 'NR==2{printf "Disk: %s/%s (%s)", $3,$2,$5}')
        info+="$disk_info\n"
    fi
    
    echo -e "$info"
}

# Function to show confirmation dialog
confirm_action() {
    local action="$1"
    local message="$2"
    
    if [[ "$CONFIRM_ACTIONS" != "true" ]]; then
        return 0
    fi
    
    local options="Yes\nNo"
    local chosen=$(echo -e "$options" | rofi -dmenu -i -p "$message" \
        -theme-str "window { width: 300px; }" \
        -theme-str "listview { lines: 2; }" \
        -theme "$ROFI_THEME")
    
    [[ "$chosen" == "Yes" ]]
}

# Function to execute lock command
execute_lock() {
    if command_exists i3lock-fancy; then
        i3lock-fancy -p
    elif command_exists i3lock; then
        # Create a simple lock screen with blur effect
        if command_exists scrot && command_exists convert; then
            local temp_img="/tmp/i3lock_screen.png"
            scrot "$temp_img"
            convert "$temp_img" -blur 0x5 "$temp_img"
            i3lock -i "$temp_img"
            rm -f "$temp_img"
        else
            i3lock -c "$COLOR_BG"
        fi
    else
        notify-send "Lock Error" "No lock command available"
        return 1
    fi
}

# Function to execute logout
execute_logout() {
    if confirm_action "logout" "Are you sure you want to logout?"; then
        if command_exists i3-msg; then
            i3-msg exit
        elif [[ -n "$DESKTOP_SESSION" ]]; then
            case "$DESKTOP_SESSION" in
                i3|i3wm)
                    i3-msg exit
                    ;;
                *)
                    loginctl terminate-session "$XDG_SESSION_ID"
                    ;;
            esac
        else
            pkill -TERM -u "$USER"
        fi
    fi
}

# Function to execute suspend
execute_suspend() {
    if confirm_action "suspend" "Are you sure you want to suspend?"; then
        # Lock screen before suspending
        execute_lock &
        sleep 1
        
        if command_exists systemctl; then
            systemctl suspend
        else
            echo mem > /sys/power/state
        fi
    fi
}

# Function to execute hibernate
execute_hibernate() {
    if confirm_action "hibernate" "Are you sure you want to hibernate?"; then
        # Check if hibernation is available
        if [[ ! -f /sys/power/state ]] || ! grep -q disk /sys/power/state; then
            notify-send "Hibernate Error" "Hibernation is not available on this system"
            return 1
        fi
        
        # Lock screen before hibernating
        execute_lock &
        sleep 1
        
        if command_exists systemctl; then
            systemctl hibernate
        else
            echo disk > /sys/power/state
        fi
    fi
}

# Function to execute reboot
execute_reboot() {
    if confirm_action "reboot" "Are you sure you want to reboot?"; then
        if command_exists systemctl; then
            systemctl reboot
        else
            reboot
        fi
    fi
}

# Function to execute shutdown
execute_shutdown() {
    if confirm_action "shutdown" "Are you sure you want to shutdown?"; then
        if command_exists systemctl; then
            systemctl poweroff
        else
            poweroff
        fi
    fi
}

# Function to show system information dialog
show_system_info() {
    local info=$(get_system_info)
    
    echo -e "$info" | rofi -dmenu -i -p "System Information" \
        -theme-str "window { width: 400px; }" \
        -theme-str "listview { lines: 10; }" \
        -theme-str "textbox-prompt-colon { str: \"\"; }" \
        -theme "$ROFI_THEME"
}

# Function to create main menu
create_main_menu() {
    local options=""
    
    # Lock
    options+="$ICON_LOCK Lock\n"
    
    # Logout
    options+="$ICON_LOGOUT Logout\n"
    
    # Suspend (if available)
    if [[ -f /sys/power/state ]] && grep -q mem /sys/power/state; then
        options+="$ICON_SUSPEND Suspend\n"
    fi
    
    # Hibernate (if available)
    if [[ -f /sys/power/state ]] && grep -q disk /sys/power/state; then
        options+="$ICON_HIBERNATE Hibernate\n"
    fi
    
    # Reboot
    options+="$ICON_REBOOT Reboot\n"
    
    # Shutdown
    options+="$ICON_SHUTDOWN Shutdown\n"
    
    # System info (if enabled)
    if [[ "$SHOW_SYSTEM_INFO" == "true" ]]; then
        options+=" System Info\n"
    fi
    
    # Cancel
    options+="$ICON_CANCEL Cancel"
    
    echo -e "$options"
}

# Function to handle menu selection
handle_selection() {
    local choice="$1"
    
    case "$choice" in
        "$ICON_LOCK Lock")
            execute_lock
            ;;
        "$ICON_LOGOUT Logout")
            execute_logout
            ;;
        "$ICON_SUSPEND Suspend")
            execute_suspend
            ;;
        "$ICON_HIBERNATE Hibernate")
            execute_hibernate
            ;;
        "$ICON_REBOOT Reboot")
            execute_reboot
            ;;
        "$ICON_SHUTDOWN Shutdown")
            execute_shutdown
            ;;
        " System Info")
            show_system_info
            ;;
        "$ICON_CANCEL Cancel"|"")
            exit 0
            ;;
        *)
            echo "Unknown option: $choice"
            exit 1
            ;;
    esac
}

# Function to check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command_exists rofi; then
        missing_deps+=("rofi")
    fi
    
    if ! command_exists systemctl; then
        echo "Warning: systemctl not found, some features may not work"
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "Error: Missing dependencies: ${missing_deps[*]}"
        exit 1
    fi
}

# Function to setup rofi theme
setup_rofi_theme() {
    # Create theme if it doesn't exist
    if [[ ! -f "$ROFI_THEME" ]]; then
        local theme_dir=$(dirname "$ROFI_THEME")
        mkdir -p "$theme_dir"
        
        cat > "$ROFI_THEME" << EOF
* {
    background-color: $COLOR_BG;
    text-color: $COLOR_FG;
    border-color: $COLOR_ACTIVE;
    separatorcolor: $COLOR_ACTIVE;
    selected-normal-background: $COLOR_ACTIVE;
    selected-normal-foreground: $COLOR_BG;
    urgent-background: $COLOR_URGENT;
    urgent-foreground: $COLOR_BG;
    active-background: $COLOR_SUCCESS;
    active-foreground: $COLOR_BG;
}

window {
    transparency: "real";
    location: center;
    anchor: center;
    fullscreen: false;
    width: 350px;
    x-offset: 0px;
    y-offset: 0px;
    enabled: true;
    margin: 0px;
    padding: 0px;
    border: 2px solid;
    border-radius: 10px;
    cursor: "default";
}

mainbox {
    enabled: true;
    spacing: 10px;
    margin: 0px;
    padding: 20px;
    border: 0px solid;
    border-radius: 0px 0px 0px 0px;
    children: [ "inputbar", "message", "listview" ];
}

inputbar {
    enabled: true;
    spacing: 10px;
    margin: 0px;
    padding: 8px;
    border: 0px solid;
    border-radius: 5px;
    children: [ "textbox-prompt-colon", "prompt"];
}

prompt {
    enabled: true;
    font: "JetBrainsMono Nerd Font 12";
}

textbox-prompt-colon {
    enabled: true;
    expand: false;
    str: "⏻";
    font: "JetBrainsMono Nerd Font 14";
}

message {
    enabled: true;
    margin: 0px;
    padding: 8px;
    border: 0px solid;
    border-radius: 5px;
}

textbox {
    font: "JetBrainsMono Nerd Font 10";
    vertical-align: 0.5;
    horizontal-align: 0.0;
}

listview {
    enabled: true;
    columns: 1;
    lines: 8;
    cycle: true;
    dynamic: true;
    scrollbar: false;
    layout: vertical;
    reverse: false;
    fixed-height: true;
    fixed-columns: true;
    spacing: 5px;
    margin: 0px;
    padding: 0px;
    border: 0px solid;
}

element {
    enabled: true;
    spacing: 10px;
    margin: 0px;
    padding: 8px;
    border: 0px solid;
    border-radius: 5px;
    cursor: pointer;
}

element-text {
    font: "JetBrainsMono Nerd Font 11";
    cursor: inherit;
    vertical-align: 0.5;
    horizontal-align: 0.0;
}
EOF
    fi
}

# Main function
main() {
    # Check dependencies
    check_dependencies
    
    # Setup rofi theme
    setup_rofi_theme
    
    # Create and show menu
    local menu_options=$(create_main_menu)
    local chosen=$(echo -e "$menu_options" | rofi -dmenu -i -p "Power Menu" \
        -theme "$ROFI_THEME" \
        -kb-custom-1 "Alt+s" \
        -kb-custom-2 "Alt+i")
    
    # Handle the selection
    handle_selection "$chosen"
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Enhanced Power Menu Script"
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --lock         Lock screen directly"
        echo "  --logout       Logout directly"
        echo "  --suspend      Suspend directly"
        echo "  --hibernate    Hibernate directly"
        echo "  --reboot       Reboot directly"
        echo "  --shutdown     Shutdown directly"
        echo "  --info         Show system information"
        echo ""
        exit 0
        ;;
    --lock)
        execute_lock
        ;;
    --logout)
        execute_logout
        ;;
    --suspend)
        execute_suspend
        ;;
    --hibernate)
        execute_hibernate
        ;;
    --reboot)
        execute_reboot
        ;;
    --shutdown)
        execute_shutdown
        ;;
    --info)
        show_system_info
        ;;
    *)
        main
        ;;
esac
