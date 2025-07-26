#!/bin/bash

# AUB Tools Installation Script
# This script automates the installation of AUB Tools,
# creating necessary directories, downloading dependencies,
# and setting up the main executable.

# --- Configuration ---
INSTALL_DIR="${HOME}/.aub-tools"
BIN_DIR="${INSTALL_DIR}/bin"
CORE_DIR="${INSTALL_DIR}/core"
HELPERS_DIR="${INSTALL_DIR}/helpers"
LANG_DIR="${INSTALL_DIR}/lang"
TEMP_DIR="/tmp/aub-tools" # Temporary directory for logs and reports
JQ_VERSION="1.7.1"
JQ_URL="https://github.com/stedolan/jq/releases/download/jq-${JQ_VERSION}/jq-linux64" # For Linux 64-bit

# --- Colors for pretty output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Logging function for installation script ---
install_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${BLUE}[INSTALLER]${NC} [${timestamp}] ${level}: ${message}"
}

# --- Proxy handling for download ---
setup_proxy() {
    install_log "INFO" "Checking for proxy settings..."
    if [ -n "$http_proxy" ]; then
        PROXY_SETTINGS="--proxy $http_proxy"
        install_log "INFO" "Using HTTP proxy: $http_proxy"
    elif [ -n "$HTTP_PROXY" ]; then
        PROXY_SETTINGS="--proxy $HTTP_PROXY"
        install_log "INFO" "Using HTTP proxy: $HTTP_PROXY"
    else
        PROXY_SETTINGS=""
        install_log "INFO" "No HTTP proxy found."
    fi

    if [ -n "$https_proxy" ]; then
        PROXY_SETTINGS="$PROXY_SETTINGS --proxy $https_proxy"
        install_log "INFO" "Using HTTPS proxy: $https_proxy"
    elif [ -n "$HTTPS_PROXY" ]; then
        PROXY_SETTINGS="$PROXY_SETTINGS --proxy $HTTPS_PROXY"
        install_log "INFO" "Using HTTPS proxy: $HTTPS_PROXY"
    else
        install_log "INFO" "No HTTPS proxy found."
    fi

    # Unset NO_PROXY for internal downloads if it contains GitHub
    if [[ "$no_proxy" =~ "github.com" ]] || [[ "$NO_PROXY" =~ "github.com" ]]; then
        install_log "WARN" "github.com found in NO_PROXY. Temporarily unsetting NO_PROXY for dependency download."
        # Store original NO_PROXY values if they exist
        ORIGINAL_NO_PROXY_LOWER="$no_proxy"
        ORIGINAL_NO_PROXY_UPPER="$NO_PROXY"
        unset no_proxy
        unset NO_PROXY
    fi
}

# --- Restore original proxy settings ---
restore_proxy() {
    if [ -n "$ORIGINAL_NO_PROXY_LOWER" ]; then
        export no_proxy="$ORIGINAL_NO_PROXY_LOWER"
        install_log "INFO" "Restored no_proxy to original value."
    fi
    if [ -n "$ORIGINAL_NO_PROXY_UPPER" ]; then
        export NO_PROXY="$ORIGINAL_NO_PROXY_UPPER"
        install_log "INFO" "Restored NO_PROXY to original value."
    fi
}

# --- Create necessary directories ---
create_directories() {
    install_log "INFO" "Creating AUB Tools directories..."
    mkdir -p "${BIN_DIR}" || { install_log "ERROR" "Failed to create ${BIN_DIR}"; exit 1; }
    mkdir -p "${CORE_DIR}" || { install_log "ERROR" "Failed to create ${CORE_DIR}"; exit 1; }
    mkdir -p "${HELPERS_DIR}" || { install_log "ERROR" "Failed to create ${HELPERS_DIR}"; exit 1; }
    mkdir -p "${LANG_DIR}/en_US" || { install_log "ERROR" "Failed to create ${LANG_DIR}/en_US"; exit 1; }
    mkdir -p "${LANG_DIR}/fr_FR" || { install_log "ERROR" "Failed to create ${LANG_DIR}/fr_FR"; exit 1; }
    mkdir -p "${TEMP_DIR}" || { install_log "ERROR" "Failed to create ${TEMP_DIR}"; exit 1; }
    install_log "SUCCESS" "All directories created."
}

# --- Download jq ---
download_jq() {
    install_log "INFO" "Downloading jq ${JQ_VERSION}..."
    if command -v curl &> /dev/null; then
        if curl ${PROXY_SETTINGS} -sSL "${JQ_URL}" -o "${BIN_DIR}/jq"; then
            chmod +x "${BIN_DIR}/jq"
            install_log "SUCCESS" "jq downloaded and made executable."
        else
            install_log "ERROR" "Failed to download jq. Please ensure curl is installed and accessible."
            exit 1
        fi
    else
        install_log "ERROR" "curl is not installed. Please install curl to proceed with jq download."
        exit 1
    fi
}

# --- Create core files ---
create_core_files() {
    install_log "INFO" "Creating core script files..."

    # core/composer.sh
    cat << 'EOF' > "${CORE_DIR}/composer.sh"
#!/bin/bash

# AUB Tools - core/composer.sh
# This script contains functions for Composer management.

# Load helpers
source "${HELPERS_DIR}/log.sh"
source "${HELPERS_DIR}/menu.sh"
source "${HELPERS_DIR}/prompt.sh"
source "${HELPERS_DIR}/i18n.sh"
source "${HELPERS_DIR}/utils.sh"
source "${HELPERS_DIR}/config.sh"
source "${CORE_DIR}/project.sh" # Needed for project path detection

# Function to run composer commands
# Arguments:
#   $1 - Composer command (e.g., 'install', 'update')
#   $@ - Additional arguments for composer
composer_run() {
    local cmd="$1"
    shift
    local args="$@"

    if ! is_current_project_drupal; then
        log_error "$(i18n_message "ERROR_NOT_DRUPAL_PROJECT")"
        return 1
    fi

    local project_root_path=$(get_current_project_path)
    if [ -z "$project_root_path" ]; then
        log_error "$(i18n_message "ERROR_PROJECT_PATH_UNKNOWN")"
        return 1
    fi

    log_info "$(i18n_message "COMPOSER_RUNNING_COMMAND" "${cmd}")"
    (cd "${project_root_path}" && composer "${cmd}" ${args})
    local status=$?
    if [ $status -eq 0 ]; then
        log_success "$(i18n_message "COMPOSER_COMMAND_SUCCESS" "${cmd}")"
    else
        log_error "$(i18n_message "COMPOSER_COMMAND_FAILED" "${cmd}")"
    fi
    return $status
}

# Function to display Composer menu
composer_menu() {
    while true; do
        clear
        print_header "$(i18n_message "COMPOSER_MENU_TITLE")"
        log_info "$(i18n_message "CURRENT_PROJECT_PATH" "${CURRENT_PROJECT_PATH}")"

        local options=(
            "$(i18n_message "COMPOSER_INSTALL")"
            "$(i18n_message "COMPOSER_UPDATE")"
            "$(i18n_message "COMPOSER_REQUIRE")"
            "$(i18n_message "COMPOSER_REMOVE")"
            "$(i18n_message "BACK")"
        )
        local choice=$(display_menu "${options[@]}")

        case "${choice}" in
            "$(i18n_message "COMPOSER_INSTALL")")
                log_info "$(i18n_message "COMPOSER_RUNNING_INSTALL")"
                composer_run install
                prompt_continue
                ;;
            "$(i18n_message "COMPOSER_UPDATE")")
                log_info "$(i18n_message "COMPOSER_RUNNING_UPDATE")"
                composer_run update
                prompt_continue
                ;;
            "$(i18n_message "COMPOSER_REQUIRE")")
                local package_name=$(prompt_input "$(i18n_message "COMPOSER_ENTER_PACKAGE_TO_REQUIRE")" "")
                if [ -n "$package_name" ]; then
                    composer_run require "$package_name"
                else
                    log_warn "$(i18n_message "COMPOSER_PACKAGE_EMPTY")"
                fi
                prompt_continue
                ;;
            "$(i18n_message "COMPOSER_REMOVE")")
                local package_name=$(prompt_input "$(i18n_message "COMPOSER_ENTER_PACKAGE_TO_REMOVE")" "")
                if [ -n "$package_name" ]; then
                    composer_run remove "$package_name"
                else
                    log_warn "$(i18n_message "COMPOSER_PACKAGE_EMPTY")"
                fi
                prompt_continue
                ;;
            "$(i18n_message "BACK")")
                break
                ;;
            *)
                log_error "$(i18n_message "ERROR_INVALID_CHOICE")"
                prompt_continue
                ;;
        esac
    done
}
EOF

    # core/database.sh
    cat << 'EOF' > "${CORE_DIR}/database.sh"
#!/bin/bash

# AUB Tools - core/database.sh
# This script contains functions for Drupal database management.

# Load helpers
source "${HELPERS_DIR}/log.sh"
source "${HELPERS_DIR}/menu.sh"
source "${HELPERS_DIR}/prompt.sh"
source "${HELPERS_DIR}/i18n.sh"
source "${HELPERS_DIR}/utils.sh"
source "${HELPERS_DIR}/config.sh"
source "${CORE_DIR}/drush.sh" # Needed for drush_run_command

# Function to restore a database from a dump file
# Automatically handles various archive formats (.gz, .zip, .tar, .dmp)
# Looks for dump files in the project's 'data/' directory by default.
# Arguments:
#   $1 - Optional: Path to the dump file. If not provided, user will be prompted.
#   $2 - Optional: Drush alias or URI to restore to. If not provided, user will be prompted or current selection used.
drush_db_restore() {
    local dump_file="$1"
    local drush_target="$2"
    local data_dir

    if ! is_current_project_drupal; then
        log_error "$(i18n_message "ERROR_NOT_DRUPAL_PROJECT")"
        return 1
    fi

    local project_root_path=$(get_current_project_path)
    if [ -z "$project_root_path" ]; then
        log_error "$(i18n_message "ERROR_PROJECT_PATH_UNKNOWN")"
        return 1
    fi

    data_dir="${project_root_path}/data"

    if [ -z "$dump_file" ]; then
        log_info "$(i18n_message "DB_RESTORE_SEARCHING_DUMPS" "${data_dir}")"
        # Find all common dump file extensions
        readarray -t dump_files < <(find "${data_dir}" -maxdepth 1 -type f \
            -regextype posix-extended -regex ".*\\.(sql|gz|zip|tar|dmp)$" \
            -printf "%f\n" | sort)

        if [ ${#dump_files[@]} -eq 0 ]; then
            log_error "$(i18n_message "DB_RESTORE_NO_DUMPS_FOUND" "${data_dir}")"
            return 1
        fi

        log_info "$(i18n_message "DB_RESTORE_SELECT_DUMP")"
        local selected_dump_name=$(display_menu "${dump_files[@]}")
        if [ -z "$selected_dump_name" ]; then
            log_warn "$(i18n_message "DB_RESTORE_NO_DUMP_SELECTED")"
            return 1
        fi
        dump_file="${data_dir}/${selected_dump_name}"
    fi

    if [ ! -f "$dump_file" ]; then
        log_error "$(i18n_message "DB_RESTORE_DUMP_NOT_FOUND" "${dump_file}")"
        return 1
    fi

    # Determine Drush target if not provided
    if [ -z "$drush_target" ]; then
        drush_target=$(get_drush_target_for_command)
        if [ -z "$drush_target" ]; then
            log_warn "$(i18n_message "DB_RESTORE_NO_DRUSH_TARGET")"
            return 1
        fi
    fi

    log_info "$(i18n_message "DB_RESTORE_PROCESSING_DUMP" "${dump_file}" "${drush_target}")"

    local temp_extracted_file="${TEMP_DIR}/$(basename "${dump_file%.*}")_extracted.sql"
    local restore_command=""

    case "${dump_file##*.}" in
        sql)
            restore_command="cat \"${dump_file}\" | drush ${drush_target} sql:cli"
            ;;
        gz)
            restore_command="gunzip < \"${dump_file}\" | drush ${drush_target} sql:cli"
            ;;
        zip)
            log_info "$(i18n_message "DB_RESTORE_EXTRACTING_ZIP")"
            unzip -p "${dump_file}" > "${temp_extracted_file}"
            if [ $? -eq 0 ]; then
                restore_command="cat \"${temp_extracted_file}\" | drush ${drush_target} sql:cli"
            else
                log_error "$(i18n_message "DB_RESTORE_ZIP_EXTRACTION_FAILED" "${dump_file}")"
                rm -f "${temp_extracted_file}"
                return 1
            fi
            ;;
        tar)
            log_info "$(i18n_message "DB_RESTORE_EXTRACTING_TAR")"
            tar -xf "${dump_file}" -O > "${temp_extracted_file}" # -O extracts to stdout
            if [ $? -eq 0 ]; then
                restore_command="cat \"${temp_extracted_file}\" | drush ${drush_target} sql:cli"
            else
                log_error "$(i18n_message "DB_RESTORE_TAR_EXTRACTION_FAILED" "${dump_file}")"
                rm -f "${temp_extracted_file}"
                return 1
            fi
            ;;
        dmp) # Oracle or PostgreSQL dump (assuming it's a plain SQL dump from pg_dump or similar)
            restore_command="cat \"${dump_file}\" | drush ${drush_target} sql:cli"
            ;;
        *)
            log_error "$(i18n_message "DB_RESTORE_UNSUPPORTED_FORMAT" "${dump_file##*.}")"
            return 1
            ;;
    esac

    log_info "$(i18n_message "DB_RESTORE_EXECUTING_RESTORE" "${drush_target}")"
    eval "${restore_command}"
    local status=$?

    # Clean up temporary extracted file if it was created
    if [ -f "${temp_extracted_file}" ]; then
        rm -f "${temp_extracted_file}"
    fi

    if [ $status -eq 0 ]; then
        log_success "$(i18n_message "DB_RESTORE_SUCCESS" "${dump_file}" "${drush_target}")"
        # Always run drush updb and drush cr after a restore
        drush_run_command "${drush_target}" "updb -y"
        drush_run_command "${drush_target}" "cr"
        log_success "$(i18n_message "DB_RESTORE_POST_UPDATE_SUCCESS")"
    else
        log_error "$(i18n_message "DB_RESTORE_FAILED" "${dump_file}" "${drush_target}")"
    fi
    return $status
}

# Function to display Database menu
database_menu() {
    while true; do
        clear
        print_header "$(i18n_message "DATABASE_MENU_TITLE")"
        log_info "$(i18n_message "CURRENT_DRUSH_TARGET" "${CURRENT_DRUSH_TARGET}")"

        local options=(
            "$(i18n_message "DB_UPDATE_DB")" # drush updb
            "$(i18n_message "DB_DUMP")"      # drush sql:dump
            "$(i18n_message "DB_CLI")"       # drush sql:cli
            "$(i18n_message "DB_QUERY")"     # drush sql:query
            "$(i18n_message "DB_SYNC")"      # drush sql:sync
            "$(i18n_message "DB_RESTORE")"   # drush_db_restore
            "$(i18n_message "DRUSH_SELECT_TARGET")"
            "$(i18n_message "BACK")"
        )
        local choice=$(display_menu "${options[@]}")

        case "${choice}" in
            "$(i18n_message "DB_UPDATE_DB")")
                drush_run_command "${CURRENT_DRUSH_TARGET}" "updb -y"
                prompt_continue
                ;;
            "$(i18n_message "DB_DUMP")")
                local dump_file_name=$(prompt_input "$(i18n_message "DB_ENTER_DUMP_FILENAME")" "db_dump_$(date +%Y%m%d%H%M%S).sql")
                if [ -n "$dump_file_name" ]; then
                    local dump_path=$(get_current_project_path)/data
                    mkdir -p "$dump_path"
                    drush_run_command "${CURRENT_DRUSH_TARGET}" "sql:dump --result-file=\"${dump_path}/${dump_file_name}\""
                else
                    log_warn "$(i18n_message "DB_DUMP_FILENAME_EMPTY")"
                fi
                prompt_continue
                ;;
            "$(i18n_message "DB_CLI")")
                log_info "$(i18n_message "DB_ENTERING_SQL_CLI")"
                drush_run_command "${CURRENT_DRUSH_TARGET}" "sql:cli"
                log_info "$(i18n_message "DB_EXITED_SQL_CLI")"
                prompt_continue
                ;;
            "$(i18n_message "DB_QUERY")")
                local query=$(prompt_input "$(i18n_message "DB_ENTER_SQL_QUERY")" "")
                if [ -n "$query" ]; then
                    drush_run_command "${CURRENT_DRUSH_TARGET}" "sql:query \"${query}\""
                else
                    log_warn "$(i18n_message "DB_QUERY_EMPTY")"
                fi
                prompt_continue
                ;;
            "$(i18n_message "DB_SYNC")")
                local source_alias=$(prompt_input "$(i18n_message "DB_ENTER_SOURCE_ALIAS")" "")
                if [ -n "$source_alias" ]; then
                    drush_run_command "${source_alias}" "sql:sync ${CURRENT_DRUSH_TARGET} -y"
                else
                    log_warn "$(i18n_message "DB_SYNC_SOURCE_EMPTY")"
                fi
                prompt_continue
                ;;
            "$(i18n_message "DB_RESTORE")")
                drush_db_restore
                prompt_continue
                ;;
            "$(i18n_message "DRUSH_SELECT_TARGET")")
                select_drush_target
                ;;
            "$(i18n_message "BACK")")
                break
                ;;
            *)
                log_error "$(i18n_message "ERROR_INVALID_CHOICE")"
                prompt_continue
                ;;
        esac
    done
}
EOF

    # core/drush.sh
    cat << 'EOF' > "${CORE_DIR}/drush.sh"
#!/bin/bash

# AUB Tools - core/drush.sh
# This script contains functions for Drush management.

# Load helpers
source "${HELPERS_DIR}/log.sh"
source "${HELPERS_DIR}/menu.sh"
source "${HELPERS_DIR}/prompt.sh"
source "${HELPERS_DIR}/i18n.sh"
source "${HELPERS_DIR}/utils.sh"
source "${HELPERS_DIR}/config.sh"
source "${CORE_DIR}/project.sh" # Needed for project path detection

# Global variable for current Drush target (alias or URI)
CURRENT_DRUSH_TARGET=""

# Function to run a drush command with a specific target
# Arguments:
#   $1 - Drush target (e.g., '@self', '@my.site', 'http://localhost/site')
#   $@ - Drush command and arguments
drush_run_command() {
    local target="$1"
    shift
    local command_args="$@"

    if ! is_current_project_drupal; then
        log_error "$(i18n_message "ERROR_NOT_DRUPAL_PROJECT")"
        return 1
    fi

    local drupal_root_path=$(get_drupal_root_path)
    if [ -z "$drupal_root_path" ]; then
        log_error "$(i18n_message "ERROR_DRUPAL_ROOT_UNKNOWN")"
        return 1
    fi

    log_info "$(i18n_message "DRUSH_EXECUTING_COMMAND" "drush ${target} ${command_args}")"
    (cd "${drupal_root_path}" && drush "${target}" ${command_args})
    local status=$?
    if [ $status -eq 0 ]; then
        log_success "$(i18n_message "DRUSH_COMMAND_SUCCESS")"
    else
        log_error "$(i18n_message "DRUSH_COMMAND_FAILED")"
    fi
    return $status
}

# Function to detect Drush aliases or multi-site URIs
# Populates a menu for user selection
get_drush_targets() {
    local drupal_root_path=$(get_drupal_root_path)
    if [ -z "$drupal_root_path" ]; then
        log_error "$(i18n_message "ERROR_DRUPAL_ROOT_UNKNOWN")"
        return 1
    fi

    log_info "$(i18n_message "DRUSH_DETECTING_TARGETS")"
    local targets=()

    # Add '@self' as a default option
    targets+=("@self ($(i18n_message "DRUSH_CURRENT_SITE"))")

    # Get aliases from 'drush sa' (site alias list)
    local aliases=$(cd "${drupal_root_path}" && drush sa --format=json 2>/dev/null | jq -r 'keys[]')
    if [ -n "$aliases" ]; then
        for alias in $aliases; do
            # Filter out @self if it appears as an alias
            if [[ "$alias" != "@self" ]]; then
                targets+=("${alias}")
            fi
        done
    fi

    # Detect multi-site URIs if sites.php exists
    local sites_php_path="${drupal_root_path}/sites/sites.php"
    if [ -f "$sites_php_path" ]; then
        log_debug "$(i18n_message "DRUSH_DETECTING_MULTI_SITES")"
        # Extract URIs from sites.php using a regex (this is a simplified approach)
        # Assumes format like $sites['example.com'] = 'my_site_directory';
        # or $sites['sub.example.com'] = 'my_sub_site_directory';
        local uris=$(grep -Po "\['\K[^'\.]+\.[^'\.]+'(?= *\])" "${sites_php_path}" | sed "s/'//g")
        if [ -n "$uris" ]; then
            for uri in $uris; do
                targets+=("${uri}")
            done
        fi
    fi

    # Add "All sites" option
    targets+=("$(i18n_message "DRUSH_ALL_SITES_ALIAS")")

    # Ensure uniqueness and sort
    readarray -t unique_targets < <(printf "%s\n" "${targets[@]}" | sort -u)

    echo "${unique_targets[@]}"
}

# Function to prompt user to select a Drush target
select_drush_target() {
    local available_targets=($(get_drush_targets))
    if [ ${#available_targets[@]} -eq 0 ]; then
        log_error "$(i18n_message "DRUSH_NO_TARGETS_FOUND")"
        CURRENT_DRUSH_TARGET=""
        return 1
    fi

    log_info "$(i18n_message "DRUSH_PLEASE_SELECT_TARGET")"
    local selected_choice=$(display_menu "${available_targets[@]}")

    if [ -n "$selected_choice" ]; then
        # Remove the description for @self
        if [[ "$selected_choice" == "@self "* ]]; then
            CURRENT_DRUSH_TARGET="@self"
        elif [[ "$selected_choice" == "$(i18n_message "DRUSH_ALL_SITES_ALIAS")" ]]; then
            CURRENT_DRUSH_TARGET="@sites" # Standard Drush alias for all sites
        else
            CURRENT_DRUSH_TARGET="$selected_choice"
        fi
        log_success "$(i18n_message "DRUSH_TARGET_SET" "${CURRENT_DRUSH_TARGET}")"
    else
        log_warn "$(i18n_message "DRUSH_TARGET_NOT_SET")"
    fi
}

# Ensure a Drush target is set before running commands
# This function will prompt the user if CURRENT_DRUSH_TARGET is empty
get_drush_target_for_command() {
    if [ -z "$CURRENT_DRUSH_TARGET" ]; then
        select_drush_target
    fi
    echo "$CURRENT_DRUSH_TARGET"
}

# --- Sub-menus for Drush commands ---

# Drush General commands
drush_general_menu() {
    while true; do
        clear
        print_header "$(i18n_message "DRUSH_GENERAL_MENU_TITLE")"
        log_info "$(i18n_message "CURRENT_DRUSH_TARGET" "${CURRENT_DRUSH_TARGET}")"

        local options=(
            "$(i18n_message "DRUSH_STATUS")"
            "$(i18n_message "DRUSH_CACHE_REBUILD")"
            "$(i18n_message "DRUSH_SELECT_TARGET")"
            "$(i18n_message "BACK")"
        )
        local choice=$(display_menu "${options[@]}")
        local target=$(get_drush_target_for_command)
        if [ -z "$target" ]; then prompt_continue; continue; fi

        case "${choice}" in
            "$(i18n_message "DRUSH_STATUS")")
                drush_run_command "${target}" "status"
                prompt_continue
                ;;
            "$(i18n_message "DRUSH_CACHE_REBUILD")")
                drush_run_command "${target}" "cr"
                prompt_continue
                ;;
            "$(i18n_message "DRUSH_SELECT_TARGET")")
                select_drush_target
                ;;
            "$(i18n_message "BACK")")
                break
                ;;
            *)
                log_error "$(i18n_message "ERROR_INVALID_CHOICE")"
                prompt_continue
                ;;
        esac
    done
}

# Drush Configuration commands
drush_config_menu() {
    while true; do
        clear
        print_header "$(i18n_message "DRUSH_CONFIG_MENU_TITLE")"
        log_info "$(i18n_message "CURRENT_DRUSH_TARGET" "${CURRENT_DRUSH_TARGET}")"

        local options=(
            "$(i18n_message "DRUSH_CONFIG_IMPORT")"
            "$(i18n_message "DRUSH_CONFIG_EXPORT")"
            "$(i18n_message "DRUSH_SELECT_TARGET")"
            "$(i18n_message "BACK")"
        )
        local choice=$(display_menu "${options[@]}")
        local target=$(get_drush_target_for_command)
        if [ -z "$target" ]; then prompt_continue; continue; fi

        case "${choice}" in
            "$(i18n_message "DRUSH_CONFIG_IMPORT")")
                drush_run_command "${target}" "cim -y"
                prompt_continue
                ;;
            "$(i18n_message "DRUSH_CONFIG_EXPORT")")
                drush_run_command "${target}" "cex -y"
                prompt_continue
                ;;
            "$(i18n_message "DRUSH_SELECT_TARGET")")
                select_drush_target
                ;;
            "$(i18n_message "BACK")")
                break
                ;;
            *)
                log_error "$(i18n_message "ERROR_INVALID_CHOICE")"
                prompt_continue
                ;;
        esac
    done
}

# Drush Modules/Themes commands
drush_modules_themes_menu() {
    while true; do
        clear
        print_header "$(i18n_message "DRUSH_MODULES_THEMES_MENU_TITLE")"
        log_info "$(i18n_message "CURRENT_DRUSH_TARGET" "${CURRENT_DRUSH_TARGET}")"

        local options=(
            "$(i18n_message "DRUSH_PM_LIST")"
            "$(i18n_message "DRUSH_PM_ENABLE")"
            "$(i18n_message "DRUSH_PM_DISABLE")"
            "$(i18n_message "DRUSH_PM_UNINSTALL")"
            "$(i18n_message "DRUSH_SELECT_TARGET")"
            "$(i18n_message "BACK")"
        )
        local choice=$(display_menu "${options[@]}")
        local target=$(get_drush_target_for_command)
        if [ -z "$target" ]; then prompt_continue; continue; fi

        case "${choice}" in
            "$(i18n_message "DRUSH_PM_LIST")")
                drush_run_command "${target}" "pm:list --status=enabled --field=name"
                prompt_continue
                ;;
            "$(i18n_message "DRUSH_PM_ENABLE")")
                local module_name=$(prompt_input "$(i18n_message "DRUSH_ENTER_MODULE_NAME_TO_ENABLE")" "")
                if [ -n "$module_name" ]; then
                    drush_run_command "${target}" "pm:enable ${module_name} -y"
                else
                    log_warn "$(i18n_message "DRUSH_MODULE_NAME_EMPTY")"
                fi
                prompt_continue
                ;;
            "$(i18n_message "DRUSH_PM_DISABLE")")
                local module_name=$(prompt_input "$(i18n_message "DRUSH_ENTER_MODULE_NAME_TO_DISABLE")" "")
                if [ -n "$module_name" ]; then
                    drush_run_command "${target}" "pm:disable ${module_name} -y"
                else
                    log_warn "$(i18n_message "DRUSH_MODULE_NAME_EMPTY")"
                fi
                prompt_continue
                ;;
            "$(i18n_message "DRUSH_PM_UNINSTALL")")
                local module_name=$(prompt_input "$(i18n_message "DRUSH_ENTER_MODULE_NAME_TO_UNINSTALL")" "")
                if [ -n "$module_name" ]; then
                    drush_run_command "${target}" "pm:uninstall ${module_name} -y"
                else
                    log_warn "$(i18n_message "DRUSH_MODULE_NAME_EMPTY")"
                fi
                prompt_continue
                ;;
            "$(i18n_message "DRUSH_SELECT_TARGET")")
                select_drush_target
                ;;
            "$(i18n_message "BACK")")
                break
                ;;
            *)
                log_error "$(i18n_message "ERROR_INVALID_CHOICE")"
                prompt_continue
                ;;
        esac
    done
}

