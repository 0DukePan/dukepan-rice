#!/usr/bin/env bash

# =====================================================
# Enhanced Weather Script for Polybar - Perfect i3 Rice
# Multiple weather providers with fallback support
# Advanced caching and error handling
# =====================================================

# Configuration
CITY="${WEATHER_CITY:-}"  # Set your city or leave empty for auto-detection
UNITS="${WEATHER_UNITS:-metric}"  # metric, imperial, or si
LANG="${WEATHER_LANG:-en}"  # Language code
API_KEY="${OPENWEATHER_API_KEY:-}"  # OpenWeatherMap API key (optional)

# Cache settings
CACHE_DIR="$HOME/.cache/polybar"
CACHE_FILE="$CACHE_DIR/weather"
ERROR_CACHE_FILE="$CACHE_DIR/weather_error"
CACHE_DURATION=600  # 10 minutes in seconds
ERROR_CACHE_DURATION=300  # 5 minutes for errors

# Display settings
MAX_LENGTH=30
SHOW_TEMPERATURE=true
SHOW_CONDITION=true
SHOW_HUMIDITY=false
SHOW_WIND=false

# Colors (Catppuccin Mocha)
COLOR_NORMAL="#cdd6f4"
COLOR_WARNING="#f9e2af"
COLOR_ERROR="#f38ba8"
COLOR_SUCCESS="#a6e3a1"

# Weather icons mapping
declare -A WEATHER_ICONS=(
    # Clear/Sunny
    ["clear"]="☀️"
    ["sunny"]="☀️"
    ["sun"]="☀️"
    
    # Cloudy
    ["partly cloudy"]="⛅"
    ["partly-cloudy"]="⛅"
    ["cloudy"]="☁️"
    ["overcast"]="☁️"
    ["clouds"]="☁️"
    
    # Rain
    ["light rain"]="🌦️"
    ["rain"]="🌧️"
    ["heavy rain"]="🌧️"
    ["shower"]="🌦️"
    ["drizzle"]="🌦️"
    
    # Snow
    ["light snow"]="🌨️"
    ["snow"]="❄️"
    ["heavy snow"]="❄️"
    ["blizzard"]="❄️"
    
    # Storms
    ["thunderstorm"]="⛈️"
    ["storm"]="⛈️"
    ["thunder"]="⛈️"
    
    # Atmospheric
    ["mist"]="🌫️"
    ["fog"]="🌫️"
    ["haze"]="🌫️"
    ["smoke"]="🌫️"
    
    # Wind
    ["windy"]="💨"
    ["tornado"]="🌪️"
    
    # Default
    ["unknown"]="❓"
)

# Create cache directory if it doesn't exist
mkdir -p "$CACHE_DIR"

# Logging function
log_debug() {
    if [[ "${WEATHER_DEBUG:-false}" == "true" ]]; then
        echo "[WEATHER DEBUG] $1" >&2
    fi
}

# Function to get location automatically
get_location() {
    local location=""
    
    # Try multiple location services
    local services=(
        "https://ipapi.co/city"
        "https://ipinfo.io/city"
        "https://api.ipify.org"
    )
    
    for service in "${services[@]}"; do
        if command -v curl >/dev/null 2>&1; then
            location=$(curl -s --max-time 5 "$service" 2>/dev/null | tr -d '\n\r' | head -c 50)
        elif command -v wget >/dev/null 2>&1; then
            location=$(wget -qO- --timeout=5 "$service" 2>/dev/null | tr -d '\n\r' | head -c 50)
        fi
        
        if [[ -n "$location" && "$location" != *"error"* ]]; then
            log_debug "Location detected: $location"
            echo "$location"
            return 0
        fi
    done
    
    log_debug "Failed to detect location automatically"
    return 1
}

# Function to get weather from wttr.in
get_weather_wttr() {
    local city="$1"
    local url="https://wttr.in/${city}?format=%C+%t+%h+%w&units=${UNITS}&lang=${LANG}"
    
    log_debug "Fetching weather from wttr.in: $url"
    
    if command -v curl >/dev/null 2>&1; then
        curl -s --max-time 10 "$url" 2>/dev/null
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- --timeout=10 "$url" 2>/dev/null
    else
        return 1
    fi
}

