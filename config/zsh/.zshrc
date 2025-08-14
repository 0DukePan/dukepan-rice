#!/usr/bin/env zsh
# =====================================================
# duke pan's Ultimate Zsh Configuration
# Perfect Zsh setup for Pop!_OS i3 Rice
# =====================================================

# Performance optimization - compile .zshrc if needed
if [[ ~/.zshrc.zwc -ot ~/.zshrc ]]; then
    zcompile ~/.zshrc
fi

# =====================================================
# Oh My Zsh Configuration
# =====================================================
export ZSH="$HOME/.oh-my-zsh"

# Theme configuration
ZSH_THEME="powerlevel10k/powerlevel10k"

# Update settings
zstyle ':omz:update' mode auto
zstyle ':omz:update' frequency 7

# Completion settings
CASE_SENSITIVE="false"
HYPHEN_INSENSITIVE="true"
DISABLE_AUTO_UPDATE="false"
DISABLE_UPDATE_PROMPT="false"
DISABLE_MAGIC_FUNCTIONS="false"
DISABLE_LS_COLORS="false"
DISABLE_AUTO_TITLE="false"
ENABLE_CORRECTION="true"
COMPLETION_WAITING_DOTS="true"
DISABLE_UNTRACKED_FILES_DIRTY="false"
HIST_STAMPS="yyyy-mm-dd"

# =====================================================
# Plugins Configuration
# =====================================================
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-completions
    colored-man-pages
    command-not-found
    extract
    web-search
    copypath
    copyfile
    copybuffer
    dirhistory
    history
    sudo
    tmux
    docker
    docker-compose
    npm
    node
    python
    pip
    systemd
    ubuntu
    vscode
    fzf
    z
    aliases
    common-aliases
    safe-paste
    jsontools
    urltools
    encode64
    battery
    bgnotify
    branch
    catimg
    chucknorris
    colorize
    cp
    dircycle
    fancy-ctrl-z
    fast-syntax-highlighting
    per-directory-history
    zsh-interactive-cd
)

# Load Oh My Zsh
source $ZSH/oh-my-zsh.sh

# =====================================================
# Powerlevel10k Configuration
# =====================================================
# Enable Powerlevel10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Powerlevel10k configuration
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# =====================================================
# Environment Variables
# =====================================================
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export EDITOR='nvim'
export VISUAL='nvim'
export PAGER='less'
export BROWSER='brave-browser'
export TERMINAL='alacritty'

# Path configuration
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/.npm-global/bin:$PATH"
export PATH="/usr/local/go/bin:$PATH"
export PATH="$HOME/go/bin:$PATH"

# XDG Base Directory Specification
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"

# Development environment
export GOPATH="$HOME/go"
export CARGO_HOME="$HOME/.cargo"
export RUSTUP_HOME="$HOME/.rustup"
export NPM_CONFIG_PREFIX="$HOME/.npm-global"

# =====================================================
# Catppuccin Mocha Colors
# =====================================================
export CATPPUCCIN_ROSEWATER="#f5e0dc"
export CATPPUCCIN_FLAMINGO="#f2cdcd"
export CATPPUCCIN_PINK="#f5c2e7"
export CATPPUCCIN_MAUVE="#cba6f7"
export CATPPUCCIN_RED="#f38ba8"
export CATPPUCCIN_MAROON="#eba0ac"
export CATPPUCCIN_PEACH="#fab387"
export CATPPUCCIN_YELLOW="#f9e2af"
export CATPPUCCIN_GREEN="#a6e3a1"
export CATPPUCCIN_TEAL="#94e2d5"
export CATPPUCCIN_SKY="#89dceb"
export CATPPUCCIN_SAPPHIRE="#74c7ec"
export CATPPUCCIN_BLUE="#89b4fa"
export CATPPUCCIN_LAVENDER="#b4befe"
export CATPPUCCIN_TEXT="#cdd6f4"
export CATPPUCCIN_SUBTEXT1="#bac2de"
export CATPPUCCIN_SUBTEXT0="#a6adc8"
export CATPPUCCIN_OVERLAY2="#9399b2"
export CATPPUCCIN_OVERLAY1="#7f849c"
export CATPPUCCIN_OVERLAY0="#6c7086"
export CATPPUCCIN_SURFACE2="#585b70"
export CATPPUCCIN_SURFACE1="#45475a"
export CATPPUCCIN_SURFACE0="#313244"
export CATPPUCCIN_BASE="#1e1e2e"
export CATPPUCCIN_MANTLE="#181825"
export CATPPUCCIN_CRUST="#11111b"

