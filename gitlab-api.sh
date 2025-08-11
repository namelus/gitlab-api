#!/bin/bash

# ==============================================================================
# GitLab API Helper Script - Enhanced Version
# ==============================================================================
#
# This script provides a comprehensive set of functions for managing GitLab 
# Personal Access Tokens (PATs) and interacting with the GitLab API.
#
# FEATURES:
# - Smart token management with review and selection capabilities
# - Secure token storage in ~/.env file with proper file permissions (600)
# - GitLab project creation with comprehensive error handling
# - GitLab project listing with pagination support and multiple output formats
# - Complete project member management (add, list, remove)
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
# QUICK START:
#   source ./gitlab-api.sh
#   manage_project_members    # Complete interactive workflow
#
# ==============================================================================

# --- ENHANCED TOKEN MANAGEMENT FUNCTIONS ---

##
# Lists all GitLab tokens found in ~/.env file that match GITLAB_*_TOKEN pattern.
#
# DESCRIPTION:
#   This function searches the ~/.env file for environment variables that follow
#   the GitLab token naming pattern: GITLAB_*_TOKEN (e.g., GITLAB_API_TOKEN, 
#   GITLAB_GMAIL_API_TOKEN, etc.). It displays them in a user-friendly format
#   without exposing the actual token values for security.
#
# PATTERN MATCHING:
#   - Prefix: GITLAB_
#   - Suffix: _TOKEN  
#   - Examples: GITLAB_API_TOKEN, GITLAB_GMAIL_API_TOKEN, GITLAB_PROD_TOKEN
#
# OUTPUT:
#   stdout - List of token names with preview (first 10 chars + "...")
#   stderr - Error messages if .env file issues
#
# RETURN VALUES:
#   0 - Success: Tokens found and displayed
#   1 - Failure: No .env file or no GitLab tokens found
#
# SECURITY FEATURES:
#   - Never displays full token values
#   - Shows only first 10 characters for identification
#   - Maintains token confidentiality while allowing selection
#
list_gitlab_tokens() {
    local env_file="${HOME}/.env"
    local count=0
    
    if [ ! -f "$env_file" ]; then
        echo "Error: .env file not found at $env_file" >&2
        return 1
    fi
    
    echo "🔍 Searching for GitLab tokens in ~/.env..."
    echo
    
    # Find all lines that match GITLAB_*_TOKEN pattern
    local gitlab_tokens
    gitlab_tokens=$(grep -E '^GITLAB_.*_TOKEN=' "$env_file" 2>/dev/null)
    
    if [ -z "$gitlab_tokens" ]; then
        echo "❌ No GitLab tokens found matching pattern GITLAB_*_TOKEN"
        echo
        echo "💡 GitLab token naming convention:"
        echo "   GITLAB_API_TOKEN      - General API access"
        echo "   GITLAB_GMAIL_API_TOKEN - Gmail integration"
        echo "   GITLAB_PROD_TOKEN     - Production environment"
        echo "   GITLAB_DEV_TOKEN      - Development environment"
        echo
        return 1
    fi
    
    echo "✅ Found GitLab tokens:"
    echo
    
    # Process each token and display with preview
    while IFS='=' read -r token_name token_value; do
        if [ -n "$token_name" ] && [ -n "$token_value" ]; then
            ((count++))
            
            # Remove quotes from token value if present
            token_value=$(echo "$token_value" | sed 's/^"//; s/"$//')
            
            # Create preview (first 10 chars + ...)
            local preview="${token_value:0:10}..."
            
            # Generate description based on token name
            local description
            case "$token_name" in
                *API_TOKEN) description="(General API access)" ;;
                *GMAIL*) description="(Gmail integration)" ;;
                *PROD*) description="(Production environment)" ;;
                *DEV*) description="(Development environment)" ;;
                *TEST*) description="(Testing environment)" ;;
                *STAGING*) description="(Staging environment)" ;;
                *) description="(Custom token)" ;;
            esac
            
            printf "%2d) %-25s - %s %s\n" "$count" "$token_name" "$preview" "$description"
        fi
    done <<< "$gitlab_tokens"
    
    echo
    echo "📝 Total: $count GitLab token(s) found"
    
    return 0
}

