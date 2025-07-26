#!/bin/bash

# install.sh
# This script automates the installation of AUB Tools.

set -e

# --- Configuration ---
INSTALL_DIR="${HOME}/.aub-tools"
BIN_DIR="${INSTALL_DIR}/bin"
CORE_DIR="${INSTALL_DIR}/core"
LANG_DIR="${INSTALL_DIR}/lang"
HELPERS_DIR="${INSTALL_DIR}/helpers"

JQ_DOWNLOAD_URL="https://github.com/stedolan/jq/releases/download/jq-1.7.1/jq-linux64" # Adjust for other OS if needed
JQ_BIN_PATH="${BIN_DIR}/jq"

# --- Functions ---

log_info() {
    echo -e "\e[34m[INFO]\e[0m $1"
}

log_success() {
    echo -e "\e[32m[SUCCESS]\e[0m $1"
}

log_error() {
    echo -e "\e[31m[ERROR]\e[0m $1"
}

# Check for a specific command
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Download jq binary
download_jq() {
    log_info "Checking for jq..."
    if command_exists "jq"; then
        log_info "jq is already installed. Checking version..."
        CURRENT_JQ_VERSION=$(jq --version | awk '{print $NF}' | sed 's/jq-//')
        REQUIRED_JQ_VERSION=$(basename "$JQ_DOWNLOAD_URL" | sed 's/jq-linux64//' | sed 's/jq-//' | cut -d'-' -f1) # Extracting version from URL

        # Simple version comparison, assumes format like 1.6, 1.7
        if (( $(echo "$CURRENT_JQ_VERSION < $REQUIRED_JQ_VERSION" | bc -l) )); then
            log_warn "Installed jq version ($CURRENT_JQ_VERSION) is older than recommended ($REQUIRED_JQ_VERSION). Updating..."
            do_download_jq
        else
            log_success "jq version ($CURRENT_JQ_VERSION) is up to date."
        fi
    else
        log_info "jq not found. Downloading it for AUB Tools."
        do_download_jq
    fi
}

do_download_jq() {
    mkdir -p "$BIN_DIR"
    log_info "Downloading jq from $JQ_DOWNLOAD_URL to $JQ_BIN_PATH"
    if curl -sL "$JQ_DOWNLOAD_URL" -o "$JQ_BIN_PATH"; then
        chmod +x "$JQ_BIN_PATH"
        log_success "jq downloaded and made executable."
    else
        log_error "Failed to download jq. Please install it manually or check your internet connection."
        exit 1
    fi
}


# Create directory structure
create_directories() {
    log_info "Creating AUB Tools directories..."
    mkdir -p "$BIN_DIR"
    mkdir -p "$CORE_DIR"
    mkdir -p "$LANG_DIR/en_US"
    mkdir -p "$LANG_DIR/fr_FR"
    mkdir -p "$HELPERS_DIR"
    log_success "Directories created."
}

