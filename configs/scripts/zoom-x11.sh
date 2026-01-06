#!/bin/bash

# Launch Zoom via XWayland for stable pop-up menus on Wayland compositors.
set -e

QT_QPA_PLATFORM=xcb exec /usr/bin/zoom "$@"
