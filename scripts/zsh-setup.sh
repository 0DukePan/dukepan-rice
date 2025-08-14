#!/bin/bash
# =====================================================
# duke pan's Ultimate Zsh Setup Script
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

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "\n${PURPLE}=== $1 ===${NC}\n"
}

# Check if running on supported system
check_system() {
    log_header "System Compatibility Check"
    
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        log_error "This script is designed for Linux systems only"
        exit 1
    fi
    
    if ! command -v apt >/dev/null 2>&1; then
        log_error "This script requires apt package manager (Ubuntu/Debian/Pop!_OS)"
        exit 1
    fi
    
    # Check if running on Pop!_OS
    if grep -q "Pop!_OS" /etc/os-release 2>/dev/null; then
        log_success "Pop!_OS detected - perfect for duke pan's rice!"
    elif grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
        log_success "Ubuntu detected - compatible system"
    else
        log_warning "Unknown system detected, proceeding anyway..."
    fi
    
    log_success "System compatibility verified"
}

# Install required packages
install_dependencies() {
    log_header "Installing Dependencies"
    
    local packages=(
        "zsh"
        "curl"
        "wget"
        "git"
        "build-essential"
        "fontconfig"
        "unzip"
        "fd-find"
        "ripgrep"
        "fzf"
        "bat"
        "exa"
        "zoxide"
        "neovim"
        "tmux"
        "htop"
        "btop"
        "tree"
        "jq"
        "python3-pip"
        "nodejs"
        "npm"
        "golang-go"
        "rust-all"
        "cargo"
        "ruby"
        "php"
        "default-jdk"
        "docker.io"
        "docker-compose"
        "kubectl"
        "terraform"
        "awscli"
        "gh"
        "neofetch"
        "lolcat"
        "figlet"
        "cowsay"
        "fortune"
        "cmatrix"
        "pipes.sh"
        "tty-clock"
        "sensors"
        "lm-sensors"
        "acpi"
        "upower"
        "speedtest-cli"
        "qrencode"
        "imagemagick"
        "ffmpeg"
        "youtube-dl"
        "pandoc"
        "shellcheck"
        "tldr"
        "thefuck"
    )
    
    log_info "Updating package lists..."
    sudo apt update
    
    log_info "Installing required packages..."
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            log_info "Installing $package..."
            sudo apt install -y "$package" || log_warning "Failed to install $package, continuing..."
        else
            log_info "$package is already installed"
        fi
    done
    
    # Install additional tools via pip
    log_info "Installing Python tools..."
    pip3 install --user \
        thefuck \
        httpie \
        youtube-dl \
        pipenv \
        poetry \
        black \
        flake8 \
        mypy \
        pytest \
        jupyter \
        matplotlib \
        numpy \
        pandas \
        requests \
        beautifulsoup4 \
        flask \
        django \
        fastapi
    
    # Install additional tools via npm
    log_info "Installing Node.js tools..."
    npm config set prefix ~/.npm-global
    npm install -g \
        neofetch \
        http-server \
        live-server \
        nodemon \
        pm2 \
        typescript \
        ts-node \
        eslint \
        prettier \
        webpack \
        create-react-app \
        vue-cli \
        @angular/cli \
        express-generator \
        gatsby-cli \
        next \
        vercel \
        netlify-cli
    
    # Install Rust tools
    if command -v cargo >/dev/null 2>&1; then
        log_info "Installing Rust tools..."
        cargo install \
            bat \
            exa \
            fd-find \
            ripgrep \
            tokei \
            hyperfine \
            bandwhich \
            bottom \
            dust \
            procs \
            sd \
            tealdeer \
            zoxide \
            starship
    fi
    
    log_success "All dependencies installed"
}

