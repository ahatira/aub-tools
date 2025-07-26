# File: install.sh
#!/bin/bash

# Define the installation directory
INSTALL_DIR="${HOME}/.aub-tools"
BIN_DIR="${INSTALL_DIR}/bin"
CORE_DIR="${INSTALL_DIR}/core"
LANG_DIR="${INSTALL_DIR}/lang"
HELPERS_DIR="${INSTALL_DIR}/helpers"
CONFIG_DIR="${HOME}/.aub-tools_config" # User-specific config directory

# --- Helper functions for installation ---

log_info() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

log_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

# --- Main installation script ---

log_info "Starting AUB Tools installation..."

# Create installation directories
log_info "Creating necessary directories..."
mkdir -p "${BIN_DIR}" || { log_error "Failed to create bin directory."; exit 1; }
mkdir -p "${CORE_DIR}" || { log_error "Failed to create core directory."; exit 1; }
mkdir -p "${LANG_DIR}/en_US" || { log_error "Failed to create lang/en_US directory."; exit 1; }
mkdir -p "${LANG_DIR}/fr_FR" || { log_error "Failed to create lang/fr_FR directory."; exit 1; }
mkdir -p "${HELPERS_DIR}" || { log_error "Failed to create helpers directory."; exit 1; }
mkdir -p "${CONFIG_DIR}" || { log_error "Failed to create config directory."; exit 1; }

# Download jq
log_info "Downloading jq (JSON processor)..."
JQ_URL="https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64" # Adjust for other OS if needed
if [[ "$(uname)" == "Darwin" ]]; then
    JQ_URL="https://github.com/stedolan/jq/releases/download/jq-1.6/jq-osx-amd64"
elif [[ "$(expr substr $(uname -s) 1 5)" == "Linux" ]]; then
    JQ_URL="https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64"
fi

curl -sLo "${BIN_DIR}/jq" "$JQ_URL" && chmod +x "${BIN_DIR}/jq" || { log_error "Failed to download or make jq executable. Please install jq manually."; exit 1; }
log_success "jq downloaded and installed."

# Create main entry script (aub-tools)
log_info "Creating main entry script: ${BIN_DIR}/aub-tools"
cat << 'EOF' > "${BIN_DIR}/aub-tools"
#!/bin/bash

# Source global configuration and helper functions
# This ensures that all scripts have access to common variables and functions.
# The path is relative to the script's location, assuming it's in bin/
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
AUB_TOOLS_DIR="${SCRIPT_DIR}/.."

# Load configuration and helper modules
source "${AUB_TOOLS_DIR}/helpers/config.sh"
source "${AUB_TOOLS_DIR}/helpers/i18n.sh"
source "${AUB_TOOLS_DIR}/helpers/log.sh"
source "${AUB_TOOLS_DIR}/helpers/menu.sh"
source "${AUB_TOOLS_DIR}/helpers/utils.sh"
source "${AUB_TOOLS_DIR}/helpers/history.sh"
source "${AUB_TOOLS_DIR}/helpers/favorites.sh"
source "${AUB_TOOLS_DIR}/helpers/report.sh"


# Load core modules
source "${AUB_TOOLS_DIR}/core/composer.sh"
source "${AUB_TOOLS_DIR}/core/database.sh"
source "${AUB_TOOLS_DIR}/core/drush.sh"
source "${AUB_TOOLS_DIR}/core/git.sh"
source "${AUB_TOOLS_DIR}/core/ibmcloud.sh"
source "${AUB_TOOLS_DIR}/core/k8s.sh"
source "${AUB_TOOLS_DIR}/core/project.sh"
source "${AUB_TOOLS_DIR}/core/solr.sh"

# Main menu logic
source "${AUB_TOOLS_DIR}/core/main.sh"

# Global error handler for the main script
trap 'handle_error_and_report $LINENO "$BASH_COMMAND"' ERR

# Initialize logging and internationalization
initialize_config
initialize_i18n
initialize_history_and_favorites

# Display header
display_header() {
    clear
    echo "----------------------------------------------------"
    echo "                 DevxTools 1.0                      "
    echo "----------------------------------------------------"
    echo ""
}

# Call the main menu
display_header
main_menu
EOF
chmod +x "${BIN_DIR}/aub-tools"
log_success "Main entry script created."

# Create common helper scripts (helpers/)
log_info "Creating helper scripts..."

# helpers/config.sh
cat << 'EOF' > "${HELPERS_DIR}/config.sh"
#!/bin/bash

# File: helpers/config.sh
# Description: Configuration settings and initialization for AUB Tools.

# Global variables for configuration
AUB_TOOLS_CONFIG_DIR="${HOME}/.aub-tools_config"
AUB_TOOLS_LOG_FILE="${AUB_TOOLS_CONFIG_DIR}/aub-tools.log"
AUB_TOOLS_HISTORY_FILE="${AUB_TOOLS_CONFIG_DIR}/aub-tools_history"
AUB_TOOLS_FAVORITES_FILE="${AUB_TOOLS_CONFIG_DIR}/aub-tools_favorites.sh" # User-defined favorites

# Default language (fr_FR or en_US)
# This will be overridden by system language detection in i18n.sh
DEFAULT_LANG="en_US"
CURRENT_LANG="" # Will be set by i18n.sh

# Verbosity levels (DEBUG, INFO, WARN, ERROR, SUCCESS)
# Default verbosity level for logging and display
# Options: DEBUG, INFO, WARN, ERROR, SUCCESS
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3
LOG_LEVEL_SUCCESS=4
CURRENT_LOG_LEVEL_DISPLAY=$LOG_LEVEL_INFO # For console output
CURRENT_LOG_LEVEL_FILE=$LOG_LEVEL_DEBUG   # For log file

# Feature flags (true/false)
ENABLE_HISTORY="true"
ENABLE_FAVORITES="true"
ENABLE_ERROR_REPORTING="true"

# Drupal project specific configurations (default values)
DRUPAL_ROOT_DIR="src/web" # Common for composer-based Drupal projects
DRUPAL_DUMP_DIR="/data" # Default directory to look for DB dumps within a project

# IBM Cloud / Kubernetes specific configurations (default values, can be overridden by user)
IBMCLOUD_REGION=""      # User will be prompted if not set
IBMCLOUD_RESOURCE_GROUP="" # User will be prompted if not set

# Solr export directory (relative to project root or aub-tools root)
SOLR_CONFIG_EXPORT_DIR="solr_configs/" # Relative to the *project* root by default for drush

# --- Configuration Initialization ---

# Function to initialize configuration
initialize_config() {
    mkdir -p "${AUB_TOOLS_CONFIG_DIR}"

    # Check and create default favorites file if it doesn't exist
    if [[ ! -f "${AUB_TOOLS_FAVORITES_FILE}" ]]; then
        echo "#!/bin/bash" > "${AUB_TOOLS_FAVORITES_FILE}"
        echo "# Custom functions and aliases for AUB Tools." >> "${AUB_TOOLS_FAVORITES_FILE}"
        echo "# Example:" >> "${AUB_TOOLS_FAVORITES_FILE}"
        echo "# my_custom_command() {" >> "${AUB_TOOLS_FAVORITES_FILE}"
        echo "#   echo 'Hello from my custom command!'" >> "${A_TOOLS_FAVORITES_FILE}"
        echo "# }" >> "${AUB_TOOLS_FAVORITES_FILE}"
        echo "# export -f my_custom_command" >> "${AUB_TOOLS_FAVORITES_FILE}"
        chmod 700 "${AUB_TOOLS_FAVORITES_FILE}"
    fi

    log_debug "Configuration initialized. Log file: ${AUB_TOOLS_LOG_FILE}"
}

# Function to display/edit configuration (interactive, to be implemented later)
display_config_menu() {
    log_info "Configuration management (to be implemented)."
    # Example: Allow user to change LOG_LEVEL_DISPLAY, ENABLE_HISTORY, etc.
}

EOF

# helpers/i18n.sh
cat << 'EOF' > "${HELPERS_DIR}/i18n.sh"
#!/bin/bash

# File: helpers/i18n.sh
# Description: Internationalization functions for AUB Tools.

# Source messages based on current language
source_messages() {
    local lang_file="${AUB_TOOLS_DIR}/lang/${CURRENT_LANG}/messages.sh"
    if [[ -f "${lang_file}" ]]; then
        source "${lang_file}"
        log_debug "Loaded language file: ${lang_file}"
    else
        log_error "Language file not found: ${lang_file}. Falling back to default language: ${DEFAULT_LANG}."
        CURRENT_LANG="${DEFAULT_LANG}"
        source "${AUB_TOOLS_DIR}/lang/${CURRENT_LANG}/messages.sh"
    fi
}

# Function to initialize internationalization
initialize_i18n() {
    # Detect system language
    local system_lang=$(locale | grep LANG | cut -d'=' -f2 | cut -d'.' -f1)

    case "${system_lang}" in
        fr_FR)
            CURRENT_LANG="fr_FR"
            ;;
        en_US)
            CURRENT_LANG="en_US"
            ;;
        *)
            CURRENT_LANG="${DEFAULT_LANG}"
            log_warn "Unsupported system language '${system_lang}'. Using default language: ${DEFAULT_LANG}."
            ;;
    esac

    source_messages
    log_debug "Internationalization initialized. Current language: ${CURRENT_LANG}"
}

# Function to translate messages
# Usage: _ "MESSAGE_KEY"
_() {
    local key="$1"
    local message="${!key}" # Indirect expansion to get the value of the variable named by $key
    if [[ -z "${message}" ]]; then
        log_warn "Missing translation for key: ${key}. Using key as fallback."
        echo "${key}"
    else
        echo "${message}"
    fi
}
EOF

# lang/en_US/messages.sh
mkdir -p "${LANG_DIR}/en_US"
cat << 'EOF' > "${LANG_DIR}/en_US/messages.sh"
#!/bin/bash

# File: lang/en_US/messages.sh
# English translations for AUB Tools.

# General messages
MSG_WELCOME="Welcome to DevxTools 1.0!"
MSG_SELECT_OPTION="Please select an option:"
MSG_PRESS_ENTER_TO_CONTINUE="Press ENTER to continue..."
MSG_OPERATION_CANCELLED="Operation cancelled."
MSG_INVALID_SELECTION="Invalid selection. Please try again."
MSG_BACK_TO_MAIN_MENU="Back to Main Menu"
MSG_EXIT_TOOL="Exit AUB Tools"
MSG_CONFIRM_ACTION="Are you sure you want to perform this action? (y/N)"
MSG_YES="Yes"
MSG_NO="No"

# Project management
MSG_PROJECT_MENU_TITLE="Project Management"
MSG_PROJECT_INIT="Initialize New Project"
MSG_PROJECT_DETECT_DRUPAL_ROOT="Detecting Drupal root directory..."
MSG_PROJECT_CLONE_REPO="Cloning repository..."
MSG_PROJECT_COMPOSER_INSTALL="Running Composer install..."
MSG_PROJECT_GENERATE_ENV="Generating .env file..."
MSG_PROJECT_ENTER_VAR_VALUE="Enter value for %s (default: '%s'):"
MSG_PROJECT_ENV_GENERATED="'.env' file generated successfully."
MSG_PROJECT_DRUPAL_ROOT_FOUND="Drupal root found: %s"
MSG_PROJECT_DRUPAL_ROOT_NOT_FOUND="Could not find Drupal root directory. Please set DRUPAL_ROOT_DIR in config.sh or specify manually."

# Git management
MSG_GIT_MENU_TITLE="Git Management"
MSG_GIT_STATUS="Git Status"
MSG_GIT_LOG="Git Log"
MSG_GIT_BRANCH_MENU="Branch Management"
MSG_GIT_PULL="Git Pull"
MSG_GIT_PUSH="Git Push"
MSG_GIT_STASH_MENU="Stash Management"
MSG_GIT_UNDO_MENU="Undo Changes"
MSG_GIT_LIST_BRANCHES="List all branches (local and remote)"
MSG_GIT_CHECKOUT_BRANCH="Checkout an existing branch"
MSG_GIT_CREATE_BRANCH="Create a new branch"
MSG_GIT_ENTER_BRANCH_NAME="Enter new branch name:"
MSG_GIT_BRANCH_CREATED="Branch '%s' created."
MSG_GIT_CHECKED_OUT="Switched to branch '%s'."
MSG_GIT_PULL_SUCCESS="Git pull completed successfully."
MSG_GIT_PUSH_SUCCESS="Git push completed successfully."
MSG_GIT_NO_CHANGES="No changes detected."
MSG_GIT_UNCOMMITTED_CHANGES="You have uncommitted changes. Please commit or stash them before switching branches."
MSG_GIT_FETCH_ALL="Fetching all remotes and pruning..."
MSG_GIT_STASH_SAVE="Save changes to stash"
MSG_GIT_STASH_LIST="List stashes"
MSG_GIT_STASH_APPLY="Apply a stash"
MSG_GIT_STASH_POP="Pop a stash (apply and drop)"
MSG_GIT_STASH_DROP="Drop a stash"
MSG_GIT_STASH_MESSAGE="Enter a message for the stash:"
MSG_GIT_STASH_SAVED="Changes stashed."
MSG_GIT_NO_STASHES="No stashes found."
MSG_GIT_RESET_HARD="Git Reset --hard (discard all local changes)"
MSG_GIT_REVERT_COMMIT="Git Revert (undo a specific commit)"
MSG_GIT_CLEAN_FORCE="Git Clean -df (remove untracked files/dirs)"

# Drush management
MSG_DRUSH_MENU_TITLE="Drush Management"
MSG_DRUSH_SELECT_TARGET="Select Drush target (site alias or URI):"
MSG_DRUSH_CURRENT_TARGET="Current Drush target: %s"
MSG_DRUSH_GENERAL_MENU="General Drush Commands"
MSG_DRUSH_CONFIG_MENU="Configuration Management"
MSG_DRUSH_DB_MENU="Database Management"
MSG_DRUSH_MODULES_THEMES_MENU="Modules & Themes"
MSG_DRUSH_USERS_MENU="User Management"
MSG_DRUSH_WATCHDOG_MENU="Watchdog Logs"
MSG_DRUSH_SOLR_MENU="Search API Solr"
MSG_DRUSH_WEBFORM_MENU="Webform Management"
MSG_DRUSH_DEV_TOOLS_MENU="Development Tools"
MSG_DRUSH_STATUS="Drush Status"
MSG_DRUSH_CR="Drush Cache Rebuild (drush cr)"
MSG_DRUSH_CIM="Drush Config Import (drush cim)"
MSG_DRUSH_CEX="Drush Config Export (drush cex)"
MSG_DRUSH_PM_LIST="List Modules/Themes"
MSG_DRUSH_PM_ENABLE="Enable Module/Theme"
MSG_DRUSH_PM_DISABLE="Disable Module/Theme"
MSG_DRUSH_PM_UNINSTALL="Uninstall Module/Theme"
MSG_DRUSH_USER_LOGIN="Login as User (Uli)"
MSG_DRUSH_USER_BLOCK="Block User"
MSG_DRUSH_USER_UNBLOCK="Unblock User"
MSG_DRUSH_USER_PASSWORD="Change User Password"
MSG_DRUSH_WATCHDOG_SHOW="Show Watchdog (recent)"
MSG_DRUSH_WATCHDOG_LIST="List Watchdog Types"
MSG_DRUSH_WATCHDOG_DELETE="Delete Watchdog Logs"
MSG_DRUSH_WATCHDOG_TAIL="Tail Watchdog Logs"
MSG_DRUSH_EV="Execute PHP code (drush ev)"
MSG_DRUSH_PHP="Interactive PHP Shell (drush php)"
MSG_DRUSH_CRON="Run Drupal Cron (drush cron)"
MSG_DRUSH_WEBFORM_LIST="List Webforms"
MSG_DRUSH_WEBFORM_EXPORT="Export Webform Submissions"
MSG_DRUSH_WEBFORM_PURGE="Purge Webform Submissions"
MSG_DRUSH_ENTER_MODULE_THEME_NAME="Enter module/theme name:"
MSG_DRUSH_ENTER_USERNAME="Enter username:"
MSG_DRUSH_ENTER_NEW_PASSWORD="Enter new password for '%s':"
MSG_DRUSH_ENTER_WATCHDOG_TYPE="Enter watchdog type to delete (e.g., access denied):"
MSG_DRUSH_ENTER_PHP_CODE="Enter PHP code to execute:"
MSG_DRUSH_TARGET_NONE_SELECTED="No Drush target selected. Please select one first."

# Database management
MSG_DB_MENU_TITLE="Database Management"
MSG_DB_UPDATE="Drush Database Updates (drush updb)"
MSG_DB_DUMP="Drush SQL Dump (drush sql:dump)"
MSG_DB_CLI="Drush SQL CLI (drush sql:cli)"
MSG_DB_QUERY="Drush SQL Query (drush sql:query)"
MSG_DB_SYNC="Drush SQL Sync (drush sql:sync)"
MSG_DB_RESTORE="Restore Database from Dump"
MSG_DB_ENTER_QUERY="Enter SQL query:"
MSG_DB_SELECT_DUMP_FILE="Select a database dump file to restore:"
MSG_DB_NO_DUMPS_FOUND="No database dump files found in '%s'."
MSG_DB_DUMP_RESTORED="Database restored successfully from '%s'."
MSG_DB_DETECTED_FORMAT="Detected format: %s"
MSG_DB_DECOMPRESSING="Decompressing dump file..."
MSG_DB_PROMPT_SITE_MATCH="Multiple sites detected. Please specify which site this dump '%s' belongs to (e.g., default, site1):"
MSG_DB_MULTIPLE_DUMPS_MATCHING="Multiple dump files found matching format. Please select one."

# Solr management
MSG_SOLR_MENU_TITLE="Search API Solr Management"
MSG_SOLR_SERVER_LIST="List Solr Servers"
MSG_SOLR_INDEX_LIST="List Solr Indexes"
MSG_SOLR_EXPORT_CONFIG="Export Solr Configurations"
MSG_SOLR_INDEX_CONTENT="Index Content"
MSG_SOLR_CLEAR_INDEX="Clear Solr Index"
MSG_SOLR_STATUS="Solr Status"
MSG_SOLR_CONFIG_EXPORTED="Solr configurations exported to: %s"