# Create core files with initial content
create_core_files() {
    log_info "Creating core files..."

    # bin/aub-tools
    cat <<EOF > "${BIN_DIR}/aub-tools"
#!/bin/bash

# bin/aub-tools
# Main entry point for AUB Tools.

# Source helper and core scripts
export AUB_TOOLS_PATH="\$(dirname "\$(dirname "\$(readlink -f "\$0")")")"

source "\${AUB_TOOLS_PATH}/helpers/config.sh"
source "\${AUB_TOOLS_PATH}/helpers/utils.sh"
source "\${AUB_TOOLS_PATH}/helpers/log.sh"
source "\${AUB_TOOLS_PATH}/helpers/i18n.sh"
source "\${AUB_TOOLS_PATH}/helpers/menu.sh"
source "\${AUB_TOOLS_PATH}/helpers/prompt.sh"
source "\${AUB_TOOLS_PATH}/helpers/report.sh"
source "\${A_TOOLS_PATH}/helpers/history.sh"
source "\${AUB_TOOLS_PATH}/helpers/favorites.sh"

source "\${AUB_TOOLS_PATH}/core/main.sh"
source "\${AUB_TOOLS_PATH}/core/project.sh"
source "\${AUB_TOOLS_PATH}/core/git.sh"
source "\${AUB_TOOLS_PATH}/core/drush.sh"
source "\${AUB_TOOLS_PATH}/core/database.sh"
source "\${AUB_TOOLS_PATH}/core/solr.sh"
source "\${AUB_TOOLS_PATH}/core/ibmcloud.sh"
source "\${AUB_TOOLS_PATH}/core/k8s.sh"
source "\${AUB_TOOLS_PATH}/core/composer.sh"

# Initialize i18n
initialize_i18n

# Initialize logging
initialize_logging

# Display header
display_header() {
    clear
    log_info_no_log "========================================"
    log_info_no_log "${TXT_AUBAY_DEVTOOLS_HEADER}"
    log_info_no_log "========================================"
    echo ""
}

# Main application logic
main() {
    display_header
    main_menu
}

# Call the main function
main
EOF
    chmod +x "${BIN_DIR}/aub-tools"

    # helpers/config.sh
    cat <<EOF > "${HELPERS_DIR}/config.sh"
#!/bin/bash

# helpers/config.sh
# Configuration settings for AUB Tools.

# Tool installation path
AUB_TOOLS_PATH="\$(dirname "\$(dirname "\$(readlink -f "\$0")")")"

# --- General Configuration ---
# Default language (en_US or fr_FR)
DEFAULT_LANG="fr_FR"

# Log Level (DEBUG, INFO, WARN, ERROR, SUCCESS)
# Higher verbosity means more messages are displayed.
# DEBUG: All messages
# INFO: General information and progress
# WARN: Warnings, non-critical issues
# ERROR: Critical errors
# SUCCESS: Success messages
LOG_LEVEL="INFO" # Default level

# Temporary directory for logs and reports
TEMP_DIR="/tmp/aub-tools"
mkdir -p "\${TEMP_DIR}" # Ensure temp directory exists

# --- Feature Flags ---
# Enable/Disable command history (true/false)
ENABLE_HISTORY=true
HISTORY_FILE="\${HOME}/.aub-tools_history"

# Enable/Disable favorites/custom shortcuts (true/false)
ENABLE_FAVORITES=true
FAVORITES_FILE="\${HOME}/.aub-tools_favorites.sh"

# Enable/Disable error reporting (true/false)
ENABLE_ERROR_REPORTING=true

# --- Project Configuration ---
# Default Drupal root directory relative to project root
# Common values: 'src', 'web', 'docroot', 'public', 'html'
DRUPAL_DEFAULT_ROOT_DIR="src"

# Path to the directory where your Drupal projects are located
# This can be set by the user via the configuration menu.
PROJECTS_ROOT_PATH="\${HOME}/aub-projects" # Example default

# --- IBM Cloud / Kubernetes Configuration ---
IBMCLOUD_DEFAULT_REGION="eu-de"
IBMCLOUD_DEFAULT_RESOURCE_GROUP="Default"
IBMCLOUD_DEFAULT_ACCOUNT_ID="" # Will be prompted if not set

# --- Proxy Configuration (Optional) ---
# Set these if you are behind a corporate proxy
# HTTP_PROXY=""
# HTTPS_PROXY=""
# NO_PROXY="localhost,127.0.0.1"

# --- External Dependencies ---
JQ_BIN="\${AUB_TOOLS_PATH}/bin/jq"
# Other dependencies like Drush, Composer, Git, Kubectl, IBM Cloud CLI are expected to be in system PATH.

# Ensure JQ_BIN is executable
if [[ -f "\${JQ_BIN}" ]]; then
    chmod +x "\${JQ_BIN}"
fi
EOF

    # lang/en_US/messages.sh
    cat <<EOF > "${LANG_DIR}/en_US/messages.sh"
#!/bin/bash

# lang/en_US/messages.sh
# English translation messages for AUB Tools.

# Header
TXT_AUBAY_DEVTOOLS_HEADER="AUBAY DevTools 1.0"

# Main Menu
TXT_MAIN_MENU_TITLE="Main Menu"
TXT_MAIN_MENU_PROJECT="Project Management"
TXT_MAIN_MENU_GIT="Git Management"
TXT_MAIN_MENU_DRUSH="Drush Commands"
TXT_MAIN_MENU_DATABASE="Database Management"
TXT_MAIN_MENU_SOLR="Search API Solr Management"
TXT_MAIN_MENU_IBMCLOUD="IBM Cloud Integration"
TXT_MAIN_MENU_K8S="Kubernetes Management"
TXT_MAIN_MENU_CONFIG="Configuration"
TXT_MAIN_MENU_HISTORY="Command History"
TXT_MAIN_MENU_FAVORITES="Custom Favorites"
TXT_MAIN_MENU_EXIT="Exit"

# General messages
TXT_SELECT_OPTION="Select an option:"
TXT_PRESS_ENTER_TO_CONTINUE="Press ENTER to continue..."
TXT_INVALID_OPTION="Invalid option. Please try again."
TXT_OPERATION_CANCELLED="Operation cancelled."
TXT_NOT_IMPLEMENTED="This feature is not yet implemented."
TXT_ERROR_REPORT_GENERATED="An error occurred. A detailed error report has been generated at: %s"
TXT_PATH_NOT_FOUND="Path not found: %s"
TXT_CURRENT_PROJECT="Current Project: %s (Drupal Root: %s)"
TXT_NO_PROJECT_DETECTED="No Drupal project detected in the current path or its parents."
TXT_ENTER_VALUE_FOR="Enter value for %s: "
TXT_SUCCESS="Success."
TXT_FAILURE="Failure."

# Project Management
TXT_PROJECT_MENU_TITLE="Project Management"
TXT_PROJECT_MENU_INIT="Initialize New Drupal Project"
TXT_PROJECT_MENU_DETECT="Detect Current Project"
TXT_PROJECT_MENU_GENERATE_ENV="Generate .env from .env.dist"
TXT_PROJECT_MENU_BACK="Back to Main Menu"

# Git Management
TXT_GIT_MENU_TITLE="Git Management"
TXT_GIT_MENU_STATUS="Show Status"
TXT_GIT_MENU_LOG="Show Commit History"
TXT_GIT_MENU_BRANCHES="Branch Management"
TXT_GIT_MENU_PULL="Pull Changes"
TXT_GIT_MENU_PUSH="Push Changes"
TXT_GIT_MENU_STASH="Stash Management"
TXT_GIT_MENU_UNDO="Undo Changes"
TXT_GIT_MENU_BACK="Back to Main Menu"

TXT_GIT_BRANCH_MENU_TITLE="Branch Management"
TXT_GIT_BRANCH_LIST="List All Branches"
TXT_GIT_BRANCH_CHECKOUT="Switch to Existing Branch"
TXT_GIT_BRANCH_CREATE="Create New Branch"
TXT_GIT_BRANCH_BACK="Back to Git Menu"
TXT_ENTER_NEW_BRANCH_NAME="Enter new branch name: "
TXT_ENTER_EXISTING_BRANCH_NAME="Enter existing branch name: "

TXT_GIT_STASH_MENU_TITLE="Stash Management"
TXT_GIT_STASH_SAVE="Save Changes to Stash"
TXT_GIT_STASH_LIST="List Stashes"
TXT_GIT_STASH_APPLY="Apply Stash"
TXT_GIT_STASH_POP="Pop Stash"
TXT_GIT_STASH_DROP="Drop Stash"
TXT_GIT_STASH_BACK="Back to Git Menu"
TXT_ENTER_STASH_INDEX="Enter stash index (e.g., stash@{0}): "

TXT_GIT_UNDO_MENU_TITLE="Undo Changes"
TXT_GIT_UNDO_RESET_HARD="Reset Hard (Discard all local changes)"
TXT_GIT_UNDO_REVERT="Revert Last Commit"
TXT_GIT_UNDO_CLEAN="Clean Untracked Files/Directories"
TXT_GIT_UNDO_BACK="Back to Git Menu"
TXT_CONFIRM_RESET_HARD="WARNING: This will discard all local changes and untracked files. Are you sure? (yes/no): "
TXT_CONFIRM_CLEAN="WARNING: This will remove untracked files and directories. Are you sure? (yes/no): "

# Drush Management
TXT_DRUSH_MENU_TITLE="Drush Commands"
TXT_DRUSH_SELECT_TARGET="Select Drush Target (site/alias):"
TXT_DRUSH_TARGET_ALL_SITES="ALL Sites (@sites)"
TXT_DRUSH_TARGET_CURRENTLY_SELECTED="Currently selected Drush target: %s"
TXT_DRUSH_NO_ALIAS_FOUND="No Drush aliases or multi-sites found."
TXT_DRUSH_ALIAS_NOT_SET="Drush alias not set. Please select one."
TXT_DRUSH_GENERAL_MENU="General Commands"
TXT_DRUSH_CONFIG_MENU="Configuration Management"
TXT_DRUSH_MODULE_THEME_MENU="Module/Theme Management"
TXT_DRUSH_USER_MENU="User Management"
TXT_DRUSH_WATCHDOG_MENU="Watchdog Management"
TXT_DRUSH_WEBFORM_MENU="Webform Management"
TXT_DRUSH_DEV_TOOLS_MENU="Development Tools"
TXT_DRUSH_BACK="Back to Main Menu"

TXT_DRUSH_GENERAL_COMMANDS_MENU_TITLE="Drush General Commands"
TXT_DRUSH_STATUS="Show Drush Status"
TXT_DRUSH_CR="Clear Caches (drush cr)"
TXT_DRUSH_UPDB="Run Database Updates (drush updb)"
TXT_DRUSH_BACK_TO_DRUSH="Back to Drush Menu"

TXT_DRUSH_CONFIG_MENU_TITLE="Drush Configuration Management"
TXT_DRUSH_CIM="Import Configuration (drush cim)"
TXT_DRUSH_CEX="Export Configuration (drush cex)"
TXT_DRUSH_BACK_TO_DRUSH="Back to Drush Menu"

TXT_DRUSH_MODULE_THEME_MENU_TITLE="Drush Module/Theme Management"
TXT_DRUSH_PM_LIST="List Modules/Themes"
TXT_DRUSH_PM_ENABLE="Enable Module/Theme"
TXT_DRUSH_PM_DISABLE="Disable Module/Theme"
TXT_DRUSH_PM_UNINSTALL="Uninstall Module/Theme"
TXT_DRUSH_ENTER_MODULE_THEME_NAME="Enter module/theme machine name: "
TXT_DRUSH_BACK_TO_DRUSH="Back to Drush Menu"

TXT_DRUSH_USER_MENU_TITLE="Drush User Management"
TXT_DRUSH_USER_LOGIN="Generate One-Time Login Link"
TXT_DRUSH_USER_BLOCK="Block User"
TXT_DRUSH_USER_UNBLOCK="Unblock User"
TXT_DRUSH_USER_PASSWORD="Set User Password"
TXT_DRUSH_ENTER_USERNAME="Enter username: "
TXT_DRUSH_ENTER_PASSWORD="Enter new password: "
TXT_DRUSH_BACK_TO_DRUSH="Back to Drush Menu"

TXT_DRUSH_WATCHDOG_MENU_TITLE="Drush Watchdog Management"
TXT_DRUSH_WATCHDOG_SHOW="Show Recent Log Entries"
TXT_DRUSH_WATCHDOG_LIST="List Log Entry Types"
TXT_DRUSH_WATCHDOG_DELETE="Delete Log Entries"
TXT_DRUSH_WATCHDOG_TAIL="Tail Log Entries (Follow)"
TXT_DRUSH_ENTER_COUNT="Enter number of entries (default 10): "
TXT_DRUSH_ENTER_TYPE="Enter log type (e.g., 'access denied'): "
TXT_DRUSH_BACK_TO_DRUSH="Back to Drush Menu"

TXT_DRUSH_WEBFORM_MENU_TITLE="Drush Webform Management"
TXT_DRUSH_WEBFORM_LIST="List Webforms"
TXT_DRUSH_WEBFORM_EXPORT="Export Webform Submissions"
TXT_DRUSH_WEBFORM_PURGE="Purge Webform Submissions"
TXT_DRUSH_ENTER_WEBFORM_ID="Enter Webform ID: "
TXT_DRUSH_BACK_TO_DRUSH="Back to Drush Menu"

TXT_DRUSH_DEV_TOOLS_MENU_TITLE="Drush Development Tools"
TXT_DRUSH_EV="Execute PHP Code"
TXT_DRUSH_PHP="Start Interactive PHP Shell"
TXT_DRUSH_CRON="Run Cron"
TXT_DRUSH_BACK_TO_DRUSH="Back to Drush Menu"
TXT_ENTER_PHP_CODE="Enter PHP code to execute (single line): "


# Database Management
TXT_DB_MENU_TITLE="Database Management"
TXT_DB_SQL_DUMP="Dump Database"
TXT_DB_SQL_CLI="Open SQL CLI"
TXT_DB_SQL_QUERY="Execute SQL Query"
TXT_DB_SQL_SYNC="Sync Database"
TXT_DB_RESTORE="Restore Database from Dump"
TXT_DB_BACK="Back to Main Menu"
TXT_DB_ENTER_SQL_QUERY="Enter SQL query: "
TXT_DB_SELECT_SOURCE_ALIAS="Select source Drush alias for sync:"
TXT_DB_SELECT_TARGET_ALIAS="Select target Drush alias for sync:"
TXT_DB_NO_DUMPS_FOUND="No database dumps found in %s."
TXT_DB_SELECT_DUMP="Select a database dump to restore:"
TXT_DB_CONFIRM_RESTORE="WARNING: This will overwrite your current database. Are you sure? (yes/no): "
TXT_DB_RESTORE_COMPLETED="Database restoration completed successfully."
TXT_DB_RESTORE_FAILED="Database restoration failed."
TXT_DB_SELECT_DUMP_AND_SITE="Select a database dump and its corresponding Drupal site:"
TXT_DB_DUMP_FORMAT_UNSUPPORTED="Unsupported dump format: %s"


# Search API Solr Management
TXT_SOLR_MENU_TITLE="Search API Solr Management"
TXT_SOLR_SERVER_LIST="List Solr Servers"
TXT_SOLR_INDEX_LIST="List Solr Indexes"
TXT_SOLR_EXPORT_CONFIG="Export Solr Configuration"
TXT_SOLR_INDEX="Index Content"
TXT_SOLR_CLEAR="Clear Solr Index"
TXT_SOLR_STATUS="Show Solr Status"
TXT_SOLR_BACK="Back to Main Menu"
TXT_SOLR_ENTER_SERVER_ID="Enter Solr server ID: "
TXT_SOLR_ENTER_INDEX_ID="Enter Solr index ID: "
TXT_SOLR_EXPORT_PATH="Enter directory to export Solr configs to (default: %s): "


# IBM Cloud Integration
TXT_IBMCLOUD_MENU_TITLE="IBM Cloud Integration"
TXT_IBMCLOUD_LOGIN="Login to IBM Cloud"
TXT_IBMCLOUD_LOGOUT="Logout from IBM Cloud"
TXT_IBMCLOUD_LIST_KCLUSTERS="List Kubernetes Clusters"
TXT_IBMCLOUD_CONFIGURE_KUBECTL="Configure kubectl for a Cluster"
TXT_IBMCLOUD_BACK="Back to Main Menu"
TXT_IBMCLOUD_ENTER_REGION="Enter IBM Cloud region (e.g., eu-de): "
TXT_IBMCLOUD_ENTER_RESOURCE_GROUP="Enter IBM Cloud resource group: "
TXT_IBMCLOUD_ENTER_ACCOUNT_ID="Enter IBM Cloud account ID: "
TXT_IBMCLOUD_LOGIN_SUCCESS="Successfully logged in to IBM Cloud."
TXT_IBMCLOUD_LOGOUT_SUCCESS="Successfully logged out from IBM Cloud."
TXT_IBMCLOUD_KUBE_CONFIGURED="kubectl configured for cluster: %s"
TXT_IBMCLOUD_SELECT_CLUSTER="Select a Kubernetes cluster:"


# Kubernetes Management
TXT_K8S_MENU_TITLE="Kubernetes Management"
TXT_K8S_CHECK_CONTEXT="Check kubectl Context"
TXT_K8S_SOLR_MENU="Solr Pod Management"
TXT_K8S_POSTGRES_MENU="PostgreSQL Pod Management"
TXT_K8S_COPY_FILES="Copy Files to Pod"
TXT_K8S_EXEC_IN_POD="Execute Command in Pod"
TXT_K8S_BACK="Back to Main Menu"

TXT_K8S_SOLR_MENU_TITLE="Kubernetes Solr Pod Management"
TXT_K8S_SOLR_LIST_PODS="List Solr Pods"
TXT_K8S_SOLR_RESTART_POD="Restart Solr Pod"
TXT_K8S_SOLR_VIEW_LOGS="View Solr Pod Logs"
TXT_K8S_SOLR_BACK="Back to Kubernetes Menu"
TXT_K8S_SELECT_SOLR_POD="Select a Solr pod:"

TXT_K8S_POSTGRES_MENU_TITLE="Kubernetes PostgreSQL Pod Management"
TXT_K8S_PG_LIST_PODS="List PostgreSQL Pods"
TXT_K8S_PG_CLI="Access PostgreSQL CLI (psql)"
TXT_K8S_PG_VIEW_LOGS="View PostgreSQL Pod Logs"
TXT_K8S_PG_BACK="Back to Kubernetes Menu"
TXT_K8S_SELECT_PG_POD="Select a PostgreSQL pod:"

TXT_K8S_ENTER_SOURCE_PATH="Enter local source path (file/directory): "
TXT_K8S_ENTER_DEST_PATH="Enter destination path in pod: "
TXT_K8S_FILE_COPY_SUCCESS="File(s) copied to pod successfully."
TXT_K8S_SELECT_POD="Select a Pod:"
TXT_K8S_SELECT_CONTAINER="Select a Container:"
TXT_K8S_ENTER_COMMAND="Enter command to execute in pod: "
TXT_K8S_NO_KUBECTL_CONTEXT="kubectl context not set. Please configure it first."
TXT_K8S_POD_NOT_FOUND="Pod not found."
TXT_K8S_CONTAINER_NOT_FOUND="Container not found."


# Configuration
TXT_CONFIG_MENU_TITLE="Configuration"
TXT_CONFIG_SET_LANG="Set Language"
TXT_CONFIG_SET_PROJECTS_ROOT="Set Projects Root Directory"
TXT_CONFIG_SET_VERBOSITY="Set Log Verbosity Level"
TXT_CONFIG_TOGGLE_HISTORY="Toggle Command History"
TXT_CONFIG_TOGGLE_FAVORITES="Toggle Custom Favorites"
TXT_CONFIG_TOGGLE_ERROR_REPORTING="Toggle Error Reporting"
TXT_CONFIG_SET_IBMCLOUD_CONFIG="Set IBM Cloud Configuration"
TXT_CONFIG_BACK="Back to Main Menu"

TXT_CONFIG_SELECT_LANG="Select language:"
TXT_CONFIG_ENTER_PROJECTS_ROOT="Enter new projects root directory: "
TXT_CONFIG_SELECT_LOG_LEVEL="Select log verbosity level:"
TXT_CONFIG_HISTORY_STATUS="Command History is currently: %s"
TXT_CONFIG_FAVORITES_STATUS="Custom Favorites is currently: %s"
TXT_CONFIG_ERROR_REPORTING_STATUS="Error Reporting is currently: %s"
TXT_CONFIG_TOGGLE_SUCCESS="Setting updated."

# History and Favorites
TXT_HISTORY_MENU_TITLE="Command History"
TXT_HISTORY_NO_ENTRIES="No history entries found."
TXT_HISTORY_REPLAY_INSTRUCTIONS="Select an entry to replay, or 'Back' to return."
TXT_HISTORY_BACK="Back to Main Menu"

TXT_FAVORITES_MENU_TITLE="Custom Favorites"
TXT_FAVORITES_NO_ENTRIES="No favorite entries found. Edit %s to add some."
TXT_FAVORITES_HELP="You can define custom functions or aliases in %s. They will appear here."
TXT_FAVORITES_BACK="Back to Main Menu"

# Prompts
TXT_PROMPT_CONFIRM="Confirm (yes/no): "
TXT_PROMPT_ENTER_PATH="Enter path: "

EOF

    # lang/fr_FR/messages.sh
    cat <<EOF > "${LANG_DIR}/fr_FR/messages.sh"
#!/bin/bash

# lang/fr_FR/messages.sh
# French translation messages for AUB Tools.

# Header
TXT_AUBAY_DEVTOOLS_HEADER="AUBAY DevTools 1.0"

# Main Menu
TXT_MAIN_MENU_TITLE="Menu Principal"
TXT_MAIN_MENU_PROJECT="Gestion de Projets"
TXT_MAIN_MENU_GIT="Gestion Git"
TXT_MAIN_MENU_DRUSH="Commandes Drush"
TXT_MAIN_MENU_DATABASE="Gestion de Base de Données"
TXT_MAIN_MENU_SOLR="Gestion Search API Solr"
TXT_MAIN_MENU_IBMCLOUD="Intégration IBM Cloud"
TXT_MAIN_MENU_K8S="Gestion Kubernetes"
TXT_MAIN_MENU_CONFIG="Configuration"
TXT_MAIN_MENU_HISTORY="Historique des Commandes"
TXT_MAIN_MENU_FAVORITES="Raccourcis Personnalisés"
TXT_MAIN_MENU_EXIT="Quitter"

# General messages
TXT_SELECT_OPTION="Sélectionnez une option :"
TXT_PRESS_ENTER_TO_CONTINUE="Appuyez sur ENTRÉE pour continuer..."
TXT_INVALID_OPTION="Option invalide. Veuillez réessayer."
TXT_OPERATION_CANCELLED="Opération annulée."
TXT_NOT_IMPLEMENTED="Cette fonctionnalité n'est pas encore implémentée."
TXT_ERROR_REPORT_GENERATED="Une erreur est survenue. Un rapport d'erreur détaillé a été généré à : %s"
TXT_PATH_NOT_FOUND="Chemin introuvable : %s"
TXT_CURRENT_PROJECT="Projet Actuel : %s (Racine Drupal : %s)"
TXT_NO_PROJECT_DETECTED="Aucun projet Drupal détecté dans le chemin actuel ou ses parents."
TXT_ENTER_VALUE_FOR="Entrez une valeur pour %s : "
TXT_SUCCESS="Succès."
TXT_FAILURE="Échec."

# Project Management
TXT_PROJECT_MENU_TITLE="Gestion de Projets"
TXT_PROJECT_MENU_INIT="Initialiser un Nouveau Projet Drupal"
TXT_PROJECT_MENU_DETECT="Détecter le Projet Actuel"
TXT_PROJECT_MENU_GENERATE_ENV="Générer .env à partir de .env.dist"
TXT_PROJECT_MENU_BACK="Retour au Menu Principal"

# Git Management
TXT_GIT_MENU_TITLE="Gestion Git"
TXT_GIT_MENU_STATUS="Afficher le Statut"
TXT_GIT_MENU_LOG="Afficher l'Historique des Commits"
TXT_GIT_MENU_BRANCHES="Gestion des Branches"
TXT_GIT_MENU_PULL="Tirer les Changements (Pull)"
TXT_GIT_MENU_PUSH="Pousser les Changements (Push)"
TXT_GIT_MENU_STASH="Gestion des Stashs"
TXT_GIT_MENU_UNDO="Annuler les Changements"
TXT_GIT_MENU_BACK="Retour au Menu Principal"

TXT_GIT_BRANCH_MENU_TITLE="Gestion des Branches"
TXT_GIT_BRANCH_LIST="Lister Toutes les Branches"
TXT_GIT_BRANCH_CHECKOUT="Basculer vers une Branche Existante"
TXT_GIT_BRANCH_CREATE="Créer une Nouvelle Branche"
TXT_GIT_BRANCH_BACK="Retour au Menu Git"
TXT_ENTER_NEW_BRANCH_NAME="Entrez le nom de la nouvelle branche : "
TXT_ENTER_EXISTING_BRANCH_NAME="Entrez le nom de la branche existante : "

TXT_GIT_STASH_MENU_TITLE="Gestion des Stashs"
TXT_GIT_STASH_SAVE="Sauvegarder les Changements (Stash)"
TXT_GIT_STASH_LIST="Lister les Stashs"
TXT_GIT_STASH_APPLY="Appliquer un Stash"
TXT_GIT_STASH_POP="Appliquer et Supprimer un Stash (Pop)"
TXT_GIT_STASH_DROP="Supprimer un Stash"
TXT_GIT_STASH_BACK="Retour au Menu Git"
TXT_ENTER_STASH_INDEX="Entrez l'index du stash (ex: stash@{0}) : "

TXT_GIT_UNDO_MENU_TITLE="Annuler les Changements"
TXT_GIT_UNDO_RESET_HARD="Reset Hard (Ignorer toutes les modifications locales)"
TXT_GIT_UNDO_REVERT="Annuler le Dernier Commit"
TXT_GIT_UNDO_CLEAN="Nettoyer les Fichiers/Dossiers Non Suivis"
TXT_GIT_UNDO_BACK="Retour au Menu Git"
TXT_CONFIRM_RESET_HARD="ATTENTION : Ceci va annuler toutes les modifications locales et les fichiers non suivis. Êtes-vous sûr ? (oui/non) : "
TXT_CONFIRM_CLEAN="ATTENTION : Ceci va supprimer les fichiers et répertoires non suivis. Êtes-vous sûr ? (oui/non) : "

# Drush Management
TXT_DRUSH_MENU_TITLE="Commandes Drush"
TXT_DRUSH_SELECT_TARGET="Sélectionnez la Cible Drush (site/alias) :"
TXT_DRUSH_TARGET_ALL_SITES="TOUS les Sites (@sites)"
TXT_DRUSH_TARGET_CURRENTLY_SELECTED="Cible Drush actuellement sélectionnée : %s"
TXT_DRUSH_NO_ALIAS_FOUND="Aucun alias Drush ou multi-site trouvé."
TXT_DRUSH_ALIAS_NOT_SET="Alias Drush non défini. Veuillez en sélectionner un."
TXT_DRUSH_GENERAL_MENU="Commandes Générales"
TXT_DRUSH_CONFIG_MENU="Gestion de Configuration"
TXT_DRUSH_MODULE_THEME_MENU="Gestion Modules/Thèmes"
TXT_DRUSH_USER_MENU="Gestion des Utilisateurs"
TXT_DRUSH_WATCHDOG_MENU="Gestion Watchdog"
TXT_DRUSH_WEBFORM_MENU="Gestion Webform"
TXT_DRUSH_DEV_TOOLS_MENU="Outils de Développement"
TXT_DRUSH_BACK="Retour au Menu Principal"

TXT_DRUSH_GENERAL_COMMANDS_MENU_TITLE="Commandes Générales Drush"
TXT_DRUSH_STATUS="Afficher le Statut Drush"
TXT_DRUSH_CR="Vider les Caches (drush cr)"
TXT_DRUSH_UPDB="Mettre à jour la Base de Données (drush updb)"
TXT_DRUSH_BACK_TO_DRUSH="Retour au Menu Drush"

TXT_DRUSH_CONFIG_MENU_TITLE="Gestion de Configuration Drush"
TXT_DRUSH_CIM="Importer la Configuration (drush cim)"
TXT_DRUSH_CEX="Exporter la Configuration (drush cex)"
TXT_DRUSH_BACK_TO_DRUSH="Retour au Menu Drush"

TXT_DRUSH_MODULE_THEME_MENU_TITLE="Gestion Modules/Thèmes Drush"
TXT_DRUSH_PM_LIST="Lister Modules/Thèmes"
TXT_DRUSH_PM_ENABLE="Activer Module/Thème"
TXT_DRUSH_PM_DISABLE="Désactiver Module/Thème"
TXT_DRUSH_PM_UNINSTALL="Désinstaller Module/Thème"
TXT_DRUSH_ENTER_MODULE_THEME_NAME="Entrez le nom machine du module/thème : "
TXT_DRUSH_BACK_TO_DRUSH="Retour au Menu Drush"

TXT_DRUSH_USER_MENU_TITLE="Gestion des Utilisateurs Drush"
TXT_DRUSH_USER_LOGIN="Générer un Lien de Connexion Unique"
TXT_DRUSH_USER_BLOCK="Bloquer l'Utilisateur"
TXT_DRUSH_USER_UNBLOCK="Débloquer l'Utilisateur"
TXT_DRUSH_USER_PASSWORD="Définir le Mot de Passe Utilisateur"
TXT_DRUSH_ENTER_USERNAME="Entrez le nom d'utilisateur : "
TXT_DRUSH_ENTER_PASSWORD="Entrez le nouveau mot de passe : "
TXT_DRUSH_BACK_TO_DRUSH="Retour au Menu Drush"

TXT_DRUSH_WATCHDOG_MENU_TITLE="Gestion Watchdog Drush"
TXT_DRUSH_WATCHDOG_SHOW="Afficher les Entrées de Journal Récentes"
TXT_DRUSH_WATCHDOG_LIST="Lister les Types d'Entrées de Journal"
TXT_DRUSH_WATCHDOG_DELETE="Supprimer les Entrées de Journal"
TXT_DRUSH_WATCHDOG_TAIL="Suivre les Entrées de Journal (Tail)"
TXT_DRUSH_ENTER_COUNT="Entrez le nombre d'entrées (par défaut 10) : "
TXT_DRUSH_ENTER_TYPE="Entrez le type de journal (ex: 'access denied') : "
TXT_DRUSH_BACK_TO_DRUSH="Retour au Menu Drush"

TXT_DRUSH_WEBFORM_MENU_TITLE="Gestion Webform Drush"
TXT_DRUSH_WEBFORM_LIST="Lister les Formulaires Web"
TXT_DRUSH_WEBFORM_EXPORT="Exporter les Soumissions de Formulaire Web"
TXT_DRUSH_WEBFORM_PURGE="Purger les Soumissions de Formulaire Web"
TXT_DRUSH_ENTER_WEBFORM_ID="Entrez l'ID du formulaire web : "
TXT_DRUSH_BACK_TO_DRUSH="Retour au Menu Drush"

TXT_DRUSH_DEV_TOOLS_MENU_TITLE="Outils de Développement Drush"
TXT_DRUSH_EV="Exécuter du Code PHP"
TXT_DRUSH_PHP="Lancer un Shell PHP Interactif"
TXT_DRUSH_CRON="Exécuter Cron"
TXT_DRUSH_BACK_TO_DRUSH="Retour au Menu Drush"
TXT_ENTER_PHP_CODE="Entrez le code PHP à exécuter (une seule ligne) : "

# Database Management
TXT_DB_MENU_TITLE="Gestion de Base de Données"
TXT_DB_SQL_DUMP="Dumper la Base de Données"
TXT_DB_SQL_CLI="Ouvrir le Client SQL"
TXT_DB_SQL_QUERY="Exécuter une Requête SQL"
TXT_DB_SQL_SYNC="Synchroniser la Base de Données"
TXT_DB_RESTORE="Restaurer la Base de Données à partir d'un Dump"
TXT_DB_BACK="Retour au Menu Principal"
TXT_DB_ENTER_SQL_QUERY="Entrez la requête SQL : "
TXT_DB_SELECT_SOURCE_ALIAS="Sélectionnez l'alias Drush source pour la synchronisation :"
TXT_DB_SELECT_TARGET_ALIAS="Sélectionnez l'alias Drush cible pour la synchronisation :"
TXT_DB_NO_DUMPS_FOUND="Aucun dump de base de données trouvé dans %s."
TXT_DB_SELECT_DUMP="Sélectionnez un dump de base de données à restaurer :"
TXT_DB_CONFIRM_RESTORE="ATTENTION : Ceci va écraser votre base de données actuelle. Êtes-vous sûr ? (oui/non) : "
TXT_DB_RESTORE_COMPLETED="Restauration de la base de données terminée avec succès."
TXT_DB_RESTORE_FAILED="Échec de la restauration de la base de données."
TXT_DB_SELECT_DUMP_AND_SITE="Sélectionnez un dump de base de données et son site Drupal correspondant :"
TXT_DB_DUMP_FORMAT_UNSUPPORTED="Format de dump non supporté : %s"

# Search API Solr Management
TXT_SOLR_MENU_TITLE="Gestion Search API Solr"
TXT_SOLR_SERVER_LIST="Lister les Serveurs Solr"
TXT_SOLR_INDEX_LIST="Lister les Index Solr"
TXT_SOLR_EXPORT_CONFIG="Exporter la Configuration Solr"
TXT_SOLR_INDEX="Indexer le Contenu"
TXT_SOLR_CLEAR="Vider l'Index Solr"
TXT_SOLR_STATUS="Afficher le Statut Solr"
TXT_SOLR_BACK="Retour au Menu Principal"
TXT_SOLR_ENTER_SERVER_ID="Entrez l'ID du serveur Solr : "
TXT_SOLR_ENTER_INDEX_ID="Entrez l'ID de l'index Solr : "
TXT_SOLR_EXPORT_PATH="Entrez le répertoire d'exportation des configs Solr (par défaut : %s) : "

# IBM Cloud Integration
TXT_IBMCLOUD_MENU_TITLE="Intégration IBM Cloud"
TXT_IBMCLOUD_LOGIN="Se connecter à IBM Cloud"
TXT_IBMCLOUD_LOGOUT="Se déconnecter d'IBM Cloud"
TXT_IBMCLOUD_LIST_KCLUSTERS="Lister les Clusters Kubernetes"
TXT_IBMCLOUD_CONFIGURE_KUBECTL="Configurer kubectl pour un Cluster"
TXT_IBMCLOUD_BACK="Retour au Menu Principal"
TXT_IBMCLOUD_ENTER_REGION="Entrez la région IBM Cloud (ex: eu-de) : "
TXT_IBMCLOUD_ENTER_RESOURCE_GROUP="Entrez le groupe de ressources IBM Cloud : "
TXT_IBMCLOUD_ENTER_ACCOUNT_ID="Entrez l'ID du compte IBM Cloud : "
TXT_IBMCLOUD_LOGIN_SUCCESS="Connexion à IBM Cloud réussie."
TXT_IBMCLOUD_LOGOUT_SUCCESS="Déconnexion d'IBM Cloud réussie."
TXT_IBMCLOUD_KUBE_CONFIGURED="kubectl configuré pour le cluster : %s"
TXT_IBMCLOUD_SELECT_CLUSTER="Sélectionnez un cluster Kubernetes :"

# Kubernetes Management
TXT_K8S_MENU_TITLE="Gestion Kubernetes"
TXT_K8S_CHECK_CONTEXT="Vérifier le Contexte kubectl"
TXT_K8S_SOLR_MENU="Gestion des Pods Solr"
TXT_K8S_POSTGRES_MENU="Gestion des Pods PostgreSQL"
TXT_K8S_COPY_FILES="Copier des Fichiers vers un Pod"
TXT_K8S_EXEC_IN_POD="Exécuter une Commande dans un Pod"
TXT_K8S_BACK="Retour au Menu Principal"

TXT_K8S_SOLR_MENU_TITLE="Gestion des Pods Solr Kubernetes"
TXT_K8S_SOLR_LIST_PODS="Lister les Pods Solr"
TXT_K8S_SOLR_RESTART_POD="Redémarrer un Pod Solr"
TXT_K8S_SOLR_VIEW_LOGS="Voir les Logs d'un Pod Solr"
TXT_K8S_SOLR_BACK="Retour au Menu Kubernetes"
TXT_K8S_SELECT_SOLR_POD="Sélectionnez un pod Solr :"

TXT_K8S_POSTGRES_MENU_TITLE="Gestion des Pods PostgreSQL Kubernetes"
TXT_K8S_PG_LIST_PODS="Lister les Pods PostgreSQL"
TXT_K8S_PG_CLI="Accéder à la CLI PostgreSQL (psql)"
TXT_K8S_PG_VIEW_LOGS="Voir les Logs d'un Pod PostgreSQL"
TXT_K8S_PG_BACK="Retour au Menu Kubernetes"
TXT_K8S_SELECT_PG_POD="Sélectionnez un pod PostgreSQL :"

TXT_K8S_ENTER_SOURCE_PATH="Entrez le chemin source local (fichier/répertoire) : "
TXT_K8S_ENTER_DEST_PATH="Entrez le chemin de destination dans le pod : "
TXT_K8S_FILE_COPY_SUCCESS="Fichier(s) copié(s) vers le pod avec succès."
TXT_K8S_SELECT_POD="Sélectionnez un Pod :"
TXT_K8S_SELECT_CONTAINER="Sélectionnez un Conteneur :"
TXT_K8S_ENTER_COMMAND="Entrez la commande à exécuter dans le pod : "
TXT_K8S_NO_KUBECTL_CONTEXT="Contexte kubectl non défini. Veuillez le configurer d'abord."
TXT_K8S_POD_NOT_FOUND="Pod introuvable."
TXT_K8S_CONTAINER_NOT_FOUND="Conteneur introuvable."

# Configuration
TXT_CONFIG_MENU_TITLE="Configuration"
TXT_CONFIG_SET_LANG="Définir la Langue"
TXT_CONFIG_SET_PROJECTS_ROOT="Définir le Répertoire Racine des Projets"
TXT_CONFIG_SET_VERBOSITY="Définir le Niveau de Verbosité des Logs"
TXT_CONFIG_TOGGLE_HISTORY="Activer/Désactiver l'Historique des Commandes"
TXT_CONFIG_TOGGLE_FAVORITES="Activer/Désactiver les Raccourcis Personnalisés"
TXT_CONFIG_TOGGLE_ERROR_REPORTING="Activer/Désactiver les Rapports d'Erreurs"
TXT_CONFIG_SET_IBMCLOUD_CONFIG="Définir la Configuration IBM Cloud"
TXT_CONFIG_BACK="Retour au Menu Principal"

TXT_CONFIG_SELECT_LANG="Sélectionnez la langue :"
TXT_CONFIG_ENTER_PROJECTS_ROOT="Entrez le nouveau répertoire racine des projets : "
TXT_CONFIG_SELECT_LOG_LEVEL="Sélectionnez le niveau de verbosité des logs :"
TXT_CONFIG_HISTORY_STATUS="L'historique des commandes est actuellement : %s"
TXT_CONFIG_FAVORITES_STATUS="Les raccourcis personnalisés sont actuellement : %s"
TXT_CONFIG_ERROR_REPORTING_STATUS="Les rapports d'erreurs sont actuellement : %s"
TXT_CONFIG_TOGGLE_SUCCESS="Paramètre mis à jour."

# History and Favorites
TXT_HISTORY_MENU_TITLE="Historique des Commandes"
TXT_HISTORY_NO_ENTRIES="Aucune entrée d'historique trouvée."
TXT_HISTORY_REPLAY_INSTRUCTIONS="Sélectionnez une entrée à rejouer, ou 'Retour' pour revenir."
TXT_HISTORY_BACK="Retour au Menu Principal"

TXT_FAVORITES_MENU_TITLE="Raccourcis Personnalisés"
TXT_FAVORITES_NO_ENTRIES="Aucune entrée de favori trouvée. Modifiez %s pour en ajouter."
TXT_FAVORITES_HELP="Vous pouvez définir des fonctions ou alias personnalisés dans %s. Ils apparaîtront ici."
TXT_FAVORITES_BACK="Retour au Menu Principal"

# Prompts
TXT_PROMPT_CONFIRM="Confirmer (oui/non) : "
TXT_PROMPT_ENTER_PATH="Entrez le chemin : "
EOF

    # Create empty stubs for all other files
    touch "${CORE_DIR}/main.sh"
    cat <<EOF > "${CORE_DIR}/main.sh"
#!/bin/bash

# core/main.sh
# Main menu and navigation logic for AUB Tools.

# main_menu: Displays the main interactive menu and handles user choices.
main_menu() {
    local options=(
        "\${TXT_MAIN_MENU_PROJECT}"
        "\${TXT_MAIN_MENU_GIT}"
        "\${TXT_MAIN_MENU_DRUSH}"
        "\${TXT_MAIN_MENU_DATABASE}"
        "\${TXT_MAIN_MENU_SOLR}"
        "\${TXT_MAIN_MENU_IBMCLOUD}"
        "\${TXT_MAIN_MENU_K8S}"
        "\${TXT_MAIN_MENU_CONFIG}"
        "\${TXT_MAIN_MENU_HISTORY}"
        "\${TXT_MAIN_MENU_FAVORITES}"
        "\${TXT_MAIN_MENU_EXIT}"
    )

    while true; do
        display_header # Refresh header
        log_info_no_log "\${TXT_MAIN_MENU_TITLE}"
        log_info_no_log "\$(printf "\${TXT_CURRENT_PROJECT}" "\${CURRENT_PROJECT_NAME:-"N/A"}" "\${CURRENT_DRUPAL_ROOT_PATH:-"N/A"}")"
        echo ""

        local choice
        choice=\$(display_menu "\${options[@]}")

        case "\${choice}" in
            "\${TXT_MAIN_MENU_PROJECT}")
                project_menu
                ;;
            "\${TXT_MAIN_MENU_GIT}")
                git_menu
                ;;
            "\${TXT_MAIN_MENU_DRUSH}")
                drush_menu
                ;;
            "\${TXT_MAIN_MENU_DATABASE}")
                database_menu
                ;;
            "\${TXT_MAIN_MENU_SOLR}")
                solr_menu
                ;;
            "\${TXT_MAIN_MENU_IBMCLOUD}")
                ibmcloud_menu
                ;;
            "\${TXT_MAIN_MENU_K8S}")
                kubernetes_menu
                ;;
            "\${TXT_MAIN_MENU_CONFIG}")
                config_menu
                ;;
            "\${TXT_MAIN_MENU_HISTORY}")
                history_menu
                ;;
            "\${TXT_MAIN_MENU_FAVORITES}")
                favorites_menu
                ;;
            "\${TXT_MAIN_MENU_EXIT}")
                log_info_no_log "Exiting AUB Tools. Goodbye!"
                exit 0
                ;;
            *)
                log_error "\${TXT_INVALID_OPTION}"
                press_enter_to_continue
                ;;
        esac
    done
}

