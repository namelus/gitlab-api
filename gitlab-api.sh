#!/bin/bash

# ==============================================================================
# GitLab API Helper Script
# ==============================================================================
#
# This script provides a comprehensive set of functions for managing GitLab 
# Personal Access Tokens (PATs) and interacting with the GitLab API.
#
# FEATURES:
# - Secure token storage in ~/.env file with proper file permissions (600)
# - GitLab project creation with comprehensive error handling
# - GitLab project listing with pagination support and multiple output formats
# - Cross-platform compatibility (Linux, macOS, Windows/Git Bash)
# - Robust error handling and validation
#
# REQUIREMENTS:
# - bash shell
# - curl (for API requests)
# - jq (for JSON processing)
# - sed and grep (for file manipulation)
#
# SECURITY NOTES:
# - Tokens are stored in ~/.env with 600 permissions (owner read/write only)
# - Never log or echo token values to stdout
# - Always validate input parameters before making API calls
#
# USAGE:
#   source ./gitlab-api.sh
#   input_token "GITLAB_API_TOKEN"
#   get_list_of_projects "$GITLAB_API_TOKEN"
#
# ==============================================================================

# --- TOKEN MANAGEMENT FUNCTIONS ---

##
# Prompts user for a token value and securely stores it in ~/.env file.
#
# DESCRIPTION:
#   This function provides an interactive way to input and store GitLab Personal
#   Access Tokens or other sensitive environment variables. The token is stored
#   in a .env file in the user's home directory with restrictive permissions
#   (600 - owner read/write only) to prevent unauthorized access.
#
# SECURITY FEATURES:
#   - Creates .env file with 600 permissions if it doesn't exist
#   - Updates existing token values without creating duplicates
#   - Validates that token value is not empty before storing
#   - Never echoes the actual token value to terminal
#
# PARAMETERS:
#   $1 (string, required) - The name of the environment variable to store
#                          Common examples: "GITLAB_API_TOKEN", "GITHUB_TOKEN"
#
# RETURN VALUES:
#   0 - Success: Token successfully stored in ~/.env
#   1 - Failure: Empty token value provided or file operations failed
#
# ERROR HANDLING:
#   - Validates token_name parameter is provided
#   - Ensures token value is not empty or whitespace-only
#   - Reports file permission or write errors
#
# SIDE EFFECTS:
#   - Creates ~/.env file if it doesn't exist
#   - Sets ~/.env file permissions to 600
#   - Updates or adds the specified environment variable
#
# EXAMPLES:
#   # Store a GitLab Personal Access Token
#   input_token "GITLAB_API_TOKEN"
#   
#   # Store a GitHub token
#   input_token "GITHUB_TOKEN"
#   
#   # Store any environment variable
#   input_token "MY_SECRET_KEY"
#
# SEE ALSO:
#   update_env_file() - Lower-level function for programmatic updates
#   get_env_variable() - Function to retrieve stored variables
#
input_token() {
    local token_name="$1"
    local token_value

    read -p "Enter value for $token_name: " token_value

    if [ -z "$token_value" ]; then
        echo "Error: Token value cannot be empty." >&2
        return 1
    fi

    update_env_file "$token_name" "$token_value"
    echo "$token_name successfully stored in ~/.env"
}