# IBM Cloud integration
MSG_IBMCLOUD_MENU_TITLE="IBM Cloud Integration"
MSG_IBMCLOUD_LOGIN="IBM Cloud Login"
MSG_IBMCLOUD_LOGOUT="IBM Cloud Logout"
MSG_IBMCLOUD_LIST_K8S_CLUSTERS="List Kubernetes Clusters"
MSG_IBMCLOUD_CONFIGURE_KUBECTL="Configure Kubectl for a Cluster"
MSG_IBMCLOUD_ENTER_REGION="Enter IBM Cloud Region (e.g., eu-de):"
MSG_IBMCLOUD_ENTER_RESOURCE_GROUP="Enter IBM Cloud Resource Group (leave empty for default):"
MSG_IBMCLOUD_LOGIN_SUCCESS="Successfully logged into IBM Cloud."
MSG_IBMCLOUD_LOGOUT_SUCCESS="Successfully logged out from IBM Cloud."
MSG_IBMCLOUD_K8S_CONTEXT_SET="Kubectl context set for cluster '%s'."

# Kubernetes management
MSG_K8S_MENU_TITLE="Kubernetes Management"
MSG_K8S_CHECK_CONTEXT="Check Kubectl Context"
MSG_K8S_SELECT_POD="Select Pod"
MSG_K8S_SELECT_CONTAINER="Select Container"
MSG_K8S_SOLR_MENU="Solr Pod Management"
MSG_K8S_POSTGRES_MENU="PostgreSQL Pod Management"
MSG_K8S_COPY_FILES="Copy Files to Pod (kubectl cp)"
MSG_K8S_POD_STATUS="Pod Status (List)"
MSG_K8S_POD_RESTART="Restart Pod"
MSG_K8S_POD_LOGS="View Pod/Container Logs"
MSG_K8S_PSQL_CLI="Access PostgreSQL CLI (psql)"
MSG_K8S_CONTEXT_NOT_SET="Kubectl context not set. Please configure IBM Cloud or your kubectl."
MSG_K8S_ENTER_POD_LABEL_FILTER="Enter label filter for pods (e.g., app=drupal, leave empty for all):"
MSG_K8S_SELECT_POD_TO_MANAGE="Select a pod to manage:"
MSG_K8S_SELECT_CONTAINER_TO_MANAGE="Select a container to manage:"
MSG_K8S_ENTER_LOCAL_PATH="Enter local path to copy:"
MSG_K8S_ENTER_REMOTE_PATH="Enter remote path in container:"
MSG_K8S_COPY_SUCCESS="File(s) copied successfully to pod '%s' container '%s'."
MSG_K8S_COPY_FAILED="Failed to copy file(s)."
MSG_K8S_NO_PODS_FOUND="No pods found."
MSG_K8S_NO_CONTAINERS_FOUND="No containers found for selected pod."

# Logs and Reporting
MSG_LOG_DEBUG_LEVEL="DEBUG"
MSG_LOG_INFO_LEVEL="INFO"
MSG_LOG_WARN_LEVEL="WARN"
MSG_LOG_ERROR_LEVEL="ERROR"
MSG_LOG_SUCCESS_LEVEL="SUCCESS"
MSG_ERROR_OCCURRED="An error occurred on line %d during command: '%s'"
MSG_GENERATE_ERROR_REPORT="Do you want to generate a detailed error report? (y/N)"
MSG_ERROR_REPORT_GENERATED="Error report generated at: %s"
MSG_ERROR_REPORT_FAILED="Failed to generate error report."

# History and Favorites
MSG_HISTORY_MENU_TITLE="Command History"
MSG_HISTORY_VIEW="View History"
MSG_HISTORY_RUN_AGAIN="Run a historical command"
MSG_HISTORY_CLEAN="Clean History"
MSG_HISTORY_DISABLED="Command history is disabled in config.sh."
MSG_HISTORY_NO_ENTRIES="No history entries found."
MSG_FAVORITES_MENU_TITLE="Custom Favorites"
MSG_FAVORITES_VIEW="View Favorites"
MSG_FAVORITES_RUN="Run a Favorite"
MSG_FAVORITES_EDIT="Edit Favorites File"
MSG_FAVORITES_DISABLED="Favorites feature is disabled in config.sh."
MSG_FAVORITES_NO_ENTRIES="No favorites found."

# Other utils
MSG_ENTER_VALUE="Enter value:"
MSG_SEARCH="Search"
MSG_FILTER="Filter"
MSG_CANCEL="Cancel"
MSG_SELECT_AN_ITEM="Select an item:"
MSG_NO_ITEM_SELECTED="No item selected."

EOF

# lang/fr_FR/messages.sh
mkdir -p "${LANG_DIR}/fr_FR"
cat << 'EOF' > "${LANG_DIR}/fr_FR/messages.sh"
#!/bin/bash

# File: lang/fr_FR/messages.sh
# Traductions françaises pour AUB Tools.

# Messages généraux
MSG_WELCOME="Bienvenue dans DevxTools 1.0 !"
MSG_SELECT_OPTION="Veuillez sélectionner une option :"
MSG_PRESS_ENTER_TO_CONTINUE="Appuyez sur ENTRÉE pour continuer..."
MSG_OPERATION_CANCELLED="Opération annulée."
MSG_INVALID_SELECTION="Sélection invalide. Veuillez réessayer."
MSG_BACK_TO_MAIN_MENU="Retour au menu principal"
MSG_EXIT_TOOL="Quitter AUB Tools"
MSG_CONFIRM_ACTION="Voulez-vous vraiment effectuer cette action ? (o/N)"
MSG_YES="Oui"
MSG_NO="Non"

# Gestion de projet
MSG_PROJECT_MENU_TITLE="Gestion de Projet"
MSG_PROJECT_INIT="Initialiser un Nouveau Projet"
MSG_PROJECT_DETECT_DRUPAL_ROOT="Détection du répertoire racine Drupal..."
MSG_PROJECT_CLONE_REPO="Clonage du dépôt..."
MSG_PROJECT_COMPOSER_INSTALL="Exécution de Composer install..."
MSG_PROJECT_GENERATE_ENV="Génération du fichier .env..."
MSG_PROJECT_ENTER_VAR_VALUE="Entrez la valeur pour %s (par défaut : '%s') :"
MSG_PROJECT_ENV_GENERATED="Fichier '.env' généré avec succès."
MSG_PROJECT_DRUPAL_ROOT_FOUND="Racine Drupal trouvée : %s"
MSG_PROJECT_DRUPAL_ROOT_NOT_FOUND="Impossible de trouver le répertoire racine de Drupal. Veuillez définir DRUPAL_ROOT_DIR dans config.sh ou spécifier manuellement."

# Gestion Git
MSG_GIT_MENU_TITLE="Gestion Git"
MSG_GIT_STATUS="Statut Git"
MSG_GIT_LOG="Historique Git"
MSG_GIT_BRANCH_MENU="Gestion des Branches"
MSG_GIT_PULL="Git Pull"
MSG_GIT_PUSH="Git Push"
MSG_GIT_STASH_MENU="Gestion des Stashs"
MSG_GIT_UNDO_MENU="Annuler les Modifications"
MSG_GIT_LIST_BRANCHES="Lister toutes les branches (locales et distantes)"
MSG_GIT_CHECKOUT_BRANCH="Basculer vers une branche existante"
MSG_GIT_CREATE_BRANCH="Créer une nouvelle branche"
MSG_GIT_ENTER_BRANCH_NAME="Entrez le nom de la nouvelle branche :"
MSG_GIT_BRANCH_CREATED="Branche '%s' créée."
MSG_GIT_CHECKED_OUT="Basculé vers la branche '%s'."
MSG_GIT_PULL_SUCCESS="Git pull terminé avec succès."
MSG_GIT_PUSH_SUCCESS="Git push terminé avec succès."
MSG_GIT_NO_CHANGES="Aucune modification détectée."
MSG_GIT_UNCOMMITTED_CHANGES="Vous avez des modifications non-validées. Veuillez les committer ou les stasher avant de changer de branche."
MSG_GIT_FETCH_ALL="Récupération de tous les dépôts distants et nettoyage..."
MSG_GIT_STASH_SAVE="Sauvegarder les modifications dans un stash"
MSG_GIT_STASH_LIST="Lister les stashs"
MSG_GIT_STASH_APPLY="Appliquer un stash"
MSG_GIT_STASH_POP="Pop un stash (appliquer et supprimer)"
MSG_GIT_STASH_DROP="Supprimer un stash"
MSG_GIT_STASH_MESSAGE="Entrez un message pour le stash :"
MSG_GIT_STASH_SAVED="Modifications stashées."
MSG_GIT_NO_STASHES="Aucun stash trouvé."
MSG_GIT_RESET_HARD="Git Reset --hard (annuler toutes les modifications locales)"
MSG_GIT_REVERT_COMMIT="Git Revert (annuler un commit spécifique)"
MSG_GIT_CLEAN_FORCE="Git Clean -df (supprimer les fichiers/répertoires non suivis)"

# Gestion Drush
MSG_DRUSH_MENU_TITLE="Gestion Drush"
MSG_DRUSH_SELECT_TARGET="Sélectionnez la cible Drush (alias de site ou URI) :"
MSG_DRUSH_CURRENT_TARGET="Cible Drush actuelle : %s"
MSG_DRUSH_GENERAL_MENU="Commandes Drush Générales"
MSG_DRUSH_CONFIG_MENU="Gestion de la Configuration"
MSG_DRUSH_DB_MENU="Gestion de la Base de Données"
MSG_DRUSH_MODULES_THEMES_MENU="Modules et Thèmes"
MSG_DRUSH_USERS_MENU="Gestion des Utilisateurs"
MSG_DRUSH_WATCHDOG_MENU="Logs Watchdog"
MSG_DRUSH_SOLR_MENU="Search API Solr"
MSG_DRUSH_WEBFORM_MENU="Gestion des Webforms"
MSG_DRUSH_DEV_TOOLS_MENU="Outils de Développement"
MSG_DRUSH_STATUS="Statut Drush"
MSG_DRUSH_CR="Reconstruction du Cache Drush (drush cr)"
MSG_DRUSH_CIM="Importation de Configuration Drush (drush cim)"
MSG_DRUSH_CEX="Exportation de Configuration Drush (drush cex)"
MSG_DRUSH_PM_LIST="Lister les Modules/Thèmes"
MSG_DRUSH_PM_ENABLE="Activer un Module/Thème"
MSG_DRUSH_PM_DISABLE="Désactiver un Module/Thème"
MSG_DRUSH_PM_UNINSTALL="Désinstaller un Module/Thème"
MSG_DRUSH_USER_LOGIN="Se connecter en tant qu'utilisateur (Uli)"
MSG_DRUSH_USER_BLOCK="Bloquer un Utilisateur"
MSG_DRUSH_USER_UNBLOCK="Débloquer un Utilisateur"
MSG_DRUSH_USER_PASSWORD="Changer le Mot de Passe Utilisateur"
MSG_DRUSH_WATCHDOG_SHOW="Afficher Watchdog (récent)"
MSG_DRUSH_WATCHDOG_LIST="Lister les Types Watchdog"
MSG_DRUSH_WATCHDOG_DELETE="Supprimer les Logs Watchdog"
MSG_DRUSH_WATCHDOG_TAIL="Suivre les Logs Watchdog"
MSG_DRUSH_EV="Exécuter du code PHP (drush ev)"
MSG_DRUSH_PHP="Shell PHP interactif (drush php)"
MSG_DRUSH_CRON="Exécuter le Cron Drupal (drush cron)"
MSG_DRUSH_WEBFORM_LIST="Lister les Webforms"
MSG_DRUSH_WEBFORM_EXPORT="Exporter les Soumissions de Webform"
MSG_DRUSH_WEBFORM_PURGE="Purger les Soumissions de Webform"
MSG_DRUSH_ENTER_MODULE_THEME_NAME="Entrez le nom du module/thème :"
MSG_DRUSH_ENTER_USERNAME="Entrez le nom d'utilisateur :"
MSG_DRUSH_ENTER_NEW_PASSWORD="Entrez le nouveau mot de passe pour '%s' :"
MSG_DRUSH_ENTER_WATCHDOG_TYPE="Entrez le type watchdog à supprimer (ex: access denied) :"
MSG_DRUSH_ENTER_PHP_CODE="Entrez le code PHP à exécuter :"
MSG_DRUSH_TARGET_NONE_SELECTED="Aucune cible Drush sélectionnée. Veuillez en sélectionner une d'abord."

# Gestion de base de données
MSG_DB_MENU_TITLE="Gestion de la Base de Données"
MSG_DB_UPDATE="Mises à jour de la Base de Données Drush (drush updb)"
MSG_DB_DUMP="Dump SQL Drush (drush sql:dump)"
MSG_DB_CLI="CLI SQL Drush (drush sql:cli)"
MSG_DB_QUERY="Requête SQL Drush (drush sql:query)"
MSG_DB_SYNC="Synchronisation SQL Drush (drush sql:sync)"
MSG_DB_RESTORE="Restaurer la Base de Données à partir d'un Dump"
MSG_DB_ENTER_QUERY="Entrez la requête SQL :"
MSG_DB_SELECT_DUMP_FILE="Sélectionnez un fichier de dump de base de données à restaurer :"
MSG_DB_NO_DUMPS_FOUND="Aucun fichier de dump de base de données trouvé dans '%s'."
MSG_DB_DUMP_RESTORED="Base de données restaurée avec succès à partir de '%s'."
MSG_DB_DETECTED_FORMAT="Format détecté : %s"
MSG_DB_DECOMPRESSING="Décompression du fichier de dump..."
MSG_DB_PROMPT_SITE_MATCH="Plusieurs sites détectés. Veuillez spécifier à quel site ce dump '%s' appartient (ex: default, site1) :"
MSG_DB_MULTIPLE_DUMPS_MATCHING="Plusieurs fichiers de dump trouvés correspondant au format. Veuillez en sélectionner un."

# Gestion Solr
MSG_SOLR_MENU_TITLE="Gestion Search API Solr"
MSG_SOLR_SERVER_LIST="Lister les serveurs Solr"
MSG_SOLR_INDEX_LIST="Lister les index Solr"
MSG_SOLR_EXPORT_CONFIG="Exporter les Configurations Solr"
MSG_SOLR_INDEX_CONTENT="Indexer le Contenu"
MSG_SOLR_CLEAR_INDEX="Vider l'Index Solr"
MSG_SOLR_STATUS="Statut Solr"
MSG_SOLR_CONFIG_EXPORTED="Configurations Solr exportées vers : %s"

# Intégration IBM Cloud
MSG_IBMCLOUD_MENU_TITLE="Intégration IBM Cloud"
MSG_IBMCLOUD_LOGIN="Connexion IBM Cloud"
MSG_IBMCLOUD_LOGOUT="Déconnexion IBM Cloud"
MSG_IBMCLOUD_LIST_K8S_CLUSTERS="Lister les Clusters Kubernetes"
MSG_IBMCLOUD_CONFIGURE_KUBECTL="Configurer Kubectl pour un Cluster"
MSG_IBMCLOUD_ENTER_REGION="Entrez la Région IBM Cloud (ex: eu-de) :"
MSG_IBMCLOUD_ENTER_RESOURCE_GROUP="Entrez le Groupe de Ressources IBM Cloud (laissez vide pour le défaut) :"
MSG_IBMCLOUD_LOGIN_SUCCESS="Connecté à IBM Cloud avec succès."
MSG_IBMCLOUD_LOGOUT_SUCCESS="Déconnecté de IBM Cloud avec succès."
MSG_IBMCLOUD_K8S_CONTEXT_SET="Contexte Kubectl défini pour le cluster '%s'."

# Gestion Kubernetes
MSG_K8S_MENU_TITLE="Gestion Kubernetes"
MSG_K8S_CHECK_CONTEXT="Vérifier le Contexte Kubectl"
MSG_K8S_SELECT_POD="Sélectionner un Pod"
MSG_K8S_SELECT_CONTAINER="Sélectionner un Conteneur"
MSG_K8S_SOLR_MENU="Gestion des Pods Solr"
MSG_K8S_POSTGRES_MENU="Gestion des Pods PostgreSQL"
MSG_K8S_COPY_FILES="Copier des Fichiers vers un Pod (kubectl cp)"
MSG_K8S_POD_STATUS="Statut des Pods (Liste)"
MSG_K8S_POD_RESTART="Redémarrer un Pod"
MSG_K8S_POD_LOGS="Afficher les Logs du Pod/Conteneur"
MSG_K8S_PSQL_CLI="Accéder à la CLI PostgreSQL (psql)"
MSG_K8S_CONTEXT_NOT_SET="Contexte Kubectl non défini. Veuillez configurer IBM Cloud ou votre kubectl."
MSG_K8S_ENTER_POD_LABEL_FILTER="Entrez un filtre de label pour les pods (ex: app=drupal, laissez vide pour tous) :"
MSG_K8S_SELECT_POD_TO_MANAGE="Sélectionnez un pod à gérer :"
MSG_K8S_SELECT_CONTAINER_TO_MANAGE="Sélectionnez un conteneur à gérer :"
MSG_K8S_ENTER_LOCAL_PATH="Entrez le chemin local à copier :"
MSG_K8S_ENTER_REMOTE_PATH="Entrez le chemin distant dans le conteneur :"
MSG_K8S_COPY_SUCCESS="Fichier(s) copié(s) avec succès vers le pod '%s' conteneur '%s'."
MSG_K8S_COPY_FAILED="Échec de la copie des fichier(s)."
MSG_K8S_NO_PODS_FOUND="Aucun pod trouvé."
MSG_K8S_NO_CONTAINERS_FOUND="Aucun conteneur trouvé pour le pod sélectionné."

# Logs et Rapports
MSG_LOG_DEBUG_LEVEL="DEBUG"
MSG_LOG_INFO_LEVEL="INFO"
MSG_LOG_WARN_LEVEL="WARN"
MSG_LOG_ERROR_LEVEL="ERREUR"
MSG_LOG_SUCCESS_LEVEL="SUCCÈS"
MSG_ERROR_OCCURRED="Une erreur est survenue à la ligne %d pendant la commande : '%s'"
MSG_GENERATE_ERROR_REPORT="Voulez-vous générer un rapport d'erreurs détaillé ? (o/N)"
MSG_ERROR_REPORT_GENERATED="Rapport d'erreurs généré à : %s"
MSG_ERROR_REPORT_FAILED="Échec de la génération du rapport d'erreurs."

