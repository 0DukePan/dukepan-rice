#!/usr/bin/env bash
# Enhanced kernel info for duke pan's perfect system

kernel_version=$(uname -r)
kernel_short=$(echo $kernel_version | cut -d'-' -f1)
echo "$kernel_short"