##
# Interactive function to select a GitLab token from available options.
#
# DESCRIPTION:
#   This function presents the user with a menu of available GitLab tokens
#   and allows them to select one for use. It combines the functionality of
#   list_gitlab_tokens() with an interactive selection interface.
#
# OUTPUT:
#   stdout - Selected token name (for use in scripts)
#   stderr - Menu display and error messages
#
# RETURN VALUES:
#   0 - Success: Token selected and returned
#   1 - Failure: No tokens available or invalid selection
#
select_gitlab_token() {
    local env_file="${HOME}/.env"
    
    # First, list available tokens
    if ! list_gitlab_tokens >&2; then
        return 1
    fi
    
    # Build array of token names for selection
    local token_names=()
    local gitlab_tokens
    gitlab_tokens=$(grep -E '^GITLAB_.*_TOKEN=' "$env_file" 2>/dev/null)
    
    while IFS='=' read -r token_name token_value; do
        if [ -n "$token_name" ]; then
            token_names+=("$token_name")
        fi
    done <<< "$gitlab_tokens"
    
    if [ ${#token_names[@]} -eq 0 ]; then
        echo "Error: No tokens available for selection" >&2
        return 1
    fi
    
    # Single token - auto-select
    if [ ${#token_names[@]} -eq 1 ]; then
        echo "🎯 Auto-selecting the only available token: ${token_names[0]}" >&2
        echo "${token_names[0]}"
        return 0
    fi
    
    # Multiple tokens - interactive selection
    echo "🎯 Select a GitLab token to use:" >&2
    echo >&2
    
    local choice
    read -p "Enter choice (1-${#token_names[@]}): " choice >&2
    
    # Validate choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#token_names[@]} ]; then
        echo "❌ Invalid choice. Please enter a number between 1 and ${#token_names[@]}" >&2
        return 1
    fi
    
    # Return selected token name (0-based array indexing)
    local selected_token="${token_names[$((choice-1))]}"
    echo "✅ Selected: $selected_token" >&2
    echo "$selected_token"
    
    return 0
}

##
# Enhanced token setup function that allows reviewing existing tokens or creating new ones.
#
# DESCRIPTION:
#   This function replaces the simple input_token workflow with a more sophisticated
#   approach that first checks for existing GitLab tokens and gives users options
#   to use existing tokens or create new ones.
#
# PARAMETERS:
#   $1 (string, optional) - Default token name if creating new token
#                          Defaults to "GITLAB_API_TOKEN"
#
# RETURN VALUES:
#   0 - Success: Token selected or created
#   1 - Failure: User cancelled or error occurred
#
setup_gitlab_token() {
    local default_token_name="${1:-GITLAB_API_TOKEN}"
    
    echo "🚀 GitLab Token Setup"
    echo "===================="
    echo
    
    # Check if we have existing tokens
    local has_tokens=false
    if list_gitlab_tokens >/dev/null 2>&1; then
        has_tokens=true
        echo
    fi
    
    echo "📋 What would you like to do?"
    echo
    
    if [ "$has_tokens" = true ]; then
        echo "1) Use an existing GitLab token"
        echo "2) Create a new GitLab token"
        echo "3) View existing tokens again"
        echo "4) View token usage examples"
        echo "5) Exit without changes"
    else
        echo "1) Create a new GitLab token"
        echo "2) View token usage examples"
        echo "3) Exit without changes"
    fi
    
    echo
    local choice
    read -p "Enter your choice: " choice
    echo
    
    case "$choice" in
        1)
            if [ "$has_tokens" = true ]; then
                # Use existing token
                if selected_token=$(select_gitlab_token); then
                    echo "🎉 Ready to use token: $selected_token"
                    echo
                    echo "💡 To use this token in your scripts:"
                    echo "   token=\$(get_env_variable \"$selected_token\")"
                    echo "   add_project_member \"PROJECT_ID\" \"\$token\""
                    return 0
                else
                    echo "❌ Token selection failed"
                    return 1
                fi
            else
                # Create new token
                input_token "$default_token_name"
                return $?
            fi
            ;;
        2)
            if [ "$has_tokens" = true ]; then
                # Create new token
                echo "📝 Creating a new GitLab token..."
                echo
                read -p "Enter token name [$default_token_name]: " token_name
                token_name="${token_name:-$default_token_name}"
                
                # Ensure it follows naming convention
                if [[ ! "$token_name" =~ ^GITLAB_.*_TOKEN$ ]]; then
                    echo "⚠️  Token name doesn't follow convention. Suggested: GITLAB_${token_name}_TOKEN"
                    read -p "Use suggested name? (y/N): " use_suggested
                    if [[ "$use_suggested" =~ ^[Yy]$ ]]; then
                        token_name="GITLAB_${token_name}_TOKEN"
                    fi
                fi
                
                input_token "$token_name"
                return $?
            else
                # View examples
                show_token_examples
                return 1
            fi
            ;;
        3)
            if [ "$has_tokens" = true ]; then
                # View tokens again
                list_gitlab_tokens
                echo
                setup_gitlab_token "$default_token_name"
                return $?
            else
                # Exit
                echo "👋 Exiting without changes"
                return 1
            fi
            ;;
        4)
            if [ "$has_tokens" = true ]; then
                # View examples
                show_token_examples
                echo
                setup_gitlab_token "$default_token_name"
                return $?
            else
                # Exit
                echo "👋 Exiting without changes"
                return 1
            fi
            ;;
        5)
            if [ "$has_tokens" = true ]; then
                # Exit
                echo "👋 Exiting without changes"
                return 1
            else
                echo "❌ Invalid choice"
                return 1
            fi
            ;;
        *)
            echo "❌ Invalid choice"
            return 1
            ;;
    esac
}