# Source the individual menus/functions here to make them callable
# from main_menu. If not already sourced in aub-tools main script.
# Example: source "\${AUB_TOOLS_PATH}/core/project.sh"
EOF

    touch "${CORE_DIR}/composer.sh"
    cat <<EOF > "${CORE_DIR}/composer.sh"
#!/bin/bash

# core/composer.sh
# Functions for Composer dependency management.

# composer_install: Runs composer install within the Drupal root.
composer_install() {
    log_info "Running 'composer install' in \${CURRENT_DRUPAL_ROOT_PATH}..."
    if [[ -z "\${CURRENT_DRUPAL_ROOT_PATH}" ]]; then
        log_error "\${TXT_NO_PROJECT_DETECTED}"
        return 1
    fi

    (cd "\${CURRENT_DRUPAL_ROOT_PATH}" && composer install)
    if [[ \$? -eq 0 ]]; then
        log_success "Composer install completed."
    else
        log_error "Composer install failed."
        return 1
    fi
}

# composer_update: Runs composer update within the Drupal root.
composer_update() {
    log_info "Running 'composer update' in \${CURRENT_DRUPAL_ROOT_PATH}..."
    if [[ -z "\${CURRENT_DRUPAL_ROOT_PATH}" ]]; then
        log_error "\${TXT_NO_PROJECT_DETECTED}"
        return 1
    fi

    (cd "\${CURRENT_DRUPAL_ROOT_PATH}" && composer update)
    if [[ \$? -eq 0 ]]; then
        log_success "Composer update completed."
    else
        log_error "Composer update failed."
        return 1
    fi
}

# composer_require: Adds a new Composer dependency.
composer_require() {
    log_info "Adding new Composer dependency..."
    if [[ -z "\${CURRENT_DRUPAL_ROOT_PATH}" ]]; then
        log_error "\${TXT_NO_PROJECT_DETECTED}"
        return 1
    fi

    local package_name
    read -p "Enter Composer package name (e.g., drupal/devel): " package_name
    if [[ -z "\$package_name" ]]; then
        log_warn "\${TXT_OPERATION_CANCELLED}"
        return 0
    fi

    log_info "Running 'composer require \$package_name' in \${CURRENT_DRUPAL_ROOT_PATH}..."
    (cd "\${CURRENT_DRUPAL_ROOT_PATH}" && composer require "\$package_name")
    if [[ \$? -eq 0 ]]; then
        log_success "Composer package '\$package_name' added."
    else
        log_error "Failed to add Composer package '\$package_name'."
        return 1
    fi
}

# composer_remove: Removes a Composer dependency.
composer_remove() {
    log_info "Removing Composer dependency..."
    if [[ -z "\${CURRENT_DRUPAL_ROOT_PATH}" ]]; then
        log_error "\${TXT_NO_PROJECT_DETECTED}"
        return 1
    fi

    local package_name
    read -p "Enter Composer package name to remove: " package_name
    if [[ -z "\$package_name" ]]; then
        log_warn "\${TXT_OPERATION_CANCELLED}"
        return 0
    fi

    log_info "Running 'composer remove \$package_name' in \${CURRENT_DRUPAL_ROOT_PATH}..."
    (cd "\${CURRENT_DRUPAL_ROOT_PATH}" && composer remove "\$package_name")
    if [[ \$? -eq 0 ]]; then
        log_success "Composer package '\$package_name' removed."
    else
        log_error "Failed to remove Composer package '\$package_name'."
        return 1
    fi
}

# composer_validate: Validates the composer.json file.
composer_validate() {
    log_info "Validating composer.json in \${CURRENT_DRUPAL_ROOT_PATH}..."
    if [[ -z "\${CURRENT_DRUPAL_ROOT_PATH}" ]]; then
        log_error "\${TXT_NO_PROJECT_DETECTED}"
        return 1
    fi

    (cd "\${CURRENT_DRUPAL_ROOT_PATH}" && composer validate)
    if [[ \$? -eq 0 ]]; then
        log_success "composer.json is valid."
    else
        log_error "composer.json is invalid."
        return 1
    fi
}

EOF

    touch "${CORE_DIR}/database.sh"
    cat <<EOF > "${CORE_DIR}/database.sh"
#!/bin/bash

# core/database.sh
# Functions for Drupal database management using Drush.

# database_menu: Displays the database management menu.
database_menu() {
    local options=(
        "\${TXT_DB_SQL_DUMP}"
        "\${TXT_DB_SQL_CLI}"
        "\${TXT_DB_SQL_QUERY}"
        "\${TXT_DB_SQL_SYNC}"
        "\${TXT_DB_RESTORE}"
        "\${TXT_DB_BACK}"
    )

    while true; do
        display_header
        log_info_no_log "\${TXT_DB_MENU_TITLE}"
        log_info_no_log "\$(printf "\${TXT_DRUSH_TARGET_CURRENTLY_SELECTED}" "\${DRUSH_CURRENT_TARGET:-"\${TXT_DRUSH_ALIAS_NOT_SET}"}")"
        echo ""

        local choice
        choice=\$(display_menu "\${options[@]}")

        case "\${choice}" in
            "\${TXT_DB_SQL_DUMP}")
                drush_sql_dump
                ;;
            "\${TXT_DB_SQL_CLI}")
                drush_sql_cli
                ;;
            "\${TXT_DB_SQL_QUERY}")
                drush_sql_query
                ;;
            "\${TXT_DB_SQL_SYNC}")
                drush_sql_sync_interactive
                ;;
            "\${TXT_DB_RESTORE}")
                drush_db_restore_interactive
                ;;
            "\${TXT_DB_BACK}")
                break
                ;;
            *)
                log_error "\${TXT_INVALID_OPTION}"
                press_enter_to_continue
                ;;
        esac
    done
}

# drush_sql_dump: Dumps the database using drush sql:dump.
drush_sql_dump() {
    log_info "Running 'drush sql:dump'..."
    run_drush_command "sql:dump"
}

# drush_sql_cli: Opens the SQL CLI using drush sql:cli.
drush_sql_cli() {
    log_info "Opening SQL CLI..."
    log_warn "This will open a new prompt within the Drush target's database."
    run_drush_command "sql:cli"
}

# drush_sql_query: Executes an SQL query using drush sql:query.
drush_sql_query() {
    local query
    query=\$(prompt_for_input "\${TXT_DB_ENTER_SQL_QUERY}")
    if [[ -z "\$query" ]]; then
        log_warn "\${TXT_OPERATION_CANCELLED}"
        return 0
    fi
    log_info "Running 'drush sql:query \$query'..."
    run_drush_command "sql:query \"\$query\""
}

# drush_sql_sync_interactive: Guides user to sync databases between Drush aliases.
drush_sql_sync_interactive() {
    log_info "Starting database synchronization (drush sql:sync)..."
    if [[ -z "\${CURRENT_DRUPAL_ROOT_PATH}" ]]; then
        log_error "\${TXT_NO_PROJECT_DETECTED}"
        return 1
    fi

    local aliases
    aliases=\$(get_drush_aliases)
    if [[ -z "\$aliases" ]]; then
        log_error "\${TXT_DRUSH_NO_ALIAS_FOUND}"
        press_enter_to_continue
        return 1
    fi

    log_info_no_log "\${TXT_DB_SELECT_SOURCE_ALIAS}"
    local source_alias=\$(echo "\$aliases" | display_menu_from_list)
    if [[ -z "\$source_alias" ]]; then
        log_warn "\${TXT_OPERATION_CANCELLED}"
        return 0
    fi

    log_info_no_log "\${TXT_DB_SELECT_TARGET_ALIAS}"
    local target_alias=\$(echo "\$aliases" | display_menu_from_list)
    if [[ -z "\$target_alias" ]]; then
        log_warn "\${TXT_OPERATION_CANCELLED}"
        return 0
    fi

    log_info "Synchronizing database from \$source_alias to \$target_alias..."
    run_drush_command "sql:sync \$source_alias \$target_alias"
}