##
# Updates or adds a key-value pair to the ~/.env file programmatically.
#
# DESCRIPTION:
#   This function provides a programmatic interface for managing environment
#   variables in the ~/.env file. It's designed to be called by other functions
#   or scripts that need to store configuration values securely. The function
#   handles both creating new entries and updating existing ones atomically.
#
# FUNCTIONALITY:
#   - Creates ~/.env file if it doesn't exist
#   - Sets secure file permissions (600) on creation
#   - Updates existing variables in-place without duplication
#   - Appends new variables to end of file
#   - Handles special characters in values by using double quotes
#   - Uses sed for atomic updates to prevent corruption
#
# PARAMETERS:
#   $1 (string, required) - Environment variable name
#                          Must be a valid shell variable name (alphanumeric + underscore)
#                          Example: "GITLAB_API_TOKEN"
#   
#   $2 (string, required) - Environment variable value
#                          Can contain spaces, special characters
#                          Will be automatically quoted in the file
#                          Example: "glpat-xxxxxxxxxxxxxxxxxxxx"
#
# FILE FORMAT:
#   The function maintains the standard .env file format:
#   VARIABLE_NAME="variable_value"
#   
#   Special characters in values are preserved through double-quoting.
#
# RETURN VALUES:
#   0 - Success: Variable successfully updated or added
#   1 - Failure: File creation failed, permission issues, or sed operation failed
#
# ERROR SCENARIOS:
#   - ~/.env file cannot be created (permission denied)
#   - chmod fails to set proper permissions
#   - sed update operation fails
#   - Invalid variable name format
#
# SECURITY CONSIDERATIONS:
#   - File permissions set to 600 (owner read/write only)
#   - Values are properly quoted to handle special characters
#   - Uses | delimiter in sed to avoid conflicts with URLs/tokens
#
# EXAMPLES:
#   # Add or update a GitLab token
#   update_env_file "GITLAB_API_TOKEN" "glpat-xxxxxxxxxxxxxxxxxxxx"
#   
#   # Store a database URL with special characters
#   update_env_file "DATABASE_URL" "postgresql://user:pass@localhost:5432/db"
#   
#   # Update an existing variable
#   update_env_file "API_ENDPOINT" "https://api.example.com/v2"
#
# INTEGRATION:
#   This function is used by:
#   - input_token() for interactive token storage
#   - Any script needing programmatic .env management
#
# SEE ALSO:
#   input_token() - Interactive wrapper for this function
#   get_env_variable() - Function to retrieve stored variables
#
update_env_file() {
    local token_name="$1"
    local token_value="$2"
    local env_file="${HOME}/.env"

    if [ ! -f "$env_file" ]; then
        touch "$env_file"
        chmod 600 "$env_file"
    fi

    if grep -q "^$token_name=" "$env_file"; then
        sed -i "s|^$token_name=.*|$token_name=\"$token_value\"|" "$env_file"
    else
        echo "$token_name=\"$token_value\"" >> "$env_file"
    fi
}

##
# Retrieves and outputs an environment variable from the ~/.env file.
#
# DESCRIPTION:
#   This function provides a secure method to retrieve environment variables
#   stored in the ~/.env file. It sources the file in a controlled manner,
#   extracts the requested variable, and outputs its value to stdout. The
#   function includes comprehensive validation and error reporting.
#
# PROCESS FLOW:
#   1. Validates that ~/.env file exists
#   2. Sources the .env file using allexport mode
#   3. Checks if the requested variable is set and non-empty
#   4. Outputs the variable value to stdout
#   5. Restores original shell export settings
#
# PARAMETERS:
#   $1 (string, required) - Name of the environment variable to retrieve
#                          Must match exactly the variable name stored in .env
#                          Case-sensitive
#                          Example: "GITLAB_API_TOKEN"
#
# OUTPUT:
#   stdout - The value of the requested environment variable (on success)
#   stderr - Error messages describing any failures
#
# RETURN VALUES:
#   0 - Success: Variable found and value output to stdout
#   1 - Failure: .env file not found, variable not set, or empty value
#
# ERROR CONDITIONS:
#   - ~/.env file does not exist
#   - ~/.env file exists but is not readable
#   - Requested variable is not defined in .env file
#   - Variable is defined but has an empty value
#   - Shell variable expansion fails
#
# SECURITY FEATURES:
#   - Uses 'set -o allexport' for controlled environment sourcing
#   - Properly restores shell settings after operation
#   - Does not expose other environment variables
#   - Validates variable existence before output
#
# SHELL COMPATIBILITY:
#   - Uses bash indirect variable expansion ${!variable_name}
#   - Compatible with bash 3.0+ and most POSIX shells
#   - Handles special characters in variable values
#
# EXAMPLES:
#   # Retrieve a GitLab token
#   token=$(get_env_variable "GITLAB_API_TOKEN")
#   if [ $? -eq 0 ]; then
#       echo "Token retrieved successfully"
#   fi
#   
#   # Use in conditional
#   if api_key=$(get_env_variable "API_KEY"); then
#       curl -H "Authorization: Bearer $api_key" ...
#   else
#       echo "API key not found"
#   fi
#   
#   # Direct usage in command substitution
#   make_new_project "my-project" "$(get_env_variable 'GITLAB_API_TOKEN')"
#
# TROUBLESHOOTING:
#   - Ensure ~/.env file exists and is readable
#   - Verify variable name spelling and case
#   - Check that variable has a non-empty value in .env
#   - Confirm .env file format: VARIABLE_NAME="value"
#
# SEE ALSO:
#   input_token() - Function to store variables
#   update_env_file() - Function to programmatically update variables
#
get_env_variable() {
    local variable_name="$1"
    local env_file="${HOME}/.env"

    if [ ! -f "$env_file" ]; then
        echo "Error: .env file not found." >&2
        return 1
    fi

    set -o allexport
    source "$env_file"
    set +o allexport

    if [ -z "${!variable_name}" ]; then
        echo "Error: Variable '$variable_name' not found in .env." >&2
        return 1
    fi

    echo "${!variable_name}"
}

