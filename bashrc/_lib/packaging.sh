# shellcheck shell=bash
#!/bin/bash

package() {
  # Show help if no parameters are passed
  if [ $# -eq 0 ]; then
    package --help
    return 1
  fi

  local method="gzip"
  local level=""
  local output=""
  local folder=""
  local param=""

  # Prepare logging
  local log_file
  log_file="$(_dnb_init_log)"
  if [ -z "${log_file}" ]; then
    log_file=""
  fi

  while [ $# -gt 0 ]; do
    param="${1}"
    case "${param}" in
      --help)
        echo "${FUNCNAME[0]}: compress a folder into a tar archive"
        echo ""
        echo "Usage:"
        echo "  ${FUNCNAME[0]} [--output <file>] --method <gzip|xz|zstd> [--level <N>] <folder>"
        echo ""
        echo "Parameters:"
        echo "  --output    Name of the resulting archive file."
        echo "              If omitted, a timestamped name based on the folder is used."
        echo "  --method    Compression method. Default: gzip"
        echo "              gzip -> .tar.gz (defaults to level 9)"
        echo "              xz   -> .tar.xz"
        echo "              zstd -> .tar.zst"
        echo "  --level     Compression level. If omitted with gzip, level 9 is used."
        echo "  folder      Folder to compress."
        echo ""
        echo "Examples:"
        echo "  ${FUNCNAME[0]} myfolder/"
        echo "    -> gzip level 9, output myfolder_YYYYMMDD-HHMMSS.tar.gz"
        echo ""
        echo "  ${FUNCNAME[0]} --output backup.tar.xz --method xz myfolder/"
        echo "    -> xz with default compression level"
        return 0
        ;;

      --method)
        shift
        method="${1}"
        ;;

      --output)
        shift
        output="${1}"
        ;;

      --level)
        shift
        level="${1}"
        ;;

      *)
        if [ -z "${folder}" ]; then
          folder="${param}"
        else
          echo "Error: Unknown parameter '${param}'"
          package --help
          return 1
        fi
        ;;
    esac
    shift
  done

  # Validate folder
  if [ -z "${folder}" ]; then
    echo "Error: folder path is required"
    package --help
    return 1
  fi

  if [ ! -d "${folder}" ]; then
    echo "Error: folder '${folder}' does not exist"
    return 1
  fi

  # Decide base name and final output name
  local base_name
  if [ -z "${output}" ]; then
    local folder_base
    folder_base="$(basename "${folder}")"
    local ts
    ts="$(date '+%Y%m%d-%H%M%S')"
    base_name="${folder_base}_${ts}"
  else
    base_name="${output}"
    base_name="${base_name%.tar.gz}"
    base_name="${base_name%.tgz}"
    base_name="${base_name%.tar.xz}"
    base_name="${base_name%.tar.zst}"
    base_name="${base_name%.tar}"
  fi

  local base_tar="${base_name}.tar"
  local comp_cmd=()
  case "${method}" in
    gzip)
      # Default to level 9 if no level was given
      if [ -z "${level}" ]; then
        level="9"
      fi
      comp_cmd=(gzip "-${level}")
      output="${base_name}.tar.gz"
      ;;

    xz)
      if [ -n "${level}" ]; then
        comp_cmd=(xz "-${level}")
      else
        comp_cmd=(xz)
      fi
      output="${base_name}.tar.xz"
      ;;

    zstd)
      if [ -n "${level}" ]; then
        comp_cmd=(zstd "-${level}")
      else
        comp_cmd=(zstd)
      fi
      output="${base_name}.tar.zst"
      ;;

    *)
      echo "Error: Unsupported --method '${method}'"
      package --help
      return 1
      ;;
  esac

  if [ -n "${log_file}" ]; then
    printf '[%s] package: method=%s level=%s folder=%s output=%s base_tar=%s\n' \
      "$(date '+%Y-%m-%d %H:%M:%S')" "${method}" "${level}" "${folder}" "${output}" "${base_tar}" \
      >> "${log_file}"
  fi

  echo "Creating archive '${output}' using '${method}', level '${level:-default}'..."

  # Step 1: create uncompressed tar
  if ! tar -cvf "${base_tar}" "${folder}"; then
    local status_tar="${?}"
    echo "Archive creation failed during tar step (exit code ${status_tar})"
    if [ -n "${log_file}" ]; then
      printf '[%s] package: FAILED tar exit_code=%s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" "${status_tar}" >> "${log_file}"
    fi
    return "${status_tar}"
  fi

  # Step 2: compress using selected compressor
  if ! "${comp_cmd[@]}" "${base_tar}"; then
    local status_comp="${?}"
    echo "Archive creation failed during compression step (exit code ${status_comp})"
    if [ -n "${log_file}" ]; then
      printf '[%s] package: FAILED compression exit_code=%s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" "${status_comp}" >> "${log_file}"
    fi
    return "${status_comp}"
  fi

  # At this point, ${base_tar} has been replaced by ${output}
  echo "Archive created successfully: ${output}"
  if [ -n "${log_file}" ]; then
    printf '[%s] package: SUCCESS output=%s\n' \
      "$(date '+%Y-%m-%d %H:%M:%S')" "${output}" >> "${log_file}"
  fi

  return 0
}

