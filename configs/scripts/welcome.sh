#!/bin/bash

# Welcome message for interactive shells (shown once per session).
[[ $- != *i* ]] && return
[[ -n ${WELCOME_SHOWN:-} ]] && return
export WELCOME_SHOWN=1

YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
GREEN=$'\033[0;32m'
NC=$'\033[0m'

if command -v fastfetch >/dev/null 2>&1; then
  fastfetch --logo arch --logo-width 20 --structure Title:OS:Kernel:Uptime:Shell:WM:Terminal:CPU:Memory || true
  echo
fi

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}⌨${NC}  ${GREEN}Super+D${NC} launcher  ${GREEN}Super+Return${NC} terminal  ${GREEN}Super+Q${NC} close"
echo -e "${CYAN}🎨${NC} ${GREEN}Ctrl+Alt+1-8${NC} kitty themes  ${GREEN}Super+W${NC} wallpapers  ${GREEN}yy${NC} files"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