# Install Nerd Fonts
install_fonts() {
    log_header "Installing Nerd Fonts"
    
    local font_dir="$HOME/.local/share/fonts"
    mkdir -p "$font_dir"
    
    local fonts=(
        "JetBrainsMono"
        "FiraCode"
        "Hack"
        "SourceCodePro"
        "UbuntuMono"
        "CascadiaCode"
        "Meslo"
        "RobotoMono"
        "DejaVuSansMono"
        "InconsolataGo"
    )
    
    for font in "${fonts[@]}"; do
        if [[ ! -d "$font_dir/$font" ]]; then
            log_info "Installing $font Nerd Font..."
            wget -q "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$font.zip" -O "/tmp/$font.zip"
            unzip -q "/tmp/$font.zip" -d "$font_dir/$font"
            rm "/tmp/$font.zip"
        else
            log_info "$font Nerd Font already installed"
        fi
    done
    
    # Update font cache
    fc-cache -fv
    log_success "Nerd Fonts installed and cache updated"
}

# Install Oh My Zsh
install_oh_my_zsh() {
    log_header "Installing Oh My Zsh"
    
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        log_info "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        log_success "Oh My Zsh installed"
    else
        log_info "Oh My Zsh already installed"
        log_info "Updating Oh My Zsh..."
        cd "$HOME/.oh-my-zsh" && git pull
    fi
}

# Install Zsh plugins
install_zsh_plugins() {
    log_header "Installing Zsh Plugins"
    
    local plugin_dir="$HOME/.oh-my-zsh/custom/plugins"
    
    local plugins=(
        "zsh-users/zsh-autosuggestions"
        "zsh-users/zsh-syntax-highlighting"
        "zsh-users/zsh-completions"
        "zdharma-continuum/fast-syntax-highlighting"
        "changyuheng/zsh-interactive-cd"
        "MichaelAquilina/zsh-you-should-use"
        "hlissner/zsh-autopair"
        "zsh-users/zsh-history-substring-search"
        "supercrabtree/k"
        "djui/alias-tips"
        "unixorn/autoupdate-zsh-plugin"
        "wfxr/forgit"
        "agkozak/zsh-z"
        "Aloxaf/fzf-tab"
        "zdharma-continuum/history-search-multi-word"
    )
    
    for plugin in "${plugins[@]}"; do
        local plugin_name=$(basename "$plugin")
        if [[ ! -d "$plugin_dir/$plugin_name" ]]; then
            log_info "Installing $plugin_name..."
            git clone "https://github.com/$plugin.git" "$plugin_dir/$plugin_name"
        else
            log_info "$plugin_name already installed, updating..."
            cd "$plugin_dir/$plugin_name" && git pull
        fi
    done
    
    log_success "Zsh plugins installed"
}

# Install Powerlevel10k theme
install_powerlevel10k() {
    log_header "Installing Powerlevel10k Theme"
    
    local theme_dir="$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
    
    if [[ ! -d "$theme_dir" ]]; then
        log_info "Installing Powerlevel10k..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$theme_dir"
        log_success "Powerlevel10k installed"
    else
        log_info "Powerlevel10k already installed, updating..."
        cd "$theme_dir" && git pull
    fi
}

# Install Starship (alternative prompt)
install_starship() {
    log_header "Installing Starship Prompt"
    
    if ! command -v starship >/dev/null 2>&1; then
        log_info "Installing Starship..."
        curl -sS https://starship.rs/install.sh | sh -s -- -y
        log_success "Starship installed"
    else
        log_info "Starship already installed"
    fi
    
    # Create Starship config
    local starship_config="$HOME/.config/starship.toml"
    mkdir -p "$(dirname "$starship_config")"
    
    if [[ ! -f "$starship_config" ]]; then
        log_info "Creating Starship configuration..."
        cat > "$starship_config" << 'EOF'
# duke pan's Starship Configuration
# Catppuccin Mocha theme

format = """
[👑 duke pan](bold purple) $all$character
"""

[character]
success_symbol = "[❯](purple)"
error_symbol = "[❯](red)"

[directory]
style = "bold green"
truncation_length = 8
truncate_to_repo = true

[git_branch]
symbol = " "
style = "bold purple"

[git_status]
style = "bold yellow"

[cmd_duration]
style = "bold yellow"

[time]
disabled = false
format = "🕐 [$time](bold lavender)"
time_format = "%H:%M:%S"

[battery]
full_symbol = "🔋"
charging_symbol = "⚡"
discharging_symbol = "💀"

[[battery.display]]
threshold = 20
style = "bold red"

[[battery.display]]
threshold = 50
style = "bold yellow"

[[battery.display]]
threshold = 100
style = "bold green"
EOF
        log_success "Starship configuration created"
    fi
}

