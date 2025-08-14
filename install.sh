#!/bin/bash

# =====================================================
# Perfect i3 Rice Installer for Pop!_OS/Ubuntu
# Ultimate Desktop Environment Setup Script
# Enhanced with Advanced Features & Error Handling
# =====================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/i3-rice-install.log"
BACKUP_DIR="$HOME/.config/i3-rice-backup-$(date +%Y%m%d-%H%M%S)"
REQUIRED_SPACE=2048  # MB
MIN_RAM=4096  # MB

# Logging functions with timestamps
log_info() { 
    echo -e "${BLUE}[$(date '+%H:%M:%S')] [INFO]${NC} $1" | tee -a "$LOG_FILE"
}
log_success() { 
    echo -e "${GREEN}[$(date '+%H:%M:%S')] [SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}
log_warning() { 
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] [WARNING]${NC} $1" | tee -a "$LOG_FILE"
}
log_error() { 
    echo -e "${RED}[$(date '+%H:%M:%S')] [ERROR]${NC} $1" | tee -a "$LOG_FILE"
}
log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${CYAN}[$(date '+%H:%M:%S')] [DEBUG]${NC} $1" | tee -a "$LOG_FILE"
    fi
}

# Initialize logging
init_logging() {
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "Perfect i3 Rice Installation Log - $(date)" > "$LOG_FILE"
    echo "=========================================" >> "$LOG_FILE"
}

# Enhanced banner with system info
show_banner() {
    clear
    echo -e "${PURPLE}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                    Perfect i3 Rice Installer                  ║
║                   Ultimate Desktop Environment                ║
║                      for Pop!_OS & Ubuntu                    ║
║                                                               ║
║  🎨 Catppuccin Mocha Theme                                    ║
║  ⚡ Advanced Polybar with System Monitoring                   ║
║  🚀 Rofi Menus with Power Management                          ║
║  💎 Picom Compositor with Blur Effects                        ║
║  📱 Modern Terminal Setup (Alacritty + Kitty)                 ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    # Show system information
    echo -e "${WHITE}System Information:${NC}"
    echo -e "  OS: $(lsb_release -d | cut -f2)"
    echo -e "  Kernel: $(uname -r)"
    echo -e "  RAM: $(free -h | awk 'NR==2{printf "%.1f GB", $2/1024/1024/1024}')"
    echo -e "  Disk Space: $(df -h / | awk 'NR==2{print $4}') available"
    echo
}

# Comprehensive system checks
check_system() {
    log_info "Performing comprehensive system checks..."
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root!"
        exit 1
    fi
    
    # Check package manager
    if ! command -v apt &> /dev/null; then
        log_error "This installer requires apt package manager (Ubuntu/Debian based systems)"
        exit 1
    fi
    
    # Check system compatibility
    if ! grep -q "Pop!_OS\|Ubuntu\|Debian" /etc/os-release; then
        log_warning "This installer is optimized for Pop!_OS/Ubuntu but may work on other Debian-based systems"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Check available disk space
    local available_space=$(df / | awk 'NR==2 {print $4}')
    if [[ $available_space -lt $((REQUIRED_SPACE * 1024)) ]]; then
        log_error "Insufficient disk space. Required: ${REQUIRED_SPACE}MB, Available: $((available_space / 1024))MB"
        exit 1
    fi
    
    # Check RAM
    local total_ram=$(free -m | awk 'NR==2{print $2}')
    if [[ $total_ram -lt $MIN_RAM ]]; then
        log_warning "Low RAM detected (${total_ram}MB). Recommended: ${MIN_RAM}MB"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Check internet connection
    if ! ping -c 1 google.com &> /dev/null; then
        log_error "No internet connection detected. Please check your network."
        exit 1
    fi
    
    # Check if X11 is running
    if [[ -z "$DISPLAY" ]]; then
        log_warning "X11 display not detected. Make sure you're running this in a graphical session."
    fi
    
    log_success "System checks passed"
}

