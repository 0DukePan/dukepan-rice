#!/usr/bin/env bash
# Perfect system load display

load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
echo "$load_avg"