# Function to get weather from OpenWeatherMap
get_weather_openweather() {
    local city="$1"
    local api_key="$2"
    
    if [[ -z "$api_key" ]]; then
        return 1
    fi
    
    local url="https://api.openweathermap.org/data/2.5/weather?q=${city}&appid=${api_key}&units=${UNITS}&lang=${LANG}"
    
    log_debug "Fetching weather from OpenWeatherMap: $url"
    
    local response
    if command -v curl >/dev/null 2>&1; then
        response=$(curl -s --max-time 10 "$url" 2>/dev/null)
    elif command -v wget >/dev/null 2>&1; then
        response=$(wget -qO- --timeout=10 "$url" 2>/dev/null)
    else
        return 1
    fi
    
    # Parse JSON response (basic parsing without jq)
    if [[ "$response" == *'"main":'* ]]; then
        local temp=$(echo "$response" | grep -o '"temp":[^,]*' | cut -d':' -f2)
        local desc=$(echo "$response" | grep -o '"description":"[^"]*' | cut -d'"' -f4)
        local humidity=$(echo "$response" | grep -o '"humidity":[^,]*' | cut -d':' -f2)
        
        # Format temperature
        if [[ "$UNITS" == "metric" ]]; then
            temp="${temp}°C"
        elif [[ "$UNITS" == "imperial" ]]; then
            temp="${temp}°F"
        else
            temp="${temp}K"
        fi
        
        echo "$desc $temp $humidity%"
    else
        return 1
    fi
}