# Historique et Favoris
MSG_HISTORY_MENU_TITLE="Historique des Commandes"
MSG_HISTORY_VIEW="Afficher l'Historique"
MSG_HISTORY_RUN_AGAIN="Exécuter une commande de l'historique"
MSG_HISTORY_CLEAN="Nettoyer l'Historique"
MSG_HISTORY_DISABLED="L'historique des commandes est désactivé dans config.sh."
MSG_HISTORY_NO_ENTRIES="Aucune entrée d'historique trouvée."
MSG_FAVORITES_MENU_TITLE="Favoris Personnalisés"
MSG_FAVORITES_VIEW="Afficher les Favoris"
MSG_FAVORITES_RUN="Exécuter un Favori"
MSG_FAVORITES_EDIT="Modifier le Fichier des Favoris"
MSG_FAVORITES_DISABLED="La fonctionnalité des favoris est désactivée dans config.sh."
MSG_FAVORITES_NO_ENTRIES="Aucun favori trouvé."

# Autres utilitaires
MSG_ENTER_VALUE="Entrez une valeur :"
MSG_SEARCH="Rechercher"
MSG_FILTER="Filtrer"
MSG_CANCEL="Annuler"
MSG_SELECT_AN_ITEM="Sélectionnez un élément :"
MSG_NO_ITEM_SELECTED="Aucun élément sélectionné."

EOF

# helpers/log.sh
cat << 'EOF' > "${HELPERS_DIR}/log.sh"
#!/bin/bash

# File: helpers/log.sh
# Description: Logging functions for AUB Tools.

# Function to log messages with different verbosity levels
# Usage: log_debug "message"
#        log_info "message"
#        log_warn "message"
#        log_error "message"
#        log_success "message"
# log_message LEVEL COLOR_CODE MESSAGE
log_message() {
    local level_num=$1
    local color_code=$2
    local message="$3"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local level_name=""

    case $level_num in
        $LOG_LEVEL_DEBUG) level_name="${MSG_LOG_DEBUG_LEVEL}";;
        $LOG_LEVEL_INFO) level_name="${MSG_LOG_INFO_LEVEL}";;
        $LOG_LEVEL_WARN) level_name="${MSG_LOG_WARN_LEVEL}";;
        $LOG_LEVEL_ERROR) level_name="${MSG_LOG_ERROR_LEVEL}";;
        $LOG_LEVEL_SUCCESS) level_name="${MSG_LOG_SUCCESS_LEVEL}";;
        *) level_name="UNKNOWN";;
    esac

    # Log to file if level is appropriate
    if [[ "$level_num" -ge "$CURRENT_LOG_LEVEL_FILE" ]]; then
        echo "[$timestamp] [$level_name] $message" >> "${AUB_TOOLS_LOG_FILE}"
    fi

    # Print to console if level is appropriate
    if [[ "$level_num" -ge "$CURRENT_LOG_LEVEL_DISPLAY" ]]; then
        echo -e "${color_code}[$level_name]\033[0m $message"
    fi
}

log_debug() { log_message "$LOG_LEVEL_DEBUG" "\033[0;35m" "$1"; } # Magenta
log_info() { log_message "$LOG_LEVEL_INFO" "\033[0;34m" "$1"; }  # Blue
log_warn() { log_message "$LOG_LEVEL_WARN" "\033[0;33m" "$1"; }  # Yellow
log_error() { log_message "$LOG_LEVEL_ERROR" "\033[0;31m" "$1"; } # Red
log_success() { log_message "$LOG_LEVEL_SUCCESS" "\033[0;32m" "$1"; } # Green

EOF

# helpers/menu.sh
cat << 'EOF' > "${HELPERS_DIR}/menu.sh"
#!/bin/bash

# File: helpers/menu.sh
# Description: Functions for creating interactive menus in AUB Tools.

# Generic interactive menu function
# Usage: select_option "Title" "Option1" "Option2" ...
# Returns the selected option text in $REPLY
select_option() {
    local title="$1"
    shift
    local options=("$@")
    local selected_option=0
    local total_options=${#options[@]}

    while true; do
        clear
        echo "----------------------------------------------------"
        echo "                 $title"
        echo "----------------------------------------------------"
        echo ""

        for i in "${!options[@]}"; do
            if [[ $i -eq $selected_option ]]; then
                echo -e "> \033[1;32m${options[$i]}\033[0m" # Green and bold for selected
            else
                echo "  ${options[$i]}"
            fi
        done
        echo ""
        echo "$(_ "MSG_SELECT_OPTION")"

        read -s -n 3 key # Read up to 3 characters to capture arrow key sequences

        case "$key" in
            $'\x1b[A') # Up arrow
                ((selected_option--))
                if [[ $selected_option -lt 0 ]]; then
                    selected_option=$((total_options - 1))
                fi
                ;;
            $'\x1b[B') # Down arrow
                ((selected_option++))
                if [[ $selected_option -ge $total_options ]]; then
                    selected_option=0
                fi
                ;;
            $'\t') # Tab key - simulate down arrow
                ((selected_option++))
                if [[ $selected_option -ge $total_options ]]; then
                    selected_option=0
                fi
                ;;
            '') # Enter key
                REPLY="${options[$selected_option]}"
                log_debug "Selected menu option: ${REPLY}"
                return 0 # Success
                ;;
            $'\x1b') # ESC key
                REPLY="" # Indicate cancellation
                log_debug "Menu operation cancelled by user (ESC key)."
                return 1 # Cancelled
                ;;
        esac
    done
}

# Function to prompt for confirmation
# Usage: confirm_action "Are you sure?"
# Returns 0 for yes, 1 for no/cancel
confirm_action() {
    local prompt="${1:-$(_ "MSG_CONFIRM_ACTION")}" # Use default if no prompt provided
    log_debug "Confirming action: ${prompt}"
    read -p "$prompt " -n 1 -r
    echo # New line
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        log_debug "Action confirmed."
        return 0
    else
        log_debug "Action cancelled by user."
        return 1
    fi
}
EOF

# helpers/utils.sh
cat << 'EOF' > "${HELPERS_DIR}/utils.sh"
#!/bin/bash

# File: helpers/utils.sh
# Description: General utility functions for AUB Tools.

# Function to find the Drupal root directory within a project
# Assumes the script is run from the project root or its child directory.
# This function should be called from within a specific project directory.
detect_drupal_root() {
    local current_dir="$(pwd)"
    local project_root="$1" # The root of the cloned project

    # Check common Drupal root directories
    if [[ -d "${project_root}/web" && -f "${project_root}/web/index.php" ]]; then
        DRUPAL_ROOT="${project_root}/web"
        return 0
    elif [[ -d "${project_root}/src/web" && -f "${project_root}/src/web/index.php" ]]; then
        DRUPAL_ROOT="${project_root}/src/web"
        return 0
    elif [[ -d "${current_dir}/web" && -f "${current_dir}/web/index.php" ]]; then
        DRUPAL_ROOT="${current_dir}/web"
        return 0
    elif [[ -d "${current_dir}/src/web" && -f "${current_dir}/src/web/index.php" ]]; then
        DRUPAL_ROOT="${current_dir}/src/web"
        return 0
    elif [[ -f "${current_dir}/index.php" && -d "${current_dir}/core" ]]; then
        DRUPAL_ROOT="${current_dir}" # Current directory is Drupal root
        return 0
    fi

    DRUPAL_ROOT="" # No Drupal root found
    log_warn "$(_ "MSG_PROJECT_DRUPAL_ROOT_NOT_FOUND")"
    return 1
}

# Function to execute a command within the Drupal root
# Usage: run_drush_command "command" "args"
# Ensures DRUPAL_ROOT is set and cd into it before executing
execute_in_drupal_root() {
    local cmd="$1"
    shift
    local args="$@"

    if [[ -z "$DRUPAL_ROOT" || ! -d "$DRUPAL_ROOT" ]]; then
        log_error "$(_ "MSG_PROJECT_DRUPAL_ROOT_NOT_FOUND")"
        return 1
    fi

    log_info "Executing '$cmd $args' in Drupal root: ${DRUPAL_ROOT}"
    (cd "$DRUPAL_ROOT" && eval "$cmd $args")
    local status=$?
    if [[ $status -ne 0 ]]; then
        log_error "Command '$cmd $args' failed with exit code $status."
        return 1
    else
        log_success "Command '$cmd $args' completed successfully."
        return 0
    fi
}

# Function to get user input
# Usage: get_user_input "Prompt" [default_value]
# Returns the input in REPLY
get_user_input() {
    local prompt="$1"
    local default_value="$2"
    log_debug "Prompting user for input: '$prompt' (default: '$default_value')"
    if [[ -n "$default_value" ]]; then
        read -r -p "$(printf "$prompt" "$default_value") " REPLY
        REPLY="${REPLY:-$default_value}" # Use default if user input is empty
    else
        read -r -p "$prompt " REPLY
    fi
    log_debug "User input: '$REPLY'"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to display a formatted message and wait for user to press enter
press_enter_to_continue() {
    echo ""
    read -r -p "$(_ "MSG_PRESS_ENTER_TO_CONTINUE")"
}
EOF

# helpers/history.sh
cat << 'EOF' > "${HELPERS_DIR}/history.sh"
#!/bin/bash

# File: helpers/history.sh
# Description: Functions for managing command history in AUB Tools.

# Global variable to store current project path for history context
CURRENT_PROJECT_PATH=""

# Function to initialize history
initialize_history_and_favorites() {
    # Check if history file exists, create if not
    if [[ "$ENABLE_HISTORY" == "true" && ! -f "$AUB_TOOLS_HISTORY_FILE" ]]; then
        touch "$AUB_TOOLS_HISTORY_FILE"
        log_debug "History file created: ${AUB_TOOLS_HISTORY_FILE}"
    fi

    # Source favorites file
    if [[ "$ENABLE_FAVORITES" == "true" && -f "$AUB_TOOLS_FAVORITES_FILE" ]]; then
        source "$AUB_TOOLS_FAVORITES_FILE"
        log_debug "Favorites file sourced: ${AUB_TOOLS_FAVORITES_FILE}"
    fi
}

# Function to record a significant action in history
# Usage: record_history "command_description" "command_to_execute"
record_history() {
    if [[ "$ENABLE_HISTORY" != "true" ]]; then
        log_debug "History recording is disabled."
        return
    fi
    local description="$1"
    local command="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [${CURRENT_PROJECT_PATH:-"GLOBAL"}] \"$description\" \"$command\"" >> "${AUB_TOOLS_HISTORY_FILE}"
    log_debug "History recorded: [$timestamp] $description"
}

# Function to view history and optionally re-run a command
view_history_menu() {
    if [[ "$ENABLE_HISTORY" != "true" ]]; then
        log_warn "$(_ "MSG_HISTORY_DISABLED")"
        press_enter_to_continue
        return
    fi

    local history_entries=()
    if [[ -f "$AUB_TOOLS_HISTORY_FILE" ]]; then
        # Read history, parse into displayable format and executable command
        while IFS= read -r line; do
            # Extract timestamp, project, description, and command using regex
            if [[ "$line" =~ ^\[([^]]+)\]\ \[(.*)\]\ \"([^\"]*)\"\ \"(.*)\"$ ]]; then
                local timestamp="${BASH_REMATCH[1]}"
                local project="${BASH_REMATCH[2]}"
                local description="${BASH_REMATCH[3]}"
                local command="${BASH_REMATCH[4]}"
                history_entries+=("${timestamp} | ${project} | ${description}::${command}")
            fi
        done < "$AUB_TOOLS_HISTORY_FILE"
    fi

    if [[ ${#history_entries[@]} -eq 0 ]]; then
        log_info "$(_ "MSG_HISTORY_NO_ENTRIES")"
        press_enter_to_continue
        return
    fi

    history_entries+=("$(_ "MSG_BACK_TO_MAIN_MENU")")

    select_option "$(_ "MSG_HISTORY_MENU_TITLE")" "${history_entries[@]}"
    local selected_entry="$REPLY"

    if [[ "$selected_entry" == "$(_ "MSG_BACK_TO_MAIN_MENU")" || -z "$selected_entry" ]]; then
        return # Go back or cancelled
    fi

    # Extract command from selected entry
    local command_to_run=$(echo "$selected_entry" | sed -n 's/.*::\(.*\)/\1/p')

    if [[ -n "$command_to_run" ]]; then
        log_info "$(_ "MSG_HISTORY_RUN_AGAIN"): ${command_to_run}"
        # Execute the command in the appropriate project path if available
        local project_path=$(echo "$selected_entry" | sed -n 's/.*| \(.*\) |.*::.*/\1/p')
        if [[ "$project_path" != "GLOBAL" && -n "$project_path" && -d "$project_path" ]]; then
            log_info "Changing to project directory: ${project_path}"
            (cd "$project_path" && eval "$command_to_run")
        else
            eval "$command_to_run"
        fi
        press_enter_to_continue
    fi
}

# Function to clean history
clean_history() {
    if [[ "$ENABLE_HISTORY" != "true" ]]; then
        log_warn "$(_ "MSG_HISTORY_DISABLED")"
        press_enter_to_continue
        return
    fi

    if confirm_action "$(_ "MSG_CONFIRM_ACTION")"; then
        > "$AUB_TOOLS_HISTORY_FILE" # Truncate the file
        log_success "History cleared."
    else
        log_info "$(_ "MSG_OPERATION_CANCELLED")"
    fi
    press_enter_to_continue
}
EOF

# helpers/favorites.sh
cat << 'EOF' > "${HELPERS_DIR}/favorites.sh"
#!/bin/bash

# File: helpers/favorites.sh
# Description: Functions for managing custom favorite commands/functions.

# Function to view and run favorites
view_favorites_menu() {
    if [[ "$ENABLE_FAVORITES" != "true" ]]; then
        log_warn "$(_ "MSG_FAVORITES_DISABLED")"
        press_enter_to_continue
        return
    fi

    local favorite_functions=()
    # Parse the favorites file to find defined functions
    if [[ -f "$AUB_TOOLS_FAVORITES_FILE" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)\(\) ]]; then
                favorite_functions+=("${BASH_REMATCH[1]}")
            fi
        done < "$AUB_TOOLS_FAVORITES_FILE"
    fi

    if [[ ${#favorite_functions[@]} -eq 0 ]]; then
        log_info "$(_ "MSG_FAVORITES_NO_ENTRIES")"
        press_enter_to_continue
        return
    fi

    local menu_options=()
    for func_name in "${favorite_functions[@]}"; do
        menu_options+=("Run: $func_name")
    done
    menu_options+=("$(_ "MSG_FAVORITES_EDIT")")
    menu_options+=("$(_ "MSG_BACK_TO_MAIN_MENU")")

    select_option "$(_ "MSG_FAVORITES_MENU_TITLE")" "${menu_options[@]}"
    local selected_option="$REPLY"

    if [[ "$selected_option" == "$(_ "MSG_BACK_TO_MAIN_MENU")" || -z "$selected_option" ]]; then
        return # Go back or cancelled
    elif [[ "$selected_option" == "$(_ "MSG_FAVORITES_EDIT")" ]]; then
        edit_favorites_file
    elif [[ "$selected_option" =~ ^Run:\ ([a-zA-Z_][a-zA-Z0-9_]*)$ ]]; then
        local func_name="${BASH_REMATCH[1]}"
        log_info "Running favorite: ${func_name}"
        record_history "Run Favorite: ${func_name}" "${func_name}"
        eval "$func_name" # Execute the function
        press_enter_to_continue
    fi
}

# Function to open the favorites file for editing
edit_favorites_file() {
    log_info "Opening favorites file for editing: ${AUB_TOOLS_FAVORITES_FILE}"
    if command_exists "code"; then # VS Code
        code "${AUB_TOOLS_FAVORITES_FILE}"
    elif command_exists "atom"; then # Atom
        atom "${AUB_TOOLS_FAVORITES_FILE}"
    elif command_exists "subl"; then # Sublime Text
        subl "${AUB_TOOLS_FAVORITES_FILE}"
    else # Fallback to default editor
        "${EDITOR:-vi}" "${AUB_TOOLS_FAVORITES_FILE}"
    fi
    press_enter_to_continue
}
EOF

# helpers/report.sh
cat << 'EOF' > "${HELPERS_DIR}/report.sh"
#!/bin/bash

# File: helpers/report.sh
# Description: Functions for generating detailed error reports.

# Global variable to store last error details
LAST_ERROR_LINE=""
LAST_ERROR_COMMAND=""

# Function to handle errors and propose generating a report
handle_error_and_report() {
    local exit_code=$?
    LAST_ERROR_LINE="$1"
    LAST_ERROR_COMMAND="$2"
    log_error "$(printf "$(_ "MSG_ERROR_OCCURRED")" "$LAST_ERROR_LINE" "$LAST_ERROR_COMMAND")"

    if [[ "$ENABLE_ERROR_REPORTING" == "true" ]]; then
        if confirm_action "$(_ "MSG_GENERATE_ERROR_REPORT")"; then
            generate_error_report
        fi
    fi
}

# Function to generate a detailed error report
generate_error_report() {
    local report_file="${AUB_TOOLS_CONFIG_DIR}/aub-tools_error_report_$(date +"%Y%m%d_%H%M%S").log"
    log_info "Generating error report to: ${report_file}"

    echo "--- AUB Tools Error Report ---" > "${report_file}"
    echo "Date: $(date)" >> "${report_file}"
    echo "AUB Tools Version: DevxTools 1.0" >> "${report_file}"
    echo "--- System Information ---" >> "${report_file}"
    uname -a >> "${report_file}"
    echo "Shell: $BASH_VERSION" >> "${report_file}"
    echo "--- Last Error Details ---" >> "${report_file}"
    echo "Line: ${LAST_ERROR_LINE}" >> "${report_file}"
    echo "Command: ${LAST_ERROR_COMMAND}" >> "${report_file}"
    echo "Exit Code: $?" >> "${report_file}"
    echo "--- Environment Variables ---" >> "${report_file}"
    # Filter sensitive info, only include AUB_TOOLS related vars
    env | grep AUB_TOOLS >> "${report_file}" || echo "No AUB_TOOLS env vars." >> "${report_file}"
    echo "--- Tool Versions ---" >> "${report_file}"
    command -v git &> /dev/null && echo "Git: $(git --version)" >> "${report_file}" || echo "Git: Not found" >> "${report_file}"
    command -v composer &> /dev/null && echo "Composer: $(composer --version | head -n 1)" >> "${report_file}" || echo "Composer: Not found" >> "${report_file}"
    command -v drush &> /dev/null && echo "Drush: $(drush --version | head -n 1)" >> "${report_file}" || echo "Drush: Not found" >> "${report_file}"
    command -v kubectl &> /dev/null && echo "Kubectl: $(kubectl version --client --short | head -n 1)" >> "${report_file}" || echo "Kubectl: Not found" >> "${report_file}"
    command -v ibmcloud &> /dev/null && echo "IBM Cloud CLI: $(ibmcloud --version | head -n 1)" >> "${report_file}" || echo "IBM Cloud CLI: Not found" >> "${report_file}"
    command -v jq &> /dev/null && echo "jq: $(jq --version)" >> "${report_file}" || echo "jq: Not found" >> "${report_file}"
    echo "--- Recent AUB Tools Logs ---" >> "${report_file}"
    tail -n 50 "${AUB_TOOLS_LOG_FILE}" >> "${report_file}" 2>&1 || echo "Could not read recent logs." >> "${report_file}"
    echo "--- End of Report ---" >> "${report_file}"

    if [[ -f "${report_file}" ]]; then
        log_success "$(printf "$(_ "MSG_ERROR_REPORT_GENERATED")" "${report_file}")"
    else
        log_error "$(_ "MSG_ERROR_REPORT_FAILED")"
    fi
    press_enter_to_continue
}
EOF

# Core scripts (empty for now, will be populated later)
cat << 'EOF' > "${CORE_DIR}/main.sh"
#!/bin/bash

# File: core/main.sh
# Description: Main menu and navigation logic for AUB Tools.

main_menu() {
    local options=(
        "$(_ "MSG_PROJECT_MENU_TITLE")"
        "$(_ "MSG_GIT_MENU_TITLE")"
        "$(_ "MSG_DRUSH_MENU_TITLE")"
        "$(_ "MSG_DB_MENU_TITLE")"
        "$(_ "MSG_SOLR_MENU_TITLE")"
        "$(_ "MSG_IBMCLOUD_MENU_TITLE")"
        "$(_ "MSG_K8S_MENU_TITLE")"
        "$(_ "MSG_HISTORY_MENU_TITLE")"
        "$(_ "MSG_FAVORITES_MENU_TITLE")"
        "$(_ "MSG_EXIT_TOOL")"
    )

    while true; do
        display_header # From aub-tools script
        if [[ -n "$CURRENT_PROJECT_PATH" ]]; then
            log_info "Current project: $(basename "$CURRENT_PROJECT_PATH")"
        fi
        if [[ -n "$DRUSH_CURRENT_TARGET_ALIAS" || -n "$DRUSH_CURRENT_TARGET_URI" ]]; then
            log_info "$(printf "$(_ "MSG_DRUSH_CURRENT_TARGET")" "${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI}")"
        fi
        echo ""

        select_option "$(_ "MSG_WELCOME")" "${options[@]}"
        local choice="$REPLY"

        case "$choice" in
            "$(_ "MSG_PROJECT_MENU_TITLE")") project_menu ;;
            "$(_ "MSG_GIT_MENU_TITLE")") git_menu ;;
            "$(_ "MSG_DRUSH_MENU_TITLE")") drush_menu ;;
            "$(_ "MSG_DB_MENU_TITLE")") db_menu ;;
            "$(_ "MSG_SOLR_MENU_TITLE")") solr_menu ;;
            "$(_ "MSG_IBMCLOUD_MENU_TITLE")") ibmcloud_menu ;;
            "$(_ "MSG_K8S_MENU_TITLE")") k8s_menu ;;
            "$(_ "MSG_HISTORY_MENU_TITLE")") view_history_menu ;;
            "$(_ "MSG_FAVORITES_MENU_TITLE")") view_favorites_menu ;;
            "$(_ "MSG_EXIT_TOOL")") log_info "$(_ "MSG_WELCOME")"; exit 0 ;;
            *) log_error "$(_ "MSG_INVALID_SELECTION")"; press_enter_to_continue ;;
        esac
    done
}