# Setup configuration files
setup_config_files() {
    log_header "Setting Up Configuration Files"
    
    # Backup existing configurations
    if [[ -f "$HOME/.zshrc" ]]; then
        log_info "Backing up existing .zshrc..."
        cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    if [[ -f "$HOME/.p10k.zsh" ]]; then
        log_info "Backing up existing .p10k.zsh..."
        cp "$HOME/.p10k.zsh" "$HOME/.p10k.zsh.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Copy configuration files
    log_info "Installing duke pan's ultimate zsh configuration..."
    cp "config/zsh/.zshrc" "$HOME/.zshrc"
    cp "config/zsh/.p10k.zsh" "$HOME/.p10k.zsh"
    
    # Set proper permissions
    chmod 644 "$HOME/.zshrc"
    chmod 644 "$HOME/.p10k.zsh"
    
    # Create additional config directories
    mkdir -p "$HOME/.config/zsh"
    mkdir -p "$HOME/.zsh/cache"
    mkdir -p "$HOME/Projects"
    mkdir -p "$HOME/Scripts"
    mkdir -p "$HOME/Notes"
    
    log_success "Configuration files installed"
}

# Setup additional tools
setup_additional_tools() {
    log_header "Setting Up Additional Tools"
    
    # Setup FZF
    if [[ ! -f "$HOME/.fzf.zsh" ]]; then
        log_info "Setting up FZF..."
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
        ~/.fzf/install --all
    fi
    
    # Setup bat config
    local bat_config_dir="$HOME/.config/bat"
    mkdir -p "$bat_config_dir"
    if [[ ! -f "$bat_config_dir/config" ]]; then
        log_info "Setting up bat configuration..."
        cat > "$bat_config_dir/config" << 'EOF'
--theme="Catppuccin-mocha"
--style="numbers,changes,header"
--italic-text=always
--decorations=always
--color=always
--wrap=never
--tabs=4
EOF
    fi
    
    # Setup direnv
    if command -v direnv >/dev/null 2>&1; then
        log_info "Direnv is available and will be configured in .zshrc"
    else
        log_info "Installing direnv..."
        curl -sfL https://direnv.net/install.sh | bash
    fi
    
    # Setup git configuration
    if ! git config --global user.name >/dev/null 2>&1; then
        log_info "Setting up git configuration for duke pan..."
        git config --global user.name "duke pan"
        git config --global user.email "duke.pan@example.com"
        git config --global init.defaultBranch main
        git config --global core.editor nvim
        git config --global pull.rebase false
    fi
    
    # Setup tmux plugin manager
    if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
        log_info "Installing tmux plugin manager..."
        git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
    fi
    
    # Setup neovim configuration
    if [[ ! -d "$HOME/.config/nvim" ]]; then
        log_info "Setting up basic neovim configuration..."
        mkdir -p "$HOME/.config/nvim"
        cat > "$HOME/.config/nvim/init.vim" << 'EOF'
" duke pan's basic neovim configuration
set number
set relativenumber
set tabstop=4
set shiftwidth=4
set expandtab
set smartindent
set wrap
set smartcase
set noswapfile
set nobackup
set undodir=~/.vim/undodir
set undofile
set incsearch
set scrolloff=8
set colorcolumn=80
syntax on
colorscheme desert
EOF
    fi
    
    log_success "Additional tools configured"
}

# Change default shell to zsh
change_shell() {
    log_header "Setting Zsh as Default Shell"
    
    if [[ "$SHELL" != "$(which zsh)" ]]; then
        log_info "Changing default shell to zsh..."
        chsh -s "$(which zsh)"
        log_success "Default shell changed to zsh"
        log_warning "Please log out and log back in for the shell change to take effect"
    else
        log_info "Zsh is already the default shell"
    fi
}

