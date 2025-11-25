#!/bin/bash

# Welcome script for Arch Linux Hyprland setup
# Neo-brutalist themed welcome message
# Shows every time a new terminal opens

# Only run in interactive shells
[[ $- != *i* ]] && return

# Colors
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
PURPLE=$'\033[0;35m'
CYAN=$'\033[0;36m'
NC=$'\033[0m' # No Color

# Show system info with fastfetch (compact)
if command -v fastfetch >/dev/null 2>&1; then
  fastfetch --logo arch --logo-width 20 --structure Title:OS:Kernel:Uptime:Shell:WM:Terminal:CPU:Memory
  echo
fi

# Quick tips (compact)
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}⌨${NC}  ${GREEN}Super+D${NC} launcher  ${GREEN}Super+Return${NC} terminal  ${GREEN}Super+Q${NC} close"
echo -e "${CYAN}🎨${NC} ${GREEN}Ctrl+Alt+1-8${NC} kitty themes  ${GREEN}Super+W${NC} wallpapers  ${GREEN}yy${NC} files"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
