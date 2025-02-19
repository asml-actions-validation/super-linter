#!/usr/bin/env bash

##################################################################
# Debug Vars                                                     #
# Define these early, so we can use debug logging ASAP if needed #
##################################################################
declare -l ACTIONS_RUNNER_DEBUG
ACTIONS_RUNNER_DEBUG="${ACTIONS_RUNNER_DEBUG:-"false"}" # Boolean to see even more info (debug)
IMAGE="${IMAGE:-standard}"                              # Version of the Super-linter (standard,slim,etc)

##################################################################
# Log Vars                                                       #
# Define these early, so we can use debug logging ASAP if needed #
##################################################################
LOG_FILE="${LOG_FILE:-"super-linter.log"}" # Default log file name (located in GITHUB_WORKSPACE folder)
LOG_LEVEL="${LOG_LEVEL:-VERBOSE}"          # Default log level (VERBOSE, DEBUG, TRACE)
declare -l CREATE_LOG_FILE
CREATE_LOG_FILE="${CREATE_LOG_FILE:-"false"}"

if [[ ${ACTIONS_RUNNER_DEBUG} == true ]]; then LOG_LEVEL="DEBUG"; fi
# Boolean to see trace logs
LOG_TRACE=$(if [[ ${LOG_LEVEL} == "TRACE" ]]; then echo "true"; fi)
export LOG_TRACE
# Boolean to see debug logs
LOG_DEBUG=$(if [[ ${LOG_LEVEL} == "DEBUG" || ${LOG_LEVEL} == "TRACE" ]]; then echo "true"; fi)
export LOG_DEBUG
# Boolean to see verbose logs (info function)
LOG_VERBOSE=$(if [[ ${LOG_LEVEL} == "VERBOSE" || ${LOG_LEVEL} == "DEBUG" || ${LOG_LEVEL} == "TRACE" ]]; then echo "true"; fi)
export LOG_VERBOSE
# Boolean to see notice logs
LOG_NOTICE=$(if [[ ${LOG_LEVEL} == "NOTICE" || ${LOG_LEVEL} == "VERBOSE" || ${LOG_LEVEL} == "DEBUG" || ${LOG_LEVEL} == "TRACE" ]]; then echo "true"; fi)
export LOG_NOTICE
# Boolean to see warn logs
LOG_WARN=$(if [[ ${LOG_LEVEL} == "WARN" || ${LOG_LEVEL} == "NOTICE" || ${LOG_LEVEL} == "VERBOSE" || ${LOG_LEVEL} == "DEBUG" || ${LOG_LEVEL} == "TRACE" ]]; then echo "true"; fi)
export LOG_WARN
# Boolean to see error logs
LOG_ERROR=$(if [[ ${LOG_LEVEL} == "ERROR" || ${LOG_LEVEL} == "WARN" || ${LOG_LEVEL} == "NOTICE" || ${LOG_LEVEL} == "VERBOSE" || ${LOG_LEVEL} == "DEBUG" || ${LOG_LEVEL} == "TRACE" ]]; then echo "true"; fi)
export LOG_ERROR

#########################
# Source Function Files #
#########################
# shellcheck source=/dev/null
source /action/lib/functions/buildFileList.sh # Source the function script(s)
# shellcheck source=/dev/null
source /action/lib/functions/detectFiles.sh # Source the function script(s)
# shellcheck source=/dev/null
source /action/lib/functions/linterRules.sh # Source the function script(s)
# shellcheck source=/dev/null
source /action/lib/functions/log.sh # Source the function script(s)
# shellcheck source=/dev/null
source /action/lib/functions/updateSSL.sh # Source the function script(s)
# shellcheck source=/dev/null
source /action/lib/functions/validation.sh # Source the function script(s)
# shellcheck source=/dev/null
source /action/lib/functions/worker.sh # Source the function script(s)
# shellcheck source=/dev/null
source /action/lib/functions/setupSSH.sh # Source the function script(s)
# shellcheck source=/dev/null
source /action/lib/functions/githubEvent.sh

# We want a lowercase value
declare -l RUN_LOCAL
# Initialize RUN_LOCAL early because we need it for logging
RUN_LOCAL="${RUN_LOCAL:-"false"}"

# Dynamically set the default behavior for GitHub Actions log markers because
# we want to give users a chance to enable this even when running locally, but
# we still want to provide a default value in case they don't want to explictly
# configure it.
if [[ "${RUN_LOCAL}" == "true" ]]; then
  DEFAULT_ENABLE_GITHUB_ACTIONS_GROUP_TITLE="false"
else
  DEFAULT_ENABLE_GITHUB_ACTIONS_GROUP_TITLE="true"
fi
# Let users configure GitHub Actions log markers regardless of running locally or not
ENABLE_GITHUB_ACTIONS_GROUP_TITLE="${ENABLE_GITHUB_ACTIONS_GROUP_TITLE:-"${DEFAULT_ENABLE_GITHUB_ACTIONS_GROUP_TITLE}"}"
export ENABLE_GITHUB_ACTIONS_GROUP_TITLE

startGitHubActionsLogGroup "${SUPER_LINTER_INITIALIZATION_LOG_GROUP_TITLE}"

# We want a lowercase value
declare -l DISABLE_ERRORS
DISABLE_ERRORS="${DISABLE_ERRORS:-"false"}"

# We want a lowercase value
declare -l IGNORE_GENERATED_FILES
# Do not ignore generated files by default for backwards compatibility
IGNORE_GENERATED_FILES="${IGNORE_GENERATED_FILES:-false}"
export IGNORE_GENERATED_FILES

# We want a lowercase value
declare -l IGNORE_GITIGNORED_FILES
IGNORE_GITIGNORED_FILES="${IGNORE_GITIGNORED_FILES:-false}"
export IGNORE_GITIGNORED_FILES