# Function to format weather output
format_weather() {
    local weather_data="$1"
    
    # Check if we got valid data
    if [[ -z "$weather_data" || "$weather_data" == *"Unknown location"* || "$weather_data" == *"error"* ]]; then
        return 1
    fi
    
    # Clean up the weather data
    weather_data=$(echo "$weather_data" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Extract components
    local condition=""
    local temperature=""
    local humidity=""
    local wind=""
    
    # Parse different formats
    if [[ "$weather_data" =~ ^([^0-9+-]+)[[:space:]]*([+-]?[0-9]+°[CF])[[:space:]]*([0-9]+%)?[[:space:]]*(.*)$ ]]; then
        condition="${BASH_REMATCH[1]}"
        temperature="${BASH_REMATCH[2]}"
        humidity="${BASH_REMATCH[3]}"
        wind="${BASH_REMATCH[4]}"
    else
        # Fallback parsing
        condition=$(echo "$weather_data" | sed 's/[+-][0-9]*°[CF].*$//' | xargs)
        temperature=$(echo "$weather_data" | grep -o '[+-][0-9]*°[CF]' | head -1)
        humidity=$(echo "$weather_data" | grep -o '[0-9]*%' | head -1)
    fi
    
    # Get weather icon
    local icon=""
    local condition_lower=$(echo "$condition" | tr '[:upper:]' '[:lower:]')
    
    for key in "${!WEATHER_ICONS[@]}"; do
        if [[ "$condition_lower" == *"$key"* ]]; then
            icon="${WEATHER_ICONS[$key]}"
            break
        fi
    done
    
    # Default icon if none found
    if [[ -z "$icon" ]]; then
        icon="${WEATHER_ICONS[unknown]}"
    fi
    
    # Build output string
    local output=""
    
    if [[ "$SHOW_CONDITION" == "true" ]]; then
        output="$icon"
    fi
    
    if [[ "$SHOW_TEMPERATURE" == "true" && -n "$temperature" ]]; then
        if [[ -n "$output" ]]; then
            output="$output $temperature"
        else
            output="$temperature"
        fi
    fi
    
    if [[ "$SHOW_HUMIDITY" == "true" && -n "$humidity" ]]; then
        output="$output 💧$humidity"
    fi
    
    if [[ "$SHOW_WIND" == "true" && -n "$wind" ]]; then
        output="$output 💨$wind"
    fi
    
    # Truncate if too long
    if [[ ${#output} -gt $MAX_LENGTH ]]; then
        output="${output:0:$((MAX_LENGTH-3))}..."
    fi
    
    echo "$output"
}

# Function to check if cache is valid
is_cache_valid() {
    local cache_file="$1"
    local duration="$2"
    
    if [[ -f "$cache_file" ]]; then
        local cache_time=$(stat -c %Y "$cache_file" 2>/dev/null || echo 0)
        local current_time=$(date +%s)
        local age=$((current_time - cache_time))
        
        if [[ $age -lt $duration ]]; then
            return 0
        fi
    fi
    return 1
}

# Function to save to cache
save_to_cache() {
    local data="$1"
    local cache_file="$2"
    
    echo "$data" > "$cache_file"
    log_debug "Saved to cache: $cache_file"
}

# Function to get weather data
get_weather_data() {
    local city="$1"
    local weather_data=""
    
    # Try different weather providers
    log_debug "Trying wttr.in..."
    weather_data=$(get_weather_wttr "$city")
    
    if [[ -z "$weather_data" || "$weather_data" == *"error"* ]]; then
        log_debug "wttr.in failed, trying OpenWeatherMap..."
        weather_data=$(get_weather_openweather "$city" "$API_KEY")
    fi
    
    echo "$weather_data"
}

# Function to handle click events
handle_click() {
    case "$1" in
        --click|--left-click)
            # Open weather website
            local city="${CITY:-$(get_location)}"
            local url="https://wttr.in/${city}"
            
            if command -v xdg-open >/dev/null 2>&1; then
                xdg-open "$url" >/dev/null 2>&1 &
            elif command -v firefox >/dev/null 2>&1; then
                firefox "$url" >/dev/null 2>&1 &
            fi
            ;;
        --right-click)
            # Force refresh
            rm -f "$CACHE_FILE" "$ERROR_CACHE_FILE"
            exec "$0"
            ;;
        --middle-click)
            # Show detailed weather
            local city="${CITY:-$(get_location)}"
            if command -v curl >/dev/null 2>&1; then
                curl -s "https://wttr.in/${city}?T" | head -20 | notify-send -t 10000 "Weather Details" "$(cat)"
            fi
            ;;
    esac
}

# Main execution function
main() {
    # Determine city to use
    local city="$CITY"
    if [[ -z "$city" ]]; then
        city=$(get_location)
        if [[ -z "$city" ]]; then
            city="New York"  # Fallback
        fi
    fi
    
    log_debug "Using city: $city"
    
    # Check if we should use cached data
    if is_cache_valid "$CACHE_FILE" "$CACHE_DURATION"; then
        log_debug "Using cached weather data"
        cat "$CACHE_FILE"
        return 0
    fi
    
    # Check if we're in error cache period
    if is_cache_valid "$ERROR_CACHE_FILE" "$ERROR_CACHE_DURATION"; then
        log_debug "In error cache period, using old cache if available"
        if [[ -f "$CACHE_FILE" ]]; then
            cat "$CACHE_FILE"
        else
            echo "Weather unavailable"
        fi
        return 0
    fi
    
    # Get fresh weather data
    log_debug "Fetching fresh weather data..."
    local weather_raw=$(get_weather_data "$city")
    
    if [[ -n "$weather_raw" && "$weather_raw" != *"error"* && "$weather_raw" != *"Unknown location"* ]]; then
        # Format the weather data
        local weather_formatted=$(format_weather "$weather_raw")
        
        if [[ -n "$weather_formatted" ]]; then
            # Save to cache
            save_to_cache "$weather_formatted" "$CACHE_FILE"
            
            # Remove error cache
            rm -f "$ERROR_CACHE_FILE"
            
            echo "$weather_formatted"
            return 0
        fi
    fi
    
    # Error occurred - save error cache and use old data if available
    log_debug "Error fetching weather data"
    save_to_cache "error" "$ERROR_CACHE_FILE"
    
    if [[ -f "$CACHE_FILE" ]]; then
        log_debug "Using old cached data due to error"
        cat "$CACHE_FILE"
    else
        echo "Weather error"
    fi
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Enhanced Weather Script for Polybar"
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h         Show this help message"
        echo "  --click            Handle left click (open weather website)"
        echo "  --right-click      Handle right click (force refresh)"
        echo "  --middle-click     Handle middle click (show details)"
        echo "  --refresh          Force refresh weather data"
        echo "  --config           Show current configuration"
        echo ""
        echo "Environment Variables:"
        echo "  WEATHER_CITY       City name (auto-detected if not set)"
        echo "  WEATHER_UNITS      Units: metric, imperial, si (default: metric)"
        echo "  WEATHER_LANG       Language code (default: en)"
        echo "  OPENWEATHER_API_KEY OpenWeatherMap API key (optional)"
        echo "  WEATHER_DEBUG      Enable debug output (default: false)"
        echo ""
        exit 0
        ;;
    --click|--left-click|--right-click|--middle-click)
        handle_click "$1"
        ;;
    --refresh)
        rm -f "$CACHE_FILE" "$ERROR_CACHE_FILE"
        main
        ;;
    --config)
        echo "Weather Script Configuration:"
        echo "  City: ${CITY:-auto-detect}"
        echo "  Units: $UNITS"
        echo "  Language: $LANG"
        echo "  API Key: ${API_KEY:+set}"
        echo "  Cache Duration: ${CACHE_DURATION}s"
        echo "  Cache Directory: $CACHE_DIR"
        ;;
    *)
        main
        ;;
esac