##
# Shows examples of GitLab token usage and naming conventions.
#
show_token_examples() {
    echo "💡 GitLab Token Examples & Best Practices"
    echo "========================================="
    echo
    echo "🏷️  Token Naming Convention:"
    echo "   Pattern: GITLAB_[PURPOSE]_TOKEN"
    echo
    echo "   Examples:"
    echo "   • GITLAB_API_TOKEN        - General API access"
    echo "   • GITLAB_GMAIL_API_TOKEN  - Gmail integration"
    echo "   • GITLAB_PROD_TOKEN       - Production environment"
    echo "   • GITLAB_DEV_TOKEN        - Development environment"
    echo "   • GITLAB_CI_TOKEN         - CI/CD pipeline access"
    echo "   • GITLAB_PERSONAL_TOKEN   - Personal automation"
    echo
    echo "🔑 Token Scopes Needed:"
    echo "   • read_api  - List projects and members"
    echo "   • api       - Create projects, manage members"
    echo
    echo "📋 Usage Examples:"
    echo "   # Load and use a token"
    echo "   token=\$(get_env_variable \"GITLAB_API_TOKEN\")"
    echo "   add_project_member \"123\" \"\$token\""
    echo
    echo "   # List all your tokens"
    echo "   list_gitlab_tokens"
    echo
    echo "   # Interactive token selection"
    echo "   selected=\$(select_gitlab_token)"
    echo "   token=\$(get_env_variable \"\$selected\")"
    echo
    echo "🔗 Get your token at: https://gitlab.com/-/profile/personal_access_tokens"
}

# --- BASIC TOKEN MANAGEMENT FUNCTIONS ---