# We want a lowercase value
declare -l MULTI_STATUS
MULTI_STATUS="${MULTI_STATUS:-true}"

# We want a lowercase value
declare -l SSH_INSECURE_NO_VERIFY_GITHUB_KEY
SSH_INSECURE_NO_VERIFY_GITHUB_KEY="${SSH_INSECURE_NO_VERIFY_GITHUB_KEY:-false}"

# We want a lowercase value
declare -l SSH_SETUP_GITHUB
SSH_SETUP_GITHUB="${SSH_SETUP_GITHUB:-false}"

# We want a lowercase value
declare -l SUPPRESS_FILE_TYPE_WARN
SUPPRESS_FILE_TYPE_WARN="${SUPPRESS_FILE_TYPE_WARN:-false}"

# We want a lowercase value
declare -l SUPPRESS_POSSUM
SUPPRESS_POSSUM="${SUPPRESS_POSSUM:-false}"

# We want a lowercase value
declare -l TEST_CASE_RUN
# Option to tell code to run only test cases
TEST_CASE_RUN="${TEST_CASE_RUN:-"false"}"

# We want a lowercase value
declare -l USE_FIND_ALGORITHM
USE_FIND_ALGORITHM="${USE_FIND_ALGORITHM:-false}"

# We want a lowercase value
declare -l VALIDATE_ALL_CODEBASE
VALIDATE_ALL_CODEBASE="${VALIDATE_ALL_CODEBASE:-"true"}"

# We want a lowercase value
declare -l YAML_ERROR_ON_WARNING
YAML_ERROR_ON_WARNING="${YAML_ERROR_ON_WARNING:-false}"

ValidateBooleanConfigurationVariables

###########
# GLOBALS #
###########
DEFAULT_RULES_LOCATION='/action/lib/.automation'                            # Default rules files location
DEFAULT_SUPER_LINTER_WORKSPACE="/tmp/lint"                                  # Fall-back value for the workspace
DEFAULT_WORKSPACE="${DEFAULT_WORKSPACE:-${DEFAULT_SUPER_LINTER_WORKSPACE}}" # Default workspace if running locally
FILTER_REGEX_INCLUDE="${FILTER_REGEX_INCLUDE:-""}"
FILTER_REGEX_EXCLUDE="${FILTER_REGEX_EXCLUDE:-""}"
# GitHub API root url
GITHUB_API_URL="${GITHUB_CUSTOM_API_URL:-"https://api.github.com"}"
# Remove trailing slash if present
GITHUB_API_URL="${GITHUB_API_URL%/}"
GITHUB_SERVER_URL="${GITHUB_DOMAIN:-"https://github.com"}"
# Extract domain name from URL
GITHUB_SERVER_URL=$(echo "$GITHUB_SERVER_URL" | cut -d '/' -f 3)
LINTER_RULES_PATH="${LINTER_RULES_PATH:-.github/linters}" # Linter rules directory
# shellcheck disable=SC2034 # Variable is referenced in other scripts
RAW_FILE_ARRAY=() # Array of all files that were changed
# shellcheck disable=SC2034 # Variable is referenced in other scripts
TEST_CASE_FOLDER='test/linters' # Folder for test cases we should always ignore

# Set the log level
TF_LOG_LEVEL="info"
if [ "${ACTIONS_RUNNER_DEBUG}" = "true" ]; then
  TF_LOG_LEVEL="debug"
fi
export TF_LOG_LEVEL
debug "TF_LOG_LEVEL: ${TF_LOG_LEVEL}"
TFLINT_LOG="${TF_LOG_LEVEL}"
export TFLINT_LOG
debug "TFLINT_LOG: ${TFLINT_LOG}"