# drush_db_restore_interactive: Intelligently restores a database from a dump.
# This function looks for SQL dump files in the project's data/ directory.
drush_db_restore_interactive() {
    log_info "Starting database restoration..."
    if [[ -z "\${CURRENT_PROJECT_PATH}" ]]; then
        log_error "\${TXT_NO_PROJECT_DETECTED}"
        return 1
    fi

    local data_dir="\${CURRENT_PROJECT_PATH}/data"
    if [[ ! -d "\$data_dir" ]]; then
        log_error "\$(printf "\${TXT_PATH_NOT_FOUND}" "\$data_dir")"
        log_info "Please ensure your database dumps are in the 'data/' directory of your project."
        press_enter_to_continue
        return 1
    fi

    local dump_files=(\$(find "\$data_dir" -maxdepth 1 -type f \( -name "*.sql" -o -name "*.gz" -o -name "*.zip" -o -name "*.tar" -o -name "*.dump" -o -name "*.dmp" \) -print | sort))
    if [[ \${#dump_files[@]} -eq 0 ]]; then
        log_error "\$(printf "\${TXT_DB_NO_DUMPS_FOUND}" "\$data_dir")"
        press_enter_to_continue
        return 1
    fi

    log_info_no_log "\${TXT_DB_SELECT_DUMP}"
    local selected_dump_path=\$(display_menu "\${dump_files[@]}")
    if [[ -z "\$selected_dump_path" ]]; then
        log_warn "\${TXT_OPERATION_CANCELLED}"
        return 0
    fi

    if ! confirm_action "\$(printf "\${TXT_DB_CONFIRM_RESTORE}")"; then
        log_warn "\${TXT_OPERATION_CANCELLED}"
        return 0
    fi

    local temp_decompressed_file=""
    local dump_extension="\$(echo "\$selected_dump_path" | awk -F'.' '{print \$NF}')"

    case "\$dump_extension" in
        "sql"|"dump"|"dmp")
            local final_dump_path="\$selected_dump_path"
            ;;
        "gz")
            log_info "Decompressing GZ file..."
            temp_decompressed_file="\${TEMP_DIR}/\$(basename "\$selected_dump_path" .gz).sql"
            gunzip -c "\$selected_dump_path" > "\$temp_decompressed_file" || { log_error "Failed to decompress GZ file."; return 1; }
            local final_dump_path="\$temp_decompressed_file"
            ;;
        "zip")
            log_info "Decompressing ZIP file..."
            # For simplicity, assumes a single SQL file inside the zip or specifies one.
            # A more robust solution might list contents and ask user.
            temp_decompressed_file="\${TEMP_DIR}/\$(basename "\$selected_dump_path" .zip).sql"
            unzip -p "\$selected_dump_path" > "\$temp_decompressed_file" || { log_error "Failed to decompress ZIP file."; return 1; }
            local final_dump_path="\$temp_decompressed_file"
            ;;
        "tar")
            log_info "Decompressing TAR file..."
            # Again, assumes a single SQL file.
            temp_decompressed_file="\${TEMP_DIR}/\$(basename "\$selected_dump_path" .tar).sql"
            tar -xf "\$selected_dump_path" -O > "\$temp_decompressed_file" || { log_error "Failed to decompress TAR file."; return 1; }
            local final_dump_path="\$temp_decompressed_file"
            ;;
        *)
            log_error "\$(printf "\${TXT_DB_DUMP_FORMAT_UNSUPPORTED}" "\$dump_extension")"
            return 1
            ;;
    esac

    log_info "Restoring database from \$final_dump_path..."
    # Check if a Drush target is set. If not, prompt.
    if [[ -z "\${DRUSH_CURRENT_TARGET}" ]]; then
        select_drush_target
        if [[ -z "\${DRUSH_CURRENT_TARGET}" ]]; then
            log_warn "\${TXT_OPERATION_CANCELLED}"
            return 0
        fi
    fi

    if run_drush_command "sql:drop -y && drush sql:cli < \$final_dump_path"; then
        log_success "\${TXT_DB_RESTORE_COMPLETED}"
    else
        log_error "\${TXT_DB_RESTORE_FAILED}"
    fi

    # Clean up temporary decompressed file
    if [[ -n "\$temp_decompressed_file" && -f "\$temp_decompressed_file" ]]; then
        rm -f "\$temp_decompressed_file"
        log_debug "Removed temporary decompressed file: \$temp_decompressed_file"
    fi
    press_enter_to_continue
}

EOF

    touch "${CORE_DIR}/drush.sh"
    cat <<EOF > "${CORE_DIR}/drush.sh"
#!/bin/bash

# core/drush.sh
# Functions for Drush commands, including multi-site/target support.

DRUSH_CURRENT_TARGET="" # Global variable to store the currently selected Drush target

# get_drush_aliases: Discovers Drush aliases and multi-site URIs.
# Returns a newline-separated list of possible Drush targets.
get_drush_aliases() {
    if [[ -z "\${CURRENT_DRUPAL_ROOT_PATH}" ]]; then
        log_error "\${TXT_NO_PROJECT_DETECTED}"
        return ""
    fi

    local aliases_output
    aliases_output=\$(cd "\${CURRENT_DRUPAL_ROOT_PATH}" && drush sa --format=json 2>/dev/null | "\${JQ_BIN}" -r 'keys[]' 2>/dev/null)

    # Also look for multi-site directories
    local multi_site_uris=""
    if [[ -d "\${CURRENT_DRUPAL_ROOT_PATH}/web/sites" ]]; then
        for site_dir in "\${CURRENT_DRUPAL_ROOT_PATH}/web/sites/"*; do
            if [[ -d "\$site_dir" && "\$(basename "\$site_dir")" != "default" && "\$(basename "\$site_dir")" != "all" ]]; then
                multi_site_uris+="\n\$(basename "\$site_dir")"
            fi
        done
    fi

    local all_targets="\$(echo -e "\$aliases_output\n\$multi_site_uris" | grep -v '^\s*$' | sort -u)"
    echo "\$all_targets"
}

# select_drush_target: Prompts the user to select a Drush alias or multi-site URI.
select_drush_target() {
    local aliases_list=\$(get_drush_aliases)
    if [[ -z "\$aliases_list" ]]; then
        log_error "\${TXT_DRUSH_NO_ALIAS_FOUND}"
        DRUSH_CURRENT_TARGET=""
        return 1
    fi

    local options=("\${TXT_DRUSH_TARGET_ALL_SITES}")
    IFS=$'\n' read -r -d '' -a aliases_array <<< "\$aliases_list"
    for alias_entry in "\${aliases_array[@]}"; do
        options+=("\$alias_entry")
    done

    log_info_no_log "\${TXT_DRUSH_SELECT_TARGET}"
    local choice=\$(display_menu "\${options[@]}")

    if [[ -n "\$choice" ]]; then
        if [[ "\$choice" == "\${TXT_DRUSH_TARGET_ALL_SITES}" ]]; then
            DRUSH_CURRENT_TARGET="@sites"
        else
            DRUSH_CURRENT_TARGET="\$choice"
        fi
        log_info "\$(printf "\${TXT_DRUSH_TARGET_CURRENTLY_SELECTED}" "\${DRUSH_CURRENT_TARGET}")"
    else
        log_warn "\${TXT_OPERATION_CANCELLED}"
        DRUSH_CURRENT_TARGET=""
    fi
    press_enter_to_continue
}

# run_drush_command: Executes a Drush command with the selected target.
# $1: The Drush command and its arguments (e.g., "status", "cr", "pm:enable module_name")
run_drush_command() {
    local drush_cmd="\$1"

    if [[ -z "\${CURRENT_DRUPAL_ROOT_PATH}" ]]; then
        log_error "\${TXT_NO_PROJECT_DETECTED}"
        return 1
    fi

    # Ensure drush is installed
    if ! command_exists "drush"; then
        log_error "Drush command not found. Please install Drush or ensure it's in your PATH."
        return 1
    fi

    # If no target is set, try to select one
    if [[ -z "\${DRUSH_CURRENT_TARGET}" ]]; then
        log_warn "No Drush target selected. Attempting to select one."
        select_drush_target
        if [[ -z "\${DRUSH_CURRENT_TARGET}" ]]; then
            log_error "Cannot execute Drush command without a target."
            return 1
        fi
    fi

    log_info "Executing: drush --uri=\"\${DRUSH_CURRENT_TARGET}\" \$drush_cmd in \${CURRENT_DRUPAL_ROOT_PATH}"
    (cd "\${CURRENT_DRUPAL_ROOT_PATH}" && drush --uri="\${DRUSH_CURRENT_TARGET}" \$drush_cmd)
    local status=\$?
    if [[ \$status -eq 0 ]]; then
        log_success "Drush command executed successfully."
    else
        log_error "Drush command failed with exit code \$status."
        generate_error_report "\$0" "Drush command failed: drush --uri=\"\${DRUSH_CURRENT_TARGET}\" \$drush_cmd" "\$status"
    fi
    return \$status
}

# drush_menu: Main Drush menu
drush_menu() {
    local options=(
        "\${TXT_DRUSH_SELECT_TARGET}"
        "\${TXT_DRUSH_GENERAL_MENU}"
        "\${TXT_DRUSH_CONFIG_MENU}"
        "\${TXT_DRUSH_MODULE_THEME_MENU}"
        "\${TXT_DRUSH_USER_MENU}"
        "\${TXT_DRUSH_WATCHDOG_MENU}"
        "\${TXT_DRUSH_WEBFORM_MENU}"
        "\${TXT_DRUSH_DEV_TOOLS_MENU}"
        "\${TXT_DRUSH_BACK}"
    )

    while true; do
        display_header
        log_info_no_log "\${TXT_DRUSH_MENU_TITLE}"
        log_info_no_log "\$(printf "\${TXT_DRUSH_TARGET_CURRENTLY_SELECTED}" "\${DRUSH_CURRENT_TARGET:-"\${TXT_DRUSH_ALIAS_NOT_SET}"}")"
        echo ""

        local choice
        choice=\$(display_menu "\${options[@]}")

        case "\${choice}" in
            "\${TXT_DRUSH_SELECT_TARGET}")
                select_drush_target
                ;;
            "\${TXT_DRUSH_GENERAL_MENU}")
                drush_general_commands_menu
                ;;
            "\${TXT_DRUSH_CONFIG_MENU}")
                drush_config_menu
                ;;
            "\${TXT_DRUSH_MODULE_THEME_MENU}")
                drush_module_theme_menu
                ;;
            "\${TXT_DRUSH_USER_MENU}")
                drush_user_menu
                ;;
            "\${TXT_DRUSH_WATCHDOG_MENU}")
                drush_watchdog_menu
                ;;
            "\${TXT_DRUSH_WEBFORM_MENU}")
                drush_webform_menu
                ;;
            "\${TXT_DRUSH_DEV_TOOLS_MENU}")
                drush_dev_tools_menu
                ;;
            "\${TXT_DRUSH_BACK}")
                break
                ;;
            *)
                log_error "\${TXT_INVALID_OPTION}"
                press_enter_to_continue
                ;;
        esac
    done
}

# --- Sub-menus for Drush ---

# drush_general_commands_menu:
drush_general_commands_menu() {
    local options=(
        "\${TXT_DRUSH_STATUS}"
        "\${TXT_DRUSH_CR}"
        "\${TXT_DRUSH_UPDB}"
        "\${TXT_DRUSH_BACK_TO_DRUSH}"
    )

    while true; do
        display_header
        log_info_no_log "\${TXT_DRUSH_GENERAL_COMMANDS_MENU_TITLE}"
        log_info_no_log "\$(printf "\${TXT_DRUSH_TARGET_CURRENTLY_SELECTED}" "\${DRUSH_CURRENT_TARGET:-"\${TXT_DRUSH_ALIAS_NOT_SET}"}")"
        echo ""

        local choice
        choice=\$(display_menu "\${options[@]}")

        case "\${choice}" in
            "\${TXT_DRUSH_STATUS}")
                run_drush_command "status"
                press_enter_to_continue
                ;;
            "\${TXT_DRUSH_CR}")
                run_drush_command "cr"
                press_enter_to_continue
                ;;
            "\${TXT_DRUSH_UPDB}")
                run_drush_command "updb -y"
                press_enter_to_continue
                ;;
            "\${TXT_DRUSH_BACK_TO_DRUSH}")
                break
                ;;
            *)
                log_error "\${TXT_INVALID_OPTION}"
                press_enter_to_continue
                ;;
        esac
    done
}

# drush_config_menu:
drush_config_menu() {
    local options=(
        "\${TXT_DRUSH_CIM}"
        "\${TXT_DRUSH_CEX}"
        "\${TXT_DRUSH_BACK_TO_DRUSH}"
    )

    while true; do
        display_header
        log_info_no_log "\${TXT_DRUSH_CONFIG_MENU_TITLE}"
        log_info_no_log "\$(printf "\${TXT_DRUSH_TARGET_CURRENTLY_SELECTED}" "\${DRUSH_CURRENT_TARGET:-"\${TXT_DRUSH_ALIAS_NOT_SET}"}")"
        echo ""

        local choice
        choice=\$(display_menu "\${options[@]}")

        case "\${choice}" in
            "\${TXT_DRUSH_CIM}")
                run_drush_command "cim -y"
                press_enter_to_continue
                ;;
            "\${TXT_DRUSH_CEX}")
                run_drush_command "cex -y"
                press_enter_to_continue
                ;;
            "\${TXT_DRUSH_BACK_TO_DRUSH}")
                break
                ;;
            *)
                log_error "\${TXT_INVALID_OPTION}"
                press_enter_to_continue
                ;;
        esac
    done
}

# drush_module_theme_menu:
drush_module_theme_menu() {
    local options=(
        "\${TXT_DRUSH_PM_LIST}"
        "\${TXT_DRUSH_PM_ENABLE}"
        "\${TXT_DRUSH_PM_DISABLE}"
        "\${TXT_DRUSH_PM_UNINSTALL}"
        "\${TXT_DRUSH_BACK_TO_DRUSH}"
    )

    while true; do
        display_header
        log_info_no_log "\${TXT_DRUSH_MODULE_THEME_MENU_TITLE}"
        log_info_no_log "\$(printf "\${TXT_DRUSH_TARGET_CURRENTLY_SELECTED}" "\${DRUSH_CURRENT_TARGET:-"\${TXT_DRUSH_ALIAS_NOT_SET}"}")"
        echo ""

        local choice
        choice=\$(display_menu "\${options[@]}")

        case "\${choice}" in
            "\${TXT_DRUSH_PM_LIST}")
                run_drush_command "pm:list --status=enabled --type=module --no-core"
                run_drush_command "pm:list --status=enabled --type=theme --no-core"
                press_enter_to_continue
                ;;
            "\${TXT_DRUSH_PM_ENABLE}")
                local name=\$(prompt_for_input "\${TXT_DRUSH_ENTER_MODULE_THEME_NAME}")
                if [[ -n "\$name" ]]; then
                    run_drush_command "pm:enable -y \$name"
                else
                    log_warn "\${TXT_OPERATION_CANCELLED}"
                fi
                press_enter_to_continue
                ;;
            "\${TXT_DRUSH_PM_DISABLE}")
                local name=\$(prompt_for_input "\${TXT_DRUSH_ENTER_MODULE_THEME_NAME}")
                if [[ -n "\$name" ]]; then
                    run_drush_command "pm:disable -y \$name"
                else
                    log_warn "\${TXT_OPERATION_CANCELLED}"
                fi
                press_enter_to_continue
                ;;
            "\${TXT_DRUSH_PM_UNINSTALL}")
                local name=\$(prompt_for_input "\${TXT_DRUSH_ENTER_MODULE_THEME_NAME}")
                if [[ -n "\$name" ]]; then
                    run_drush_command "pm:uninstall -y \$name"
                else
                    log_warn "\${TXT_OPERATION_CANCELLED}"
                fi
                press_enter_to_continue
                ;;
            "\${TXT_DRUSH_BACK_TO_DRUSH}")
                break
                ;;
            *)
                log_error "\${TXT_INVALID_OPTION}"
                press_enter_to_continue
                ;;
        esac
    done
}

# drush_user_menu:
drush_user_menu() {
    local options=(
        "\${TXT_DRUSH_USER_LOGIN}"
        "\${TXT_DRUSH_USER_BLOCK}"
        "\${TXT_DRUSH_USER_UNBLOCK}"
        "\${TXT_DRUSH_USER_PASSWORD}"
        "\${TXT_DRUSH_BACK_TO_DRUSH}"
    )

    while true; do
        display_header
        log_info_no_log "\${TXT_DRUSH_USER_MENU_TITLE}"
        log_info_no_log "\$(printf "\${TXT_DRUSH_TARGET_CURRENTLY_SELECTED}" "\${DRUSH_CURRENT_TARGET:-"\${TXT_DRUSH_ALIAS_NOT_SET}"}")"
        echo ""

        local choice
        choice=\$(display_menu "\${options[@]}")

        case "\${choice}" in
            "\${TXT_DRUSH_USER_LOGIN}")
                run_drush_command "user:login"
                press_enter_to_continue
                ;;
            "\${TXT_DRUSH_USER_BLOCK}")
                local username=\$(prompt_for_input "\${TXT_DRUSH_ENTER_USERNAME}")
                if [[ -n "\$username" ]]; then
                    run_drush_command "user:block \$username"
                else
                    log_warn "\${TXT_OPERATION_CANCELLED}"
                fi
                press_enter_to_continue
                ;;
            "\${TXT_DRUSH_USER_UNBLOCK}")
                local username=\$(prompt_for_input "\${TXT_DRUSH_ENTER_USERNAME}")
                if [[ -n "\$username" ]]; then
                    run_drush_command "user:unblock \$username"
                else
                    log_warn "\${TXT_OPERATION_CANCELLED}"
                fi
                press_enter_to_continue
                ;;
            "\${TXT_DRUSH_USER_PASSWORD}")
                local username=\$(prompt_for_input "\${TXT_DRUSH_ENTER_USERNAME}")
                local password=\$(prompt_for_input "\${TXT_DRUSH_ENTER_PASSWORD}")
                if [[ -n "\$username" && -n "\$password" ]]; then
                    run_drush_command "user:password \$username \"\$password\""
                else
                    log_warn "\${TXT_OPERATION_CANCELLED}"
                fi
                press_enter_to_continue
                ;;
            "\${TXT_DRUSH_BACK_TO_DRUSH}")
                break
                ;;
            *)
                log_error "\${TXT_INVALID_OPTION}"
                press_enter_to_continue
                ;;
        esac
    done
}

# drush_watchdog_menu:
drush_watchdog_menu() {
    local options=(
        "\${TXT_DRUSH_WATCHDOG_SHOW}"
        "\${TXT_DRUSH_WATCHDOG_LIST}"
        "\${TXT_DRUSH_WATCHDOG_DELETE}"
        "\${TXT_DRUSH_WATCHDOG_TAIL}"
        "\${TXT_DRUSH_BACK_TO_DRUSH}"
    )

    while true; do
        display_header
        log_info_no_log "\${TXT_DRUSH_WATCHDOG_MENU_TITLE}"
        log_info_no_log "\$(printf "\${TXT_DRUSH_TARGET_CURRENTLY_SELECTED}" "\${DRUSH_CURRENT_TARGET:-"\${TXT_DRUSH_ALIAS_NOT_SET}"}")"
        echo ""

        local choice
        choice=\$(display_menu "\${options[@]}")

        case "\${choice}" in
            "\${TXT_DRUSH_WATCHDOG_SHOW}")
                local count=\$(prompt_for_input "\${TXT_DRUSH_ENTER_COUNT}" "10")
                run_drush_command "watchdog:show --count=\$count"
                press_enter_to_continue
                ;;
            "\${TXT_DRUSH_WATCHDOG_LIST}")
                run_drush_command "watchdog:list"
                press_enter_to_continue
                ;;
            "\${TXT_DRUSH_WATCHDOG_DELETE}")
                local type=\$(prompt_for_input "\${TXT_DRUSH_ENTER_TYPE}" "all")
                run_drush_command "watchdog:delete \$type -y"
                press_enter_to_continue
                ;;
            "\${TXT_DRUSH_WATCHDOG_TAIL}")
                log_info "Tailing watchdog entries. Press Ctrl+C to stop."
                run_drush_command "watchdog:tail"
                press_enter_to_continue
                ;;
            "\${TXT_DRUSH_BACK_TO_DRUSH}")
                break
                ;;
            *)
                log_error "\${TXT_INVALID_OPTION}"
                press_enter_to_continue
                ;;
        esac
    done
}

