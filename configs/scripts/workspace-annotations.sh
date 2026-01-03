#!/usr/bin/env bash
# Workspace annotation manager for Hyprland + Waybar

ANNOTATIONS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/workspace-annotations.json"
LOCK_FILE="/tmp/workspace-annotations.lock"

# Ensure directory and file exist
mkdir -p "$(dirname "$ANNOTATIONS_FILE")"
[ -f "$ANNOTATIONS_FILE" ] || echo '{}' > "$ANNOTATIONS_FILE"

# Read current annotations
read_annotations() {
    cat "$ANNOTATIONS_FILE" 2>/dev/null || echo '{}'
}

# Write annotations atomically
write_annotations() {
    local data="$1"
    (
        flock -x 200
        echo "$data" > "$ANNOTATIONS_FILE"
    ) 200>"$LOCK_FILE"
}

# Get annotation for a workspace
get_annotation() {
    local ws="$1"
    jq -r --arg ws "$ws" '.[$ws] // ""' "$ANNOTATIONS_FILE" 2>/dev/null
}

# Set annotation for a workspace
set_annotation() {
    local ws="$1"
    local annotation="$2"
    local current
    current=$(read_annotations)

    if [ -z "$annotation" ]; then
        # Remove annotation if empty
        local new_data
        new_data=$(echo "$current" | jq --arg ws "$ws" 'del(.[$ws])')
        write_annotations "$new_data"
    else
        # Set annotation
        local new_data
        new_data=$(echo "$current" | jq --arg ws "$ws" --arg ann "$annotation" '.[$ws] = $ann')
        write_annotations "$new_data"
    fi
}

# Show edit dialog using wofi/rofi
edit_annotation() {
    local ws="$1"
    local current_annotation
    current_annotation=$(get_annotation "$ws")

    # Use wofi for input
    local new_annotation
    new_annotation=$(echo "$current_annotation" | wofi --dmenu \
        --prompt "Workspace $ws annotation:" \
        --width 400 \
        --height 60 \
        --lines 1 \
        2>/dev/null)

    # If wofi returns something (even empty = cleared), save it
    if [ $? -eq 0 ]; then
        set_annotation "$ws" "$new_annotation"
        # Signal waybar to update
        pkill -RTMIN+8 waybar
    fi
}

# Generate waybar module output for a specific workspace
waybar_workspace_tooltip() {
    local ws="$1"
    local annotation
    annotation=$(get_annotation "$ws")

    if [ -n "$annotation" ]; then
        echo "$annotation"
    else
        echo "Workspace $ws"
    fi
}

# Generate full workspace overview for dropdown menu
show_overview() {
    local annotations
    annotations=$(read_annotations)

    # Get all workspaces with windows
    local workspaces
    workspaces=$(hyprctl workspaces -j | jq -r '.[].id' | sort -n)

    local overview=""
    for ws in $workspaces; do
        local annotation
        annotation=$(echo "$annotations" | jq -r --arg ws "$ws" '.[$ws] // ""')

        local windows
        windows=$(hyprctl clients -j | jq --arg ws "$ws" '[.[] | select(.workspace.id == ($ws | tonumber))] | length')

        local apps
        apps=$(hyprctl clients -j | jq -r --arg ws "$ws" '[.[] | select(.workspace.id == ($ws | tonumber)) | .class] | unique | join(", ")')

        if [ -n "$annotation" ]; then
            overview+="$ws: $annotation [$apps]\n"
        else
            overview+="$ws: [$apps]\n"
        fi
    done

    # Show with wofi and allow selection
    local selected
    selected=$(echo -e "$overview" | wofi --dmenu \
        --prompt "Workspaces (double-click number to annotate)" \
        --width 500 \
        --height 400 \
        2>/dev/null)

    if [ -n "$selected" ]; then
        local ws_num
        ws_num=$(echo "$selected" | cut -d: -f1 | tr -d ' ')
        hyprctl dispatch workspace "$ws_num"
    fi
}

# Generate waybar JSON output for all workspaces
waybar_output() {
    local annotations
    annotations=$(read_annotations)
    local current_ws
    current_ws=$(hyprctl activeworkspace -j | jq -r '.id')

    # Get all workspaces
    local workspaces
    workspaces=$(hyprctl workspaces -j | jq -r '.[].id' | sort -n)

    local tooltip="━━━ Workspace Overview ━━━\n"
    for ws in $workspaces; do
        local annotation
        annotation=$(echo "$annotations" | jq -r --arg ws "$ws" '.[$ws] // ""')

        local apps
        apps=$(hyprctl clients -j | jq -r --arg ws "$ws" '[.[] | select(.workspace.id == ($ws | tonumber)) | .class] | unique | join(", ")' 2>/dev/null)

        local marker=""
        [ "$ws" = "$current_ws" ] && marker="→ "

        if [ -n "$annotation" ]; then
            tooltip+="${marker}${ws}: ${annotation}"
        else
            tooltip+="${marker}${ws}"
        fi
        [ -n "$apps" ] && tooltip+=" [$apps]"
        tooltip+="\n"
    done
    tooltip+="━━━━━━━━━━━━━━━━━━━━━━━━━━\nClick: Overview  |  Scroll: Switch"

    printf '{"text": "📋", "tooltip": "%s"}\n' "$tooltip"
}

# Main command handler
case "$1" in
    get)
        get_annotation "$2"
        ;;
    set)
        set_annotation "$2" "$3"
        ;;
    edit)
        edit_annotation "$2"
        ;;
    overview)
        show_overview
        ;;
    waybar)
        waybar_output
        ;;
    tooltip)
        waybar_workspace_tooltip "$2"
        ;;
    *)
        echo "Usage: $0 {get|set|edit|overview|waybar|tooltip} [workspace] [annotation]"
        echo ""
        echo "Commands:"
        echo "  get <ws>              Get annotation for workspace"
        echo "  set <ws> <text>       Set annotation for workspace"
        echo "  edit <ws>             Open editor for workspace annotation"
        echo "  overview              Show workspace overview menu"
        echo "  waybar                Output JSON for waybar module"
        echo "  tooltip <ws>          Get tooltip text for workspace"
        exit 1
        ;;
esac
