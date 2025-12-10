# shellcheck shell=bash

dnb_client_structure() {
  local func_name="${FUNCNAME[0]}"

  __client_structure_help() {
    cat <<EOF
${func_name} - Create standard client folder structure

Usage:
  ${func_name} --client-name "Client Name" [--base-dir /path/to/base] [--verbose]
  ${func_name} --help

Options:
  --client-name   Name of the client folder to create (required).
  --base-dir      Base directory where the client folder will be created.
                  Defaults to the current working directory.
  --verbose       Enable detailed console output.
  --help          Show this help message and return.

Example:
  ${func_name} --client-name "ACME Corp"
  ${func_name} --client-name "ACME Corp" --base-dir /home/patrick/clients
EOF
  }

  if [[ "$#" -eq 0 ]]; then
    __client_structure_help
    return 1
  fi

  local CLIENT_NAME=""
  local BASE_DIR=""
  local LOCAL_VERBOSE="false"

  while [[ "$#" -gt 0 ]]; do
    case "${1}" in
      --client-name)
        if [[ "$#" -lt 2 ]]; then
          __dnb_error "--client-name requires a value"
          __client_structure_help
          return 1
        fi
        CLIENT_NAME="${2}"
        shift 2
        ;;
      --base-dir)
        if [[ "$#" -lt 2 ]]; then
          __dnb_error "--base-dir requires a value"
          __client_structure_help
          return 1
        fi
        BASE_DIR="${2}"
        shift 2
        ;;
      --verbose)
        LOCAL_VERBOSE="true"
        shift 1
        ;;
      --help)
        __client_structure_help
        return 0
        ;;
      *)
        __dnb_error "Unknown option: ${1}"
        __client_structure_help
        return 1
        ;;
    esac
  done

  if [[ -z "${CLIENT_NAME}" ]]; then
    __dnb_error "Missing required parameter: --client-name"
    __client_structure_help
    return 1
  fi

  if [[ -z "${BASE_DIR}" ]]; then
    BASE_DIR="$(pwd)"
  fi

  if [[ ! -d "${BASE_DIR}" ]]; then
    __dnb_error "Base directory does not exist: ${BASE_DIR}"
    return 1
  fi

  # set verbosity only for this call
  local OLD_VERBOSE="${DNB_VERBOSE:-false}"
  DNB_VERBOSE="${LOCAL_VERBOSE}"

  local CLIENT_ROOT="${BASE_DIR}/${CLIENT_NAME}"
  __dnb_create_directory "${CLIENT_ROOT}" || {
    DNB_VERBOSE="${OLD_VERBOSE}"
    return 1
  }

  __dnb_log "INFO" "Creating client structure in: ${CLIENT_ROOT}"

  # Top-level folders
  __dnb_create_directory "${CLIENT_ROOT}/Backup"       || { DNB_VERBOSE="${OLD_VERBOSE}"; return 1; }
  __dnb_create_directory "${CLIENT_ROOT}/Incoming"     || { DNB_VERBOSE="${OLD_VERBOSE}"; return 1; }
  __dnb_create_directory "${CLIENT_ROOT}/Assets"       || { DNB_VERBOSE="${OLD_VERBOSE}"; return 1; }
  __dnb_create_directory "${CLIENT_ROOT}/Final"        || { DNB_VERBOSE="${OLD_VERBOSE}"; return 1; }
  __dnb_create_directory "${CLIENT_ROOT}/Briefs"       || { DNB_VERBOSE="${OLD_VERBOSE}"; return 1; }
  __dnb_create_directory "${CLIENT_ROOT}/Offers"       || { DNB_VERBOSE="${OLD_VERBOSE}"; return 1; }
  __dnb_create_directory "${CLIENT_ROOT}/Designs"      || { DNB_VERBOSE="${OLD_VERBOSE}"; return 1; }
  __dnb_create_directory "${CLIENT_ROOT}/Research"     || { DNB_VERBOSE="${OLD_VERBOSE}"; return 1; }
  __dnb_create_directory "${CLIENT_ROOT}/Drafts"       || { DNB_VERBOSE="${OLD_VERBOSE}"; return 1; }
  __dnb_create_directory "${CLIENT_ROOT}/Paperwork"    || { DNB_VERBOSE="${OLD_VERBOSE}"; return 1; }
  __dnb_create_directory "${CLIENT_ROOT}/Projects"     || { DNB_VERBOSE="${OLD_VERBOSE}"; return 1; }

  # Assets subfolders
  __dnb_create_directory "${CLIENT_ROOT}/Assets/Identity"       || { DNB_VERBOSE="${OLD_VERBOSE}"; return 1; }
  __dnb_create_directory "${CLIENT_ROOT}/Assets/Stockimages"    || { DNB_VERBOSE="${OLD_VERBOSE}"; return 1; }
  __dnb_create_directory "${CLIENT_ROOT}/Assets/Photos"         || { DNB_VERBOSE="${OLD_VERBOSE}"; return 1; }
  __dnb_create_directory "${CLIENT_ROOT}/Assets/Videos"         || { DNB_VERBOSE="${OLD_VERBOSE}"; return 1; }
  __dnb_create_directory "${CLIENT_ROOT}/Assets/Documentation"  || { DNB_VERBOSE="${OLD_VERBOSE}"; return 1; }

  # Paperwork subfolders
  __dnb_create_directory "${CLIENT_ROOT}/Paperwork/Invoices"    || { DNB_VERBOSE="${OLD_VERBOSE}"; return 1; }
  __dnb_create_directory "${CLIENT_ROOT}/Paperwork/Contracts"   || { DNB_VERBOSE="${OLD_VERBOSE}"; return 1; }
  __dnb_create_directory "${CLIENT_ROOT}/Paperwork/Receipts"    || { DNB_VERBOSE="${OLD_VERBOSE}"; return 1; }
  __dnb_create_directory "${CLIENT_ROOT}/Paperwork/Technicals"  || { DNB_VERBOSE="${OLD_VERBOSE}"; return 1; }

  __dnb_log "INFO" "Client structure created for: ${CLIENT_ROOT}"
  __dnb_log "INFO" "Log file: ${DNB_SETUP_LOG_FILE}"

  DNB_VERBOSE="${OLD_VERBOSE}"
}

