#!/usr/bin/env bash

# =====================================================
# Voice Control System for i3 Rice
# Speech recognition for common i3 commands
# =====================================================

set -euo pipefail

# Configuration
CONFIG_DIR="$HOME/.config/voice-control"
CACHE_DIR="$HOME/.cache/voice-control"
LOG_FILE="$CACHE_DIR/voice-control.log"
COMMANDS_FILE="$CONFIG_DIR/commands.json"

# Voice commands mapping
declare -A VOICE_COMMANDS=(
    # Window management
    ["close window"]="i3-msg kill"
    ["kill window"]="i3-msg kill"
    ["fullscreen"]="i3-msg fullscreen toggle"
    ["floating"]="i3-msg floating toggle"
    ["split horizontal"]="i3-msg split h"
    ["split vertical"]="i3-msg split v"
    
    # Workspace navigation
    ["workspace one"]="i3-msg workspace 1"
    ["workspace two"]="i3-msg workspace 2"
    ["workspace three"]="i3-msg workspace 3"
    ["workspace four"]="i3-msg workspace 4"
    ["workspace five"]="i3-msg workspace 5"
    ["next workspace"]="i3-msg workspace next"
    ["previous workspace"]="i3-msg workspace prev"
    
    # Applications
    ["open terminal"]="alacritty"
    ["open browser"]="brave-browser"
    ["open file manager"]="thunar"
    ["open calculator"]="gnome-calculator"
    
    # System controls
    ["lock screen"]="i3lock-fancy"
    ["reload config"]="i3-msg reload"
    ["restart i3"]="i3-msg restart"
    
    # Rofi menus
    ["app launcher"]="rofi -modi drun -show drun"
    ["window switcher"]="rofi -modi window -show window"
    ["power menu"]="~/.config/rofi/scripts/powermenu.sh"
    
    # Volume controls
    ["volume up"]="pactl set-sink-volume @DEFAULT_SINK@ +10%"
    ["volume down"]="pactl set-sink-volume @DEFAULT_SINK@ -10%"
    ["mute"]="pactl set-sink-mute @DEFAULT_SINK@ toggle"
)

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Initialize system
init_system() {
    mkdir -p "$CONFIG_DIR" "$CACHE_DIR"
    
    if [[ ! -f "$CONFIG_DIR/config" ]]; then
        cat > "$CONFIG_DIR/config" << 'EOF'
# Voice Control Configuration
ENABLE_VOICE_CONTROL=true
ENABLE_CONTINUOUS_LISTENING=false
VOICE_ACTIVATION_PHRASE="computer"
CONFIDENCE_THRESHOLD=0.7
LANGUAGE="en-US"
MICROPHONE_DEVICE="default"
ENABLE_FEEDBACK=true
ENABLE_BEEP=true
TIMEOUT_SECONDS=5
EOF
    fi
    
    source "$CONFIG_DIR/config"
    
    # Create commands file
    create_commands_file
}