###############
# Rules files #
###############
# shellcheck disable=SC2034  # Variable is referenced indirectly
ANSIBLE_FILE_NAME="${ANSIBLE_CONFIG_FILE:-.ansible-lint.yml}"
# shellcheck disable=SC2034  # Variable is referenced indirectly
ARM_FILE_NAME=".arm-ttk.psd1"
CHECKOV_FILE_NAME="${CHECKOV_FILE_NAME:-".checkov.yaml"}"
# shellcheck disable=SC2034  # Variable is referenced indirectly
CLOJURE_FILE_NAME=".clj-kondo/config.edn"
# shellcheck disable=SC2034  # Variable is referenced indirectly
CLOUDFORMATION_FILE_NAME=".cfnlintrc.yml"
# shellcheck disable=SC2034  # Variable is referenced indirectly
COFFEESCRIPT_FILE_NAME=".coffee-lint.json"
CSS_FILE_NAME="${CSS_FILE_NAME:-.stylelintrc.json}"
DOCKERFILE_HADOLINT_FILE_NAME="${DOCKERFILE_HADOLINT_FILE_NAME:-.hadolint.yaml}"
EDITORCONFIG_FILE_NAME="${EDITORCONFIG_FILE_NAME:-.ecrc}"
# shellcheck disable=SC2034  # Variable is referenced indirectly
GITHUB_ACTIONS_FILE_NAME="${GITHUB_ACTIONS_CONFIG_FILE:-actionlint.yml}"
# shellcheck disable=SC2034  # Variable is referenced indirectly
GITHUB_ACTIONS_COMMAND_ARGS="${GITHUB_ACTIONS_COMMAND_ARGS:-null}"
# shellcheck disable=SC2034  # Variable is referenced indirectly
GITLEAKS_FILE_NAME="${GITLEAKS_CONFIG_FILE:-.gitleaks.toml}"
# shellcheck disable=SC2034  # Variable is referenced indirectly
GHERKIN_FILE_NAME=".gherkin-lintrc"
# shellcheck disable=SC2034  # Variable is referenced indirectly
GO_FILE_NAME=".golangci.yml"
# shellcheck disable=SC2034  # Variable is referenced indirectly
GROOVY_FILE_NAME=".groovylintrc.json"
# shellcheck disable=SC2034  # Variable is referenced indirectly
HTML_FILE_NAME=".htmlhintrc"
# shellcheck disable=SC2034  # Variable is referenced indirectly
JAVA_FILE_NAME="${JAVA_FILE_NAME:-sun_checks.xml}"
# shellcheck disable=SC2034  # Variable is referenced indirectly
JAVASCRIPT_ES_FILE_NAME="${JAVASCRIPT_ES_CONFIG_FILE:-.eslintrc.yml}"
# shellcheck disable=SC2034  # Variable is referenced indirectly
JAVASCRIPT_DEFAULT_STYLE="${JAVASCRIPT_DEFAULT_STYLE:-standard}"
JAVASCRIPT_STYLE_NAME='' # Variable for the style
# shellcheck disable=SC2034  # Variable is referenced indirectly
JAVASCRIPT_STANDARD_FILE_NAME="${JAVASCRIPT_ES_CONFIG_FILE:-.eslintrc.yml}"
# shellcheck disable=SC2034  # Variable is referenced indirectly
JSCPD_FILE_NAME="${JSCPD_CONFIG_FILE:-.jscpd.json}"
# shellcheck disable=SC2034  # Variable is referenced indirectly
JSX_FILE_NAME="${JAVASCRIPT_ES_CONFIG_FILE:-.eslintrc.yml}"
# shellcheck disable=SC2034  # Variable is referenced indirectly
KUBERNETES_KUBECONFORM_OPTIONS="${KUBERNETES_KUBECONFORM_OPTIONS:-null}"
# shellcheck disable=SC2034  # Variable is referenced indirectly
LATEX_FILE_NAME=".chktexrc"
# shellcheck disable=SC2034  # Variable is referenced indirectly
LUA_FILE_NAME=".luacheckrc"
# shellcheck disable=SC2034  # Variable is referenced indirectly
MARKDOWN_FILE_NAME="${MARKDOWN_CONFIG_FILE:-.markdown-lint.yml}"
# shellcheck disable=SC2034  # Variable is referenced indirectly
OPENAPI_FILE_NAME=".openapirc.yml"
# shellcheck disable=SC2034  # Variable is referenced indirectly
PERL_PERLCRITIC_OPTIONS="${PERL_PERLCRITIC_OPTIONS:-null}"
# shellcheck disable=SC2034  # Variable is referenced indirectly
PHP_BUILTIN_FILE_NAME="${PHP_CONFIG_FILE:-php.ini}"
# shellcheck disable=SC2034  # Variable is referenced indirectly
PHP_PHPCS_FILE_NAME="${PHP_PHPCS_FILE_NAME:-phpcs.xml}"
# shellcheck disable=SC2034  # Variable is referenced indirectly
PHP_PHPSTAN_FILE_NAME="phpstan.neon"
# shellcheck disable=SC2034  # Variable is referenced indirectly
PHP_PSALM_FILE_NAME="psalm.xml"
# shellcheck disable=SC2034  # Variable is referenced indirectly
POWERSHELL_FILE_NAME=".powershell-psscriptanalyzer.psd1"
# shellcheck disable=SC2034  # Variable is referenced indirectly
PROTOBUF_FILE_NAME="${PROTOBUF_CONFIG_FILE:-.protolintrc.yml}"
# shellcheck disable=SC2034  # Variable is referenced indirectly
PYTHON_BLACK_FILE_NAME="${PYTHON_BLACK_CONFIG_FILE:-.python-black}"
# shellcheck disable=SC2034  # Variable is referenced indirectly
PYTHON_FLAKE8_FILE_NAME="${PYTHON_FLAKE8_CONFIG_FILE:-.flake8}"
# shellcheck disable=SC2034  # Variable is referenced indirectly
PYTHON_ISORT_FILE_NAME="${PYTHON_ISORT_CONFIG_FILE:-.isort.cfg}"
# shellcheck disable=SC2034  # Variable is referenced indirectly
PYTHON_MYPY_FILE_NAME="${PYTHON_MYPY_CONFIG_FILE:-.mypy.ini}"
# shellcheck disable=SC2034  # Variable is referenced indirectly
PYTHON_PYLINT_FILE_NAME="${PYTHON_PYLINT_CONFIG_FILE:-.python-lint}"
# shellcheck disable=SC2034  # Variable is referenced indirectly
R_FILE_NAME=".lintr"
# shellcheck disable=SC2034  # Variable is referenced indirectly
RUBY_FILE_NAME="${RUBY_CONFIG_FILE:-.ruby-lint.yml}"
# shellcheck disable=SC2034  # Variable is referenced indirectly
SCALAFMT_FILE_NAME="${SCALAFMT_CONFIG_FILE:-.scalafmt.conf}"
# shellcheck disable=SC2034  # Variable is referenced indirectly
SNAKEMAKE_SNAKEFMT_FILE_NAME="${SNAKEMAKE_SNAKEFMT_CONFIG_FILE:-.snakefmt.toml}"
# shellcheck disable=SC2034  # Variable is referenced indirectly
SQL_FILE_NAME="${SQL_CONFIG_FILE:-.sql-config.json}"
# shellcheck disable=SC2034  # Variable is referenced indirectly
SQLFLUFF_FILE_NAME="${SQLFLUFF_CONFIG_FILE:-/.sqlfluff}"
# shellcheck disable=SC2034  # Variable is referenced indirectly
TERRAFORM_TFLINT_FILE_NAME="${TERRAFORM_TFLINT_CONFIG_FILE:-.tflint.hcl}"
# shellcheck disable=SC2034  # Variable is referenced indirectly
TERRAFORM_TERRASCAN_FILE_NAME="${TERRAFORM_TERRASCAN_CONFIG_FILE:-terrascan.toml}"
# shellcheck disable=SC2034  # Variable is referenced indirectly
NATURAL_LANGUAGE_FILE_NAME="${NATURAL_LANGUAGE_CONFIG_FILE:-.textlintrc}"
# shellcheck disable=SC2034  # Variable is referenced indirectly
TSX_FILE_NAME="${TYPESCRIPT_ES_CONFIG_FILE:-.eslintrc.yml}"
# shellcheck disable=SC2034  # Variable is referenced indirectly
TYPESCRIPT_DEFAULT_STYLE="${TYPESCRIPT_DEFAULT_STYLE:-ts-standard}"
TYPESCRIPT_STYLE_NAME='' # Variable for the style
# shellcheck disable=SC2034  # Variable is referenced indirectly
TYPESCRIPT_ES_FILE_NAME="${TYPESCRIPT_ES_CONFIG_FILE:-.eslintrc.yml}"
# shellcheck disable=SC2034  # Variable is referenced indirectly
YAML_FILE_NAME="${YAML_CONFIG_FILE:-.yaml-lint.yml}"