EOF

cat << 'EOF' > "${CORE_DIR}/composer.sh"
#!/bin/bash

# File: core/composer.sh
# Description: Functions for managing PHP/Composer dependencies.

# Function to run composer install
composer_install() {
    log_info "$(_ "MSG_PROJECT_COMPOSER_INSTALL")"
    if execute_in_drupal_root "composer install"; then
        record_history "Composer Install" "cd ${DRUPAL_ROOT} && composer install"
    fi
}

# Function to run composer update
composer_update() {
    log_info "Running Composer update..."
    if execute_in_drupal_root "composer update"; then
        record_history "Composer Update" "cd ${DRUPAL_ROOT} && composer update"
    fi
}

# Add more Composer related functions as needed
# For example: composer_require, composer_remove, composer_validate
EOF

cat << 'EOF' > "${CORE_DIR}/database.sh"
#!/bin/bash

# File: core/database.sh
# Description: Functions for managing Drupal databases.

# Global variable to store current drush target alias/uri
DRUSH_CURRENT_TARGET_ALIAS=""
DRUSH_CURRENT_TARGET_URI=""

# Function to run drush updb
drush_updb() {
    if ! select_drush_target; then return; fi
    log_info "$(_ "MSG_DB_UPDATE")"
    execute_drush_command "updb -y"
    record_history "Drush DB Update" "drush ${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI} updb -y"
}

# Function to run drush sql-dump
drush_sql_dump() {
    if ! select_drush_target; then return; }
    log_info "$(_ "MSG_DB_DUMP")"
    execute_drush_command "sql-dump > dump.sql"
    record_history "Drush SQL Dump" "drush ${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI} sql-dump > dump.sql"
}

# Function to run drush sql-cli
drush_sql_cli() {
    if ! select_drush_target; then return; fi
    log_info "$(_ "MSG_DB_CLI")"
    execute_drush_command "sql-cli"
    record_history "Drush SQL CLI" "drush ${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI} sql-cli"
}

# Function to run drush sql-query
drush_sql_query() {
    if ! select_drush_target; then return; fi
    get_user_input "$(_ "MSG_DB_ENTER_QUERY")"
    local query="$REPLY"
    if [[ -z "$query" ]]; then
        log_warn "$(_ "MSG_OPERATION_CANCELLED")"
        return
    fi
    log_info "$(_ "MSG_DB_QUERY"): $query"
    execute_drush_command "sql-query \"$query\""
    record_history "Drush SQL Query: $query" "drush ${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI} sql-query \"$query\""
}

# Function to run drush sql-sync
drush_sql_sync() {
    if ! select_drush_target; then return; fi # Select destination first
    local destination_target="${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI}"

    log_info "Synchronizing database to ${destination_target}."
    log_info "Please select the source Drush target:"
    # Temporarily clear target to select source
    local temp_drush_target_alias="$DRUSH_CURRENT_TARGET_ALIAS"
    local temp_drush_target_uri="$DRUSH_CURRENT_TARGET_URI"
    DRUSH_CURRENT_TARGET_ALIAS=""
    DRUSH_CURRENT_TARGET_URI=""
    if ! select_drush_target; then
        DRUSH_CURRENT_TARGET_ALIAS="$temp_drush_target_alias"
        DRUSH_CURRENT_TARGET_URI="$temp_drush_target_uri"
        return
    fi
    local source_target="${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI}"

    if confirm_action "Are you sure you want to sync DB from '${source_target}' to '${destination_target}'? This will overwrite the destination DB. (y/N)"; then
        log_info "Executing drush sql-sync ${source_target} ${destination_target}"
        if execute_drush_command "sql-sync ${source_target} ${destination_target} -y" "--skip-find"; then # --skip-find to avoid re-prompting for target
            record_history "Drush SQL Sync ${source_target} to ${destination_target}" "drush sql-sync ${source_target} ${destination_target} -y"
        fi
    else
        log_info "$(_ "MSG_OPERATION_CANCELLED")"
    fi

    # Restore original target
    DRUSH_CURRENT_TARGET_ALIAS="$temp_drush_target_alias"
    DRUSH_CURRENT_TARGET_URI="$temp_drush_target_uri"
}

# Function to restore database from a dump file
# Intelligently handles various dump formats and site matching
drush_db_restore() {
    if ! select_drush_target; then return; fi

    local current_project_root
    if [[ -n "$CURRENT_PROJECT_PATH" ]]; then
        current_project_root="$CURRENT_PROJECT_PATH"
    elif [[ -n "$DRUPAL_ROOT" ]]; then
        current_project_root=$(dirname "$DRUPAL_ROOT")
    else
        log_error "Cannot determine project root. Please initialize a project first."
        return 1
    fi

    local dump_dir="${current_project_root}${DRUPAL_DUMP_DIR}"
    mkdir -p "$dump_dir" # Ensure dump directory exists
    log_info "Looking for database dumps in: ${dump_dir}"

    local dump_files=()
    # Find all potential dump files
    while IFS= read -r -d $'\0' file; do
        dump_files+=("$(basename "$file")")
    done < <(find "$dump_dir" -maxdepth 1 -type f \( -name "*.sql" -o -name "*.sql.gz" -o -name "*.zip" -o -name "*.tar" -o -name "*.dump" -o -name "*.dmp" \) -print0 | sort -z)

    if [[ ${#dump_files[@]} -eq 0 ]]; then
        log_warn "$(printf "$(_ "MSG_DB_NO_DUMPS_FOUND")" "${dump_dir}")"
        press_enter_to_continue
        return
    fi

    dump_files+=("$(_ "MSG_CANCEL")")

    select_option "$(_ "MSG_DB_SELECT_DUMP_FILE")" "${dump_files[@]}"
    local selected_dump="$REPLY"

    if [[ -z "$selected_dump" || "$selected_dump" == "$(_ "MSG_CANCEL")" ]]; then
        log_info "$(_ "MSG_OPERATION_CANCELLED")"
        return
    fi

    local full_dump_path="${dump_dir}/${selected_dump}"
    local extracted_dump_path=""
    local dump_format=""

    # Detect format and decompress if necessary
    if [[ "$selected_dump" =~ \.sql$ ]]; then
        dump_format="sql"
        extracted_dump_path="$full_dump_path"
    elif [[ "$selected_dump" =~ \.sql\.gz$ ]]; then
        dump_format="sql.gz"
        log_info "$(_ "MSG_DB_DECOMPRESSING")"
        gunzip -c "$full_dump_path" > "${full_dump_path%.gz}" || { log_error "Failed to decompress gz."; return 1; }
        extracted_dump_path="${full_dump_path%.gz}"
    elif [[ "$selected_dump" =~ \.zip$ ]]; then
        dump_format="zip"
        log_info "$(_ "MSG_DB_DECOMPRESSING")"
        local temp_dir=$(mktemp -d)
        unzip -qq "$full_dump_path" -d "$temp_dir" || { log_error "Failed to decompress zip."; rm -rf "$temp_dir"; return 1; }
        # Find the .sql file inside the unzipped directory (assume one .sql file)
        extracted_dump_path=$(find "$temp_dir" -name "*.sql" -print -quit)
        if [[ -z "$extracted_dump_path" ]]; then
            log_error "No .sql file found inside the zip archive."
            rm -rf "$temp_dir"
            return 1
        fi
        # If multiple .sql files, user needs to pick one (advanced, not implemented for simplicity here)
        log_debug "Extracted SQL file: ${extracted_dump_path}"
    elif [[ "$selected_dump" =~ \.tar$ ]]; then
        dump_format="tar"
        log_info "$(_ "MSG_DB_DECOMPRESSING")"
        local temp_dir=$(mktemp -d)
        tar -xf "$full_dump_path" -C "$temp_dir" || { log_error "Failed to decompress tar."; rm -rf "$temp_dir"; return 1; }
        extracted_dump_path=$(find "$temp_dir" -name "*.sql" -print -quit)
        if [[ -z "$extracted_dump_path" ]]; then
            log_error "No .sql file found inside the tar archive."
            rm -rf "$temp_dir"
            return 1
        fi
        log_debug "Extracted SQL file: ${extracted_dump_path}"
    elif [[ "$selected_dump" =~ \.dump$ || "$selected_dump" =~ \.dmp$ ]]; then # PostgreSQL custom dump format
        dump_format="pg_dump"
        extracted_dump_path="$full_dump_path"
        log_warn "Assuming this is a PostgreSQL dump. Restoration method may vary. Attempting with drush sqlc < dump.sql"
    else
        log_error "Unsupported dump format: $selected_dump"
        return 1
    fi

    log_info "$(printf "$(_ "MSG_DB_DETECTED_FORMAT")" "$dump_format")"

    # Handle multi-site scenario for restoration
    local site_uri_to_restore="${DRUSH_CURRENT_TARGET_URI:-default}" # Default to 'default' if URI not set
    local drush_alias_option=""

    if [[ -n "$DRUSH_CURRENT_TARGET_ALIAS" ]]; then
        drush_alias_option="${DRUSH_CURRENT_TARGET_ALIAS}"
    elif [[ -n "$DRUSH_CURRENT_TARGET_URI" ]]; then
        drush_alias_option="--uri=${DRUSH_CURRENT_TARGET_URI}"
    else
        # If no target selected, try to detect available sites
        local available_sites=$(execute_drush_command "site:alias --format=json" | "${AUB_TOOLS_DIR}/bin/jq" -r 'keys[]' | grep -v '^@')
        local num_sites=$(echo "$available_sites" | wc -l)

        if [[ "$num_sites" -gt 1 ]]; then
            log_warn "$(printf "$(_ "MSG_DB_PROMPT_SITE_MATCH")" "$selected_dump")"
            local site_options=($available_sites "$(_ "MSG_CANCEL")")
            select_option "$(_ "MSG_SELECT_AN_ITEM")" "${site_options[@]}"
            local chosen_site="$REPLY"
            if [[ -z "$chosen_site" || "$chosen_site" == "$(_ "MSG_CANCEL")" ]]; then
                log_info "$(_ "MSG_OPERATION_CANCELLED")"
                # Clean up temporary extracted file if any
                if [[ -n "$temp_dir" ]]; then rm -rf "$temp_dir"; fi
                if [[ "$dump_format" == "sql.gz" && -f "${full_dump_path%.gz}" ]]; then rm "${full_dump_path%.gz}"; fi
                return
            fi
            site_uri_to_restore="$chosen_site"
            drush_alias_option="--uri=$site_uri_to_restore"
            log_info "Restoring to site: ${site_uri_to_restore}"
        else
            log_info "Restoring to default site."
        fi
    fi

    if confirm_action "Restore database from '${selected_dump}' to '${DRUSH_CURRENT_TARGET_ALIAS:-$site_uri_to_restore}'? THIS WILL OVERWRITE THE CURRENT DATABASE. (y/N)"; then
        log_info "Restoring database..."
        if [[ "$dump_format" == "pg_dump" ]]; then
             # For PostgreSQL custom dumps, use psql directly via drush sql-cli
             execute_drush_command "sql-cli < \"$extracted_dump_path\"" "${drush_alias_option}"
        else
            # For SQL dumps, use drush sql:cli or similar
            # Drush sql:cli usually accepts piping or file path.
            # A common way for large dumps is: `drush sql-cli < dump.sql`
            # Ensure the command is executed in Drupal root for Drush context
            if execute_drush_command "sql-drop -y" "${drush_alias_option}"; then
                log_info "Dropped existing database for current target. Importing new dump..."
                # Use a specific exec to avoid issues with `eval` and pipes
                (cd "$DRUPAL_ROOT" && drush ${drush_alias_option} sql-cli < "$extracted_dump_path")
            else
                log_error "Failed to drop existing database. Aborting restore."
            fi
        fi

        if [[ $? -eq 0 ]]; then
            log_success "$(printf "$(_ "MSG_DB_DUMP_RESTORED")" "$selected_dump")"
            record_history "Drush DB Restore: $selected_dump" "drush ${drush_alias_option} sql-cli < \"$extracted_dump_path\""
            # After restore, it's often good practice to run drush updb and drush cr
            drush_updb
            drush_cr
        else
            log_error "Database restoration failed."
        fi
    else
        log_info "$(_ "MSG_OPERATION_CANCELLED")"
    fi

    # Clean up temporary extracted file if any
    if [[ -n "$temp_dir" ]]; then rm -rf "$temp_dir"; fi
    if [[ "$dump_format" == "sql.gz" && -f "${full_dump_path%.gz}" ]]; then rm "${full_dump_path%.gz}"; fi
    press_enter_to_continue
}

# Database management menu
db_menu() {
    local options=(
        "$(_ "MSG_DB_UPDATE")"
        "$(_ "MSG_DB_DUMP")"
        "$(_ "MSG_DB_CLI")"
        "$(_ "MSG_DB_QUERY")"
        "$(_ "MSG_DB_SYNC")"
        "$(_ "MSG_DB_RESTORE")"
        "$(_ "MSG_BACK_TO_MAIN_MENU")"
    )

    while true; do
        display_header
        if [[ -n "$DRUSH_CURRENT_TARGET_ALIAS" || -n "$DRUSH_CURRENT_TARGET_URI" ]]; then
            log_info "$(printf "$(_ "MSG_DRUSH_CURRENT_TARGET")" "${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI}")"
        else
            log_warn "$(_ "MSG_DRUSH_TARGET_NONE_SELECTED")"
        fi
        select_option "$(_ "MSG_DB_MENU_TITLE")" "${options[@]}"
        local choice="$REPLY"

        case "$choice" in
            "$(_ "MSG_DB_UPDATE")") drush_updb ;;
            "$(_ "MSG_DB_DUMP")") drush_sql_dump ;;
            "$(_ "MSG_DB_CLI")") drush_sql_cli ;;
            "$(_ "MSG_DB_QUERY")") drush_sql_query ;;
            "$(_ "MSG_DB_SYNC")") drush_sql_sync ;;
            "$(_ "MSG_DB_RESTORE")") drush_db_restore ;;
            "$(_ "MSG_BACK_TO_MAIN_MENU")") break ;;
            *) log_error "$(_ "MSG_INVALID_SELECTION")"; press_enter_to_continue ;;
        esac
    done
}
EOF