# drush_webform_menu:
drush_webform_menu() {
    local options=(
        "\${TXT_DRUSH_WEBFORM_LIST}"
        "\${TXT_DRUSH_WEBFORM_EXPORT}"
        "\${TXT_DRUSH_WEBFORM_PURGE}"
        "\${TXT_DRUSH_BACK_TO_DRUSH}"
    )

    while true; do
        display_header
        log_info_no_log "\${TXT_DRUSH_WEBFORM_MENU_TITLE}"
        log_info_no_log "\$(printf "\${TXT_DRUSH_TARGET_CURRENTLY_SELECTED}" "\${DRUSH_CURRENT_TARGET:-"\${TXT_DRUSH_ALIAS_NOT_SET}"}")"
        echo ""

        local choice
        choice=\$(display_menu "\${options[@]}")

        case "\${choice}" in
            "\${TXT_DRUSH_WEBFORM_LIST}")
                run_drush_command "webform:list"
                press_enter_to_continue
                ;;
            "\${TXT_DRUSH_WEBFORM_EXPORT}")
                local webform_id=\$(prompt_for_input "\${TXT_DRUSH_ENTER_WEBFORM_ID}")
                if [[ -n "\$webform_id" ]]; then
                    run_drush_command "webform:export \$webform_id"
                else
                    log_warn "\${TXT_OPERATION_CANCELLED}"
                fi
                press_enter_to_continue
                ;;
            "\${TXT_DRUSH_WEBFORM_PURGE}")
                local webform_id=\$(prompt_for_input "\${TXT_DRUSH_ENTER_WEBFORM_ID}")
                if [[ -n "\$webform_id" ]]; then
                    run_drush_command "webform:purge \$webform_id -y"
                else
                    log_warn "\${TXT_OPERATION_CANCELLED}"
                fi
                press_enter_to_continue
                ;;
            "\${TXT_DRUSH_BACK_TO_DRUSH}")
                break
                ;;
            *)
                log_error "\${TXT_INVALID_OPTION}"
                press_enter_to_continue
                ;;
        esac
    done
}

# drush_dev_tools_menu:
drush_dev_tools_menu() {
    local options=(
        "\${TXT_DRUSH_EV}"
        "\${TXT_DRUSH_PHP}"
        "\${TXT_DRUSH_CRON}"
        "\${TXT_DRUSH_BACK_TO_DRUSH}"
    )

    while true; do
        display_header
        log_info_no_log "\${TXT_DRUSH_DEV_TOOLS_MENU_TITLE}"
        log_info_no_log "\$(printf "\${TXT_DRUSH_TARGET_CURRENTLY_SELECTED}" "\${DRUSH_CURRENT_TARGET:-"\${TXT_DRUSH_ALIAS_NOT_SET}"}")"
        echo ""

        local choice
        choice=\$(display_menu "\${options[@]}")

        case "\${choice}" in
            "\${TXT_DRUSH_EV}")
                local php_code=\$(prompt_for_input "\${TXT_ENTER_PHP_CODE}")
                if [[ -n "\$php_code" ]]; then
                    run_drush_command "eval \"\$php_code\""
                else
                    log_warn "\${TXT_OPERATION_CANCELLED}"
                fi
                press_enter_to_continue
                ;;
            "\${TXT_DRUSH_PHP}")
                log_info "Entering Drush PHP shell. Type 'exit' to return."
                run_drush_command "php"
                press_enter_to_continue
                ;;
            "\${TXT_DRUSH_CRON}")
                run_drush_command "cron"
                press_enter_to_continue
                ;;
            "\${TXT_DRUSH_BACK_TO_DRUSH}")
                break
                ;;
            *)
                log_error "\${TXT_INVALID_OPTION}"
                press_enter_to_continue
                ;;
        esac
    done
}

EOF

    touch "${CORE_DIR}/git.sh"
    cat <<EOF > "${CORE_DIR}/git.sh"
#!/bin/bash

# core/git.sh
# Functions for Git operations.

# git_menu: Displays the Git management menu.
git_menu() {
    local options=(
        "\${TXT_GIT_MENU_STATUS}"
        "\${TXT_GIT_MENU_LOG}"
        "\${TXT_GIT_MENU_BRANCHES}"
        "\${TXT_GIT_MENU_PULL}"
        "\${TXT_GIT_MENU_PUSH}"
        "\${TXT_GIT_MENU_STASH}"
        "\${TXT_GIT_MENU_UNDO}"
        "\${TXT_GIT_MENU_BACK}"
    )

    while true; do
        display_header
        log_info_no_log "\${TXT_GIT_MENU_TITLE}"
        log_info_no_log "\$(printf "\${TXT_CURRENT_PROJECT}" "\${CURRENT_PROJECT_NAME:-"N/A"}" "\${CURRENT_DRUPAL_ROOT_PATH:-"N/A"}")"
        echo ""

        if [[ -z "\${CURRENT_PROJECT_PATH}" || ! -d "\${CURRENT_PROJECT_PATH}/.git" ]]; then
            log_error "\${TXT_NO_PROJECT_DETECTED} or .git directory not found."
            press_enter_to_continue
            break # Exit git menu if no git project
        fi

        local choice
        choice=\$(display_menu "\${options[@]}")

        case "\${choice}" in
            "\${TXT_GIT_MENU_STATUS}")
                git_status
                ;;
            "\${TXT_GIT_MENU_LOG}")
                git_log
                ;;
            "\${TXT_GIT_MENU_BRANCHES}")
                git_branch_menu
                ;;
            "\${TXT_GIT_MENU_PULL}")
                git_pull
                ;;
            "\${TXT_GIT_MENU_PUSH}")
                git_push
                ;;
            "\${TXT_GIT_MENU_STASH}")
                git_stash_menu
                ;;
            "\${TXT_GIT_MENU_UNDO}")
                git_undo_menu
                ;;
            "\${TXT_GIT_MENU_BACK}")
                break
                ;;
            *)
                log_error "\${TXT_INVALID_OPTION}"
                press_enter_to_continue
                ;;
        esac
    done
}

# run_git_command: Helper to run git commands in the project directory.
# $1: The git command and arguments.
run_git_command() {
    if [[ -z "\${CURRENT_PROJECT_PATH}" || ! -d "\${CURRENT_PROJECT_PATH}/.git" ]]; then
        log_error "\${TXT_NO_PROJECT_DETECTED} or .git directory not found."
        return 1
    fi
    log_info "Executing: git \$1 in \${CURRENT_PROJECT_PATH}"
    (cd "\${CURRENT_PROJECT_PATH}" && git \$1)
    local status=\$?
    if [[ \$status -eq 0 ]]; then
        log_success "Git command executed successfully."
    else
        log_error "Git command failed with exit code \$status."
        generate_error_report "\$0" "Git command failed: git \$1" "\$status"
    fi
    press_enter_to_continue
    return \$status
}

# git_status: Shows the git status.
git_status() {
    log_info "Showing Git status..."
    run_git_command "status"
}

# git_log: Shows the commit history.
git_log() {
    log_info "Showing Git commit history..."
    run_git_command "log --oneline --graph --decorate --all -n 20"
}

# git_branch_menu: Manages branches.
git_branch_menu() {
    local options=(
        "\${TXT_GIT_BRANCH_LIST}"
        "\${TXT_GIT_BRANCH_CHECKOUT}"
        "\${TXT_GIT_BRANCH_CREATE}"
        "\${TXT_GIT_BRANCH_BACK}"
    )

    while true; do
        display_header
        log_info_no_log "\${TXT_GIT_BRANCH_MENU_TITLE}"
        echo ""

        local choice
        choice=\$(display_menu "\${options[@]}")

        case "\${choice}" in
            "\${TXT_GIT_BRANCH_LIST}")
                log_info "Fetching all remote branches..."
                run_git_command "fetch --all --prune"
                log_info "Listing all local and remote branches:"
                run_git_command "branch -a"
                ;;
            "\${TXT_GIT_BRANCH_CHECKOUT}")
                local branch_name=\$(prompt_for_input "\${TXT_ENTER_EXISTING_BRANCH_NAME}")
                if [[ -n "\$branch_name" ]]; then
                    run_git_command "checkout \$branch_name"
                else
                    log_warn "\${TXT_OPERATION_CANCELLED}"
                fi
                ;;
            "\${TXT_GIT_BRANCH_CREATE}")
                local branch_name=\$(prompt_for_input "\${TXT_ENTER_NEW_BRANCH_NAME}")
                if [[ -n "\$branch_name" ]]; then
                    run_git_command "checkout -b \$branch_name"
                else
                    log_warn "\${TXT_OPERATION_CANCELLED}"
                fi
                ;;
            "\${TXT_GIT_BRANCH_BACK}")
                break
                ;;
            *)
                log_error "\${TXT_INVALID_OPTION}"
                press_enter_to_continue
                ;;
        esac
    done
}

# git_pull: Pulls changes from the remote.
git_pull() {
    log_info "Pulling changes..."
    run_git_command "pull"
}

# git_push: Pushes changes to the remote.
git_push() {
    log_info "Pushing changes..."
    run_git_command "push"
}

# git_stash_menu: Manages stashes.
git_stash_menu() {
    local options=(
        "\${TXT_GIT_STASH_SAVE}"
        "\${TXT_GIT_STASH_LIST}"
        "\${TXT_GIT_STASH_APPLY}"
        "\${TXT_GIT_STASH_POP}"
        "\${TXT_GIT_STASH_DROP}"
        "\${TXT_GIT_STASH_BACK}"
    )

    while true; do
        display_header
        log_info_no_log "\${TXT_GIT_STASH_MENU_TITLE}"
        echo ""

        local choice
        choice=\$(display_menu "\${options[@]}")

        case "\${choice}" in
            "\${TXT_GIT_STASH_SAVE}")
                log_info "Saving current changes to stash..."
                run_git_command "stash save"
                ;;
            "\${TXT_GIT_STASH_LIST}")
                log_info "Listing stashes:"
                run_git_command "stash list"
                ;;
            "\${TXT_GIT_STASH_APPLY}")
                local stash_index=\$(prompt_for_input "\${TXT_ENTER_STASH_INDEX}" "stash@{0}")
                if [[ -n "\$stash_index" ]]; then
                    log_info "Applying stash \$stash_index..."
                    run_git_command "stash apply \"\$stash_index\""
                else
                    log_warn "\${TXT_OPERATION_CANCELLED}"
                fi
                ;;
            "\${TXT_GIT_STASH_POP}")
                local stash_index=\$(prompt_for_input "\${TXT_ENTER_STASH_INDEX}" "stash@{0}")
                if [[ -n "\$stash_index" ]]; then
                    log_info "Popping stash \$stash_index..."
                    run_git_command "stash pop \"\$stash_index\""
                else
                    log_warn "\${TXT_OPERATION_CANCELLED}"
                fi
                ;;
            "\${TXT_GIT_STASH_DROP}")
                local stash_index=\$(prompt_for_input "\${TXT_ENTER_STASH_INDEX}" "stash@{0}")
                if [[ -n "\$stash_index" ]]; then
                    if confirm_action "Are you sure you want to drop stash \$stash_index? (yes/no): "; then
                        log_info "Dropping stash \$stash_index..."
                        run_git_command "stash drop \"\$stash_index\""
                    else
                        log_warn "\${TXT_OPERATION_CANCELLED}"
                    fi
                else
                    log_warn "\${TXT_OPERATION_CANCELLED}"
                fi
                ;;
            "\${TXT_GIT_STASH_BACK}")
                break
                ;;
            *)
                log_error "\${TXT_INVALID_OPTION}"
                press_enter_to_continue
                ;;
        esac
    done
}

# git_undo_menu: Provides options to undo changes.
git_undo_menu() {
    local options=(
        "\${TXT_GIT_UNDO_RESET_HARD}"
        "\${TXT_GIT_UNDO_REVERT}"
        "\${TXT_GIT_UNDO_CLEAN}"
        "\${TXT_GIT_UNDO_BACK}"
    )

    while true; do
        display_header
        log_info_no_log "\${TXT_GIT_UNDO_MENU_TITLE}"
        echo ""

        local choice
        choice=\$(display_menu "\${options[@]}")

        case "\${choice}" in
            "\${TXT_GIT_UNDO_RESET_HARD}")
                if confirm_action "\${TXT_CONFIRM_RESET_HARD}"; then
                    log_warn "Performing git reset --hard HEAD. All local changes will be lost!"
                    run_git_command "reset --hard HEAD"
                else
                    log_warn "\${TXT_OPERATION_CANCELLED}"
                fi
                ;;
            "\${TXT_GIT_UNDO_REVERT}")
                log_info "Reverting last commit..."
                run_git_command "revert HEAD" # This creates a new commit that undoes the last one
                ;;
            "\${TXT_GIT_UNDO_CLEAN}")
                if confirm_action "\${TXT_CONFIRM_CLEAN}"; then
                    log_warn "Cleaning untracked files and directories..."
                    run_git_command "clean -df"
                else
                    log_warn "\${TXT_OPERATION_CANCELLED}"
                fi
                ;;
            "\${TXT_GIT_UNDO_BACK}")
                break
                ;;
            *)
                log_error "\${TXT_INVALID_OPTION}"
                press_enter_to_continue
                ;;
        esac
    done
}
EOF

    touch "${CORE_DIR}/ibmcloud.sh"
    cat <<EOF > "${CORE_DIR}/ibmcloud.sh"
#!/bin/bash

# core/ibmcloud.sh
# Functions for IBM Cloud integration.

# ibmcloud_menu: Displays the IBM Cloud integration menu.
ibmcloud_menu() {
    local options=(
        "\${TXT_IBMCLOUD_LOGIN}"
        "\${TXT_IBMCLOUD_LOGOUT}"
        "\${TXT_IBMCLOUD_LIST_KCLUSTERS}"
        "\${TXT_IBMCLOUD_CONFIGURE_KUBECTL}"
        "\${TXT_IBMCLOUD_BACK}"
    )

    while true; do
        display_header
        log_info_no_log "\${TXT_IBMCLOUD_MENU_TITLE}"
        echo ""

        local choice
        choice=\$(display_menu "\${options[@]}")

        case "\${choice}" in
            "\${TXT_IBMCLOUD_LOGIN}")
                ibmcloud_login_interactive
                ;;
            "\${TXT_IBMCLOUD_LOGOUT}")
                ibmcloud_logout
                ;;
            "\${TXT_IBMCLOUD_LIST_KCLUSTERS}")
                ibmcloud_list_kubernetes_clusters
                ;;
            "\${TXT_IBMCLOUD_CONFIGURE_KUBECTL}")
                ibmcloud_configure_kubectl_for_cluster
                ;;
            "\${TXT_IBMCLOUD_BACK}")
                break
                ;;
            *)
                log_error "\${TXT_INVALID_OPTION}"
                press_enter_to_continue
                ;;
        esac
    done
}

# check_ibmcloud_cli: Checks if the ibmcloud CLI is installed.
check_ibmcloud_cli() {
    if ! command_exists "ibmcloud"; then
        log_error "IBM Cloud CLI not found. Please install it to use this feature."
        return 1
    fi
    return 0
}

# ibmcloud_login_interactive: Handles interactive IBM Cloud login.
ibmcloud_login_interactive() {
    if ! check_ibmcloud_cli; then return 1; fi

    local region="\${IBMCLOUD_DEFAULT_REGION}"
    local resource_group="\${IBMCLOUD_DEFAULT_RESOURCE_GROUP}"
    local account_id="\${IBMCLOUD_DEFAULT_ACCOUNT_ID}"

    region=\$(prompt_for_input "\$(printf "\${TXT_IBMCLOUD_ENTER_REGION}" )" "\$region")
    resource_group=\$(prompt_for_input "\$(printf "\${TXT_IBMCLOUD_ENTER_RESOURCE_GROUP}" )" "\$resource_group")
    account_id=\$(prompt_for_input "\$(printf "\${TXT_IBMCLOUD_ENTER_ACCOUNT_ID}" )" "\$account_id")

    log_info "Attempting IBM Cloud login..."
    log_info "Region: \$region, Resource Group: \$resource_group"

    # Set proxy if configured
    set_proxy

    if ibmcloud login --sso -r "\$region" -g "\$resource_group" -a "\$account_id"; then
        log_success "\${TXT_IBMCLOUD_LOGIN_SUCCESS}"
    else
        log_error "IBM Cloud login failed."
        generate_error_report "\$0" "IBM Cloud login failed" "\$?"
    fi

    # Reset proxy
    reset_proxy
    press_enter_to_continue
}

# ibmcloud_logout: Logs out from IBM Cloud.
ibmcloud_logout() {
    if ! check_ibmcloud_cli; then return 1; fi
    log_info "Logging out from IBM Cloud..."
    if ibmcloud logout; then
        log_success "\${TXT_IBMCLOUD_LOGOUT_SUCCESS}"
    else
        log_error "IBM Cloud logout failed."
        generate_error_report "\$0" "IBM Cloud logout failed" "\$?"
    fi
    press_enter_to_continue
}

# ibmcloud_list_kubernetes_clusters: Lists available Kubernetes clusters.
ibmcloud_list_kubernetes_clusters() {
    if ! check_ibmcloud_cli; then return 1; fi
    log_info "Listing Kubernetes clusters..."
    ibmcloud ks clusters --json | "\${JQ_BIN}" -r '.[] | "\(.name) (\(.id))"'
    local status=\$?
    if [[ \$status -ne 0 ]]; then
        log_error "Failed to list Kubernetes clusters."
        generate_error_report "\$0" "ibmcloud ks clusters failed" "\$status"
    fi
    press_enter_to_continue
}