# Drush User management commands
drush_user_menu() {
    while true; do
        clear
        print_header "$(i18n_message "DRUSH_USER_MENU_TITLE")"
        log_info "$(i18n_message "CURRENT_DRUSH_TARGET" "${CURRENT_DRUSH_TARGET}")"

        local options=(
            "$(i18n_message "DRUSH_USER_LOGIN")"
            "$(i18n_message "DRUSH_USER_BLOCK")"
            "$(i18n_message "DRUSH_USER_UNBLOCK")"
            "$(i18n_message "DRUSH_USER_PASSWORD")"
            "$(i18n_message "DRUSH_SELECT_TARGET")"
            "$(i18n_message "BACK")"
        )
        local choice=$(display_menu "${options[@]}")
        local target=$(get_drush_target_for_command)
        if [ -z "$target" ]; then prompt_continue; continue; fi

        case "${choice}" in
            "$(i18n_message "DRUSH_USER_LOGIN")")
                drush_run_command "${target}" "user:login"
                prompt_continue
                ;;
            "$(i18n_message "DRUSH_USER_BLOCK")")
                local username=$(prompt_input "$(i18n_message "DRUSH_ENTER_USERNAME_TO_BLOCK")" "")
                if [ -n "$username" ]; then
                    drush_run_command "${target}" "user:block ${username}"
                else
                    log_warn "$(i18n_message "DRUSH_USERNAME_EMPTY")"
                fi
                prompt_continue
                ;;
            "$(i18n_message "DRUSH_USER_UNBLOCK")")
                local username=$(prompt_input "$(i18n_message "DRUSH_ENTER_USERNAME_TO_UNBLOCK")" "")
                if [ -n "$username" ]; then
                    drush_run_command "${target}" "user:unblock ${username}"
                else
                    log_warn "$(i18n_message "DRUSH_USERNAME_EMPTY")"
                fi
                prompt_continue
                ;;
            "$(i18n_message "DRUSH_USER_PASSWORD")")
                local username=$(prompt_input "$(i18n_message "DRUSH_ENTER_USERNAME_TO_SET_PASSWORD")" "")
                if [ -n "$username" ]; then
                    local new_password=$(prompt_input "$(i18n_message "DRUSH_ENTER_NEW_PASSWORD")" "")
                    if [ -n "$new_password" ]; then
                        drush_run_command "${target}" "user:password ${username} '${new_password}'"
                    else
                        log_warn "$(i18n_message "DRUSH_NEW_PASSWORD_EMPTY")"
                    fi
                else
                    log_warn "$(i18n_message "DRUSH_USERNAME_EMPTY")"
                fi
                prompt_continue
                ;;
            "$(i18n_message "DRUSH_SELECT_TARGET")")
                select_drush_target
                ;;
            "$(i18n_message "BACK")")
                break
                ;;
            *)
                log_error "$(i18n_message "ERROR_INVALID_CHOICE")"
                prompt_continue
                ;;
        esac
    done
}

# Drush Watchdog commands
drush_watchdog_menu() {
    while true; do
        clear
        print_header "$(i18n_message "DRUSH_WATCHDOG_MENU_TITLE")"
        log_info "$(i18n_message "CURRENT_DRUSH_TARGET" "${CURRENT_DRUSH_TARGET}")"

        local options=(
            "$(i18n_message "DRUSH_WATCHDOG_SHOW")"
            "$(i18n_message "DRUSH_WATCHDOG_LIST")"
            "$(i18n_message "DRUSH_WATCHDOG_DELETE")"
            "$(i18n_message "DRUSH_WATCHDOG_TAIL")"
            "$(i18n_message "DRUSH_SELECT_TARGET")"
            "$(i18n_message "BACK")"
        )
        local choice=$(display_menu "${options[@]}")
        local target=$(get_drush_target_for_command)
        if [ -z "$target" ]; then prompt_continue; continue; fi

        case "${choice}" in
            "$(i18n_message "DRUSH_WATCHDOG_SHOW")")
                drush_run_command "${target}" "watchdog:show"
                prompt_continue
                ;;
            "$(i18n_message "DRUSH_WATCHDOG_LIST")")
                drush_run_command "${target}" "watchdog:list"
                prompt_continue
                ;;
            "$(i18n_message "DRUSH_WATCHDOG_DELETE")")
                drush_run_command "${target}" "watchdog:delete all -y"
                prompt_continue
                ;;
            "$(i18n_message "DRUSH_WATCHDOG_TAIL")")
                log_info "$(i18n_message "DRUSH_WATCHDOG_TAIL_EXPLANATION")"
                drush_run_command "${target}" "watchdog:tail"
                prompt_continue
                ;;
            "$(i18n_message "DRUSH_SELECT_TARGET")")
                select_drush_target
                ;;
            "$(i18n_message "BACK")")
                break
                ;;
            *)
                log_error "$(i18n_message "ERROR_INVALID_CHOICE")"
                prompt_continue
                ;;
        esac
    done
}

# Drush Development Tools commands
drush_dev_tools_menu() {
    while true; do
        clear
        print_header "$(i18n_message "DRUSH_DEV_TOOLS_MENU_TITLE")"
        log_info "$(i18n_message "CURRENT_DRUSH_TARGET" "${CURRENT_DRUSH_TARGET}")"

        local options=(
            "$(i18n_message "DRUSH_EVAL_PHP")"
            "$(i18n_message "DRUSH_PHP_SHELL")"
            "$(i18n_message "DRUSH_RUN_CRON")"
            "$(i18n_message "DRUSH_SELECT_TARGET")"
            "$(i18n_message "BACK")"
        )
        local choice=$(display_menu "${options[@]}")
        local target=$(get_drush_target_for_command)
        if [ -z "$target" ]; then prompt_continue; continue; fi

        case "${choice}" in
            "$(i18n_message "DRUSH_EVAL_PHP")")
                local php_code=$(prompt_input "$(i18n_message "DRUSH_ENTER_PHP_CODE")" "")
                if [ -n "$php_code" ]; then
                    drush_run_command "${target}" "ev '${php_code}'"
                else
                    log_warn "$(i18n_message "DRUSH_PHP_CODE_EMPTY")"
                fi
                prompt_continue
                ;;
            "$(i18n_message "DRUSH_PHP_SHELL")")
                log_info "$(i18n_message "DRUSH_PHP_SHELL_EXPLANATION")"
                drush_run_command "${target}" "php"
                log_info "$(i18n_message "DRUSH_PHP_SHELL_EXITED")"
                prompt_continue
                ;;
            "$(i18n_message "DRUSH_RUN_CRON")")
                drush_run_command "${target}" "cron"
                prompt_continue
                ;;
            "$(i18n_message "DRUSH_SELECT_TARGET")")
                select_drush_target
                ;;
            "$(i18n_message "BACK")")
                break
                ;;
            *)
                log_error "$(i18n_message "ERROR_INVALID_CHOICE")"
                prompt_continue
                ;;
        esac
    done
}

# Drush Webform commands
drush_webform_menu() {
    while true; do
        clear
        print_header "$(i18n_message "DRUSH_WEBFORM_MENU_TITLE")"
        log_info "$(i18n_message "CURRENT_DRUSH_TARGET" "${CURRENT_DRUSH_TARGET}")"

        local options=(
            "$(i18n_message "DRUSH_WEBFORM_LIST")"
            "$(i18n_message "DRUSH_WEBFORM_EXPORT")"
            "$(i18n_message "DRUSH_WEBFORM_PURGE")"
            "$(i18n_message "DRUSH_SELECT_TARGET")"
            "$(i18n_message "BACK")"
        )
        local choice=$(display_menu "${options[@]}")
        local target=$(get_drush_target_for_command)
        if [ -z "$target" ]; then prompt_continue; continue; fi

        case "${choice}" in
            "$(i18n_message "DRUSH_WEBFORM_LIST")")
                drush_run_command "${target}" "webform:list"
                prompt_continue
                ;;
            "$(i18n_message "DRUSH_WEBFORM_EXPORT")")
                local webform_id=$(prompt_input "$(i18n_message "DRUSH_ENTER_WEBFORM_ID_TO_EXPORT")" "")
                if [ -n "$webform_id" ]; then
                    drush_run_command "${target}" "webform:export ${webform_id}"
                else
                    log_warn "$(i18n_message "DRUSH_WEBFORM_ID_EMPTY")"
                fi
                prompt_continue
                ;;
            "$(i18n_message "DRUSH_WEBFORM_PURGE")")
                local webform_id=$(prompt_input "$(i18n_message "DRUSH_ENTER_WEBFORM_ID_TO_PURGE")" "")
                if [ -n "$webform_id" ]; then
                    drush_run_command "${target}" "webform:purge ${webform_id} -y"
                else
                    log_warn "$(i18n_message "DRUSH_WEBFORM_ID_EMPTY")"
                fi
                prompt_continue
                ;;
            "$(i18n_message "DRUSH_SELECT_TARGET")")
                select_drush_target
                ;;
            "$(i18n_message "BACK")")
                break
                ;;
            *)
                log_error "$(i18n_message "ERROR_INVALID_CHOICE")"
                prompt_continue
                ;;
        esac
    done
}

# Main Drush menu
drush_menu() {
    while true; do
        clear
        print_header "$(i18n_message "DRUSH_MENU_TITLE")"
        log_info "$(i18n_message "CURRENT_DRUSH_TARGET" "${CURRENT_DRUSH_TARGET}")"

        local options=(
            "$(i18n_message "DRUSH_GENERAL_COMMANDS")"
            "$(i18n_message "DRUSH_CONFIG_COMMANDS")"
            "$(i18n_message "DATABASE_MENU_TITLE")" # From database.sh
            "$(i18n_message "DRUSH_MODULES_THEMES_COMMANDS")"
            "$(i18n_message "DRUSH_USER_COMMANDS")"
            "$(i18n_message "DRUSH_WATCHDOG_COMMANDS")"
            "$(i18n_message "DRUSH_SEARCH_API_SOLR_COMMANDS")" # From solr.sh
            "$(i18n_message "DRUSH_WEBFORM_COMMANDS")"
            "$(i18n_message "DRUSH_DEV_TOOLS_COMMANDS")"
            "$(i18n_message "DRUSH_SELECT_TARGET")"
            "$(i18n_message "BACK")"
        )
        local choice=$(display_menu "${options[@]}")

        case "${choice}" in
            "$(i18n_message "DRUSH_GENERAL_COMMANDS")")
                drush_general_menu
                ;;
            "$(i18n_message "DRUSH_CONFIG_COMMANDS")")
                drush_config_menu
                ;;
            "$(i18n_message "DATABASE_MENU_TITLE")")
                database_menu # Calls function from database.sh
                ;;
            "$(i18n_message "DRUSH_MODULES_THEMES_COMMANDS")")
                drush_modules_themes_menu
                ;;
            "$(i18n_message "DRUSH_USER_COMMANDS")")
                drush_user_menu
                ;;
            "$(i18n_message "DRUSH_WATCHDOG_COMMANDS")")
                drush_watchdog_menu
                ;;
            "$(i18n_message "DRUSH_SEARCH_API_SOLR_COMMANDS")")
                solr_menu # Calls function from solr.sh
                ;;
            "$(i18n_message "DRUSH_WEBFORM_COMMANDS")")
                drush_webform_menu
                ;;
            "$(i18n_message "DRUSH_DEV_TOOLS_COMMANDS")")
                drush_dev_tools_menu
                ;;
            "$(i18n_message "DRUSH_SELECT_TARGET")")
                select_drush_target
                ;;
            "$(i18n_message "BACK")")
                break
                ;;
            *)
                log_error "$(i18n_message "ERROR_INVALID_CHOICE")"
                prompt_continue
                ;;
        esac
    done
}
EOF

    # core/git.sh
    cat << 'EOF' > "${CORE_DIR}/git.sh"
#!/bin/bash

# AUB Tools - core/git.sh
# This script contains functions for Git management.

# Load helpers
source "${HELPERS_DIR}/log.sh"
source "${HELPERS_DIR}/menu.sh"
source "${HELPERS_DIR}/prompt.sh"
source "${HELPERS_DIR}/i18n.sh"
source "${HELPERS_DIR}/utils.sh"
source "${HELPERS_DIR}/config.sh"
source "${CORE_DIR}/project.sh" # Needed for project path detection

# Function to run a Git command
# Arguments:
#   $1 - Git command (e.g., 'status', 'pull')
#   $@ - Additional arguments for git
git_run() {
    local cmd="$1"
    shift
    local args="$@"

    local project_root_path=$(get_current_project_path)
    if [ -z "$project_root_path" ]; then
        log_error "$(i18n_message "ERROR_PROJECT_PATH_UNKNOWN")"
        return 1
    fi

    if [ ! -d "${project_root_path}/.git" ]; then
        log_error "$(i18n_message "GIT_NOT_GIT_REPO" "${project_root_path}")"
        return 1
    fi

    log_info "$(i18n_message "GIT_RUNNING_COMMAND" "git ${cmd} ${args}")"
    (cd "${project_root_path}" && git "${cmd}" ${args})
    local status=$?
    if [ $status -eq 0 ]; then
        log_success "$(i18n_message "GIT_COMMAND_SUCCESS" "${cmd}")"
    else
        log_error "$(i18n_message "GIT_COMMAND_FAILED" "${cmd}")"
    fi
    return $status
}

# Function to display Git Status
git_status() {
    git_run status
}

# Function to display Git Log
git_log() {
    local num_commits=$(prompt_input "$(i18n_message "GIT_ENTER_NUMBER_OF_COMMITS")" "10")
    git_run log --oneline -n ${num_commits}
}

# Function to list and switch branches
git_branch_management() {
    while true; do
        clear
        print_header "$(i18n_message "GIT_BRANCH_MENU_TITLE")"
        log_info "$(i18n_message "CURRENT_PROJECT_PATH" "${CURRENT_PROJECT_PATH}")"

        local options=(
            "$(i18n_message "GIT_LIST_BRANCHES")"
            "$(i18n_message "GIT_SWITCH_BRANCH")"
            "$(i18n_message "GIT_CREATE_NEW_BRANCH")"
            "$(i18n_message "BACK")"
        )
        local choice=$(display_menu "${options[@]}")

        case "${choice}" in
            "$(i18n_message "GIT_LIST_BRANCHES")")
                log_info "$(i18n_message "GIT_FETCHING_BRANCHES")"
                git_run fetch --all --prune
                log_info "$(i18n_message "GIT_LISTING_BRANCHES")"
                git_run branch -a
                prompt_continue
                ;;
            "$(i18n_message "GIT_SWITCH_BRANCH")")
                local project_root_path=$(get_current_project_path)
                if [ -z "$project_root_path" ]; then
                    log_error "$(i18n_message "ERROR_PROJECT_PATH_UNKNOWN")"
                    prompt_continue
                    continue
                fi
                git_run fetch --all --prune # Ensure we have all remote branches

                log_info "$(i18n_message "GIT_SELECT_BRANCH_TO_SWITCH")"
                # Get all local and remote branches for menu selection
                readarray -t branches < <(cd "${project_root_path}" && git branch -a --format="%(refname:short)" | sort -u)
                if [ ${#branches[@]} -eq 0 ]; then
                    log_warn "$(i18n_message "GIT_NO_BRANCHES_FOUND")"
                    prompt_continue
                    continue
                fi

                local selected_branch=$(display_menu "${branches[@]}")
                if [ -n "$selected_branch" ]; then
                    # Handle remote tracking branches (e.g., remotes/origin/main)
                    if [[ "$selected_branch" == "remotes/"* ]]; then
                        local local_branch_name=$(basename "$selected_branch")
                        log_info "$(i18n_message "GIT_CHECKOUT_REMOTE_AS_LOCAL" "${selected_branch}" "${local_branch_name}")"
                        git_run checkout -b "${local_branch_name}" "${selected_branch}"
                    else
                        git_run checkout "${selected_branch}"
                    fi
                else
                    log_warn "$(i18n_message "GIT_NO_BRANCH_SELECTED")"
                fi
                prompt_continue
                ;;
            "$(i18n_message "GIT_CREATE_NEW_BRANCH")")
                local new_branch_name=$(prompt_input "$(i18n_message "GIT_ENTER_NEW_BRANCH_NAME")" "")
                if [ -n "$new_branch_name" ]; then
                    git_run checkout -b "${new_branch_name}"
                else
                    log_warn "$(i18n_message "GIT_NEW_BRANCH_NAME_EMPTY")"
                fi
                prompt_continue
                ;;
            "$(i18n_message "BACK")")
                break
                ;;
            *)
                log_error "$(i18n_message "ERROR_INVALID_CHOICE")"
                prompt_continue
                ;;
        esac
    done
}

# Function for Git Pull
git_pull() {
    git_run pull
}

# Function for Git Push
git_push() {
    git_run push
}

# Function for Git Stash management
git_stash_management() {
    while true; do
        clear
        print_header "$(i18n_message "GIT_STASH_MENU_TITLE")"
        log_info "$(i18n_message "CURRENT_PROJECT_PATH" "${CURRENT_PROJECT_PATH}")"

        local options=(
            "$(i18n_message "GIT_STASH_SAVE")"
            "$(i18n_message "GIT_STASH_LIST")"
            "$(i18n_message "GIT_STASH_APPLY")"
            "$(i18n_message "GIT_STASH_POP")"
            "$(i18n_message "GIT_STASH_DROP")"
            "$(i18n_message "BACK")"
        )
        local choice=$(display_menu "${options[@]}")

        case "${choice}" in
            "$(i18n_message "GIT_STASH_SAVE")")
                local message=$(prompt_input "$(i18n_message "GIT_ENTER_STASH_MESSAGE")" "")
                if [ -n "$message" ]; then
                    git_run stash save "${message}"
                else
                    git_run stash save
                fi
                prompt_continue
                ;;
            "$(i18n_message "GIT_STASH_LIST")")
                git_run stash list
                prompt_continue
                ;;
            "$(i18n_message "GIT_STASH_APPLY")")
                local stash_ref=$(prompt_input "$(i18n_message "GIT_ENTER_STASH_REF_TO_APPLY")" "stash@{0}")
                git_run stash apply "${stash_ref}"
                prompt_continue
                ;;
            "$(i18n_message "GIT_STASH_POP")")
                local stash_ref=$(prompt_input "$(i18n_message "GIT_ENTER_STASH_REF_TO_POP")" "stash@{0}")
                git_run stash pop "${stash_ref}"
                prompt_continue
                ;;
            "$(i18n_message "GIT_STASH_DROP")")
                local stash_ref=$(prompt_input "$(i18n_message "GIT_ENTER_STASH_REF_TO_DROP")" "stash@{0}")
                git_run stash drop "${stash_ref}" -y
                prompt_continue
                ;;
            "$(i18n_message "BACK")")
                break
                ;;
            *)
                log_error "$(i18n_message "ERROR_INVALID_CHOICE")"
                prompt_continue
                ;;
        esac
    done
}

# Function for Git Undo operations
git_undo_management() {
    while true; do
        clear
        print_header "$(i18n_message "GIT_UNDO_MENU_TITLE")"
        log_info "$(i18n_message "CURRENT_PROJECT_PATH" "${CURRENT_PROJECT_PATH}")"

        local options=(
            "$(i18n_message "GIT_RESET_HARD")"
            "$(i18n_message "GIT_REVERT_COMMIT")"
            "$(i18n_message "GIT_CLEAN")"
            "$(i18n_message "BACK")"
        )
        local choice=$(display_menu "${options[@]}")

        case "${choice}" in
            "$(i18n_message "GIT_RESET_HARD")")
                if prompt_confirm "$(i18n_message "GIT_CONFIRM_RESET_HARD")"; then
                    git_run reset --hard
                    log_warn "$(i18n_message "GIT_RESET_HARD_WARNING")"
                else
                    log_info "$(i18n_message "GIT_RESET_HARD_CANCELLED")"
                fi
                prompt_continue
                ;;
            "$(i18n_message "GIT_REVERT_COMMIT")")
                local commit_hash=$(prompt_input "$(i18n_message "GIT_ENTER_COMMIT_HASH_TO_REVERT")" "")
                if [ -n "$commit_hash" ]; then
                    if prompt_confirm "$(i18n_message "GIT_CONFIRM_REVERT_COMMIT" "${commit_hash}")"; then
                        git_run revert "${commit_hash}"
                    else
                        log_info "$(i18n_message "GIT_REVERT_COMMIT_CANCELLED")"
                    fi
                else
                    log_warn "$(i18n_message "GIT_COMMIT_HASH_EMPTY")"
                fi
                prompt_continue
                ;;
            "$(i18n_message "GIT_CLEAN")")
                if prompt_confirm "$(i18n_message "GIT_CONFIRM_CLEAN")"; then
                    git_run clean -dfx
                    log_warn "$(i18n_message "GIT_CLEAN_WARNING")"
                else
                    log_info "$(i18n_message "GIT_CLEAN_CANCELLED")"
                fi
                prompt_continue
                ;;
            "$(i18n_message "BACK")")
                break
                ;;
            *)
                log_error "$(i18n_message "ERROR_INVALID_CHOICE")"
                prompt_continue
                ;;
        esac
    done
}

# Main Git menu
git_menu() {
    while true; do
        clear
        print_header "$(i18n_message "GIT_MENU_TITLE")"
        log_info "$(i18n_message "CURRENT_PROJECT_PATH" "${CURRENT_PROJECT_PATH}")"

        local options=(
            "$(i18n_message "GIT_STATUS")"
            "$(i18n_message "GIT_LOG")"
            "$(i18n_message "GIT_BRANCH_MANAGEMENT")"
            "$(i18n_message "GIT_PULL")"
            "$(i18n_message "GIT_PUSH")"
            "$(i18n_message "GIT_STASH_MANAGEMENT")"
            "$(i18n_message "GIT_UNDO_OPERATIONS")"
            "$(i18n_message "BACK")"
        )
        local choice=$(display_menu "${options[@]}")

        case "${choice}" in
            "$(i18n_message "GIT_STATUS")")
                git_status
                prompt_continue
                ;;
            "$(i18n_message "GIT_LOG")")
                git_log
                prompt_continue
                ;;
            "$(i18n_message "GIT_BRANCH_MANAGEMENT")")
                git_branch_management
                ;;
            "$(i18n_message "GIT_PULL")")
                git_pull
                prompt_continue
                ;;
            "$(i18n_message "GIT_PUSH")")
                git_push
                prompt_continue
                ;;
            "$(i18n_message "GIT_STASH_MANAGEMENT")")
                git_stash_management
                ;;
            "$(i18n_message "GIT_UNDO_OPERATIONS")")
                git_undo_management
                ;;
            "$(i18n_message "BACK")")
                break
                ;;
            *)
                log_error "$(i18n_message "ERROR_INVALID_CHOICE")"
                prompt_continue
                ;;
        esac
    done
}
EOF

    # core/ibmcloud.sh
    cat << 'EOF' > "${CORE_DIR}/ibmcloud.sh"
#!/bin/bash

# AUB Tools - core/ibmcloud.sh
# This script contains functions for IBM Cloud integration.

# Load helpers
source "${HELPERS_DIR}/log.sh"
source "${HELPERS_DIR}/menu.sh"
source "${HELPERS_DIR}/prompt.sh"
source "${HELPERS_DIR}/i18n.sh"
source "${HELPERS_DIR}/utils.sh"
source "${HELPERS_DIR}/config.sh"

# Function to check if ibmcloud CLI is installed
check_ibmcloud_cli() {
    if ! command -v ibmcloud &> /dev/null; then
        log_error "$(i18n_message "IBMCLOUD_CLI_NOT_FOUND")"
        return 1
    fi
    return 0
}

# Function to log in to IBM Cloud
ibmcloud_login() {
    if ! check_ibmcloud_cli; then return 1; fi

    local region="${AUB_TOOLS_IBMCLOUD_REGION}"
    local resource_group="${AUB_TOOLS_IBMCLOUD_RESOURCE_GROUP}"

    if [ -z "$region" ]; then
        region=$(prompt_input "$(i18n_message "IBMCLOUD_ENTER_REGION")" "eu-de")
        if [ -z "$region" ]; then
            log_warn "$(i18n_message "IBMCLOUD_REGION_EMPTY")"
            return 1
        else
            update_config "AUB_TOOLS_IBMCLOUD_REGION" "$region"
        fi
    fi

    if [ -z "$resource_group" ]; then
        resource_group=$(prompt_input "$(i18n_message "IBMCLOUD_ENTER_RESOURCE_GROUP")" "Default")
        if [ -z "$resource_group" ]; then
            log_warn "$(i18n_message "IBMCLOUD_RESOURCE_GROUP_EMPTY")"
            return 1
        else
            update_config "AUB_TOOLS_IBMCLOUD_RESOURCE_GROUP" "$resource_group"
        fi
    fi

    log_info "$(i18n_message "IBMCLOUD_LOGGING_IN" "${region}" "${resource_group}")"
    ibmcloud login --sso -r "${region}" -g "${resource_group}"
    local status=$?
    if [ $status -eq 0 ]; then
        log_success "$(i18n_message "IBMCLOUD_LOGIN_SUCCESS")"
    else
        log_error "$(i18n_message "IBMCLOUD_LOGIN_FAILED")"
    fi
    return $status
}

# Function to log out from IBM Cloud
ibmcloud_logout() {
    if ! check_ibmcloud_cli; then return 1; }
    log_info "$(i18n_message "IBMCLOUD_LOGGING_OUT")"
    ibmcloud logout
    local status=$?
    if [ $status -eq 0 ]; then
        log_success "$(i18n_message "IBMCLOUD_LOGOUT_SUCCESS")"
    else
        log_error "$(i18n_message "IBMCLOUD_LOGOUT_FAILED")"
    fi
    return $status
}

# Function to list Kubernetes clusters
ibmcloud_list_kubernetes_clusters() {
    if ! check_ibmcloud_cli; then return 1; }
    log_info "$(i18n_message "IBMCLOUD_LISTING_KUBERNETES_CLUSTERS")"
    ibmcloud ks clusters
}

# Function to configure kubectl for a specific cluster
ibmcloud_configure_kubectl() {
    if ! check_ibmcloud_cli; then return 1; fi

    local clusters=$(ibmcloud ks clusters --json 2>/dev/null | jq -r '.[].name')
    if [ -z "$clusters" ]; then
        log_warn "$(i18n_message "IBMCLOUD_NO_KUBERNETES_CLUSTERS_FOUND")"
        return 1
    fi

    readarray -t cluster_names < <(echo "$clusters")

    log_info "$(i18n_message "IBMCLOUD_SELECT_KUBERNETES_CLUSTER")"
    local selected_cluster=$(display_menu "${cluster_names[@]}")

    if [ -n "$selected_cluster" ]; then
        log_info "$(i18n_message "IBMCLOUD_CONFIGURING_KUBECTL" "${selected_cluster}")"
        ibmcloud ks cluster config --cluster "${selected_cluster}" --admin --endpoint private
        local status=$?
        if [ $status -eq 0 ]; then
            log_success "$(i18n_message "IBMCLOUD_KUBECTL_CONFIG_SUCCESS" "${selected_cluster}")"
            log_info "$(i18n_message "IBMCLOUD_KUBECTL_CONTEXT_SET")"
            kubectl config current-context
        else
            log_error "$(i18n_message "IBMCLOUD_KUBECTL_CONFIG_FAILED" "${selected_cluster}")"
        fi
        return $status
    else
        log_warn "$(i18n_message "IBMCLOUD_NO_CLUSTER_SELECTED")"
        return 1
    fi
}

# Main IBM Cloud menu
ibmcloud_menu() {
    while true; do
        clear
        print_header "$(i18n_message "IBMCLOUD_MENU_TITLE")"

        local options=(
            "$(i18n_message "IBMCLOUD_LOGIN")"
            "$(i18n_message "IBMCLOUD_LOGOUT")"
            "$(i18n_message "IBMCLOUD_LIST_KUBERNETES_CLUSTERS")"
            "$(i18n_message "IBMCLOUD_CONFIGURE_KUBECTL")"
            "$(i18n_message "BACK")"
        )
        local choice=$(display_menu "${options[@]}")

        case "${choice}" in
            "$(i18n_message "IBMCLOUD_LOGIN")")
                ibmcloud_login
                prompt_continue
                ;;
            "$(i18n_message "IBMCLOUD_LOGOUT")")
                ibmcloud_logout
                prompt_continue
                ;;
            "$(i18n_message "IBMCLOUD_LIST_KUBERNETES_CLUSTERS")")
                ibmcloud_list_kubernetes_clusters
                prompt_continue
                ;;
            "$(i18n_message "IBMCLOUD_CONFIGURE_KUBECTL")")
                ibmcloud_configure_kubectl
                prompt_continue
                ;;
            "$(i18n_message "BACK")")
                break
                ;;
            *)
                log_error "$(i18n_message "ERROR_INVALID_CHOICE")"
                prompt_continue
                ;;
        esac
    done
}
EOF

    # core/k8s.sh
    cat << 'EOF' > "${CORE_DIR}/k8s.sh"
