#!/usr/bin/env bash

# =====================================================
# DUKE PAN'S TMUX SETUP SCRIPT
# Automated installation and configuration
# =====================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Check if running on supported system
check_system() {
    log "Checking system compatibility..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get >/dev/null 2>&1; then
            PACKAGE_MANAGER="apt-get"
        elif command -v pacman >/dev/null 2>&1; then
            PACKAGE_MANAGER="pacman"
        elif command -v dnf >/dev/null 2>&1; then
            PACKAGE_MANAGER="dnf"
        else
            error "Unsupported package manager"
        fi
    else
        error "This script is designed for Linux systems"
    fi
    
    log "System check passed - using $PACKAGE_MANAGER"
}

# Install dependencies
install_dependencies() {
    log "Installing tmux and dependencies..."
    
    case $PACKAGE_MANAGER in
        "apt-get")
            sudo apt-get update
            sudo apt-get install -y tmux git curl xclip
            ;;
        "pacman")
            sudo pacman -S --noconfirm tmux git curl xclip
            ;;
        "dnf")
            sudo dnf install -y tmux git curl xclip
            ;;
    esac
    
    log "Dependencies installed successfully"
}

# Install TPM (Tmux Plugin Manager)
install_tpm() {
    log "Installing Tmux Plugin Manager..."
    
    TPM_DIR="$HOME/.tmux/plugins/tpm"
    
    if [[ -d "$TPM_DIR" ]]; then
        warn "TPM already installed, updating..."
        cd "$TPM_DIR"
        git pull
    else
        git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
    fi
    
    log "TPM installed successfully"
}

# Create tmux configuration directory
setup_config_dir() {
    log "Setting up configuration directory..."
    
    TMUX_CONFIG_DIR="$HOME/.config/tmux"
    mkdir -p "$TMUX_CONFIG_DIR"
    
    # Create symlink for traditional location
    if [[ ! -L "$HOME/.tmux.conf" ]]; then
        ln -sf "$TMUX_CONFIG_DIR/tmux.conf" "$HOME/.tmux.conf"
    fi
    
    log "Configuration directory setup complete"
}

# Create additional configuration files
create_additional_configs() {
    log "Creating additional configuration files..."
    
    # Linux-specific config
    cat > "$HOME/.config/tmux/linux.conf" << 'EOF'
# Linux-specific tmux configuration
# Clipboard integration for Linux
bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "xclip -in -selection clipboard"
bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xclip -in -selection clipboard"

# Linux-specific key bindings
bind-key -T copy-mode-vi 'C-v' send -X rectangle-toggle
EOF

    # Local config template
    cat > "$HOME/.config/tmux/local.conf" << 'EOF'
# Local tmux configuration
# Add your personal customizations here
# This file is sourced last and won't be overwritten

# Example: Custom key bindings
# bind-key C-x kill-session

# Example: Custom status bar modules
# set -g status-right "#[bg=#{@catppuccin_blue}] Custom Module #{status-right}"
EOF

    log "Additional configuration files created"
}

# Install plugins
install_plugins() {
    log "Installing tmux plugins..."
    
    # Start tmux server if not running
    if ! tmux list-sessions >/dev/null 2>&1; then
        tmux new-session -d -s setup
        CLEANUP_SESSION=true
    fi
    
    # Install plugins
    "$HOME/.tmux/plugins/tpm/scripts/install_plugins.sh"
    
    # Clean up temporary session
    if [[ "${CLEANUP_SESSION:-}" == "true" ]]; then
        tmux kill-session -t setup
    fi
    
    log "Plugins installed successfully"
}

# Create startup script
create_startup_script() {
    log "Creating tmux startup script..."
    
    cat > "$HOME/.local/bin/tmux-duke" << 'EOF'
#!/usr/bin/env bash

# Duke Pan's Tmux Startup Script
# Creates a perfect development environment

SESSION_NAME="duke-dev"

# Check if session exists
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Session '$SESSION_NAME' already exists. Attaching..."
    tmux attach-session -t "$SESSION_NAME"
    exit 0
fi

# Create new session
tmux new-session -d -s "$SESSION_NAME" -n "main"

# Window 1: Main development
tmux send-keys -t "$SESSION_NAME:main" "clear && neofetch" Enter

# Window 2: System monitoring
tmux new-window -t "$SESSION_NAME" -n "monitor"
tmux send-keys -t "$SESSION_NAME:monitor" "htop" Enter

# Window 3: File management
tmux new-window -t "$SESSION_NAME" -n "files"
tmux send-keys -t "$SESSION_NAME:files" "ranger" Enter

# Window 4: Git operations
tmux new-window -t "$SESSION_NAME" -n "git"
tmux send-keys -t "$SESSION_NAME:git" "clear && git status" Enter

# Select main window
tmux select-window -t "$SESSION_NAME:main"

# Attach to session
tmux attach-session -t "$SESSION_NAME"
EOF

    chmod +x "$HOME/.local/bin/tmux-duke"
    
    log "Startup script created at ~/.local/bin/tmux-duke"
}

# Main installation function
main() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    DUKE PAN'S TMUX SETUP                    ║"
    echo "║              The Ultimate Tmux Configuration                ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_system
    install_dependencies
    setup_config_dir
    install_tpm
    create_additional_configs
    install_plugins
    create_startup_script
    
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    INSTALLATION COMPLETE!                   ║"
    echo "║                                                              ║"
    echo "║  Your ultimate tmux configuration is now ready!             ║"
    echo "║                                                              ║"
    echo "║  Usage:                                                      ║"
    echo "║    tmux-duke    - Start development session                 ║"
    echo "║    tmux         - Start regular tmux                        ║"
    echo "║                                                              ║"
    echo "║  Key bindings:                                               ║"
    echo "║    Ctrl-a       - Prefix key                                ║"
    echo "║    Prefix + |   - Split horizontally                        ║"
    echo "║    Prefix + -   - Split vertically                          ║"
    echo "║    Prefix + r   - Reload config                             ║"
    echo "║                                                              ║"
    echo "║  Enjoy your perfect tmux setup, Duke Pan! 🚀               ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Run main function
main "$@"