# ibmcloud_configure_kubectl_for_cluster: Configures kubectl for a selected cluster.
ibmcloud_configure_kubectl_for_cluster() {
    if ! check_ibmcloud_cli; then return 1; fi
    if ! command_exists "kubectl"; then
        log_error "kubectl not found. Please install it to use this feature."
        press_enter_to_continue
        return 1
    fi

    local clusters_json
    clusters_json=\$(ibmcloud ks clusters --json 2>/dev/null)
    if [[ \$? -ne 0 ]]; then
        log_error "Failed to retrieve cluster list from IBM Cloud. Are you logged in?"
        press_enter_to_continue
        return 1
    fi

    local cluster_names=(\$(echo "\$clusters_json" | "\${JQ_BIN}" -r '.[].name'))
    if [[ \${#cluster_names[@]} -eq 0 ]]; then
        log_warn "No Kubernetes clusters found."
        press_enter_to_continue
        return 0
    fi

    log_info_no_log "\${TXT_IBMCLOUD_SELECT_CLUSTER}"
    local selected_cluster_name=\$(display_menu "\${cluster_names[@]}")

    if [[ -z "\$selected_cluster_name" ]]; then
        log_warn "\${TXT_OPERATION_CANCELLED}"
        return 0
    fi

    local cluster_id=\$(echo "\$clusters_json" | "\${JQ_BIN}" -r ".[] | select(.name==\"\$selected_cluster_name\") | .id")
    if [[ -z "\$cluster_id" ]]; then
        log_error "Could not find ID for cluster: \$selected_cluster_name"
        press_enter_to_continue
        return 1
    fi

    log_info "Configuring kubectl for cluster '\$selected_cluster_name' (ID: \$cluster_id)..."
    if ibmcloud ks cluster config --cluster "\$cluster_id" --admin --network; then
        log_success "\$(printf "\${TXT_IBMCLOUD_KUBE_CONFIGURED}" "\$selected_cluster_name")"
    else
        log_error "Failed to configure kubectl for cluster '\$selected_cluster_name'."
        generate_error_report "\$0" "ibmcloud ks cluster config failed for \$selected_cluster_name" "\$?"
    fi
    press_enter_to_continue
}
EOF

    touch "${CORE_DIR}/k8s.sh"
    cat <<EOF > "${CORE_DIR}/k8s.sh"
#!/bin/bash

# core/k8s.sh
# Functions for Kubernetes management.

# kubernetes_menu: Displays the Kubernetes management menu.
kubernetes_menu() {
    local options=(
        "\${TXT_K8S_CHECK_CONTEXT}"
        "\${TXT_K8S_SOLR_MENU}"
        "\${TXT_K8S_POSTGRES_MENU}"
        "\${TXT_K8S_COPY_FILES}"
        "\${TXT_K8S_EXEC_IN_POD}"
        "\${TXT_K8S_BACK}"
    )

    while true; do
        display_header
        log_info_no_log "\${TXT_K8S_MENU_TITLE}"
        echo ""

        if ! command_exists "kubectl"; then
            log_error "kubectl not found. Please install it to use this feature."
            press_enter_to_continue
            break
        fi

        local choice
        choice=\$(display_menu "\${options[@]}")

        case "\${choice}" in
            "\${TXT_K8S_CHECK_CONTEXT}")
                check_kubectl_context
                ;;
            "\${TXT_K8S_SOLR_MENU}")
                k8s_solr_menu
                ;;
            "\${TXT_K8S_POSTGRES_MENU}")
                k8s_postgres_menu
                ;;
            "\${TXT_K8S_COPY_FILES}")
                k8s_copy_files_to_pod
                ;;
            "\${TXT_K8S_EXEC_IN_POD}")
                k8s_exec_in_pod
                ;;
            "\${TXT_K8S_BACK}")
                break
                ;;
            *)
                log_error "\${TXT_INVALID_OPTION}"
                press_enter_to_continue
                ;;
        esac
    done
}

# check_kubectl_context: Verifies if kubectl context is set.
check_kubectl_context() {
    log_info "Checking kubectl context..."
    local current_context=\$(kubectl config current-context 2>/dev/null)
    local status=\$?
    if [[ \$status -eq 0 ]]; then
        log_success "kubectl context is set to: \$current_context"
        return 0
    else
        log_error "\${TXT_K8S_NO_KUBECTL_CONTEXT}"
        return 1
    fi
    press_enter_to_continue
}

# get_kubectl_pods: Lists pods based on a label selector (optional).
# $1: Label selector (e.g., "app=solr", "tier=database")
get_kubectl_pods() {
    local selector="\$1"
    if [[ -n "\$selector" ]]; then
        kubectl get pods -l "\$selector" -o json | "\${JQ_BIN}" -r '.items[].metadata.name' 2>/dev/null
    else
        kubectl get pods -o json | "\${JQ_BIN}" -r '.items[].metadata.name' 2>/dev/null
    fi
    return \$?
}

# select_kubectl_pod: Interactive selection of a Kubernetes pod.
# $1: Optional label selector (e.g., "app=solr")
# Returns selected pod name, or empty string on cancellation/failure.
select_kubectl_pod() {
    local selector="\$1"
    local pods_list=\$(get_kubectl_pods "\$selector")
    if [[ \$? -ne 0 || -z "\$pods_list" ]]; then
        log_error "\${TXT_K8S_POD_NOT_FOUND} (Selector: \$selector)"
        return 1
    fi

    log_info_no_log "\${TXT_K8S_SELECT_POD}"
    local selected_pod=\$(echo "\$pods_list" | display_menu_from_list)
    echo "\$selected_pod"
    return 0
}

# select_kubectl_container: Interactive selection of a container within a pod.
# $1: Pod name.
# Returns selected container name, or empty string on cancellation/failure.
select_kubectl_container() {
    local pod_name="\$1"
    local containers_list=\$(kubectl get pod "\$pod_name" -o json | "\${JQ_BIN}" -r '.spec.containers[].name' 2>/dev/null)
    if [[ \$? -ne 0 || -z "\$containers_list" ]]; then
        log_error "\${TXT_K8S_CONTAINER_NOT_FOUND} in pod: \$pod_name"
        return 1
    fi

    log_info_no_log "\${TXT_K8S_SELECT_CONTAINER}"
    local selected_container=\$(echo "\$containers_list" | display_menu_from_list)
    echo "\$selected_container"
    return 0
}

# k8s_solr_menu: Solr specific Kubernetes operations.
k8s_solr_menu() {
    local options=(
        "\${TXT_K8S_SOLR_LIST_PODS}"
        "\${TXT_K8S_SOLR_RESTART_POD}"
        "\${TXT_K8S_SOLR_VIEW_LOGS}"
        "\${TXT_K8S_SOLR_BACK}"
    )

    while true; do
        display_header
        log_info_no_log "\${TXT_K8S_SOLR_MENU_TITLE}"
        echo ""

        if ! check_kubectl_context; then press_enter_to_continue; break; fi

        local choice
        choice=\$(display_menu "\${options[@]}")

        case "\${choice}" in
            "\${TXT_K8S_SOLR_LIST_PODS}")
                log_info "Listing Solr pods..."
                get_kubectl_pods "app=solr" # Assuming 'app=solr' label for Solr pods
                press_enter_to_continue
                ;;
            "\${TXT_K8S_SOLR_RESTART_POD}")
                log_info "Restarting Solr pod..."
                local pod_name=\$(select_kubectl_pod "app=solr")
                if [[ -n "\$pod_name" ]]; then
                    log_info "Deleting pod \$pod_name to trigger restart..."
                    kubectl delete pod "\$pod_name"
                    local status=\$?
                    if [[ \$status -eq 0 ]]; then
                        log_success "Pod \$pod_name deleted. It should be recreated by the deployment."
                    else
                        log_error "Failed to delete pod \$pod_name."
                        generate_error_report "\$0" "kubectl delete pod \$pod_name failed" "\$status"
                    fi
                else
                    log_warn "\${TXT_OPERATION_CANCELLED}"
                fi
                press_enter_to_continue
                ;;
            "\${TXT_K8S_SOLR_VIEW_LOGS}")
                log_info "Viewing Solr pod logs..."
                local pod_name=\$(select_kubectl_pod "app=solr")
                if [[ -n "\$pod_name" ]]; then
                    local container_name=\$(select_kubectl_container "\$pod_name")
                    if [[ -n "\$container_name" ]]; then
                        log_info "Showing logs for pod/\$pod_name container/\$container_name. Press Ctrl+C to exit."
                        kubectl logs -f "\$pod_name" -c "\$container_name"
                    else
                        log_warn "\${TXT_OPERATION_CANCELLED}"
                    fi
                else
                    log_warn "\${TXT_OPERATION_CANCELLED}"
                fi
                press_enter_to_continue
                ;;
            "\${TXT_K8S_SOLR_BACK}")
                break
                ;;
            *)
                log_error "\${TXT_INVALID_OPTION}"
                press_enter_to_continue
                ;;
        esac
    done
}

# k8s_postgres_menu: PostgreSQL specific Kubernetes operations.
k8s_postgres_menu() {
    local options=(
        "\${TXT_K8S_PG_LIST_PODS}"
        "\${TXT_K8S_PG_CLI}"
        "\${TXT_K8S_PG_VIEW_LOGS}"
        "\${TXT_K8S_PG_BACK}"
    )

    while true; do
        display_header
        log_info_no_log "\${TXT_K8S_POSTGRES_MENU_TITLE}"
        echo ""

        if ! check_kubectl_context; then press_enter_to_continue; break; fi

        local choice
        choice=\$(display_menu "\${options[@]}")

        case "\${choice}" in
            "\${TXT_K8S_PG_LIST_PODS}")
                log_info "Listing PostgreSQL pods..."
                get_kubectl_pods "app.kubernetes.io/name=postgresql" # Assuming label for postgres pods
                press_enter_to_continue
                ;;
            "\${TXT_K8S_PG_CLI}")
                log_info "Accessing PostgreSQL CLI (psql)..."
                local pod_name=\$(select_kubectl_pod "app.kubernetes.io/name=postgresql")
                if [[ -n "\$pod_name" ]]; then
                    local container_name=\$(select_kubectl_container "\$pod_name")
                    if [[ -n "\$container_name" ]]; then
                        local db_user=\$(prompt_for_input "Enter PostgreSQL username (e.g., drupal):" "drupal")
                        log_info "Executing psql in pod/\$pod_name container/\$container_name."
                        kubectl exec -it "\$pod_name" -c "\$container_name" -- psql -U "\$db_user"
                    else
                        log_warn "\${TXT_OPERATION_CANCELLED}"
                    fi
                else
                    log_warn "\${TXT_OPERATION_CANCELLED}"
                fi
                press_enter_to_continue
                ;;
            "\${TXT_K8S_PG_VIEW_LOGS}")
                log_info "Viewing PostgreSQL pod logs..."
                local pod_name=\$(select_kubectl_pod "app.kubernetes.io/name=postgresql")
                if [[ -n "\$pod_name" ]]; then
                    local container_name=\$(select_kubectl_container "\$pod_name")
                    if [[ -n "\$container_name" ]]; then
                        log_info "Showing logs for pod/\$pod_name container/\$container_name. Press Ctrl+C to exit."
                        kubectl logs -f "\$pod_name" -c "\$container_name"
                    else
                        log_warn "\${TXT_OPERATION_CANCELLED}"
                    fi
                else
                    log_warn "\${TXT_OPERATION_CANCELLED}"
                fi
                press_enter_to_continue
                ;;
            "\${TXT_K8S_PG_BACK}")
                break
                ;;
            *)
                log_error "\${TXT_INVALID_OPTION}"
                press_enter_to_continue
                ;;
        esac
    done
}

# k8s_copy_files_to_pod: Copies local files/folders to a Kubernetes pod.
k8s_copy_files_to_pod() {
    log_info "Copying files to Kubernetes pod..."
    if ! check_kubectl_context; then press_enter_to_continue; return 1; fi

    local source_path=\$(prompt_for_input "\${TXT_K8S_ENTER_SOURCE_PATH}")
    if [[ -z "\$source_path" ]]; then
        log_warn "\${TXT_OPERATION_CANCELLED}"
        return 0
    fi
    if [[ ! -e "\$source_path" ]]; then
        log_error "\$(printf "\${TXT_PATH_NOT_FOUND}" "\$source_path")"
        press_enter_to_continue
        return 1
    fi

    local pod_name=\$(select_kubectl_pod)
    if [[ -z "\$pod_name" ]]; then
        log_warn "\${TXT_OPERATION_CANCELLED}"
        return 0
    fi

    local container_name=\$(select_kubectl_container "\$pod_name")
    if [[ -z "\$container_name" ]]; then
        log_warn "\${TXT_OPERATION_CANCELLED}"
        return 0
    fi

    local dest_path=\$(prompt_for_input "\${TXT_K8S_ENTER_DEST_PATH}")
    if [[ -z "\$dest_path" ]]; then
        log_warn "\${TXT_OPERATION_CANCELLED}"
        return 0
    fi

    log_info "Copying \$source_path to pod/\$pod_name:/\$dest_path (container: \$container_name)..."
    if kubectl cp "\$source_path" "\$pod_name":/"\$dest_path" -c "\$container_name"; then
        log_success "\${TXT_K8S_FILE_COPY_SUCCESS}"
    else
        log_error "Failed to copy files to pod."
        generate_error_report "\$0" "kubectl cp failed" "\$?"
    fi
    press_enter_to_continue
}

# k8s_exec_in_pod: Executes a command in a Kubernetes pod.
k8s_exec_in_pod() {
    log_info "Executing command in Kubernetes pod..."
    if ! check_kubectl_context; then press_enter_to_continue; return 1; fi

    local pod_name=\$(select_kubectl_pod)
    if [[ -z "\$pod_name" ]]; then
        log_warn "\${TXT_OPERATION_CANCELLED}"
        return 0
    fi

    local container_name=\$(select_kubectl_container "\$pod_name")
    if [[ -z "\$container_name" ]]; then
        log_warn "\${TXT_OPERATION_CANCELLED}"
        return 0
    fi

    local command_to_exec=\$(prompt_for_input "\${TXT_K8S_ENTER_COMMAND}")
    if [[ -z "\$command_to_exec" ]]; then
        log_warn "\${TXT_OPERATION_CANCELLED}"
        return 0
    fi

    log_info "Executing '\$command_to_exec' in pod/\$pod_name container/\$container_name."
    kubectl exec -it "\$pod_name" -c "\$container_name" -- bash -c "\$command_to_exec"
    local status=\$?
    if [[ \$status -eq 0 ]]; then
        log_success "Command executed successfully."
    else
        log_error "Command failed with exit code \$status."
        generate_error_report "\$0" "kubectl exec failed: \$command_to_exec" "\$status"
    fi
    press_enter_to_continue
}
EOF

    touch "${CORE_DIR}/project.sh"
    cat <<EOF > "${CORE_DIR}/project.sh"
#!/bin/bash

# core/project.sh
# Functions for Drupal project management.

# Global variables to store current project and Drupal root paths
CURRENT_PROJECT_PATH=""
CURRENT_DRUPAL_ROOT_PATH=""
CURRENT_PROJECT_NAME="N/A"

# project_menu: Displays the project management menu.
project_menu() {
    local options=(
        "\${TXT_PROJECT_MENU_INIT}"
        "\${TXT_PROJECT_MENU_DETECT}"
        "\${TXT_PROJECT_MENU_GENERATE_ENV}"
        "\${TXT_PROJECT_MENU_BACK}"
    )

    # Attempt to detect project path on menu entry
    detect_current_project_path

    while true; do
        display_header
        log_info_no_log "\${TXT_PROJECT_MENU_TITLE}"
        log_info_no_log "\$(printf "\${TXT_CURRENT_PROJECT}" "\${CURRENT_PROJECT_NAME}" "\${CURRENT_DRUPAL_ROOT_PATH}")"
        echo ""

        local choice
        choice=\$(display_menu "\${options[@]}")

        case "\${choice}" in
            "\${TXT_PROJECT_MENU_INIT}")
                initialize_new_drupal_project
                ;;
            "\${TXT_PROJECT_MENU_DETECT}")
                detect_current_project_path
                press_enter_to_continue
                ;;
            "\${TXT_PROJECT_MENU_GENERATE_ENV}")
                generate_env_file
                ;;
            "\${TXT_PROJECT_MENU_BACK}")
                break
                ;;
            *)
                log_error "\${TXT_INVALID_OPTION}"
                press_enter_to_continue
                ;;
        esac
    done
}

# detect_current_project_path: Automatically detects the Drupal project root and Drupal web root.
detect_current_project_path() {
    log_info "Detecting current Drupal project path..."
    local current_dir="\$(pwd)"
    local found_project_root=""
    local found_drupal_root=""

    # Search upwards for .git and composer.json
    local search_path="\$current_dir"
    while [[ "\$search_path" != "/" ]]; do
        if [[ -d "\$search_path/.git" ]]; then
            found_project_root="\$search_path"
            break
        fi
        search_path="\$(dirname "\$search_path")"
    done

    if [[ -z "\$found_project_root" ]]; then
        log_warn "\${TXT_NO_PROJECT_DETECTED}"
        CURRENT_PROJECT_PATH=""
        CURRENT_DRUPAL_ROOT_PATH=""
        CURRENT_PROJECT_NAME="N/A"
        return 1
    fi

    CURRENT_PROJECT_PATH="\$found_project_root"

    # Try to find Drupal root within the project, prioritizing src/, web/, etc.
    local drupal_possible_roots=("src" "web" "docroot" "public" "html")
    for root_dir in "\${drupal_possible_roots[@]}"; do
        if [[ -f "\${CURRENT_PROJECT_PATH}/\$root_dir/index.php" && -d "\${CURRENT_PROJECT_PATH}/\$root_dir/core" ]]; then
            found_drupal_root="\${CURRENT_PROJECT_PATH}/\$root_dir"
            break
        fi
        # Special case: composer.json at project root and web/ in that project root
        if [[ "\$root_dir" == "web" && -f "\${CURRENT_PROJECT_PATH}/composer.json" && -f "\${CURRENT_PROJECT_PATH}/web/index.php" && -d "\${CURRENT_PROJECT_PATH}/web/core" ]]; then
            found_drupal_root="\${CURRENT_PROJECT_PATH}/web"
            break
        fi
    done

    if [[ -z "\$found_drupal_root" ]]; then
        # Fallback: if composer.json is at project root, assume Drupal root is there
        if [[ -f "\${CURRENT_PROJECT_PATH}/composer.json" && -d "\${CURRENT_PROJECT_PATH}/core" ]]; then
             found_drupal_root="\$CURRENT_PROJECT_PATH"
        fi
    fi

    if [[ -z "\$found_drupal_root" ]]; then
        log_warn "Could not find Drupal web root (e.g., src/, web/) in \${CURRENT_PROJECT_PATH}."
        CURRENT_DRUPAL_ROOT_PATH="N/A"
        log_info "Project root detected: \${CURRENT_PROJECT_PATH}"
        CURRENT_PROJECT_NAME=\$(basename "\${CURRENT_PROJECT_PATH}")
        return 1
    fi

    CURRENT_DRUPAL_ROOT_PATH="\$found_drupal_root"
    CURRENT_PROJECT_NAME=\$(basename "\${CURRENT_PROJECT_PATH}")

    log_success "Drupal project detected!"
    log_info "Project root: \${CURRENT_PROJECT_PATH}"
    log_info "Drupal web root: \${CURRENT_DRUPAL_ROOT_PATH}"
    log_info "Project name: \${CURRENT_PROJECT_NAME}"
    return 0
}

