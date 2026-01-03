#!/usr/bin/env bash
# Workspace rename manager for Hyprland
# Uses native hyprctl renameworkspace with persistence

NAMES_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/workspace-names.json"
LOCK_FILE="/tmp/workspace-names.lock"

# Ensure directory and file exist
mkdir -p "$(dirname "$NAMES_FILE")"
[ -f "$NAMES_FILE" ] || echo '{}' > "$NAMES_FILE"

# Read saved names
read_names() {
    cat "$NAMES_FILE" 2>/dev/null || echo '{}'
}

# Write names atomically
write_names() {
    local data="$1"
    (
        flock -x 200
        echo "$data" > "$NAMES_FILE"
    ) 200>"$LOCK_FILE"
}

# Get saved name for a workspace
get_name() {
    local ws="$1"
    jq -r --arg ws "$ws" '.[$ws] // ""' "$NAMES_FILE" 2>/dev/null
}

# Rename workspace (both in Hyprland and save to file)
rename_workspace() {
    local ws="$1"
    local name="$2"
    local current
    current=$(read_names)

    if [ -z "$name" ]; then
        # Reset to number if empty
        hyprctl dispatch renameworkspace "$ws" "$ws"
        local new_data
        new_data=$(echo "$current" | jq --arg ws "$ws" 'del(.[$ws])')
        write_names "$new_data"
    else
        # Set custom name
        hyprctl dispatch renameworkspace "$ws" "$name"
        local new_data
        new_data=$(echo "$current" | jq --arg ws "$ws" --arg name "$name" '.[$ws] = $name')
        write_names "$new_data"
    fi
}

# Show rename dialog
edit_name() {
    local ws="$1"
    local current_name
    current_name=$(get_name "$ws")

    # If no saved name, show current workspace name from Hyprland
    if [ -z "$current_name" ]; then
        current_name=$(hyprctl workspaces -j | jq -r --argjson ws "$ws" '.[] | select(.id == $ws) | .name // ""')
        # If it's just the number, show empty
        [ "$current_name" = "$ws" ] && current_name=""
    fi

    # Use wofi for input
    local new_name
    new_name=$(echo "$current_name" | wofi --dmenu \
        --prompt "Rename workspace $ws:" \
        --width 400 \
        --height 60 \
        --lines 1 \
        2>/dev/null)

    # If wofi exited successfully, apply the rename
    if [ $? -eq 0 ]; then
        rename_workspace "$ws" "$new_name"
    fi
}

# Restore all saved workspace names (run on Hyprland startup)
restore_names() {
    local names
    names=$(read_names)

    # Iterate through all saved names
    echo "$names" | jq -r 'to_entries[] | "\(.key) \(.value)"' | while read -r ws name; do
        if [ -n "$name" ]; then
            hyprctl dispatch renameworkspace "$ws" "$name"
        fi
    done
}

# Show workspace overview with names
show_overview() {
    local workspaces
    workspaces=$(hyprctl workspaces -j | jq -r 'sort_by(.id) | .[] | "\(.id)|\(.name)"')

    local current_ws
    current_ws=$(hyprctl activeworkspace -j | jq -r '.id')

    local overview=""
    while IFS='|' read -r ws_id ws_name; do
        local apps
        apps=$(hyprctl clients -j | jq -r --argjson ws "$ws_id" '[.[] | select(.workspace.id == $ws) | .class] | unique | join(", ")' 2>/dev/null)

        local marker=""
        [ "$ws_id" = "$current_ws" ] && marker="→ "

        if [ "$ws_name" != "$ws_id" ] && [ -n "$ws_name" ]; then
            overview+="${marker}${ws_id}: ${ws_name}"
        else
            overview+="${marker}${ws_id}"
        fi
        [ -n "$apps" ] && overview+=" [$apps]"
        overview+="\n"
    done <<< "$workspaces"

    # Show with wofi
    local selected
    selected=$(echo -e "$overview" | wofi --dmenu \
        --prompt "Workspaces (select to switch, Super+A to rename)" \
        --width 500 \
        --height 400 \
        2>/dev/null)

    if [ -n "$selected" ]; then
        local ws_num
        ws_num=$(echo "$selected" | sed 's/^→ //' | cut -d: -f1 | cut -d' ' -f1 | tr -d ' ')
        hyprctl dispatch workspace "$ws_num"
    fi
}

# Generate waybar JSON output
waybar_output() {
    local current_ws
    current_ws=$(hyprctl activeworkspace -j | jq -r '.id')

    local workspaces
    workspaces=$(hyprctl workspaces -j | jq -r 'sort_by(.id) | .[] | "\(.id)|\(.name)"')

    local tooltip="━━━ Workspaces ━━━\n"
    while IFS='|' read -r ws_id ws_name; do
        local apps
        apps=$(hyprctl clients -j | jq -r --argjson ws "$ws_id" '[.[] | select(.workspace.id == $ws) | .class] | unique | join(", ")' 2>/dev/null)

        local marker=""
        [ "$ws_id" = "$current_ws" ] && marker="→ "

        if [ "$ws_name" != "$ws_id" ] && [ -n "$ws_name" ]; then
            tooltip+="${marker}${ws_id}: ${ws_name}"
        else
            tooltip+="${marker}${ws_id}"
        fi
        [ -n "$apps" ] && tooltip+=" [$apps]"
        tooltip+="\n"
    done <<< "$workspaces"
    tooltip+="━━━━━━━━━━━━━━━━━━"

    printf '{"text": "📋", "tooltip": "%s"}\n' "$tooltip"
}

# Main command handler
case "$1" in
    rename)
        rename_workspace "$2" "$3"
        ;;
    edit)
        edit_name "$2"
        ;;
    restore)
        restore_names
        ;;
    overview)
        show_overview
        ;;
    waybar)
        waybar_output
        ;;
    get)
        get_name "$2"
        ;;
    *)
        echo "Usage: $0 {rename|edit|restore|overview|waybar|get} [workspace] [name]"
        echo ""
        echo "Commands:"
        echo "  rename <ws> <name>    Rename workspace (empty name resets to number)"
        echo "  edit <ws>             Open rename dialog for workspace"
        echo "  restore               Restore all saved workspace names"
        echo "  overview              Show workspace overview menu"
        echo "  waybar                Output JSON for waybar module"
        echo "  get <ws>              Get saved name for workspace"
        exit 1
        ;;
esac