# ============================================================================
# create_project - create YYYY Project Name inside Projects
# ============================================================================

dnb_create_project() {
  local func_name="${FUNCNAME[0]}"

  __create_project_help() {
    cat <<EOF
${func_name} - Create a project folder inside a client's Projects directory

Usage:
  ${func_name} --client-dir /path/to/ClientName --project-name "Project Name" [--year YYYY] [--verbose]
  ${func_name} --help

Options:
  --client-dir    Path to the client root directory (must contain 'Projects' or it will be created).
  --project-name  Name of the project (will be prefixed with the year).
  --year          Year prefix for the project (defaults to current year).
  --verbose       Enable detailed console output.
  --help          Show this help message and return.

Resulting folder:
  /path/to/ClientName/Projects/YYYY Project Name

Example:
  ${func_name} --client-dir "/home/patrick/clients/ACME Corp" --project-name "Website Relaunch"
  ${func_name} --client-dir . --project-name "Logo Update" --year 2026
EOF
  }

  if [[ "$#" -eq 0 ]]; then
    __create_project_help
    return 1
  fi

  local CLIENT_DIR=""
  local PROJECT_NAME=""
  local YEAR=""
  local LOCAL_VERBOSE="false"

  while [[ "$#" -gt 0 ]]; do
    case "${1}" in
      --client-dir)
        if [[ "$#" -lt 2 ]]; then
          __dnb_error "--client-dir requires a value"
          __create_project_help
          return 1
        fi
        CLIENT_DIR="${2}"
        shift 2
        ;;
      --project-name)
        if [[ "$#" -lt 2 ]]; then
          __dnb_error "--project-name requires a value"
          __create_project_help
          return 1
        fi
        PROJECT_NAME="${2}"
        shift 2
        ;;
      --year)
        if [[ "$#" -lt 2 ]]; then
          __dnb_error "--year requires a value"
          __create_project_help
          return 1
        fi
        YEAR="${2}"
        shift 2
        ;;
      --verbose)
        LOCAL_VERBOSE="true"
        shift 1
        ;;
      --help)
        __create_project_help
        return 0
        ;;
      *)
        __dnb_error "Unknown option: ${1}"
        __create_project_help
        return 1
        ;;
    esac
  done

  if [[ -z "${CLIENT_DIR}" ]]; then
    __dnb_error "Missing required parameter: --client-dir"
    __create_project_help
    return 1
  fi

  if [[ -z "${PROJECT_NAME}" ]]; then
    __dnb_error "Missing required parameter: --project-name"
    __create_project_help
    return 1
  fi

  if [[ ! -d "${CLIENT_DIR}" ]]; then
    __dnb_error "Client directory does not exist: ${CLIENT_DIR}"
    return 1
  fi

  if [[ -z "${YEAR}" ]]; then
    YEAR="$(date +%Y)"
  fi

  local OLD_VERBOSE="${DNB_VERBOSE:-false}"
  DNB_VERBOSE="${LOCAL_VERBOSE}"

  local PROJECTS_DIR="${CLIENT_DIR%/}/Projects"
  __dnb_create_directory "${PROJECTS_DIR}" || {
    DNB_VERBOSE="${OLD_VERBOSE}"
    return 1
  }

  local PROJECT_DIR="${PROJECTS_DIR}/${YEAR} ${PROJECT_NAME}"
  __dnb_create_directory "${PROJECT_DIR}" || {
    DNB_VERBOSE="${OLD_VERBOSE}"
    return 1
  }

  __dnb_log "INFO" "Project directory created: ${PROJECT_DIR}"
  __dnb_log "INFO" "Log file: ${DNB_SETUP_LOG_FILE}"

  DNB_VERBOSE="${OLD_VERBOSE}"
}