# =====================================================
# History Configuration
# =====================================================
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000

setopt EXTENDED_HISTORY
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_SAVE_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY

# =====================================================
# Zsh Options
# =====================================================
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT
setopt CORRECT
setopt CORRECT_ALL
setopt GLOB_DOTS
setopt EXTENDED_GLOB
setopt NUMERIC_GLOB_SORT
setopt RC_EXPAND_PARAM
setopt INTERACTIVE_COMMENTS
setopt HASH_LIST_ALL
setopt COMPLETE_IN_WORD
setopt ALWAYS_TO_END
setopt PATH_DIRS
setopt AUTO_MENU
setopt AUTO_LIST
setopt AUTO_PARAM_SLASH
setopt AUTO_PARAM_KEYS
setopt FLOW_CONTROL
unsetopt MENU_COMPLETE
unsetopt BEEP

# =====================================================
# Completion System
# =====================================================
autoload -Uz compinit
if [[ -n ${ZDOTDIR}/.zcompdump(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi

# Completion styling
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:group-name' ''
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
zstyle ':completion:*:messages' format '%F{purple} -- %d --%f'
zstyle ':completion:*:warnings' format '%F{red}-- no matches found --%f'
zstyle ':completion:*:corrections' format '%F{green}-- %d (errors: %e) --%f'

# =====================================================
# duke pan's Custom Aliases
# =====================================================

# System aliases
alias ll='ls -alF --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias ps='ps auxf'
alias psg='ps aux | grep -v grep | grep -i -e VSZ -e'
alias mkdir='mkdir -pv'
alias wget='wget -c'
alias histg='history | grep'
alias myip='curl http://ipecho.net/plain; echo'
alias distro='cat /etc/*-release'
alias reload='source ~/.zshrc'

# i3 specific aliases
alias i3config='$EDITOR ~/.config/i3/config'
alias polyconfig='$EDITOR ~/.config/polybar/config.ini'
alias picomconfig='$EDITOR ~/.config/picom/picom.conf'
alias roficonfig='$EDITOR ~/.config/rofi/config.rasi'
alias i3reload='i3-msg reload'
alias i3restart='i3-msg restart'

# Development aliases
alias vim='nvim'
alias vi='nvim'
alias code='code .'
alias python='python3'
alias pip='pip3'
alias serve='python3 -m http.server'
alias jsonpp='python3 -m json.tool'
alias urlencode='python3 -c "import sys, urllib.parse as ul; print(ul.quote_plus(sys.argv[1]))"'
alias urldecode='python3 -c "import sys, urllib.parse as ul; print(ul.unquote_plus(sys.argv[1]))"'

# Git aliases (enhanced)
alias g='git'
alias ga='git add'
alias gaa='git add --all'
alias gb='git branch'
alias gba='git branch -a'
alias gbd='git branch -d'
alias gc='git commit -v'
alias gcm='git commit -m'
alias gca='git commit -a'
alias gcam='git commit -a -m'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gd='git diff'
alias gds='git diff --staged'
alias gf='git fetch'
alias gl='git pull'
alias gp='git push'
alias gst='git status'
alias gss='git status -s'
alias glog='git log --oneline --decorate --graph'
alias gloga='git log --oneline --decorate --graph --all'

# Docker aliases
alias d='docker'
alias dc='docker-compose'
alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias drm='docker rm'
alias drmi='docker rmi'
alias dstop='docker stop $(docker ps -q)'
alias dclean='docker system prune -af'

# Tmux aliases
alias t='tmux'
alias ta='tmux attach'
alias tls='tmux list-sessions'
alias tnew='tmux new-session'

# System maintenance
alias update='sudo apt update && sudo apt upgrade'
alias install='sudo apt install'
alias search='apt search'
alias autoremove='sudo apt autoremove'
alias autoclean='sudo apt autoclean'
alias cleanup='sudo apt autoremove && sudo apt autoclean'

# Fun aliases
alias weather='curl wttr.in'
alias moon='curl wttr.in/Moon'
alias duke='echo "Welcome back, duke pan! 👑"'
alias rice='neofetch'
alias matrix='cmatrix -s'
alias pipes='pipes.sh'
alias clock='tty-clock -c'

# =====================================================
# Custom Functions
# =====================================================

# Create directory and cd into it
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Extract any archive
extract() {
    if [ -f $1 ] ; then
        case $1 in
            *.tar.bz2)   tar xjf $1     ;;
            *.tar.gz)    tar xzf $1     ;;
            *.bz2)       bunzip2 $1     ;;
            *.rar)       unrar e $1     ;;
            *.gz)        gunzip $1      ;;
            *.tar)       tar xf $1      ;;
            *.tbz2)      tar xjf $1     ;;
            *.tgz)       tar xzf $1     ;;
            *.zip)       unzip $1       ;;
            *.Z)         uncompress $1  ;;
            *.7z)        7z x $1        ;;
            *)     echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Find and kill process