# get_project_name_from_git: Extracts project name from Git remote URL.
get_project_name_from_git() {
    if [[ -z "\${CURRENT_PROJECT_PATH}" ]]; then
        echo "N/A"
        return 1
    fi
    local remote_url=\$(cd "\${CURRENT_PROJECT_PATH}" && git config --get remote.origin.url 2>/dev/null)
    if [[ -z "\$remote_url" ]]; then
        echo "\$(basename "\${CURRENT_PROJECT_PATH}")" # Fallback to directory name
        return 0
    fi
    # Extract project name from URL (e.g., git@github.com:user/project.git -> project)
    echo "\$remote_url" | sed -E 's/.*[\/:]([^/]+\.git)$/\1/' | sed 's/\.git$//'
}


# initialize_new_drupal_project: Guides the user through cloning a new Drupal project.
initialize_new_drupal_project() {
    log_info "Initializing a new Drupal project..."

    local repo_url
    repo_url=\$(prompt_for_input "Enter Git repository URL (e.g., git@gitlab.com:your/project.git):")
    if [[ -z "\$repo_url" ]]; then
        log_warn "\${TXT_OPERATION_CANCELLED}"
        return 0
    fi

    local project_name=\$(get_project_name_from_url "\$repo_url")
    project_name=\$(prompt_for_input "Enter project directory name (default: \$project_name):" "\$project_name")
    if [[ -z "\$project_name" ]]; then
        log_warn "\${TXT_OPERATION_CANCELLED}"
        return 0
    fi

    local parent_dir="\${PROJECTS_ROOT_PATH}"
    parent_dir=\$(prompt_for_input "Enter parent directory for the new project (default: \$parent_dir):" "\$parent_dir")
    if [[ ! -d "\$parent_dir" ]]; then
        log_warn "\$(printf "\${TXT_PATH_NOT_FOUND}" "\$parent_dir"). Creating it..."
        mkdir -p "\$parent_dir" || { log_error "Failed to create directory: \$parent_dir"; return 1; }
    fi

    local project_path="\${parent_dir}/\${project_name}"
    if [[ -d "\$project_path" ]]; then
        log_error "Directory '\$project_path' already exists. Please choose a different name or remove it."
        press_enter_to_continue
        return 1
    fi

    log_info "Cloning repository '\$repo_url' into '\$project_path'..."
    git clone "\$repo_url" "\$project_path"
    if [[ \$? -ne 0 ]]; then
        log_error "Git clone failed."
        generate_error_report "\$0" "Git clone \$repo_url failed" "\$?"
        press_enter_to_continue
        return 1
    fi

    # After cloning, change to the new project directory for further operations
    (cd "\$project_path" && detect_current_project_path)
    if [[ \$? -ne 0 ]]; then
        log_warn "Could not detect Drupal root in the newly cloned project. Proceeding without specific Drupal root."
    fi

    log_success "Project '\$project_name' cloned successfully into \${project_path}."

    # Automatically generate .env after cloning
    generate_env_file

    # Run composer install if composer.json exists in detected Drupal root
    if [[ -f "\${CURRENT_DRUPAL_ROOT_PATH}/composer.json" ]]; then
        composer_install
    else
        log_warn "No composer.json found in \${CURRENT_DRUPAL_ROOT_PATH}. Skipping 'composer install'."
    fi

    press_enter_to_continue
}

# get_project_name_from_url: Extracts project name from a Git URL.
# $1: Git URL
get_project_name_from_url() {
    local url="\$1"
    local name=\$(basename "\$url")
    echo "\${name%.*}" # Remove extension like .git
}

# generate_env_file: Generates .env from .env.dist interactively.
generate_env_file() {
    if [[ -z "\${CURRENT_DRUPAL_ROOT_PATH}" ]]; then
        log_error "\${TXT_NO_PROJECT_DETECTED}. Cannot generate .env file."
        press_enter_to_continue
        return 1
    fi

    local env_dist_path="\${CURRENT_DRUPAL_ROOT_PATH}/.env.dist"
    local env_path="\${CURRENT_DRUPAL_ROOT_PATH}/.env"

    if [[ ! -f "\$env_dist_path" ]]; then
        log_warn "No .env.dist found at '\$env_dist_path'. Cannot generate .env file."
        press_enter_to_continue
        return 1
    fi

    log_info "Generating .env from .env.dist..."

    # Create a temporary file for the new .env content
    local temp_env_content="\${TEMP_DIR}/.env_temp_\$(date +%s%N)"
    cp "\$env_dist_path" "\$temp_env_content"

    local variables_to_prompt=()
    # Read .env.dist line by line
    while IFS= read -r line; do
        # Extract non-commented lines that define a variable (VAR=value or VAR="value")
        if [[ "\$line" =~ ^[[:space:]]*([A-Z_]+)= ]]; then
            local var_name="\${BASH_REMATCH[1]}"
            # Exclude variables that are typically set by the system or hardcoded
            if [[ "\$var_name" != "APP_ENV" && "\$var_name" != "APP_SECRET" && "\$var_name" != "DATABASE_URL" ]]; then
                variables_to_prompt+=("\$var_name")
            fi
        fi
    done < "\$env_dist_path"

    # Iterate through unique variables and prompt user for values
    for var_name in "\$(echo "\${variables_to_prompt[@]}" | tr ' ' '\n' | sort -u)"; do
        local current_value=\$(grep "^[[:space:]]*\$var_name=" "\$temp_env_content" | head -1 | cut -d'=' -f2-)
        local new_value=\$(prompt_for_input "\$(printf "\${TXT_ENTER_VALUE_FOR}" "\$var_name")" "\${current_value//\"/}") # Remove quotes for display

        # Update the variable in the temporary file
        if grep -q "^[[:space:]]*\$var_name=" "\$temp_env_content"; then
            # Replace existing line
            sed -i.bak -E "s|^\s*\b\$var_name=.*|\$var_name=\"\$new_value\"|" "\$temp_env_content"
            rm -f "\$temp_env_content".bak # Clean up backup file
        else
            # Add if not present (shouldn't happen often if we parse .env.dist correctly)
            echo "\$var_name=\"\$new_value\"" >> "\$temp_env_content"
        fi
    done

    # Move the temporary file to the final .env location
    mv "\$temp_env_content" "\$env_path"
    if [[ \$? -eq 0 ]]; then
        log_success ".env file generated and updated at '\$env_path'."
    else
        log_error "Failed to generate .env file."
        generate_error_report "\$0" "Failed to generate .env file" "\$?"
    fi
    press_enter_to_continue
}

EOF

    touch "${CORE_DIR}/solr.sh"
    cat <<EOF > "${CORE_DIR}/solr.sh"
#!/bin/bash

# core/solr.sh
# Functions for Search API Solr management using Drush.

# solr_menu: Displays the Search API Solr management menu.
solr_menu() {
    local options=(
        "\${TXT_SOLR_SERVER_LIST}"
        "\${TXT_SOLR_INDEX_LIST}"
        "\${TXT_SOLR_EXPORT_CONFIG}"
        "\${TXT_SOLR_INDEX}"
        "\${TXT_SOLR_CLEAR}"
        "\${TXT_SOLR_STATUS}"
        "\${TXT_SOLR_BACK}"
    )

    while true; do
        display_header
        log_info_no_log "\${TXT_SOLR_MENU_TITLE}"
        log_info_no_log "\$(printf "\${TXT_DRUSH_TARGET_CURRENTLY_SELECTED}" "\${DRUSH_CURRENT_TARGET:-"\${TXT_DRUSH_ALIAS_NOT_SET}"}")"
        echo ""

        local choice
        choice=\$(display_menu "\${options[@]}")

        case "\${choice}" in
            "\${TXT_SOLR_SERVER_LIST}")
                drush_solr_server_list
                ;;
            "\${TXT_SOLR_INDEX_LIST}")
                drush_solr_index_list
                ;;
            "\${TXT_SOLR_EXPORT_CONFIG}")
                drush_solr_export_config
                ;;
            "\${TXT_SOLR_INDEX}")
                drush_solr_index_content
                ;;
            "\${TXT_SOLR_CLEAR}")
                drush_solr_clear_index
                ;;
            "\${TXT_SOLR_STATUS}")
                drush_solr_status
                ;;
            "\${TXT_SOLR_BACK}")
                break
                ;;
            *)
                log_error "\${TXT_INVALID_OPTION}"
                press_enter_to_continue
                ;;
        esac
    done
}

# drush_solr_server_list: Lists configured Solr servers.
drush_solr_server_list() {
    log_info "Listing Search API Solr servers..."
    run_drush_command "search-api:server-list"
    press_enter_to_continue
}

# drush_solr_index_list: Lists configured Solr indexes.
drush_solr_index_list() {
    log_info "Listing Search API Solr indexes..."
    run_drush_command "search-api:index-list"
    press_enter_to_continue
}

# drush_solr_export_config: Exports Solr configuration.
drush_solr_export_config() {
    local export_path="\${CURRENT_PROJECT_PATH}/solr_configs"
    export_path=\$(prompt_for_input "\$(printf "\${TXT_SOLR_EXPORT_PATH}" "\$export_path")" "\$export_path")
    if [[ -z "\$export_path" ]]; then
        log_warn "\${TXT_OPERATION_CANCELLED}"
        return 0
    fi

    mkdir -p "\$export_path" || { log_error "Failed to create export directory: \$export_path"; return 1; }

    log_info "Exporting Solr configuration to \$export_path..."
    run_drush_command "search-api-solr:export-solr-config --destination=\"\$export_path\""
    press_enter_to_continue
}

# drush_solr_index_content: Indexes content for a specific Solr index.
drush_solr_index_content() {
    local index_id=\$(prompt_for_input "\${TXT_SOLR_ENTER_INDEX_ID}")
    if [[ -z "\$index_id" ]]; then
        log_warn "\${TXT_OPERATION_CANCELLED}"
        return 0
    fi
    log_info "Indexing content for Solr index: \$index_id..."
    run_drush_command "search-api:index \$index_id"
    press_enter_to_continue
}

# drush_solr_clear_index: Clears a specific Solr index.
drush_solr_clear_index() {
    local index_id=\$(prompt_for_input "\${TXT_SOLR_ENTER_INDEX_ID}")
    if [[ -z "\$index_id" ]]; then
        log_warn "\${TXT_OPERATION_CANCELLED}"
        return 0
    fi
    if confirm_action "Are you sure you want to clear Solr index '\$index_id'? (yes/no): "; then
        log_info "Clearing Solr index: \$index_id..."
        run_drush_command "search-api:clear \$index_id"
    else
        log_warn "\${TXT_OPERATION_CANCELLED}"
    fi
    press_enter_to_continue
}

# drush_solr_status: Shows Solr index status.
drush_solr_status() {
    log_info "Showing Search API Solr status..."
    run_drush_command "search-api:status"
    press_enter_to_continue
}
EOF

    touch "${HELPERS_DIR}/i18n.sh"
    cat <<EOF > "${HELPERS_DIR}/i18n.sh"
#!/bin/bash

# helpers/i18n.sh
# Internationalization (i18n) functions.

# Global variable for current language
CURRENT_LANG=""

# initialize_i18n: Detects system language and loads appropriate messages.
initialize_i18n() {
    local system_lang="\$(locale | grep LANG | cut -d'=' -f2 | cut -d'.' -f1)"

    if [[ -f "\${AUB_TOOLS_PATH}/lang/\${system_lang}/messages.sh" ]]; then
        CURRENT_LANG="\$system_lang"
    elif [[ -f "\${AUB_TOOLS_PATH}/lang/\${DEFAULT_LANG}/messages.sh" ]]; then
        CURRENT_LANG="\$DEFAULT_LANG"
    else
        # Fallback to English if default is not found either
        CURRENT_LANG="en_US"
    fi

    log_debug "Initializing i18n. Detected language: \$system_lang. Using: \$CURRENT_LANG"
    load_messages "\${CURRENT_LANG}"
}

# load_messages: Sources the messages file for the given language.
# $1: Language code (e.g., "en_US", "fr_FR")
load_messages() {
    local lang_code="\$1"
    local messages_file="\${AUB_TOOLS_PATH}/lang/\${lang_code}/messages.sh"

    if [[ -f "\$messages_file" ]]; then
        source "\$messages_file"
        log_debug "Loaded messages for language: \$lang_code"
    else
        log_error "Messages file not found for language: \$lang_code at \$messages_file"
        # If the requested language file is missing, try to fall back to English
        if [[ "\$lang_code" != "en_US" ]]; then
            log_warn "Falling back to English messages."
            source "\${AUB_TOOLS_PATH}/lang/en_US/messages.sh"
            CURRENT_LANG="en_US"
        else
            log_error "Critical: English messages file also missing!"
            # Define some fallback text directly if truly nothing is found
            TXT_AUBAY_DEVTOOLS_HEADER="AUBAY DevTools (Error: No translations)"
            TXT_MAIN_MENU_EXIT="Exit"
            TXT_INVALID_OPTION="Invalid option."
            TXT_PRESS_ENTER_TO_CONTINUE="Press ENTER to continue..."
            TXT_OPERATION_CANCELLED="Operation cancelled."
        fi
    fi
}

# set_tool_language: Changes the tool's language interactively.
set_tool_language() {
    local options=("en_US" "fr_FR") # Add more languages here as needed

    log_info_no_log "\${TXT_CONFIG_SELECT_LANG}"
    local selected_lang=\$(display_menu "\${options[@]}")

    if [[ -n "\$selected_lang" ]]; then
        CURRENT_LANG="\$selected_lang"
        load_messages "\$selected_lang"
        log_success "\$(printf "\${TXT_CONFIG_TOGGLE_SUCCESS}")"
    else
        log_warn "\${TXT_OPERATION_CANCELLED}"
    fi
    press_enter_to_continue
}

# get_translation: A simple function to get a translated string.
# This isn't strictly necessary with the current sourcing method, but good for consistency.
# $1: The variable name of the translated string (e.g., "TXT_MAIN_MENU_TITLE")
get_translation() {
    local key="\$1"
    # Use indirect expansion to get the value of the variable named by \$key
    echo "\${!key}"
}
EOF

    touch "${HELPERS_DIR}/log.sh"
    cat <<EOF > "${HELPERS_DIR}/log.sh"
#!/bin/bash

# helpers/log.sh
# Functions for logging with configurable verbosity.

# initialize_logging: Sets up logging and ensures the log directory exists.
initialize_logging() {
    mkdir -p "\${TEMP_DIR}"
    LOG_FILE="\${TEMP_DIR}/aub-tools.log"
    # Clear log file on start
    > "\$LOG_FILE"
    log_debug "Logging initialized. Log file: \$LOG_FILE"
}

# get_log_level_numeric: Converts log level string to a numeric value.
# Used for comparison.
get_log_level_numeric() {
    case "\$1" in
        "DEBUG") echo 0 ;;
        "INFO") echo 1 ;;
        "WARN") echo 2 ;;
        "ERROR") echo 3 ;;
        "SUCCESS") echo 4 ;;
        *) echo 1 # Default to INFO
    esac
}

# _log_message: Internal function to handle logging.
# $1: Log level (DEBUG, INFO, WARN, ERROR, SUCCESS)
# $2: Message
# $3: Color code (optional)
# $4: No log to file flag (optional)
_log_message() {
    local level="\$1"
    local message="\$2"
    local color_code="\$3" # e.g., "\e[34m" for blue
    local no_file_log="\$4" # "true" to skip logging to file

    local current_level_num=\$(get_log_level_numeric "\${LOG_LEVEL}")
    local message_level_num=\$(get_log_level_numeric "\$level")

    # Display to console if current log level allows
    if [[ \$message_level_num -ge \$current_level_num ]]; then
        local timestamp="\$(date +'%Y-%m-%d %H:%M:%S')"
        local prefix="[\${level}]"
        if [[ -n "\$color_code" ]]; then
            echo -e "\${color_code}\${timestamp} \${prefix} \${message}\e[0m" >&2
        else
            echo -e "\${timestamp} \${prefix} \${message}" >&2
        fi
    fi

    # Log to file unless no_file_log is true
    if [[ "\$no_file_log" != "true" ]]; then
        echo "\$(date +'%Y-%m-%d %H:%M:%S') [\${level}] \${message}" >> "\$LOG_FILE"
    fi
}

# Public logging functions
log_debug() { _log_message "DEBUG" "\$1" "\e[35m"; } # Magenta
log_info() { _log_message "INFO" "\$1" "\e[34m"; }  # Blue
log_warn() { _log_message "WARN" "\$1" "\e[33m"; }  # Yellow
log_error() { _log_message "ERROR" "\$1" "\e[31m"; } # Red
log_success() { _log_message "SUCCESS" "\$1" "\e[32m"; } # Green

# Special functions for messages that should NOT go to the log file (e.g., menu headers)
log_info_no_log() { _log_message "INFO" "\$1" "\e[34m" "true"; }
log_warn_no_log() { _log_message "WARN" "\$1" "\e[33m" "true"; }
log_error_no_log() { _log_message "ERROR" "\$1" "\e[31m" "true"; }

# set_log_verbosity: Allows user to change the log level.
set_log_verbosity() {
    local options=("DEBUG" "INFO" "WARN" "ERROR" "SUCCESS")

    log_info_no_log "\${TXT_CONFIG_SELECT_LOG_LEVEL}"
    local selected_level=\$(display_menu "\${options[@]}")

    if [[ -n "\$selected_level" ]]; then
        LOG_LEVEL="\$selected_level"
        log_success "\$(printf "\${TXT_CONFIG_TOGGLE_SUCCESS}")"
    else
        log_warn "\${TXT_OPERATION_CANCELLED}"
    fi
    press_enter_to_continue
}
EOF

    touch "${HELPERS_DIR}/menu.sh"
    cat <<EOF > "${HELPERS_DIR}/menu.sh"
#!/bin/bash

# helpers/menu.sh
# Functions for interactive menus using arrow keys/tab and enter.

