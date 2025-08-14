# Perfect i3 Rice Setup Guide for duke pan

## 🚀 Complete Installation Steps

### Prerequisites
- Pop!_OS 22.04+ or Ubuntu 20.04+
- At least 4GB RAM and 2GB free disk space
- Active internet connection
- Administrative privileges

### Step 1: Download and Prepare
\`\`\`bash
# Clone or download the configuration
git clone <repository-url> perfect-i3-rice
cd perfect-i3-rice

# Make installer executable
chmod +x install.sh
\`\`\`

### Step 2: Run the Installer
\`\`\`bash
# Full installation (recommended)
./install.sh

# Alternative installation options
./install.sh --debug          # Enable debug output
./install.sh --minimal        # Minimal installation
./install.sh --no-backup      # Skip backup creation
\`\`\`

### Step 3: Post-Installation Setup

#### 3.1 Session Selection
1. Log out of your current session
2. At the login screen, click the gear icon
3. Select "i3" from the session options
4. Log in with your credentials

#### 3.2 Initial Configuration
\`\`\`bash
# Set up dynamic wallpapers
~/.local/bin/dynamic-wallpaper.sh setup

# Configure calendar integration
~/.local/bin/calendar-integration.sh setup

# Initialize note-taking system
~/.local/bin/notes-system.sh init

# Setup password manager
~/.local/bin/password-manager.sh setup
\`\`\`

#### 3.3 Font Configuration
\`\`\`bash
# Verify fonts are installed
fc-list | grep -i "jetbrains\|nerd"

# If fonts are missing, reinstall
sudo apt install fonts-jetbrains-mono
fc-cache -fv
\`\`\`

#### 3.4 Theme Verification
\`\`\`bash
# Check GTK theme
gsettings get org.gnome.desktop.interface gtk-theme

# Verify icon theme
gsettings get org.gnome.desktop.interface icon-theme

# Test wallpaper system
nitrogen --restore
\`\`\`

### Step 4: Service Configuration

#### 4.1 Enable User Services
\`\`\`bash
# Enable Polybar auto-start
systemctl --user enable polybar.service

# Enable dynamic wallpaper service
systemctl --user enable dynamic-wallpaper.service

# Start all services
systemctl --user start polybar dynamic-wallpaper
\`\`\`

#### 4.2 Configure System Services
\`\`\`bash
# Enable Bluetooth
sudo systemctl enable bluetooth
sudo systemctl start bluetooth

# Configure NetworkManager
sudo systemctl enable NetworkManager
\`\`\`

### Step 5: Application Setup

#### 5.1 Terminal Configuration
\`\`\`bash
# Set up Zsh (if not already done)
~/.local/bin/zsh-setup.sh

# Configure tmux
~/.local/bin/tmux-setup.sh

# Test terminal themes
alacritty --config-file ~/.config/alacritty/alacritty.toml
kitty --config ~/.config/kitty/kitty.conf
\`\`\`

#### 5.2 Development Environment
\`\`\`bash
# Install development tools
sudo apt install nodejs npm python3-pip docker.io

# Configure Git
git config --global user.name "duke pan"
git config --global user.email "your-email@example.com"

# Set up development workspace
mkdir -p ~/Projects ~/Scripts
\`\`\`

#### 5.3 Media and Graphics
\`\`\`bash
# Test screenshot functionality
flameshot gui

# Configure media controls
playerctl --version

# Set up graphics tools
gimp --version
\`\`\`

### Step 6: Customization

#### 6.1 Wallpaper Management
\`\`\`bash
# Download additional wallpapers
~/.local/bin/wallpaper-manager.sh download

# Set custom wallpaper
~/.local/bin/wallpaper-manager.sh set /path/to/wallpaper.jpg

# Configure dynamic wallpapers
~/.local/bin/dynamic-wallpaper.sh config
\`\`\`

#### 6.2 Polybar Customization
\`\`\`bash
# Edit Polybar configuration
nano ~/.config/polybar/config.ini

# Restart Polybar
~/.config/polybar/launch.sh

# Test weather module
~/.config/polybar/scripts/weather.sh
\`\`\`

#### 6.3 Rofi Themes
\`\`\`bash
# Test Rofi launcher
rofi -show drun -theme ~/.config/rofi/themes/launcher.rasi

# Configure power menu
~/.config/rofi/scripts/powermenu.sh

# Test clipboard manager
~/.config/rofi/scripts/clipboard-manager.sh
\`\`\`

### Step 7: Productivity Tools Setup

#### 7.1 Calendar Integration
\`\`\`bash
# Configure Google Calendar
~/.local/bin/calendar-integration.sh auth

# Test calendar display
~/.config/rofi/scripts/calendar.sh
\`\`\`

#### 7.2 Note-Taking System
\`\`\`bash
# Create first note
~/.local/bin/notes-quick-capture.sh "My first note"

# Open notes menu
~/.config/rofi/scripts/notes-menu.sh
\`\`\`

#### 7.3 Password Manager
\`\`\`bash
# Initialize password store
~/.local/bin/password-manager.sh init

# Add first password
~/.config/rofi/scripts/password-menu.sh
\`\`\`

### Step 8: Verification and Testing

#### 8.1 System Check
\`\`\`bash
# Run system diagnostics
~/.local/bin/system-monitor.sh check

# Test all key bindings
# See KEYBINDINGS.md for complete list

# Verify all services
systemctl --user status polybar dynamic-wallpaper
\`\`\`

#### 8.2 Performance Optimization
\`\`\`bash
# Enable battery optimization
~/.local/bin/battery-optimizer.sh enable

# Configure network monitoring
~/.local/bin/network-monitor.sh start

# Set up gesture support
~/.local/bin/gesture-handler.sh --start
\`\`\`

## 🔧 Troubleshooting

### Common Issues

#### Polybar Not Starting
\`\`\`bash
# Check Polybar logs
journalctl --user -u polybar.service

# Restart Polybar manually
killall polybar
~/.config/polybar/launch.sh
\`\`\`

#### Fonts Not Displaying
\`\`\`bash
# Reinstall fonts
sudo apt install --reinstall fonts-jetbrains-mono
fc-cache -fv
\`\`\`

#### Wallpaper Issues
\`\`\`bash
# Reset wallpaper system
nitrogen --restore
~/.local/bin/dynamic-wallpaper.sh reset
\`\`\`

#### Audio Problems
\`\`\`bash
# Restart audio services
systemctl --user restart pipewire pipewire-pulse
pulseaudio --kill && pulseaudio --start
\`\`\`

### Recovery Options

#### Restore Backup
\`\`\`bash
# Find backup location
ls ~/.config/i3-rice-backup-*

# Restore configurations
cp -r ~/.config/i3-rice-backup-*/. ~/.config/
\`\`\`

#### Reset to Defaults
\`\`\`bash
# Remove current configuration
rm -rf ~/.config/i3 ~/.config/polybar ~/.config/rofi

# Reinstall
./install.sh --no-backup
\`\`\`

## 📚 Additional Resources

### Configuration Files
- i3 config: `~/.config/i3/config`
- Polybar: `~/.config/polybar/config.ini`
- Rofi themes: `~/.config/rofi/themes/`
- Scripts: `~/.local/bin/`

### Logs and Debugging
- Installation log: `/tmp/i3-rice-install.log`
- i3 log: `~/.local/share/i3/i3log`
- Polybar log: `~/.config/polybar/polybar.log`

### Community and Support
- Catppuccin theme: https://github.com/catppuccin/catppuccin
- i3 documentation: https://i3wm.org/docs/
- Polybar wiki: https://github.com/polybar/polybar/wiki

## 🎯 Next Steps

1. Customize colors in `~/.config/i3/config`
2. Add personal applications to autostart
3. Configure workspace-specific layouts
4. Set up additional Rofi modi
5. Explore advanced scripting options

Your perfect i3 rice is now ready! Enjoy your beautiful and productive desktop environment.