#################################################
# Parse if we are using JS standard or prettier #
#################################################
# Remove spaces
JAVASCRIPT_DEFAULT_STYLE=$(echo "${JAVASCRIPT_DEFAULT_STYLE}" | tr -d ' ')
# lowercase
JAVASCRIPT_DEFAULT_STYLE=$(echo "${JAVASCRIPT_DEFAULT_STYLE}" | tr '[:upper:]' '[:lower:]')
# Check and set
if [ "${JAVASCRIPT_DEFAULT_STYLE}" == "prettier" ]; then
  # Set to prettier
  JAVASCRIPT_STYLE_NAME='JAVASCRIPT_PRETTIER'
else
  # Default to standard
  JAVASCRIPT_STYLE_NAME='JAVASCRIPT_STANDARD'
fi

#################################################
# Parse if we are using JS standard or prettier #
#################################################
# Remove spaces
TYPESCRIPT_DEFAULT_STYLE=$(echo "${TYPESCRIPT_DEFAULT_STYLE}" | tr -d ' ')
# lowercase
TYPESCRIPT_DEFAULT_STYLE=$(echo "${TYPESCRIPT_DEFAULT_STYLE}" | tr '[:upper:]' '[:lower:]')
# Check and set
if [ "${TYPESCRIPT_DEFAULT_STYLE}" == "prettier" ]; then
  # Set to prettier
  TYPESCRIPT_STYLE_NAME='TYPESCRIPT_PRETTIER'
else
  # Default to standard
  TYPESCRIPT_STYLE_NAME='TYPESCRIPT_STANDARD'
fi

##################
# Language array #
##################
LANGUAGE_ARRAY=('ANSIBLE' 'ARM' 'BASH' 'BASH_EXEC' 'CHECKOV' 'CLANG_FORMAT'
  'CLOUDFORMATION' 'CLOJURE' 'COFFEESCRIPT' 'CPP' 'CSHARP' 'CSS' 'DART'
  'DOCKERFILE_HADOLINT' 'EDITORCONFIG' 'ENV' 'GITHUB_ACTIONS'
  'GITLEAKS' 'GHERKIN' 'GO' 'GO_MODULES' 'GOOGLE_JAVA_FORMAT' 'GROOVY' 'HTML' 'JAVA'
  'JAVASCRIPT_ES' "${JAVASCRIPT_STYLE_NAME}" 'JSCPD' 'JSON' 'JSONC' 'JSX'
  'KUBERNETES_KUBECONFORM' 'KOTLIN' 'LATEX' 'LUA' 'MARKDOWN'
  'NATURAL_LANGUAGE' 'OPENAPI' 'PERL' 'PHP_BUILTIN' 'PHP_PHPCS' 'PHP_PHPSTAN'
  'PHP_PSALM' 'POWERSHELL' 'PROTOBUF' 'PYTHON_BLACK' 'PYTHON_PYLINT'
  'PYTHON_FLAKE8' 'PYTHON_ISORT' 'PYTHON_MYPY' 'R' 'RAKU' 'RENOVATE' 'RUBY' 'RUST_2015'
  'RUST_2018' 'RUST_2021' 'RUST_CLIPPY' 'SCALAFMT' 'SHELL_SHFMT'
  'SNAKEMAKE_LINT' 'SNAKEMAKE_SNAKEFMT' 'STATES' 'SQL' 'SQLFLUFF' 'TEKTON'
  'TERRAFORM_FMT' 'TERRAFORM_TFLINT' 'TERRAFORM_TERRASCAN' 'TERRAGRUNT' 'TSX'
  'TYPESCRIPT_ES' "${TYPESCRIPT_STYLE_NAME}" 'XML' 'YAML')

##########################
# Array of changed files #
##########################
for LANGUAGE in "${LANGUAGE_ARRAY[@]}"; do
  FILE_ARRAY_VARIABLE_NAME="FILE_ARRAY_${LANGUAGE}"
  debug "Setting ${FILE_ARRAY_VARIABLE_NAME} variable..."
  eval "${FILE_ARRAY_VARIABLE_NAME}=()"
done

################################################################################
########################## FUNCTIONS BELOW #####################################
################################################################################
################################################################################
#### Function Header ###########################################################
Header() {
  ###############################
  # Give them the possum action #
  ###############################
  if [[ "${SUPPRESS_POSSUM}" == "false" ]]; then
    /bin/bash /action/lib/functions/possum.sh
  fi

  ##########
  # Prints #
  ##########
  info "---------------------------------------------"
  info "--- GitHub Actions Multi Language Linter ----"
  info " - Image Creation Date:[${BUILD_DATE}]"
  info " - Image Revision:[${BUILD_REVISION}]"
  info " - Image Version:[${BUILD_VERSION}]"
  info "---------------------------------------------"
  info "---------------------------------------------"
  info "The Super-Linter source code can be found at:"
  info " - https://github.com/super-linter/super-linter"
  info "---------------------------------------------"

  if [[ ${VALIDATE_ALL_CODEBASE} != "false" ]]; then
    VALIDATE_ALL_CODEBASE="true"
    info "- Validating all files in code base..."
  else
    info "- Validating changed files in code base..."
  fi
}

