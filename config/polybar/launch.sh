#!/usr/bin/env bash

# =====================================================
# Enhanced Polybar Launch Script - Perfect i3 Rice
# Multi-monitor support with intelligent detection
# =====================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[POLYBAR]${NC} $1"; }
log_success() { echo -e "${GREEN}[POLYBAR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[POLYBAR]${NC} $1"; }
log_error() { echo -e "${RED}[POLYBAR]${NC} $1"; }

# Configuration
CONFIG_FILE="$HOME/.config/polybar/config.ini"
LOG_FILE="/tmp/polybar.log"
LOCK_FILE="/tmp/polybar.lock"

# Check if polybar is installed
if ! command -v polybar >/dev/null 2>&1; then
    log_error "Polybar is not installed!"
    exit 1
fi

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    log_error "Config file not found: $CONFIG_FILE"
    exit 1
fi

# Function to cleanup on exit
cleanup() {
    rm -f "$LOCK_FILE"
    log_info "Cleanup completed"
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

# Create lock file to prevent multiple instances
if [[ -f "$LOCK_FILE" ]]; then
    log_warning "Another instance is already running"
    exit 1
fi
echo $$ > "$LOCK_FILE"

# Function to terminate existing polybar instances
terminate_polybar() {
    log_info "Terminating existing polybar instances..."
    
    # Kill all polybar processes
    killall -q polybar
    
    # Wait for processes to terminate
    local timeout=10
    local count=0
    
    while pgrep -u $UID -x polybar >/dev/null; do
        if [[ $count -ge $timeout ]]; then
            log_warning "Force killing remaining polybar processes..."
            killall -9 polybar 2>/dev/null
            break
        fi
        sleep 1
        ((count++))
    done
    
    log_success "All polybar instances terminated"
}

# Function to detect monitors
detect_monitors() {
    log_info "Detecting monitors..."
    
    # Get list of connected monitors
    local monitors=()
    
    if command -v xrandr >/dev/null 2>&1; then
        # Use xrandr to detect monitors
        while IFS= read -r line; do
            if [[ $line =~ ^([A-Za-z0-9-]+)\ connected ]]; then
                monitors+=("${BASH_REMATCH[1]}")
            fi
        done < <(xrandr --query)
    else
        log_warning "xrandr not found, using fallback detection"
        # Fallback to environment variable or default
        monitors=("${MONITOR:-$(xrandr --listmonitors | awk 'NR>1{print $4}' | head -1)}")
    fi
    
    if [[ ${#monitors[@]} -eq 0 ]]; then
        log_error "No monitors detected!"
        exit 1
    fi
    
    log_success "Detected ${#monitors[@]} monitor(s): ${monitors[*]}"
    echo "${monitors[@]}"
}

# Function to get primary monitor
get_primary_monitor() {
    local primary_monitor
    
    if command -v xrandr >/dev/null 2>&1; then
        primary_monitor=$(xrandr --query | grep " connected primary" | cut -d" " -f1)
    fi
    
    if [[ -z "$primary_monitor" ]]; then
        # Fallback to first monitor
        local monitors=($(detect_monitors))
        primary_monitor="${monitors[0]}"
    fi
    
    echo "$primary_monitor"
}

# Function to launch polybar on specific monitor
launch_polybar() {
    local monitor="$1"
    local bar_name="${2:-main}"
    
    log_info "Launching polybar '$bar_name' on monitor '$monitor'..."
    
    # Set monitor environment variable
    export MONITOR="$monitor"
    
    # Launch polybar with specific configuration
    if polybar --config="$CONFIG_FILE" "$bar_name" >>"$LOG_FILE" 2>&1 &; then
        local pid=$!
        log_success "Polybar '$bar_name' launched on '$monitor' (PID: $pid)"
        return 0
    else
        log_error "Failed to launch polybar '$bar_name' on '$monitor'"
        return 1
    fi
}

# Function to setup log file
setup_logging() {
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Initialize log file
    {
        echo "========================================"
        echo "Polybar Launch Log - $(date)"
        echo "========================================"
    } > "$LOG_FILE"
}

# Function to wait for window manager
wait_for_wm() {
    log_info "Waiting for window manager..."
    
    local timeout=30
    local count=0
    
    while ! xprop -root _NET_SUPPORTING_WM_CHECK >/dev/null 2>&1; do
        if [[ $count -ge $timeout ]]; then
            log_warning "Window manager not detected within timeout"
            break
        fi
        sleep 1
        ((count++))
    done
    
    # Additional wait for i3 to be fully ready
    if pgrep -x i3 >/dev/null; then
        log_info "i3 window manager detected, waiting for full initialization..."
        sleep 2
    fi
}

# Function to validate polybar config
validate_config() {
    log_info "Validating polybar configuration..."
    
    if polybar --config="$CONFIG_FILE" --list-bars >/dev/null 2>&1; then
        log_success "Configuration is valid"
        return 0
    else
        log_error "Configuration validation failed"
        return 1
    fi
}

# Function to setup environment
setup_environment() {
    # Set locale for proper character rendering
    export LC_ALL=C.UTF-8
    export LANG=C.UTF-8
    
    # Set XDG directories if not set
    export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
    export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
    
    # Create cache directory for polybar modules
    mkdir -p "$XDG_CACHE_HOME/polybar"
}

# Main execution function
main() {
    log_info "Starting Enhanced Polybar Launch Script"
    
    # Setup environment
    setup_environment
    
    # Setup logging
    setup_logging
    
    # Wait for window manager
    wait_for_wm
    
    # Validate configuration
    if ! validate_config; then
        exit 1
    fi
    
    # Terminate existing instances
    terminate_polybar
    
    # Detect monitors
    local monitors=($(detect_monitors))
    local primary_monitor=$(get_primary_monitor)
    
    log_info "Primary monitor: $primary_monitor"
    
    # Launch polybar on each monitor
    local success_count=0
    local total_monitors=${#monitors[@]}
    
    for monitor in "${monitors[@]}"; do
        if [[ "$monitor" == "$primary_monitor" ]]; then
            # Launch main bar on primary monitor
            if launch_polybar "$monitor" "main"; then
                ((success_count++))
            fi
        else
            # Launch secondary bar on other monitors (if configured)
            if polybar --config="$CONFIG_FILE" --list-bars | grep -q "secondary"; then
                if launch_polybar "$monitor" "secondary"; then
                    ((success_count++))
                fi
            else
                # Use main bar for all monitors
                if launch_polybar "$monitor" "main"; then
                    ((success_count++))
                fi
            fi
        fi
        
        # Small delay between launches
        sleep 0.5
    done
    
    # Report results
    if [[ $success_count -eq $total_monitors ]]; then
        log_success "All polybar instances launched successfully ($success_count/$total_monitors)"
    elif [[ $success_count -gt 0 ]]; then
        log_warning "Some polybar instances failed to launch ($success_count/$total_monitors)"
    else
        log_error "All polybar instances failed to launch"
        exit 1
    fi
    
    # Monitor polybar processes
    log_info "Monitoring polybar processes..."
    
    # Wait a bit to ensure processes are stable
    sleep 3
    
    # Check if any polybar processes are running
    if pgrep -u $UID -x polybar >/dev/null; then
        log_success "Polybar is running successfully"
        
        # Optional: Monitor for crashes and restart
        if [[ "${POLYBAR_AUTO_RESTART:-true}" == "true" ]]; then
            log_info "Auto-restart monitoring enabled"
            
            # Background monitoring (optional)
            (
                while true; do
                    sleep 30
                    if ! pgrep -u $UID -x polybar >/dev/null; then
                        log_warning "Polybar crashed, attempting restart..."
                        exec "$0"
                    fi
                done
            ) &
        fi
    else
        log_error "No polybar processes are running after launch"
        exit 1
    fi
    
    log_success "Polybar launch completed successfully"
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Enhanced Polybar Launch Script"
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --restart, -r  Restart polybar"
        echo "  --status, -s   Show polybar status"
        echo "  --kill, -k     Kill all polybar instances"
        echo ""
        exit 0
        ;;
    --restart|-r)
        log_info "Restarting polybar..."
        main
        ;;
    --status|-s)
        if pgrep -u $UID -x polybar >/dev/null; then
            log_success "Polybar is running"
            pgrep -u $UID -x polybar | while read -r pid; do
                echo "  PID: $pid"
            done
        else
            log_warning "Polybar is not running"
        fi
        ;;
    --kill|-k)
        log_info "Killing all polybar instances..."
        terminate_polybar
        ;;
    *)
        main
        ;;
esac
