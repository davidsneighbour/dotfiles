# shellcheck shell=bash

# __dnb_archive_require_method
__dnb_archive_require_method() {
  case "${1}" in
  gzip) dnb_check_requirements tar gzip ;;
  xz) dnb_check_requirements tar xz ;;
  zstd) dnb_check_requirements tar zstd ;;
  none) dnb_check_requirements tar ;;
  *) return 1 ;;
  esac
}

# dnb_archive_create
#
# Create a tar archive and optionally compress it.
#
# Parameters:
#   folder            Folder to archive.
#
# Options:
#   --output <file>   Output archive base name or final archive name.
#   --method <name>   gzip, xz, zstd. Default: gzip.
#   --level <N>       Compressor level when supported.
#   --help            Show help output.
#
# Examples:
#   dnb_archive_create ./data
#   dnb_archive_create --method xz --output backup ./data
#
# Requirements:
#   - bash
#   - tar
#   - gzip/xz/zstd depending on method

dnb_archive_create() {
  local method='gzip'
  local level=''
  local output=''
  local folder=''
  local param=''
  local base_name=''
  local base_tar=''
  local archive_path=''
  local compressor_status=0
  local tar_status=0
  local -a comp_cmd=()

  if [[ "$#" -eq 0 ]]; then
    dnb_archive_create --help
    return 1
  fi

  while [[ "$#" -gt 0 ]]; do
    param="${1}"
    case "${param}" in
    --help)
      cat <<EOF2
${FUNCNAME[0]} - create a tar archive

Usage:
  ${FUNCNAME[0]} [--output <file>] [--method <gzip|xz|zstd>] [--level <N>] <folder>
EOF2
      return 0
      ;;
    --method)
      shift
      method="${1:-}"
      ;;
    --output)
      shift
      output="${1:-}"
      ;;
    --level)
      shift
      level="${1:-}"
      ;;
    *)
      if [[ -z "${folder}" ]]; then
        folder="${param}"
      else
        printf 'Unknown parameter: %s\n' "${param}" >&2
        return 1
      fi
      ;;
    esac
    shift
  done

  [[ -n "${folder}" && -d "${folder}" ]] || {
    dnb_error "Folder does not exist: ${folder}"
    return 1
  }

  __dnb_archive_require_method "${method}" || {
    dnb_error "Unsupported or unavailable archive method: ${method}"
    return 1
  }

  if [[ -z "${output}" ]]; then
    base_name="$(basename "${folder}")_$(date '+%Y%m%d-%H%M%S')"
  else
    base_name="${output}"
    base_name="${base_name%.tar.gz}"
    base_name="${base_name%.tgz}"
    base_name="${base_name%.tar.xz}"
    base_name="${base_name%.tar.zst}"
    base_name="${base_name%.tar}"
  fi

  base_tar="${base_name}.tar"

  case "${method}" in
  gzip)
    [[ -n "${level}" ]] || level='9'
    comp_cmd=(gzip "-${level}")
    archive_path="${base_name}.tar.gz"
    ;;
  xz)
    if [[ -n "${level}" ]]; then
      comp_cmd=(xz "-${level}")
    else
      comp_cmd=(xz)
    fi
    archive_path="${base_name}.tar.xz"
    ;;
  zstd)
    if [[ -n "${level}" ]]; then
      comp_cmd=(zstd "-${level}")
    else
      comp_cmd=(zstd)
    fi
    archive_path="${base_name}.tar.zst"
    ;;
  esac

  dnb_log info "Creating archive ${archive_path} from ${folder}"
  tar -cvf "${base_tar}" "${folder}"
  tar_status=$?
  if [[ "${tar_status}" -ne 0 ]]; then
    dnb_error "Tar step failed with exit code ${tar_status}"
    return "${tar_status}"
  fi

  "${comp_cmd[@]}" "${base_tar}"
  compressor_status=$?
  if [[ "${compressor_status}" -ne 0 ]]; then
    dnb_error "Compression step failed with exit code ${compressor_status}"
    return "${compressor_status}"
  fi

  dnb_log success "Archive created successfully: ${archive_path}"
  printf '%s\n' "${archive_path}"
}

# dnb_archive_extract
#
# Extract a supported archive into a target directory.
#
# Options:
#   --input <file>         Archive file.
#   --output-dir <dir>     Destination directory. Default: current directory.
#   --help                 Show help output.
#
# Examples:
#   dnb_archive_extract --input backup.tar.gz
#   dnb_archive_extract --input backup.tar.xz --output-dir ./restore
#
# Requirements:
#   - bash
#   - tar

dnb_archive_extract() {
  local input=''
  local output_dir='.'
  local compression='none'
  local param=''
  local status=0
  local -a tar_args=()

  if [[ "$#" -eq 0 ]]; then
    dnb_archive_extract --help
    return 1
  fi

  while [[ "$#" -gt 0 ]]; do
    param="${1}"
    case "${param}" in
    --help)
      cat <<EOF2
${FUNCNAME[0]} - extract a tar archive

Usage:
  ${FUNCNAME[0]} --input <archive> [--output-dir <dir>]
EOF2
      return 0
      ;;
    --input)
      shift
      input="${1:-}"
      ;;
    --output-dir)
      shift
      output_dir="${1:-}"
      ;;
    *)
      if [[ -z "${input}" ]]; then
        input="${param}"
      else
        printf 'Unknown parameter: %s\n' "${param}" >&2
        return 1
      fi
      ;;
    esac
    shift
  done

  [[ -n "${input}" && -f "${input}" ]] || {
    dnb_error "Archive file does not exist: ${input}"
    return 1
  }

  dnb_create_directory "${output_dir}" || return 1

  case "${input}" in
  *.tar.gz | *.tgz)
    compression='gzip'
    tar_args=(--gzip -xvf "${input}")
    ;;
  *.tar.xz)
    compression='xz'
    tar_args=(--xz -xvf "${input}")
    ;;
  *.tar.zst)
    compression='zstd'
    tar_args=(--zstd -xvf "${input}")
    ;;
  *.tar)
    compression='none'
    tar_args=(-xvf "${input}")
    ;;
  *)
    dnb_error "Unsupported archive type: ${input}"
    return 1
    ;;
  esac

  tar_args+=(-C "${output_dir}")
  dnb_log info "Extracting ${input} to ${output_dir} (${compression})"
  tar "${tar_args[@]}"
  status=$?
  if [[ "${status}" -ne 0 ]]; then
    dnb_error "Extraction failed with exit code ${status}"
    return "${status}"
  fi

  dnb_log success "Archive extracted successfully into ${output_dir}"
}