# Create desktop entry
create_desktop_entry() {
    log_header "Creating Desktop Entry"
    
    local desktop_file="$HOME/.local/share/applications/duke-pan-terminal.desktop"
    mkdir -p "$(dirname "$desktop_file")"
    
    cat > "$desktop_file" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=👑 duke pan's Terminal
Comment=Ultimate terminal with perfect zsh configuration
Exec=alacritty -e zsh
Icon=terminal
Terminal=false
StartupNotify=true
Categories=System;TerminalEmulator;
Keywords=shell;prompt;command;commandline;cmd;duke;pan;
EOF
    
    chmod +x "$desktop_file"
    
    # Create launcher script
    local launcher_script="$HOME/.local/bin/duke-terminal"
    mkdir -p "$(dirname "$launcher_script")"
    cat > "$launcher_script" << 'EOF'
#!/bin/bash
# duke pan's terminal launcher
alacritty -e zsh -c "duke_info; exec zsh"
EOF
    chmod +x "$launcher_script"
    
    log_success "Desktop entry and launcher created"
}

# Performance optimization
optimize_performance() {
    log_header "Optimizing Performance"
    
    # Compile zsh configuration for faster loading
    log_info "Compiling zsh configuration..."
    zsh -c "source ~/.zshrc && zcompile ~/.zshrc" || log_warning "Failed to compile .zshrc"
    
    # Setup completion cache
    log_info "Setting up completion cache..."
    mkdir -p "$HOME/.zsh/cache"
    
    # Create zsh history file
    touch "$HOME/.zsh_history"
    
    # Setup zoxide database
    if command -v zoxide >/dev/null 2>&1; then
        log_info "Initializing zoxide database..."
        zoxide init zsh > /dev/null 2>&1 || true
    fi
    
    log_success "Performance optimizations applied"
}

# Setup development environment
setup_dev_environment() {
    log_header "Setting Up Development Environment"
    
    # Setup Python environment
    if command -v python3 >/dev/null 2>&1; then
        log_info "Setting up Python development environment..."
        pip3 install --user virtualenv pipenv poetry
    fi
    
    # Setup Node.js environment
    if command -v npm >/dev/null 2>&1; then
        log_info "Setting up Node.js development environment..."
        npm config set prefix ~/.npm-global
        echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.zshrc.local
    fi
    
    # Setup Go environment
    if command -v go >/dev/null 2>&1; then
        log_info "Setting up Go development environment..."
        mkdir -p "$HOME/go/{bin,src,pkg}"
        echo 'export GOPATH="$HOME/go"' >> ~/.zshrc.local
        echo 'export PATH="$GOPATH/bin:$PATH"' >> ~/.zshrc.local
    fi
    
    # Setup Rust environment
    if command -v cargo >/dev/null 2>&1; then
        log_info "Rust environment already configured"
    else
        log_info "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    fi
    
    log_success "Development environment configured"
}

# Final verification
verify_installation() {
    log_header "Verifying Installation"
    
    local errors=0
    
    # Check if zsh is installed
    if ! command -v zsh >/dev/null 2>&1; then
        log_error "Zsh is not installed"
        ((errors++))
    fi
    
    # Check if Oh My Zsh is installed
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        log_error "Oh My Zsh is not installed"
        ((errors++))
    fi
    
    # Check if configuration files exist
    if [[ ! -f "$HOME/.zshrc" ]]; then
        log_error "Zsh configuration file is missing"
        ((errors++))
    fi
    
    if [[ ! -f "$HOME/.p10k.zsh" ]]; then
        log_error "Powerlevel10k configuration file is missing"
        ((errors++))
    fi
    
    # Check if essential plugins are installed
    local essential_plugins=("zsh-autosuggestions" "zsh-syntax-highlighting" "powerlevel10k")
    for plugin in "${essential_plugins[@]}"; do
        if [[ ! -d "$HOME/.oh-my-zsh/custom/plugins/$plugin" ]] && [[ ! -d "$HOME/.oh-my-zsh/custom/themes/$plugin" ]]; then
            log_error "Essential plugin/theme $plugin is missing"
            ((errors++))
        fi
    done
    
    if [[ $errors -eq 0 ]]; then
        log_success "Installation verification completed successfully"
        return 0
    else
        log_error "Installation verification failed with $errors errors"
        return 1
    fi
}