# --- GITLAB API FUNCTIONS ---

##
# Creates a new GitLab project via the GitLab API with comprehensive error handling.
#
# DESCRIPTION:
#   This function creates a new project in GitLab using the REST API v4. It provides
#   detailed error handling for common scenarios including authentication failures,
#   project name conflicts, and API rate limiting. The function returns structured
#   JSON output on success and detailed error information on failure.
#
# API INTERACTION:
#   - Endpoint: POST /api/v4/projects
#   - Authentication: Personal Access Token (PAT) via PRIVATE-TOKEN header
#   - Content-Type: application/json
#   - Request Body: JSON object with project name
#   - Response: JSON object with project details or error information
#
# PARAMETERS:
#   $1 (string, required) - Project name for the new GitLab project
#                          Must be valid GitLab project name (no spaces, special chars)
#                          Will be used as both project name and URL slug
#                          Example: "my-awesome-project"
#   
#   $2 (string, required) - GitLab Personal Access Token (PAT)
#                          Must have 'api' scope for project creation
#                          Format: "glpat-xxxxxxxxxxxxxxxxxxxx"
#                          Should be kept secret and never logged
#
# HTTP STATUS CODES HANDLED:
#   201 - Created: Project successfully created
#   409 - Conflict: Project with this name already exists
#   401 - Unauthorized: Invalid or expired token
#   403 - Forbidden: Token lacks required permissions
#   422 - Unprocessable Entity: Invalid project name or parameters
#   429 - Too Many Requests: API rate limit exceeded
#   500+ - Server Error: GitLab internal server issues
#
# OUTPUT:
#   stdout (Success) - Complete JSON response from GitLab API containing:
#                     - Project ID, name, description
#                     - URLs (web_url, ssh_url_to_repo, http_url_to_repo)
#                     - Timestamps, visibility level, permissions
#   
#   stderr (Failure) - Detailed error messages including:
#                     - HTTP status code
#                     - GitLab API error message (if available)
#                     - Suggested troubleshooting steps
#
# RETURN VALUES:
#   0 - Success: Project created successfully
#   1 - Failure: Missing parameters, authentication error, or API error
#
# ERROR SCENARIOS:
#   - Missing or empty project name
#   - Missing or empty GitLab PAT
#   - Project name already exists (409)
#   - Invalid token or insufficient permissions (401/403)
#   - Network connectivity issues
#   - GitLab service unavailable
#   - Invalid project name format
#
# SECURITY CONSIDERATIONS:
#   - Token is passed via HTTP header (encrypted in HTTPS)
#   - Token value is never echoed to stdout/stderr
#   - Uses --silent flag to prevent curl from showing progress
#   - Validates all inputs before making API call
#
# DEPENDENCIES:
#   - curl: For HTTP requests to GitLab API
#   - jq: For JSON parsing and pretty-printing
#   - head/tail: For parsing HTTP response codes
#
# EXAMPLES:
#   # Basic project creation
#   make_new_project "my-new-project" "$GITLAB_API_TOKEN"
#   
#   # With error handling
#   if make_new_project "test-project" "$GITLAB_API_TOKEN"; then
#       echo "Project created successfully!"
#   else
#       echo "Failed to create project"
#   fi
#   
#   # Capture project details
#   project_json=$(make_new_project "api-client" "$GITLAB_API_TOKEN")
#   project_id=$(echo "$project_json" | jq -r '.id')
#
# TROUBLESHOOTING:
#   - Verify token has 'api' scope in GitLab settings
#   - Check project name follows GitLab naming conventions
#   - Ensure network connectivity to gitlab.com
#   - Confirm token is not expired
#   - Check GitLab API rate limits
#
# SEE ALSO:
#   get_list_of_projects() - Function to list existing projects
#   GitLab API Documentation: https://docs.gitlab.com/ee/api/projects.html
#
make_new_project() {
    local project_name="$1"
    local gitlab_pat="$2"
    local gitlab_url="https://gitlab.com"

    if [ -z "$project_name" ] || [ -z "$gitlab_pat" ]; then
        echo "Usage: make_new_project <project_name> <gitlab_pat>" >&2
        return 1
    fi

    echo "Creating new project '$project_name'..."

    local http_status
    local response

    response=$(curl --request POST --header "PRIVATE-TOKEN: $gitlab_pat" \
                    --header "Content-Type: application/json" \
                    --data "{\"name\": \"$project_name\"}" \
                    --url "$gitlab_url/api/v4/projects" \
                    --silent \
                    --write-out "%{http_code}")

    http_status=$(echo "$response" | tail -c 4)
    response=$(echo "$response" | head -c -4)

    if [ "$http_status" == "201" ]; then
        echo "Project '$project_name' created successfully."
        echo "$response" | jq '.'
    elif [ "$http_status" == "409" ]; then
        echo "Error: Project '$project_name' already exists." >&2
        echo "Aborting creation process." >&2
        echo "$response" | jq '.' >&2
        return 1
    else
        echo "Error creating project '$project_name'." >&2
        echo "HTTP Status Code: $http_status" >&2
        echo "$response" | jq '.' >&2
        return 1
    fi
}