cat << 'EOF' > "${CORE_DIR}/drush.sh"
#!/bin/bash

# File: core/drush.sh
# Description: Drush specific functions for AUB Tools.

# Global variable for the selected Drush target (alias or URI)
DRUSH_CURRENT_TARGET_ALIAS=""
DRUSH_CURRENT_TARGET_URI=""

# Function to select Drush target (alias or URI)
# Sets DRUSH_CURRENT_TARGET_ALIAS or DRUSH_CURRENT_TARGET_URI
# Returns 0 on success, 1 on cancel or no target found
select_drush_target() {
    if [[ -z "$DRUPAL_ROOT" ]]; then
        log_error "$(_ "MSG_PROJECT_DRUPAL_ROOT_NOT_FOUND")"
        press_enter_to_continue
        return 1
    fi

    # Check for drush
    if ! command_exists "drush"; then
        log_error "Drush command not found. Please ensure Drush is installed and in your PATH."
        press_enter_to_continue
        return 1
    fi

    log_info "$(_ "MSG_DRUSH_SELECT_TARGET")"

    local drush_aliases=()
    local drush_uris=()
    local all_targets=()

    # Get aliases
    log_debug "Detecting Drush aliases..."
    if ! local aliases_json=$(execute_in_drupal_root "drush site:alias --format=json" 2>/dev/null); then
        log_warn "Could not retrieve Drush aliases. Is Drush configured correctly in the project?"
        aliases_json="{}" # Empty JSON
    fi

    # Use jq to parse aliases, excluding the top-level "@" if it exists
    # And also filter out any non-alias like "@self" if it's not a real site alias
    # Iterate through keys of the JSON object
    for alias_name in $(echo "$aliases_json" | "${AUB_TOOLS_DIR}/bin/jq" -r 'keys_without_null_values | .[]' 2>/dev/null | grep -v '^@self$' | grep -v '^@'); do
        # Add @ prefix if it's missing (jq might return without it)
        if [[ ! "$alias_name" =~ ^@ ]]; then
            alias_name="@${alias_name}"
        fi
        drush_aliases+=("$alias_name")
        all_targets+=("$alias_name")
    done

    # Get URIs (multi-site) - drush status --format=json provides 'site_name' which is the URI
    log_debug "Detecting Drush URIs (multi-site)..."
    if local status_json=$(execute_in_drupal_root "drush status --format=json" 2>/dev/null); then
        local current_uri=$(echo "$status_json" | "${AUB_TOOLS_DIR}/bin/jq" -r '.uri' 2>/dev/null)
        if [[ -n "$current_uri" && "$current_uri" != "null" ]]; then
            drush_uris+=("$current_uri")
        fi
    fi

    # Also try to get sites from `sites.php` if it exists in the Drupal root's sites directory
    local sites_dir="${DRUPAL_ROOT}/sites"
    if [[ -d "$sites_dir" ]]; then
        for dir in "$sites_dir"/*; do
            if [[ -d "$dir" && "$(basename "$dir")" != "default" && "$(basename "$dir")" != "all" ]]; then
                # Assume dir name is the URI, or could be mapped in sites.php
                # For simplicity, we just add the directory name as a potential URI
                # A more robust solution might parse sites.php for hostnames
                if [[ ! " ${drush_uris[*]} " =~ " $(basename "$dir") " ]]; then
                    drush_uris+=("$(basename "$dir")")
                fi
            fi
        done
    fi

    # Add unique URIs to all_targets
    for uri in "${drush_uris[@]}"; do
        if [[ ! " ${all_targets[*]} " =~ " ${uri} " ]]; then
            all_targets+=("${uri}")
        fi
    done

    # Add special option for "ALL sites" (Drush specific)
    all_targets+=("@sites") # Drush's way to target all sites

    # Add current project's default site if not already included
    if [[ ! " ${all_targets[*]} " =~ " default " ]]; then
        all_targets+=("default")
    fi

    # Add current directory if it corresponds to the Drupal root and not already listed as 'default'
    if [[ "$DRUPAL_ROOT" == "$(pwd)" ]]; then
         if [[ ! " ${all_targets[*]} " =~ " current " ]]; then
            all_targets+=("current") # Can refer to current context
        fi
    fi


    if [[ ${#all_targets[@]} -eq 0 ]]; then
        log_error "No Drush aliases or multi-site URIs found for this project."
        press_enter_to_continue
        return 1
    fi

    all_targets+=("$(_ "MSG_CANCEL")")

    select_option "$(_ "MSG_DRUSH_SELECT_TARGET")" "${all_targets[@]}"
    local selected_target="$REPLY"

    if [[ -z "$selected_target" || "$selected_target" == "$(_ "MSG_CANCEL")" ]]; then
        log_info "$(_ "MSG_OPERATION_CANCELLED")"
        return 1
    fi

    if [[ "$selected_target" =~ ^@ ]]; then
        DRUSH_CURRENT_TARGET_ALIAS="$selected_target"
        DRUSH_CURRENT_TARGET_URI=""
        log_info "Selected Drush alias: ${DRUSH_CURRENT_TARGET_ALIAS}"
    else
        DRUSH_CURRENT_TARGET_URI="$selected_target"
        DRUSH_CURRENT_TARGET_ALIAS=""
        log_info "Selected Drush URI: ${DRUSH_CURRENT_TARGET_URI}"
    fi

    return 0 # Target successfully selected
}

# Function to execute a Drush command with the selected target
# Usage: execute_drush_command "drush_command_and_args" [additional_drush_options]
execute_drush_command() {
    local drush_cmd_args="$1"
    local additional_options="$2" # For internal use like --skip-find for sql-sync

    local target_option=""
    if [[ -n "$DRUSH_CURRENT_TARGET_ALIAS" ]]; then
        target_option="$DRUSH_CURRENT_TARGET_ALIAS"
    elif [[ -n "$DRUSH_CURRENT_TARGET_URI" ]]; then
        target_option="--uri=$DRUSH_CURRENT_TARGET_URI"
    fi

    log_info "Running: drush ${target_option} ${drush_cmd_args} ${additional_options}"
    execute_in_drupal_root "drush ${target_option} ${drush_cmd_args} ${additional_options}"
    return $?
}

# --- Drush Sub-menus and Commands ---

# General Drush commands
drush_general_menu() {
    local options=(
        "$(_ "MSG_DRUSH_STATUS")"
        "$(_ "MSG_DRUSH_CR")"
        "$(_ "MSG_BACK_TO_MAIN_MENU")"
    )

    while true; do
        display_header
        log_info "$(printf "$(_ "MSG_DRUSH_CURRENT_TARGET")" "${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI}")"
        select_option "$(_ "MSG_DRUSH_GENERAL_MENU")" "${options[@]}"
        local choice="$REPLY"

        case "$choice" in
            "$(_ "MSG_DRUSH_STATUS")") execute_drush_command "status"; press_enter_to_continue ;;
            "$(_ "MSG_DRUSH_CR")") execute_drush_command "cr"; press_enter_to_continue ;;
            "$(_ "MSG_BACK_TO_MAIN_MENU")") break ;;
            *) log_error "$(_ "MSG_INVALID_SELECTION")"; press_enter_to_continue ;;
        esac
    done
}

# Configuration management
drush_config_menu() {
    local options=(
        "$(_ "MSG_DRUSH_CIM")"
        "$(_ "MSG_DRUSH_CEX")"
        "$(_ "MSG_BACK_TO_MAIN_MENU")"
    )

    while true; do
        display_header
        log_info "$(printf "$(_ "MSG_DRUSH_CURRENT_TARGET")" "${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI}")"
        select_option "$(_ "MSG_DRUSH_CONFIG_MENU")" "${options[@]}"
        local choice="$REPLY"

        case "$choice" in
            "$(_ "MSG_DRUSH_CIM")") execute_drush_command "cim -y"; record_history "Drush Config Import" "drush ${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI} cim -y"; press_enter_to_continue ;;
            "$(_ "MSG_DRUSH_CEX")") execute_drush_command "cex -y"; record_history "Drush Config Export" "drush ${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI} cex -y"; press_enter_to_continue ;;
            "$(_ "MSG_BACK_TO_MAIN_MENU")") break ;;
            *) log_error "$(_ "MSG_INVALID_SELECTION")"; press_enter_to_continue ;;
        esac
    done
}

# Modules and Themes management
drush_pm_menu() {
    local options=(
        "$(_ "MSG_DRUSH_PM_LIST")"
        "$(_ "MSG_DRUSH_PM_ENABLE")"
        "$(_ "MSG_DRUSH_PM_DISABLE")"
        "$(_ "MSG_DRUSH_PM_UNINSTALL")"
        "$(_ "MSG_BACK_TO_MAIN_MENU")"
    )

    while true; do
        display_header
        log_info "$(printf "$(_ "MSG_DRUSH_CURRENT_TARGET")" "${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI}")"
        select_option "$(_ "MSG_DRUSH_MODULES_THEMES_MENU")" "${options[@]}"
        local choice="$REPLY"

        case "$choice" in
            "$(_ "MSG_DRUSH_PM_LIST")") execute_drush_command "pm:list"; press_enter_to_continue ;;
            "$(_ "MSG_DRUSH_PM_ENABLE")")
                get_user_input "$(_ "MSG_DRUSH_ENTER_MODULE_THEME_NAME")"
                local name="$REPLY"
                if [[ -n "$name" ]]; then
                    execute_drush_command "pm:enable $name -y"
                    record_history "Drush Enable $name" "drush ${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI} pm:enable $name -y"
                else
                    log_info "$(_ "MSG_OPERATION_CANCELLED")"
                fi
                press_enter_to_continue
                ;;
            "$(_ "MSG_DRUSH_PM_DISABLE")")
                get_user_input "$(_ "MSG_DRUSH_ENTER_MODULE_THEME_NAME")"
                local name="$REPLY"
                if [[ -n "$name" ]]; then
                    execute_drush_command "pm:disable $name -y"
                    record_history "Drush Disable $name" "drush ${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI} pm:disable $name -y"
                else
                    log_info "$(_ "MSG_OPERATION_CANCELLED")"
                fi
                press_enter_to_continue
                ;;
            "$(_ "MSG_DRUSH_PM_UNINSTALL")")
                get_user_input "$(_ "MSG_DRUSH_ENTER_MODULE_THEME_NAME")"
                local name="$REPLY"
                if [[ -n "$name" ]]; then
                    execute_drush_command "pm:uninstall $name -y"
                    record_history "Drush Uninstall $name" "drush ${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI} pm:uninstall $name -y"
                else
                    log_info "$(_ "MSG_OPERATION_CANCELLED")"
                fi
                press_enter_to_continue
                ;;
            "$(_ "MSG_BACK_TO_MAIN_MENU")") break ;;
            *) log_error "$(_ "MSG_INVALID_SELECTION")"; press_enter_to_continue ;;
        esac
    done
}

# User management
drush_user_menu() {
    local options=(
        "$(_ "MSG_DRUSH_USER_LOGIN")"
        "$(_ "MSG_DRUSH_USER_BLOCK")"
        "$(_ "MSG_DRUSH_USER_UNBLOCK")"
        "$(_ "MSG_DRUSH_USER_PASSWORD")"
        "$(_ "MSG_BACK_TO_MAIN_MENU")"
    )

    while true; do
        display_header
        log_info "$(printf "$(_ "MSG_DRUSH_CURRENT_TARGET")" "${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI}")"
        select_option "$(_ "MSG_DRUSH_USERS_MENU")" "${options[@]}"
        local choice="$REPLY"

        case "$choice" in
            "$(_ "MSG_DRUSH_USER_LOGIN")")
                get_user_input "$(_ "MSG_DRUSH_ENTER_USERNAME")" "admin"
                local username="$REPLY"
                if [[ -n "$username" ]]; then
                    execute_drush_command "user:login $username"
                    record_history "Drush User Login: $username" "drush ${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI} user:login $username"
                else
                    log_info "$(_ "MSG_OPERATION_CANCELLED")"
                fi
                press_enter_to_continue
                ;;
            "$(_ "MSG_DRUSH_USER_BLOCK")")
                get_user_input "$(_ "MSG_DRUSH_ENTER_USERNAME")"
                local username="$REPLY"
                if [[ -n "$username" ]]; then
                    execute_drush_command "user:block $username"
                    record_history "Drush User Block: $username" "drush ${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI} user:block $username"
                else
                    log_info "$(_ "MSG_OPERATION_CANCELLED")"
                fi
                press_enter_to_continue
                ;;
            "$(_ "MSG_DRUSH_USER_UNBLOCK")")
                get_user_input "$(_ "MSG_DRUSH_ENTER_USERNAME")"
                local username="$REPLY"
                if [[ -n "$username" ]]; then
                    execute_drush_command "user:unblock $username"
                    record_history "Drush User Unblock: $username" "drush ${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI} user:unblock $username"
                else
                    log_info "$(_ "MSG_OPERATION_CANCELLED")"
                fi
                press_enter_to_continue
                ;;
            "$(_ "MSG_DRUSH_USER_PASSWORD")")
                get_user_input "$(_ "MSG_DRUSH_ENTER_USERNAME")"
                local username="$REPLY"
                if [[ -n "$username" ]]; then
                    get_user_input "$(printf "$(_ "MSG_DRUSH_ENTER_NEW_PASSWORD")" "$username")"
                    local password="$REPLY"
                    if [[ -n "$password" ]]; then
                        execute_drush_command "user:password $username --password='$password'"
                        record_history "Drush User Password Change: $username" "drush ${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI} user:password $username --password='<HIDDEN>'"
                    else
                        log_info "$(_ "MSG_OPERATION_CANCELLED")"
                    fi
                else
                    log_info "$(_ "MSG_OPERATION_CANCELLED")"
                fi
                press_enter_to_continue
                ;;
            "$(_ "MSG_BACK_TO_MAIN_MENU")") break ;;
            *) log_error "$(_ "MSG_INVALID_SELECTION")"; press_enter_to_continue ;;
        esac
    done
}

# Watchdog management
drush_watchdog_menu() {
    local options=(
        "$(_ "MSG_DRUSH_WATCHDOG_SHOW")"
        "$(_ "MSG_DRUSH_WATCHDOG_LIST")"
        "$(_ "MSG_DRUSH_WATCHDOG_DELETE")"
        "$(_ "MSG_DRUSH_WATCHDOG_TAIL")"
        "$(_ "MSG_BACK_TO_MAIN_MENU")"
    )

    while true; do
        display_header
        log_info "$(printf "$(_ "MSG_DRUSH_CURRENT_TARGET")" "${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI}")"
        select_option "$(_ "MSG_DRUSH_WATCHDOG_MENU")" "${options[@]}"
        local choice="$REPLY"

        case "$choice" in
            "$(_ "MSG_DRUSH_WATCHDOG_SHOW")") execute_drush_command "wd-show"; press_enter_to_continue ;;
            "$(_ "MSG_DRUSH_WATCHDOG_LIST")") execute_drush_command "wd-list"; press_enter_to_continue ;;
            "$(_ "MSG_DRUSH_WATCHDOG_DELETE")")
                get_user_input "$(_ "MSG_DRUSH_ENTER_WATCHDOG_TYPE")" "all"
                local type="$REPLY"
                if [[ -n "$type" ]]; then
                    execute_drush_command "wd-del $type"
                    record_history "Drush Watchdog Delete: $type" "drush ${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI} wd-del $type"
                else
                    log_info "$(_ "MSG_OPERATION_CANCELLED")"
                fi
                press_enter_to_continue
                ;;
            "$(_ "MSG_DRUSH_WATCHDOG_TAIL")") execute_drush_command "wd-tail"; press_enter_to_continue ;;
            "$(_ "MSG_BACK_TO_MAIN_MENU")") break ;;
            *) log_error "$(_ "MSG_INVALID_SELECTION")"; press_enter_to_continue ;;
        esac
    done
}

# Development Tools
drush_dev_tools_menu() {
    local options=(
        "$(_ "MSG_DRUSH_EV")"
        "$(_ "MSG_DRUSH_PHP")"
        "$(_ "MSG_DRUSH_CRON")"
        "$(_ "MSG_BACK_TO_MAIN_MENU")"
    )

    while true; do
        display_header
        log_info "$(printf "$(_ "MSG_DRUSH_CURRENT_TARGET")" "${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI}")"
        select_option "$(_ "MSG_DRUSH_DEV_TOOLS_MENU")" "${options[@]}"
        local choice="$REPLY"

        case "$choice" in
            "$(_ "MSG_DRUSH_EV")")
                get_user_input "$(_ "MSG_DRUSH_ENTER_PHP_CODE")"
                local php_code="$REPLY"
                if [[ -n "$php_code" ]]; then
                    execute_drush_command "ev \"$php_code\""
                    record_history "Drush Eval PHP: ${php_code:0:50}..." "drush ${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI} ev \"$php_code\""
                else
                    log_info "$(_ "MSG_OPERATION_CANCELLED")"
                fi
                press_enter_to_continue
                ;;
            "$(_ "MSG_DRUSH_PHP")") execute_drush_command "php"; record_history "Drush Interactive PHP" "drush ${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI} php"; press_enter_to_continue ;;
            "$(_ "MSG_DRUSH_CRON")") execute_drush_command "cron"; record_history "Drush Cron" "drush ${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI} cron"; press_enter_to_continue ;;
            "$(_ "MSG_BACK_TO_MAIN_MENU")") break ;;
            *) log_error "$(_ "MSG_INVALID_SELECTION")"; press_enter_to_continue ;;
        esac
    done
}

# Webform management
drush_webform_menu() {
    local options=(
        "$(_ "MSG_DRUSH_WEBFORM_LIST")"
        "$(_ "MSG_DRUSH_WEBFORM_EXPORT")"
        "$(_ "MSG_DRUSH_WEBFORM_PURGE")"
        "$(_ "MSG_BACK_TO_MAIN_MENU")"
    )

    while true; do
        display_header
        log_info "$(printf "$(_ "MSG_DRUSH_CURRENT_TARGET")" "${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI}")"
        select_option "$(_ "MSG_DRUSH_WEBFORM_MENU")" "${options[@]}"
        local choice="$REPLY"

        case "$choice" in
            "$(_ "MSG_DRUSH_WEBFORM_LIST")") execute_drush_command "webform:list"; press_enter_to_continue ;;
            "$(_ "MSG_DRUSH_WEBFORM_EXPORT")")
                get_user_input "Enter webform ID to export submissions from:"
                local webform_id="$REPLY"
                if [[ -n "$webform_id" ]]; then
                    execute_drush_command "webform:export $webform_id"
                    record_history "Drush Webform Export: $webform_id" "drush ${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI} webform:export $webform_id"
                else
                    log_info "$(_ "MSG_OPERATION_CANCELLED")"
                fi
                press_enter_to_continue
                ;;
            "$(_ "MSG_DRUSH_WEBFORM_PURGE")")
                get_user_input "Enter webform ID to purge submissions from (or 'all'):"
                local webform_id="$REPLY"
                if [[ -n "$webform_id" ]]; then
                    execute_drush_command "webform:purge $webform_id -y"
                    record_history "Drush Webform Purge: $webform_id" "drush ${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI} webform:purge $webform_id -y"
                else
                    log_info "$(_ "MSG_OPERATION_CANCELLED")"
                fi
                press_enter_to_continue
                ;;
            "$(_ "MSG_BACK_TO_MAIN_MENU")") break ;;
            *) log_error "$(_ "MSG_INVALID_SELECTION")"; press_enter_to_continue ;;
        esac
    done
}


# Main Drush menu
drush_menu() {
    # Ensure a Drush target is selected before showing sub-menus
    if ! select_drush_target; then
        return
    fi

    local options=(
        "$(_ "MSG_DRUSH_GENERAL_MENU")"
        "$(_ "MSG_DRUSH_CONFIG_MENU")"
        "$(_ "MSG_DB_MENU_TITLE")" # Database functions are in core/database.sh but called from Drush context
        "$(_ "MSG_DRUSH_MODULES_THEMES_MENU")"
        "$(_ "MSG_DRUSH_USERS_MENU")"
        "$(_ "MSG_DRUSH_WATCHDOG_MENU")"
        "$(_ "MSG_SOLR_MENU_TITLE")" # Solr functions are in core/solr.sh but called from Drush context
        "$(_ "MSG_DRUSH_WEBFORM_MENU")"
        "$(_ "MSG_DRUSH_DEV_TOOLS_MENU")"
        "$(_ "MSG_BACK_TO_MAIN_MENU")"
    )

    while true; do
        display_header
        log_info "$(printf "$(_ "MSG_DRUSH_CURRENT_TARGET")" "${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI}")"
        select_option "$(_ "MSG_DRUSH_MENU_TITLE")" "${options[@]}"
        local choice="$REPLY"

        case "$choice" in
            "$(_ "MSG_DRUSH_GENERAL_MENU")") drush_general_menu ;;
            "$(_ "MSG_DRUSH_CONFIG_MENU")") drush_config_menu ;;
            "$(_ "MSG_DB_MENU_TITLE")") db_menu ;; # Calls the database menu
            "$(_ "MSG_DRUSH_MODULES_THEMES_MENU")") drush_pm_menu ;;
            "$(_ "MSG_DRUSH_USERS_MENU")") drush_user_menu ;;
            "$(_ "MSG_DRUSH_WATCHDOG_MENU")") drush_watchdog_menu ;;
            "$(_ "MSG_SOLR_MENU_TITLE")") solr_menu ;; # Calls the solr menu
            "$(_ "MSG_DRUSH_WEBFORM_MENU")") drush_webform_menu ;;
            "$(_ "MSG_DRUSH_DEV_TOOLS_MENU")") drush_dev_tools_menu ;;
            "$(_ "MSG_BACK_TO_MAIN_MENU")")
                DRUSH_CURRENT_TARGET_ALIAS="" # Clear selected target on exit
                DRUSH_CURRENT_TARGET_URI=""
                break
                ;;
            *) log_error "$(_ "MSG_INVALID_SELECTION")"; press_enter_to_continue ;;
        esac
    done
}

EOF

cat << 'EOF' > "${CORE_DIR}/git.sh"
#!/bin/bash

# File: core/git.sh
# Description: Git related functions for AUB Tools.

# Check if we are in a Git repository
is_git_repo() {
    git rev-parse --is-inside-work-tree &> /dev/null
}

# Ensure we are in a Git repository
ensure_git_repo() {
    if ! is_git_repo; then
        log_error "Not in a Git repository. Please navigate to a project directory."
        press_enter_to_continue
        return 1
    fi
    return 0
}

# Function to display git status
git_status() {
    if ! ensure_git_repo; then return; fi
    log_info "$(_ "MSG_GIT_STATUS")"
    git status
    press_enter_to_continue
}

# Function to display git log
git_log() {
    if ! ensure_git_repo; then return; fi
    log_info "$(_ "MSG_GIT_LOG")"
    git log --oneline --graph --decorate --all -n 20
    press_enter_to_continue
}

# Function to list all branches (local and remote)
git_list_branches() {
    if ! ensure_git_repo; then return; fi
    log_info "$(_ "MSG_GIT_FETCH_ALL")"
    git fetch --all --prune
    log_info "$(_ "MSG_GIT_LIST_BRANCHES")"
    git branch -a --color=always
    press_enter_to_continue
}

# Function to checkout an existing branch
git_checkout_branch() {
    if ! ensure_git_repo; then return; fi

    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    if ! git diff-index --quiet HEAD --; then
        log_warn "$(_ "MSG_GIT_UNCOMMITTED_CHANGES")"
        if ! confirm_action "Do you want to stash your changes before switching? (y/N)"; then
            log_info "$(_ "MSG_OPERATION_CANCELLED")"
            press_enter_to_continue
            return
        else
            git stash save "Auto-stash before branch switch"
            if [[ $? -ne 0 ]]; then
                log_error "Failed to stash changes. Aborting branch switch."
                press_enter_to_continue
                return
            fi
            log_success "Changes stashed before switching branch."
        fi
    fi

    log_info "$(_ "MSG_GIT_FETCH_ALL")"
    git fetch --all --prune

    local all_branches=$(git branch -a | sed 's/^[ *]*//g' | grep -v 'HEAD detached' | grep -v '^remotes/origin/HEAD' | sort -u)
    local branch_options=($all_branches "$(_ "MSG_CANCEL")")

    select_option "$(_ "MSG_GIT_CHECKOUT_BRANCH")" "${branch_options[@]}"
    local selected_branch="$REPLY"

    if [[ -z "$selected_branch" || "$selected_branch" == "$(_ "MSG_CANCEL")" ]]; then
        log_info "$(_ "MSG_OPERATION_CANCELLED")"
        return
    fi

    # Remove "remotes/origin/" prefix if it's a remote branch selected
    selected_branch=$(echo "$selected_branch" | sed 's/^remotes\/origin\///')

    log_info "Attempting to checkout: ${selected_branch}"
    if git checkout "${selected_branch}"; then
        log_success "$(printf "$(_ "MSG_GIT_CHECKED_OUT")" "${selected_branch}")"
        record_history "Git Checkout: ${selected_branch}" "git checkout ${selected_branch}"
    else
        log_error "Failed to checkout branch: ${selected_branch}"
    fi
    press_enter_to_continue
}

