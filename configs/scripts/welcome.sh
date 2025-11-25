#!/bin/bash

# Welcome script for Arch Linux Hyprland setup
# Neo-brutalist themed welcome message

# Colors
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
PURPLE=$'\033[0;35m'
CYAN=$'\033[0;36m'
NC=$'\033[0m' # No Color

# Only show welcome message once per session
if [[ $- == *i* && -z ${WELCOME_SHOWN:-} ]]; then
  export WELCOME_SHOWN=1

  banner() {
    printf '\n'
    printf '%b\n' "${YELLOW}╔══════════════════════════════════════════════╗${NC}"
    printf '%b\n' "${YELLOW}║${NC}  ${PURPLE}▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄${NC}  ${YELLOW}║${NC}"
    printf '%b\n' "${YELLOW}║${NC}  ${PURPLE}█${NC} ${CYAN}WELCOME TO HYPRLAND${NC} ${PURPLE}█${NC}  ${YELLOW}║${NC}"
    printf '%b\n' "${YELLOW}║${NC}  ${PURPLE}█${NC} ${GREEN}Neo-Brutalist Setup${NC} ${PURPLE}█${NC}  ${YELLOW}║${NC}"
    printf '%b\n' "${YELLOW}║${NC}  ${PURPLE}▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀${NC}  ${YELLOW}║${NC}"
    printf '%b\n' "${YELLOW}╚══════════════════════════════════════════════╝${NC}"
  }

  banner
  echo
  echo -e "${BLUE}🚀 Quick Start:${NC}"
  echo -e "   • ${GREEN}Super+Return${NC} - Open terminal"
  echo -e "   • ${GREEN}Super+D${NC} - Application launcher"
  echo -e "   • ${GREEN}Super+E${NC} - File manager"
  echo -e "   • ${GREEN}Super+W${NC} - Cycle wallpapers"
  echo
  echo -e "${PURPLE}🎨 Theme Switching:${NC}"
  echo -e "   • ${GREEN}Ctrl+Alt+1-8${NC} - Kitty color themes"
  echo -e "   • ${GREEN}Super+T${NC} - VS Code theme cycling"
  echo
  echo -e "${CYAN}📁 File Manager:${NC} Type ${GREEN}yy${NC} to open Yazi with cd-on-exit"
  echo -e "${CYAN}📋 Clipboard:${NC} ${GREEN}Super+C${NC} for clipboard history"
  echo

  # Show system info
  if command -v fastfetch >/dev/null 2>&1; then
    fastfetch --config none --logo arch
  fi

  echo
fi