#!/bin/bash

# AUB Tools - core/k8s.sh
# This script contains functions for Kubernetes (kubectl) management.

# Load helpers
source "${HELPERS_DIR}/log.sh"
source "${HELPERS_DIR}/menu.sh"
source "${HELPERS_DIR}/prompt.sh"
source "${HELPERS_DIR}/i18n.sh"
source "${HELPERS_DIR}/utils.sh"
source "${HELPERS_DIR}/config.sh"

# Function to check if kubectl CLI is installed and configured
check_kubectl_cli() {
    if ! command -v kubectl &> /dev/null; then
        log_error "$(i18n_message "KUBECTL_CLI_NOT_FOUND")"
        return 1
    fi

    local current_context=$(kubectl config current-context 2>/dev/null)
    if [ -z "$current_context" ]; then
        log_warn "$(i18n_message "KUBECTL_NO_CONTEXT_SET")"
        return 1
    fi
    log_debug "$(i18n_message "KUBECTL_CURRENT_CONTEXT" "${current_context}")"
    return 0
}

# Function to select a Kubernetes namespace
# Arguments:
#   $1 - Optional: Default namespace
select_kubectl_namespace() {
    local default_namespace="$1"
    local namespaces=($(kubectl get ns -o=jsonpath='{.items[*].metadata.name}' 2>/dev/null))
    if [ ${#namespaces[@]} -eq 0 ]; then
        log_error "$(i18n_message "KUBECTL_NO_NAMESPACES_FOUND")"
        return 1
    fi

    log_info "$(i18n_message "KUBECTL_SELECT_NAMESPACE")"
    local selected_namespace=$(display_menu "${namespaces[@]}")

    if [ -n "$selected_namespace" ]; then
        echo "$selected_namespace"
    elif [ -n "$default_namespace" ]; then
        log_info "$(i18n_message "KUBECTL_USING_DEFAULT_NAMESPACE" "${default_namespace}")"
        echo "$default_namespace"
    else
        log_warn "$(i18n_message "KUBECTL_NO_NAMESPACE_SELECTED")"
        return 1
    fi
    return 0
}

# Function to select a Kubernetes pod (with optional label filter)
# Arguments:
#   $1 - Optional: Namespace (if not provided, current context namespace or prompt)
#   $2 - Optional: Label selector (e.g., 'app=nginx')
# Returns the selected pod name
select_kubectl_pod() {
    local namespace="$1"
    local label_selector="$2"
    local pods=()
    local kubectl_cmd="kubectl get pods -o=jsonpath='{.items[*].metadata.name}'"

    if [ -z "$namespace" ]; then
        namespace=$(select_kubectl_namespace)
        if [ $? -ne 0 ]; then return 1; fi
    fi
    kubectl_cmd="${kubectl_cmd} -n ${namespace}"

    if [ -n "$label_selector" ]; then
        kubectl_cmd="${kubectl_cmd} -l ${label_selector}"
        log_info "$(i18n_message "KUBECTL_FILTERING_PODS_BY_LABEL" "${label_selector}")"
    fi

    readarray -t pods < <(${kubectl_cmd} 2>/dev/null)

    if [ ${#pods[@]} -eq 0 ]; then
        log_warn "$(i18n_message "KUBECTL_NO_PODS_FOUND" "${namespace}")"
        return 1
    fi

    log_info "$(i18n_message "KUBECTL_SELECT_POD")"
    local selected_pod=$(display_menu "${pods[@]}")

    if [ -n "$selected_pod" ]; then
        echo "$selected_pod"
        return 0
    else
        log_warn "$(i18n_message "KUBECTL_NO_POD_SELECTED")"
        return 1
    fi
}

# Function to select a container within a Kubernetes pod
# Arguments:
#   $1 - Pod name
#   $2 - Optional: Namespace
# Returns the selected container name
select_kubectl_container() {
    local pod_name="$1"
    local namespace="$2"
    local containers=()

    if [ -z "$pod_name" ]; then
        log_error "$(i18n_message "KUBECTL_POD_NAME_MISSING")"
        return 1
    fi

    local kubectl_cmd="kubectl get pod ${pod_name} -o=jsonpath='{.spec.containers[*].name}'"
    if [ -n "$namespace" ]; then
        kubectl_cmd="${kubectl_cmd} -n ${namespace}"
    fi

    readarray -t containers < <(${kubectl_cmd} 2>/dev/null)

    if [ ${#containers[@]} -eq 0 ]; then
        log_warn "$(i18n_message "KUBECTL_NO_CONTAINERS_FOUND" "${pod_name}")"
        return 1
    fi

    if [ ${#containers[@]} -eq 1 ]; then
        log_info "$(i18n_message "KUBECTL_AUTO_SELECT_SINGLE_CONTAINER" "${containers[0]}")"
        echo "${containers[0]}"
        return 0
    fi

    log_info "$(i18n_message "KUBECTL_SELECT_CONTAINER")"
    local selected_container=$(display_menu "${containers[@]}")

    if [ -n "$selected_container" ]; then
        echo "$selected_container"
        return 0
    else
        log_warn "$(i18n_message "KUBECTL_NO_CONTAINER_SELECTED")"
        return 1
    fi
}

# Function to copy files to a Kubernetes pod
# Arguments:
#   $1 - Local path to copy from
#   $2 - Remote path to copy to (inside container)
#   $3 - Pod name
#   $4 - Optional: Container name
#   $5 - Optional: Namespace
kubectl_copy_to_pod() {
    local local_path="$1"
    local remote_path="$2"
    local pod_name="$3"
    local container_name="$4"
    local namespace="$5"

    if ! check_kubectl_cli; then return 1; fi

    if [ -z "$local_path" ] || [ -z "$remote_path" ]; then
        log_error "$(i18n_message "KUBECTL_COPY_MISSING_PATHS")"
        return 1
    fi

    if [ -z "$pod_name" ]; then
        pod_name=$(select_kubectl_pod "$namespace")
        if [ $? -ne 0 ]; then return 1; fi
    fi

    if [ -z "$container_name" ]; then
        container_name=$(select_kubectl_container "$pod_name" "$namespace")
        if [ $? -ne 0 ]; then return 1; fi
    fi

    local kubectl_cmd="kubectl cp \"${local_path}\" \"${pod_name}:${remote_path}\" -c \"${container_name}\""
    if [ -n "$namespace" ]; then
        kubectl_cmd="${kubectl_cmd} -n ${namespace}"
    fi

    log_info "$(i18n_message "KUBECTL_COPYING_FILES" "${local_path}" "${pod_name}:${remote_path}" "${container_name}")"
    eval "${kubectl_cmd}"
    local status=$?
    if [ $status -eq 0 ]; then
        log_success "$(i18n_message "KUBECTL_COPY_SUCCESS")"
    else
        log_error "$(i18n_message "KUBECTL_COPY_FAILED")"
    fi
    return $status
}


# --- Solr specific Kubernetes functions ---

# List Solr pods
k8s_solr_list_pods() {
    if ! check_kubectl_cli; then return 1; fi
    local namespace=$(select_kubectl_namespace)
    if [ $? -ne 0 ]; then prompt_continue; return 1; fi
    log_info "$(i18n_message "KUBECTL_LISTING_SOLR_PODS" "${namespace}")"
    kubectl get pods -n "${namespace}" -l app.kubernetes.io/name=solr
}

# Restart a Solr pod
k8s_solr_restart_pod() {
    if ! check_kubectl_cli; then return 1; fi
    local namespace=$(select_kubectl_namespace)
    if [ $? -ne 0 ]; then prompt_continue; return 1; fi

    local solr_pod=$(select_kubectl_pod "$namespace" "app.kubernetes.io/name=solr")
    if [ -z "$solr_pod" ]; then
        log_warn "$(i18n_message "KUBECTL_NO_SOLR_POD_SELECTED")"
        prompt_continue
        return 1
    fi

    if prompt_confirm "$(i18n_message "KUBECTL_CONFIRM_RESTART_SOLR_POD" "${solr_pod}")"; then
        log_info "$(i18n_message "KUBECTL_RESTARTING_SOLR_POD" "${solr_pod}")"
        kubectl delete pod "${solr_pod}" -n "${namespace}"
        local status=$?
        if [ $status -eq 0 ]; then
            log_success "$(i18n_message "KUBECTL_RESTART_SUCCESS" "${solr_pod}")"
        else
            log_error "$(i18n_message "KUBECTL_RESTART_FAILED" "${solr_pod}")"
        fi
    else
        log_info "$(i18n_message "KUBECTL_RESTART_CANCELLED")"
    fi
}

# View Solr pod logs
k8s_solr_view_logs() {
    if ! check_kubectl_cli; then return 1; fi
    local namespace=$(select_kubectl_namespace)
    if [ $? -ne 0 ]; then prompt_continue; return 1; fi

    local solr_pod=$(select_kubectl_pod "$namespace" "app.kubernetes.io/name=solr")
    if [ -z "$solr_pod" ]; then
        log_warn "$(i18n_message "KUBECTL_NO_SOLR_POD_SELECTED")"
        prompt_continue
        return 1
    fi

    local solr_container=$(select_kubectl_container "$solr_pod" "$namespace")
    if [ -z "$solr_container" ]; then
        log_warn "$(i18n_message "KUBECTL_NO_SOLR_CONTAINER_SELECTED")"
        prompt_continue
        return 1
    fi

    log_info "$(i18n_message "KUBECTL_VIEWING_SOLR_LOGS" "${solr_pod}/${solr_container}")"
    kubectl logs "${solr_pod}" -c "${solr_container}" -n "${namespace}" -f
}

# --- PostgreSQL specific Kubernetes functions ---

# List PostgreSQL pods
k8s_pgsql_list_pods() {
    if ! check_kubectl_cli; then return 1; fi
    local namespace=$(select_kubectl_namespace)
    if [ $? -ne 0 ]; then prompt_continue; return 1; fi
    log_info "$(i18n_message "KUBECTL_LISTING_PGSQL_PODS" "${namespace}")"
    kubectl get pods -n "${namespace}" -l app.kubernetes.io/name=postgresql
}

# Access PostgreSQL CLI
k8s_pgsql_cli() {
    if ! check_kubectl_cli; then return 1; fi
    local namespace=$(select_kubectl_namespace)
    if [ $? -ne 0 ]; then prompt_continue; return 1; fi

    local pgsql_pod=$(select_kubectl_pod "$namespace" "app.kubernetes.io/name=postgresql")
    if [ -z "$pgsql_pod" ]; then
        log_warn "$(i18n_message "KUBECTL_NO_PGSQL_POD_SELECTED")"
        prompt_continue
        return 1
    fi

    local pgsql_container=$(select_kubectl_container "$pgsql_pod" "$namespace")
    if [ -z "$pgsql_container" ]; then
        log_warn "$(i18n_message "KUBECTL_NO_PGSQL_CONTAINER_SELECTED")"
        prompt_continue
        return 1
    fi

    log_info "$(i18n_message "KUBECTL_ACCESSING_PGSQL_CLI" "${pgsql_pod}/${pgsql_container}")"
    kubectl exec -it "${pgsql_pod}" -c "${pgsql_container}" -n "${namespace}" -- psql
}

# View PostgreSQL pod logs
k8s_pgsql_view_logs() {
    if ! check_kubectl_cli; then return 1; fi
    local namespace=$(select_kubectl_namespace)
    if [ $? -ne 0 ]; then prompt_continue; return 1; fi

    local pgsql_pod=$(select_kubectl_pod "$namespace" "app.kubernetes.io/name=postgresql")
    if [ -z "$pgsql_pod" ]; then
        log_warn "$(i18n_message "KUBECTL_NO_PGSQL_POD_SELECTED")"
        prompt_continue
        return 1
    fi

    local pgsql_container=$(select_kubectl_container "$pgsql_pod" "$namespace")
    if [ -z "$pgsql_container" ]; then
        log_warn "$(i18n_message "KUBECTL_NO_PGSQL_CONTAINER_SELECTED")"
        prompt_continue
        return 1
    fi

    log_info "$(i18n_message "KUBECTL_VIEWING_PGSQL_LOGS" "${pgsql_pod}/${pgsql_container}")"
    kubectl logs "${pgsql_pod}" -c "${pgsql_container}" -n "${namespace}" -f
}

# --- Main Kubernetes menu ---
k8s_menu() {
    while true; do
        clear
        print_header "$(i18n_message "KUBECTL_MENU_TITLE")"
        if ! check_kubectl_cli; then
            log_warn "$(i18n_message "KUBECTL_CLI_NOT_READY")"
            prompt_continue
            break
        fi

        local options=(
            "$(i18n_message "KUBECTL_SOLR_COMMANDS")"
            "$(i18n_message "KUBECTL_PGSQL_COMMANDS")"
            "$(i18n_message "KUBECTL_COPY_FILES")"
            "$(i18n_message "BACK")"
        )
        local choice=$(display_menu "${options[@]}")

        case "${choice}" in
            "$(i18n_message "KUBECTL_SOLR_COMMANDS")")
                while true; do
                    clear
                    print_header "$(i18n_message "KUBECTL_SOLR_MENU_TITLE")"
                    local solr_options=(
                        "$(i18n_message "KUBECTL_LIST_SOLR_PODS")"
                        "$(i18n_message "KUBECTL_RESTART_SOLR_POD")"
                        "$(i18n_message "KUBECTL_VIEW_SOLR_LOGS")"
                        "$(i18n_message "BACK")"
                    )
                    local solr_choice=$(display_menu "${solr_options[@]}")
                    case "${solr_choice}" in
                        "$(i18n_message "KUBECTL_LIST_SOLR_PODS")") k8s_solr_list_pods; prompt_continue ;;
                        "$(i18n_message "KUBECTL_RESTART_SOLR_POD")") k8s_solr_restart_pod; prompt_continue ;;
                        "$(i18n_message "KUBECTL_VIEW_SOLR_LOGS")") k8s_solr_view_logs; prompt_continue ;;
                        "$(i18n_message "BACK")") break ;;
                        *) log_error "$(i18n_message "ERROR_INVALID_CHOICE")"; prompt_continue ;;
                    esac
                done
                ;;
            "$(i18n_message "KUBECTL_PGSQL_COMMANDS")")
                while true; do
                    clear
                    print_header "$(i18n_message "KUBECTL_PGSQL_MENU_TITLE")"
                    local pgsql_options=(
                        "$(i18n_message "KUBECTL_LIST_PGSQL_PODS")"
                        "$(i18n_message "KUBECTL_ACCESS_PGSQL_CLI")"
                        "$(i18n_message "KUBECTL_VIEW_PGSQL_LOGS")"
                        "$(i18n_message "BACK")"
                    )
                    local pgsql_choice=$(display_menu "${pgsql_options[@]}")
                    case "${pgsql_choice}" in
                        "$(i18n_message "KUBECTL_LIST_PGSQL_PODS")") k8s_pgsql_list_pods; prompt_continue ;;
                        "$(i18n_message "KUBECTL_ACCESS_PGSQL_CLI")") k8s_pgsql_cli; prompt_continue ;;
                        "$(i18n_message "KUBECTL_VIEW_PGSQL_LOGS")") k8s_pgsql_view_logs; prompt_continue ;;
                        "$(i18n_message "BACK")") break ;;
                        *) log_error "$(i18n_message "ERROR_INVALID_CHOICE")"; prompt_continue ;;
                    esac
                done
                ;;
            "$(i18n_message "KUBECTL_COPY_FILES")")
                local local_src=$(prompt_input "$(i18n_message "KUBECTL_ENTER_LOCAL_SOURCE_PATH")" "")
                if [ -z "$local_src" ]; then log_warn "$(i18n_message "KUBECTL_PATH_EMPTY")"; prompt_continue; continue; fi
                local remote_dest=$(prompt_input "$(i18n_message "KUBECTL_ENTER_REMOTE_DEST_PATH")" "/tmp/")
                if [ -z "$remote_dest" ]; then log_warn "$(i18n_message "KUBECTL_PATH_EMPTY")"; prompt_continue; continue; fi
                kubectl_copy_to_pod "$local_src" "$remote_dest" "" "" "" # Prompt for pod/container/namespace
                prompt_continue
                ;;
            "$(i18n_message "BACK")")
                break
                ;;
            *)
                log_error "$(i18n_message "ERROR_INVALID_CHOICE")"
                prompt_continue
                ;;
        esac
    done
}
EOF

    # core/main.sh (main menu and logic)
    cat << 'EOF' > "${CORE_DIR}/main.sh"
#!/bin/bash

# AUB Tools - core/main.sh
# This is the main script that orchestrates the AUB Tools functionalities,
# presenting the interactive menu and routing to sub-modules.

# Source all helper functions first
source "${HELPERS_DIR}/config.sh"
source "${HELPERS_DIR}/log.sh"
source "${HELPERS_DIR}/menu.sh"
source "${HELPERS_DIR}/prompt.sh"
source "${HELPERS_DIR}/i18n.sh"
source "${HELPERS_DIR}/utils.sh"
source "${HELPERS_DIR}/history.sh"
source "${HELPERS_DIR}/favorites.sh"
source "${HELPERS_DIR}/report.sh"

# Source core functionalities
source "${CORE_DIR}/project.sh"
source "${CORE_DIR}/git.sh"
source "${CORE_DIR}/drush.sh"
source "${CORE_DIR}/composer.sh"
source "${CORE_DIR}/database.sh"
source "${CORE_DIR}/solr.sh"
source "${CORE_DIR}/ibmcloud.sh"
source "${CORE_DIR}/k8s.sh"

# --- Initialization ---

# Function to display the main header
print_header() {
    clear
    echo -e "${BLUE}-----------------------------------------------------${NC}"
    echo -e "${BLUE}        AUBAY DevTools 1.0                           ${NC}"
    echo -e "${BLUE}-----------------------------------------------------${NC}"
    echo ""
    echo -e "${YELLOW}  ${1}${NC}" # Display the provided title for the current menu
    echo ""
}

# Function to initialize AUB Tools
initialize_aub_tools() {
    log_info "$(i18n_message "INITIALIZING_AUB_TOOLS")"
    load_config # Load configuration settings
    init_i18n   # Initialize internationalization
    init_log    # Initialize logging
    log_level ${AUB_TOOLS_LOG_LEVEL} # Set log level from config
    detect_current_project_path # Try to detect project path at start
    log_debug "$(i18n_message "AUB_TOOLS_INITIALIZED")"
}

# --- Main Menu Logic ---
main_menu() {
    initialize_aub_tools

    while true; do
        print_header "$(i18n_message "MAIN_MENU_TITLE")"
        log_info "$(i18n_message "CURRENT_PROJECT_PATH" "${CURRENT_PROJECT_PATH:-$(i18n_message "NOT_DETECTED")}")"

        local options=(
            "$(i18n_message "PROJECT_MANAGEMENT_MENU_TITLE")"
            "$(i18n_message "GIT_MENU_TITLE")"
            "$(i18n_message "COMPOSER_MENU_TITLE")"
            "$(i18n_message "DRUSH_MENU_TITLE")"
            "$(i18n_message "IBMCLOUD_MENU_TITLE")"
            "$(i18n_message "KUBECTL_MENU_TITLE")"
            "$(i18n_message "AUB_TOOLS_SETTINGS")"
            "$(i18n_message "HISTORY_MENU_TITLE")"
            "$(i18n_message "FAVORITES_MENU_TITLE")"
            "$(i18n_message "EXIT")"
        )

        local choice=$(display_menu "${options[@]}")

        case "${choice}" in
            "$(i18n_message "PROJECT_MANAGEMENT_MENU_TITLE")")
                project_management_menu
                ;;
            "$(i18n_message "GIT_MENU_TITLE")")
                git_menu
                ;;
            "$(i18n_message "COMPOSER_MENU_TITLE")")
                composer_menu
                ;;
            "$(i18n_message "DRUSH_MENU_TITLE")")
                drush_menu
                ;;
            "$(i18n_message "IBMCLOUD_MENU_TITLE")")
                ibmcloud_menu
                ;;
            "$(i18n_message "KUBECTL_MENU_TITLE")")
                k8s_menu
                ;;
            "$(i18n_message "AUB_TOOLS_SETTINGS")")
                settings_menu
                ;;
            "$(i18n_message "HISTORY_MENU_TITLE")")
                if [[ "${AUB_TOOLS_ENABLE_HISTORY}" == "true" ]]; then
                    history_menu
                else
                    log_warn "$(i18n_message "FEATURE_DISABLED" "$(i18n_message "HISTORY_MENU_TITLE")")"
                    prompt_continue
                fi
                ;;
            "$(i18n_message "FAVORITES_MENU_TITLE")")
                if [[ "${AUB_TOOLS_ENABLE_FAVORITES}" == "true" ]]; then
                    favorites_menu
                else
                    log_warn "$(i18n_message "FEATURE_DISABLED" "$(i18n_message "FAVORITES_MENU_TITLE")")"
                    prompt_continue
                fi
                ;;
            "$(i18n_message "EXIT")")
                log_info "$(i18n_message "EXITING_AUB_TOOLS")"
                exit 0
                ;;
            *)
                log_error "$(i18n_message "ERROR_INVALID_CHOICE")"
                prompt_continue
                ;;
        esac
    done
}

# --- Settings Menu ---
settings_menu() {
    while true; do
        clear
        print_header "$(i18n_message "SETTINGS_MENU_TITLE")"

        local options=(
            "$(i18n_message "SETTING_LANGUAGE") (current: $(i18n_message "LANGUAGE_NAME"))"
            "$(i18n_message "SETTING_PROJECT_ROOT") (current: ${AUB_TOOLS_PROJECTS_ROOT_DIR:-$(i18n_message "NOT_SET")})"
            "$(i18n_message "SETTING_LOG_LEVEL") (current: ${AUB_TOOLS_LOG_LEVEL})"
            "$(i18n_message "SETTING_ENABLE_HISTORY") (current: ${AUB_TOOLS_ENABLE_HISTORY})"
            "$(i18n_message "SETTING_ENABLE_FAVORITES") (current: ${AUB_TOOLS_ENABLE_FAVORITES})"
            "$(i18n_message "SETTING_ENABLE_ERROR_REPORTING") (current: ${AUB_TOOLS_ENABLE_ERROR_REPORTING})"
            "$(i18n_message "SETTING_IBMCLOUD_CONFIG")"
            "$(i18n_message "BACK")"
        )
        local choice=$(display_menu "${options[@]}")

        case "${choice}" in
            "$(i18n_message "SETTING_LANGUAGE") ("*)
                local current_lang_code="${AUB_TOOLS_LANGUAGE:-$(locale | grep LANGUAGE | cut -d= -f2 | cut -d_ -f1)}"
                local lang_options=("fr_FR" "en_US")
                log_info "$(i18n_message "SELECT_LANGUAGE")"
                local new_lang=$(display_menu "${lang_options[@]}")
                if [ -n "$new_lang" ]; then
                    update_config "AUB_TOOLS_LANGUAGE" "$new_lang"
                    log_success "$(i18n_message "LANGUAGE_SET_SUCCESS" "$(i18n_message "LANGUAGE_NAME")")"
                    init_i18n # Reload messages
                else
                    log_warn "$(i18n_message "NO_LANGUAGE_SELECTED")"
                fi
                prompt_continue
                ;;
            "$(i18n_message "SETTING_PROJECT_ROOT") ("*)
                local new_path=$(prompt_input "$(i18n_message "ENTER_PROJECTS_ROOT_PATH")" "${AUB_TOOLS_PROJECTS_ROOT_DIR}")
                if [ -n "$new_path" ] && [ -d "$new_path" ]; then
                    update_config "AUB_TOOLS_PROJECTS_ROOT_DIR" "$new_path"
                    log_success "$(i18n_message "PROJECT_ROOT_SET_SUCCESS" "${new_path}")"
                else
                    log_error "$(i18n_message "INVALID_PATH_OR_EMPTY")"
                fi
                prompt_continue
                ;;
            "$(i18n_message "SETTING_LOG_LEVEL") ("*)
                local log_levels=("DEBUG" "INFO" "WARN" "ERROR" "SUCCESS")
                log_info "$(i18n_message "SELECT_LOG_LEVEL")"
                local new_level=$(display_menu "${log_levels[@]}")
                if [ -n "$new_level" ]; then
                    update_config "AUB_TOOLS_LOG_LEVEL" "$new_level"
                    log_level "$new_level" # Apply immediately
                    log_success "$(i18n_message "LOG_LEVEL_SET_SUCCESS" "${new_level}")"
                else
                    log_warn "$(i18n_message "NO_LOG_LEVEL_SELECTED")"
                fi
                prompt_continue
                ;;
            "$(i18n_message "SETTING_ENABLE_HISTORY") ("*)
                local options_bool=("true" "false")
                local current_status="${AUB_TOOLS_ENABLE_HISTORY:-false}"
                log_info "$(i18n_message "ENABLE_HISTORY_PROMPT" "${current_status}")"
                local choice_bool=$(display_menu "${options_bool[@]}")
                if [ -n "$choice_bool" ]; then
                    update_config "AUB_TOOLS_ENABLE_HISTORY" "$choice_bool"
                    log_success "$(i18n_message "SETTING_UPDATED_SUCCESS")"
                else
                    log_warn "$(i18n_message "NO_CHOICE_MADE")"
                fi
                prompt_continue
                ;;
            "$(i18n_message "SETTING_ENABLE_FAVORITES") ("*)
                local options_bool=("true" "false")
                local current_status="${AUB_TOOLS_ENABLE_FAVORITES:-false}"
                log_info "$(i18n_message "ENABLE_FAVORITES_PROMPT" "${current_status}")"
                local choice_bool=$(display_menu "${options_bool[@]}")
                if [ -n "$choice_bool" ]; then
                    update_config "AUB_TOOLS_ENABLE_FAVORITES" "$choice_bool"
                    log_success "$(i18n_message "SETTING_UPDATED_SUCCESS")"
                else
                    log_warn "$(i18n_message "NO_CHOICE_MADE")"
                fi
                prompt_continue
                ;;
            "$(i18n_message "SETTING_ENABLE_ERROR_REPORTING") ("*)
                local options_bool=("true" "false")
                local current_status="${AUB_TOOLS_ENABLE_ERROR_REPORTING:-true}"
                log_info "$(i18n_message "ENABLE_ERROR_REPORTING_PROMPT" "${current_status}")"
                local choice_bool=$(display_menu "${options_bool[@]}")
                if [ -n "$choice_bool" ]; then
                    update_config "AUB_TOOLS_ENABLE_ERROR_REPORTING" "$choice_bool"
                    log_success "$(i18n_message "SETTING_UPDATED_SUCCESS")"
                else
                    log_warn "$(i18n_message "NO_CHOICE_MADE")"
                fi
                prompt_continue
                ;;
            "$(i18n_message "SETTING_IBMCLOUD_CONFIG")")
                settings_ibmcloud_menu
                ;;
            "$(i18n_message "BACK")")
                break
                ;;
            *)
                log_error "$(i18n_message "ERROR_INVALID_CHOICE")"
                prompt_continue
                ;;
        esac
    done
}