fkill() {
    local pid
    pid=$(ps -ef | sed 1d | fzf -m | awk '{print $2}')
    if [ "x$pid" != "x" ]; then
        echo $pid | xargs kill -${1:-9}
    fi
}

# Git commit with conventional commits
gcom() {
    if [ -z "$1" ]; then
        echo "Usage: gcom <type> <message>"
        echo "Types: feat, fix, docs, style, refactor, test, chore"
        return 1
    fi
    git commit -m "$1: $2"
}

# Quick backup
backup() {
    cp "$1"{,.bak}
}

# Weather function with location
weather() {
    local location=${1:-""}
    curl -s "wttr.in/$location?format=3"
}

# System info function
sysinfo() {
    echo "🖥️  duke pan's System Information"
    echo "=================================="
    echo "Hostname: $(hostname)"
    echo "Uptime: $(uptime -p)"
    echo "Kernel: $(uname -r)"
    echo "Shell: $SHELL"
    echo "CPU: $(lscpu | grep 'Model name' | cut -f 2 -d ':' | awk '{$1=$1}1')"
    echo "Memory: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
    echo "Disk: $(df -h / | awk '/\// {print $3 "/" $2 " (" $5 ")"}')"
    echo "Load: $(uptime | awk -F'load average:' '{print $2}')"
}