ConfigureGitSafeDirectories() {
  debug "Configuring Git safe directories"
  declare -a git_safe_directories=("${GITHUB_WORKSPACE}" "${DEFAULT_SUPER_LINTER_WORKSPACE}" "${DEFAULT_WORKSPACE}")
  for safe_directory in "${git_safe_directories[@]}"; do
    debug "Set ${safe_directory} as a Git safe directory"
    if ! git config --global --add safe.directory "${safe_directory}"; then
      fatal "Cannot configure ${safe_directory} as a Git safe directory."
    fi
  done
}

################################################################################
#### Function GetGitHubVars ####################################################
GetGitHubVars() {
  ##########
  # Prints #
  ##########
  info "--------------------------------------------"
  info "Gathering GitHub information..."

  local GITHUB_REPOSITORY_DEFAULT_BRANCH
  GITHUB_REPOSITORY_DEFAULT_BRANCH="master"

  if [[ ${RUN_LOCAL} != "false" ]]; then
    info "RUN_LOCAL has been set to: ${RUN_LOCAL}. Bypassing GitHub Actions variables..."

    if [ -z "${GITHUB_WORKSPACE}" ]; then
      GITHUB_WORKSPACE="${DEFAULT_WORKSPACE}"
    fi

    ValidateGitHubWorkspace "${GITHUB_WORKSPACE}"

    pushd "${GITHUB_WORKSPACE}" >/dev/null || exit 1

    if [[ "${USE_FIND_ALGORITHM}" == "false" ]]; then
      ConfigureGitSafeDirectories
      debug "Initializing GITHUB_SHA considering ${GITHUB_WORKSPACE}"
      if ! GITHUB_SHA=$(git -C "${GITHUB_WORKSPACE}" rev-parse HEAD); then
        fatal "Failed to initialize GITHUB_SHA. Output: ${GITHUB_SHA}"
      fi
      debug "GITHUB_SHA: ${GITHUB_SHA}"
    else
      debug "Skip the initalization of GITHUB_SHA because we don't need it"
    fi

    MULTI_STATUS="false"
    debug "Setting MULTI_STATUS to ${MULTI_STATUS} because we are not running on GitHub Actions"
  else
    ValidateGitHubWorkspace "${GITHUB_WORKSPACE}"

    # Ensure that Git can access the local repository
    ConfigureGitSafeDirectories

    if [ -z "${GITHUB_EVENT_PATH}" ]; then
      fatal "Failed to get GITHUB_EVENT_PATH: ${GITHUB_EVENT_PATH}]"
    else
      info "Successfully found GITHUB_EVENT_PATH: ${GITHUB_EVENT_PATH}]"
      debug "${GITHUB_EVENT_PATH} contents: $(cat "${GITHUB_EVENT_PATH}")"
    fi

    if [ -z "${GITHUB_SHA}" ]; then
      fatal "Failed to get GITHUB_SHA: ${GITHUB_SHA}"
    else
      info "Successfully found GITHUB_SHA: ${GITHUB_SHA}"
    fi

    ##################################################
    # Need to pull the GitHub Vars from the env file #
    ##################################################

    GITHUB_ORG=$(jq -r '.repository.owner.login' <"${GITHUB_EVENT_PATH}")

    # Github sha on PR events is not the latest commit.
    # https://docs.github.com/en/actions/reference/events-that-trigger-workflows#pull_request
    if [ "$GITHUB_EVENT_NAME" == "pull_request" ]; then
      debug "This is a GitHub pull request. Updating the current GITHUB_SHA (${GITHUB_SHA}) to the pull request HEAD SHA"

      if ! GITHUB_SHA=$(jq -r .pull_request.head.sha <"$GITHUB_EVENT_PATH"); then
        fatal "Failed to update GITHUB_SHA for pull request event: ${GITHUB_SHA}"
      fi
      debug "Updated GITHUB_SHA: ${GITHUB_SHA}"
    elif [ "${GITHUB_EVENT_NAME}" == "push" ]; then
      debug "This is a GitHub push event."

      GITHUB_PUSH_COMMIT_COUNT=$(GetGithubPushEventCommitCount "$GITHUB_EVENT_PATH")
      if [ -z "${GITHUB_PUSH_COMMIT_COUNT}" ]; then
        fatal "Failed to get GITHUB_PUSH_COMMIT_COUNT"
      fi
      info "Successfully found GITHUB_PUSH_COMMIT_COUNT: ${GITHUB_PUSH_COMMIT_COUNT}"

      # Ref: https://docs.github.com/en/actions/learn-github-actions/contexts#github-context
      debug "Get the hash of the commit to start the diff from from Git because the GitHub push event payload may not contain references to base_ref or previous commit."
      # shellcheck disable=SC2086  # We checked that GITHUB_PUSH_COMMIT_COUNT is an integer
      if ! GITHUB_BEFORE_SHA=$(git -C "${GITHUB_WORKSPACE}" rev-parse HEAD~${GITHUB_PUSH_COMMIT_COUNT}); then
        fatal "Failed to initialize GITHUB_BEFORE_SHA for a push event. Output: ${GITHUB_BEFORE_SHA}"
      fi

      ValidateGitBeforeShaReference
      info "Successfully found GITHUB_BEFORE_SHA: ${GITHUB_BEFORE_SHA}"
    fi

    ############################
    # Validate we have a value #
    ############################
    if [ -z "${GITHUB_ORG}" ]; then
      error "Failed to get [GITHUB_ORG]!"
      fatal "[${GITHUB_ORG}]"
    else
      info "Successfully found GITHUB_ORG: ${GITHUB_ORG}"
    fi

    #######################
    # Get the GitHub Repo #
    #######################
    GITHUB_REPO=$(jq -r '.repository.name' <"${GITHUB_EVENT_PATH}")

    ############################
    # Validate we have a value #
    ############################
    if [ -z "${GITHUB_REPO}" ]; then
      error "Failed to get [GITHUB_REPO]!"
      fatal "[${GITHUB_REPO}]"
    else
      info "Successfully found GITHUB_REPO: ${GITHUB_REPO}"
    fi

    GITHUB_REPOSITORY_DEFAULT_BRANCH=$(GetGithubRepositoryDefaultBranch "${GITHUB_EVENT_PATH}")
  fi

  if [ -z "${GITHUB_REPOSITORY_DEFAULT_BRANCH}" ]; then
    fatal "Failed to get GITHUB_REPOSITORY_DEFAULT_BRANCH"
  else
    debug "Successfully detected the default branch for this repository: ${GITHUB_REPOSITORY_DEFAULT_BRANCH}"
  fi

  DEFAULT_BRANCH="${DEFAULT_BRANCH:-${GITHUB_REPOSITORY_DEFAULT_BRANCH}}"

  if [[ "${DEFAULT_BRANCH}" != "${GITHUB_REPOSITORY_DEFAULT_BRANCH}" ]]; then
    debug "The default branch for this repository was set to ${GITHUB_REPOSITORY_DEFAULT_BRANCH}, but it was explicitly overridden using the DEFAULT_BRANCH variable, and set to: ${DEFAULT_BRANCH}"
  fi
  info "The default branch for this repository is set to: ${DEFAULT_BRANCH}"

  if [ "${MULTI_STATUS}" == "true" ]; then

    if [[ ${RUN_LOCAL} == "true" ]]; then
      # Safety check. This shouldn't occur because we forcefully set MULTI_STATUS=false above
      # when RUN_LOCAL=true
      fatal "Cannot enable status reports when running locally."
    fi

    if [ -z "${GITHUB_TOKEN}" ]; then
      fatal "Failed to get [GITHUB_TOKEN]. Terminating because status reports were explicitly enabled, but GITHUB_TOKEN was not provided."
    else
      info "Successfully found GITHUB_TOKEN."
    fi

    if [ -z "${GITHUB_REPOSITORY}" ]; then
      error "Failed to get [GITHUB_REPOSITORY]!"
      fatal "[${GITHUB_REPOSITORY}]"
    else
      info "Successfully found GITHUB_REPOSITORY: ${GITHUB_REPOSITORY}"
    fi

    if [ -z "${GITHUB_RUN_ID}" ]; then
      error "Failed to get [GITHUB_RUN_ID]!"
      fatal "[${GITHUB_RUN_ID}]"
    else
      info "Successfully found GITHUB_RUN_ID ${GITHUB_RUN_ID}"
    fi
  else
    debug "Skip GITHUB_TOKEN, GITHUB_REPOSITORY, and GITHUB_RUN_ID validation because we don't need these variables for GitHub Actions status reports. MULTI_STATUS: ${MULTI_STATUS}"
  fi

  # We need this for parallel
  export GITHUB_WORKSPACE
}
################################################################################
#### Function CallStatusAPI ####################################################
CallStatusAPI() {
  ####################
  # Pull in the vars #
  ####################
  LANGUAGE="${1}" # language that was validated
  STATUS="${2}"   # success | error
  SUCCESS_MSG='No errors were found in the linting process'
  FAIL_MSG='Errors were detected, please view logs'
  MESSAGE='' # Message to send to status API

  debug "Calling Multi-Status API for $LANGUAGE with status $STATUS"

  ######################################
  # Check the status to create message #
  ######################################
  if [ "${STATUS}" == "success" ]; then
    # Success
    MESSAGE="${SUCCESS_MSG}"
  else
    # Failure
    MESSAGE="${FAIL_MSG}"
  fi

  ##########################################################
  # Check to see if were enabled for multi Status mesaages #
  ##########################################################
  if [ "${MULTI_STATUS}" == "true" ] && [ -n "${GITHUB_TOKEN}" ] && [ -n "${GITHUB_REPOSITORY}" ]; then

    # make sure we honor DISABLE_ERRORS
    if [ "${DISABLE_ERRORS}" == "true" ]; then
      STATUS="success"
    fi

    debug "Status URL: ${GITHUB_API_URL}/repos/${GITHUB_REPOSITORY}/statuses/${GITHUB_SHA}"

    ##############################################
    # Call the status API to create status check #
    ##############################################
    if ! SEND_STATUS_CMD=$(
      curl -f -s --show-error -X POST \
        --url "${GITHUB_API_URL}/repos/${GITHUB_REPOSITORY}/statuses/${GITHUB_SHA}" \
        -H 'accept: application/vnd.github.v3+json' \
        -H "authorization: Bearer ${GITHUB_TOKEN}" \
        -H 'content-type: application/json' \
        -d "{ \"state\": \"${STATUS}\",
        \"target_url\": \"https://${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}\",
        \"description\": \"${MESSAGE}\", \"context\": \"--> Linted: ${LANGUAGE}\"
      }" 2>&1
    ); then
      info "Failed to call GitHub Status API: ${SEND_STATUS_CMD}"
    fi
  fi
}