# IBM Cloud specific settings menu
settings_ibmcloud_menu() {
    while true; do
        clear
        print_header "$(i18n_message "SETTINGS_IBMCLOUD_MENU_TITLE")"

        local options=(
            "$(i18n_message "SETTING_IBMCLOUD_REGION") (current: ${AUB_TOOLS_IBMCLOUD_REGION:-$(i18n_message "NOT_SET")})"
            "$(i18n_message "SETTING_IBMCLOUD_RESOURCE_GROUP") (current: ${AUB_TOOLS_IBMCLOUD_RESOURCE_GROUP:-$(i18n_message "NOT_SET")})"
            "$(i18n_message "SETTING_IBMCLOUD_ACCOUNT") (current: ${AUB_TOOLS_IBMCLOUD_ACCOUNT:-$(i18n_message "NOT_SET")})"
            "$(i18n_message "BACK")"
        )
        local choice=$(display_menu "${options[@]}")

        case "${choice}" in
            "$(i18n_message "SETTING_IBMCLOUD_REGION") ("*)
                local new_region=$(prompt_input "$(i18n_message "ENTER_IBMCLOUD_REGION")" "${AUB_TOOLS_IBMCLOUD_REGION}")
                if [ -n "$new_region" ]; then
                    update_config "AUB_TOOLS_IBMCLOUD_REGION" "$new_region"
                    log_success "$(i18n_message "SETTING_UPDATED_SUCCESS")"
                else
                    log_warn "$(i18n_message "NO_VALUE_ENTERED")"
                fi
                prompt_continue
                ;;
            "$(i18n_message "SETTING_IBMCLOUD_RESOURCE_GROUP") ("*)
                local new_rg=$(prompt_input "$(i18n_message "ENTER_IBMCLOUD_RESOURCE_GROUP")" "${AUB_TOOLS_IBMCLOUD_RESOURCE_GROUP}")
                if [ -n "$new_rg" ]; then
                    update_config "AUB_TOOLS_IBMCLOUD_RESOURCE_GROUP" "$new_rg"
                    log_success "$(i18n_message "SETTING_UPDATED_SUCCESS")"
                else
                    log_warn "$(i18n_message "NO_VALUE_ENTERED")"
                fi
                prompt_continue
                ;;
            "$(i18n_message "SETTING_IBMCLOUD_ACCOUNT") ("*)
                local new_account=$(prompt_input "$(i18n_message "ENTER_IBMCLOUD_ACCOUNT")" "${AUB_TOOLS_IBMCLOUD_ACCOUNT}")
                if [ -n "$new_account" ]; then
                    update_config "AUB_TOOLS_IBMCLOUD_ACCOUNT" "$new_account"
                    log_success "$(i18n_message "SETTING_UPDATED_SUCCESS")"
                else
                    log_warn "$(i18n_message "NO_VALUE_ENTERED")"
                fi
                prompt_continue
                ;;
            "$(i18n_message "BACK")")
                break
                ;;
            *)
                log_error "$(i18n_message "ERROR_INVALID_CHOICE")"
                prompt_continue
                ;;
        esac
    done
}


# Call the main menu function
# This is typically called from the 'bin/aub-tools' script
# main_menu
EOF

    # core/project.sh
    cat << 'EOF' > "${CORE_DIR}/project.sh"
#!/bin/bash

# AUB Tools - core/project.sh
# This script contains functions for general project management,
# including initialization, .env file generation, and path detection.

# Load helpers
source "${HELPERS_DIR}/log.sh"
source "${HELPERS_DIR}/menu.sh"
source "${HELPERS_DIR}/prompt.sh"
source "${HELPERS_DIR}/i18n.sh"
source "${HELPERS_DIR}/utils.sh"
source "${HELPERS_DIR}/config.sh"

# Global variable to store the current project path
CURRENT_PROJECT_PATH=""
# Global variable to store the Drupal root path within the project
CURRENT_DRUPAL_ROOT_PATH=""
# Global variable to store the project name
CURRENT_PROJECT_NAME=""

# Function to detect the current project's root path
# It searches upwards from the current directory for a .git folder or a src/composer.json
detect_current_project_path() {
    log_debug "$(i18n_message "PROJECT_DETECTING_PATH")"
    local current_dir="${PWD}"
    local max_depth=5 # Limit search depth to avoid infinite loops

    for ((i=0; i<max_depth; i++)); do
        if [ -d "${current_dir}/.git" ]; then
            CURRENT_PROJECT_PATH="${current_dir}"
            log_info "$(i18n_message "PROJECT_PATH_DETECTED" "${CURRENT_PROJECT_PATH}")"
            get_project_name_from_git "${CURRENT_PROJECT_PATH}"
            return 0
        fi
        if [ -f "${current_dir}/src/composer.json" ]; then
            CURRENT_PROJECT_PATH="${current_dir}"
            log_info "$(i18n_message "PROJECT_PATH_DETECTED_COMPOSER" "${CURRENT_PROJECT_PATH}")"
            get_project_name_from_git "${CURRENT_PROJECT_PATH}"
            return 0
        fi
        current_dir=$(dirname "${current_dir}")
        if [ "$current_dir" = "/" ]; then
            break
        fi
    done

    # If not found in current path, check AUB_TOOLS_PROJECTS_ROOT_DIR if set
    if [ -n "${AUB_TOOLS_PROJECTS_ROOT_DIR}" ] && [ -d "${AUB_TOOLS_PROJECTS_ROOT_DIR}" ]; then
        log_debug "$(i18n_message "PROJECT_SEARCHING_IN_CONFIG_ROOT" "${AUB_TOOLS_PROJECTS_ROOT_DIR}")"
        # Find directories with .git inside AUB_TOOLS_PROJECTS_ROOT_DIR
        local git_repos=$(find "${AUB_TOOLS_PROJECTS_ROOT_DIR}" -maxdepth 2 -type d -name ".git" | sed 's/\/.git$//')
        if [ -n "$git_repos" ]; then
            readarray -t project_paths < <(echo "$git_repos")
            if [ ${#project_paths[@]} -gt 0 ]; then
                log_info "$(i18n_message "PROJECT_SELECT_FROM_CONFIG_ROOT")"
                local selected_project_path=$(display_menu "${project_paths[@]}")
                if [ -n "$selected_project_path" ]; then
                    CURRENT_PROJECT_PATH="$selected_project_path"
                    log_info "$(i18n_message "PROJECT_PATH_SELECTED_FROM_CONFIG" "${CURRENT_PROJECT_PATH}")"
                    get_project_name_from_git "${CURRENT_PROJECT_PATH}"
                    return 0
                fi
            fi
        fi
    fi

    log_warn "$(i18n_message "PROJECT_PATH_NOT_DETECTED")"
    CURRENT_PROJECT_PATH=""
    CURRENT_PROJECT_NAME=""
    return 1
}

# Function to get the detected project path
get_current_project_path() {
    if [ -z "$CURRENT_PROJECT_PATH" ]; then
        detect_current_project_path
    fi
    echo "$CURRENT_PROJECT_PATH"
}

# Function to get the project name from the Git repository
get_project_name_from_git() {
    local repo_path="$1"
    if [ -d "${repo_path}/.git" ]; then
        # Get remote origin URL and extract name
        local remote_url=$(cd "${repo_path}" && git config --get remote.origin.url 2>/dev/null)
        if [ -n "$remote_url" ]; then
            # Extract name from URL (e.g., git@github.com:user/repo.git -> repo)
            CURRENT_PROJECT_NAME=$(basename "$remote_url" .git)
            log_debug "$(i18n_message "PROJECT_NAME_DETECTED" "${CURRENT_PROJECT_NAME}")"
            return 0
        else
            log_warn "$(i18n_message "PROJECT_NAME_NO_REMOTE_ORIGIN")"
        fi
    fi
    # Fallback to directory name if git name not found
    CURRENT_PROJECT_NAME=$(basename "$repo_path")
    log_warn "$(i18n_message "PROJECT_NAME_FALLBACK_TO_DIR" "${CURRENT_PROJECT_NAME}")"
    return 1
}

# Function to get the detected project name
get_current_project_name() {
    if [ -z "$CURRENT_PROJECT_NAME" ]; then
        get_project_name_from_git "$(get_current_project_path)"
    fi
    echo "$CURRENT_PROJECT_NAME"
}

# Function to detect the Drupal root path within the project
# Assumes the Drupal root is directly under 'src/' or in a subdirectory like 'src/web', 'src/docroot', etc.
detect_drupal_root_path() {
    log_debug "$(i18n_message "DRUPAL_DETECTING_ROOT")"
    local project_root=$(get_current_project_path)
    if [ -z "$project_root" ]; then
        log_error "$(i18n_message "ERROR_PROJECT_PATH_UNKNOWN")"
        CURRENT_DRUPAL_ROOT_PATH=""
        return 1
    fi

    local potential_drupal_roots=(
        "${project_root}/src/web"
        "${project_root}/src/docroot"
        "${project_root}/src/public"
        "${project_root}/src/html"
        "${project_root}/src" # Default fallback
    )

    for path in "${potential_drupal_roots[@]}"; do
        if [ -d "${path}/core" ] && [ -f "${path}/index.php" ]; then
            CURRENT_DRUPAL_ROOT_PATH="${path}"
            log_info "$(i18n_message "DRUPAL_ROOT_DETECTED" "${CURRENT_DRUPAL_ROOT_PATH}")"
            return 0
        fi
    done

    log_error "$(i18n_message "DRUPAL_ROOT_NOT_DETECTED" "${project_root}/src/")"
    CURRENT_DRUPAL_ROOT_PATH=""
    return 1
}

# Function to get the detected Drupal root path
get_drupal_root_path() {
    if [ -z "$CURRENT_DRUPAL_ROOT_PATH" ]; then
        detect_drupal_root_path
    fi
    echo "$CURRENT_DRUPAL_ROOT_PATH"
}

# Function to check if the current project is a Drupal project
is_current_project_drupal() {
    if [ -n "$(get_drupal_root_path)" ]; then
        return 0 # True
    else
        return 1 # False
    fi
}

# Function to initialize a new Drupal project (clone git, composer install)
project_init() {
    local repo_url=$(prompt_input "$(i18n_message "PROJECT_ENTER_GIT_REPO_URL")" "")
    if [ -z "$repo_url" ]; then
        log_warn "$(i18n_message "PROJECT_GIT_REPO_URL_EMPTY")"
        return 1
    fi

    local target_dir_name=$(basename "$repo_url" .git)
    local target_path="${AUB_TOOLS_PROJECTS_ROOT_DIR:-${HOME}/projects}/${target_dir_name}"

    # Allow user to override target directory
    local confirmed_target_path=$(prompt_input "$(i18n_message "PROJECT_ENTER_TARGET_DIRECTORY" "${target_path}")" "${target_path}")
    if [ -z "$confirmed_target_path" ]; then
        log_warn "$(i18n_message "PROJECT_TARGET_DIRECTORY_EMPTY")"
        return 1
    fi

    if [ -d "$confirmed_target_path" ]; then
        if ! prompt_confirm "$(i18n_message "PROJECT_TARGET_DIRECTORY_EXISTS_OVERWRITE" "${confirmed_target_path}")"; then
            log_info "$(i18n_message "PROJECT_INIT_CANCELLED")"
            return 1
        fi
    fi

    log_info "$(i18n_message "PROJECT_CLONING_REPO" "${repo_url}" "${confirmed_target_path}")"
    mkdir -p "$(dirname "${confirmed_target_path}")" # Ensure parent directory exists
    git clone "${repo_url}" "${confirmed_target_path}"
    local status=$?
    if [ $status -ne 0 ]; then
        log_error "$(i18n_message "PROJECT_CLONE_FAILED" "${repo_url}")"
        return 1
    fi
    log_success "$(i18n_message "PROJECT_CLONE_SUCCESS" "${confirmed_target_path}")"

    # Set the newly cloned project as the current project
    CURRENT_PROJECT_PATH="${confirmed_target_path}"
    get_project_name_from_git "${CURRENT_PROJECT_PATH}"
    detect_drupal_root_path

    # Generate .env file
    generate_env_file

    # Run composer install if composer.json exists
    if [ -f "${CURRENT_PROJECT_PATH}/composer.json" ]; then
        log_info "$(i18n_message "PROJECT_RUNNING_COMPOSER_INSTALL")"
        (cd "${CURRENT_PROJECT_PATH}" && composer install)
        if [ $? -eq 0 ]; then
            log_success "$(i18n_message "PROJECT_COMPOSER_INSTALL_SUCCESS")"
        else
            log_error "$(i18n_message "PROJECT_COMPOSER_INSTALL_FAILED")"
        fi
    else
        log_warn "$(i18n_message "PROJECT_COMPOSER_JSON_NOT_FOUND")"
    fi

    log_success "$(i18n_message "PROJECT_INITIALIZATION_COMPLETE")"
    return 0
}

# Function to generate .env file from .env.dist
generate_env_file() {
    local project_root=$(get_current_project_path)
    if [ -z "$project_root" ]; then
        log_error "$(i18n_message "ERROR_PROJECT_PATH_UNKNOWN")"
        return 1
    fi

    local env_dist_path="${project_root}/src/.env.dist" # Assuming .env.dist is in src/
    local env_path="${project_root}/src/.env"

    if [ ! -f "${env_dist_path}" ]; then
        log_warn "$(i18n_message "PROJECT_ENV_DIST_NOT_FOUND" "${env_dist_path}")"
        return 1
    fi

    if [ -f "${env_path}" ]; then
        if ! prompt_confirm "$(i18n_message "PROJECT_ENV_EXISTS_OVERWRITE" "${env_path}")"; then
            log_info "$(i18n_message "PROJECT_ENV_GENERATION_CANCELLED")"
            return 1
        fi
        rm -f "${env_path}"
    fi

    log_info "$(i18n_message "PROJECT_GENERATING_ENV" "${env_path}")"
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*# ]]; then
            # Keep commented lines as is
            echo "$line" >> "${env_path}"
        elif [[ "$line" =~ ^[[:space:]]*([A-Z0-9_]+)=([^#]*).* ]]; then
            local var_name="${BASH_REMATCH[1]}"
            local default_value="${BASH_REMATCH[2]}"
            # Remove leading/trailing whitespace from default_value
            default_value=$(echo "$default_value" | xargs)

            local current_value="${default_value}"
            # Check if variable is already defined in current shell env
            # This allows overriding with system env vars if desired, but we want user input for .env
            # local system_env_val=$(printenv "$var_name")
            # if [ -n "$system_env_val" ]; then
            #     current_value="$system_env_val"
            # fi

            local new_value=$(prompt_input "$(i18n_message "PROJECT_ENTER_VAR_VALUE" "${var_name}")" "$current_value")
            echo "${var_name}=${new_value}" >> "${env_path}"
        else
            # Keep empty lines or other non-variable lines
            echo "$line" >> "${env_path}"
        fi
    done < "${env_dist_path}"

    log_success "$(i18n_message "PROJECT_ENV_GENERATED_SUCCESS" "${env_path}")"
}

# Main Project Management menu
project_management_menu() {
    while true; do
        clear
        print_header "$(i18n_message "PROJECT_MANAGEMENT_MENU_TITLE")"
        log_info "$(i18n_message "CURRENT_PROJECT_PATH" "${CURRENT_PROJECT_PATH:-$(i18n_message "NOT_DETECTED")}")"
        log_info "$(i18n_message "CURRENT_DRUPAL_ROOT_PATH" "${CURRENT_DRUPAL_ROOT_PATH:-$(i18n_message "NOT_DETECTED")}")"
        log_info "$(i18n_message "CURRENT_PROJECT_NAME" "${CURRENT_PROJECT_NAME:-$(i18n_message "NOT_DETECTED")}")"

        local options=(
            "$(i18n_message "PROJECT_INITIALIZE_NEW")"
            "$(i18n_message "PROJECT_RE_DETECT_PATH")"
            "$(i18n_message "PROJECT_GENERATE_ENV")"
            "$(i18n_message "BACK")"
        )
        local choice=$(display_menu "${options[@]}")

        case "${choice}" in
            "$(i18n_message "PROJECT_INITIALIZE_NEW")")
                project_init
                prompt_continue
                ;;
            "$(i18n_message "PROJECT_RE_DETECT_PATH")")
                detect_current_project_path
                detect_drupal_root_path
                prompt_continue
                ;;
            "$(i18n_message "PROJECT_GENERATE_ENV")")
                generate_env_file
                prompt_continue
                ;;
            "$(i18n_message "BACK")")
                break
                ;;
            *)
                log_error "$(i18n_message "ERROR_INVALID_CHOICE")"
                prompt_continue
                ;;
        esac
    done
}
EOF

    # core/solr.sh
    cat << 'EOF' > "${CORE_DIR}/solr.sh"
#!/bin/bash

# AUB Tools - core/solr.sh
# This script contains functions for Search API Solr management in Drupal.

# Load helpers
source "${HELPERS_DIR}/log.sh"
source "${HELPERS_DIR}/menu.sh"
source "${HELPERS_DIR}/prompt.sh"
source "${HELPERS_DIR}/i18n.sh"
source "${HELPERS_DIR}/utils.sh"
source "${HELPERS_DIR}/config.sh"
source "${CORE_DIR}/drush.sh" # Needed for drush_run_command

# Default directory for exporting Solr configurations
SOLR_CONFIGS_EXPORT_DIR="${INSTALL_DIR}/solr_configs"

# Function to list Search API Solr servers
drush_solr_server_list() {
    local target=$(get_drush_target_for_command)
    if [ -z "$target" ]; then return 1; fi
    drush_run_command "${target}" "search-api:server-list"
}

# Function to list Search API Solr indexes
drush_solr_index_list() {
    local target=$(get_drush_target_for_command)
    if [ -z "$target" ]; then return 1; fi
    drush_run_command "${target}" "search-api:index-list"
}

# Function to export Solr configurations
# Arguments:
#   $1 - Optional: Server ID to export. If empty, user will be prompted.
#   $2 - Optional: Target directory for export. Defaults to SOLR_CONFIGS_EXPORT_DIR.
drush_solr_export_config() {
    local server_id="$1"
    local export_dir="${2:-${SOLR_CONFIGS_EXPORT_DIR}}"
    local target=$(get_drush_target_for_command)
    if [ -z "$target" ]; then return 1; fi

    if [ -z "$server_id" ]; then
        log_info "$(i18n_message "SOLR_SELECT_SERVER_TO_EXPORT")"
        local servers_json=$(drush_run_command "${target}" "search-api:server-list --format=json" 2>/dev/null)
        readarray -t server_ids < <(echo "${servers_json}" | jq -r 'keys[]' 2>/dev/null)

        if [ ${#server_ids[@]} -eq 0 ]; then
            log_warn "$(i18n_message "SOLR_NO_SERVERS_FOUND")"
            return 1
        fi
        server_id=$(display_menu "${server_ids[@]}")
    fi

    if [ -z "$server_id" ]; then
        log_warn "$(i18n_message "SOLR_NO_SERVER_SELECTED")"
        return 1
    fi

    log_info "$(i18n_message "SOLR_EXPORTING_CONFIG" "${server_id}" "${export_dir}")"
    mkdir -p "${export_dir}"
    drush_run_command "${target}" "search-api-solr:export-solr-config ${server_id} --destination=\"${export_dir}\""
    local status=$?
    if [ $status -eq 0 ]; then
        log_success "$(i18n_message "SOLR_EXPORT_CONFIG_SUCCESS" "${export_dir}")"
    else
        log_error "$(i18n_message "SOLR_EXPORT_CONFIG_FAILED")"
    fi
    return $status
}

# Function to index Solr data
# Arguments:
#   $1 - Optional: Index ID. If empty, user will be prompted.
drush_solr_index() {
    local index_id="$1"
    local target=$(get_drush_target_for_command)
    if [ -z "$target" ]; then return 1; fi

    if [ -z "$index_id" ]; then
        log_info "$(i18n_message "SOLR_SELECT_INDEX_TO_INDEX")"
        local indexes_json=$(drush_run_command "${target}" "search-api:index-list --format=json" 2>/dev/null)
        readarray -t index_ids < <(echo "${indexes_json}" | jq -r 'keys[]' 2>/dev/null)

        if [ ${#index_ids[@]} -eq 0 ]; then
            log_warn "$(i18n_message "SOLR_NO_INDEXES_FOUND")"
            return 1
        fi
        index_id=$(display_menu "${index_ids[@]}")
    fi

    if [ -z "$index_id" ]; then
        log_warn "$(i18n_message "SOLR_NO_INDEX_SELECTED")"
        return 1
    fi

    log_info "$(i18n_message "SOLR_INDEXING" "${index_id}")"
    drush_run_command "${target}" "search-api:index ${index_id}"
    local status=$?
    if [ $status -eq 0 ]; then
        log_success "$(i18n_message "SOLR_INDEX_SUCCESS")"
    else
        log_error "$(i18n_message "SOLR_INDEX_FAILED")"
    fi
    return $status
}

# Function to clear Solr index
# Arguments:
#   $1 - Optional: Index ID. If empty, user will be prompted.
drush_solr_clear() {
    local index_id="$1"
    local target=$(get_drush_target_for_command)
    if [ -z "$target" ]; then return 1; fi

    if [ -z "$index_id" ]; then
        log_info "$(i18n_message "SOLR_SELECT_INDEX_TO_CLEAR")"
        local indexes_json=$(drush_run_command "${target}" "search-api:index-list --format=json" 2>/dev/null)
        readarray -t index_ids < <(echo "${indexes_json}" | jq -r 'keys[]' 2>/dev/null)

        if [ ${#index_ids[@]} -eq 0 ]; then
            log_warn "$(i18n_message "SOLR_NO_INDEXES_FOUND")"
            return 1
        fi
        index_id=$(display_menu "${index_ids[@]}")
    fi

    if [ -z "$index_id" ]; then
        log_warn "$(i18n_message "SOLR_NO_INDEX_SELECTED")"
        return 1
    fi

    if prompt_confirm "$(i18n_message "SOLR_CONFIRM_CLEAR_INDEX" "${index_id}")"; then
        log_info "$(i18n_message "SOLR_CLEARING_INDEX" "${index_id}")"
        drush_run_command "${target}" "search-api:clear ${index_id}"
        local status=$?
        if [ $status -eq 0 ]; then
            log_success "$(i18n_message "SOLR_CLEAR_SUCCESS")"
        else
            log_error "$(i18n_message "SOLR_CLEAR_FAILED")"
        fi
    else
        log_info "$(i18n_message "SOLR_CLEAR_CANCELLED")"
    fi
    return $status
}

# Function to check Solr status
drush_solr_status() {
    local target=$(get_drush_target_for_command)
    if [ -z "$target" ]; then return 1; fi
    drush_run_command "${target}" "search-api:status"
}

# Main Solr menu (called from drush.sh)
solr_menu() {
    while true; do
        clear
        print_header "$(i18n_message "DRUSH_SEARCH_API_SOLR_COMMANDS")"
        log_info "$(i18n_message "CURRENT_DRUSH_TARGET" "${CURRENT_DRUSH_TARGET}")"

        local options=(
            "$(i18n_message "SOLR_SERVER_LIST")"
            "$(i18n_message "SOLR_INDEX_LIST")"
            "$(i18n_message "SOLR_EXPORT_CONFIG")"
            "$(i18n_message "SOLR_INDEX_CONTENT")"
            "$(i18n_message "SOLR_CLEAR_INDEX")"
            "$(i18n_message "SOLR_STATUS")"
            "$(i18n_message "DRUSH_SELECT_TARGET")"
            "$(i18n_message "BACK")"
        )
        local choice=$(display_menu "${options[@]}")

        case "${choice}" in
            "$(i18n_message "SOLR_SERVER_LIST")")
                drush_solr_server_list
                prompt_continue
                ;;
            "$(i18n_message "SOLR_INDEX_LIST")")
                drush_solr_index_list
                prompt_continue
                ;;
            "$(i18n_message "SOLR_EXPORT_CONFIG")")
                drush_solr_export_config
                prompt_continue
                ;;
            "$(i18n_message "SOLR_INDEX_CONTENT")")
                drush_solr_index
                prompt_continue
                ;;
            "$(i18n_message "SOLR_CLEAR_INDEX")")
                drush_solr_clear
                prompt_continue
                ;;
            "$(i18n_message "SOLR_STATUS")")
                drush_solr_status
                prompt_continue
                ;;
            "$(i18n_message "DRUSH_SELECT_TARGET")")
                select_drush_target
                ;;
            "$(i18n_message "BACK")")
                break
                ;;
            *)
                log_error "$(i18n_message "ERROR_INVALID_CHOICE")"
                prompt_continue
                ;;
        esac
    done
}
EOF

    install_log "SUCCESS" "Core script files created."
}

# --- Create helper files ---
create_helper_files() {
    install_log "INFO" "Creating helper script files..."

    # helpers/config.sh
    cat << 'EOF' > "${HELPERS_DIR}/config.sh"
#!/bin/bash

# AUB Tools - helpers/config.sh
# This script manages the configuration settings for AUB Tools.

# Configuration file path
CONFIG_FILE="${INSTALL_DIR}/aub-tools.conf"

# Default settings
AUB_TOOLS_LANGUAGE="en_US" # Default language
AUB_TOOLS_PROJECTS_ROOT_DIR="${HOME}/projects" # Default project root directory
AUB_TOOLS_LOG_LEVEL="INFO" # Default logging level (DEBUG, INFO, WARN, ERROR, SUCCESS)
AUB_TOOLS_ENABLE_HISTORY="true" # Enable command history by default
AUB_TOOLS_ENABLE_FAVORITES="true" # Enable favorites by default
AUB_TOOLS_ENABLE_ERROR_REPORTING="true" # Enable error reporting by default

# IBM Cloud specific defaults (can be prompted and saved by user)
AUB_TOOLS_IBMCLOUD_REGION=""
AUB_TOOLS_IBMCLOUD_RESOURCE_GROUP=""
AUB_TOOLS_IBMCLOUD_ACCOUNT=""

# Function to load configuration from file
load_config() {
    if [ -f "${CONFIG_FILE}" ]; then
        log_debug "Loading configuration from ${CONFIG_FILE}"
        source "${CONFIG_FILE}"
        log_debug "Configuration loaded."
    else
        log_warn "Configuration file not found: ${CONFIG_FILE}. Using default settings."
        # Create a default config file if it doesn't exist
        save_config
    fi
}

# Function to save configuration to file
save_config() {
    log_debug "Saving configuration to ${CONFIG_FILE}"
    {
        echo "# AUB Tools Configuration File"
        echo "# Generated on $(date)"
        echo "INSTALL_DIR=\"${INSTALL_DIR}\"" # Store INSTALL_DIR for persistent use

        echo "AUB_TOOLS_LANGUAGE=\"${AUB_TOOLS_LANGUAGE}\""
        echo "AUB_TOOLS_PROJECTS_ROOT_DIR=\"${AUB_TOOLS_PROJECTS_ROOT_DIR}\""
        echo "AUB_TOOLS_LOG_LEVEL=\"${AUB_TOOLS_LOG_LEVEL}\""
        echo "AUB_TOOLS_ENABLE_HISTORY=\"${AUB_TOOLS_ENABLE_HISTORY}\""
        echo "AUB_TOOLS_ENABLE_FAVORITES=\"${AUB_TOOLS_ENABLE_FAVORITES}\""
        echo "AUB_TOOLS_ENABLE_ERROR_REPORTING=\"${AUB_TOOLS_ENABLE_ERROR_REPORTING}\""
        echo "AUB_TOOLS_IBMCLOUD_REGION=\"${AUB_TOOLS_IBMCLOUD_REGION}\""
        echo "AUB_TOOLS_IBMCLOUD_RESOURCE_GROUP=\"${AUB_TOOLS_IBMCLOUD_RESOURCE_GROUP}\""
        echo "AUB_TOOLS_IBMCLOUD_ACCOUNT=\"${AUB_TOOLS_IBMCLOUD_ACCOUNT}\""
    } > "${CONFIG_FILE}"
    log_debug "Configuration saved."
}

# Function to update a specific configuration variable
# Arguments:
#   $1 - Variable name (e.g., AUB_TOOLS_LANGUAGE)
#   $2 - New value
update_config() {
    local var_name="$1"
    local new_value="$2"

    # Use declare -g to ensure global scope if variable not yet defined
    declare -g "$var_name=$new_value"
    log_debug "Updated config: ${var_name}=\"${new_value}\""
    save_config
}
EOF

    # helpers/favorites.sh
    cat << 'EOF' > "${HELPERS_DIR}/favorites.sh"
#!/bin/bash

# AUB Tools - helpers/favorites.sh
# This script manages user-defined favorite commands/shortcuts.

# Path to the favorites file
FAVORITES_FILE="${HOME}/.aub-tools_favorites.sh"

# Function to initialize the favorites file if it doesn't exist
init_favorites() {
    if [[ "${AUB_TOOLS_ENABLE_FAVORITES}" != "true" ]]; then
        return 0 # Do nothing if feature is disabled
    fi

    if [ ! -f "${FAVORITES_FILE}" ]; then
        log_info "$(i18n_message "FAVORITES_CREATING_FILE" "${FAVORITES_FILE}")"
        cat << 'EOL' > "${FAVORITES_FILE}"
# AUB Tools Favorites / Shortcuts
# Add your custom Bash functions or aliases here.
# These will be loaded and available in the 'Favorites' menu.
# Example:
# my_custom_command() {
#     echo "Hello from my custom command!"
#     ls -la
# }
#
# another_drush_shortcut() {
#    drush @self cron
# }
EOL
        log_success "$(i18n_message "FAVORITES_FILE_CREATED")"
    fi
}

# Function to list available favorites
list_favorites() {
    if [[ "${AUB_TOOLS_ENABLE_FAVORITES}" != "true" ]]; then
        log_warn "$(i18n_message "FEATURE_DISABLED" "$(i18n_message "FAVORITES_MENU_TITLE")")"
        return 1
    fi

    init_favorites # Ensure the file exists

    local favorites=()
    # Source the favorites file to make functions available for inspection
    source "${FAVORITES_FILE}" >/dev/null 2>&1

    # Find all functions defined in the favorites file
    # This is a bit tricky, but we can list all functions and filter by source file
    # A simpler approach: assume functions are defined on their own lines.
    # We'll just read function names from the file.
    # Limitation: This won't work for aliases or complex definitions spanning multiple lines.
    # For robust parsing, more advanced tools like awk or sed would be needed.

    # This approach gets defined functions and checks if they are in the favorites file
    # This might list functions defined elsewhere if sourced globally
    # Better: just grep for function definitions in the file
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z0-9_]+)[[:space:]]*\(\)[[:space:]]*\{ ]]; then
            local func_name="${BASH_REMATCH[1]}"
            favorites+=("${func_name}")
        fi
    done < "${FAVORITES_FILE}"

    if [ ${#favorites[@]} -eq 0 ]; then
        log_info "$(i18n_message "FAVORITES_NO_FAVORITES_FOUND")"
        return 1
    fi

    echo "${favorites[@]}"
    return 0
}

# Function to run a selected favorite
run_favorite() {
    local favorite_name="$1"
    if [[ -z "$favorite_name" ]]; then
        log_warn "$(i18n_message "FAVORITES_NO_FAVORITE_SELECTED")"
        return 1
    fi

    if [[ "${AUB_TOOLS_ENABLE_FAVORITES}" != "true" ]]; then
        log_warn "$(i18n_message "FEATURE_DISABLED" "$(i18n_message "FAVORITES_MENU_TITLE")")"
        return 1
    fi

    # Source the favorites file to make the function available in the current shell
    source "${FAVORITES_FILE}"
    if type -t "$favorite_name" | grep -q 'function'; then
        log_info "$(i18n_message "FAVORITES_RUNNING" "${favorite_name}")"
        "$favorite_name"
        local status=$?
        if [ $status -eq 0 ]; then
            log_success "$(i18n_message "FAVORITES_RUN_SUCCESS")"
        else
            log_error "$(i18n_message "FAVORITES_RUN_FAILED")"
        fi
        return $status
    else
        log_error "$(i18n_message "FAVORITES_NOT_A_FUNCTION" "${favorite_name}")"
        return 1
    fi
}

# Main Favorites menu
favorites_menu() {
    if [[ "${AUB_TOOLS_ENABLE_FAVORITES}" != "true" ]]; then
        log_warn "$(i18n_message "FEATURE_DISABLED" "$(i18n_message "FAVORITES_MENU_TITLE")")"
        prompt_continue
        return
    fi

    init_favorites # Ensure the file exists

    while true; do
        clear
        print_header "$(i18n_message "FAVORITES_MENU_TITLE")"
        log_info "$(i18n_message "FAVORITES_FILE_LOCATION" "${FAVORITES_FILE}")"

        local available_favorites=($(list_favorites))
        if [ ${#available_favorites[@]} -eq 0 ]; then
            log_info "$(i18n_message "FAVORITES_NO_FAVORITES_TO_SHOW")"
            prompt_continue
            break
        fi

        log_info "$(i18n_message "FAVORITES_SELECT_TO_RUN")"
        local options=("${available_favorites[@]}" "$(i18n_message "BACK")")
        local choice=$(display_menu "${options[@]}")

        case "${choice}" in
            "$(i18n_message "BACK")")
                break
                ;;
            "") # No choice made
                log_warn "$(i18n_message "FAVORITES_NO_SELECTION")"
                prompt_continue
                ;;
            *)
                run_favorite "${choice}"
                prompt_continue
                ;;
        esac
    done
}
EOF

    # helpers/history.sh
    cat << 'EOF' > "${HELPERS_DIR}/history.sh"