# =====================================================
# FZF Configuration
# =====================================================
if command -v fzf >/dev/null 2>&1; then
    export FZF_DEFAULT_OPTS="
        --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8
        --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc
        --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8
        --height 40% --layout=reverse --border --margin=1 --padding=1"
    
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
    
    # FZF key bindings
    [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
fi

# =====================================================
# Additional Tool Configurations
# =====================================================

# Zoxide (better cd)
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
    alias cd='z'
fi

# Starship prompt (fallback if p10k not available)
if command -v starship >/dev/null 2>&1 && [[ ! -f ~/.p10k.zsh ]]; then
    eval "$(starship init zsh)"
fi

# Direnv
if command -v direnv >/dev/null 2>&1; then
    eval "$(direnv hook zsh)"
fi

# Thefuck
if command -v thefuck >/dev/null 2>&1; then
    eval $(thefuck --alias)
fi

# =====================================================
# Syntax Highlighting & Autosuggestions
# =====================================================
# Syntax highlighting colors (Catppuccin)
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern cursor)
ZSH_HIGHLIGHT_STYLES[default]=none
ZSH_HIGHLIGHT_STYLES[unknown-token]=fg=red,bold
ZSH_HIGHLIGHT_STYLES[reserved-word]=fg=cyan,bold
ZSH_HIGHLIGHT_STYLES[suffix-alias]=fg=green,underline
ZSH_HIGHLIGHT_STYLES[global-alias]=fg=magenta
ZSH_HIGHLIGHT_STYLES[precommand]=fg=green,underline
ZSH_HIGHLIGHT_STYLES[commandseparator]=fg=blue,bold
ZSH_HIGHLIGHT_STYLES[autodirectory]=fg=green,underline
ZSH_HIGHLIGHT_STYLES[path]=underline
ZSH_HIGHLIGHT_STYLES[path_pathseparator]=
ZSH_HIGHLIGHT_STYLES[path_prefix_pathseparator]=
ZSH_HIGHLIGHT_STYLES[globbing]=fg=blue,bold
ZSH_HIGHLIGHT_STYLES[history-expansion]=fg=blue,bold
ZSH_HIGHLIGHT_STYLES[command-substitution]=none
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter]=fg=magenta
ZSH_HIGHLIGHT_STYLES[process-substitution]=none
ZSH_HIGHLIGHT_STYLES[process-substitution-delimiter]=fg=magenta
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]=fg=magenta
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]=fg=magenta
ZSH_HIGHLIGHT_STYLES[back-quoted-argument]=none
ZSH_HIGHLIGHT_STYLES[back-quoted-argument-delimiter]=fg=blue,bold
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]=fg=yellow
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]=fg=yellow
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]=fg=yellow
ZSH_HIGHLIGHT_STYLES[rc-quote]=fg=magenta
ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]=fg=magenta
ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]=fg=magenta
ZSH_HIGHLIGHT_STYLES[back-dollar-quoted-argument]=fg=magenta
ZSH_HIGHLIGHT_STYLES[assign]=none
ZSH_HIGHLIGHT_STYLES[redirection]=fg=blue,bold
ZSH_HIGHLIGHT_STYLES[comment]=fg=black,bold
ZSH_HIGHLIGHT_STYLES[named-fd]=none
ZSH_HIGHLIGHT_STYLES[numeric-fd]=none
ZSH_HIGHLIGHT_STYLES[arg0]=fg=green

# Autosuggestions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#585b70,bg=bold"
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

# =====================================================
# duke pan's Advanced Custom Functions
# =====================================================

# Smart cd with auto ls
cd() {
    builtin cd "$@" && ls -la --color=auto
}

# Advanced git workflow functions
gwork() {
    local branch_name="$1"
    if [ -z "$branch_name" ]; then
        echo "Usage: gwork <branch-name>"
        return 1
    fi
    git checkout -b "feature/$branch_name" && git push -u origin "feature/$branch_name"
}

# Quick project setup
project() {
    local project_name="$1"
    if [ -z "$project_name" ]; then
        echo "Usage: project <project-name>"
        return 1
    fi
    mkdir -p ~/Projects/"$project_name" && cd ~/Projects/"$project_name"
    git init
    echo "# $project_name" > README.md
    echo "🚀 Project $project_name created by duke pan" >> README.md
    git add README.md && git commit -m "feat: initial commit for $project_name"
}

