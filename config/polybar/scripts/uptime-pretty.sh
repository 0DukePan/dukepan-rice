#!/usr/bin/env bash
# Perfect uptime display for duke pan's system

uptime_seconds=$(awk '{print int($1)}' /proc/uptime)
days=$((uptime_seconds / 86400))
hours=$(((uptime_seconds % 86400) / 3600))
minutes=$(((uptime_seconds % 3600) / 60))

if [ $days -gt 0 ]; then
    echo "${days}d ${hours}h ${minutes}m"
elif [ $hours -gt 0 ]; then
    echo "${hours}h ${minutes}m"
else
    echo "${minutes}m"
fi