Footer() {
  info "----------------------------------------------"
  info "----------------------------------------------"

  local ANY_LINTER_SUCCESS
  ANY_LINTER_SUCCESS="false"

  local SUPER_LINTER_EXIT_CODE
  SUPER_LINTER_EXIT_CODE=0

  for LANGUAGE in "${LANGUAGE_ARRAY[@]}"; do
    # This used to be the count of errors found for a given LANGUAGE, but since
    # after we switched to running linters against a batch of files, it may not
    # represent the actual number of files that didn't pass the validation,
    # but a number that's less than that because of how GNU parallel returns
    # exit codes.
    # Ref: https://www.gnu.org/software/parallel/parallel.html#exit-status
    ERROR_COUNTER_FILE_PATH="/tmp/super-linter-parallel-command-exit-code-${LANGUAGE}"
    if [ ! -f "${ERROR_COUNTER_FILE_PATH}" ]; then
      debug "Error counter ${ERROR_COUNTER_FILE_PATH} doesn't exist"
    else
      ERROR_COUNTER=$(<"${ERROR_COUNTER_FILE_PATH}")
      debug "ERROR_COUNTER for ${LANGUAGE}: ${ERROR_COUNTER}"

      if [[ ${ERROR_COUNTER} -ne 0 ]]; then
        error "Errors found in ${LANGUAGE}"
        CallStatusAPI "${LANGUAGE}" "error"
        SUPER_LINTER_EXIT_CODE=1
        debug "Setting super-linter exit code to ${SUPER_LINTER_EXIT_CODE} because there were errors for ${LANGUAGE}"
      elif [[ ${ERROR_COUNTER} -eq 0 ]]; then
        notice "Successfully linted ${LANGUAGE}"
        CallStatusAPI "${LANGUAGE}" "success"
        ANY_LINTER_SUCCESS="true"
        debug "Set ANY_LINTER_SUCCESS to ${ANY_LINTER_SUCCESS} because ${LANGUAGE} reported a success"
      fi
    fi
  done

  if [[ "${ANY_LINTER_SUCCESS}" == "true" ]] && [[ ${SUPER_LINTER_EXIT_CODE} -ne 0 ]]; then
    SUPER_LINTER_EXIT_CODE=2
    debug "There was at least one linter that reported a success. Setting the super-linter exit code to: ${SUPER_LINTER_EXIT_CODE}"
  fi

  if [ "${DISABLE_ERRORS}" == "true" ]; then
    warn "The super-linter exit code is ${SUPER_LINTER_EXIT_CODE}. Forcibly setting it to 0 because DISABLE_ERRORS is set to: ${DISABLE_ERRORS}"
    SUPER_LINTER_EXIT_CODE=0
  fi

  if [[ ${SUPER_LINTER_EXIT_CODE} -eq 0 ]]; then
    notice "All files and directories linted successfully"
  else
    error "Super-linter detected linting errors"
  fi

  exit ${SUPER_LINTER_EXIT_CODE}
}
################################################################################
#### Function UpdateLoopsForImage ##############################################
UpdateLoopsForImage() {
  ######################################################################
  # Need to clean the array lists of the linters removed for the image #
  ######################################################################
  if [[ "${IMAGE}" == "slim" ]]; then
    #############################################
    # Need to remove linters for the slim image #
    #############################################
    REMOVE_ARRAY=("ARM" "CSHARP" "ENV" "POWERSHELL" "RUST_2015" "RUST_2018"
      "RUST_2021" "RUST_CLIPPY")

    # Remove from LANGUAGE_ARRAY
    debug "Removing Languages from LANGUAGE_ARRAY for slim image..."
    for REMOVE_LANGUAGE in "${REMOVE_ARRAY[@]}"; do
      for INDEX in "${!LANGUAGE_ARRAY[@]}"; do
        if [[ ${LANGUAGE_ARRAY[INDEX]} = "${REMOVE_LANGUAGE}" ]]; then
          debug "found item:[${REMOVE_LANGUAGE}], removing Language..."
          unset 'LANGUAGE_ARRAY[INDEX]'
        fi
      done
    done
  fi
}

