#!/bin/bash

export_keybindings() {
    local filename="$1"
    echo "Exporting keybindings to $filename"

    local gsettings_folders=(
        "org.gnome.desktop.wm.keybindings"
        "org.gnome.settings-daemon.plugins.power"
        "org.gnome.settings-daemon.plugins.media-keys"
    )
    local custom_bindings
    custom_bindings=$(dconf list /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ | tr -d '/')

    {
        # Export main keybindings
        for folder in "${gsettings_folders[@]}"; do
            gsettings list-recursively "$folder" | while read -r line; do
                if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+(.+)$ ]]; then
                    local path="${BASH_REMATCH[1]}"
                    local name="${BASH_REMATCH[2]}"
                    local value="${BASH_REMATCH[3]}"
                    if [[ "$value" =~ ^\[ ]]; then
                        echo -e "$path\t$name\t$value"
                    fi
                else
                    echo "Could not parse line: $line" >&2
                    exit 1
                fi
            done
        done

        # Export custom keybindings
        for custom in $custom_bindings; do
            local folder="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/${custom}/"
            local name
            name=$(dconf read "${folder}name")
            local command
            command=$(dconf read "${folder}command")
            local binding
            binding=$(dconf read "${folder}binding")
            echo -e "custom\t$name\t$command\t$binding"
        done
    } > "$filename"

    echo "Keybindings exported successfully."
}

import_keybindings() {
    local filename="$1"
    echo "Importing keybindings from $filename"

    local custom_count=0
    local custom_list=""

    while IFS=$'\t' read -r type name_or_path command_or_name binding_or_value; do
        if [[ "$type" == "custom" ]]; then
            echo "Installing custom keybinding: $name_or_path"
            local folder="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom${custom_count}/"
            dconf write "${folder}name" "$name_or_path"
            dconf write "${folder}command" "$command_or_name"
            dconf write "${folder}binding" "$binding_or_value"
            custom_list+="'${folder}',"
            custom_count=$((custom_count + 1))
        else
            echo "Importing $name_or_path $command_or_name"
            gsettings set "$type" "$name_or_path" "$command_or_name"
        fi
    done < "$filename"

    if [[ $custom_count -gt 0 ]]; then
        custom_list="[${custom_list%,}]"
        echo "Importing list of custom keybindings."
        dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings "$custom_list"
    fi

    echo "Keybindings imported successfully."
}

keybindingsmanager() {

  show_help() {
      echo "Import and export keybindings"
      echo " -e, --export <filename>     Export keybindings to a file"
      echo " -i, --import <filename>     Import keybindings from a file"
      echo " -h, --help                  Show this help message"
  }

    local action=""
    local filename=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -e|--export)
                action="export"
                filename="$2"
                shift 2
                ;;
            -i|--import)
                action="import"
                filename="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown argument: $1" >&2
                show_help
                exit 1
                ;;
        esac
    done

    if [[ -z "$action" ]]; then
        echo "No action specified. Use -h for help." >&2
        exit 1
    fi

    if [[ -z "$filename" ]]; then
        echo "No filename specified. Use -h for help." >&2
        exit 1
    fi

    if [[ "$action" == "export" ]]; then
        export_keybindings "$filename"
    elif [[ "$action" == "import" ]]; then
        import_keybindings "$filename"
    else
        echo "Unknown action: $action" >&2
        exit 1
    fi
}