# Enhanced backup with compression and verification
backup_configs() {
    log_info "Creating comprehensive backup of existing configurations..."
    
    mkdir -p "$BACKUP_DIR"
    
    # List of configurations to backup
    local configs=(
        "i3" "polybar" "rofi" "dunst" "picom" "alacritty" "kitty"
        "gtk-3.0" "fontconfig" "nitrogen" "redshift"
    )
    
    local backup_count=0
    
    for config in "${configs[@]}"; do
        if [[ -d "$HOME/.config/$config" ]]; then
            log_debug "Backing up $config configuration..."
            cp -r "$HOME/.config/$config" "$BACKUP_DIR/" 2>/dev/null || true
            ((backup_count++))
        fi
    done
    
    # Backup dotfiles
    local dotfiles=(".xinitrc" ".xprofile" ".Xresources")
    for dotfile in "${dotfiles[@]}"; do
        if [[ -f "$HOME/$dotfile" ]]; then
            cp "$HOME/$dotfile" "$BACKUP_DIR/" 2>/dev/null || true
            ((backup_count++))
        fi
    done
    
    # Create backup info file
    cat > "$BACKUP_DIR/backup_info.txt" << EOF
Backup created: $(date)
System: $(lsb_release -d | cut -f2)
User: $USER
Backed up configs: $backup_count
Original location: $HOME/.config/
Restore command: cp -r $BACKUP_DIR/* $HOME/.config/
EOF
    
    # Compress backup if tar is available
    if command -v tar &> /dev/null; then
        log_info "Compressing backup..."
        tar -czf "${BACKUP_DIR}.tar.gz" -C "$(dirname "$BACKUP_DIR")" "$(basename "$BACKUP_DIR")"
        rm -rf "$BACKUP_DIR"
        BACKUP_DIR="${BACKUP_DIR}.tar.gz"
    fi
    
    log_success "Backup created: $BACKUP_DIR ($backup_count items)"
}

# Enhanced system update with error handling
update_system() {
    log_info "Updating system packages..."
    
    # Update package lists
    if ! sudo apt update; then
        log_error "Failed to update package lists"
        exit 1
    fi
    
    # Check for upgradeable packages
    local upgradeable=$(apt list --upgradeable 2>/dev/null | wc -l)
    if [[ $upgradeable -gt 1 ]]; then
        log_info "Found $((upgradeable - 1)) upgradeable packages"
        
        # Upgrade with progress
        if ! sudo apt upgrade -y; then
            log_warning "Some packages failed to upgrade, continuing..."
        fi
    else
        log_info "System is already up to date"
    fi
    
    # Clean package cache
    sudo apt autoremove -y
    sudo apt autoclean
    
    log_success "System update completed"
}

# Comprehensive package installation with error handling
install_core_packages() {
    log_info "Installing core i3 packages..."
    
    # Core window manager packages
    local wm_packages=(
        "i3-wm" "i3status" "i3lock" "i3lock-fancy"
        "suckless-tools" "dmenu"
    )
    
    # Status bar and menu packages
    local ui_packages=(
        "polybar" "rofi" "rofi-calc" "rofi-dev"
    )
    
    # Compositor and notifications
    local visual_packages=(
        "picom" "dunst" "libnotify-bin"
        "redshift-gtk" "lxappearance"
    )
    
    # Terminal emulators
    local terminal_packages=(
        "alacritty" "kitty" "tmux"
    )
    
    # File management
    local file_packages=(
        "thunar" "thunar-volman" "thunar-archive-plugin"
        "file-roller" "gvfs" "gvfs-backends"
    )
    
    # Media and screenshots
    local media_packages=(
        "feh" "nitrogen" "scrot" "flameshot" "maim"
        "imagemagick" "gimp" "vlc"
        "playerctl" "pavucontrol" "pulseaudio-utils"
        "alsa-utils" "pipewire" "pipewire-pulse"
    )
    
    # System monitoring and utilities
    local system_packages=(
        "htop" "btop" "neofetch" "lm-sensors"
        "brightnessctl" "acpi" "upower"
        "xclip" "xsel" "clipit"
        "tree" "fd-find" "ripgrep" "bat"
    )
    
    # Network and bluetooth
    local network_packages=(
        "network-manager-gnome" "blueman"
        "wireless-tools" "wpasupplicant"
    )
    
    # Development tools
    local dev_packages=(
        "git" "curl" "wget" "vim" "nano"
        "build-essential" "cmake" "python3-pip"
    )
    
    # Additional utilities
    local util_packages=(
        "arandr" "autorandr" "xorg-xrandr"
        "gnome-calculator" "gnome-system-monitor"
        "gnome-disk-utility" "gparted"
        "firefox" "code" "discord"
    )
    
    # Combine all packages
    local all_packages=(
        "${wm_packages[@]}" "${ui_packages[@]}" "${visual_packages[@]}"
        "${terminal_packages[@]}" "${file_packages[@]}" "${media_packages[@]}"
        "${system_packages[@]}" "${network_packages[@]}" "${dev_packages[@]}"
        "${util_packages[@]}"
    )
    
    # Install packages with progress tracking
    local total_packages=${#all_packages[@]}
    local installed_count=0
    local failed_packages=()
    
    log_info "Installing $total_packages packages..."
    
    for package in "${all_packages[@]}"; do
        log_debug "Installing $package..."
        if sudo apt install -y "$package" &>> "$LOG_FILE"; then
            ((installed_count++))
        else
            failed_packages+=("$package")
            log_warning "Failed to install $package"
        fi
        
        # Show progress
        local progress=$((installed_count * 100 / total_packages))
        echo -ne "\rProgress: $progress% ($installed_count/$total_packages)"
    done
    echo
    
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        log_warning "Failed to install ${#failed_packages[@]} packages: ${failed_packages[*]}"
    fi
    
    log_success "Core packages installation completed ($installed_count/$total_packages)"
}

# Enhanced font installation with verification
install_fonts() {
    log_info "Installing comprehensive font collection..."
    
    # System fonts
    local system_fonts=(
        "fonts-jetbrains-mono" "fonts-firacode"
        "fonts-font-awesome" "fonts-powerline"
        "fonts-noto-color-emoji" "fonts-noto-sans"
        "fonts-roboto" "fonts-ubuntu" "fonts-liberation"
    )
    
    sudo apt install -y "${system_fonts[@]}"
    
    # Create fonts directory
    mkdir -p ~/.local/share/fonts
    cd /tmp
    
    # Download Nerd Fonts
    local nerd_fonts=(
        "JetBrainsMono" "FiraCode" "Hack" "SourceCodePro"
        "UbuntuMono" "DejaVuSansMono"
    )
    
    for font in "${nerd_fonts[@]}"; do
        log_info "Installing $font Nerd Font..."
        local font_url="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/${font}.zip"
        
        if wget -q --show-progress "$font_url"; then
            unzip -o "${font}.zip" -d ~/.local/share/fonts/ &>> "$LOG_FILE"
            rm -f "${font}.zip"
            log_success "$font Nerd Font installed"
        else
            log_warning "Failed to download $font Nerd Font"
        fi
    done
    
    # Install additional icon fonts
    log_info "Installing icon fonts..."
    
    # Font Awesome
    wget -q https://use.fontawesome.com/releases/v6.4.0/fontawesome-free-6.4.0-desktop.zip
    if [[ -f fontawesome-free-6.4.0-desktop.zip ]]; then
        unzip -o fontawesome-free-6.4.0-desktop.zip
        cp fontawesome-free-6.4.0-desktop/otfs/*.otf ~/.local/share/fonts/
        rm -rf fontawesome-free-6.4.0-desktop*
    fi
    
    # Update font cache with verification
    log_info "Updating font cache..."
    fc-cache -fv &>> "$LOG_FILE"
    
    # Verify font installation
    local installed_fonts=$(fc-list | grep -i "jetbrains\|fira\|nerd" | wc -l)
    log_success "Font installation completed ($installed_fonts fonts installed)"
}

# Install additional software with Flatpak and Snap support
install_additional_software() {
    log_info "Installing additional software..."
    
    # Install Flatpak if not present
    if ! command -v flatpak &> /dev/null; then
        log_info "Installing Flatpak..."
        sudo apt install -y flatpak
        sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        log_success "Flatpak installed"
    fi
    
    # Install Snap if not present (for Ubuntu)
    if ! command -v snap &> /dev/null && grep -q "Ubuntu" /etc/os-release; then
        log_info "Installing Snap..."
        sudo apt install -y snapd
        log_success "Snap installed"
    fi
    
    # Flatpak applications
    local flatpak_apps=(
        "org.mozilla.firefox"
        "com.spotify.Client"
        "org.videolan.VLC"
        "org.gimp.GIMP"
        "com.obsproject.Studio"
        "org.telegram.desktop"
        "com.discordapp.Discord"
        "org.libreoffice.LibreOffice"
        "com.github.tchx84.Flatseal"
        "org.blender.Blender"
        "com.github.IsmaelMartinez.teams_for_linux"
    )
    
    log_info "Installing Flatpak applications..."
    for app in "${flatpak_apps[@]}"; do
        log_debug "Installing $app..."
        if flatpak install -y flathub "$app" &>> "$LOG_FILE"; then
            log_success "Installed $app"
        else
            log_warning "Failed to install $app"
        fi
    done
    
    # Install development tools via package manager
    local dev_tools=(
        "nodejs" "npm" "python3-venv" "docker.io"
        "docker-compose" "git-lfs"
    )
    
    log_info "Installing development tools..."
    sudo apt install -y "${dev_tools[@]}"
    
    # Add user to docker group
    if command -v docker &> /dev/null; then
        sudo usermod -aG docker "$USER"
        log_info "Added $USER to docker group (logout required)"
    fi
    
    log_success "Additional software installation completed"
}

# Enhanced directory structure creation
create_directories() {
    log_info "Creating comprehensive directory structure..."
    
    # Config directories
    local config_dirs=(
        "i3" "polybar" "rofi" "dunst" "picom" "alacritty" "kitty"
        "gtk-3.0" "fontconfig" "nitrogen" "redshift" "autorandr"
    )
    
    for dir in "${config_dirs[@]}"; do
        mkdir -p ~/.config/"$dir"
    done
    
    # Rofi subdirectories
    mkdir -p ~/.config/rofi/{themes,scripts,modi}
    
    # Polybar subdirectories
    mkdir -p ~/.config/polybar/{scripts,modules,themes}
    
    # User directories
    mkdir -p ~/Pictures/{Wallpapers,Screenshots,Icons}
    mkdir -p ~/Documents/{Scripts,Configs,Projects}
    mkdir -p ~/Downloads/Software
    mkdir -p ~/.local/{bin,share/applications,share/icons,share/themes}
    mkdir -p ~/.themes ~/.icons ~/.fonts
    
    # Cache directories
    mkdir -p ~/.cache/{polybar,rofi,i3,wallpapers}
    
    # Create symlinks for common directories
    ln -sf ~/Pictures/Screenshots ~/.local/share/screenshots 2>/dev/null || true
    ln -sf ~/Pictures/Wallpapers ~/.local/share/wallpapers 2>/dev/null || true
    
    log_success "Directory structure created"
}

# Enhanced configuration installation with validation
install_configurations() {
    log_info "Installing configuration files..."
    
    # Verify source directory exists
    if [[ ! -d "$SCRIPT_DIR/config" ]]; then
        log_error "Configuration directory not found at $SCRIPT_DIR/config"
        exit 1
    fi
    
    # Copy configurations with verification
    local config_files=0
    while IFS= read -r -d '' file; do
        local relative_path="${file#$SCRIPT_DIR/config/}"
        local target_path="$HOME/.config/$relative_path"
        local target_dir=$(dirname "$target_path")
        
        mkdir -p "$target_dir"
        
        if cp "$file" "$target_path"; then
            ((config_files++))
            log_debug "Copied $relative_path"
        else
            log_warning "Failed to copy $relative_path"
        fi
    done < <(find "$SCRIPT_DIR/config" -type f -print0)
    
    # Copy scripts
    if [[ -d "$SCRIPT_DIR/scripts" ]]; then
        local script_files=0
        while IFS= read -r -d '' script; do
            local script_name=$(basename "$script")
            if cp "$script" ~/.local/bin/; then
                chmod +x ~/.local/bin/"$script_name"
                ((script_files++))
                log_debug "Installed script $script_name"
            fi
        done < <(find "$SCRIPT_DIR/scripts" -type f -print0)
        
        log_success "Installed $script_files scripts"
    fi
    
    # Make all shell scripts executable
    find ~/.config -name "*.sh" -exec chmod +x {} \;
    
    # Validate critical configuration files
    local critical_configs=(
        "~/.config/i3/config"
        "~/.config/polybar/config.ini"
        "~/.config/rofi/themes/launcher.rasi"
    )
    
    for config in "${critical_configs[@]}"; do
        config=$(eval echo "$config")  # Expand tilde
        if [[ ! -f "$config" ]]; then
            log_error "Critical configuration file missing: $config"
            exit 1
        fi
    done
    
    log_success "Configuration files installed ($config_files files)"
}

# Enhanced wallpaper download with multiple sources
download_wallpapers() {
    log_info "Downloading wallpaper collection..."
    
    cd ~/Pictures/Wallpapers
    
    # Catppuccin wallpapers
    local catppuccin_wallpapers=(
        "https://raw.githubusercontent.com/catppuccin/wallpapers/main/landscapes/evening-sky.png"
        "https://raw.githubusercontent.com/catppuccin/wallpapers/main/landscapes/japanese_street.png"
        "https://raw.githubusercontent.com/catppuccin/wallpapers/main/landscapes/mountain.png"
        "https://raw.githubusercontent.com/catppuccin/wallpapers/main/landscapes/forest.png"
        "https://raw.githubusercontent.com/catppuccin/wallpapers/main/misc/cat-sound.png"
        "https://raw.githubusercontent.com/catppuccin/wallpapers/main/misc/cat-rainbow.png"
    )
    
    local catppuccin_names=(
        "catppuccin-evening-sky.png"
        "catppuccin-japanese-street.png"
        "catppuccin-mountain.png"
        "catppuccin-forest.png"
        "catppuccin-cat-sound.png"
        "catppuccin-cat-rainbow.png"
    )
    
    # Download Catppuccin wallpapers
    for i in "${!catppuccin_wallpapers[@]}"; do
        log_debug "Downloading ${catppuccin_names[$i]}..."
        if wget -q --show-progress "${catppuccin_wallpapers[$i]}" -O "${catppuccin_names[$i]}"; then
            log_success "Downloaded ${catppuccin_names[$i]}"
        else
            log_warning "Failed to download ${catppuccin_names[$i]}"
        fi
    done
    
    # Download additional high-quality wallpapers
    local additional_wallpapers=(
        "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=1920&h=1080&fit=crop"
        "https://images.unsplash.com/photo-1419242902214-272b3f66ee7a?w=1920&h=1080&fit=crop"
    )
    
    local additional_names=(
        "mountain-landscape.jpg"
        "night-sky.jpg"
    )
    
    for i in "${!additional_wallpapers[@]}"; do
        log_debug "Downloading ${additional_names[$i]}..."
        wget -q --show-progress "${additional_wallpapers[$i]}" -O "${additional_names[$i]}" || true
    done
    
    # Create wallpaper index
    ls -la > wallpaper_index.txt
    
    local wallpaper_count=$(find . -name "*.png" -o -name "*.jpg" | wc -l)
    log_success "Wallpaper collection downloaded ($wallpaper_count wallpapers)"
}

# Comprehensive theme setup
setup_themes() {
    log_info "Setting up comprehensive theme system..."
    
    # Download and install Catppuccin GTK theme
    cd /tmp
    if git clone https://github.com/catppuccin/gtk.git catppuccin-gtk; then
        cd catppuccin-gtk
        
        # Install all Catppuccin variants
        local variants=("Mocha" "Macchiato" "Frappe" "Latte")
        local accents=("Mauve" "Pink" "Red" "Peach" "Yellow" "Green" "Teal" "Blue")
        
        mkdir -p ~/.themes
        
        for variant in "${variants[@]}"; do
            for accent in "${accents[@]}"; do
                local theme_name="Catppuccin-${variant}-Standard-${accent}-Dark"
                if [[ -d "themes/$theme_name" ]]; then
                    cp -r "themes/$theme_name" ~/.themes/
                    log_debug "Installed theme: $theme_name"
                fi
            done
        done
        
        # Set default theme
        gsettings set org.gnome.desktop.interface gtk-theme "Catppuccin-Mocha-Standard-Mauve-Dark"
        gsettings set org.gnome.desktop.wm.preferences theme "Catppuccin-Mocha-Standard-Mauve-Dark"
        
        log_success "Catppuccin GTK themes installed"
    else
        log_warning "Failed to download Catppuccin GTK theme"
    fi
    
    # Install icon themes
    log_info "Installing icon themes..."
    
    # Papirus icons
    sudo apt install -y papirus-icon-theme
    
    # Catppuccin icons
    cd /tmp
    if git clone https://github.com/catppuccin/papirus-folders.git; then
        cd papirus-folders
        cp -r src/* ~/.local/share/icons/ 2>/dev/null || true
        log_success "Catppuccin Papirus icons installed"
    fi
    
    # Set icon theme
    gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"
    
    # Install cursor theme
    sudo apt install -y bibata-cursor-theme
    gsettings set org.gnome.desktop.interface cursor-theme "Bibata-Modern-Classic"
    
    # Configure font settings
    gsettings set org.gnome.desktop.interface font-name "Ubuntu 11"
    gsettings set org.gnome.desktop.interface document-font-name "Ubuntu 11"
    gsettings set org.gnome.desktop.interface monospace-font-name "JetBrainsMono Nerd Font 10"
    gsettings set org.gnome.desktop.wm.preferences titlebar-font "Ubuntu Bold 11"
    
    log_success "Theme system configured"
}

# Enhanced service configuration
configure_services() {
    log_info "Configuring system services..."
    
    # Enable and start essential services
    local services=(
        "bluetooth" "NetworkManager" "systemd-timesyncd"
    )
    
    for service in "${services[@]}"; do
        if systemctl is-available "$service" &>/dev/null; then
            sudo systemctl enable "$service"
            sudo systemctl start "$service"
            log_debug "Enabled service: $service"
        fi
    done
    
    # Configure user services
    systemctl --user enable pipewire pipewire-pulse 2>/dev/null || true
    
    # Set up automatic login (optional)
    read -p "Enable automatic login? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
        sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf > /dev/null << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER --noclear %I \$TERM
EOF
        log_success "Automatic login configured"
    fi
    
    log_success "System services configured"
}

# Comprehensive final setup
final_setup() {
    log_info "Performing final system setup..."
    
    # Set default wallpaper
    local default_wallpaper="$HOME/Pictures/Wallpapers/catppuccin-evening-sky.png"
    if [[ -f "$default_wallpaper" ]]; then
        nitrogen --set-zoom-fill "$default_wallpaper"
        nitrogen --save
        log_success "Default wallpaper set"
    fi
    
    # Create desktop entries
    cat > ~/.local/share/applications/perfect-i3-rice.desktop << EOF
[Desktop Entry]
Name=Perfect i3 Rice
Comment=Launch the perfect i3 desktop environment
Exec=i3
Icon=preferences-desktop-theme
Type=Application
Categories=System;Settings;
Keywords=desktop;environment;rice;i3;
EOF
    
    # Create useful scripts
    cat > ~/.local/bin/rice-update << 'EOF'
#!/bin/bash
# Update rice configurations
cd ~/.config
git pull origin main 2>/dev/null || echo "No git repository found"
~/.config/polybar/launch.sh
notify-send "Rice Updated" "Configuration refreshed"
EOF
    chmod +x ~/.local/bin/rice-update
    
    # Update desktop database
    update-desktop-database ~/.local/share/applications/ 2>/dev/null || true
    
    # Generate system information
    cat > ~/Documents/system-info.txt << EOF
Perfect i3 Rice Installation Summary
===================================
Installation Date: $(date)
System: $(lsb_release -d | cut -f2)
Kernel: $(uname -r)
User: $USER
Backup Location: $BACKUP_DIR

Installed Components:
- i3 Window Manager with Catppuccin theme
- Polybar with system monitoring
- Rofi application launcher and menus
- Picom compositor with effects
- Alacritty and Kitty terminals
- Comprehensive font collection
- GTK themes and icon packs
- Wallpaper collection

Key Bindings:
- Super+Return: Terminal
- Super+d: App launcher
- Super+Shift+e: Power menu
- Super+Tab: Window switcher
- Print: Screenshot

Configuration Locations:
- i3: ~/.config/i3/config
- Polybar: ~/.config/polybar/config.ini
- Rofi: ~/.config/rofi/
- Scripts: ~/.local/bin/

For support and updates, visit:
https://github.com/catppuccin/catppuccin
EOF
    
    log_success "Final setup completed"
}

# Error handling and cleanup
cleanup() {
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "Installation failed with exit code $exit_code"
        log_info "Check the log file: $LOG_FILE"
        
        if [[ -n "$BACKUP_DIR" ]]; then
            log_info "Your original configurations are backed up at: $BACKUP_DIR"
        fi
    fi
    
    # Clean up temporary files
    rm -rf /tmp/catppuccin-gtk /tmp/papirus-folders 2>/dev/null || true
    
    exit $exit_code
}

# Set up error handling
trap cleanup EXIT INT TERM

# Main installation function
main() {
    init_logging
    show_banner
    
    log_info "Starting Perfect i3 Rice installation..."
    log_info "Installation log: $LOG_FILE"
    
    # Confirm installation
    echo -e "${YELLOW}This will install and configure a complete i3 desktop environment.${NC}"
    echo -e "${YELLOW}Your existing configurations will be backed up.${NC}"
    echo
    read -p "Continue with installation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled by user"
        exit 0
    fi
    
    # Installation steps
    check_system
    backup_configs
    update_system
    install_core_packages
    install_fonts
    install_additional_software
    create_directories
    install_configurations
    download_wallpapers
    setup_themes
    configure_services
    final_setup
    
    # Success message
    echo
    echo -e "${GREEN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                    Installation Complete!                     ║
║                                                               ║
║  🚀 Log out and select 'i3' as your session                  ║
║  💡 Press Super+d to open the app launcher                   ║
║  📖 Check ~/Documents/system-info.txt for details            ║
║  🎨 Your perfect rice is ready to use!                       ║
║                                                               ║
║  🔧 Troubleshooting:                                          ║
║     - Check log: /tmp/i3-rice-install.log                    ║
║     - Restore backup if needed                               ║
║     - Run 'rice-update' to refresh configs                   ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    log_success "Perfect i3 Rice installed successfully!"
    log_info "Installation completed in $(date)"
    log_info "Backup location: $BACKUP_DIR"
    log_info "Log file: $LOG_FILE"
    
    # Optional reboot
    echo
    read -p "Reboot now to complete installation? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Rebooting system..."
        sudo reboot
    else
        log_info "Please reboot manually to complete the installation"
    fi
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Perfect i3 Rice Installer"
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --debug        Enable debug output"
        echo "  --no-backup    Skip configuration backup"
        echo "  --minimal      Install minimal configuration only"
        echo
        exit 0
        ;;
    --debug)
        DEBUG=true
        main
        ;;
    --no-backup)
        backup_configs() { log_info "Skipping backup as requested"; }
        main
        ;;
    --minimal)
        install_additional_software() { log_info "Skipping additional software (minimal install)"; }
        download_wallpapers() { log_info "Skipping wallpaper download (minimal install)"; }
        main
        ;;
    *)
        main
        ;;
esac