##
# Prompts user for a token value and securely stores it in ~/.env file.
#
# PARAMETERS:
#   $1 (string, required) - The name of the environment variable to store
#
# RETURN VALUES:
#   0 - Success: Token successfully stored in ~/.env
#   1 - Failure: Empty token value provided or file operations failed
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
# PARAMETERS:
#   $1 (string, required) - Environment variable name
#   $2 (string, required) - Environment variable value
#
# RETURN VALUES:
#   0 - Success: Variable successfully updated or added
#   1 - Failure: File creation failed, permission issues, or sed operation failed
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
# PARAMETERS:
#   $1 (string, required) - Name of the environment variable to retrieve
#
# OUTPUT:
#   stdout - The value of the requested environment variable (on success)
#   stderr - Error messages describing any failures
#
# RETURN VALUES:
#   0 - Success: Variable found and value output to stdout
#   1 - Failure: .env file not found, variable not set, or empty value
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
# PARAMETERS:
#   $1 (string, required) - Project name for the new GitLab project
#   $2 (string, required) - GitLab Personal Access Token (PAT)
#
# OUTPUT:
#   stdout (Success) - Complete JSON response from GitLab API
#   stderr (Failure) - Detailed error messages with troubleshooting steps
#
# RETURN VALUES:
#   0 - Success: Project created successfully
#   1 - Failure: Missing parameters, authentication error, or API error
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
# PARAMETERS:
#   $1 (string, required) - GitLab Personal Access Token (PAT)
#   $2 (string, optional) - Output format [Default: "raw"]
#                          Options: "raw", "csv", "json"
#   $3 (string, optional) - Filter by last activity after date (YYYY-MM-DD)
#   $4 (string, optional) - Filter by visibility level ("public", "internal", "private")
#
# RETURN VALUES:
#   0 - Success: Projects retrieved and displayed successfully
#   1 - Failure: Authentication error, network issues, or invalid parameters
#
get_list_of_projects() {
    local token="$1"
    local output_format="${2:-raw}"
    local last_activity_after="${3}"
    local visibility="${4}"
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
# PARAMETERS:
#   $1 (string, required) - GitLab Personal Access Token (PAT)
#
# OUTPUT:
#   stdout - Simple list format: "Project Name - YYYY-MM-DDTHH:MM:SS.sssZ"
#   stderr - Basic error messages and progress indicators
#
# RETURN VALUES:
#   0 - Success: Projects retrieved and displayed
#   1 - Failure: Missing token or API error
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

# --- PROJECT MEMBER MANAGEMENT FUNCTIONS ---

##
# Adds a member to a GitLab project with interactive prompts for role and expiry date.
#
# PARAMETERS:
#   $1 (string, required) - Project ID or project path (URL-encoded)
#   $2 (string, required) - GitLab Personal Access Token (PAT)
#
# RETURN VALUES:
#   0 - Success: Member added successfully
#   1 - Failure: Invalid parameters, user not found, or API error
#
add_project_member() {
    local project_id="$1"
    local gitlab_pat="$2"
    local gitlab_url="https://gitlab.com"

    if [ -z "$project_id" ] || [ -z "$gitlab_pat" ]; then
        echo "Usage: add_project_member <project_id> <gitlab_pat>" >&2
        return 1
    fi

    # Interactive prompts
    local user_email
    local access_level
    local expires_at
    local user_id

    echo "=== Add Member to GitLab Project ==="
    echo

    # Get user email
    read -p "Enter user's email address: " user_email
    if [ -z "$user_email" ]; then
        echo "Error: Email address cannot be empty." >&2
        return 1
    fi

    # Validate email format
    if ! echo "$user_email" | grep -qE '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'; then
        echo "Error: Invalid email format." >&2
        return 1
    fi

    # Find user by email
    echo "Looking up user by email..."
    local user_response
    user_response=$(curl -s --header "PRIVATE-TOKEN: $gitlab_pat" \
                         "$gitlab_url/api/v4/users?search=$user_email")

    if [ $? -ne 0 ]; then
        echo "Error: Failed to search for user." >&2
        return 1
    fi

    # Check if user was found
    local user_count
    user_count=$(echo "$user_response" | jq length 2>/dev/null)
    
    if [ "$user_count" -eq 0 ]; then
        echo "Error: User with email '$user_email' not found in GitLab." >&2
        return 1
    fi

    # Get the first matching user (should be exact match)
    user_id=$(echo "$user_response" | jq -r '.[0].id' 2>/dev/null)
    local username=$(echo "$user_response" | jq -r '.[0].username' 2>/dev/null)
    local name=$(echo "$user_response" | jq -r '.[0].name' 2>/dev/null)

    echo "Found user: $name (@$username)"
    echo

    # Get role selection
    echo "Select user role:"
    echo "1) Guest (10) - Can view project, create issues and comments"
    echo "2) Reporter (20) - Can pull project, download artifacts, create issues/merge requests"
    echo "3) Developer (30) - Can push to non-protected branches, manage issues/merge requests"
    echo "4) Maintainer (40) - Can push to protected branches, manage project settings"
    echo "5) Owner (50) - Full access including project deletion"
    echo

    local role_choice
    read -p "Enter choice (1-5): " role_choice

    case "$role_choice" in
        1) access_level=10 ;;
        2) access_level=20 ;;
        3) access_level=30 ;;
        4) access_level=40 ;;
        5) access_level=50 ;;
        *)
            echo "Error: Invalid role selection." >&2
            return 1
            ;;
    esac

    # Get expiry date (optional)
    echo
    read -p "Enter expiry date (YYYY-MM-DD) or press Enter for no expiry: " expires_at

    if [ -n "$expires_at" ]; then
        # Validate date format
        if ! echo "$expires_at" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
            echo "Error: Invalid date format. Use YYYY-MM-DD." >&2
            return 1
        fi

        # Validate date is in the future
        if command -v date >/dev/null 2>&1; then
            local current_date=$(date +%Y-%m-%d)
            if [[ "$expires_at" < "$current_date" ]]; then
                echo "Error: Expiry date must be in the future." >&2
                return 1
            fi
        fi
    fi

    # Prepare request body
    local request_body="{\"user_id\": $user_id, \"access_level\": $access_level"
    if [ -n "$expires_at" ]; then
        request_body+=", \"expires_at\": \"$expires_at\""
    fi
    request_body+="}"

    echo
    echo "Adding member to project..."

    # Make the API call
    local http_status
    local response

    response=$(curl --request POST \
                    --header "PRIVATE-TOKEN: $gitlab_pat" \
                    --header "Content-Type: application/json" \
                    --data "$request_body" \
                    --url "$gitlab_url/api/v4/projects/$project_id/members" \
                    --silent \
                    --write-out "%{http_code}")

    http_status=$(echo "$response" | tail -c 4)
    response=$(echo "$response" | head -c -4)

    case "$http_status" in
        201)
            echo "✅ Member added successfully!"
            echo "User: $name (@$username)"
            echo "Role: $(get_role_name $access_level)"
            [ -n "$expires_at" ] && echo "Expires: $expires_at"
            echo
            echo "$response" | jq '.' 2>/dev/null || echo "$response"
            ;;
        409)
            echo "⚠️  User is already a member of this project." >&2
            echo "$response" | jq -r '.message' 2>/dev/null || echo "$response" >&2
            return 1
            ;;
        400)
            echo "❌ Bad request. Check project ID and parameters." >&2
            echo "$response" | jq -r '.message' 2>/dev/null || echo "$response" >&2
            return 1
            ;;
        401)
            echo "❌ Unauthorized. Check your access token." >&2
            return 1
            ;;
        403)
            echo "❌ Forbidden. You don't have permission to add members to this project." >&2
            echo "$response" | jq -r '.message' 2>/dev/null || echo "$response" >&2
            return 1
            ;;
        404)
            echo "❌ Project not found or user not found." >&2
            echo "$response" | jq -r '.message' 2>/dev/null || echo "$response" >&2
            return 1
            ;;
        *)
            echo "❌ Error adding member to project." >&2
            echo "HTTP Status Code: $http_status" >&2
            echo "$response" | jq '.' 2>/dev/null || echo "$response" >&2
            return 1
            ;;
    esac
}

