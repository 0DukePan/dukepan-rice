# Duke Pan's i3 Rice

Welcome to **Duke Pan's i3 Rice** – a customized i3 window manager setup designed for productivity, minimalism, and aesthetics.

## ✨ Features
- 🚀 Lightweight and blazing fast
- 🎨 Clean, minimal design with carefully chosen colors
- ⌨️ Intuitive keybindings for efficiency
- 🖥️ Polybar with essential modules (workspaces, network, battery, etc.)
- 🪟 i3-gaps for beautiful window spacing
- 🔊 Integrated volume and brightness controls

## 📂 Structure
```
~/.config/i3/
├── config        # Main i3 configuration file
├── scripts/      # Custom scripts for automation
└── polybar/      # Polybar configuration
```

## ⚡ Requirements
- i3-gaps
- polybar
- rofi
- feh (for wallpapers)
- pulseaudio / pipewire
- fonts: JetBrainsMono Nerd Font, FontAwesome

## 🔧 Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/i3-rice.git ~/.config/i3
   ```
2. Install dependencies:
   ```bash
   sudo apt install i3 polybar rofi feh pulseaudio fonts-font-awesome
   ```
3. Restart i3 (`$mod+Shift+R`) and enjoy!

## 🎯 Keybindings
- `$mod+Enter` → Open terminal
- `$mod+D` → Rofi launcher
- `$mod+Shift+Q` → Close window
- `$mod+H/J/K/L` → Move focus (vim-style)
- `$mod+Shift+H/J/K/L` → Move window
- `$mod+F` → Toggle fullscreen

## 📸 Preview
_Add screenshots here to showcase your rice._

## 📝 Credits
Inspired by the i3 community and countless r/unixporn setups.

---
Enjoy your clean and productive workflow! 🚀