#!/bin/bash

# AUB Tools - helpers/history.sh
# This script manages the command history for AUB Tools.

# Path to the history file
HISTORY_FILE="${HOME}/.aub-tools_history"
MAX_HISTORY_SIZE=100 # Maximum number of entries in history

# Function to add an action to history
# Arguments:
#   $1 - The action string to record
add_to_history() {
    if [[ "${AUB_TOOLS_ENABLE_HISTORY}" != "true" ]]; then
        return 0 # Do nothing if history is disabled
    fi

    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local entry="[${timestamp}] $1"

    # Add new entry to the top of the file
    echo "${entry}" | cat - "${HISTORY_FILE}" > "${HISTORY_FILE}.tmp" && mv "${HISTORY_FILE}.tmp" "${HISTORY_FILE}"

    # Trim history file to MAX_HISTORY_SIZE
    local line_count=$(wc -l < "${HISTORY_FILE}")
    if [ "$line_count" -gt "$MAX_HISTORY_SIZE" ]; then
        tail -n "${MAX_HISTORY_SIZE}" "${HISTORY_FILE}" > "${HISTORY_FILE}.tmp" && mv "${HISTORY_FILE}.tmp" "${HISTORY_FILE}"
    fi
    log_debug "$(i18n_message "HISTORY_ADDED_ENTRY")"
}

# Function to display history
display_history() {
    if [[ "${AUB_TOOLS_ENABLE_HISTORY}" != "true" ]]; then
        log_warn "$(i18n_message "FEATURE_DISABLED" "$(i18n_message "HISTORY_MENU_TITLE")")"
        return 1
    fi

    if [ ! -f "${HISTORY_FILE}" ] || [ ! -s "${HISTORY_FILE}" ]; then
        log_info "$(i18n_message "HISTORY_EMPTY")"
        return 1
    fi

    log_info "$(i18n_message "HISTORY_RECENT_ACTIONS")"
    cat "${HISTORY_FILE}"
    return 0
}

# Function to run a historical command (by index)
# Arguments:
#   $1 - The history index to run (1-based)
run_history_command() {
    if [[ "${AUB_TOOLS_ENABLE_HISTORY}" != "true" ]]; then
        log_warn "$(i18n_message "FEATURE_DISABLED" "$(i18n_message "HISTORY_MENU_TITLE")")"
        return 1
    fi

    local index="$1"
    if [ -z "$index" ] || ! [[ "$index" =~ ^[0-9]+$ ]]; then
        log_error "$(i18n_message "HISTORY_INVALID_INDEX")"
        return 1
    fi

    if [ ! -f "${HISTORY_FILE}" ] || [ ! -s "${HISTORY_FILE}" ]; then
        log_info "$(i18n_message "HISTORY_EMPTY")"
        return 1
    fi

    # Read the command from the history file (strip timestamp)
    local command_to_run=$(sed -n "${index}p" "${HISTORY_FILE}" | sed -E 's/^\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\] (.*)/\1/')

    if [ -z "$command_to_run" ]; then
        log_error "$(i18n_message "HISTORY_COMMAND_NOT_FOUND_AT_INDEX" "${index}")"
        return 1
    fi

    log_info "$(i18n_message "HISTORY_RELAUNCHING_COMMAND" "${command_to_run}")"
    # Execute the command. Be careful with 'eval' as it's powerful.
    # For this purpose, assuming the stored commands are safe, it's acceptable.
    eval "$command_to_run"
    local status=$?
    if [ $status -eq 0 ]; then
        log_success "$(i18n_message "HISTORY_COMMAND_RELAUNCH_SUCCESS")"
    else
        log_error "$(i18n_message "HISTORY_COMMAND_RELAUNCH_FAILED")"
    fi
    return $status
}

# Main History menu
history_menu() {
    if [[ "${AUB_TOOLS_ENABLE_HISTORY}" != "true" ]]; then
        log_warn "$(i18n_message "FEATURE_DISABLED" "$(i18n_message "HISTORY_MENU_TITLE")")"
        prompt_continue
        return
    fi

    while true; do
        clear
        print_header "$(i18n_message "HISTORY_MENU_TITLE")"
        log_info "$(i18n_message "HISTORY_FILE_LOCATION" "${HISTORY_FILE}")"

        local history_entries=()
        if [ -f "${HISTORY_FILE}" ] && [ -s "${HISTORY_FILE}" ]; then
            readarray -t history_entries < "${HISTORY_FILE}"
        fi

        if [ ${#history_entries[@]} -eq 0 ]; then
            log_info "$(i18n_message "HISTORY_EMPTY")"
            prompt_continue
            break
        fi

        log_info "$(i18n_message "HISTORY_SELECT_TO_RELAUNCH")"
        # Prepend numbers for easier selection
        local numbered_options=()
        for i in "${!history_entries[@]}"; do
            numbered_options+=("$((${i}+1)). ${history_entries[$i]}")
        done

        local options=("${numbered_options[@]}" "$(i18n_message "BACK")")
        local choice_text=$(display_menu "${options[@]}")

        case "${choice_text}" in
            "$(i18n_message "BACK")")
                break
                ;;
            "") # No choice made
                log_warn "$(i18n_message "HISTORY_NO_SELECTION")"
                prompt_continue
                ;;
            *)
                local selected_index=$(echo "$choice_text" | cut -d'.' -f1)
                run_history_command "${selected_index}"
                prompt_continue
                ;;
        esac
    done
}
EOF

    # helpers/i18n.sh
    cat << 'EOF' > "${HELPERS_DIR}/i18n.sh"
#!/bin/bash

# AUB Tools - helpers/i18n.sh
# This script handles internationalization (i18n) for AUB Tools.

# Global associative array for messages
declare -A MESSAGES

# Function to load messages for the specified language
# Arguments:
#   $1 - Language code (e.g., "en_US", "fr_FR")
load_messages() {
    local lang_code="$1"
    local lang_file="${LANG_DIR}/${lang_code}/messages.sh"

    if [ -f "${lang_file}" ]; then
        log_debug "Loading messages for language: ${lang_code} from ${lang_file}"
        source "${lang_file}"
        # Populate MESSAGES array from the _messages_ associative array defined in the lang file
        for key in "${!_messages_[@]}"; do
            MESSAGES["$key"]="${_messages_[$key]}"
        done
        log_debug "Messages loaded for ${lang_code}."
    else
        log_error "Language file not found: ${lang_file}. Falling back to default English."
        # If the requested language file is not found, try loading English
        if [ "${lang_code}" != "en_US" ]; then
            load_messages "en_US"
        else
            log_error "Default English language file not found. Translations will not work."
        fi
    fi
}

# Function to get a translated message
# Arguments:
#   $1 - The technical key for the message (e.g., "HELLO_WORLD")
#   $@ - Additional arguments to substitute into the message (printf style)
i18n_message() {
    local key="$1"
    shift
    local message="${MESSAGES[$key]}"

    if [ -z "$message" ]; then
        # Fallback to English if message not found in current language
        message=$(get_english_message "$key")
        if [ -z "$message" ]; then
             echo "MISSING_TRANSLATION_KEY: ${key}" >&2
             return 1
        fi
    fi

    # Use printf to substitute arguments into the message
    printf "${message}" "$@"
}

# Function to get a message from the English translation file as a fallback
get_english_message() {
    local key="$1"
    local en_lang_file="${LANG_DIR}/en_US/messages.sh"
    local temp_messages_array
    declare -A temp_messages_array

    if [ -f "${en_lang_file}" ]; then
        # Source temporarily to get the English message without affecting current MESSAGES
        local _messages_ # Local scope to prevent collision
        source "${en_lang_file}"
        echo "${_messages_[$key]}"
    fi
}

# Function to initialize i18n: detect system language or use configured language
init_i18n() {
    local desired_lang="${AUB_TOOLS_LANGUAGE}"

    if [ -z "$desired_lang" ]; then
        # Auto-detect system language
        local system_lang=$(locale | grep LANGUAGE | cut -d= -f2 | cut -d_ -f1)
        if [ -n "$system_lang" ]; then
            log_debug "System language detected: ${system_lang}"
            case "${system_lang}" in
                fr) desired_lang="fr_FR" ;;
                en) desired_lang="en_US" ;;
                *)  desired_lang="en_US" # Default to English if system lang not supported
                    log_warn "Unsupported system language '${system_lang}'. Defaulting to en_US."
                    ;;
            esac
        else
            desired_lang="en_US"
            log_warn "Could not detect system language. Defaulting to en_US."
        fi
        AUB_TOOLS_LANGUAGE="$desired_lang" # Update global config variable
        # Don't save here, let main config saving handle it
    fi

    load_messages "${desired_lang}"
}

# Function to return the current language's name (for display in settings)
i18n_language_name() {
    case "${AUB_TOOLS_LANGUAGE}" in
        "fr_FR") i18n_message "LANGUAGE_FRENCH" ;;
        "en_US") i18n_message "LANGUAGE_ENGLISH" ;;
        *) echo "${AUB_TOOLS_LANGUAGE}" ;;
    esac
}
EOF

    # helpers/log.sh
    cat << 'EOF' > "${HELPERS_DIR}/log.sh"
#!/bin/bash

# AUB Tools - helpers/log.sh
# This script provides logging functionalities for AUB Tools.

# Log file path
LOG_FILE="${TEMP_DIR}/aub-tools.log"

# Log levels mapping (higher number = more severe)
declare -A LOG_LEVELS_MAP
LOG_LEVELS_MAP["DEBUG"]=0
LOG_LEVELS_MAP["INFO"]=1
LOG_LEVELS_MAP["WARN"]=2
LOG_LEVELS_MAP["ERROR"]=3
LOG_LEVELS_MAP["SUCCESS"]=4

# Current effective log level (default to INFO if not set by config.sh)
CURRENT_LOG_LEVEL_NUM=${LOG_LEVELS_MAP["${AUB_TOOLS_LOG_LEVEL:-INFO}"]}

# --- Colors for console output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to initialize the log file
init_log() {
    # Ensure log directory exists
    mkdir -p "$(dirname "${LOG_FILE}")"
    # Create or clear log file
    # echo "# AUB Tools Log - $(date)" > "${LOG_FILE}" # Don't clear on every run, append
    touch "${LOG_FILE}" # Ensure file exists
}

# Function to set the current logging level
# Arguments:
#   $1 - The desired log level (DEBUG, INFO, WARN, ERROR, SUCCESS)
log_level() {
    local level_name="$1"
    if [ -n "${LOG_LEVELS_MAP[$level_name]}" ]; then
        CURRENT_LOG_LEVEL_NUM="${LOG_LEVELS_MAP[$level_name]}"
        log_debug "Log level set to ${level_name} (${CURRENT_LOG_LEVEL_NUM})."
    else
        log_warn "Invalid log level: ${level_name}. Keeping current level."
    fi
}

# Generic logging function
# Arguments:
#   $1 - Log level (DEBUG, INFO, WARN, ERROR, SUCCESS)
#   $2 - Message to log
log_message() {
    local level_name="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local level_num=${LOG_LEVELS_MAP[$level_name]:-1} # Default to INFO if invalid level provided

    # Console output with colors
    local color=""
    case "${level_name}" in
        "DEBUG") color="${CYAN}" ;;
        "INFO")  color="${BLUE}" ;;
        "WARN")  color="${YELLOW}" ;;
        "ERROR") color="${RED}" ;;
        "SUCCESS") color="${GREEN}" ;;
        *)       color="${NC}" ;;
    esac

    if [ "$level_num" -ge "$CURRENT_LOG_LEVEL_NUM" ]; then
        echo -e "${color}[${level_name}]${NC} [${timestamp}] ${message}"
    fi

    # File output (always plain text, log all levels for debugging potential)
    echo "[${level_name}] [${timestamp}] ${message}" >> "${LOG_FILE}"
}

# Convenience functions for specific log levels
log_debug() {
    log_message "DEBUG" "$1"
}

log_info() {
    log_message "INFO" "$1"
}

log_warn() {
    log_message "WARN" "$1"
}

log_error() {
    log_message "ERROR" "$1"
    # If error reporting is enabled, offer to generate a report
    if [[ "${AUB_TOOLS_ENABLE_ERROR_REPORTING}" == "true" ]]; then
        generate_error_report "$1"
    fi
}

log_success() {
    log_message "SUCCESS" "$1"
}

# Set a trap to catch errors and log them
trap_error_handler() {
    local last_command="${BASH_COMMAND}"
    local line_number="${BASH_LINENO[0]}"
    local script_name="${BASH_SOURCE[1]}" # Get the script where the error occurred

    # Avoid logging internal trap errors
    if [[ "$last_command" == "log_error \"$(i18n_message \"ERROR_UNEXPECTED\")"\"* ]]; then
        return
    fi
    if [[ "$last_command" == *generate_error_report* ]]; then
        return
    fi

    log_error "$(i18n_message "ERROR_UNEXPECTED" "${script_name}:${line_number}" "${last_command}")"
}

# Set the trap. This must be done after functions are defined.
# If AUB_TOOLS_ENABLE_ERROR_REPORTING is not 'true', this trap won't be set.
# This relies on the 'init_log' being called early in main.sh, which it is.
# The trap is set in bin/aub-tools to cover the whole execution.
# trap 'trap_error_handler' ERR
EOF

    # helpers/menu.sh
    cat << 'EOF' > "${HELPERS_DIR}/menu.sh"
#!/bin/bash

# AUB Tools - helpers/menu.sh
# This script provides functions for creating interactive menus.

# Requires 'jq' for certain operations, which is managed by install.sh.
# Make sure jq is in PATH or specify its full path if needed.
JQ_PATH="${BIN_DIR}/jq" # Defined in config.sh, ensure it's loaded in main.sh or bin/aub-tools

# Function to display an interactive menu using arrow keys and Enter
# Arguments:
#   $@ - List of menu options
# Returns the selected option
display_menu() {
    local options=("$@")
    local selected_idx=0
    local key_input=""
    local num_options=${#options[@]}

    # Ensure terminal is in raw mode to capture arrow keys
    # Use stty -echo to hide input and stty raw to read char by char
    # Temporarily save and restore terminal settings
    local old_stty_settings=$(stty -g)
    stty raw -echo

    # Cleanup function to restore terminal settings on exit or interruption
    local cleanup_terminal_settings_on_exit() {
        stty "${old_stty_settings}"
    }
    trap cleanup_terminal_settings_on_exit EXIT SIGINT SIGTERM

    while true; do
        clear # Clear screen for fresh menu
        print_header "${MENU_TITLE:-Menu}" # Use a placeholder if not set
        echo ""
        log_info "$(i18n_message "MENU_INSTRUCTIONS")"
        echo ""

        for i in "${!options[@]}"; do
            if [ "$i" -eq "$selected_idx" ]; then
                echo -e "${GREEN}> ${options[$i]}${NC}"
            else
                echo -e "  ${options[$i]}"
            fi
        done
        echo ""

        read -s -n 1 key_input # Read single character input silently

        case "$key_input" in
            # Arrow keys (terminal sends escape sequences)
            $'\x1b') # ESC key
                read -s -n 1 -t 0.1 key_input # Read next char with timeout
                if [ -z "$key_input" ]; then # If no more input, it was just ESC (exit)
                    cleanup_terminal_settings_on_exit
                    return 1 # Indicate cancellation
                fi
                read -s -n 1 -t 0.1 key_input # Read next char with timeout
                case "$key_input" in
                    '[A') # Up arrow
                        selected_idx=$(( (selected_idx - 1 + num_options) % num_options ))
                        ;;
                    '[B') # Down arrow
                        selected_idx=$(( (selected_idx + 1) % num_options ))
                        ;;
                    *)
                        ;;
                esac
                ;;
            "") # Enter key (empty string means Enter)
                cleanup_terminal_settings_on_exit
                echo "${options[$selected_idx]}"
                return 0
                ;;
            $'\t') # Tab key
                selected_idx=$(( (selected_idx + 1) % num_options ))
                ;;
            *)
                # For any other key, ignore
                ;;
        esac
    done
}
EOF

    # helpers/prompt.sh
    cat << 'EOF' > "${HELPERS_DIR}/prompt.sh"
#!/bin/bash

# AUB Tools - helpers/prompt.sh
# This script provides functions for user input prompts.

# Load helpers (log and i18n are essential)
source "${HELPERS_DIR}/log.sh"
source "${HELPERS_DIR}/i18n.sh"

# Function to prompt for input
# Arguments:
#   $1 - The prompt message
#   $2 - Default value (optional)
# Returns the user's input
prompt_input() {
    local message="$1"
    local default_value="$2"
    local input=""

    if [ -n "$default_value" ]; then
        read -rp "${YELLOW}${message} [${default_value}]: ${NC}" input
        input="${input:-${default_value}}" # Use default if input is empty
    else
        read -rp "${YELLOW}${message}: ${NC}" input
    fi
    echo "$input"
}

# Function to prompt for confirmation (Yes/No)
# Arguments:
#   $1 - The confirmation message
# Returns 0 for Yes, 1 for No
prompt_confirm() {
    local message="$1"
    while true; do
        read -rp "${YELLOW}${message} (y/N): ${NC}" yn
        case ${yn:0:1} in
            y|Y ) return 0 ;;
            n|N|"" ) return 1 ;;
            * ) echo "$(i18n_message "PROMPT_INVALID_INPUT")" ;;
        esac
    done
}

# Function to prompt user to press Enter to continue
prompt_continue() {
    echo ""
    read -rp "$(i18n_message "PROMPT_PRESS_ENTER_TO_CONTINUE")"
}
EOF

    # helpers/report.sh
    cat << 'EOF' > "${HELPERS_DIR}/report.sh"
#!/bin/bash

# AUB Tools - helpers/report.sh
# This script provides functionality for generating error reports.

# Load helpers
source "${HELPERS_DIR}/log.sh"
source "${HELPERS_DIR}/prompt.sh"
source "${HELPERS_DIR}/i18n.sh"
source "${HELPERS_DIR}/config.sh"

# Function to generate a detailed error report
# Arguments:
#   $1 - The initial error message or context
generate_error_report() {
    if [[ "${AUB_TOOLS_ENABLE_ERROR_REPORTING}" != "true" ]]; then
        return 0 # Do nothing if error reporting is disabled
    fi

    local error_context="$1"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local report_file="${TEMP_DIR}/aub-tools_error_report_${timestamp}.log"

    log_warn "$(i18n_message "REPORT_ERROR_DETECTED")"
    if ! prompt_confirm "$(i18n_message "REPORT_GENERATE_REPORT_PROMPT")"; then
        log_info "$(i18n_message "REPORT_GENERATION_CANCELLED")"
        return 1
    fi

    log_info "$(i18n_message "REPORT_GENERATING_FILE" "${report_file}")"

    {
        echo "--- AUB Tools Error Report ---"
        echo "Generated On: $(date)"
        echo "AUB Tools Version: 1.0"
        echo "Error Context: ${error_context}"
        echo ""

        echo "--- System Information ---"
        echo "Hostname: $(hostname)"
        echo "OS Type: $(uname -s)"
        echo "OS Version: $(uname -v)"
        echo "Kernel: $(uname -r)"
        echo "Shell: ${SHELL} (Version: ${BASH_VERSION:-Unknown})"
        echo "User: ${USER}"
        echo ""

        echo "--- AUB Tools Configuration ---"
        echo "Install Dir: ${INSTALL_DIR}"
        echo "Config File: ${CONFIG_FILE}"
        if [ -f "${CONFIG_FILE}" ]; then
            echo "$(cat "${CONFIG_FILE}")"
        else
            echo "Config file not found."
        fi
        echo ""

        echo "--- Relevant Environment Variables ---"
        env | grep -E 'HOME|PATH|LANG|LC_|TERM|DRUSH|COMPOSER|KUBECFG|IBMCLOUD|AUB_TOOLS' | sort
        echo ""

        echo "--- Tool Versions ---"
        echo "git: $(git --version 2>/dev/null || echo 'Not found')"
        echo "composer: $(composer --version 2>/dev/null || echo 'Not found')"
        echo "drush: $(drush --version 2>/dev/null || echo 'Not found')"
        echo "kubectl: $(kubectl version --client=true --short 2>/dev/null || echo 'Not found')"
        echo "ibmcloud: $(ibmcloud --version 2>/dev/null || echo 'Not found')"
        echo "jq: $("${BIN_DIR}/jq" --version 2>/dev/null || echo 'Not found')"
        echo "php: $(php --version 2>/dev/null | head -n 1 || echo 'Not found')"
        echo ""

        echo "--- Recent AUB Tools Log Entries (${LOG_FILE}) ---"
        if [ -f "${LOG_FILE}" ]; then
            tail -n 50 "${LOG_FILE}" || echo "Could not read log file."
        else
            echo "Log file not found."
        fi
        echo ""

        echo "--- Directory Listing of Current Project (if detected) ---"
        if [ -n "$CURRENT_PROJECT_PATH" ] && [ -d "$CURRENT_PROJECT_PATH" ]; then
            echo "CURRENT_PROJECT_PATH: ${CURRENT_PROJECT_PATH}"
            ls -la "${CURRENT_PROJECT_PATH}"
            echo "Drupal Root: ${CURRENT_DRUPAL_ROOT_PATH}"
            if [ -n "$CURRENT_DRUPAL_ROOT_PATH" ] && [ -d "$CURRENT_DRUPAL_ROOT_PATH" ]; then
                 ls -la "${CURRENT_DRUPAL_ROOT_PATH}/core" 2>/dev/null
                 ls -la "${CURRENT_DRUPAL_ROOT_PATH}/sites" 2>/dev/null
                 ls -la "${CURRENT_DRUPAL_ROOT_PATH}/sites/default" 2>/dev/null
            fi
        else
            echo "Current project path not detected."
        fi
        echo ""

        echo "--- End of Report ---"

    } > "${report_file}" 2>&1 # Redirect stdout and stderr to report file

    log_success "$(i18n_message "REPORT_GENERATED_SUCCESS" "${report_file}")"
    log_info "$(i18n_message "REPORT_PLEASE_SHARE")"
    return 0
}
EOF

    # helpers/utils.sh
    cat << 'EOF' > "${HELPERS_DIR}/utils.sh"
#!/bin/bash

# AUB Tools - helpers/utils.sh
# This script provides general utility functions for AUB Tools.

# Load helpers
source "${HELPERS_DIR}/log.sh" # Needed for logging

# Function to check if a command exists
# Arguments:
#   $1 - The command name
# Returns 0 if command exists, 1 otherwise
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to pause execution for a given number of seconds
# Arguments:
#   $1 - Number of seconds to pause
pause_seconds() {
    local seconds="$1"
    sleep "${seconds}"
}

# Add any other general utility functions here
# For example, a function to safely execute a command and capture its output/status
# safe_exec() {
#     local cmd="$@"
#     log_debug "Executing: ${cmd}"
#     eval "${cmd}"
#     local status=$?
#     if [ $status -ne 0 ]; then
#         log_error "Command failed: ${cmd} (Exit code: ${status})"
#     fi
#     return $status
# }
EOF

    install_log "SUCCESS" "Helper script files created."
}