##
# Lists all members of a GitLab project with their roles and details.
#
# PARAMETERS:
#   $1 (string, required) - Project ID or project path (URL-encoded)
#   $2 (string, required) - GitLab Personal Access Token (PAT)
#   $3 (string, optional) - Output format: "table" (default), "json", "csv"
#
list_project_members() {
    local project_id="$1"
    local gitlab_pat="$2"
    local output_format="${3:-table}"
    local gitlab_url="https://gitlab.com"

    if [ -z "$project_id" ] || [ -z "$gitlab_pat" ]; then
        echo "Usage: list_project_members <project_id> <gitlab_pat> [output_format]" >&2
        return 1
    fi

    echo "Fetching project members..." >&2

    local response
    response=$(curl -s --header "PRIVATE-TOKEN: $gitlab_pat" \
                    "$gitlab_url/api/v4/projects/$project_id/members")

    if [ $? -ne 0 ]; then
        echo "Error: Failed to fetch project members." >&2
        return 1
    fi

    # Check for API errors
    local has_error
    has_error=$(echo "$response" | jq -r 'if type=="object" and has("message") then "true" else "false" end' 2>/dev/null)
    
    if [ "$has_error" = "true" ]; then
        echo "Error from GitLab API:" >&2
        echo "$response" | jq -r '.message' >&2
        return 1
    fi

    case "$output_format" in
        table)
            echo
            printf "%-20s %-15s %-12s %-12s\n" "Name" "Username" "Role" "Expires"
            echo "------------------------------------------------------------"
            echo "$response" | jq -r '.[] | "\(.name // "N/A")|\(.username // "N/A")|\(.access_level)|\(.expires_at // "Never")"' | \
            while IFS='|' read -r name username access_level expires_at; do
                role_name=$(get_role_name "$access_level")
                printf "%-20s %-15s %-12s %-12s\n" "$name" "$username" "$role_name" "$expires_at"
            done
            ;;
        json)
            echo "$response" | jq '.'
            ;;
        csv)
            echo "name,username,access_level,role,expires_at"
            echo "$response" | jq -r '.[] | [(.name // ""), (.username // ""), (.access_level // ""), "", (.expires_at // "")] | @csv' | \
            while IFS=',' read -r name username access_level empty expires_at; do
                role_name=$(get_role_name "${access_level//\"/}")
                echo "$name,$username,$access_level,\"$role_name\",$expires_at"
            done
            ;;
        *)
            echo "Error: Invalid output format. Use table, json, or csv." >&2
            return 1
            ;;
    esac
}