# Function to create a new branch
git_create_branch() {
    if ! ensure_git_repo; then return; fi

    get_user_input "$(_ "MSG_GIT_ENTER_BRANCH_NAME")"
    local new_branch_name="$REPLY"

    if [[ -z "$new_branch_name" ]]; then
        log_warn "$(_ "MSG_OPERATION_CANCELLED")"
        return
    fi

    if git checkout -b "${new_branch_name}"; then
        log_success "$(printf "$(_ "MSG_GIT_BRANCH_CREATED")" "${new_branch_name}")"
        record_history "Git Create Branch: ${new_branch_name}" "git checkout -b ${new_branch_name}"
    else
        log_error "Failed to create branch: ${new_branch_name}. It might already exist."
    fi
    press_enter_to_continue
}

# Branch management menu
git_branch_menu() {
    local options=(
        "$(_ "MSG_GIT_LIST_BRANCHES")"
        "$(_ "MSG_GIT_CHECKOUT_BRANCH")"
        "$(_ "MSG_GIT_CREATE_BRANCH")"
        "$(_ "MSG_BACK_TO_MAIN_MENU")"
    )

    while true; do
        display_header
        select_option "$(_ "MSG_GIT_BRANCH_MENU")" "${options[@]}"
        local choice="$REPLY"

        case "$choice" in
            "$(_ "MSG_GIT_LIST_BRANCHES")") git_list_branches ;;
            "$(_ "MSG_GIT_CHECKOUT_BRANCH")") git_checkout_branch ;;
            "$(_ "MSG_GIT_CREATE_BRANCH")") git_create_branch ;;
            "$(_ "MSG_BACK_TO_MAIN_MENU")") break ;;
            *) log_error "$(_ "MSG_INVALID_SELECTION")"; press_enter_to_continue ;;
        esac
    done
}

# Function to perform git pull
git_pull() {
    if ! ensure_git_repo; then return; fi
    log_info "$(_ "MSG_GIT_PULL")"
    if git pull; then
        log_success "$(_ "MSG_GIT_PULL_SUCCESS")"
        record_history "Git Pull" "git pull"
    else
        log_error "Git pull failed."
    fi
    press_enter_to_continue
}

# Function to perform git push
git_push() {
    if ! ensure_git_repo; then return; fi
    log_info "$(_ "MSG_GIT_PUSH")"
    if git push; then
        log_success "$(_ "MSG_GIT_PUSH_SUCCESS")"
        record_history "Git Push" "git push"
    else
        log_error "Git push failed."
    fi
    press_enter_to_continue
}

# Function to save changes to stash
git_stash_save() {
    if ! ensure_git_repo; then return; fi
    get_user_input "$(_ "MSG_GIT_STASH_MESSAGE")" "$(date +"%Y-%m-%d %H:%M") Automated Stash"
    local message="$REPLY"
    log_info "$(_ "MSG_GIT_STASH_SAVE")"
    if git stash save "$message"; then
        log_success "$(_ "MSG_GIT_STASH_SAVED")"
        record_history "Git Stash Save: $message" "git stash save \"$message\""
    else
        log_warn "$(_ "MSG_GIT_NO_CHANGES")"
    fi
    press_enter_to_continue
}

# Function to list stashes
git_stash_list() {
    if ! ensure_git_repo; then return; fi
    log_info "$(_ "MSG_GIT_STASH_LIST")"
    if ! git stash list; then
        log_info "$(_ "MSG_GIT_NO_STASHES")"
    fi
    press_enter_to_continue
}

# Function to apply a stash
git_stash_apply() {
    if ! ensure_git_repo; then return; fi
    local stashes=($(git stash list --format="%gd::%gs" | awk -F'::' '{print $1}'))
    if [[ ${#stashes[@]} -eq 0 ]]; then
        log_info "$(_ "MSG_GIT_NO_STASHES")"
        press_enter_to_continue
        return
    fi
    stashes+=("$(_ "MSG_CANCEL")")

    select_option "$(_ "MSG_GIT_STASH_APPLY")" "${stashes[@]}"
    local selected_stash="$REPLY"

    if [[ -z "$selected_stash" || "$selected_stash" == "$(_ "MSG_CANCEL")" ]]; then
        log_info "$(_ "MSG_OPERATION_CANCELLED")"
        return
    fi

    local stash_ref=$(echo "$selected_stash" | awk -F'::' '{print $1}')

    log_info "Applying stash: ${stash_ref}"
    if git stash apply "${stash_ref}"; then
        log_success "Stash applied: ${stash_ref}"
        record_history "Git Stash Apply: ${stash_ref}" "git stash apply ${stash_ref}"
    else
        log_error "Failed to apply stash: ${stash_ref}"
    fi
    press_enter_to_continue
}

# Function to pop a stash
git_stash_pop() {
    if ! ensure_git_repo; then return; fi
    local stashes=($(git stash list --format="%gd::%gs" | awk -F'::' '{print $1}'))
    if [[ ${#stashes[@]} -eq 0 ]]; then
        log_info "$(_ "MSG_GIT_NO_STASHES")"
        press_enter_to_continue
        return
    fi
    stashes+=("$(_ "MSG_CANCEL")")

    select_option "$(_ "MSG_GIT_STASH_POP")" "${stashes[@]}"
    local selected_stash="$REPLY"

    if [[ -z "$selected_stash" || "$selected_stash" == "$(_ "MSG_CANCEL")" ]]; then
        log_info "$(_ "MSG_OPERATION_CANCELLED")"
        return
    fi

    local stash_ref=$(echo "$selected_stash" | awk -F'::' '{print $1}')

    log_info "Popping stash: ${stash_ref}"
    if git stash pop "${stash_ref}"; then
        log_success "Stash popped: ${stash_ref}"
        record_history "Git Stash Pop: ${stash_ref}" "git stash pop ${stash_ref}"
    else
        log_error "Failed to pop stash: ${stash_ref}"
    fi
    press_enter_to_continue
}

# Function to drop a stash
git_stash_drop() {
    if ! ensure_git_repo; then return; fi
    local stashes=($(git stash list --format="%gd::%gs" | awk -F'::' '{print $1}'))
    if [[ ${#stashes[@]} -eq 0 ]]; then
        log_info "$(_ "MSG_GIT_NO_STASHES")"
        press_enter_to_continue
        return
    fi
    stashes+=("$(_ "MSG_CANCEL")")

    select_option "$(_ "MSG_GIT_STASH_DROP")" "${stashes[@]}"
    local selected_stash="$REPLY"

    if [[ -z "$selected_stash" || "$selected_stash" == "$(_ "MSG_CANCEL")" ]]; then
        log_info "$(_ "MSG_OPERATION_CANCELLED")"
        return
    fi

    local stash_ref=$(echo "$selected_stash" | awk -F'::' '{print $1}')

    if confirm_action "Are you sure you want to drop stash '${stash_ref}'? This action cannot be undone. (y/N)"; then
        log_info "Dropping stash: ${stash_ref}"
        if git stash drop "${stash_ref}"; then
            log_success "Stash dropped: ${stash_ref}"
            record_history "Git Stash Drop: ${stash_ref}" "git stash drop ${stash_ref}"
        else
            log_error "Failed to drop stash: ${stash_ref}"
        fi
    else
        log_info "$(_ "MSG_OPERATION_CANCELLED")"
    fi
    press_enter_to_continue
}

# Stash management menu
git_stash_menu() {
    local options=(
        "$(_ "MSG_GIT_STASH_SAVE")"
        "$(_ "MSG_GIT_STASH_LIST")"
        "$(_ "MSG_GIT_STASH_APPLY")"
        "$(_ "MSG_GIT_STASH_POP")"
        "$(_ "MSG_GIT_STASH_DROP")"
        "$(_ "MSG_BACK_TO_MAIN_MENU")"
    )

    while true; do
        display_header
        select_option "$(_ "MSG_GIT_STASH_MENU")" "${options[@]}"
        local choice="$REPLY"

        case "$choice" in
            "$(_ "MSG_GIT_STASH_SAVE")") git_stash_save ;;
            "$(_ "MSG_GIT_STASH_LIST")") git_stash_list ;;
            "$(_ "MSG_GIT_STASH_APPLY")") git_stash_apply ;;
            "$(_ "MSG_GIT_STASH_POP")") git_stash_pop ;;
            "$(_ "MSG_GIT_STASH_DROP")") git_stash_drop ;;
            "$(_ "MSG_BACK_TO_MAIN_MENU")") break ;;
            *) log_error "$(_ "MSG_INVALID_SELECTION")"; press_enter_to_continue ;;
        esac
    done
}

# Function to perform git reset --hard
git_reset_hard() {
    if ! ensure_git_repo; then return; fi
    if confirm_action "$(_ "MSG_GIT_RESET_HARD") THIS WILL DISCARD ALL LOCAL CHANGES. (y/N)"; then
        log_info "$(_ "MSG_GIT_RESET_HARD")"
        if git reset --hard; then
            log_success "Git reset --hard completed."
            record_history "Git Reset Hard" "git reset --hard"
        else
            log_error "Git reset --hard failed."
        fi
    else
        log_info "$(_ "MSG_OPERATION_CANCELLED")"
    fi
    press_enter_to_continue
}

# Function to perform git revert
git_revert_commit() {
    if ! ensure_git_repo; then return; fi
    log_info "Fetching recent commits..."
    local commits=$(git log --oneline -n 10 | awk '{print $1 "::" substr($0, index($0,$2))}') # Hash::Message
    local commit_options=($commits "$(_ "MSG_CANCEL")")

    if [[ -z "$commits" ]]; then
        log_info "No recent commits found."
        press_enter_to_continue
        return
    fi

    select_option "$(_ "MSG_GIT_REVERT_COMMIT") Select commit to revert:" "${commit_options[@]}"
    local selected_commit_line="$REPLY"

    if [[ -z "$selected_commit_line" || "$selected_commit_line" == "$(_ "MSG_CANCEL")" ]]; then
        log_info "$(_ "MSG_OPERATION_CANCELLED")"
        return
    fi

    local commit_hash=$(echo "$selected_commit_line" | awk -F'::' '{print $1}')
    local commit_message=$(echo "$selected_commit_line" | awk -F'::' '{print $2}')

    if confirm_action "Revert commit '${commit_message}' (${commit_hash})? This creates a new commit undoing changes. (y/N)"; then
        log_info "Reverting commit: ${commit_hash}"
        if git revert "${commit_hash}"; then
            log_success "Commit reverted: ${commit_hash}"
            record_history "Git Revert: ${commit_hash}" "git revert ${commit_hash}"
        else
            log_error "Failed to revert commit: ${commit_hash}"
        fi
    else
        log_info "$(_ "MSG_OPERATION_CANCELLED")"
    fi
    press_enter_to_continue
}

# Function to perform git clean -df
git_clean_force() {
    if ! ensure_git_repo; then return; fi
    if confirm_action "$(_ "MSG_GIT_CLEAN_FORCE") THIS WILL PERMANENTLY DELETE UNTRACKED FILES AND DIRECTORIES. (y/N)"; then
        log_info "$(_ "MSG_GIT_CLEAN_FORCE")"
        if git clean -df; then
            log_success "Git clean -df completed."
            record_history "Git Clean -df" "git clean -df"
        else
            log_error "Git clean -df failed."
        fi
    else
        log_info "$(_ "MSG_OPERATION_CANCELLED")"
    fi
    press_enter_to_continue
}

# Undo changes menu
git_undo_menu() {
    local options=(
        "$(_ "MSG_GIT_RESET_HARD")"
        "$(_ "MSG_GIT_REVERT_COMMIT")"
        "$(_ "MSG_GIT_CLEAN_FORCE")"
        "$(_ "MSG_BACK_TO_MAIN_MENU")"
    )

    while true; do
        display_header
        select_option "$(_ "MSG_GIT_UNDO_MENU")" "${options[@]}"
        local choice="$REPLY"

        case "$choice" in
            "$(_ "MSG_GIT_RESET_HARD")") git_reset_hard ;;
            "$(_ "MSG_GIT_REVERT_COMMIT")") git_revert_commit ;;
            "$(_ "MSG_GIT_CLEAN_FORCE")") git_clean_force ;;
            "$(_ "MSG_BACK_TO_MAIN_MENU")") break ;;
            *) log_error "$(_ "MSG_INVALID_SELECTION")"; press_enter_to_continue ;;
        esac
    done
}