# shellcheck disable=SC2317
cleanup() {
  local -ri EXIT_CODE=$?

  debug "Removing temporary files and directories"
  rm -rfv \
    "${GITHUB_WORKSPACE}/.mypy_cache" \
    "${GITHUB_WORKSPACE}/logback.log"

  if [ "${SUPER_LINTER_COPIED_R_LINTER_RULES_FILE}" == "true" ]; then
    debug "Deleting ${R_RULES_FILE_PATH_IN_ROOT} because super-linter created it."
    rm -rfv "${R_RULES_FILE_PATH_IN_ROOT}"
  fi

  # Define this variable here so we can rely on it as soon as possible
  local LOG_FILE_PATH="${GITHUB_WORKSPACE}/${LOG_FILE}"
  debug "LOG_FILE_PATH: ${LOG_FILE_PATH}"
  if [ "${CREATE_LOG_FILE}" = "true" ]; then
    debug "Moving log file from ${LOG_TEMP} to ${LOG_FILE_PATH}"
    mv \
      --force \
      --verbose \
      "${LOG_TEMP}" "${LOG_FILE_PATH}"
  else
    debug "Skipping the moving of the log file from ${LOG_TEMP} to ${LOG_FILE_PATH}"
  fi

  exit "${EXIT_CODE}"
  trap - 0 1 2 3 6 14 15
}
trap 'cleanup' 0 1 2 3 6 14 15

################################################################################
############################### MAIN ###########################################
################################################################################

##########
# Header #
##########
Header

############################################
# Create SSH agent and add key if provided #
############################################
SetupSshAgent
SetupGithubComSshKeys

################################################
# Need to update the loops for the image style #
################################################
UpdateLoopsForImage

if ! cat "${VERSION_FILE}"; then
  fatal "Failed to view version file: ${VERSION_FILE}"
fi

#######################
# Get GitHub Env Vars #
#######################
# Need to pull in all the GitHub variables
# needed to connect back and update checks
GetGitHubVars

# Ensure that Git safe directories are configured because we don't do this in
# all cases when initializing variables
ConfigureGitSafeDirectories