##
# Removes a member from a GitLab project.
#
# PARAMETERS:
#   $1 (string, required) - Project ID or project path (URL-encoded)
#   $2 (string, required) - User email or user ID
#   $3 (string, required) - GitLab Personal Access Token (PAT)
#
remove_project_member() {
    local project_id="$1"
    local user_identifier="$2"
    local gitlab_pat="$3"
    local gitlab_url="https://gitlab.com"

    if [ -z "$project_id" ] || [ -z "$user_identifier" ] || [ -z "$gitlab_pat" ]; then
        echo "Usage: remove_project_member <project_id> <user_email_or_id> <gitlab_pat>" >&2
        return 1
    fi

    local user_id="$user_identifier"

    # If identifier looks like an email, find the user ID
    if echo "$user_identifier" | grep -qE '@'; then
        echo "Looking up user by email..."
        local user_response
        user_response=$(curl -s --header "PRIVATE-TOKEN: $gitlab_pat" \
                             "$gitlab_url/api/v4/users?search=$user_identifier")

        if [ $? -ne 0 ]; then
            echo "Error: Failed to search for user." >&2
            return 1
        fi

        local user_count
        user_count=$(echo "$user_response" | jq length 2>/dev/null)
        
        if [ "$user_count" -eq 0 ]; then
            echo "Error: User with email '$user_identifier' not found." >&2
            return 1
        fi

        user_id=$(echo "$user_response" | jq -r '.[0].id' 2>/dev/null)
        local username=$(echo "$user_response" | jq -r '.[0].username' 2>/dev/null)
        local name=$(echo "$user_response" | jq -r '.[0].name' 2>/dev/null)
        
        echo "Found user: $name (@$username)"
    fi

    # Confirmation prompt
    echo
    read -p "Are you sure you want to remove this member? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        return 0
    fi

    echo "Removing member from project..."

    local http_status
    local response

    response=$(curl --request DELETE \
                    --header "PRIVATE-TOKEN: $gitlab_pat" \
                    --url "$gitlab_url/api/v4/projects/$project_id/members/$user_id" \
                    --silent \
                    --write-out "%{http_code}")

    http_status=$(echo "$response" | tail -c 4)
    response=$(echo "$response" | head -c -4)

    case "$http_status" in
        204)
            echo "✅ Member removed successfully!"
            ;;
        404)
            echo "❌ Member not found in project or project not found." >&2
            return 1
            ;;
        401)
            echo "❌ Unauthorized. Check your access token." >&2
            return 1
            ;;
        403)
            echo "❌ Forbidden. You don't have permission to remove members from this project." >&2
            return 1
            ;;
        *)
            echo "❌ Error removing member from project." >&2
            echo "HTTP Status Code: $http_status" >&2
            [ -n "$response" ] && echo "$response" >&2
            return 1
            ;;
    esac
}

##
# Helper function to convert GitLab access level numbers to role names.
#
# PARAMETERS:
#   $1 (integer, required) - GitLab access level (10, 20, 30, 40, 50)
#
# OUTPUT:
#   stdout - Role name corresponding to the access level
#
get_role_name() {
    local access_level="$1"
    
    case "$access_level" in
        10) echo "Guest" ;;
        20) echo "Reporter" ;;
        30) echo "Developer" ;;
        40) echo "Maintainer" ;;
        50) echo "Owner" ;;
        *) echo "Unknown" ;;
    esac
}

# --- ENHANCED WORKFLOW FUNCTIONS ---