# Main Git menu
git_menu() {
    if ! ensure_git_repo; then return; fi # Check if it's a git repo first

    local options=(
        "$(_ "MSG_GIT_STATUS")"
        "$(_ "MSG_GIT_LOG")"
        "$(_ "MSG_GIT_BRANCH_MENU")"
        "$(_ "MSG_GIT_PULL")"
        "$(_ "MSG_GIT_PUSH")"
        "$(_ "MSG_GIT_STASH_MENU")"
        "$(_ "MSG_GIT_UNDO_MENU")"
        "$(_ "MSG_BACK_TO_MAIN_MENU")"
    )

    while true; do
        display_header
        select_option "$(_ "MSG_GIT_MENU_TITLE")" "${options[@]}"
        local choice="$REPLY"

        case "$choice" in
            "$(_ "MSG_GIT_STATUS")") git_status ;;
            "$(_ "MSG_GIT_LOG")") git_log ;;
            "$(_ "MSG_GIT_BRANCH_MENU")") git_branch_menu ;;
            "$(_ "MSG_GIT_PULL")") git_pull ;;
            "$(_ "MSG_GIT_PUSH")") git_push ;;
            "$(_ "MSG_GIT_STASH_MENU")") git_stash_menu ;;
            "$(_ "MSG_GIT_UNDO_MENU")") git_undo_menu ;;
            "$(_ "MSG_BACK_TO_MAIN_MENU")") break ;;
            *) log_error "$(_ "MSG_INVALID_SELECTION")"; press_enter_to_continue ;;
        esac
    done
}
EOF

cat << 'EOF' > "${CORE_DIR}/ibmcloud.sh"
#!/bin/bash

# File: core/ibmcloud.sh
# Description: Functions for IBM Cloud integration.

# Function to check if ibmcloud CLI is available
ibmcloud_cli_exists() {
    command_exists "ibmcloud"
}

# Function to prompt for IBM Cloud region and resource group if not set
prompt_ibmcloud_config() {
    if [[ -z "$IBMCLOUD_REGION" ]]; then
        get_user_input "$(_ "MSG_IBMCLOUD_ENTER_REGION")"
        IBMCLOUD_REGION="$REPLY"
        if [[ -z "$IBMCLOUD_REGION" ]]; then
            log_error "IBM Cloud region is required."
            return 1
        fi
    fi

    if [[ -z "$IBMCLOUD_RESOURCE_GROUP" ]]; then
        get_user_input "$(_ "MSG_IBMCLOUD_ENTER_RESOURCE_GROUP")"
        IBMCLOUD_RESOURCE_GROUP="$REPLY" # Can be empty
    fi
    return 0
}


# Function to log in to IBM Cloud
ibmcloud_login() {
    if ! ibmcloud_cli_exists; then
        log_error "IBM Cloud CLI not found. Please install it."
        press_enter_to_continue
        return
    fi

    if ! prompt_ibmcloud_config; then return; fi

    log_info "Logging into IBM Cloud (SSO)..."
    local login_command="ibmcloud login --sso -r ${IBMCLOUD_REGION}"
    if [[ -n "$IBMCLOUD_RESOURCE_GROUP" ]]; then
        login_command="${login_command} -g \"${IBMCLOUD_RESOURCE_GROUP}\""
    fi

    if eval "$login_command"; then
        log_success "$(_ "MSG_IBMCLOUD_LOGIN_SUCCESS")"
        record_history "IBM Cloud Login" "$login_command"
    else
        log_error "IBM Cloud login failed."
    fi
    press_enter_to_continue
}

# Function to log out from IBM Cloud
ibmcloud_logout() {
    if ! ibmcloud_cli_exists; then
        log_error "IBM Cloud CLI not found."
        press_enter_to_continue
        return
    fi
    log_info "Logging out from IBM Cloud..."
    if ibmcloud logout -f; then # -f for force logout
        log_success "$(_ "MSG_IBMCLOUD_LOGOUT_SUCCESS")"
        record_history "IBM Cloud Logout" "ibmcloud logout -f"
    else
        log_error "IBM Cloud logout failed."
    fi
    press_enter_to_continue
}

# Function to list Kubernetes clusters
ibmcloud_list_k8s_clusters() {
    if ! ibmcloud_cli_exists; then
        log_error "IBM Cloud CLI not found."
        press_enter_to_continue
        return
    fi
    log_info "$(_ "MSG_IBMCLOUD_LIST_K8S_CLUSTERS")"
    ibmcloud ks clusters
    press_enter_to_continue
}

# Function to configure kubectl for a specific cluster
ibmcloud_configure_kubectl() {
    if ! ibmcloud_cli_exists; then
        log_error "IBM Cloud CLI not found."
        press_enter_to_continue
        return
    fi

    log_info "Fetching Kubernetes clusters..."
    local clusters_output=$(ibmcloud ks clusters --json)
    local cluster_names=($("${AUB_TOOLS_DIR}/bin/jq" -r '.[].name' <<< "$clusters_output"))

    if [[ ${#cluster_names[@]} -eq 0 ]]; then
        log_warn "No Kubernetes clusters found. Please ensure you are logged in and have clusters available."
        press_enter_to_continue
        return
    fi

    cluster_names+=("$(_ "MSG_CANCEL")")

    select_option "$(_ "MSG_IBMCLOUD_CONFIGURE_KUBECTL")" "${cluster_names[@]}"
    local selected_cluster="$REPLY"

    if [[ -z "$selected_cluster" || "$selected_cluster" == "$(_ "MSG_CANCEL")" ]]; then
        log_info "$(_ "MSG_OPERATION_CANCELLED")"
        return
    fi

    log_info "Configuring kubectl for cluster: ${selected_cluster}"
    if ibmcloud ks cluster config --cluster "${selected_cluster}" --admin --endpoint private; then
        log_success "$(printf "$(_ "MSG_IBMCLOUD_K8S_CONTEXT_SET")" "${selected_cluster}")"
        record_history "Configure Kubectl for ${selected_cluster}" "ibmcloud ks cluster config --cluster ${selected_cluster} --admin --endpoint private"
    else
        log_error "Failed to configure kubectl for cluster: ${selected_cluster}"
    fi
    press_enter_to_continue
}

# IBM Cloud main menu
ibmcloud_menu() {
    local options=(
        "$(_ "MSG_IBMCLOUD_LOGIN")"
        "$(_ "MSG_IBMCLOUD_LOGOUT")"
        "$(_ "MSG_IBMCLOUD_LIST_K8S_CLUSTERS")"
        "$(_ "MSG_IBMCLOUD_CONFIGURE_KUBECTL")"
        "$(_ "MSG_BACK_TO_MAIN_MENU")"
    )

    while true; do
        display_header
        select_option "$(_ "MSG_IBMCLOUD_MENU_TITLE")" "${options[@]}"
        local choice="$REPLY"

        case "$choice" in
            "$(_ "MSG_IBMCLOUD_LOGIN")") ibmcloud_login ;;
            "$(_ "MSG_IBMCLOUD_LOGOUT")") ibmcloud_logout ;;
            "$(_ "MSG_IBMCLOUD_LIST_K8S_CLUSTERS")") ibmcloud_list_k8s_clusters ;;
            "$(_ "MSG_IBMCLOUD_CONFIGURE_KUBECTL")") ibmcloud_configure_kubectl ;;
            "$(_ "MSG_BACK_TO_MAIN_MENU")") break ;;
            *) log_error "$(_ "MSG_INVALID_SELECTION")"; press_enter_to_continue ;;
        esac
    done
}
EOF

cat << 'EOF' > "${CORE_DIR}/k8s.sh"
#!/bin/bash

# File: core/k8s.sh
# Description: Functions for Kubernetes management via kubectl.

# Function to check if kubectl is installed and configured
check_kubectl_context() {
    if ! command_exists "kubectl"; then
        log_error "kubectl command not found. Please install it."
        press_enter_to_continue
        return 1
    fi

    local current_context=$(kubectl config current-context 2>/dev/null)
    if [[ -z "$current_context" ]]; then
        log_warn "$(_ "MSG_K8S_CONTEXT_NOT_SET")"
        press_enter_to_continue
        return 1
    else
        log_info "Current kubectl context: ${current_context}"
    fi
    return 0
}

# Generic function to select a Kubernetes pod interactively
# Usage: select_kubectl_pod [label_filter]
# Sets K8S_SELECTED_POD_NAME
# Returns 0 on success, 1 on cancel or no pods found
select_kubectl_pod() {
    local label_filter="${1:-}" # Optional label filter, e.g., "app=drupal"
    K8S_SELECTED_POD_NAME="" # Reset

    if ! check_kubectl_context; then return 1; }

    log_info "Listing pods..."
    local pods_output=""
    if [[ -n "$label_filter" ]]; then
        log_info "Filtering by label: ${label_filter}"
        pods_output=$(kubectl get pods -l "$label_filter" -o=json 2>/dev/null)
    else
        pods_output=$(kubectl get pods -o=json 2>/dev/null)
    fi

    local pod_names=($("${AUB_TOOLS_DIR}/bin/jq" -r '.items[].metadata.name' <<< "$pods_output" 2>/dev/null))

    if [[ ${#pod_names[@]} -eq 0 ]]; then
        log_warn "$(_ "MSG_K8S_NO_PODS_FOUND")"
        press_enter_to_continue
        return 1
    fi

    pod_names+=("$(_ "MSG_CANCEL")")

    select_option "$(_ "MSG_K8S_SELECT_POD_TO_MANAGE")" "${pod_names[@]}"
    local selected_pod="$REPLY"

    if [[ -z "$selected_pod" || "$selected_pod" == "$(_ "MSG_CANCEL")" ]]; then
        log_info "$(_ "MSG_OPERATION_CANCELLED")"
        return 1
    fi

    K8S_SELECTED_POD_NAME="$selected_pod"
    log_info "Selected Pod: ${K8S_SELECTED_POD_NAME}"
    return 0
}

# Generic function to select a container within a selected pod interactively
# Usage: select_kubectl_container [pod_name]
# Sets K8S_SELECTED_CONTAINER_NAME
# Returns 0 on success, 1 on cancel or no containers found
select_kubectl_container() {
    local pod_name="${1:-$K8S_SELECTED_POD_NAME}" # Use provided pod_name or global K8S_SELECTED_POD_NAME
    K8S_SELECTED_CONTAINER_NAME="" # Reset

    if [[ -z "$pod_name" ]]; then
        log_error "No pod name provided or selected."
        return 1
    fi
    if ! check_kubectl_context; then return 1; }

    log_info "Listing containers for pod: ${pod_name}"
    local containers_output=$(kubectl get pod "${pod_name}" -o=jsonpath='{.spec.containers[*].name}' 2>/dev/null)
    local container_names=($containers_output)

    if [[ ${#container_names[@]} -eq 0 ]]; then
        log_warn "$(_ "MSG_K8S_NO_CONTAINERS_FOUND")"
        press_enter_to_continue
        return 1
    fi

    # If only one container, select it automatically
    if [[ ${#container_names[@]} -eq 1 ]]; then
        K8S_SELECTED_CONTAINER_NAME="${container_names[0]}"
        log_info "Auto-selected single container: ${K8S_SELECTED_CONTAINER_NAME}"
        return 0
    fi

    container_names+=("$(_ "MSG_CANCEL")")

    select_option "$(_ "MSG_K8S_SELECT_CONTAINER_TO_MANAGE")" "${container_names[@]}"
    local selected_container="$REPLY"

    if [[ -z "$selected_container" || "$selected_container" == "$(_ "MSG_CANCEL")" ]]; then
        log_info "$(_ "MSG_OPERATION_CANCELLED")"
        return 1
    fi

    K8S_SELECTED_CONTAINER_NAME="$selected_container"
    log_info "Selected Container: ${K8S_SELECTED_CONTAINER_NAME}"
    return 0
}

# Function to list pods (generic)
k8s_pod_status() {
    if ! check_kubectl_context; then return; }
    log_info "$(_ "MSG_K8S_POD_STATUS")"
    get_user_input "$(_ "MSG_K8S_ENTER_POD_LABEL_FILTER")"
    local filter="$REPLY"
    if [[ -n "$filter" ]]; then
        kubectl get pods -l "$filter"
    else
        kubectl get pods
    fi
    press_enter_to_continue
}

# Function to restart a pod (by deleting it)
k8s_restart_pod() {
    if ! select_kubectl_pod "$1"; then return; fi # Pass optional label filter
    if [[ -z "$K8S_SELECTED_POD_NAME" ]]; then return; fi

    if confirm_action "Are you sure you want to restart pod '${K8S_SELECTED_POD_NAME}'? (y/N)"; then
        log_info "Restarting pod: ${K8S_SELECTED_POD_NAME}..."
        if kubectl delete pod "${K8S_SELECTED_POD_NAME}"; then
            log_success "Pod '${K8S_SELECTED_POD_NAME}' restarted."
            record_history "K8s Restart Pod: ${K8S_SELECTED_POD_NAME}" "kubectl delete pod ${K8S_SELECTED_POD_NAME}"
        else
            log_error "Failed to restart pod: ${K8S_SELECTED_POD_NAME}"
        fi
    else
        log_info "$(_ "MSG_OPERATION_CANCELLED")"
    fi
    press_enter_to_continue
}

# Function to view pod/container logs
k8s_view_logs() {
    if ! select_kubectl_pod "$1"; then return; fi # Pass optional label filter
    if [[ -z "$K8S_SELECTED_POD_NAME" ]]; then return; fi

    if ! select_kubectl_container "$K8S_SELECTED_POD_NAME"; then return; fi
    if [[ -z "$K8S_SELECTED_CONTAINER_NAME" ]]; then return; fi

    log_info "Viewing logs for pod '${K8S_SELECTED_POD_NAME}' container '${K8S_SELECTED_CONTAINER_NAME}'"
    kubectl logs -f "${K8S_SELECTED_POD_NAME}" -c "${K8S_SELECTED_CONTAINER_NAME}"
    press_enter_to_continue
}

# Function to copy files to a Kubernetes pod
k8s_copy_files_to_pod() {
    if ! select_kubectl_pod "$1"; then return; fi
    if [[ -z "$K8S_SELECTED_POD_NAME" ]]; then return; }

    if ! select_kubectl_container "$K8S_SELECTED_POD_NAME"; then return; fi
    if [[ -z "$K8S_SELECTED_CONTAINER_NAME" ]]; then return; }

    get_user_input "$(_ "MSG_K8S_ENTER_LOCAL_PATH")"
    local local_path="$REPLY"
    if [[ -z "$local_path" ]]; then
        log_warn "$(_ "MSG_OPERATION_CANCELLED")"
        return
    fi
    if [[ ! -e "$local_path" ]]; then
        log_error "Local path does not exist: $local_path"
        press_enter_to_continue
        return
    fi

    get_user_input "$(_ "MSG_K8S_ENTER_REMOTE_PATH")" "/tmp/" # Default remote path
    local remote_path="$REPLY"
    if [[ -z "$remote_path" ]]; then
        log_warn "$(_ "MSG_OPERATION_CANCELLED")"
        return
    fi

    log_info "Copying '${local_path}' to '${K8S_SELECTED_POD_NAME}:${remote_path}' in container '${K8S_SELECTED_CONTAINER_NAME}'..."
    if kubectl cp "${local_path}" "${K8S_SELECTED_POD_NAME}:${remote_path}" -c "${K8S_SELECTED_CONTAINER_NAME}"; then
        log_success "$(printf "$(_ "MSG_K8S_COPY_SUCCESS")" "${K8S_SELECTED_POD_NAME}" "${K8S_SELECTED_CONTAINER_NAME}")"
        record_history "K8s Copy Files: ${local_path} to ${K8S_SELECTED_POD_NAME}:${remote_path}" "kubectl cp ${local_path} ${K8S_SELECTED_POD_NAME}:${remote_path} -c ${K8S_SELECTED_CONTAINER_NAME}"
    else
        log_error "$(_ "MSG_K8S_COPY_FAILED")"
    fi
    press_enter_to_continue
}

# Solr Pod management menu
k8s_solr_menu() {
    if ! check_kubectl_context; then return; }
    local options=(
        "$(_ "MSG_K8S_POD_STATUS") (Solr pods)"
        "$(_ "MSG_K8S_POD_RESTART") (Solr pod)"
        "$(_ "MSG_K8S_POD_LOGS") (Solr pod)"
        "$(_ "MSG_BACK_TO_MAIN_MENU")"
    )
    local solr_label_filter="app.kubernetes.io/component=solr" # Common Solr label

    while true; do
        display_header
        select_option "$(_ "MSG_K8S_SOLR_MENU")" "${options[@]}"
        local choice="$REPLY"

        case "$choice" in
            *"$(printf "$(_ "MSG_K8S_POD_STATUS")" "Solr")"*) k8s_pod_status "$solr_label_filter" ;;
            *"$(printf "$(_ "MSG_K8S_POD_RESTART")" "Solr")"*) k8s_restart_pod "$solr_label_filter" ;;
            *"$(printf "$(_ "MSG_K8S_POD_LOGS")" "Solr")"*) k8s_view_logs "$solr_label_filter" ;;
            "$(_ "MSG_BACK_TO_MAIN_MENU")") break ;;
            *) log_error "$(_ "MSG_INVALID_SELECTION")"; press_enter_to_continue ;;
        esac
    done
}