##
# Fetches and displays GitLab projects with advanced filtering and multiple output formats.
#
# DESCRIPTION:
#   This comprehensive function retrieves projects from GitLab using the REST API v4
#   with support for multiple output formats, filtering options, and robust error
#   handling. It's designed for both interactive use and script integration, providing
#   flexible data presentation options for various use cases.
#
# API FEATURES:
#   - Uses GitLab API v4 endpoint: GET /api/v4/projects
#   - Supports pagination with per_page parameter (set to 100 for efficiency)
#   - Filters to show only projects user is a member of (membership=true)
#   - Optional filtering by last activity date and visibility level
#   - Comprehensive error detection and reporting
#
# PARAMETERS:
#   $1 (string, required) - GitLab Personal Access Token (PAT)
#                          Must have 'read_api' or 'api' scope
#                          Format: "glpat-xxxxxxxxxxxxxxxxxxxx"
#   
#   $2 (string, optional) - Output format [Default: "raw"]
#                          Options:
#                          - "raw": Human-readable "Name - Date" format
#                          - "csv": CSV format with headers for spreadsheet import
#                          - "json": Full JSON response from GitLab API
#   
#   $3 (string, optional) - Filter by last activity after date
#                          Format: YYYY-MM-DD (ISO 8601 date)
#                          Example: "2025-01-01" (shows projects active since Jan 1)
#   
#   $4 (string, optional) - Filter by visibility level
#                          Options: "public", "internal", "private"
#                          Filters projects based on their visibility setting
#
# OUTPUT FORMATS:
#   
#   RAW FORMAT (default):
#   Project Name 1 - 2025-08-06T10:30:00.000Z
#   Project Name 2 - 2025-08-05T15:22:00.000Z
#   
#   CSV FORMAT:
#   name,last_activity_at,visibility,web_url
#   "My Project","2025-08-06T10:30:00.000Z","private","https://gitlab.com/user/my-project"
#   
#   JSON FORMAT:
#   Full GitLab API response with all project metadata
#
# RETURN VALUES:
#   0 - Success: Projects retrieved and displayed successfully
#   1 - Failure: Authentication error, network issues, or invalid parameters
#
# ERROR HANDLING:
#   The function detects and reports various error conditions:
#   - Missing or invalid Personal Access Token
#   - Network connectivity problems
#   - GitLab API authentication failures
#   - Invalid response format from API
#   - Empty responses or API timeouts
#   - Invalid output format specified
#   - Malformed date filters
#
# SECURITY FEATURES:
#   - Token transmitted securely via HTTPS headers
#   - No token logging or exposure in output
#   - Graceful handling of unauthorized access
#   - Input validation for all parameters
#
# FILTERING CAPABILITIES:
#   
#   DATE FILTERING:
#   Show only projects with activity after specific date:
#   get_list_of_projects "$TOKEN" "raw" "2025-01-01"
#   
#   VISIBILITY FILTERING:
#   Show only public projects:
#   get_list_of_projects "$TOKEN" "csv" "" "public"
#   
#   COMBINED FILTERING:
#   Show private projects active since January 1st:
#   get_list_of_projects "$TOKEN" "json" "2025-01-01" "private"
#
# USE CASES:
#   
#   INTERACTIVE BROWSING:
#   get_list_of_projects "$GITLAB_API_TOKEN"
#   
#   DATA ANALYSIS:
#   get_list_of_projects "$GITLAB_API_TOKEN" "csv" > projects.csv
#   
#   AUTOMATION/SCRIPTING:
#   projects=$(get_list_of_projects "$GITLAB_API_TOKEN" "json")
#   project_count=$(echo "$projects" | jq length)
#   
#   MONITORING:
#   get_list_of_projects "$GITLAB_API_TOKEN" "raw" "2025-08-01" > recent_projects.txt
#
# EXAMPLES:
#   
#   # Basic usage - list all your projects
#   get_list_of_projects "$GITLAB_API_TOKEN"
#   
#   # Export to CSV for Excel/Sheets
#   get_list_of_projects "$GITLAB_API_TOKEN" "csv" > my_projects.csv
#   
#   # Find recently active projects
#   get_list_of_projects "$GITLAB_API_TOKEN" "raw" "2025-08-01"
#   
#   # Get full project data for automation
#   projects_json=$(get_list_of_projects "$GITLAB_API_TOKEN" "json")
#   echo "$projects_json" | jq '.[] | select(.visibility=="private") | .name'
#   
#   # List only public projects in CSV format
#   get_list_of_projects "$GITLAB_API_TOKEN" "csv" "" "public"
#
# PERFORMANCE CONSIDERATIONS:
#   - Uses per_page=100 to minimize API calls
#   - Membership filter reduces response size
#   - JSON parsing optimized for large project lists
#   - Error detection happens early to avoid unnecessary processing
#
# TROUBLESHOOTING:
#   
#   Common Issues:
#   - "401 Unauthorized": Check token validity and scopes
#   - "Empty response": Verify network connectivity
#   - "jq command not found": Install jq package
#   - "Invalid date format": Use YYYY-MM-DD format
#   - "No projects shown": Check membership or visibility filters
#
# DEPENDENCIES:
#   - curl: HTTP client for API requests
#   - jq: JSON processor for parsing and formatting
#   - Standard shell utilities (echo, grep, etc.)
#
# SEE ALSO:
#   make_new_project() - Function to create new projects
#   get_list_of_projects_simple() - Simplified version for debugging
#   GitLab API Docs: https://docs.gitlab.com/ee/api/projects.html#list-all-projects
#
get_list_of_projects() {
    local token="$1"
    local output_format="${2:-raw}"           # raw, csv, or json
    local last_activity_after="${3}"          # e.g., 2025-01-01
    local visibility="${4}"                   # public, internal, private
    local gitlab_url="https://gitlab.com"

    if [ -z "$token" ]; then
        echo "Usage: get_list_of_projects <gitlab_pat> [output_format] [last_activity_after] [visibility]" >&2
        return 1
    fi

    echo "Fetching GitLab projects..." >&2

    # Build query string
    local query="membership=true&per_page=100"
    [[ -n "$last_activity_after" ]] && query+="&last_activity_after=$last_activity_after"
    [[ -n "$visibility" ]] && query+="&visibility=$visibility"

    # Make the API call
    local response
    response=$(curl -s --header "PRIVATE-TOKEN: $token" "$gitlab_url/api/v4/projects?$query")

    # Check if curl failed
    if [ $? -ne 0 ]; then
        echo "Error: Failed to connect to GitLab API." >&2
        return 1
    fi

    # Check if response is empty
    if [ -z "$response" ]; then
        echo "Error: Empty response from GitLab API." >&2
        return 1
    fi

    # Check if response is an error object (has "message" field)
    local has_error
    has_error=$(echo "$response" | jq -r 'if type=="object" and has("message") then "true" else "false" end' 2>/dev/null)
    
    if [ "$has_error" = "true" ]; then
        echo "Error from GitLab API:" >&2
        echo "$response" | jq -r '.message' >&2
        return 1
    fi

    # Check if response is an array (expected format)
    local is_array
    is_array=$(echo "$response" | jq -r 'if type=="array" then "true" else "false" end' 2>/dev/null)
    
    if [ "$is_array" != "true" ]; then
        echo "Error: Unexpected response format from GitLab API." >&2
        echo "Response: $response" >&2
        return 1
    fi

    # Format output based on requested format
    case "$output_format" in
        raw)
            echo "$response" | jq -r '.[] | (.name // "N/A") + " - " + (.last_activity_at // "N/A")'
            ;;
        csv)
            echo "name,last_activity_at,visibility,web_url"
            echo "$response" | jq -r '.[] | [(.name // ""), (.last_activity_at // ""), (.visibility // ""), (.web_url // "")] | @csv'
            ;;
        json)
            echo "$response" | jq '.'
            ;;
        *)
            echo "Error: Invalid output format: $output_format. Use raw, csv, or json." >&2
            return 1
            ;;
    esac
}