# --- Create language files ---
create_lang_files() {
    install_log "INFO" "Creating language files..."

    # lang/en_US/messages.sh
    cat << 'EOF' > "${LANG_DIR}/en_US/messages.sh"
#!/bin/bash

# AUB Tools - English Messages (en_US)
# This file contains all translatable strings for the English interface.

declare -A _messages_

# General
_messages_["BACK"]="Back to Main Menu"
_messages_["EXIT"]="Exit"
_messages_["MAIN_MENU_TITLE"]="Main Menu"
_messages_["ERROR_INVALID_CHOICE"]="Invalid choice. Please try again."
_messages_["PROMPT_PRESS_ENTER_TO_CONTINUE"]="Press Enter to continue..."
_messages_["PROMPT_INVALID_INPUT"]="Invalid input."
_messages_["MENU_INSTRUCTIONS"]="Use UP/DOWN arrows or TAB to navigate, ENTER to select."
_messages_["NOT_DETECTED"]="Not detected"
_messages_["NOT_SET"]="Not set"
_messages_["NO_CHOICE_MADE"]="No choice was made."
_messages_["NO_VALUE_ENTERED"]="No value entered."

# Initialization
_messages_["INITIALIZING_AUB_TOOLS"]="Initializing AUB Tools..."
_messages_["AUB_TOOLS_INITIALIZED"]="AUB Tools initialized successfully."
_messages_["EXITING_AUB_TOOLS"]="Exiting AUB Tools. Goodbye!"

# Project Management (core/project.sh)
_messages_["PROJECT_MANAGEMENT_MENU_TITLE"]="Project Management"
_messages_["PROJECT_INITIALIZE_NEW"]="Initialize New Project (Git Clone & Composer)"
_messages_["PROJECT_RE_DETECT_PATH"]="Re-detect Project Path"
_messages_["PROJECT_GENERATE_ENV"]="Generate .env from .env.dist"
_messages_["PROJECT_DETECTING_PATH"]="Detecting current project path..."
_messages_["PROJECT_PATH_DETECTED"]="Project path detected: %s"
_messages_["PROJECT_PATH_DETECTED_COMPOSER"]="Project path detected via composer.json: %s"
_messages_["PROJECT_PATH_NOT_DETECTED"]="Project path not detected. Please navigate into a project directory or initialize a new one."
_messages_["PROJECT_SEARCHING_IN_CONFIG_ROOT"]="Searching for projects in configured root directory: %s"
_messages_["PROJECT_SELECT_FROM_CONFIG_ROOT"]="Select a project from your configured root directory:"
_messages_["PROJECT_PATH_SELECTED_FROM_CONFIG"]="Selected project path from config root: %s"
_messages_["ERROR_PROJECT_PATH_UNKNOWN"]="Project path is unknown. Please detect or initialize a project first."
_messages_["PROJECT_ENTER_GIT_REPO_URL"]="Enter Git repository URL (e.g., https://github.com/drupal/recommended-project.git):"
_messages_["PROJECT_GIT_REPO_URL_EMPTY"]="Git repository URL cannot be empty."
_messages_["PROJECT_ENTER_TARGET_DIRECTORY"]="Enter target directory for cloning (default: %s):"
_messages_["PROJECT_TARGET_DIRECTORY_EMPTY"]="Target directory cannot be empty."
_messages_["PROJECT_TARGET_DIRECTORY_EXISTS_OVERWRITE"]="Target directory '%s' already exists. Do you want to overwrite/clone into it?"
_messages_["PROJECT_INIT_CANCELLED"]="Project initialization cancelled."
_messages_["PROJECT_CLONING_REPO"]="Cloning repository '%s' into '%s'..."
_messages_["PROJECT_CLONE_FAILED"]="Failed to clone repository '%s'."
_messages_["PROJECT_CLONE_SUCCESS"]="Repository cloned successfully to '%s'."
_messages_["PROJECT_RUNNING_COMPOSER_INSTALL"]="Running composer install..."
_messages_["PROJECT_COMPOSER_INSTALL_SUCCESS"]="Composer install completed successfully."
_messages_["PROJECT_COMPOSER_INSTALL_FAILED"]="Composer install failed."
_messages_["PROJECT_COMPOSER_JSON_NOT_FOUND"]="composer.json not found in project root. Skipping composer install."
_messages_["PROJECT_INITIALIZATION_COMPLETE"]="Project initialization complete!"
_messages_["DRUPAL_DETECTING_ROOT"]="Detecting Drupal root path..."
_messages_["DRUPAL_ROOT_DETECTED"]="Drupal root detected: %s"
_messages_["DRUPAL_ROOT_NOT_DETECTED"]="Drupal root (e.g., src/web/core) not detected in %s. Please ensure 'src' is the correct project root."
_messages_["ERROR_DRUPAL_ROOT_UNKNOWN"]="Drupal root path is unknown. Please detect a project first."
_messages_["ERROR_NOT_DRUPAL_PROJECT"]="Current directory is not recognized as a Drupal project."
_messages_["PROJECT_NAME_DETECTED"]="Project name detected from Git: %s"
_messages_["PROJECT_NAME_NO_REMOTE_ORIGIN"]="Could not determine project name from Git remote origin. Falling back to directory name."
_messages_["PROJECT_NAME_FALLBACK_TO_DIR"]="Using directory name '%s' as project name."
_messages_["CURRENT_PROJECT_PATH"]="Current Project Path: %s"
_messages_["CURRENT_DRUPAL_ROOT_PATH"]="Current Drupal Root Path: %s"
_messages_["CURRENT_PROJECT_NAME"]="Current Project Name: %s"

# .env generation
_messages_["PROJECT_ENV_DIST_NOT_FOUND"]=".env.dist not found at %s. Cannot generate .env file."
_messages_["PROJECT_ENV_EXISTS_OVERWRITE"]=".env file already exists at %s. Do you want to overwrite it? (Recommended)"
_messages_["PROJECT_ENV_GENERATION_CANCELLED"]=".env file generation cancelled."
_messages_["PROJECT_GENERATING_ENV"]="Generating .env file at %s. Please provide values for variables."
_messages_["PROJECT_ENTER_VAR_VALUE"]="Enter value for %s (current: %s)"
_messages_["PROJECT_ENV_GENERATED_SUCCESS"]=".env file generated successfully at %s."


# Git (core/git.sh)
_messages_["GIT_MENU_TITLE"]="Git Management"
_messages_["GIT_NOT_GIT_REPO"]="The current project path '%s' is not a Git repository."
_messages_["GIT_RUNNING_COMMAND"]="Running Git command: %s"
_messages_["GIT_COMMAND_SUCCESS"]="Git command executed successfully."
_messages_["GIT_COMMAND_FAILED"]="Git command failed."
_messages_["GIT_STATUS"]="Show Status"
_messages_["GIT_LOG"]="Show Log"
_messages_["GIT_ENTER_NUMBER_OF_COMMITS"]="Enter number of commits to show:"
_messages_["GIT_BRANCH_MANAGEMENT"]="Branch Management"
_messages_["GIT_LIST_BRANCHES"]="List All Branches"
_messages_["GIT_FETCHING_BRANCHES"]="Fetching all remote branches..."
_messages_["GIT_LISTING_BRANCHES"]="Listing branches..."
_messages_["GIT_SWITCH_BRANCH"]="Switch Branch"
_messages_["GIT_SELECT_BRANCH_TO_SWITCH"]="Select a branch to switch to:"
_messages_["GIT_NO_BRANCHES_FOUND"]="No branches found."
_messages_["GIT_NO_BRANCH_SELECTED"]="No branch selected."
_messages_["GIT_CHECKOUT_REMOTE_AS_LOCAL"]="Checking out remote branch '%s' as new local branch '%s'."
_messages_["GIT_CREATE_NEW_BRANCH"]="Create New Branch"
_messages_["GIT_ENTER_NEW_BRANCH_NAME"]="Enter new branch name:"
_messages_["GIT_NEW_BRANCH_NAME_EMPTY"]="New branch name cannot be empty."
_messages_["GIT_PULL"]="Pull Changes"
_messages_["GIT_PUSH"]="Push Changes"
_messages_["GIT_STASH_MANAGEMENT"]="Stash Management"
_messages_["GIT_STASH_SAVE"]="Save Current Changes (Stash)"
_messages_["GIT_ENTER_STASH_MESSAGE"]="Enter a stash message (optional):"
_messages_["GIT_STASH_LIST"]="List Stashes"
_messages_["GIT_STASH_APPLY"]="Apply Stash"
_messages_["GIT_ENTER_STASH_REF_TO_APPLY"]="Enter stash reference to apply (e.g., stash@{0}):"
_messages_["GIT_STASH_POP"]="Pop Stash (Apply and Drop)"
_messages_["GIT_ENTER_STASH_REF_TO_POP"]="Enter stash reference to pop (e.g., stash@{0}):"
_messages_["GIT_STASH_DROP"]="Drop Stash"
_messages_["GIT_ENTER_STASH_REF_TO_DROP"]="Enter stash reference to drop (e.g., stash@{0}):"
_messages_["GIT_UNDO_OPERATIONS"]="Undo Operations"
_messages_["GIT_RESET_HARD"]="Reset Hard (Discard all local changes to last commit)"
_messages_["GIT_CONFIRM_RESET_HARD"]="WARNING: This will discard all uncommitted changes and revert to the last commit. Are you sure?"
_messages_["GIT_RESET_HARD_WARNING"]="Git reset --hard executed. All local changes are gone."
_messages_["GIT_RESET_HARD_CANCELLED"]="Git reset --hard cancelled."
_messages_["GIT_REVERT_COMMIT"]="Revert a Commit"
_messages_["GIT_ENTER_COMMIT_HASH_TO_REVERT"]="Enter commit hash to revert:"
_messages_["GIT_CONFIRM_REVERT_COMMIT"]="Are you sure you want to revert commit '%s'?"
_messages_["GIT_REVERT_COMMIT_CANCELLED"]="Commit revert cancelled."
_messages_["GIT_COMMIT_HASH_EMPTY"]="Commit hash cannot be empty."
_messages_["GIT_CLEAN"]="Clean Untracked Files/Directories"
_messages_["GIT_CONFIRM_CLEAN"]="WARNING: This will remove all untracked files and directories. Are you sure?"
_messages_["GIT_CLEAN_WARNING"]="Git clean executed. Untracked files/directories removed."
_messages_["GIT_CLEAN_CANCELLED"]="Git clean cancelled."

# Composer (core/composer.sh)
_messages_["COMPOSER_MENU_TITLE"]="Composer Management"
_messages_["COMPOSER_RUNNING_COMMAND"]="Running Composer %s..."
_messages_["COMPOSER_COMMAND_SUCCESS"]="Composer command completed successfully."
_messages_["COMPOSER_COMMAND_FAILED"]="Composer command failed."
_messages_["COMPOSER_INSTALL"]="Run 'composer install'"
_messages_["COMPOSER_RUNNING_INSTALL"]="Running composer install..."
_messages_["COMPOSER_UPDATE"]="Run 'composer update'"
_messages_["COMPOSER_RUNNING_UPDATE"]="Running composer update..."
_messages_["COMPOSER_REQUIRE"]="Require a Package"
_messages_["COMPOSER_ENTER_PACKAGE_TO_REQUIRE"]="Enter package name to require (e.g., drupal/admin_toolbar):"
_messages_["COMPOSER_REMOVE"]="Remove a Package"
_messages_["COMPOSER_ENTER_PACKAGE_TO_REMOVE"]="Enter package name to remove:"
_messages_["COMPOSER_PACKAGE_EMPTY"]="Package name cannot be empty."

# Drush (core/drush.sh)
_messages_["DRUSH_MENU_TITLE"]="Drush Management"
_messages_["DRUSH_EXECUTING_COMMAND"]="Executing Drush command: %s"
_messages_["DRUSH_COMMAND_SUCCESS"]="Drush command executed successfully."
_messages_["DRUSH_COMMAND_FAILED"]="Drush command failed."
_messages_["DRUSH_DETECTING_TARGETS"]="Detecting Drush aliases and multi-site URIs..."
_messages_["DRUSH_CURRENT_SITE"]="current local site"
_messages_["DRUSH_ALL_SITES_ALIAS"]="All Sites (@sites)"
_messages_["DRUSH_PLEASE_SELECT_TARGET"]="Please select a Drush target (site alias or URI):"
_messages_["DRUSH_NO_TARGETS_FOUND"]="No Drush aliases or multi-site URIs found."
_messages_["DRUSH_TARGET_SET"]="Drush target set to: %s"
_messages_["DRUSH_TARGET_NOT_SET"]="Drush target not set. Some commands may fail."
_messages_["DRUSH_DETECTING_MULTI_SITES"]="Detecting multi-site URIs from sites.php..."
_messages_["CURRENT_DRUSH_TARGET"]="Current Drush Target: %s"
_messages_["DRUSH_SELECT_TARGET"]="Select Drush Target (Site/Alias)"

_messages_["DRUSH_GENERAL_COMMANDS"]="General Commands"
_messages_["DRUSH_GENERAL_MENU_TITLE"]="Drush: General Commands"
_messages_["DRUSH_STATUS"]="Show Status (drush status)"
_messages_["DRUSH_CACHE_REBUILD"]="Rebuild Cache (drush cr)"

_messages_["DRUSH_CONFIG_COMMANDS"]="Configuration Management"
_messages_["DRUSH_CONFIG_MENU_TITLE"]="Drush: Configuration Management"
_messages_["DRUSH_CONFIG_IMPORT"]="Import Configuration (drush cim)"
_messages_["DRUSH_CONFIG_EXPORT"]="Export Configuration (drush cex)"

_messages_["DRUSH_MODULES_THEMES_COMMANDS"]="Modules & Themes"
_messages_["DRUSH_MODULES_THEMES_MENU_TITLE"]="Drush: Modules & Themes"
_messages_["DRUSH_PM_LIST"]="List Modules/Themes (drush pm:list)"
_messages_["DRUSH_PM_ENABLE"]="Enable Module/Theme (drush pm:enable)"
_messages_["DRUSH_ENTER_MODULE_NAME_TO_ENABLE"]="Enter module/theme name to enable:"
_messages_["DRUSH_PM_DISABLE"]="Disable Module/Theme (drush pm:disable)"
_messages_["DRUSH_ENTER_MODULE_NAME_TO_DISABLE"]="Enter module/theme name to disable:"
_messages_["DRUSH_PM_UNINSTALL"]="Uninstall Module (drush pm:uninstall)"
_messages_["DRUSH_ENTER_MODULE_NAME_TO_UNINSTALL"]="Enter module name to uninstall:"
_messages_["DRUSH_MODULE_NAME_EMPTY"]="Module/Theme name cannot be empty."

_messages_["DRUSH_USER_COMMANDS"]="User Management"
_messages_["DRUSH_USER_MENU_TITLE"]="Drush: User Management"
_messages_["DRUSH_USER_LOGIN"]="Generate User Login Link (drush user:login)"
_messages_["DRUSH_USER_BLOCK"]="Block User (drush user:block)"
_messages_["DRUSH_ENTER_USERNAME_TO_BLOCK"]="Enter username to block:"
_messages_["DRUSH_USER_UNBLOCK"]="Unblock User (drush user:unblock)"
_messages_["DRUSH_ENTER_USERNAME_TO_UNBLOCK"]="Enter username to unblock:"
_messages_["DRUSH_USER_PASSWORD"]="Set User Password (drush user:password)"
_messages_["DRUSH_ENTER_USERNAME_TO_SET_PASSWORD"]="Enter username to set password for:"
_messages_["DRUSH_ENTER_NEW_PASSWORD"]="Enter new password:"
_messages_["DRUSH_USERNAME_EMPTY"]="Username cannot be empty."
_messages_["DRUSH_NEW_PASSWORD_EMPTY"]="New password cannot be empty."

_messages_["DRUSH_WATCHDOG_COMMANDS"]="Watchdog Logs"
_messages_["DRUSH_WATCHDOG_MENU_TITLE"]="Drush: Watchdog Logs"
_messages_["DRUSH_WATCHDOG_SHOW"]="Show recent log messages (drush watchdog:show)"
_messages_["DRUSH_WATCHDOG_LIST"]="List log message types (drush watchdog:list)"
_messages_["DRUSH_WATCHDOG_DELETE"]="Delete all log messages (drush watchdog:delete)"
_messages_["DRUSH_WATCHDOG_TAIL"]="Tail recent log messages (drush watchdog:tail) (Press Ctrl+C to exit)"
_messages_["DRUSH_WATCHDOG_TAIL_EXPLANATION"]="Note: 'drush watchdog:tail' is an interactive command. Press Ctrl+C to return to the menu."

_messages_["DRUSH_DEV_TOOLS_COMMANDS"]="Development Tools"
_messages_["DRUSH_DEV_TOOLS_MENU_TITLE"]="Drush: Development Tools"
_messages_["DRUSH_EVAL_PHP"]="Evaluate PHP Code (drush ev)"
_messages_["DRUSH_ENTER_PHP_CODE"]="Enter PHP code to execute (e.g., 'echo \\Drupal::VERSION;'):"
_messages_["DRUSH_PHP_CODE_EMPTY"]="PHP code cannot be empty."
_messages_["DRUSH_PHP_SHELL"]="Interactive PHP Shell (drush php)"
_messages_["DRUSH_PHP_SHELL_EXPLANATION"]="Note: 'drush php' opens an interactive PHP shell. Type 'exit' to return to the menu."
_messages_["DRUSH_PHP_SHELL_EXITED"]="Exited Drush PHP shell."
_messages_["DRUSH_RUN_CRON"]="Run Cron (drush cron)"

_messages_["DRUSH_WEBFORM_COMMANDS"]="Webform Management"
_messages_["DRUSH_WEBFORM_MENU_TITLE"]="Drush: Webform Management"
_messages_["DRUSH_WEBFORM_LIST"]="List Webforms (drush webform:list)"
_messages_["DRUSH_WEBFORM_EXPORT"]="Export Webform Submissions (drush webform:export)"
_messages_["DRUSH_ENTER_WEBFORM_ID_TO_EXPORT"]="Enter Webform ID to export submissions from:"
_messages_["DRUSH_WEBFORM_PURGE"]="Purge Webform Submissions (drush webform:purge)"
_messages_["DRUSH_ENTER_WEBFORM_ID_TO_PURGE"]="Enter Webform ID to purge submissions from:"
_messages_["DRUSH_WEBFORM_ID_EMPTY"]="Webform ID cannot be empty."

# Database (core/database.sh)
_messages_["DATABASE_MENU_TITLE"]="Database Management"
_messages_["DB_UPDATE_DB"]="Run Database Updates (drush updb)"
_messages_["DB_DUMP"]="Dump Database (drush sql:dump)"
_messages_["DB_ENTER_DUMP_FILENAME"]="Enter filename for the database dump:"
_messages_["DB_DUMP_FILENAME_EMPTY"]="Dump filename cannot be empty."
_messages_["DB_CLI"]="Access SQL CLI (drush sql:cli)"
_messages_["DB_ENTERING_SQL_CLI"]="Entering SQL command line interface. Type 'exit' or '\\q' to quit."
_messages_["DB_EXITED_SQL_CLI"]="Exited SQL command line interface."
_messages_["DB_QUERY"]="Execute SQL Query (drush sql:query)"
_messages_["DB_ENTER_SQL_QUERY"]="Enter SQL query to execute:"
_messages_["DB_QUERY_EMPTY"]="SQL query cannot be empty."
_messages_["DB_SYNC"]="Synchronize Database (drush sql:sync)"
_messages_["DB_ENTER_SOURCE_ALIAS"]="Enter source Drush alias (e.g., @prod):"
_messages_["DB_SYNC_SOURCE_EMPTY"]="Source alias cannot be empty."
_messages_["DB_RESTORE"]="Restore Database from Dump"
_messages_["DB_RESTORE_SEARCHING_DUMPS"]="Searching for database dump files in '%s'..."
_messages_["DB_RESTORE_NO_DUMPS_FOUND"]="No database dump files found in '%s'."
_messages_["DB_RESTORE_SELECT_DUMP"]="Select a database dump file to restore from:"
_messages_["DB_RESTORE_NO_DUMP_SELECTED"]="No dump file selected. Restoration cancelled."
_messages_["DB_RESTORE_DUMP_NOT_FOUND"]="Dump file not found: %s"
_messages_["DB_RESTORE_NO_DRUSH_TARGET"]="No Drush target selected for restore. Please select a target first."
_messages_["DB_RESTORE_PROCESSING_DUMP"]="Processing dump file '%s' for target '%s'..."
_messages_["DB_RESTORE_EXTRACTING_ZIP"]="Extracting ZIP archive..."
_messages_["DB_RESTORE_ZIP_EXTRACTION_FAILED"]="Failed to extract ZIP file '%s'."
_messages_["DB_RESTORE_EXTRACTING_TAR"]="Extracting TAR archive..."
_messages_["DB_RESTORE_TAR_EXTRACTION_FAILED"]="Failed to extract TAR file '%s'."
_messages_["DB_RESTORE_UNSUPPORTED_FORMAT"]="Unsupported dump file format: %s"
_messages_["DB_RESTORE_EXECUTING_RESTORE"]="Executing database restore to target '%s'..."
_messages_["DB_RESTORE_SUCCESS"]="Database restored successfully from '%s' to '%s'."
_messages_["DB_RESTORE_FAILED"]="Database restore failed from '%s' to '%s'."
_messages_["DB_RESTORE_POST_UPDATE_SUCCESS"]="Running 'drush updb' and 'drush cr' after restore."

# Search API Solr (core/solr.sh)
_messages_["DRUSH_SEARCH_API_SOLR_COMMANDS"]="Search API Solr"
_messages_["SOLR_MENU_TITLE"]="Drush: Search API Solr"
_messages_["SOLR_SERVER_LIST"]="List Solr Servers (drush search-api:server-list)"
_messages_["SOLR_INDEX_LIST"]="List Solr Indexes (drush search-api:index-list)"
_messages_["SOLR_EXPORT_CONFIG"]="Export Solr Configs (drush search-api-solr:export-solr-config)"
_messages_["SOLR_SELECT_SERVER_TO_EXPORT"]="Select a Solr server to export configurations from:"
_messages_["SOLR_NO_SERVERS_FOUND"]="No Solr servers found."
_messages_["SOLR_NO_SERVER_SELECTED"]="No Solr server selected."
_messages_["SOLR_EXPORTING_CONFIG"]="Exporting Solr configurations for '%s' to '%s'..."
_messages_["SOLR_EXPORT_CONFIG_SUCCESS"]="Solr configurations exported successfully to '%s'."
_messages_["SOLR_EXPORT_CONFIG_FAILED"]="Failed to export Solr configurations."
_messages_["SOLR_INDEX_CONTENT"]="Index Content (drush search-api:index)"
_messages_["SOLR_SELECT_INDEX_TO_INDEX"]="Select an index to re-index content:"
_messages_["SOLR_NO_INDEXES_FOUND"]="No Search API indexes found."
_messages_["SOLR_NO_INDEX_SELECTED"]="No index selected."
_messages_["SOLR_INDEXING"]="Indexing content for index '%s'..."
_messages_["SOLR_INDEX_SUCCESS"]="Content indexed successfully."
_messages_["SOLR_INDEX_FAILED"]="Content indexing failed."
_messages_["SOLR_CLEAR_INDEX"]="Clear Index (drush search-api:clear)"
_messages_["SOLR_SELECT_INDEX_TO_CLEAR"]="Select an index to clear:"
_messages_["SOLR_CONFIRM_CLEAR_INDEX"]="WARNING: This will clear all indexed data for '%s'. Are you sure?"
_messages_["SOLR_CLEARING_INDEX"]="Clearing index '%s'..."
_messages_["SOLR_CLEAR_SUCCESS"]="Index cleared successfully."
_messages_["SOLR_CLEAR_FAILED"]="Failed to clear index."
_messages_["SOLR_CLEAR_CANCELLED"]="Index clear cancelled."
_messages_["SOLR_STATUS"]="Show Search API Status (drush search-api:status)"

# IBM Cloud (core/ibmcloud.sh)
_messages_["IBMCLOUD_MENU_TITLE"]="IBM Cloud Integration"
_messages_["IBMCLOUD_CLI_NOT_FOUND"]="IBM Cloud CLI (ibmcloud) not found. Please install it."
_messages_["IBMCLOUD_LOGIN"]="Log in to IBM Cloud"
_messages_["IBMCLOUD_ENTER_REGION"]="Enter IBM Cloud region (e.g., eu-de):"
_messages_["IBMCLOUD_REGION_EMPTY"]="IBM Cloud region cannot be empty."
_messages_["IBMCLOUD_ENTER_RESOURCE_GROUP"]="Enter IBM Cloud resource group (e.g., Default):"
_messages_["IBMCLOUD_RESOURCE_GROUP_EMPTY"]="IBM Cloud resource group cannot be empty."
_messages_["IBMCLOUD_LOGGING_IN"]="Logging in to IBM Cloud (Region: %s, Resource Group: %s)..."
_messages_["IBMCLOUD_LOGIN_SUCCESS"]="Successfully logged in to IBM Cloud."
_messages_["IBMCLOUD_LOGIN_FAILED"]="IBM Cloud login failed."
_messages_["IBMCLOUD_LOGOUT"]="Log out from IBM Cloud"
_messages_["IBMCLOUD_LOGGING_OUT"]="Logging out from IBM Cloud..."
_messages_["IBMCLOUD_LOGOUT_SUCCESS"]="Successfully logged out from IBM Cloud."
_messages_["IBMCLOUD_LOGOUT_FAILED"]="IBM Cloud logout failed."
_messages_["IBMCLOUD_LIST_KUBERNETES_CLUSTERS"]="List Kubernetes Clusters"
_messages_["IBMCLOUD_NO_KUBERNETES_CLUSTERS_FOUND"]="No Kubernetes clusters found in your IBM Cloud account."
_messages_["IBMCLOUD_CONFIGURE_KUBECTL"]="Configure kubectl for a Cluster"
_messages_["IBMCLOUD_SELECT_KUBERNETES_CLUSTER"]="Select a Kubernetes cluster to configure kubectl:"
_messages_["IBMCLOUD_CONFIGURING_KUBECTL"]="Configuring kubectl for cluster '%s'..."
_messages_["IBMCLOUD_KUBECTL_CONFIG_SUCCESS"]="kubectl configured successfully for cluster '%s'."
_messages_["IBMCLOUD_KUBECTL_CONFIG_FAILED"]="Failed to configure kubectl for cluster '%s'."
_messages_["IBMCLOUD_KUBECTL_CONTEXT_SET"]="Current kubectl context:"
_messages_["IBMCLOUD_NO_CLUSTER_SELECTED"]="No cluster selected."

# Kubernetes (core/k8s.sh)
_messages_["KUBECTL_MENU_TITLE"]="Kubernetes (kubectl) Management"
_messages_["KUBECTL_CLI_NOT_FOUND"]="kubectl CLI not found. Please install it."
_messages_["KUBECTL_NO_CONTEXT_SET"]="kubectl context is not set. Please log in to IBM Cloud and configure kubectl."
_messages_["KUBECTL_CURRENT_CONTEXT"]="Current kubectl context: %s"
_messages_["KUBECTL_CLI_NOT_READY"]="kubectl is not ready. Please ensure it's installed and configured."
_messages_["KUBECTL_NO_NAMESPACES_FOUND"]="No Kubernetes namespaces found."
_messages_["KUBECTL_SELECT_NAMESPACE"]="Select a Kubernetes namespace:"
_messages_["KUBECTL_USING_DEFAULT_NAMESPACE"]="Using default namespace: %s"
_messages_["KUBECTL_NO_NAMESPACE_SELECTED"]="No namespace selected."
_messages_["KUBECTL_FILTERING_PODS_BY_LABEL"]="Filtering pods by label: %s"
_messages_["KUBECTL_NO_PODS_FOUND"]="No pods found in namespace '%s'."
_messages_["KUBECTL_SELECT_POD"]="Select a Kubernetes pod:"
_messages_["KUBECTL_NO_POD_SELECTED"]="No pod selected."
_messages_["KUBECTL_POD_NAME_MISSING"]="Pod name is missing."
_messages_["KUBECTL_NO_CONTAINERS_FOUND"]="No containers found in pod '%s'."
_messages_["KUBECTL_AUTO_SELECT_SINGLE_CONTAINER"]="Automatically selected single container: %s"
_messages_["KUBECTL_SELECT_CONTAINER"]="Select a container in the pod:"
_messages_["KUBECTL_NO_CONTAINER_SELECTED"]="No container selected."
_messages_["KUBECTL_COPY_FILES"]="Copy Files to Pod (kubectl cp)"
_messages_["KUBECTL_COPY_MISSING_PATHS"]="Local source path or remote destination path missing."
_messages_["KUBECTL_ENTER_LOCAL_SOURCE_PATH"]="Enter local source path (file or directory):"
_messages_["KUBECTL_ENTER_REMOTE_DEST_PATH"]="Enter remote destination path in container (e.g., /app/data/):"
_messages_["KUBECTL_PATH_EMPTY"]="Path cannot be empty."
_messages_["KUBECTL_COPYING_FILES"]="Copying '%s' to '%s' in container '%s'..."
_messages_["KUBECTL_COPY_SUCCESS"]="Files copied successfully."
_messages_["KUBECTL_COPY_FAILED"]="File copy failed."

_messages_["KUBECTL_SOLR_COMMANDS"]="Solr Pod Management"
_messages_["KUBECTL_SOLR_MENU_TITLE"]="Kubernetes: Solr Pods"
_messages_["KUBECTL_LIST_SOLR_PODS"]="List Solr Pods"
_messages_["KUBECTL_RESTART_SOLR_POD"]="Restart Solr Pod"
_messages_["KUBECTL_NO_SOLR_POD_SELECTED"]="No Solr pod selected."
_messages_["KUBECTL_CONFIRM_RESTART_SOLR_POD"]="Are you sure you want to delete and restart Solr pod '%s'?"
_messages_["KUBECTL_RESTARTING_SOLR_POD"]="Restarting Solr pod '%s'..."
_messages_["KUBECTL_RESTART_SUCCESS"]="Pod '%s' restarted successfully."
_messages_["KUBECTL_RESTART_FAILED"]="Failed to restart pod '%s'."
_messages_["KUBECTL_RESTART_CANCELLED"]="Pod restart cancelled."
_messages_["KUBECTL_VIEW_SOLR_LOGS"]="View Solr Pod Logs"
_messages_["KUBECTL_NO_SOLR_CONTAINER_SELECTED"]="No Solr container selected."
_messages_["KUBECTL_VIEWING_SOLR_LOGS"]="Viewing logs for Solr pod/container '%s'. Press Ctrl+C to exit."
_messages_["KUBECTL_LISTING_SOLR_PODS"]="Listing Solr pods in namespace '%s'..."

_messages_["KUBECTL_PGSQL_COMMANDS"]="PostgreSQL Pod Management"
_messages_["KUBECTL_PGSQL_MENU_TITLE"]="Kubernetes: PostgreSQL Pods"
_messages_["KUBECTL_LIST_PGSQL_PODS"]="List PostgreSQL Pods"
_messages_["KUBECTL_NO_PGSQL_POD_SELECTED"]="No PostgreSQL pod selected."
_messages_["KUBECTL_ACCESS_PGSQL_CLI"]="Access PostgreSQL CLI"
_messages_["KUBECTL_NO_PGSQL_CONTAINER_SELECTED"]="No PostgreSQL container selected."
_messages_["KUBECTL_ACCESSING_PGSQL_CLI"]="Accessing psql CLI in pod/container '%s'. Type '\\q' or Ctrl+D to exit."
_messages_["KUBECTL_VIEW_PGSQL_LOGS"]="View PostgreSQL Pod Logs"
_messages_["KUBECTL_VIEWING_PGSQL_LOGS"]="Viewing logs for PostgreSQL pod/container '%s'. Press Ctrl+C to exit."
_messages_["KUBECTL_LISTING_PGSQL_PODS"]="Listing PostgreSQL pods in namespace '%s'..."

# Settings (core/main.sh, helpers/config.sh)
_messages_["AUB_TOOLS_SETTINGS"]="AUB Tools Settings"
_messages_["SETTINGS_MENU_TITLE"]="AUB Tools Settings"
_messages_["SETTING_LANGUAGE"]="Language"
_messages_["SELECT_LANGUAGE"]="Select preferred language:"
_messages_["LANGUAGE_FRENCH"]="French"
_messages_["LANGUAGE_ENGLISH"]="English"
_messages_["LANGUAGE_NAME"]="English" # This key is special, overridden by current language setting
_messages_["LANGUAGE_SET_SUCCESS"]="Language set to %s."
_messages_["NO_LANGUAGE_SELECTED"]="No language selected."

_messages_["SETTING_PROJECT_ROOT"]="Default Projects Root Directory"
_messages_["ENTER_PROJECTS_ROOT_PATH"]="Enter the default root directory for your projects (e.g., ${HOME}/workspace):"
_messages_["PROJECT_ROOT_SET_SUCCESS"]="Default projects root directory set to: %s"
_messages_["INVALID_PATH_OR_EMPTY"]="Invalid path or empty. Please enter a valid directory."

_messages_["SETTING_LOG_LEVEL"]="Logging Level"
_messages_["SELECT_LOG_LEVEL"]="Select logging verbosity level:"
_messages_["LOG_LEVEL_SET_SUCCESS"]="Log level set to: %s"
_messages_["NO_LOG_LEVEL_SELECTED"]="No log level selected."

_messages_["SETTING_ENABLE_HISTORY"]="Enable Command History"
_messages_["ENABLE_HISTORY_PROMPT"]="Enable command history logging? (current: %s)"
_messages_["SETTING_ENABLE_FAVORITES"]="Enable Custom Favorites/Shortcuts"
_messages_["ENABLE_FAVORITES_PROMPT"]="Enable custom favorites/shortcuts? (current: %s)"
_messages_["SETTING_ENABLE_ERROR_REPORTING"]="Enable Error Reporting"
_messages_["ENABLE_ERROR_REPORTING_PROMPT"]="Enable detailed error reporting on failures? (current: %s)"
_messages_["SETTING_UPDATED_SUCCESS"]="Setting updated successfully!"

_messages_["SETTING_IBMCLOUD_CONFIG"]="IBM Cloud Configurations"
_messages_["SETTINGS_IBMCLOUD_MENU_TITLE"]="Settings: IBM Cloud"
_messages_["SETTING_IBMCLOUD_REGION"]="IBM Cloud Region"
_messages_["ENTER_IBMCLOUD_REGION"]="Enter default IBM Cloud region (e.g., eu-de):"
_messages_["SETTING_IBMCLOUD_RESOURCE_GROUP"]="IBM Cloud Resource Group"
_messages_["ENTER_IBMCLOUD_RESOURCE_GROUP"]="Enter default IBM Cloud resource group (e.g., Default):"
_messages_["SETTING_IBMCLOUD_ACCOUNT"]="IBM Cloud Account ID"
_messages_["ENTER_IBMCLOUD_ACCOUNT"]="Enter default IBM Cloud Account ID:"

# History (helpers/history.sh)
_messages_["HISTORY_MENU_TITLE"]="Command History"
_messages_["HISTORY_FILE_LOCATION"]="History file location: %s"
_messages_["HISTORY_EMPTY"]="Command history is empty."
_messages_["HISTORY_RECENT_ACTIONS"]="Recent actions:"
_messages_["HISTORY_ADDED_ENTRY"]="Added entry to history."
_messages_["HISTORY_SELECT_TO_RELAUNCH"]="Select a command to re-launch:"
_messages_["HISTORY_NO_SELECTION"]="No command selected from history."
_messages_["HISTORY_INVALID_INDEX"]="Invalid history index. Please enter a number."
_messages_["HISTORY_COMMAND_NOT_FOUND_AT_INDEX"]="Command not found at history index %s."
_messages_["HISTORY_RELAUNCHING_COMMAND"]="Re-launching command: %s"
_messages_["HISTORY_COMMAND_RELAUNCH_SUCCESS"]="Command re-launched successfully."
_messages_["HISTORY_COMMAND_RELAUNCH_FAILED"]="Command re-launch failed."

# Favorites (helpers/favorites.sh)
_messages_["FAVORITES_MENU_TITLE"]="Custom Favorites"
_messages_["FAVORITES_FILE_LOCATION"]="Favorites file location: %s"
_messages_["FAVORITES_CREATING_FILE"]="Creating favorites file: %s"
_messages_["FAVORITES_FILE_CREATED"]="Favorites file created. You can edit it to add your custom functions."
_messages_["FAVORITES_NO_FAVORITES_FOUND"]="No custom favorites (functions) found in %s."
_messages_["FAVORITES_NO_FAVORITES_TO_SHOW"]="No custom favorites defined yet. Edit '%s' to add some!"
_messages_["FAVORITES_SELECT_TO_RUN"]="Select a favorite to run:"
_messages_["FAVORITES_NO_SELECTION"]="No favorite selected."
_messages_["FAVORITES_NO_FAVORITE_SELECTED"]="No favorite selected to run."
_messages_["FAVORITES_RUNNING"]="Running favorite: %s"
_messages_["FAVORITES_RUN_SUCCESS"]="Favorite executed successfully."
_messages_["FAVORITES_RUN_FAILED"]="Favorite execution failed."
_messages_["FAVORITES_NOT_A_FUNCTION"]="'%s' is not a callable function in favorites file."

# Feature Disabled
_messages_["FEATURE_DISABLED"]="Feature '%s' is currently disabled in settings."

# Error Reporting (helpers/report.sh)
_messages_["REPORT_ERROR_DETECTED"]="An error was detected."
_messages_["REPORT_GENERATE_REPORT_PROMPT"]="Do you want to generate a detailed error report for debugging?"
_messages_["REPORT_GENERATION_CANCELLED"]="Error report generation cancelled."
_messages_["REPORT_GENERATING_FILE"]="Generating error report to: %s"
_messages_["REPORT_GENERATED_SUCCESS"]="Error report generated successfully: %s"
_messages_["REPORT_PLEASE_SHARE"]="Please share this report with the development team for analysis."
_messages_["ERROR_UNEXPECTED"]="An unexpected error occurred in %s: '%s'"

# Logging (helpers/log.sh) - These are for internal log messages, not directly displayed in menus
_messages_["LOG_LEVEL_DEBUG"]="DEBUG"
_messages_["LOG_LEVEL_INFO"]="INFO"
_messages_["LOG_LEVEL_WARN"]="WARN"
_messages_["LOG_LEVEL_ERROR"]="ERROR"
_messages_["LOG_LEVEL_SUCCESS"]="SUCCESS"
EOF

    # lang/fr_FR/messages.sh
    cat << 'EOF' > "${LANG_DIR}/fr_FR/messages.sh"
#!/bin/bash

# AUB Tools - French Messages (fr_FR)
# This file contains all translatable strings for the French interface.

declare -A _messages_

# General
_messages_["BACK"]="Retour au menu principal"
_messages_["EXIT"]="Quitter"
_messages_["MAIN_MENU_TITLE"]="Menu Principal"
_messages_["ERROR_INVALID_CHOICE"]="Choix invalide. Veuillez réessayer."
_messages_["PROMPT_PRESS_ENTER_TO_CONTINUE"]="Appuyez sur Entrée pour continuer..."
_messages_["PROMPT_INVALID_INPUT"]="Saisie invalide."
_messages_["MENU_INSTRUCTIONS"]="Utilisez les flèches HAUT/BAS ou TAB pour naviguer, ENTRÉE pour sélectionner."
_messages_["NOT_DETECTED"]="Non détecté"
_messages_["NOT_SET"]="Non défini"
_messages_["NO_CHOICE_MADE"]="Aucun choix n'a été fait."
_messages_["NO_VALUE_ENTERED"]="Aucune valeur saisie."

# Initialization
_messages_["INITIALIZING_AUB_TOOLS"]="Initialisation des AUB Tools..."
_messages_["AUB_TOOLS_INITIALIZED"]="AUB Tools initialisés avec succès."
_messages_["EXITING_AUB_TOOLS"]="Fermeture des AUB Tools. Au revoir !"

# Project Management (core/project.sh)
_messages_["PROJECT_MANAGEMENT_MENU_TITLE"]="Gestion de Projet"
_messages_["PROJECT_INITIALIZE_NEW"]="Initialiser un nouveau projet (Clonage Git & Composer)"
_messages_["PROJECT_RE_DETECT_PATH"]="Re-détecter le chemin du projet"
_messages_["PROJECT_GENERATE_ENV"]="Générer .env à partir de .env.dist"
_messages_["PROJECT_DETECTING_PATH"]="Détection du chemin du projet actuel..."
_messages_["PROJECT_PATH_DETECTED"]="Chemin du projet détecté : %s"
_messages_["PROJECT_PATH_DETECTED_COMPOSER"]="Chemin du projet détecté via composer.json : %s"
_messages_["PROJECT_PATH_NOT_DETECTED"]="Chemin du projet non détecté. Veuillez naviguer dans un répertoire de projet ou en initialiser un nouveau."
_messages_["PROJECT_SEARCHING_IN_CONFIG_ROOT"]="Recherche de projets dans le répertoire racine configuré : %s"
_messages_["PROJECT_SELECT_FROM_CONFIG_ROOT"]="Sélectionnez un projet à partir de votre répertoire racine configuré :"
_messages_["PROJECT_PATH_SELECTED_FROM_CONFIG"]="Chemin du projet sélectionné à partir du répertoire racine configuré : %s"
_messages_["ERROR_PROJECT_PATH_UNKNOWN"]="Le chemin du projet est inconnu. Veuillez d'abord détecter ou initialiser un projet."
_messages_["PROJECT_ENTER_GIT_REPO_URL"]="Entrez l'URL du dépôt Git (ex: https://github.com/drupal/recommended-project.git) :"
_messages_["PROJECT_GIT_REPO_URL_EMPTY"]="L'URL du dépôt Git ne peut pas être vide."
_messages_["PROJECT_ENTER_TARGET_DIRECTORY"]="Entrez le répertoire cible pour le clonage (par défaut : %s) :"
_messages_["PROJECT_TARGET_DIRECTORY_EMPTY"]="Le répertoire cible ne peut pas être vide."
_messages_["PROJECT_TARGET_DIRECTORY_EXISTS_OVERWRITE"]="Le répertoire cible '%s' existe déjà. Voulez-vous le remplacer/cloner dedans ?"
_messages_["PROJECT_INIT_CANCELLED"]="Initialisation du projet annulée."
_messages_["PROJECT_CLONING_REPO"]="Clonage du dépôt '%s' dans '%s'..."
_messages_["PROJECT_CLONE_FAILED"]="Échec du clonage du dépôt '%s'."
_messages_["PROJECT_CLONE_SUCCESS"]="Dépôt cloné avec succès dans '%s'."
_messages_["PROJECT_RUNNING_COMPOSER_INSTALL"]="Exécution de 'composer install'..."
_messages_["PROJECT_COMPOSER_INSTALL_SUCCESS"]="Composer install terminé avec succès."
_messages_["PROJECT_COMPOSER_INSTALL_FAILED"]="Composer install a échoué."
_messages_["PROJECT_COMPOSER_JSON_NOT_FOUND"]="composer.json non trouvé à la racine du projet. Ignorons 'composer install'."
_messages_["PROJECT_INITIALIZATION_COMPLETE"]="Initialisation du projet terminée !"
_messages_["DRUPAL_DETECTING_ROOT"]="Détection du chemin racine de Drupal..."
_messages_["DRUPAL_ROOT_DETECTED"]="Racine Drupal détectée : %s"
_messages_["DRUPAL_ROOT_NOT_DETECTED"]="Racine Drupal (ex: src/web/core) non détectée dans %s. Veuillez vous assurer que 'src' est la bonne racine de projet."
_messages_["ERROR_DRUPAL_ROOT_UNKNOWN"]="Le chemin racine de Drupal est inconnu. Veuillez d'abord détecter un projet."
_messages_["ERROR_NOT_DRUPAL_PROJECT"]="Le répertoire actuel n'est pas reconnu comme un projet Drupal."
_messages_["PROJECT_NAME_DETECTED"]="Nom du projet détecté à partir de Git : %s"
_messages_["PROJECT_NAME_NO_REMOTE_ORIGIN"]="Impossible de déterminer le nom du projet à partir de l'origine distante Git. Retour au nom du répertoire."
_messages_["PROJECT_NAME_FALLBACK_TO_DIR"]="Utilisation du nom de répertoire '%s' comme nom de projet."
_messages_["CURRENT_PROJECT_PATH"]="Chemin actuel du projet : %s"
_messages_["CURRENT_DRUPAL_ROOT_PATH"]="Chemin racine actuel de Drupal : %s"
_messages_["CURRENT_PROJECT_NAME"]="Nom du projet actuel : %s"

# .env generation
_messages_["PROJECT_ENV_DIST_NOT_FOUND"]=".env.dist non trouvé à %s. Impossible de générer le fichier .env."
_messages_["PROJECT_ENV_EXISTS_OVERWRITE"]="Le fichier .env existe déjà à %s. Voulez-vous le remplacer ? (Recommandé)"
_messages_["PROJECT_ENV_GENERATION_CANCELLED"]="Génération du fichier .env annulée."
_messages_["PROJECT_GENERATING_ENV"]="Génération du fichier .env à %s. Veuillez fournir les valeurs pour les variables."
_messages_["PROJECT_ENTER_VAR_VALUE"]="Entrez la valeur pour %s (actuel : %s)"
_messages_["PROJECT_ENV_GENERATED_SUCCESS"]="Fichier .env généré avec succès à %s."


# Git (core/git.sh)
_messages_["GIT_MENU_TITLE"]="Gestion Git"
_messages_["GIT_NOT_GIT_REPO"]="Le chemin du projet actuel '%s' n'est pas un dépôt Git."
_messages_["GIT_RUNNING_COMMAND"]="Exécution de la commande Git : %s"
_messages_["GIT_COMMAND_SUCCESS"]="Commande Git exécutée avec succès."
_messages_["GIT_COMMAND_FAILED"]="La commande Git a échoué."
_messages_["GIT_STATUS"]="Afficher le statut"
_messages_["GIT_LOG"]="Afficher le log"
_messages_["GIT_ENTER_NUMBER_OF_COMMITS"]="Entrez le nombre de commits à afficher :"
_messages_["GIT_BRANCH_MANAGEMENT"]="Gestion des branches"
_messages_["GIT_LIST_BRANCHES"]="Lister toutes les branches"
_messages_["GIT_FETCHING_BRANCHES"]="Récupération de toutes les branches distantes..."
_messages_["GIT_LISTING_BRANCHES"]="Liste des branches..."
_messages_["GIT_SWITCH_BRANCH"]="Changer de branche"
_messages_["GIT_SELECT_BRANCH_TO_SWITCH"]="Sélectionnez une branche vers laquelle basculer :"
_messages_["GIT_NO_BRANCHES_FOUND"]="Aucune branche trouvée."
_messages_["GIT_NO_BRANCH_SELECTED"]="Aucune branche sélectionnée."
_messages_["GIT_CHECKOUT_REMOTE_AS_LOCAL"]="Extraction de la branche distante '%s' en tant que nouvelle branche locale '%s'."
_messages_["GIT_CREATE_NEW_BRANCH"]="Créer une nouvelle branche"
_messages_["GIT_ENTER_NEW_BRANCH_NAME"]="Entrez le nom de la nouvelle branche :"
_messages_["GIT_NEW_BRANCH_NAME_EMPTY"]="Le nom de la nouvelle branche ne peut pas être vide."
_messages_["GIT_PULL"]="Tirer les changements (Pull)"
_messages_["GIT_PUSH"]="Pousser les changements (Push)"
_messages_["GIT_STASH_MANAGEMENT"]="Gestion des stashes"
_messages_["GIT_STASH_SAVE"]="Sauvegarder les changements actuels (Stash)"
_messages_["GIT_ENTER_STASH_MESSAGE"]="Entrez un message pour le stash (optionnel) :"
_messages_["GIT_STASH_LIST"]="Lister les stashes"
_messages_["GIT_STASH_APPLY"]="Appliquer un stash"
_messages_["GIT_ENTER_STASH_REF_TO_APPLY"]="Entrez la référence du stash à appliquer (ex: stash@{0}) :"
_messages_["GIT_STASH_POP"]="Popper un stash (Appliquer et supprimer)"
_messages_["GIT_ENTER_STASH_REF_TO_POP"]="Entrez la référence du stash à popper (ex: stash@{0}) :"
_messages_["GIT_STASH_DROP"]="Supprimer un stash"
_messages_["GIT_ENTER_STASH_REF_TO_DROP"]="Entrez la référence du stash à supprimer (ex: stash@{0}) :"
_messages_["GIT_UNDO_OPERATIONS"]="Opérations d'annulation"
_messages_["GIT_RESET_HARD"]="Reset Hard (Annuler toutes les modifications locales au dernier commit)"
_messages_["GIT_CONFIRM_RESET_HARD"]="AVERTISSEMENT : Cela annulera toutes les modifications non commises et reviendra au dernier commit. Êtes-vous sûr ?"
_messages_["GIT_RESET_HARD_WARNING"]="Git reset --hard exécuté. Toutes les modifications locales sont perdues."
_messages_["GIT_RESET_HARD_CANCELLED"]="Git reset --hard annulé."
_messages_["GIT_REVERT_COMMIT"]="Annuler un commit"
_messages_["GIT_ENTER_COMMIT_HASH_TO_REVERT"]="Entrez le hachage du commit à annuler :"
_messages_["GIT_CONFIRM_REVERT_COMMIT"]="Êtes-vous sûr de vouloir annuler le commit '%s' ?"
_messages_["GIT_REVERT_COMMIT_CANCELLED"]="Annulation du commit annulée."
_messages_["GIT_COMMIT_HASH_EMPTY"]="Le hachage du commit ne peut pas être vide."
_messages_["GIT_CLEAN"]="Nettoyer les fichiers/répertoires non suivis"
_messages_["GIT_CONFIRM_CLEAN"]="AVERTISSEMENT : Cela supprimera tous les fichiers et répertoires non suivis. Êtes-vous sûr ?"
_messages_["GIT_CLEAN_WARNING"]="Git clean exécuté. Fichiers/répertoires non suivis supprimés."
_messages_["GIT_CLEAN_CANCELLED"]="Git clean annulé."

# Composer (core/composer.sh)
_messages_["COMPOSER_MENU_TITLE"]="Gestion Composer"
_messages_["COMPOSER_RUNNING_COMMAND"]="Exécution de Composer %s..."
_messages_["COMPOSER_COMMAND_SUCCESS"]="Commande Composer terminée avec succès."
_messages_["COMPOSER_COMMAND_FAILED"]="La commande Composer a échoué."
_messages_["COMPOSER_INSTALL"]="Exécuter 'composer install'"
_messages_["COMPOSER_RUNNING_INSTALL"]="Exécution de composer install..."
_messages_["COMPOSER_UPDATE"]="Exécuter 'composer update'"
_messages_["COMPOSER_RUNNING_UPDATE"]="Exécution de composer update..."
_messages_["COMPOSER_REQUIRE"]="Exiger un package"
_messages_["COMPOSER_ENTER_PACKAGE_TO_REQUIRE"]="Entrez le nom du package à exiger (ex: drupal/admin_toolbar) :"
_messages_["COMPOSER_REMOVE"]="Supprimer un package"
_messages_["COMPOSER_ENTER_PACKAGE_TO_REMOVE"]="Entrez le nom du package à supprimer :"
_messages_["COMPOSER_PACKAGE_EMPTY"]="Le nom du package ne peut pas être vide."

# Drush (core/drush.sh)
_messages_["DRUSH_MENU_TITLE"]="Gestion Drush"
_messages_["DRUSH_EXECUTING_COMMAND"]="Exécution de la commande Drush : %s"
_messages_["DRUSH_COMMAND_SUCCESS"]="Commande Drush exécutée avec succès."
_messages_["DRUSH_COMMAND_FAILED"]="La commande Drush a échoué."
_messages_["DRUSH_DETECTING_TARGETS"]="Détection des alias Drush et des URIs multi-sites..."
_messages_["DRUSH_CURRENT_SITE"]="site local actuel"
_messages_["DRUSH_ALL_SITES_ALIAS"]="Tous les sites (@sites)"
_messages_["DRUSH_PLEASE_SELECT_TARGET"]="Veuillez sélectionner une cible Drush (alias de site ou URI) :"
_messages_["DRUSH_NO_TARGETS_FOUND"]="Aucun alias Drush ou URI multi-site trouvé."
_messages_["DRUSH_TARGET_SET"]="Cible Drush définie sur : %s"
_messages_["DRUSH_TARGET_NOT_SET"]="Cible Drush non définie. Certaines commandes peuvent échouer."
_messages_["DRUSH_DETECTING_MULTI_SITES"]="Détection des URIs multi-sites à partir de sites.php..."
_messages_["CURRENT_DRUSH_TARGET"]="Cible Drush actuelle : %s"
_messages_["DRUSH_SELECT_TARGET"]="Sélectionner une cible Drush (Site/Alias)"

_messages_["DRUSH_GENERAL_COMMANDS"]="Commandes Générales"
_messages_["DRUSH_GENERAL_MENU_TITLE"]="Drush : Commandes Générales"
_messages_["DRUSH_STATUS"]="Afficher le statut (drush status)"
_messages_["DRUSH_CACHE_REBUILD"]="Reconstruire le cache (drush cr)"

_messages_["DRUSH_CONFIG_COMMANDS"]="Gestion de la Configuration"
_messages_["DRUSH_CONFIG_MENU_TITLE"]="Drush : Gestion de la Configuration"
_messages_["DRUSH_CONFIG_IMPORT"]="Importer la configuration (drush cim)"
_messages_["DRUSH_CONFIG_EXPORT"]="Exporter la configuration (drush cex)"

_messages_["DRUSH_MODULES_THEMES_COMMANDS"]="Modules et Thèmes"
_messages_["DRUSH_MODULES_THEMES_MENU_TITLE"]="Drush : Modules et Thèmes"
_messages_["DRUSH_PM_LIST"]="Lister les modules/thèmes (drush pm:list)"
_messages_["DRUSH_PM_ENABLE"]="Activer Module/Thème (drush pm:enable)"
_messages_["DRUSH_ENTER_MODULE_NAME_TO_ENABLE"]="Entrez le nom du module/thème à activer :"
_messages_["DRUSH_PM_DISABLE"]="Désactiver Module/Thème (drush pm:disable)"
_messages_["DRUSH_ENTER_MODULE_NAME_TO_DISABLE"]="Entrez le nom du module/thème à désactiver :"
_messages_["DRUSH_PM_UNINSTALL"]="Désinstaller Module (drush pm:uninstall)"
_messages_["DRUSH_ENTER_MODULE_NAME_TO_UNINSTALL"]="Entrez le nom du module à désinstaller :"
_messages_["DRUSH_MODULE_NAME_EMPTY"]="Le nom du module/thème ne peut pas être vide."

_messages_["DRUSH_USER_COMMANDS"]="Gestion des Utilisateurs"
_messages_["DRUSH_USER_MENU_TITLE"]="Drush : Gestion des Utilisateurs"
_messages_["DRUSH_USER_LOGIN"]="Générer un lien de connexion utilisateur (drush user:login)"
_messages_["DRUSH_USER_BLOCK"]="Bloquer l'utilisateur (drush user:block)"
_messages_["DRUSH_ENTER_USERNAME_TO_BLOCK"]="Entrez le nom d'utilisateur à bloquer :"
_messages_["DRUSH_USER_UNBLOCK"]="Débloquer l'utilisateur (drush user:unblock)"
_messages_["DRUSH_ENTER_USERNAME_TO_UNBLOCK"]="Entrez le nom d'utilisateur à débloquer :"
_messages_["DRUSH_USER_PASSWORD"]="Définir le mot de passe utilisateur (drush user:password)"
_messages_["DRUSH_ENTER_USERNAME_TO_SET_PASSWORD"]="Entrez le nom d'utilisateur pour définir le mot de passe :"
_messages_["DRUSH_ENTER_NEW_PASSWORD"]="Entrez le nouveau mot de passe :"
_messages_["DRUSH_USERNAME_EMPTY"]="Le nom d'utilisateur ne peut pas être vide."
_messages_["DRUSH_NEW_PASSWORD_EMPTY"]="Le nouveau mot de passe ne peut pas être vide."

_messages_["DRUSH_WATCHDOG_COMMANDS"]="Logs Watchdog"
_messages_["DRUSH_WATCHDOG_MENU_TITLE"]="Drush : Logs Watchdog"
_messages_["DRUSH_WATCHDOG_SHOW"]="Afficher les messages de log récents (drush watchdog:show)"
_messages_["DRUSH_WATCHDOG_LIST"]="Lister les types de messages de log (drush watchdog:list)"
_messages_["DRUSH_WATCHDOG_DELETE"]="Supprimer tous les messages de log (drush watchdog:delete)"
_messages_["DRUSH_WATCHDOG_TAIL"]="Suivre les messages de log récents (drush watchdog:tail) (Appuyez sur Ctrl+C pour quitter)"
_messages_["DRUSH_WATCHDOG_TAIL_EXPLANATION"]="Note : 'drush watchdog:tail' est une commande interactive. Appuyez sur Ctrl+C pour revenir au menu."

_messages_["DRUSH_DEV_TOOLS_COMMANDS"]="Outils de Développement"
_messages_["DRUSH_DEV_TOOLS_MENU_TITLE"]="Drush : Outils de Développement"
_messages_["DRUSH_EVAL_PHP"]="Évaluer le code PHP (drush ev)"
_messages_["DRUSH_ENTER_PHP_CODE"]="Entrez le code PHP à exécuter (ex: 'echo \\Drupal::VERSION;') :"
_messages_["DRUSH_PHP_CODE_EMPTY"]="Le code PHP ne peut pas être vide."
_messages_["DRUSH_PHP_SHELL"]="Shell PHP interactif (drush php)"
_messages_["DRUSH_PHP_SHELL_EXPLANATION"]="Note : 'drush php' ouvre un shell PHP interactif. Tapez 'exit' pour revenir au menu."
_messages_["DRUSH_PHP_SHELL_EXITED"]="Shell PHP Drush quitté."
_messages_["DRUSH_RUN_CRON"]="Exécuter Cron (drush cron)"

_messages_["DRUSH_WEBFORM_COMMANDS"]="Gestion des Webforms"
_messages_["DRUSH_WEBFORM_MENU_TITLE"]="Drush : Gestion des Webforms"
_messages_["DRUSH_WEBFORM_LIST"]="Lister les Webforms (drush webform:list)"
_messages_["DRUSH_WEBFORM_EXPORT"]="Exporter les soumissions de Webform (drush webform:export)"
_messages_["DRUSH_ENTER_WEBFORM_ID_TO_EXPORT"]="Entrez l'ID du Webform pour exporter les soumissions :"
_messages_["DRUSH_WEBFORM_PURGE"]="Purger les soumissions de Webform (drush webform:purge)"
_messages_["DRUSH_ENTER_WEBFORM_ID_TO_PURGE"]="Entrez l'ID du Webform pour purger les soumissions :"
_messages_["DRUSH_WEBFORM_ID_EMPTY"]="L'ID du Webform ne peut pas être vide."

# Database (core/database.sh)
_messages_["DATABASE_MENU_TITLE"]="Gestion de Base de Données"
_messages_["DB_UPDATE_DB"]="Exécuter les mises à jour de la base de données (drush updb)"
_messages_["DB_DUMP"]="Dumper la base de données (drush sql:dump)"
_messages_["DB_ENTER_DUMP_FILENAME"]="Entrez le nom de fichier pour le dump de la base de données :"
_messages_["DB_DUMP_FILENAME_EMPTY"]="Le nom du fichier de dump ne peut pas être vide."
_messages_["DB_CLI"]="Accéder à la CLI SQL (drush sql:cli)"
_messages_["DB_ENTERING_SQL_CLI"]="Entrée dans l'interface de ligne de commande SQL. Tapez 'exit' ou '\\q' pour quitter."
_messages_["DB_EXITED_SQL_CLI"]="Sortie de l'interface de ligne de commande SQL."
_messages_["DB_QUERY"]="Exécuter une requête SQL (drush sql:query)"
_messages_["DB_ENTER_SQL_QUERY"]="Entrez la requête SQL à exécuter :"
_messages_["DB_QUERY_EMPTY"]="La requête SQL ne peut pas être vide."
_messages_["DB_SYNC"]="Synchroniser la base de données (drush sql:sync)"
_messages_["DB_ENTER_SOURCE_ALIAS"]="Entrez l'alias Drush source (ex: @prod) :"
_messages_["DB_SYNC_SOURCE_EMPTY"]="L'alias source ne peut pas être vide."
_messages_["DB_RESTORE"]="Restaurer la base de données à partir d'un dump"
_messages_["DB_RESTORE_SEARCHING_DUMPS"]="Recherche de fichiers de dump de base de données dans '%s'..."
_messages_["DB_RESTORE_NO_DUMPS_FOUND"]="Aucun fichier de dump de base de données trouvé dans '%s'."
_messages_["DB_RESTORE_SELECT_DUMP"]="Sélectionnez un fichier de dump de base de données à restaurer :"
_messages_["DB_RESTORE_NO_DUMP_SELECTED"]="Aucun fichier de dump sélectionné. Restauration annulée."
_messages_["DB_RESTORE_DUMP_NOT_FOUND"]="Fichier de dump non trouvé : %s"
_messages_["DB_RESTORE_NO_DRUSH_TARGET"]="Aucune cible Drush sélectionnée pour la restauration. Veuillez d'abord sélectionner une cible."
_messages_["DB_RESTORE_PROCESSING_DUMP"]="Traitement du fichier de dump '%s' pour la cible '%s'..."
_messages_["DB_RESTORE_EXTRACTING_ZIP"]="Extraction de l'archive ZIP..."
_messages_["DB_RESTORE_ZIP_EXTRACTION_FAILED"]="Échec de l'extraction du fichier ZIP '%s'."
_messages_["DB_RESTORE_EXTRACTING_TAR"]="Extraction de l'archive TAR..."
_messages_["DB_RESTORE_TAR_EXTRACTION_FAILED"]="Échec de l'extraction du fichier TAR '%s'."
_messages_["DB_RESTORE_UNSUPPORTED_FORMAT"]="Format de fichier de dump non pris en charge : %s"
_messages_["DB_RESTORE_EXECUTING_RESTORE"]="Exécution de la restauration de la base de données vers la cible '%s'..."
_messages_["DB_RESTORE_SUCCESS"]="Base de données restaurée avec succès à partir de '%s' vers '%s'."
_messages_["DB_RESTORE_FAILED"]="Échec de la restauration de la base de données à partir de '%s' vers '%s'."
_messages_["DB_RESTORE_POST_UPDATE_SUCCESS"]="Exécution de 'drush updb' et 'drush cr' après la restauration."

# Search API Solr (core/solr.sh)
_messages_["DRUSH_SEARCH_API_SOLR_COMMANDS"]="Search API Solr"
_messages_["SOLR_MENU_TITLE"]="Drush : Search API Solr"
_messages_["SOLR_SERVER_LIST"]="Lister les serveurs Solr (drush search-api:server-list)"
_messages_["SOLR_INDEX_LIST"]="Lister les index Solr (drush search-api:index-list)"
_messages_["SOLR_EXPORT_CONFIG"]="Exporter les configurations Solr (drush search-api-solr:export-solr-config)"
_messages_["SOLR_SELECT_SERVER_TO_EXPORT"]="Sélectionnez un serveur Solr pour exporter les configurations :"
_messages_["SOLR_NO_SERVERS_FOUND"]="Aucun serveur Solr trouvé."
_messages_["SOLR_NO_SERVER_SELECTED"]="Aucun serveur Solr sélectionné."
_messages_["SOLR_EXPORTING_CONFIG"]="Exportation des configurations Solr pour '%s' vers '%s'..."
_messages_["SOLR_EXPORT_CONFIG_SUCCESS"]="Configurations Solr exportées avec succès vers '%s'."
_messages_["SOLR_EXPORT_CONFIG_FAILED"]="Échec de l'exportation des configurations Solr."
_messages_["SOLR_INDEX_CONTENT"]="Indexer le contenu (drush search-api:index)"
_messages_["SOLR_SELECT_INDEX_TO_INDEX"]="Sélectionnez un index à ré-indexer :"
_messages_["SOLR_NO_INDEXES_FOUND"]="Aucun index Search API trouvé."
_messages_["SOLR_NO_INDEX_SELECTED"]="Aucun index sélectionné."
_messages_["SOLR_INDEXING"]="Indexation du contenu pour l'index '%s'..."
_messages_["SOLR_INDEX_SUCCESS"]="Contenu indexé avec succès."
_messages_["SOLR_INDEX_FAILED"]="L'indexation du contenu a échoué."
_messages_["SOLR_CLEAR_INDEX"]="Vider l'index (drush search-api:clear)"
_messages_["SOLR_SELECT_INDEX_TO_CLEAR"]="Sélectionnez un index à vider :"
_messages_["SOLR_CONFIRM_CLEAR_INDEX"]="AVERTISSEMENT : Cela videra toutes les données indexées pour '%s'. Êtes-vous sûr ?"
_messages_["SOLR_CLEARING_INDEX"]="Vidage de l'index '%s'..."
_messages_["SOLR_CLEAR_SUCCESS"]="Index vidé avec succès."
_messages_["SOLR_CLEAR_FAILED"]="Échec du vidage de l'index."
_messages_["SOLR_CLEAR_CANCELLED"]="Vidage de l'index annulé."
_messages_["SOLR_STATUS"]="Afficher le statut de Search API (drush search-api:status)"

# IBM Cloud (core/ibmcloud.sh)
_messages_["IBMCLOUD_MENU_TITLE"]="Intégration IBM Cloud"
_messages_["IBMCLOUD_CLI_NOT_FOUND"]="La CLI IBM Cloud (ibmcloud) n'a pas été trouvée. Veuillez l'installer."
_messages_["IBMCLOUD_LOGIN"]="Se connecter à IBM Cloud"
_messages_["IBMCLOUD_ENTER_REGION"]="Entrez la région IBM Cloud (ex: eu-de) :"
_messages_["IBMCLOUD_REGION_EMPTY"]="La région IBM Cloud ne peut pas être vide."
_messages_["IBMCLOUD_ENTER_RESOURCE_GROUP"]="Entrez le groupe de ressources IBM Cloud (ex: Default) :"
_messages_["IBMCLOUD_RESOURCE_GROUP_EMPTY"]="Le groupe de ressources IBM Cloud ne peut pas être vide."
_messages_["IBMCLOUD_LOGGING_IN"]="Connexion à IBM Cloud (Région : %s, Groupe de ressources : %s)..."
_messages_["IBMCLOUD_LOGIN_SUCCESS"]="Connecté avec succès à IBM Cloud."
_messages_["IBMCLOUD_LOGIN_FAILED"]="Échec de la connexion à IBM Cloud."
_messages_["IBMCLOUD_LOGOUT"]="Se déconnecter d'IBM Cloud"
_messages_["IBMCLOUD_LOGGING_OUT"]="Déconnexion d'IBM Cloud..."
_messages_["IBMCLOUD_LOGOUT_SUCCESS"]="Déconnecté avec succès d'IBM Cloud."
_messages_["IBMCLOUD_LOGOUT_FAILED"]="Échec de la déconnexion d'IBM Cloud."
_messages_["IBMCLOUD_LIST_KUBERNETES_CLUSTERS"]="Lister les clusters Kubernetes"
_messages_["IBMCLOUD_NO_KUBERNETES_CLUSTERS_FOUND"]="Aucun cluster Kubernetes trouvé dans votre compte IBM Cloud."
_messages_["IBMCLOUD_CONFIGURE_KUBECTL"]="Configurer kubectl pour un cluster"
_messages_["IBMCLOUD_SELECT_KUBERNETES_CLUSTER"]="Sélectionnez un cluster Kubernetes pour configurer kubectl :"
_messages_["IBMCLOUD_CONFIGURING_KUBECTL"]="Configuration de kubectl pour le cluster '%s'..."
_messages_["IBMCLOUD_KUBECTL_CONFIG_SUCCESS"]="kubectl configuré avec succès pour le cluster '%s'."
_messages_["IBMCLOUD_KUBECTL_CONFIG_FAILED"]="Échec de la configuration de kubectl pour le cluster '%s'."
_messages_["IBMCLOUD_KUBECTL_CONTEXT_SET"]="Contexte kubectl actuel :"
_messages_["IBMCLOUD_NO_CLUSTER_SELECTED"]="Aucun cluster sélectionné."

# Kubernetes (core/k8s.sh)
_messages_["KUBECTL_MENU_TITLE"]="Gestion Kubernetes (kubectl)"
_messages_["KUBECTL_CLI_NOT_FOUND"]="La CLI kubectl n'a pas été trouvée. Veuillez l'installer."
_messages_["KUBECTL_NO_CONTEXT_SET"]="Le contexte kubectl n'est pas défini. Veuillez vous connecter à IBM Cloud et configurer kubectl."
_messages_["KUBECTL_CURRENT_CONTEXT"]="Contexte kubectl actuel : %s"
_messages_["KUBECTL_CLI_NOT_READY"]="kubectl n'est pas prêt. Veuillez vous assurer qu'il est installé et configuré."
_messages_["KUBECTL_NO_NAMESPACES_FOUND"]="Aucun espace de noms Kubernetes trouvé."
_messages_["KUBECTL_SELECT_NAMESPACE"]="Sélectionnez un espace de noms Kubernetes :"
_messages_["KUBECTL_USING_DEFAULT_NAMESPACE"]="Utilisation de l'espace de noms par défaut : %s"
_messages_["KUBECTL_NO_NAMESPACE_SELECTED"]="Aucun espace de noms sélectionné."
_messages_["KUBECTL_FILTERING_PODS_BY_LABEL"]="Filtrage des pods par étiquette : %s"
_messages_["KUBECTL_NO_PODS_FOUND"]="Aucun pod trouvé dans l'espace de noms '%s'."
_messages_["KUBECTL_SELECT_POD"]="Sélectionnez un pod Kubernetes :"
_messages_["KUBECTL_NO_POD_SELECTED"]="Aucun pod sélectionné."
_messages_["KUBECTL_POD_NAME_MISSING"]="Le nom du pod est manquant."
_messages_["KUBECTL_NO_CONTAINERS_FOUND"]="Aucun conteneur trouvé dans le pod '%s'."
_messages_["KUBECTL_AUTO_SELECT_SINGLE_CONTAINER"]="Conteneur unique sélectionné automatiquement : %s"
_messages_["KUBECTL_SELECT_CONTAINER"]="Sélectionnez un conteneur dans le pod :"
_messages_["KUBECTL_NO_CONTAINER_SELECTED"]="Aucun conteneur sélectionné."
_messages_["KUBECTL_COPY_FILES"]="Copier des fichiers vers un Pod (kubectl cp)"
_messages_["KUBECTL_COPY_MISSING_PATHS"]="Chemin source local ou chemin de destination distant manquant."
_messages_["KUBECTL_ENTER_LOCAL_SOURCE_PATH"]="Entrez le chemin source local (fichier ou répertoire) :"
_messages_["KUBECTL_ENTER_REMOTE_DEST_PATH"]="Entrez le chemin de destination distant dans le conteneur (ex: /app/data/) :"
_messages_["KUBECTL_PATH_EMPTY"]="Le chemin ne peut pas être vide."
_messages_["KUBECTL_COPYING_FILES"]="Copie de '%s' vers '%s' dans le conteneur '%s'..."
_messages_["KUBECTL_COPY_SUCCESS"]="Fichiers copiés avec succès."
_messages_["KUBECTL_COPY_FAILED"]="Échec de la copie de fichiers."

_messages_["KUBECTL_SOLR_COMMANDS"]="Gestion des Pods Solr"
_messages_["KUBECTL_SOLR_MENU_TITLE"]="Kubernetes : Pods Solr"
_messages_["KUBECTL_LIST_SOLR_PODS"]="Lister les Pods Solr"
_messages_["KUBECTL_RESTART_SOLR_POD"]="Redémarrer le Pod Solr"
_messages_["KUBECTL_NO_SOLR_POD_SELECTED"]="Aucun pod Solr sélectionné."
_messages_["KUBECTL_CONFIRM_RESTART_SOLR_POD"]="Êtes-vous sûr de vouloir supprimer et redémarrer le pod Solr '%s' ?"
_messages_["KUBECTL_RESTARTING_SOLR_POD"]="Redémarrage du pod Solr '%s'..."
_messages_["KUBECTL_RESTART_SUCCESS"]="Le pod '%s' a redémarré avec succès."
_messages_["KUBECTL_RESTART_FAILED"]="Échec du redémarrage du pod '%s'."
_messages_["KUBECTL_RESTART_CANCELLED"]="Redémarrage du pod annulé."
_messages_["KUBECTL_VIEW_SOLR_LOGS"]="Voir les Logs du Pod Solr"
_messages_["KUBECTL_NO_SOLR_CONTAINER_SELECTED"]="Aucun conteneur Solr sélectionné."
_messages_["KUBECTL_VIEWING_SOLR_LOGS"]="Affichage des logs pour le pod/conteneur Solr '%s'. Appuyez sur Ctrl+C pour quitter."
_messages_["KUBECTL_LISTING_SOLR_PODS"]="Liste des pods Solr dans l'espace de noms '%s'..."

_messages_["KUBECTL_PGSQL_COMMANDS"]="Gestion des Pods PostgreSQL"
_messages_["KUBECTL_PGSQL_MENU_TITLE"]="Kubernetes : Pods PostgreSQL"
_messages_["KUBECTL_LIST_PGSQL_PODS"]="Lister les Pods PostgreSQL"
_messages_["KUBECTL_NO_PGSQL_POD_SELECTED"]="Aucun pod PostgreSQL sélectionné."
_messages_["KUBECTL_ACCESS_PGSQL_CLI"]="Accéder à la CLI PostgreSQL"
_messages_["KUBECTL_NO_PGSQL_CONTAINER_SELECTED"]="Aucun conteneur PostgreSQL sélectionné."
_messages_["KUBECTL_ACCESSING_PGSQL_CLI"]="Accès à la CLI psql dans le pod/conteneur '%s'. Tapez '\\q' ou Ctrl+D pour quitter."
_messages_["KUBECTL_VIEW_PGSQL_LOGS"]="Voir les Logs du Pod PostgreSQL"
_messages_["KUBECTL_VIEWING_PGSQL_LOGS"]="Affichage des logs pour le pod/conteneur PostgreSQL '%s'. Appuyez sur Ctrl+C pour quitter."
_messages_["KUBECTL_LISTING_PGSQL_PODS"]="Liste des pods PostgreSQL dans l'espace de noms '%s'..."

# Settings (core/main.sh, helpers/config.sh)
_messages_["AUB_TOOLS_SETTINGS"]="Paramètres des AUB Tools"
_messages_["SETTINGS_MENU_TITLE"]="Paramètres des AUB Tools"
_messages_["SETTING_LANGUAGE"]="Langue"
_messages_["SELECT_LANGUAGE"]="Sélectionnez la langue préférée :"
_messages_["LANGUAGE_FRENCH"]="Français"
_messages_["LANGUAGE_ENGLISH"]="Anglais"
_messages_["LANGUAGE_NAME"]="Français" # This key is special, overridden by current language setting
_messages_["LANGUAGE_SET_SUCCESS"]="Langue définie sur %s."
_messages_["NO_LANGUAGE_SELECTED"]="Aucune langue sélectionnée."

_messages_["SETTING_PROJECT_ROOT"]="Répertoire racine par défaut des projets"
_messages_["ENTER_PROJECTS_ROOT_PATH"]="Entrez le répertoire racine par défaut de vos projets (ex: ${HOME}/workspace) :"
_messages_["PROJECT_ROOT_SET_SUCCESS"]="Répertoire racine par défaut des projets défini sur : %s"
_messages_["INVALID_PATH_OR_EMPTY"]="Chemin invalide ou vide. Veuillez entrer un répertoire valide."

_messages_["SETTING_LOG_LEVEL"]="Niveau de journalisation"
_messages_["SELECT_LOG_LEVEL"]="Sélectionnez le niveau de verbosité de journalisation :"
_messages_["LOG_LEVEL_SET_SUCCESS"]="Niveau de log défini sur : %s"
_messages_["NO_LOG_LEVEL_SELECTED"]="Aucun niveau de log sélectionné."

_messages_["SETTING_ENABLE_HISTORY"]="Activer l'historique des commandes"
_messages_["ENABLE_HISTORY_PROMPT"]="Activer la journalisation de l'historique des commandes ? (actuel : %s)"
_messages_["SETTING_ENABLE_FAVORITES"]="Activer les Favoris/Raccourcis personnalisés"
_messages_["ENABLE_FAVORITES_PROMPT"]="Activer les favoris/raccourcis personnalisés ? (actuel : %s)"
_messages_["SETTING_ENABLE_ERROR_REPORTING"]="Activer les rapports d'erreurs"
_messages_["ENABLE_ERROR_REPORTING_PROMPT"]="Activer les rapports d'erreurs détaillés en cas d'échec ? (actuel : %s)"
_messages_["SETTING_UPDATED_SUCCESS"]="Paramètre mis à jour avec succès !"

_messages_["SETTING_IBMCLOUD_CONFIG"]="Configurations IBM Cloud"
_messages_["SETTINGS_IBMCLOUD_MENU_TITLE"]="Paramètres : IBM Cloud"
_messages_["SETTING_IBMCLOUD_REGION"]="Région IBM Cloud"
_messages_["ENTER_IBMCLOUD_REGION"]="Entrez la région IBM Cloud par défaut (ex: eu-de) :"
_messages_["SETTING_IBMCLOUD_RESOURCE_GROUP"]="Groupe de ressources IBM Cloud"
_messages_["ENTER_IBMCLOUD_RESOURCE_GROUP"]="Entrez le groupe de ressources IBM Cloud par défaut (ex: Default) :"
_messages_["SETTING_IBMCLOUD_ACCOUNT"]="ID Compte IBM Cloud"
_messages_["ENTER_IBMCLOUD_ACCOUNT"]="Entrez l'ID de compte IBM Cloud par défaut :"

# History (helpers/history.sh)
_messages_["HISTORY_MENU_TITLE"]="Historique des Commandes"
_messages_["HISTORY_FILE_LOCATION"]="Emplacement du fichier d'historique : %s"
_messages_["HISTORY_EMPTY"]="L'historique des commandes est vide."
_messages_["HISTORY_RECENT_ACTIONS"]="Actions récentes :"
_messages_["HISTORY_ADDED_ENTRY"]="Entrée ajoutée à l'historique."
_messages_["HISTORY_SELECT_TO_RELAUNCH"]="Sélectionnez une commande à relancer :"
_messages_["HISTORY_NO_SELECTION"]="Aucune commande sélectionnée dans l'historique."
_messages_["HISTORY_INVALID_INDEX"]="Index d'historique invalide. Veuillez entrer un nombre."
_messages_["HISTORY_COMMAND_NOT_FOUND_AT_INDEX"]="Commande non trouvée à l'index d'historique %s."
_messages_["HISTORY_RELAUNCHING_COMMAND"]="Relancement de la commande : %s"
_messages_["HISTORY_COMMAND_RELAUNCH_SUCCESS"]="Commande relancée avec succès."
_messages_["HISTORY_COMMAND_RELAUNCH_FAILED"]="Échec du relancement de la commande."

# Favorites (helpers/favorites.sh)
_messages_["FAVORITES_MENU_TITLE"]="Favoris Personnalisés"
_messages_["FAVORITES_FILE_LOCATION"]="Emplacement du fichier des favoris : %s"
_messages_["FAVORITES_CREATING_FILE"]="Création du fichier des favoris : %s"
_messages_["FAVORITES_FILE_CREATED"]="Fichier des favoris créé. Vous pouvez le modifier pour ajouter vos fonctions personnalisées."
_messages_["FAVORITES_NO_FAVORITES_FOUND"]="Aucun favori personnalisé (fonction) trouvé dans %s."
_messages_["FAVORITES_NO_FAVORITES_TO_SHOW"]="Aucun favori personnalisé défini pour le moment. Modifiez '%s' pour en ajouter !"
_messages_["FAVORITES_SELECT_TO_RUN"]="Sélectionnez un favori à exécuter :"
_messages_["FAVORITES_NO_SELECTION"]="Aucun favori sélectionné."
_messages_["FAVORITES_NO_FAVORITE_SELECTED"]="Aucun favori sélectionné à exécuter."
_messages_["FAVORITES_RUNNING"]="Exécution du favori : %s"
_messages_["FAVORITES_RUN_SUCCESS"]="Favori exécuté avec succès."
_messages_["FAVORITES_RUN_FAILED"]="L'exécution du favori a échoué."
_messages_["FAVORITES_NOT_A_FUNCTION"]="'%s' n'est pas une fonction appelable dans le fichier des favoris."

# Feature Disabled
_messages_["FEATURE_DISABLED"]="La fonctionnalité '%s' est actuellement désactivée dans les paramètres."

# Error Reporting (helpers/report.sh)
_messages_["REPORT_ERROR_DETECTED"]="Une erreur a été détectée."
_messages_["REPORT_GENERATE_REPORT_PROMPT"]="Voulez-vous générer un rapport d'erreur détaillé pour le débogage ?"
_messages_["REPORT_GENERATION_CANCELLED"]="Génération du rapport d'erreur annulée."
_messages_["REPORT_GENERATING_FILE"]="Génération du rapport d'erreur vers : %s"
_messages_["REPORT_GENERATED_SUCCESS"]="Rapport d'erreur généré avec succès : %s"
_messages_["REPORT_PLEASE_SHARE"]="Veuillez partager ce rapport avec l'équipe de développement pour analyse."
_messages_["ERROR_UNEXPECTED"]="Une erreur inattendue est survenue dans %s : '%s'"

# Logging (helpers/log.sh) - These are for internal log messages, not directly displayed in menus
_messages_["LOG_LEVEL_DEBUG"]="DÉBOGAGE"
_messages_["LOG_LEVEL_INFO"]="INFO"
_messages_["LOG_LEVEL_WARN"]="ATTENTION"
_messages_["LOG_LEVEL_ERROR"]="ERREUR"
_messages_["LOG_LEVEL_SUCCESS"]="SUCCÈS"
EOF

    install_log "SUCCESS" "Language files created."
}