########################################################
# Initialize variables that depend on GitHub variables #
########################################################
TYPESCRIPT_STANDARD_TSCONFIG_FILE="${GITHUB_WORKSPACE}/${TYPESCRIPT_STANDARD_TSCONFIG_FILE:-"tsconfig.json"}"
debug "TYPESCRIPT_STANDARD_TSCONFIG_FILE: ${TYPESCRIPT_STANDARD_TSCONFIG_FILE}"

R_RULES_FILE_PATH_IN_ROOT="${GITHUB_WORKSPACE}/${R_FILE_NAME}"
debug "R_RULES_FILE_PATH_IN_ROOT: ${R_RULES_FILE_PATH_IN_ROOT}"

############################
# Validate the environment #
############################
GetValidationInfo

if [[ "${USE_FIND_ALGORITHM}" == "false" ]] || [[ "${IGNORE_GITIGNORED_FILES}" == "true" ]]; then
  debug "Validate the local Git environment"
  ValidateLocalGitRepository
  ValidateGitShaReference
  ValidateDefaultGitBranch
else
  debug "Skipped the validation of the local Git environment because we don't depend on it."
fi

ValidateDeprecatedVariables

#################################
# Get the linter rules location #
#################################
LinterRulesLocation

########################
# Get the linter rules #
########################
LANGUAGE_ARRAY_FOR_LINTER_RULES=("${LANGUAGE_ARRAY[@]}" "TYPESCRIPT_STANDARD_TSCONFIG")

for LANGUAGE in "${LANGUAGE_ARRAY_FOR_LINTER_RULES[@]}"; do
  debug "Loading rules for ${LANGUAGE}..."
  eval "GetLinterRules ${LANGUAGE} ${DEFAULT_RULES_LOCATION}"
done

# Load rules for special cases
GetStandardRules "javascript"

#################################
# Check for SSL cert and update #
#################################
CheckSSLCert

###########################################
# Build the list of files for each linter #
###########################################
BuildFileList "${VALIDATE_ALL_CODEBASE}" "${TEST_CASE_RUN}"

#####################################
# Run additional Installs as needed #
#####################################
RunAdditionalInstalls

####################################
# Print ENV before running linters #
####################################
debug "--- ENV (before running linters) ---"
debug "------------------------------------"
debug "ENV:"
debug "$(printenv)"
debug "------------------------------------"

endGitHubActionsLogGroup "${SUPER_LINTER_INITIALIZATION_LOG_GROUP_TITLE}"

###############
# Run linters #
###############
declare PARALLEL_RESULTS_FILE_PATH
PARALLEL_RESULTS_FILE_PATH="/tmp/super-linter-results.json"
debug "PARALLEL_RESULTS_FILE_PATH: ${PARALLEL_RESULTS_FILE_PATH}"

declare -a PARALLEL_COMMAND
PARALLEL_COMMAND=(parallel --will-cite --keep-order --max-procs "$(($(nproc) * 1))" --xargs --results "${PARALLEL_RESULTS_FILE_PATH}")

# Run one LANGUAGE per process. Each of these processes will run more processees in parellel if supported
PARALLEL_COMMAND+=(--max-lines 1)

if [ "${LOG_DEBUG}" == "true" ]; then
  debug "LOG_DEBUG is enabled. Enable verbose ouput for parallel"
  PARALLEL_COMMAND+=(--verbose)
fi

PARALLEL_COMMAND+=("LintCodebase" "{}" "\"${TEST_CASE_RUN}\"")
debug "PARALLEL_COMMAND: ${PARALLEL_COMMAND[*]}"

PARALLEL_COMMAND_OUTPUT=$(printf "%s\n" "${LANGUAGE_ARRAY[@]}" | "${PARALLEL_COMMAND[@]}" 2>&1)
PARALLEL_COMMAND_RETURN_CODE=$?
debug "PARALLEL_COMMAND_OUTPUT when running linters (exit code: ${PARALLEL_COMMAND_RETURN_CODE}):\n${PARALLEL_COMMAND_OUTPUT}"
debug "Parallel output file (${PARALLEL_RESULTS_FILE_PATH}) contents when running linters:\n$(cat "${PARALLEL_RESULTS_FILE_PATH}")"

RESULTS_OBJECT=
if ! RESULTS_OBJECT=$(jq --raw-output -n '[inputs]' "${PARALLEL_RESULTS_FILE_PATH}"); then
  fatal "Error loading results when building the file list: ${RESULTS_OBJECT}"
fi
debug "RESULTS_OBJECT when running linters:\n${RESULTS_OBJECT}"

# Get raw output so we can strip quotes from the data we load. Also, strip the final newline to avoid adding it two times
if ! STDOUT_LINTERS="$(jq --raw-output '.[] | select(.Stdout[:-1] | length > 0) | .Stdout[:-1]' <<<"${RESULTS_OBJECT}")"; then
  fatal "Error when loading stdout when running linters:\n${STDOUT_LINTERS}"
fi

if [ -n "${STDOUT_LINTERS}" ]; then
  info "Command output when running linters:\n------\n${STDOUT_LINTERS}\n------"
else
  debug "Stdout when running linters is empty"
fi

if ! STDERR_LINTERS="$(jq --raw-output '.[] | select(.Stderr[:-1] | length > 0) | .Stderr[:-1]' <<<"${RESULTS_OBJECT}")"; then
  fatal "Error when loading stderr for ${FILE_TYPE}:\n${STDERR_LINTERS}"
fi

if [ -n "${STDERR_LINTERS}" ]; then
  info "Stderr when running linters:\n------\n${STDERR_LINTERS}\n------"
else
  debug "Stderr when running linters is empty"
fi

if [[ ${PARALLEL_COMMAND_RETURN_CODE} -ne 0 ]]; then
  fatal "Error when running linters. Exit code: ${PARALLEL_COMMAND_RETURN_CODE}"
fi

##########
# Footer #
##########
Footer
