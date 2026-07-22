obsidian_open_in_code() {
  local project_path=""
  local file_path=""
  local reuse_window=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --project)
      project_path="${2:-}"
      shift 2
      ;;
    --file)
      file_path="${2:-}"
      shift 2
      ;;
    --reuse-window)
      reuse_window=true
      shift
      ;;
    --help)
      cat <<'EOF'
Usage:
  vscode-project --project PATH --file PATH [--reuse-window]

Options:
  --project PATH       Folder to open as the VS Code workspace.
  --file PATH          File to open. May be absolute or relative to the project.
  --reuse-window       Reuse the latest active VS Code window.
  --help               Show this help.
EOF
      return 0
      ;;
    *)
      printf 'Error: unknown option: %s\n' "$1" >&2
      return 2
      ;;
    esac
  done

  if [[ -z "$project_path" || -z "$file_path" ]]; then
    printf 'Error: --project and --file are required.\n' >&2
    return 2
  fi

  project_path="$(realpath "$project_path")" || return 1

  if [[ "$file_path" != /* ]]; then
    file_path="${project_path}/${file_path}"
  fi

  local -a window_option=(--new-window)

  if [[ "$reuse_window" == true ]]; then
    window_option=(--reuse-window)
  fi

  code "${window_option[@]}" "$project_path" "$file_path"
}