# --- Create main executable script ---
create_main_executable() {
    install_log "INFO" "Creating main executable script..."

    # bin/aub-tools
    cat << 'EOF' > "${BIN_DIR}/aub-tools"
#!/bin/bash

# AUB Tools - bin/aub-tools
# This is the main entry point for the AUB Tools application.

# Define base directories relative to this script's location
# Using dirname $0 to get the directory of the script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
INSTALL_DIR="$(dirname "${SCRIPT_DIR}")" # Parent directory of bin/

# Exporting these for child scripts to use
export INSTALL_DIR
export BIN_DIR="${INSTALL_DIR}/bin"
export CORE_DIR="${INSTALL_DIR}/core"
export HELPERS_DIR="${INSTALL_DIR}/helpers"
export LANG_DIR="${INSTALL_DIR}/lang"
export TEMP_DIR="/tmp/aub-tools" # Ensure this matches install.sh

# Source the main menu script which loads all other dependencies
source "${CORE_DIR}/main.sh"

# Set a trap to handle unexpected errors gracefully, if error reporting is enabled
# This trap must be set *after* the logging functions are sourced.
if [[ "${AUB_TOOLS_ENABLE_ERROR_REPORTING:-true}" == "true" ]]; then
    trap 'trap_error_handler' ERR
fi

# Call the main menu function to start the interactive interface
main_menu

EOF

    chmod +x "${BIN_DIR}/aub-tools" || { install_log "ERROR" "Failed to make ${BIN_DIR}/aub-tools executable."; exit 1; }
    install_log "SUCCESS" "Main executable script created."
}