unpackage() {
  # Show help if no parameters are passed
  if [ $# -eq 0 ]; then
    unpackage --help
    return 1
  fi

  local input=""
  local output_dir="."
  local param=""

  # Prepare logging
  local log_file
  log_file="$(_dnb_init_log)"
  if [ -z "${log_file}" ]; then
    log_file=""
  fi

  while [ $# -gt 0 ]; do
    param="${1}"
    case "${param}" in
      --help)
        echo "${FUNCNAME[0]}: extract a tar archive (gzip/xz/zstd)"
        echo ""
        echo "Usage:"
        echo "  ${FUNCNAME[0]} --input <archive> [--output-dir <dir>]"
        echo ""
        echo "Parameters:"
        echo "  --input       Archive file to extract (.tar.gz, .tgz, .tar.xz, .tar.zst, .tar)"
        echo "  --output-dir  Directory to extract into. Default: current directory"
        echo ""
        echo "Examples:"
        echo "  ${FUNCNAME[0]} --input myfolder_YYYYMMDD-HHMMSS.tar.gz"
        echo "  ${FUNCNAME[0]} --input backup.tar.xz --output-dir ./restore"
        return 0
        ;;

      --input)
        shift
        input="${1}"
        ;;

      --output-dir)
        shift
        output_dir="${1}"
        ;;

      *)
        # Allow archive as positional argument if not given via --input
        if [ -z "${input}" ]; then
          input="${param}"
        else
          echo "Error: Unknown parameter '${param}'"
          unpackage --help
          return 1
        fi
        ;;
    esac
    shift
  done

  if [ -z "${input}" ]; then
    echo "Error: --input (archive) is required"
    unpackage --help
    return 1
  fi

  if [ ! -f "${input}" ]; then
    echo "Error: archive file '${input}' does not exist"
    return 1
  fi

  if [ -z "${output_dir}" ]; then
    output_dir="."
  fi

  if ! mkdir -p "${output_dir}"; then
    echo "Error: could not create output directory '${output_dir}'"
    return 1
  fi

  local -a tar_args=()
  local compression=""

  case "${input}" in
    *.tar.gz|*.tgz)
      compression="gzip"
      tar_args+=("--gzip" "-xvf" "${input}")
      ;;
    *.tar.xz)
      compression="xz"
      tar_args+=("--xz" "-xvf" "${input}")
      ;;
    *.tar.zst)
      compression="zstd"
      tar_args+=("--zstd" "-xvf" "${input}")
      ;;
    *.tar)
      compression="none"
      tar_args+=("-xvf" "${input}")
      ;;
    *)
      echo "Error: unsupported archive type '${input}'"
      echo "Supported: .tar.gz, .tgz, .tar.xz, .tar.zst, .tar"
      return 1
      ;;
  esac

  tar_args+=("-C" "${output_dir}")

  if [ -n "${log_file}" ]; then
    printf '[%s] unpackage: input=%s compression=%s output_dir=%s\n' \
      "$(date '+%Y-%m-%d %H:%M:%S')" "${input}" "${compression}" "${output_dir}" \
      >> "${log_file}"
  fi

  echo "Extracting '${input}' to '${output_dir}' (compression: ${compression})..."

  if ! tar "${tar_args[@]}"; then
    local status_tar="${?}"
    echo "Extraction failed (exit code ${status_tar})"
    if [ -n "${log_file}" ]; then
      printf '[%s] unpackage: FAILED exit_code=%s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" "${status_tar}" >> "${log_file}"
    fi
    return "${status_tar}"
  fi

  echo "Archive extracted successfully into: ${output_dir}"
  if [ -n "${log_file}" ]; then
    printf '[%s] unpackage: SUCCESS input=%s output_dir=%s\n' \
      "$(date '+%Y-%m-%d %H:%M:%S')" "${input}" "${output_dir}" >> "${log_file}"
  fi

  return 0
}