##
# Enhanced member management workflow that includes smart token selection.
#
# DESCRIPTION:
#   This function provides a complete workflow for managing project members,
#   including smart token selection from available GitLab tokens.
#
# PARAMETERS:
#   $1 (string, optional) - Project ID. If not provided, will prompt user.
#
manage_project_members() {
    local project_id="$1"
    
    echo "🚀 GitLab Project Member Management"
    echo "==================================="
    echo
    
    # Step 1: Select or setup token
    echo "Step 1: Token Selection"
    echo "----------------------"
    
    local selected_token
    if ! selected_token=$(select_gitlab_token 2>/dev/null); then
        echo "No GitLab tokens found. Let's set one up..." >&2
        if ! setup_gitlab_token; then
            echo "❌ Token setup failed or cancelled" >&2
            return 1
        fi
        # Try again after setup
        if ! selected_token=$(select_gitlab_token); then
            echo "❌ Still no token available" >&2
            return 1
        fi
    fi
    
    local token
    token=$(get_env_variable "$selected_token")
    
    echo "✅ Using token: $selected_token"
    echo
    
    # Step 2: Get project ID if not provided
    if [ -z "$project_id" ]; then
        echo "Step 2: Project Selection"
        echo "------------------------"
        echo "💡 First, let's see your projects:"
        echo
        
        if ! get_list_of_projects_simple "$token" | head -10; then
            echo "❌ Failed to fetch projects. Check your token permissions." >&2
            return 1
        fi
        
        echo
        read -p "Enter Project ID or path (e.g., '123' or 'group%2Fproject'): " project_id
        
        if [ -z "$project_id" ]; then
            echo "❌ Project ID is required" >&2
            return 1
        fi
    fi
    
    echo "✅ Using project: $project_id"
    echo
    
    # Step 3: Choose action
    echo "Step 3: Choose Action"
    echo "--------------------"
    echo "What would you like to do?"
    echo
    echo "1) Add a member to the project"
    echo "2) List current project members"
    echo "3) Remove a member from the project"
    echo "4) Exit"
    echo
    
    local action
    read -p "Enter your choice (1-4): " action
    echo
    
    case "$action" in
        1)
            echo "🔄 Adding member to project $project_id..."
            add_project_member "$project_id" "$token"
            ;;
        2)
            echo "📋 Listing members of project $project_id..."
            list_project_members "$project_id" "$token"
            ;;
        3)
            echo "🗑️  Removing member from project $project_id..."
            read -p "Enter user email or ID to remove: " user_to_remove
            if [ -n "$user_to_remove" ]; then
                remove_project_member "$project_id" "$user_to_remove" "$token"
            else
                echo "❌ User email/ID is required"
            fi
            ;;
        4)
            echo "👋 Goodbye!"
            ;;
        *)
            echo "❌ Invalid choice"
            return 1
            ;;
    esac
}

##
# Smart token setup function that provides a complete workflow.
#
# PARAMETERS:
#   $1 (string, optional) - Default token name if creating new token
#                          Defaults to "GITLAB_API_TOKEN"
#
smart_token_setup() {
    local default_name="${1:-GITLAB_API_TOKEN}"
    
    echo "🎯 Smart GitLab Token Setup"
    echo "============================"
    echo
    
    setup_gitlab_token "$default_name"
    local result=$?
    
    if [ $result -eq 0 ]; then
        echo
        echo "✅ Token setup complete!"
        echo
        echo "🚀 Next steps:"
        echo "   # Start member management workflow"
        echo "   manage_project_members"
        echo
        echo "   # Or load your token manually"
        echo "   token=\$(get_env_variable \"YOUR_TOKEN_NAME\")"
        echo "   add_project_member \"PROJECT_ID\" \"\$token\""
    fi
    
    return $result
}

# --- EXAMPLES AND HELP FUNCTIONS ---

