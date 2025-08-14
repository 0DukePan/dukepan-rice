# Perfect i3 Rice for Pop!_OS

A beautiful, modern, and highly functional i3 window manager configuration featuring the Catppuccin Mocha color scheme.

## Features

### Visual Excellence
- **Catppuccin Mocha** color scheme throughout all applications
- **Rounded corners** and **blur effects** via Picom compositor
- **Modern Polybar** with system monitoring and beautiful icons
- **Consistent theming** across all applications and menus

### Productivity Features
- **Dual terminal setup**: Alacritty (daily use) + Kitty (development)
- **Smart scratchpad system** for quick access to tools
- **Comprehensive Rofi menus**: apps, calculator, power, clipboard
- **Intelligent gap management** and window handling

### Modern Enhancements
- **Smooth animations** and transitions
- **Advanced notification system** with Dunst
- **Auto-lock and power management**
- **Media and brightness controls**

## Installation

1. **Clone or download** this configuration
2. **Run the installer**: `chmod +x install.sh && ./install.sh`
3. **Log out** and select **i3** as your session
4. **Enjoy your perfect rice!**

## Key Bindings

### Core
- `Super + Return` - Open Alacritty terminal
- `Super + Shift + Return` - Open Kitty terminal
- `Super + Q` - Close window
- `Super + D` - Application launcher (Rofi)

### Navigation
- `Super + H/J/K/L` - Focus window (Vim-style)
- `Super + Shift + H/J/K/L` - Move window
- `Super + 1-0` - Switch workspace
- `Super + Shift + 1-0` - Move window to workspace

### Applications
- `Super + B` - Browser
- `Super + E` - File manager
- `Super + T` - System monitor
- `Print` - Screenshot (area)
- `Shift + Print` - Screenshot (full screen)

### System
- `Super + Shift + E` - Power menu
- `Super + C` - Calculator
- `Super + V` - Clipboard manager
- `Super + Tab` - Window switcher

### Media Controls
- `XF86AudioPlay` - Play/Pause
- `XF86AudioNext/Prev` - Next/Previous track
- `XF86AudioRaiseVolume/LowerVolume` - Volume control
- `XF86MonBrightnessUp/Down` - Brightness control

## Customization

### Colors
All colors are defined in the i3 config using Catppuccin Mocha palette. You can easily modify them by changing the color variables at the top of the config.

### Fonts
The configuration uses **JetBrainsMono Nerd Font**. You can change fonts by modifying:
- i3 config: `font pango:YourFont`
- Polybar: `font-0 = YourFont:size=11`
- Alacritty: `family = "YourFont"`
- Kitty: `font_family YourFont`

### Wallpapers
Place your wallpapers in `~/Pictures/Wallpapers/` and use nitrogen to set them:
\`\`\`bash
nitrogen --set-zoom-fill ~/Pictures/Wallpapers/your-wallpaper.jpg
\`\`\`

## Components

- **Window Manager**: i3-wm
- **Status Bar**: Polybar
- **Compositor**: Picom (with blur and rounded corners)
- **Application Launcher**: Rofi
- **Notifications**: Dunst
- **Terminals**: Alacritty + Kitty
- **File Manager**: Thunar
- **Screenshot**: Flameshot

## Troubleshooting

### Polybar not showing
\`\`\`bash
killall polybar
~/.config/polybar/launch.sh
\`\`\`

### Fonts not displaying correctly
\`\`\`bash
fc-cache -fv
\`\`\`

### Compositor issues
\`\`\`bash
killall picom
picom --config ~/.config/picom/picom.conf &
\`\`\`

## Credits

- **Catppuccin** - Beautiful color scheme
- **i3** - Amazing window manager
- **Polybar** - Highly customizable status bar
- **Rofi** - Application launcher and more

Enjoy your perfect i3 rice! 🎨
# dukepan-rice