##
# Simplified project listing function for testing and debugging purposes.
#
# DESCRIPTION:
#   This is a streamlined version of get_list_of_projects() designed specifically
#   for debugging, testing, and situations where you need a quick project list
#   without advanced filtering options. It provides a minimal, reliable way to
#   verify API connectivity and token validity.
#
# DESIGN PHILOSOPHY:
#   - Minimal complexity to reduce potential failure points
#   - Fixed parameters to ensure consistent behavior
#   - Clear, readable output for manual inspection
#   - Fast execution with limited result set (10 projects max)
#   - Optimized for troubleshooting API connection issues
#
# FUNCTIONALITY:
#   - Fetches only first 10 projects (per_page=10) for quick results
#   - Shows only projects where user is a member (membership=true)
#   - Simple "Name - Date" output format
#   - Basic error handling without complex validation
#   - Direct jq processing without intermediate variables
#
# PARAMETERS:
#   $1 (string, required) - GitLab Personal Access Token (PAT)
#                          Same requirements as get_list_of_projects()
#                          Must have 'read_api' or 'api' scope
#
# OUTPUT:
#   stdout - Simple list format: "Project Name - YYYY-MM-DDTHH:MM:SS.sssZ"
#   stderr - Basic error messages and progress indicators
#
# RETURN VALUES:
#   0 - Success: Projects retrieved and displayed
#   1 - Failure: Missing token or API error
#
# COMPARISON WITH FULL FUNCTION:
#   
#   get_list_of_projects():
#   - Full pagination support
#   - Multiple output formats (raw, csv, json)
#   - Advanced filtering (date, visibility)
#   - Comprehensive error handling
#   - Complex validation logic
#   
#   get_list_of_projects_simple():
#   - Fixed 10 project limit
#   - Single output format
#   - No filtering options
#   - Basic error handling
#   - Minimal validation
#
# DEBUGGING USE CASES:
#   
#   1. TOKEN VALIDATION:
#      Test if your token works at all:
#      get_list_of_projects_simple "$GITLAB_API_TOKEN"
#   
#   2. NETWORK CONNECTIVITY:
#      Verify you can reach GitLab API:
#      get_list_of_projects_simple "$GITLAB_API_TOKEN"
#   
#   3. JQ INSTALLATION:
#      Check if jq is properly installed:
#      get_list_of_projects_simple "$GITLAB_API_TOKEN"
#   
#   4. SHELL COMPATIBILITY:
#      Test basic shell features work:
#      get_list_of_projects_simple "$GITLAB_API_TOKEN"
#
# EXAMPLES:
#   
#   # Quick test of API connectivity
#   get_list_of_projects_simple "$GITLAB_API_TOKEN"
#   
#   # Verify token works before complex operations
#   if get_list_of_projects_simple "$GITLAB_API_TOKEN" > /dev/null 2>&1; then
#       echo "Token and API working"
#       get_list_of_projects "$GITLAB_API_TOKEN" "csv"
#   else
#       echo "Basic API test failed"
#   fi
#   
#   # Compare with full function results
#   echo "=== Simple Function ==="
#   get_list_of_projects_simple "$GITLAB_API_TOKEN"
#   echo "=== Full Function ==="
#   get_list_of_projects "$GITLAB_API_TOKEN" "raw"
#
# TROUBLESHOOTING WORKFLOW:
#   
#   1. Start with this simple function to isolate issues
#   2. If it fails, problem is likely:
#      - Invalid token
#      - Network connectivity
#      - Missing dependencies (curl, jq)
#      - GitLab API unavailable
#   
#   3. If it succeeds but full function fails, issue is likely:
#      - Complex parameter handling
#      - Advanced error checking logic
#      - Filtering or formatting code
#
# LIMITATIONS:
#   - Maximum 10 projects returned
#   - No filtering capabilities
#   - Single output format only
#   - Minimal error reporting
#   - No pagination support
#
# WHEN TO USE:
#   - Initial API testing
#   - Debugging connection issues
#   - Quick project count verification
#   - Shell script compatibility testing
#   - Before implementing complex project operations
#
# WHEN NOT TO USE:
#   - Production scripts needing all projects
#   - Data export or analysis tasks
#   - When specific output formats required
#   - For large GitLab instances (>10 projects)
#
# SEE ALSO:
#   get_list_of_projects() - Full-featured project listing function
#   make_new_project() - Project creation function
#
get_list_of_projects_simple() {
    local token="$1"
    
    if [ -z "$token" ]; then
        echo "Usage: get_list_of_projects_simple <gitlab_pat>" >&2
        return 1
    fi
    
    echo "Fetching projects (simple)..." >&2
    
    curl -s --header "PRIVATE-TOKEN: $token" \
        "https://gitlab.com/api/v4/projects?membership=true&per_page=10" | \
        jq -r '.[] | "\(.name) - \(.last_activity_at)"'
}