# System performance monitor
perf() {
    echo "🔥 duke pan's System Performance Monitor"
    echo "========================================"
    echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
    echo "Memory Usage: $(free | grep Mem | awk '{printf("%.2f%%", $3/$2 * 100.0)}')"
    echo "Disk Usage: $(df -h / | awk 'NR==2{printf "%s", $5}')"
    echo "Network: $(cat /proc/net/dev | grep -E '(eth0|wlan0|enp|wlp)' | head -1 | awk '{print "RX: " $2/1024/1024 " MB, TX: " $10/1024/1024 " MB"}')"
    echo "Processes: $(ps aux | wc -l)"
    echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
}

# Advanced file search
ff() {
    find . -type f -name "*$1*" 2>/dev/null | head -20
}

# Quick note taking
note() {
    local note_dir="$HOME/Notes"
    mkdir -p "$note_dir"
    local note_file="$note_dir/$(date +%Y-%m-%d).md"
    
    if [ -z "$1" ]; then
        $EDITOR "$note_file"
    else
        echo "$(date '+%H:%M') - $*" >> "$note_file"
        echo "📝 Note added to $(basename $note_file)"
    fi
}

# System cleanup function
cleanup() {
    echo "🧹 duke pan's System Cleanup"
    echo "============================"
    
    # APT cleanup
    echo "Cleaning APT cache..."
    sudo apt autoremove -y && sudo apt autoclean
    
    # Snap cleanup
    if command -v snap >/dev/null 2>&1; then
        echo "Cleaning snap packages..."
        sudo snap refresh
        LANG=en_US.UTF-8 snap list --all | awk '/disabled/{print $1, $3}' | while read snapname revision; do
            sudo snap remove "$snapname" --revision="$revision"
        done
    fi
    
    # Docker cleanup
    if command -v docker >/dev/null 2>&1; then
        echo "Cleaning Docker..."
        docker system prune -f
    fi
    
    # Clear logs
    echo "Clearing system logs..."
    sudo journalctl --vacuum-time=7d
    
    # Clear thumbnails
    echo "Clearing thumbnails..."
    rm -rf ~/.cache/thumbnails/*
    
    echo "✅ System cleanup completed!"
}

# =====================================================
# Advanced Development Environment
# =====================================================

# Node.js project initializer
ninit() {
    local project_name="${1:-$(basename $(pwd))}"
    npm init -y
    npm install --save-dev prettier eslint
    echo "node_modules/" > .gitignore
    echo ".env" >> .gitignore
    echo "dist/" >> .gitignore
    echo "🚀 Node.js project '$project_name' initialized by duke pan"
}

# Python virtual environment manager
venv() {
    case "$1" in
        "create")
            python3 -m venv venv
            echo "🐍 Virtual environment created"
            ;;
        "activate"|"a")
            source venv/bin/activate
            echo "🟢 Virtual environment activated"
            ;;
        "deactivate"|"d")
            deactivate
            echo "🔴 Virtual environment deactivated"
            ;;
        "install")
            if [ -f requirements.txt ]; then
                pip install -r requirements.txt
                echo "📦 Requirements installed"
            else
                echo "❌ requirements.txt not found"
            fi
            ;;
        *)
            echo "Usage: venv {create|activate|deactivate|install}"
            ;;
    esac
}

# Docker development helper
ddev() {
    case "$1" in
        "build")
            docker build -t "$(basename $(pwd)):latest" .
            ;;
        "run")
            docker run -it --rm "$(basename $(pwd)):latest"
            ;;
        "shell")
            docker run -it --rm "$(basename $(pwd)):latest) /bin/bash"
            ;;
        "logs")
            docker logs -f "$2"
            ;;
        *)
            echo "Usage: ddev {build|run|shell|logs <container>}"
            ;;
    esac
}

# =====================================================
# i3 Rice Integration Functions
# =====================================================

# Wallpaper changer with theme update
wallpaper() {
    local wallpaper_dir="$HOME/.config/wallpapers"
    if [ -z "$1" ]; then
        # Random wallpaper
        local wallpaper=$(find "$wallpaper_dir" -type f $$ -name "*.jpg" -o -name "*.png" $$ | shuf -n 1)
    else
        local wallpaper="$wallpaper_dir/$1"
    fi
    
    if [ -f "$wallpaper" ]; then
        nitrogen --set-zoom-fill "$wallpaper"
        wal -i "$wallpaper" -n
        echo "🎨 Wallpaper changed: $(basename $wallpaper)"
        echo "🎨 Theme updated with pywal"
    else
        echo "❌ Wallpaper not found: $wallpaper"
    fi
}

# i3 workspace manager
workspace() {
    case "$1" in
        "list"|"l")
            i3-msg -t get_workspaces | jq -r '.[] | "\(.num): \(.name) (\(.output))"'
            ;;
        "move"|"m")
            if [ -n "$2" ]; then
                i3-msg "move container to workspace $2"
                echo "📦 Moved container to workspace $2"
            fi
            ;;
        "rename"|"r")
            if [ -n "$2" ]; then
                i3-msg "rename workspace to \"$2\""
                echo "✏️  Workspace renamed to: $2"
            fi
            ;;
        *)
            echo "Usage: workspace {list|move <num>|rename <name>}"
            ;;
    esac
}

# System theme switcher
theme() {
    case "$1" in
        "dark")
            gsettings set org.gnome.desktop.interface gtk-theme 'Catppuccin-Mocha-Standard-Mauve-Dark'
            echo "🌙 Dark theme activated"
            ;;
        "light")
            gsettings set org.gnome.desktop.interface gtk-theme 'Catppuccin-Latte-Standard-Mauve-Light'
            echo "☀️  Light theme activated"
            ;;
        "auto")
            # Auto theme based on time
            local hour=$(date +%H)
            if [ $hour -ge 6 ] && [ $hour -lt 18 ]; then
                theme light
            else
                theme dark
            fi
            ;;
        *)
            echo "Usage: theme {dark|light|auto}"
            ;;
    esac
}

# =====================================================
# Enhanced Aliases for duke pan
# =====================================================

# Advanced system aliases
alias ports='netstat -tulanp'
alias listening='lsof -i -P -n | grep LISTEN'
alias meminfo='free -m -l -t'
alias cpuinfo='lscpu'
alias diskinfo='lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT,LABEL'
alias temp='sensors'
alias battery='upower -i /org/freedesktop/UPower/devices/battery_BAT0'

# Development shortcuts
alias serve8000='python3 -m http.server 8000'
alias serve3000='npx http-server -p 3000'
alias jsonformat='python3 -m json.tool'
alias yamlcheck='python3 -c "import yaml,sys;yaml.safe_load(sys.stdin)"'
alias base64encode='base64 -w 0'
alias base64decode='base64 -d'

# Git workflow aliases
alias gfix='git commit --amend --no-edit'
alias gundo='git reset --soft HEAD~1'
alias gclean='git clean -fd'
alias gstash='git stash push -m'
alias gpop='git stash pop'
alias glist='git stash list'
alias gdrop='git stash drop'

# Docker shortcuts
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dimg='docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"'
alias dnet='docker network ls'
alias dvol='docker volume ls'
alias dlog='docker logs -f'

# i3 rice aliases
alias i3gaps='i3-msg "gaps inner current plus 5"'
alias i3nogaps='i3-msg "gaps inner current set 0"'
alias polyrestart='~/.config/polybar/launch.sh'
alias picomrestart='pkill picom && picom --experimental-backends --config ~/.config/picom/picom.conf &'
alias dunstrestart='pkill dunst && dunst &'

# Fun and useful
alias weather-detailed='curl wttr.in/$(curl -s ipinfo.io/city)'
alias qr='qrencode -t ansiutf8'
alias speedtest='curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -'
alias publicip='curl -s ipinfo.io/ip'
alias localip='hostname -I | awk "{print \$1}"'

# =====================================================
# Productivity Enhancements
# =====================================================

# Auto-completion for custom functions
_workspace_completion() {
    local workspaces=($(i3-msg -t get_workspaces | jq -r '.[].name'))
    _describe 'workspaces' workspaces
}
compdef _workspace_completion workspace

# Smart history search
bindkey '^R' history-incremental-search-backward
bindkey '^S' history-incremental-search-forward

# Quick directory navigation
setopt AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT
alias d='dirs -v'
for index ({1..9}) alias "$index"="cd +${index}"; unset index

# Enhanced ls with icons (if exa is available)
if command -v exa >/dev/null 2>&1; then
    alias ls='exa --icons --group-directories-first'
    alias ll='exa -la --icons --group-directories-first'
    alias tree='exa --tree --icons'
fi

# =====================================================
# Final duke pan Customizations
# =====================================================

# Personal workspace setup
duke_setup() {
    echo "🎯 Setting up duke pan's workspace..."
    
    # Create essential directories
    mkdir -p ~/Projects ~/Scripts ~/Notes ~/Downloads/Software
    
    # Set up development environment
    if [ ! -d ~/.oh-my-zsh ]; then
        echo "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    fi
    
    # Install essential tools
    if ! command -v fzf >/dev/null 2>&1; then
        echo "Installing fzf..."
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
        ~/.fzf/install --all
    fi
    
    echo "✅ duke pan's workspace setup complete!"
}

# Show system info with style
duke_info() {
    clear
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    🎯 duke pan's System                      ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║ Hostname: $(hostname)                                        ║"
    echo "║ Uptime: $(uptime -p)                                         ║"
    echo "║ Shell: $SHELL                                                ║"
    echo "║ Terminal: $TERMINAL                                          ║"
    echo "║ Editor: $EDITOR                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    neofetch
}

# Quick rice showcase
rice_show() {
    echo "🎨 duke pan's Ultimate i3 Rice Showcase"
    echo "======================================"
    echo "🖥️  Window Manager: i3-gaps with Catppuccin Mocha"
    echo "🎨 Theme: Catppuccin Mocha (Dark)"
    echo "📊 Status Bar: Polybar with custom modules"
    echo "🔔 Notifications: Dunst with blur effects"
    echo "🖼️  Compositor: Picom with animations"
    echo "🐚 Shell: Zsh with Oh My Zsh + Powerlevel10k"
    echo "📱 Terminal: Alacritty + Kitty"
    echo "🔍 Launcher: Rofi with custom themes"
    echo "📝 Editor: Neovim"
    echo "🌐 Browser: Brave"
    echo ""
    echo "✨ This is the ultimate i3 rice configuration!"
}

# =====================================================
# Startup Performance Optimization
# =====================================================

# Lazy load heavy plugins
zsh_add_plugin() {
    PLUGIN_NAME=$(echo $1 | cut -d "/" -f 2)
    if [ -d "$ZSH_CUSTOM/plugins/$PLUGIN_NAME" ]; then
        # Plugin already installed
        return 0
    else
        git clone "https://github.com/$1.git" "$ZSH_CUSTOM/plugins/$PLUGIN_NAME"
    fi
}

# Conditional loading of tools
if [[ -n "$SSH_CONNECTION" ]]; then
    # Minimal setup for SSH sessions
    export PROMPT='%F{cyan}duke@%m%f:%F{yellow}%~%f$ '
else
    # Full setup for local sessions
    [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
fi

# =====================================================
# Final Cleanup
# =====================================================
# Remove duplicates from PATH
typeset -U PATH path

# Rehash for new commands
rehash

# Load local customizations if they exist
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# Final message
if [[ -o interactive ]] && [[ -z "$TMUX" ]]; then
    echo "🚀 duke pan's Ultimate Zsh Environment Ready!"
    echo "💡 Type 'duke_info' for system overview"
    echo "🎨 Type 'rice_show' to see your rice specs"
    echo ""
fi

# End of duke pan's Ultimate Zsh Configuration