# display_menu: Displays an interactive menu and returns the selected option.
# Arguments: Any number of menu options as separate arguments.
# Usage: selected_option=\$(display_menu "Option 1" "Option 2" "Exit")
display_menu() {
    local options=("\$@")
    local selected_idx=0
    local key
    local num_options=\${#options[@]}

    while true; do
        clear # Clear screen before redrawing menu
        echo "" # Add some space
        for i in "\$(seq 0 \$((\$num_options - 1)))"; do
            if [[ "\$i" -eq "\$selected_idx" ]]; then
                echo -e "> \e[36m\${options[\$i]}\e[0m" # Cyan for selected option
            else
                echo -e "  \${options[\$i]}"
            fi
        done
        echo ""
        echo "\${TXT_SELECT_OPTION}"

        # Read single character input without waiting for Enter
        # -s: Do not echo input characters.
        # -r: Backslash does not act as an escape character.
        # -n 1: Read exactly one character.
        # -t 0.1: Timeout after 0.1 seconds (for non-blocking read in some cases, though not strictly needed for arrow keys)
        # Bash specific: read -s -n 1 key
        # Zsh specific: read -s -k 1 key
        read -s -n 1 key

        case "\$key" in
            # Arrow keys (common sequences)
            $'\x1b') # ESC character
                read -s -n 1 -t 0.1 key_arrow # Read next char ( [ )
                if [[ "\$key_arrow" == "[" ]]; then
                    read -s -n 1 -t 0.1 key_arrow # Read next char ( A, B, C, D )
                    case "\$key_arrow" in
                        A) # Up arrow
                            selected_idx=\$(( (selected_idx - 1 + num_options) % num_options ))
                            ;;
                        B) # Down arrow
                            selected_idx=\$(( (selected_idx + 1) % num_options ))
                            ;;
                        C) # Right arrow (often behaves like tab)
                            selected_idx=\$(( (selected_idx + 1) % num_options ))
                            ;;
                        D) # Left arrow (often behaves like shift+tab)
                            selected_idx=\$(( (selected_idx - 1 + num_options) % num_options ))
                            ;;
                    esac
                fi
                ;;
            "") # Enter key
                echo "\${options[\$selected_idx]}"
                return 0
                ;;
            $'\t') # Tab key
                selected_idx=\$(( (selected_idx + 1) % num_options ))
                ;;
            *) # Any other key (e.g., 'q' for quit, or first letter for direct jump, could be added)
                # For this basic menu, we just ignore other keys.
                ;;
        esac
    done
}

# display_menu_from_list: Displays an interactive menu from a newline-separated list.
# $1: Newline-separated string of options.
# Usage: selected_option=\$(echo "\$my_list" | display_menu_from_list)
display_menu_from_list() {
    local list_content=\$(cat) # Read from stdin
    local options=()
    IFS=$'\n' read -r -d '' -a options <<< "\$list_content"
    display_menu "\${options[@]}"
}
EOF

    touch "${HELPERS_DIR}/prompt.sh"
    cat <<EOF > "${HELPERS_DIR}/prompt.sh"
#!/bin/bash

# helpers/prompt.sh
# Functions for user input prompts.

# prompt_for_input: Prompts the user for input with an optional default value.
# $1: Prompt message
# $2: Default value (optional)
# Returns the user's input or the default value.
prompt_for_input() {
    local prompt_msg="\$1"
    local default_value="\$2"
    local input_value

    if [[ -n "\$default_value" ]]; then
        read -p "\$prompt_msg [default: \$default_value]: " input_value
        if [[ -z "\$input_value" ]]; then
            echo "\$default_value"
        else
            echo "\$input_value"
        fi
    else
        read -p "\$prompt_msg: " input_value
        echo "\$input_value"
    fi
}

# confirm_action: Prompts the user for a yes/no confirmation.
# $1: Confirmation message (e.g., "Are you sure? (yes/no): ")
# Returns 0 for yes, 1 for no.
confirm_action() {
    local confirm_msg="\$1"
    local response

    while true; do
        read -p "\$confirm_msg" response
        case "\$(echo "\$response" | tr '[:upper:]' '[:lower:]')" in
            yes|y)
                return 0
                ;;
            no|n)
                return 1
                ;;
            *)
                log_warn "Please answer 'yes' or 'no'."
                ;;
        esac
    done
}

# press_enter_to_continue: Waits for user to press Enter.
press_enter_to_continue() {
    echo "" # Newline for readability
    read -p "\${TXT_PRESS_ENTER_TO_CONTINUE}" -n 1 -s
    echo "" # Newline after enter
}
EOF

    touch "${HELPERS_DIR}/report.sh"
    cat <<EOF > "${HELPERS_DIR}/report.sh"
#!/bin/bash

# helpers/report.sh
# Functions for generating error reports.

# generate_error_report: Generates a detailed error report.
# $1: Script where error occurred (e.g., "$0")
# $2: Error message
# $3: Exit code (optional)
generate_error_report() {
    if [[ "\${ENABLE_ERROR_REPORTING}" != "true" ]]; then
        log_debug "Error reporting is disabled."
        return 0
    fi

    local error_script="\$1"
    local error_message="\$2"
    local exit_code="\$3"
    local report_filename="\$(date +%Y%m%d%H%M%S)_aub_tools_error.log"
    local report_path="\${TEMP_DIR}/\${report_filename}"

    log_error "An error occurred: \$error_message (Exit Code: \${exit_code:-"N/A"})"
    log_warn "\$(printf "\${TXT_ERROR_REPORT_GENERATED}" "\$report_path")"

    {
        echo "--- AUB Tools Error Report ---"
        echo "Timestamp: \$(date)"
        echo "AUB Tools Version: 1.0"
        echo "Error Source Script: \${error_script}"
        echo "Error Message: \${error_message}"
        echo "Exit Code: \${exit_code:-"N/A"}"
        echo ""
        echo "--- System Information ---"
        echo "OS: \$(uname -a)"
        echo "Bash Version: \$BASH_VERSION"
        echo "Zsh Version: \$ZSH_VERSION" # Will be empty if not zsh
        echo "PATH: \$PATH"
        echo "HOME: \$HOME"
        echo "TEMP_DIR: \$TEMP_DIR"
        echo ""
        echo "--- Environment Variables (relevant) ---"
        env | grep -E "AUB_TOOLS_PATH|CURRENT_PROJECT_PATH|CURRENT_DRUPAL_ROOT_PATH|DRUSH_CURRENT_TARGET|LOG_LEVEL"
        echo ""
        echo "--- Tool Dependencies Versions ---"
        echo "git version: \$(git --version 2>/dev/null || echo "Not found")"
        echo "composer version: \$(composer --version 2>/dev/null || echo "Not found")"
        echo "drush version: \$(drush --version 2>/dev/null || echo "Not found")"
        echo "kubectl version: \$(kubectl version --client --short 2>/dev/null || echo "Not found")"
        echo "ibmcloud version: \$(ibmcloud version 2>/dev/null || echo "Not found")"
        echo "jq version: \$("\${JQ_BIN}" --version 2>/dev/null || echo "Not found")"
        echo ""
        echo "--- Recent AUB Tools Log Entries ---"
        tail -n 50 "\$LOG_FILE" 2>/dev/null || echo "No recent log entries or log file not found."
        echo ""
        echo "--- End of Report ---"
    } > "\$report_path"

    # Allow user to inspect report or continue
    press_enter_to_continue
}
EOF

    touch "${HELPERS_DIR}/utils.sh"
    cat <<EOF > "${HELPERS_DIR}/utils.sh"
#!/bin/bash

# helpers/utils.sh
# General utility functions.

# command_exists: Checks if a given command is available in PATH.
# $1: Command name
# Returns 0 if command exists, 1 otherwise.
command_exists() {
    command -v "\$1" >/dev/null 2>&1
}

# set_proxy: Configures proxy environment variables if they are set in config.sh.
set_proxy() {
    log_debug "Checking proxy settings..."
    if [[ -n "\$HTTP_PROXY" ]]; then
        export HTTP_PROXY
        export http_proxy
        log_debug "HTTP_PROXY set to: \$HTTP_PROXY"
    fi
    if [[ -n "\$HTTPS_PROXY" ]]; then
        export HTTPS_PROXY
        export https_proxy
        log_debug "HTTPS_PROXY set to: \$HTTPS_PROXY"
    fi
    if [[ -n "\$NO_PROXY" ]]; then
        export NO_PROXY
        export no_proxy
        log_debug "NO_PROXY set to: \$NO_PROXY"
    fi
}

# reset_proxy: Unsets proxy environment variables.
reset_proxy() {
    log_debug "Resetting proxy settings..."
    unset HTTP_PROXY http_proxy
    unset HTTPS_PROXY https_proxy
    unset NO_PROXY no_proxy
}

# toggle_boolean_setting: Toggles a boolean configuration setting (true/false).
# $1: The name of the variable to toggle (e.g., "ENABLE_HISTORY")
# $2: A string describing the setting for messages (e.g., "Command History")
toggle_boolean_setting() {
    local setting_var_name="\$1"
    local setting_description="\$2"

    local current_value="\${!setting_var_name}" # Indirect expansion
    local new_value

    if [[ "\$current_value" == "true" ]]; then
        new_value="false"
    else
        new_value="true"
    fi

    # Update the config.sh file directly
    if sed -i.bak "s/^\\(\s*\)\$setting_var_name=.*$/\\1\$setting_var_name=\$new_value/" "\${AUB_TOOLS_PATH}/helpers/config.sh"; then
        log_success "\$(printf "\${TXT_CONFIG_TOGGLE_SUCCESS}")"
        # Update the variable in the current shell session
        eval "\$setting_var_name=\$new_value"
    else
        log_error "Failed to update \$setting_description setting in config.sh."
        generate_error_report "\$0" "Failed to toggle setting: \$setting_var_name" "\$?"
    fi
    rm -f "\${AUB_TOOLS_PATH}/helpers/config.sh.bak" # Clean up backup
    press_enter_to_continue
}

# set_project_root_directory: Allows the user to set the PROJECTS_ROOT_PATH.
set_project_root_directory() {
    local new_path=\$(prompt_for_input "\${TXT_CONFIG_ENTER_PROJECTS_ROOT}" "\${PROJECTS_ROOT_PATH}")
    if [[ -n "\$new_path" ]]; then
        # Ensure path is absolute
        new_path="\$(realpath -q "\$new_path")"
        if [[ \$? -ne 0 ]]; then
            log_error "Invalid path entered: \$new_path"
            press_enter_to_continue
            return 1
        fi

        if sed -i.bak "s|^PROJECTS_ROOT_PATH=.*\$|PROJECTS_ROOT_PATH=\"\$new_path\"|" "\${AUB_TOOLS_PATH}/helpers/config.sh"; then
            log_success "\$(printf "\${TXT_CONFIG_TOGGLE_SUCCESS}")"
            PROJECTS_ROOT_PATH="\$new_path" # Update in current session
        else
            log_error "Failed to update PROJECTS_ROOT_PATH in config.sh."
            generate_error_report "\$0" "Failed to set PROJECTS_ROOT_PATH" "\$?"
        fi
        rm -f "\${AUB_TOOLS_PATH}/helpers/config.sh.bak"
    else
        log_warn "\${TXT_OPERATION_CANCELLED}"
    fi
    press_enter_to_continue
}
EOF

    touch "${HELPERS_DIR}/history.sh"
    cat <<EOF > "${HELPERS_DIR}/history.sh"
#!/bin/bash

# helpers/history.sh
# Functions for command history management.

# record_command: Records a command into the history file.
# $1: The command to record.
record_command() {
    if [[ "\${ENABLE_HISTORY}" != "true" ]]; then
        log_debug "Command history is disabled."
        return 0
    fi
    echo "\$(date +'%Y-%m-%d %H:%M:%S')|\$1" >> "\$HISTORY_FILE"
    log_debug "Command recorded: \$1"
}

# history_menu: Displays the command history and allows replaying commands.
history_menu() {
    if [[ ! -f "\$HISTORY_FILE" || ! -s "\$HISTORY_FILE" ]]; then
        log_info "\${TXT_HISTORY_NO_ENTRIES}"
        press_enter_to_continue
        return 0
    fi

    local options=()
    local raw_commands=()
    local i=0
    # Read history in reverse order for newest first
    while IFS='|' read -r timestamp command; do
        options+=("[\$timestamp] \$command")
        raw_commands+=("\$command")
        ((i++))
    done < <(tac "\$HISTORY_FILE") # 'tac' reads file lines in reverse

    local menu_options=("${options[@]}" "\${TXT_HISTORY_BACK}")

    while true; do
        display_header
        log_info_no_log "\${TXT_HISTORY_MENU_TITLE}"
        log_info_no_log "\${TXT_HISTORY_REPLAY_INSTRUCTIONS}"
        echo ""

        local choice_text=\$(display_menu "\${menu_options[@]}")
        local choice_index=0

        # Find the index of the chosen text (excluding the date prefix for comparison)
        local found=false
        for idx in "\$(seq 0 \$((\${#options[@]} - 1)))"; do
            if [[ "\${options[\$idx]}" == "\$choice_text" ]]; then
                choice_index="\$idx"
                found=true
                break
            fi
        done

        if [[ "\$found" == "true" ]]; then
            local command_to_replay="\${raw_commands[\$choice_index]}"
            log_info "Replaying command: \$command_to_replay"
            # It's crucial to evaluate the command in the current shell context
            # or source it if it contains functions/variables.
            # For simplicity, we'll eval. For complex commands, this might need refinement.
            eval "\$command_to_replay"
            press_enter_to_continue
        elif [[ "\$choice_text" == "\${TXT_HISTORY_BACK}" ]]; then
            break
        else
            log_error "\${TXT_INVALID_OPTION}"
            press_enter_to_continue
        fi
    done
}

# toggle_history_feature: Toggles the ENABLE_HISTORY setting.
toggle_history_feature() {
    log_info "Toggling command history..."
    toggle_boolean_setting "ENABLE_HISTORY" "Command History"
}
EOF

    touch "${HELPERS_DIR}/favorites.sh"
    cat <<EOF > "${HELPERS_DIR}/favorites.sh"
#!/bin/bash

# helpers/favorites.sh
# Functions for managing custom favorites/shortcuts.

# favorites_menu: Displays custom favorites and allows executing them.
favorites_menu() {
    if [[ "\${ENABLE_FAVORITES}" != "true" ]]; then
        log_info "Custom favorites feature is disabled."
        press_enter_to_continue
        return 0
    fi

    # Ensure the favorites file exists, create if not
    if [[ ! -f "\$FAVORITES_FILE" ]]; then
        touch "\$FAVORITES_FILE"
        chmod 600 "\$FAVORITES_FILE" # Restrict permissions
        log_info "Created empty favorites file: \$FAVORITES_FILE"
        echo "# Add your custom functions or aliases here." >> "\$FAVORITES_FILE"
        echo "# Example: my_custom_drush_command() { drush cr; drush cim -y; }" >> "\$FAVORITES_FILE"
        echo "# Then it will appear in the menu." >> "\$FAVORITES_FILE"
    fi

    # Source the favorites file to make its functions/aliases available
    source "\$FAVORITES_FILE" || {
        log_error "Failed to source favorites file: \$FAVORITES_FILE. Check for syntax errors."
        generate_error_report "\$0" "Failed to source favorites file" "\$?"
        press_enter_to_continue
        return 1
    }

    local options=()
    local favorite_functions=()

    # Get functions defined in the favorites file
    # This is a bit tricky; we'll parse the file for function definitions.
    # Assumes simple function definitions like "func_name() { ... }"
    while IFS= read -r line; do
        if [[ "\$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)\(\)[[:space:]]*\{ ]]; then
            local func_name="\${BASH_REMATCH[1]}"
            options+=("\$func_name")
            favorite_functions+=("\$func_name")
        fi
    done < "\$FAVORITES_FILE"

    if [[ \${#options[@]} -eq 0 ]]; then
        log_info "\$(printf "\${TXT_FAVORITES_NO_ENTRIES}" "\$FAVORITES_FILE")"
        log_info "\$(printf "\${TXT_FAVORITES_HELP}" "\$FAVORITES_FILE")"
        press_enter_to_continue
        return 0
    fi

    local menu_options=("${options[@]}" "\${TXT_FAVORITES_BACK}")

    while true; do
        display_header
        log_info_no_log "\${TXT_FAVORITES_MENU_TITLE}"
        log_info_no_log "\$(printf "\${TXT_FAVORITES_HELP}" "\$FAVORITES_FILE")"
        echo ""

        local choice_text=\$(display_menu "\${menu_options[@]}")
        local choice_found=false

        for func_name in "\${favorite_functions[@]}"; do
            if [[ "\$func_name" == "\$choice_text" ]]; then
                log_info "Executing favorite: \$func_name"
                # Call the function directly
                "\$func_name"
                choice_found=true
                press_enter_to_continue
                break
            fi
        done

        if [[ "\$choice_text" == "\${TXT_FAVORITES_BACK}" ]]; then
            break
        elif [[ "\$choice_found" == "false" ]]; then
            log_error "\${TXT_INVALID_OPTION}"
            press_enter_to_continue
        fi
    done
}

# toggle_favorites_feature: Toggles the ENABLE_FAVORITES setting.
toggle_favorites_feature() {
    log_info "Toggling custom favorites..."
    toggle_boolean_setting "ENABLE_FAVORITES" "Custom Favorites"
}
EOF

    log_success "Core files created and populated."
}

# Add aub-tools to PATH
add_to_path() {
    log_info "Adding AUB Tools to your PATH..."
    local shell_rc_file=""

    if [[ -n "\$ZSH_VERSION" ]]; then
        shell_rc_file="\${HOME}/.zshrc"
    elif [[ -n "\$BASH_VERSION" ]]; then
        shell_rc_file="\${HOME}/.bashrc"
    else
        log_warn "Could not detect shell (Bash or Zsh). Please add the following line to your shell's RC file manually:"
        echo "export PATH=\"\${BIN_DIR}:\$PATH\""
        return 0
    fi

    if ! grep -q "export PATH=\"\${INSTALL_DIR}/bin:\$PATH\"" "\$shell_rc_file"; then
        echo -e "\n# Add AUB Tools to PATH" >> "\$shell_rc_file"
        echo "export AUB_TOOLS_PATH=\"\${INSTALL_DIR}\"" >> "\$shell_rc_file"
        echo "export PATH=\"\${INSTALL_DIR}/bin:\$PATH\"" >> "\$shell_rc_file"
        log_success "Added AUB Tools to PATH in \${shell_rc_file}. Please run 'source \${shell_rc_file}' or restart your terminal."
    else
        log_info "AUB Tools is already in your PATH."
    fi
}

# --- Main Installation Logic ---
log_info "Starting AUB Tools installation..."

create_directories
create_core_files
download_jq
add_to_path

log_success "AUB Tools installation complete!"
log_info "You can now run 'aub-tools' after sourcing your shell's RC file or restarting your terminal."

exit 0
EOF
