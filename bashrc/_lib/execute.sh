execute() {
  local cmd="$1"
  local file="$2"

  if [[ -z "${cmd}" || -z "${file}" ]]; then
    echo "Usage: execute 'command with args' file.txt"
    return 1
  fi

  if [[ ! -f "${file}" ]]; then
    echo "File not found: ${file}"
    return 1
  fi

  while IFS= read -r line; do
    eval "${cmd} \"${line}\""
  done < "${file}"
}


# https://chatgpt.com/c/697ff66a-8198-839b-b758-713e30a68171