##
# Shows the enhanced workflow examples and available functions.
#
show_enhanced_workflow_examples() {
    echo "🌟 Enhanced GitLab Token & Member Management Workflow"
    echo "===================================================="
    echo
    echo "🔧 New Functions Available:"
    echo "   list_gitlab_tokens          - Show all GitLab tokens in ~/.env"
    echo "   select_gitlab_token         - Interactive token selection" 
    echo "   setup_gitlab_token          - Enhanced token setup with options"
    echo "   smart_token_setup           - Complete token workflow"
    echo "   manage_project_members      - Complete member management workflow"
    echo
    echo "🚀 Quick Start (Recommended):"
    echo "   source ./gitlab-api.sh"
    echo "   manage_project_members      # Complete interactive workflow"
    echo
    echo "🔍 Token Management:"
    echo "   list_gitlab_tokens          # Review existing tokens"
    echo "   smart_token_setup          # Setup or select tokens"
    echo
    echo "⚡ Advanced Usage:"
    echo "   # Select token interactively, then use it"
    echo "   selected=\$(select_gitlab_token)"
    echo "   token=\$(get_env_variable \"\$selected\")"
    echo "   add_project_member \"PROJECT_ID\" \"\$token\""
    echo
    echo "📊 Multiple Token Examples:"
    echo "   You can now have multiple tokens for different purposes:"
    echo "   • GITLAB_API_TOKEN         - General use"
    echo "   • GITLAB_GMAIL_API_TOKEN   - Gmail integration"  
    echo "   • GITLAB_PROD_TOKEN        - Production environment"
    echo "   • GITLAB_DEV_TOKEN         - Development environment"
    echo
    echo "🎯 Token Naming Convention:"
    echo "   Pattern: GITLAB_[PURPOSE]_TOKEN"
    echo "   Examples: GITLAB_CI_TOKEN, GITLAB_PERSONAL_TOKEN"
    echo
    echo "🔗 Get tokens at: https://gitlab.com/-/profile/personal_access_tokens"
}

##
# Shows usage examples for all major functions.
#
show_usage_examples() {
    echo "📚 GitLab API Script - Usage Examples"
    echo "====================================="
    echo
    echo "🚀 QUICK START:"
    echo "   source ./gitlab-api.sh"
    echo "   manage_project_members      # Complete interactive workflow"
    echo
    echo "🔑 TOKEN MANAGEMENT:"
    echo "   # List existing GitLab tokens"
    echo "   list_gitlab_tokens"
    echo
    echo "   # Interactive token selection"
    echo "   selected=\$(select_gitlab_token)"
    echo "   token=\$(get_env_variable \"\$selected\")"
    echo
    echo "   # Create new token"
    echo "   smart_token_setup \"GITLAB_MY_TOKEN\""
    echo
    echo "📁 PROJECT OPERATIONS:"
    echo "   # Create new project"
    echo "   token=\$(get_env_variable \"GITLAB_API_TOKEN\")"
    echo "   make_new_project \"my-awesome-project\" \"\$token\""
    echo
    echo "   # List projects (various formats)"
    echo "   get_list_of_projects \"\$token\"                    # Simple list"
    echo "   get_list_of_projects \"\$token\" \"csv\"             # CSV format"
    echo "   get_list_of_projects \"\$token\" \"json\"            # Full JSON"
    echo "   get_list_of_projects \"\$token\" \"raw\" \"2025-01-01\" # Active since date"
    echo
    echo "👥 MEMBER MANAGEMENT:"
    echo "   # Add member (interactive)"
    echo "   add_project_member \"123\" \"\$token\""
    echo
    echo "   # List members"
    echo "   list_project_members \"123\" \"\$token\"            # Table format"
    echo "   list_project_members \"123\" \"\$token\" \"csv\"     # CSV format"
    echo
    echo "   # Remove member"
    echo "   remove_project_member \"123\" \"user@email.com\" \"\$token\""
    echo
    echo "🛠️  UTILITY FUNCTIONS:"
    echo "   # Get simple project list (debugging)"
    echo "   get_list_of_projects_simple \"\$token\""
    echo
    echo "   # Manual token storage"
    echo "   input_token \"GITLAB_CUSTOM_TOKEN\""
    echo
    echo "   # Retrieve stored token"
    echo "   my_token=\$(get_env_variable \"GITLAB_API_TOKEN\")"
}

# --- INITIALIZATION ---

# Display welcome message when script is sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    echo "✅ Enhanced GitLab API Helper Script loaded!"
    echo
    echo "🚀 Quick Start:"
    echo "   manage_project_members      # Complete interactive workflow"
    echo
    echo "📚 Help & Examples:"
    echo "   show_enhanced_workflow_examples    # Show new features"
    echo "   show_usage_examples               # Show all examples"
    echo "   show_token_examples               # Token best practices"
    echo
    echo "🔍 Token Management:"
    echo "   list_gitlab_tokens         # Review existing tokens"
    echo "   smart_token_setup         # Setup new tokens"
fi