# PostgreSQL Pod management menu
k8s_postgres_menu() {
    if ! check_kubectl_context; then return; }
    local options=(
        "$(_ "MSG_K8S_POD_STATUS") (PostgreSQL pods)"
        "$(_ "MSG_K8S_PSQL_CLI")"
        "$(_ "MSG_K8S_POD_LOGS") (PostgreSQL pod)"
        "$(_ "MSG_BACK_TO_MAIN_MENU")"
    )
    local postgres_label_filter="app.kubernetes.io/name=postgresql" # Common PostgreSQL label

    while true; do
        display_header
        select_option "$(_ "MSG_K8S_POSTGRES_MENU")" "${options[@]}"
        local choice="$REPLY"

        case "$choice" in
            *"$(printf "$(_ "MSG_K8S_POD_STATUS")" "PostgreSQL")"*) k8s_pod_status "$postgres_label_filter" ;;
            "$(_ "MSG_K8S_PSQL_CLI")") k8s_psql_cli ;;
            *"$(printf "$(_ "MSG_K8S_POD_LOGS")" "PostgreSQL")"*) k8s_view_logs "$postgres_label_filter" ;;
            "$(_ "MSG_BACK_TO_MAIN_MENU")") break ;;
            *) log_error "$(_ "MSG_INVALID_SELECTION")"; press_enter_to_continue ;;
        esac
    done
}

# Function to access psql CLI in a Kubernetes pod
k8s_psql_cli() {
    local postgres_label_filter="app.kubernetes.io/name=postgresql" # Common PostgreSQL label
    if ! select_kubectl_pod "$postgres_label_filter"; then return; fi
    if [[ -z "$K8S_SELECTED_POD_NAME" ]]; then return; fi

    if ! select_kubectl_container "$K8S_SELECTED_POD_NAME"; then return; fi
    if [[ -z "$K8S_SELECTED_CONTAINER_NAME" ]]; then return; fi

    log_info "Accessing psql CLI in pod '${K8S_SELECTED_POD_NAME}' container '${K8S_SELECTED_CONTAINER_NAME}'..."
    # You might need to adjust the command based on your PostgreSQL container image
    # Common approaches: `psql`, `PGPASSWORD=... psql -U user -d db`
    # We'll assume 'psql' is in the PATH and env vars are set by k8s secrets
    kubectl exec -it "${K8S_SELECTED_POD_NAME}" -c "${K8S_SELECTED_CONTAINER_NAME}" -- psql
    local exit_status=$?
    if [[ $exit_status -eq 0 ]]; then
        log_success "Exited psql CLI."
        record_history "K8s psql CLI: ${K8S_SELECTED_POD_NAME}" "kubectl exec -it ${K8S_SELECTED_POD_NAME} -c ${K8S_SELECTED_CONTAINER_NAME} -- psql"
    else
        log_error "Failed to access psql CLI. Exit status: $exit_status"
    fi
    press_enter_to_continue
}


# Main Kubernetes menu
k8s_menu() {
    if ! check_kubectl_context; then return; fi

    local options=(
        "$(_ "MSG_K8S_CHECK_CONTEXT")"
        "$(_ "MSG_K8S_POD_STATUS") (All pods)"
        "$(_ "MSG_K8S_SOLR_MENU")"
        "$(_ "MSG_K8S_POSTGRES_MENU")"
        "$(_ "MSG_K8S_COPY_FILES")"
        "$(_ "MSG_BACK_TO_MAIN_MENU")"
    )

    while true; do
        display_header
        select_option "$(_ "MSG_K8S_MENU_TITLE")" "${options[@]}"
        local choice="$REPLY"

        case "$choice" in
            "$(_ "MSG_K8S_CHECK_CONTEXT")") check_kubectl_context; press_enter_to_continue ;;
            "$(_ "MSG_K8S_POD_STATUS") (All pods)") k8s_pod_status ;;
            "$(_ "MSG_K8S_SOLR_MENU")") k8s_solr_menu ;;
            "$(_ "MSG_K8S_POSTGRES_MENU")") k8s_postgres_menu ;;
            "$(_ "MSG_K8S_COPY_FILES")") k8s_copy_files_to_pod ;;
            "$(_ "MSG_BACK_TO_MAIN_MENU")") break ;;
            *) log_error "$(_ "MSG_INVALID_SELECTION")"; press_enter_to_continue ;;
        esac
    done
}
EOF

cat << 'EOF' > "${CORE_DIR}/project.sh"
#!/bin/bash

# File: core/project.sh
# Description: Functions for Drupal project initialization and management.

# Global variable to store the root directory of the current project
CURRENT_PROJECT_PATH=""
DRUPAL_ROOT="" # The actual Drupal web root within the project (e.g., project/web)

# Function to initialize a new Drupal project
init_new_project() {
    get_user_input "Enter the Git repository URL (e.g., https://github.com/drupal/recommended-project.git):"
    local repo_url="$REPLY"
    if [[ -z "$repo_url" ]]; then
        log_warn "$(_ "MSG_OPERATION_CANCELLED")"
        return
    fi

    local project_name=$(basename "$repo_url" .git)
    get_user_input "Enter local directory name for the project (default: ${project_name}):" "$project_name"
    local local_dir="$REPLY"
    if [[ -z "$local_dir" ]]; then
        log_warn "$(_ "MSG_OPERATION_CANCELLED")"
        return
    fi

    # Check if directory already exists
    if [[ -d "$local_dir" ]]; then
        log_error "Directory '${local_dir}' already exists. Please choose a different name or remove it."
        press_enter_to_continue
        return
    fi

    log_info "$(_ "MSG_PROJECT_CLONE_REPO")"
    if ! git clone "$repo_url" "$local_dir"; then
        log_error "Failed to clone repository: ${repo_url}"
        press_enter_to_continue
        return
    fi

    # Set current project path
    CURRENT_PROJECT_PATH="$(pwd)/$local_dir"
    log_info "Project cloned to: ${CURRENT_PROJECT_PATH}"
    record_history "Project Init: Clone ${repo_url} to ${local_dir}" "git clone ${repo_url} ${local_dir}"

    # Try to detect Drupal root
    log_info "$(_ "MSG_PROJECT_DETECT_DRUPAL_ROOT")"
    if ! (cd "$CURRENT_PROJECT_PATH" && detect_drupal_root "$CURRENT_PROJECT_PATH"); then
        log_warn "$(_ "MSG_PROJECT_DRUPAL_ROOT_NOT_FOUND")"
        # Prompt user to manually set if auto-detection fails
        get_user_input "Enter Drupal root directory relative to project root (e.g., 'web' or 'src/web'):" "$DRUPAL_ROOT_DIR"
        local manual_drupal_root="$REPLY"
        if [[ -d "${CURRENT_PROJECT_PATH}/${manual_drupal_root}" ]]; then
            DRUPAL_ROOT="${CURRENT_PROJECT_PATH}/${manual_drupal_root}"
            log_success "$(printf "$(_ "MSG_PROJECT_DRUPAL_ROOT_FOUND")" "${DRUPAL_ROOT}") (Manually set)"
        else
            log_error "Manual Drupal root not found: ${CURRENT_PROJECT_PATH}/${manual_drupal_root}. Please correct it."
            DRUPAL_ROOT=""
            press_enter_to_continue
            return
        fi
    else
        log_success "$(printf "$(_ "MSG_PROJECT_DRUPAL_ROOT_FOUND")" "${DRUPAL_ROOT}")"
    fi

    # Run Composer install
    composer_install

    # Generate .env file
    generate_env_file
    
    log_success "New Drupal project '${local_dir}' initialized successfully!"
    press_enter_to_continue
}

# Function to generate .env from .env.dist
generate_env_file() {
    if [[ -z "$CURRENT_PROJECT_PATH" ]]; then
        log_error "No project selected or initialized."
        return 1
    fi

    local env_dist_path="${CURRENT_PROJECT_PATH}/.env.dist"
    local env_path="${CURRENT_PROJECT_PATH}/.env"

    if [[ ! -f "$env_dist_path" ]]; then
        log_warn "'.env.dist' not found in project root: ${env_dist_path}. Skipping .env generation."
        return
    fi

    log_info "$(_ "MSG_PROJECT_GENERATE_ENV")"
    local temp_env_content=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^([A-Z_]+)=(.+)$ && ! "$line" =~ ^\# ]]; then
            local var_name="${BASH_REMATCH[1]}"
            local default_value="${BASH_REMATCH[2]}"
            # Remove leading/trailing quotes if present
            default_value=$(echo "$default_value" | sed -e "s/^'//" -e "s/'$//" -e 's/^"//' -e 's/"$//')

            get_user_input "$(printf "$(_ "MSG_PROJECT_ENTER_VAR_VALUE")" "$var_name" "$default_value")" "$default_value"
            temp_env_content+="${var_name}=\"${REPLY}\"\n"
        elif [[ "$line" =~ ^# ]]; then
            # Keep comments and empty lines
            temp_env_content+="$line\n"
        else
            # Keep lines that are not comments but not key=value
            temp_env_content+="$line\n"
        fi
    done < "$env_dist_path"

    echo -e "$temp_env_content" > "$env_path"
    log_success "$(printf "$(_ "MSG_PROJECT_ENV_GENERATED")" "${env_path}")"
    record_history "Generate .env file for ${CURRENT_PROJECT_PATH}" "generated .env from .env.dist"
}

# Function to select an existing project (by navigating to its directory)
select_existing_project() {
    local projects_dir="${HOME}/Projects" # Common location for projects, adjust as needed
    if [[ ! -d "$projects_dir" ]]; then
        log_warn "Projects directory '${projects_dir}' not found. Please create it or set CURRENT_PROJECT_PATH manually."
        press_enter_to_continue
        return 1
    fi

    log_info "Listing projects in: ${projects_dir}"
    local project_dirs=()
    while IFS= read -r -d $'\0' dir; do
        # Only include directories that look like potential projects (e.g., have a .git or composer.json)
        if [[ -d "$dir/.git" || -f "$dir/composer.json" ]]; then
            project_dirs+=("$(basename "$dir")")
        fi
    done < <(find "$projects_dir" -maxdepth 1 -mindepth 1 -type d -print0 | sort -z)


    if [[ ${#project_dirs[@]} -eq 0 ]]; then
        log_info "No projects found in '${projects_dir}'. Please clone a project first."
        press_enter_to_continue
        return 1
    fi

    project_dirs+=("$(_ "MSG_CANCEL")")

    select_option "Select an existing project" "${project_dirs[@]}"
    local selected_project_name="$REPLY"

    if [[ -z "$selected_project_name" || "$selected_project_name" == "$(_ "MSG_CANCEL")" ]]; then
        log_info "$(_ "MSG_OPERATION_CANCELLED")"
        return 1
    fi

    CURRENT_PROJECT_PATH="${projects_dir}/${selected_project_name}"
    log_info "Selected project: ${CURRENT_PROJECT_PATH}"
    record_history "Selected Project: ${selected_project_name}" "cd ${CURRENT_PROJECT_PATH}"

    # Try to detect Drupal root for the selected project
    log_info "$(_ "MSG_PROJECT_DETECT_DRUPAL_ROOT")"
    if ! (cd "$CURRENT_PROJECT_PATH" && detect_drupal_root "$CURRENT_PROJECT_PATH"); then
        log_warn "$(_ "MSG_PROJECT_DRUPAL_ROOT_NOT_FOUND")"
        # Prompt user to manually set if auto-detection fails for existing project
        get_user_input "Enter Drupal root directory relative to project root (e.g., 'web' or 'src/web'):" "$DRUPAL_ROOT_DIR"
        local manual_drupal_root="$REPLY"
        if [[ -d "${CURRENT_PROJECT_PATH}/${manual_drupal_root}" ]]; then
            DRUPAL_ROOT="${CURRENT_PROJECT_PATH}/${manual_drupal_root}"
            log_success "$(printf "$(_ "MSG_PROJECT_DRUPAL_ROOT_FOUND")" "${DRUPAL_ROOT}") (Manually set for existing project)"
        else
            log_error "Manual Drupal root not found: ${CURRENT_PROJECT_PATH}/${manual_drupal_root}. Please correct it."
            DRUPAL_ROOT=""
            press_enter_to_continue
            return 1
        fi
    else
        log_success "$(printf "$(_ "MSG_PROJECT_DRUPAL_ROOT_FOUND")" "${DRUPAL_ROOT}")"
    fi
    press_enter_to_continue
    return 0
}

# Project management menu
project_menu() {
    local options=(
        "$(_ "MSG_PROJECT_INIT")"
        "Select existing project"
        "$(_ "MSG_BACK_TO_MAIN_MENU")"
    )

    while true; do
        display_header
        if [[ -n "$CURRENT_PROJECT_PATH" ]]; then
            log_info "Current project: $(basename "$CURRENT_PROJECT_PATH")"
        else
            log_warn "No project currently selected."
        fi
        select_option "$(_ "MSG_PROJECT_MENU_TITLE")" "${options[@]}"
        local choice="$REPLY"

        case "$choice" in
            "$(_ "MSG_PROJECT_INIT")") init_new_project ;;
            "Select existing project") select_existing_project ;;
            "$(_ "MSG_BACK_TO_MAIN_MENU")") break ;;
            *) log_error "$(_ "MSG_INVALID_SELECTION")"; press_enter_to_continue ;;
        esac
    done
}

EOF

cat << 'EOF' > "${CORE_DIR}/solr.sh"
#!/bin/bash

# File: core/solr.sh
# Description: Functions for Search API Solr management.

# Function to list Solr servers
solr_server_list() {
    if ! select_drush_target; then return; fi
    log_info "$(_ "MSG_SOLR_SERVER_LIST")"
    execute_drush_command "search-api:server-list"
    press_enter_to_continue
}

# Function to list Solr indexes
solr_index_list() {
    if ! select_drush_target; then return; fi
    log_info "$(_ "MSG_SOLR_INDEX_LIST")"
    execute_drush_command "search-api:index-list"
    press_enter_to_continue
}

# Function to export Solr configurations
solr_export_config() {
    if ! select_drush_target; then return; fi
    if [[ -z "$CURRENT_PROJECT_PATH" ]]; then
        log_error "No project selected. Cannot determine export path."
        press_enter_to_continue
        return
    fi

    local export_path="${CURRENT_PROJECT_PATH}/${SOLR_CONFIG_EXPORT_DIR}"
    mkdir -p "${export_path}"
    log_info "Exporting Solr configurations to: ${export_path}"
    if execute_drush_command "search-api-solr:export-solr-config ${export_path}"; then
        log_success "$(printf "$(_ "MSG_SOLR_CONFIG_EXPORTED")" "${export_path}")"
        record_history "Drush Solr Export Config" "drush ${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI} search-api-solr:export-solr-config ${export_path}"
    else
        log_error "Failed to export Solr configurations."
    fi
    press_enter_to_continue
}

# Function to index content
solr_index_content() {
    if ! select_drush_target; then return; fi
    log_info "$(_ "MSG_SOLR_INDEX_CONTENT")"
    execute_drush_command "search-api:index"
    record_history "Drush Solr Index Content" "drush ${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI} search-api:index"
    press_enter_to_continue
}

# Function to clear Solr index
solr_clear_index() {
    if ! select_drush_target; then return; fi
    if confirm_action "Are you sure you want to clear the Solr index? (y/N)"; then
        log_info "$(_ "MSG_SOLR_CLEAR_INDEX")"
        if execute_drush_command "search-api:clear"; then
            log_success "Solr index cleared."
            record_history "Drush Solr Clear Index" "drush ${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI} search-api:clear"
        else
            log_error "Failed to clear Solr index."
        fi
    else
        log_info "$(_ "MSG_OPERATION_CANCELLED")"
    fi
    press_enter_to_continue
}

# Function to get Solr status
solr_status() {
    if ! select_drush_target; then return; fi
    log_info "$(_ "MSG_SOLR_STATUS")"
    execute_drush_command "search-api:status"
    press_enter_to_continue
}

# Main Solr management menu
solr_menu() {
    if [[ -z "$DRUSH_CURRENT_TARGET_ALIAS" && -z "$DRUSH_CURRENT_TARGET_URI" ]]; then
        log_warn "$(_ "MSG_DRUSH_TARGET_NONE_SELECTED")"
        press_enter_to_continue
        return
    fi

    local options=(
        "$(_ "MSG_SOLR_SERVER_LIST")"
        "$(_ "MSG_SOLR_INDEX_LIST")"
        "$(_ "MSG_SOLR_EXPORT_CONFIG")"
        "$(_ "MSG_SOLR_INDEX_CONTENT")"
        "$(_ "MSG_SOLR_CLEAR_INDEX")"
        "$(_ "MSG_SOLR_STATUS")"
        "$(_ "MSG_BACK_TO_MAIN_MENU")"
    )

    while true; do
        display_header
        log_info "$(printf "$(_ "MSG_DRUSH_CURRENT_TARGET")" "${DRUSH_CURRENT_TARGET_ALIAS:-$DRUSH_CURRENT_TARGET_URI}")"
        select_option "$(_ "MSG_SOLR_MENU_TITLE")" "${options[@]}"
        local choice="$REPLY"

        case "$choice" in
            "$(_ "MSG_SOLR_SERVER_LIST")") solr_server_list ;;
            "$(_ "MSG_SOLR_INDEX_LIST")") solr_index_list ;;
            "$(_ "MSG_SOLR_EXPORT_CONFIG")") solr_export_config ;;
            "$(_ "MSG_SOLR_INDEX_CONTENT")") solr_index_content ;;
            "$(_ "MSG_SOLR_CLEAR_INDEX")") solr_clear_index ;;
            "$(_ "MSG_SOLR_STATUS")") solr_status ;;
            "$(_ "MSG_BACK_TO_MAIN_MENU")") break ;;
            *) log_error "$(_ "MSG_INVALID_SELECTION")"; press_enter_to_continue ;;
        esac
    done
}
EOF

# Make install.sh executable
chmod +x "${INSTALL_DIR}/install.sh"
log_success "AUB Tools structure created."
log_info "To complete installation and add 'aub-tools' to your PATH, run:"
echo "source ${INSTALL_DIR}/install.sh"
echo "or add 'export PATH=\"${BIN_DIR}:\$PATH\"' to your ~/.bashrc or ~/.zshrc"

log_success "AUB Tools installation script generated successfully!"