# Create welcome script
create_welcome_script() {
    log_header "Creating Welcome Script"
    
    local welcome_script="$HOME/.local/bin/duke-welcome"
    mkdir -p "$(dirname "$welcome_script")"
    
    cat > "$welcome_script" << 'EOF'
#!/bin/bash
# duke pan's welcome script

clear
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    👑 Welcome duke pan! 👑                   ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  🎯 Ultimate i3 Rice Environment                             ║"
echo "║  🚀 Perfect Zsh Configuration                                ║"
echo "║  🎨 Catppuccin Mocha Theme                                   ║"
echo "║  ⚡ Optimized for Productivity                               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "🔥 Quick Commands:"
echo "  • duke_info    - System information"
echo "  • rice_show    - Rice showcase"
echo "  • perf         - Performance monitor"
echo "  • cleanup      - System cleanup"
echo "  • duke_setup   - Workspace setup"
echo ""
echo "💡 Pro Tips:"
echo "  • Use 'fzf' for fuzzy finding"
echo "  • Try 'z <directory>' for smart navigation"
echo "  • Use 'bat' instead of 'cat' for syntax highlighting"
echo "  • Type 'thefuck' after a wrong command"
echo ""
neofetch
EOF
    
    chmod +x "$welcome_script"
    log_success "Welcome script created"
}

# Main installation function
main() {
    log_header "👑 duke pan's Ultimate Zsh Setup 👑"
    echo -e "${CYAN}Setting up the perfect zsh environment for your i3 rice...${NC}\n"
    
    # Check if script is run from correct directory
    if [[ ! -f "config/zsh/.zshrc" ]]; then
        log_error "Please run this script from the root of the i3 rice configuration directory"
        log_info "Expected file: config/zsh/.zshrc"
        exit 1
    fi
    
    # Run installation steps
    check_system
    install_dependencies
    install_fonts
    install_oh_my_zsh
    install_zsh_plugins
    install_powerlevel10k
    install_starship
    setup_config_files
    setup_additional_tools
    setup_dev_environment
    change_shell
    create_desktop_entry
    create_welcome_script
    optimize_performance
    
    # Verify installation
    if verify_installation; then
        log_header "🎉 Installation Complete! 🎉"
        echo -e "${GREEN}duke pan's ultimate zsh configuration has been installed successfully!${NC}\n"
        echo -e "${CYAN}Next steps:${NC}"
        echo -e "  1. ${YELLOW}Log out and log back in${NC} (or restart your terminal)"
        echo -e "  2. ${YELLOW}Open a new terminal${NC} to see your new zsh setup"
        echo -e "  3. ${YELLOW}Run 'p10k configure'${NC} if you want to customize the prompt further"
        echo -e "  4. ${YELLOW}Run 'duke-welcome'${NC} to see the welcome screen"
        echo -e "  5. ${YELLOW}Enjoy your perfect terminal experience!${NC}\n"
        
        echo -e "${PURPLE}🌟 Features included:${NC}"
        echo -e "  ✅ Oh My Zsh with 30+ productivity plugins"
        echo -e "  ✅ Powerlevel10k theme with Catppuccin colors"
        echo -e "  ✅ Advanced autocompletion and syntax highlighting"
        echo -e "  ✅ FZF integration for fuzzy finding"
        echo -e "  ✅ Custom aliases and functions for duke pan"
        echo -e "  ✅ Development environment setup (Python, Node.js, Go, Rust)"
        echo -e "  ✅ Performance optimizations"
        echo -e "  ✅ Beautiful Catppuccin Mocha theming"
        echo -e "  ✅ Advanced git integration"
        echo -e "  ✅ Docker and Kubernetes support"
        echo -e "  ✅ Cloud provider integrations (AWS, GCP)"
        echo -e "\n${GREEN}👑 Welcome to your ultimate terminal experience, duke pan! 👑${NC}"
        
        # Show final system info
        echo -e "\n${BLUE}📊 System Summary:${NC}"
        echo -e "  • Hostname: $(hostname)"
        echo -e "  • OS: $(lsb_release -d | cut -f2)"
        echo -e "  • Kernel: $(uname -r)"
        echo -e "  • Shell: $(zsh --version)"
        echo -e "  • Terminal: ${TERMINAL:-Unknown}"
        echo -e "  • Installation Date: $(date)"
        
    else
        log_error "Installation completed with errors. Please check the output above."
        exit 1
    fi
}

# Run main function
main "$@"