# Create commands file
create_commands_file() {
    if [[ ! -f "$COMMANDS_FILE" ]]; then
        local commands_json="{"
        for phrase in "${!VOICE_COMMANDS[@]}"; do
            local command="${VOICE_COMMANDS[$phrase]}"
            commands_json+='"'"$phrase"'":"'"$command"'",'
        done
        commands_json="${commands_json%,}}"
        
        echo "$commands_json" | jq '.' > "$COMMANDS_FILE"
    fi
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for speech recognition tools
    if ! command -v speech-recognition &>/dev/null; then
        if ! python3 -c "import speech_recognition" 2>/dev/null; then
            missing_deps+=("python3-speech-recognition")
        fi
    fi
    
    # Check for audio tools
    if ! command -v arecord &>/dev/null; then
        missing_deps+=("alsa-utils")
    fi
    
    if ! command -v pactl &>/dev/null; then
        missing_deps+=("pulseaudio-utils")
    fi
    
    # Install missing dependencies
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "Installing missing dependencies: ${missing_deps[*]}"
        
        # Install Python speech recognition
        if [[ " ${missing_deps[*]} " =~ " python3-speech-recognition " ]]; then
            pip3 install --user SpeechRecognition pyaudio
        fi
        
        # Install system packages
        local system_deps=()
        for dep in "${missing_deps[@]}"; do
            if [[ "$dep" != "python3-speech-recognition" ]]; then
                system_deps+=("$dep")
            fi
        done
        
        if [[ ${#system_deps[@]} -gt 0 ]]; then
            sudo apt update && sudo apt install -y "${system_deps[@]}"
        fi
    fi
}

# Create speech recognition script
create_speech_script() {
    cat > "$CACHE_DIR/speech_recognition.py" << 'EOF'
#!/usr/bin/env python3

import speech_recognition as sr
import sys
import json
import os
from difflib import SequenceMatcher

def similarity(a, b):
    return SequenceMatcher(None, a, b).ratio()

def recognize_speech(timeout=5, phrase_time_limit=None):
    r = sr.Recognizer()
    
    # Use default microphone
    with sr.Microphone() as source:
        print("Listening...", file=sys.stderr)
        r.adjust_for_ambient_noise(source, duration=0.5)
        
        try:
            audio = r.listen(source, timeout=timeout, phrase_time_limit=phrase_time_limit)
            print("Processing...", file=sys.stderr)
            
            # Try Google Speech Recognition
            try:
                text = r.recognize_google(audio)
                return text.lower()
            except sr.UnknownValueError:
                return None
            except sr.RequestError:
                # Fallback to offline recognition if available
                try:
                    text = r.recognize_sphinx(audio)
                    return text.lower()
                except:
                    return None
                    
        except sr.WaitTimeoutError:
            return None

def find_best_match(recognized_text, commands):
    best_match = None
    best_score = 0
    
    for command_phrase in commands:
        score = similarity(recognized_text, command_phrase.lower())
        if score > best_score:
            best_score = score
            best_match = command_phrase
    
    return best_match, best_score

def main():
    if len(sys.argv) > 1:
        timeout = int(sys.argv[1])
    else:
        timeout = 5
    
    # Load commands
    commands_file = os.path.expanduser("~/.config/voice-control/commands.json")
    try:
        with open(commands_file, 'r') as f:
            commands = json.load(f)
    except:
        print("Error loading commands file", file=sys.stderr)
        sys.exit(1)
    
    # Recognize speech
    recognized_text = recognize_speech(timeout=timeout)
    
    if recognized_text:
        print(f"Recognized: {recognized_text}", file=sys.stderr)
        
        # Find best matching command
        best_match, score = find_best_match(recognized_text, commands.keys())
        
        if best_match and score > 0.7:  # Confidence threshold
            print(f"Matched: {best_match} (confidence: {score:.2f})", file=sys.stderr)
            print(commands[best_match])
        else:
            print(f"No confident match found (best: {best_match}, score: {score:.2f})", file=sys.stderr)
            sys.exit(1)
    else:
        print("No speech recognized", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
EOF
    
    chmod +x "$CACHE_DIR/speech_recognition.py"
}

# Listen for voice command
listen_for_command() {
    local timeout="${1:-$TIMEOUT_SECONDS}"
    
    log "Listening for voice command (timeout: ${timeout}s)..."
    
    # Play beep if enabled
    if [[ "$ENABLE_BEEP" == "true" ]]; then
        paplay /usr/share/sounds/freedesktop/stereo/audio-volume-change.oga 2>/dev/null &
    fi
    
    # Show notification
    if [[ "$ENABLE_FEEDBACK" == "true" ]]; then
        notify-send -t 3000 "Voice Control" "Listening for command..." -i "audio-input-microphone"
    fi
    
    # Recognize speech
    local command=$(python3 "$CACHE_DIR/speech_recognition.py" "$timeout" 2>/tmp/voice_debug.log)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]] && [[ -n "$command" ]]; then
        log "Executing command: $command"
        
        # Show feedback
        if [[ "$ENABLE_FEEDBACK" == "true" ]]; then
            notify-send -t 2000 "Voice Control" "Executing command" -i "audio-input-microphone"
        fi
        
        # Execute command
        eval "$command" &
        
        return 0
    else
        log "No command recognized or executed"
        
        if [[ "$ENABLE_FEEDBACK" == "true" ]]; then
            notify-send -t 2000 "Voice Control" "Command not recognized" -i "dialog-warning"
        fi
        
        return 1
    fi
}

# Continuous listening mode
continuous_listening() {
    log "Starting continuous listening mode..."
    
    if [[ "$ENABLE_FEEDBACK" == "true" ]]; then
        notify-send "Voice Control" "Continuous listening started" -i "audio-input-microphone"
    fi
    
    while true; do
        if [[ "$ENABLE_VOICE_CONTROL" == "true" ]]; then
            # Listen for activation phrase
            if [[ -n "$VOICE_ACTIVATION_PHRASE" ]]; then
                log "Waiting for activation phrase: $VOICE_ACTIVATION_PHRASE"
                
                local recognized=$(python3 "$CACHE_DIR/speech_recognition.py" 10 2>/dev/null || echo "")
                
                if [[ "$recognized" =~ $VOICE_ACTIVATION_PHRASE ]]; then
                    log "Activation phrase detected"
                    listen_for_command 3
                fi
            else
                # Direct command listening
                listen_for_command 5
            fi
        fi
        
        sleep 1
    done
}

# Show voice commands
show_commands() {
    local commands=$(cat "$COMMANDS_FILE")
    local options="🎤 Voice Commands\n---\n"
    
    echo "$commands" | jq -r 'to_entries[] | "\(.key) → \(.value)"' | while read -r line; do
        options+="$line\n"
    done
    
    echo -e "${options%\\n}" | rofi -dmenu -i -p "Voice Commands" \
        -theme ~/.config/rofi/themes/voice-control.rasi \
        -mesg "Available voice commands"
}

# Test microphone
test_microphone() {
    log "Testing microphone..."
    
    if [[ "$ENABLE_FEEDBACK" == "true" ]]; then
        notify-send "Voice Control" "Testing microphone - say something" -i "audio-input-microphone"
    fi
    
    local result=$(python3 "$CACHE_DIR/speech_recognition.py" 5 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log "Microphone test successful: $result"
        notify-send "Voice Control" "Microphone working: $result" -i "audio-input-microphone"
    else
        log "Microphone test failed: $result"
        notify-send "Voice Control" "Microphone test failed" -i "dialog-error"
    fi
}

# Toggle voice control
toggle_voice_control() {
    if [[ "$ENABLE_VOICE_CONTROL" == "true" ]]; then
        sed -i 's/ENABLE_VOICE_CONTROL=true/ENABLE_VOICE_CONTROL=false/' "$CONFIG_DIR/config"
        pkill -f "voice-control.sh continuous" 2>/dev/null || true
        notify-send "Voice Control" "Voice control disabled" -i "audio-input-microphone-muted"
        log "Voice control disabled"
    else
        sed -i 's/ENABLE_VOICE_CONTROL=false/ENABLE_VOICE_CONTROL=true/' "$CONFIG_DIR/config"
        notify-send "Voice Control" "Voice control enabled" -i "audio-input-microphone"
        log "Voice control enabled"
    fi
}

# Create voice control theme
create_theme() {
    local theme_file="$HOME/.config/rofi/themes/voice-control.rasi"
    mkdir -p "$(dirname "$theme_file")"
    
    cat > "$theme_file" << 'EOF'
* {
    background: #1e1e2e;
    background-alt: #313244;
    foreground: #cdd6f4;
    selected: #cba6f7;
    active: #a6e3a1;
    urgent: #f38ba8;
    border: #6c7086;
}

window {
    transparency: "real";
    location: center;
    anchor: center;
    fullscreen: false;
    width: 500px;
    x-offset: 0px;
    y-offset: 0px;
    enabled: true;
    margin: 0px;
    padding: 0px;
    border: 2px solid;
    border-radius: 12px;
    border-color: @border;
    cursor: "default";
    background-color: @background;
}

mainbox {
    enabled: true;
    spacing: 10px;
    margin: 0px;
    padding: 20px;
    border: 0px solid;
    border-radius: 0px;
    border-color: @border;
    background-color: transparent;
    children: [ "inputbar", "message", "listview" ];
}

inputbar {
    enabled: true;
    spacing: 10px;
    margin: 0px;
    padding: 10px;
    border: 0px solid;
    border-radius: 8px;
    border-color: @border;
    background-color: @background-alt;
    text-color: @foreground;
    children: [ "textbox-prompt-colon", "prompt" ];
}

prompt {
    enabled: true;
    background-color: transparent;
    text-color: inherit;
    font: "JetBrainsMono Nerd Font Bold 12";
}

textbox-prompt-colon {
    enabled: true;
    expand: false;
    str: "🎤";
    background-color: transparent;
    text-color: inherit;
    font: "JetBrainsMono Nerd Font 14";
}

listview {
    enabled: true;
    columns: 1;
    lines: 12;
    cycle: true;
    dynamic: true;
    scrollbar: true;
    layout: vertical;
    reverse: false;
    fixed-height: true;
    fixed-columns: true;
    spacing: 3px;
    margin: 0px;
    padding: 0px;
    border: 0px solid;
    border-radius: 0px;
    border-color: @border;
    background-color: transparent;
    text-color: @foreground;
    cursor: "default";
}

element {
    enabled: true;
    spacing: 8px;
    margin: 0px;
    padding: 8px;
    border: 0px solid;
    border-radius: 6px;
    border-color: @border;
    background-color: transparent;
    text-color: @foreground;
    cursor: pointer;
}

element selected.normal {
    background-color: @selected;
    text-color: @background;
}

element-text {
    background-color: transparent;
    text-color: inherit;
    highlight: inherit;
    cursor: inherit;
    vertical-align: 0.5;
    horizontal-align: 0.0;
    font: "JetBrainsMono Nerd Font 10";
}
EOF
}

# Main function
main() {
    init_system
    check_dependencies
    create_speech_script
    create_theme
    
    case "${1:-listen}" in
        "listen")
            listen_for_command "${2:-$TIMEOUT_SECONDS}"
            ;;
        "continuous")
            continuous_listening
            ;;
        "commands")
            show_commands
            ;;
        "test")
            test_microphone
            ;;
        "toggle")
            toggle_voice_control
            ;;
        "help"|"--help")
            cat << EOF
Voice Control System - Speech recognition for i3

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    listen      Listen for single voice command (default)
    continuous  Start continuous listening mode
    commands    Show available voice commands
    test        Test microphone
    toggle      Toggle voice control on/off
    help        Show this help

Examples:
    $0 listen           # Listen for one command
    $0 continuous       # Start continuous listening
    $0 test             # Test microphone
EOF
            ;;
        *)
            echo "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

main "$@"