# --- Main installation logic ---
main_install() {
    install_log "INFO" "Starting AUB Tools installation..."

    # Check if AUB Tools is already installed
    if [ -d "$INSTALL_DIR" ]; then
        install_log "WARN" "AUB Tools already exists at ${INSTALL_DIR}."
        if prompt_confirm "Do you want to reinstall AUB Tools (this will remove existing installation)?"; then
            install_log "INFO" "Removing existing AUB Tools installation..."
            rm -rf "${INSTALL_DIR}" || { install_log "ERROR" "Failed to remove existing installation."; exit 1; }
            install_log "SUCCESS" "Existing installation removed."
        else
            install_log "INFO" "Installation cancelled by user."
            exit 0
        fi
    fi

    setup_proxy
    create_directories
    download_jq
    create_helper_files
    create_lang_files
    create_core_files # Core files created after helpers and langs as they depend on them
    create_main_executable

    # Add aub-tools to PATH if not already there
    if ! grep -q "export PATH=\"${BIN_DIR}:\$PATH\"" "${HOME}/.bashrc" 2>/dev/null && \
       ! grep -q "export PATH=\"${BIN_DIR}:\$PATH\"" "${HOME}/.zshrc" 2>/dev/null; then
        install_log "INFO" "Adding AUB Tools to PATH for future sessions."
        if [ -f "${HOME}/.bashrc" ]; then
            echo -e "\n# AUB Tools Path" >> "${HOME}/.bashrc"
            echo "export PATH=\"${BIN_DIR}:\$PATH\"" >> "${HOME}/.bashrc"
            install_log "INFO" "Added to ~/.bashrc"
        fi
        if [ -f "${HOME}/.zshrc" ]; then
            echo -e "\n# AUB Tools Path" >> "${HOME}/.zshrc"
            echo "export PATH=\"${BIN_DIR}:\$PATH\"" >> "${HOME}/.zshrc"
            install_log "INFO" "Added to ~/.zshrc"
        fi
        install_log "INFO" "Please restart your terminal or run 'source ~/.bashrc' or 'source ~/.zshrc' to use 'aub-tools' command directly."
    else
        install_log "INFO" "AUB Tools is already in your PATH."
    fi

    restore_proxy # Restore proxy settings
    install_log "SUCCESS" "AUB Tools installation complete!"
    install_log "INFO" "You can now run 'aub-tools' from your terminal (you might need to restart your terminal first)."
}

# Execute the main installation function
main_install
