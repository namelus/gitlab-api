#!/bin/bash

# ==============================================================================
# GitLab Project Cache System
# ==============================================================================
#
# This extension to the GitLab API Helper provides local caching of project data
# in the AppData folder with advanced search and lookup capabilities.
#
# FEATURES:
# - Cross-platform AppData folder detection (Windows/Linux/macOS)
# - Project data caching with automatic sorting by last updated date
# - Duplicate project prevention before creation
# - Search by date ranges and member involvement
# - Efficient file-based storage with JSON format
# - Automatic cache refresh and data validation
#
# CACHE FILE STRUCTURE:
# - Location: $APPDATA/gitlab-api-helper/projects-cache.json (Windows)
#            ~/.local/share/gitlab-api-helper/projects-cache.json (Linux)
#            ~/Library/Application Support/gitlab-api-helper/projects-cache.json (macOS)
# - Format: JSON array sorted by last_activity_at (newest first)
# - Metadata: Cache timestamp, total count, last API call info
#
# DEPENDENCIES:
# - Requires gitlab-api.sh functions
# - jq for JSON processing
# - curl for API calls
# - Standard shell utilities
#
# USAGE:
#   source ./gitlab-api.sh
#   source ./gitlab-project-cache.sh
#   
#   # Initialize cache
#   init_project_cache "$GITLAB_API_TOKEN"
#   
#   # Search and lookup
#   check_project_exists "my-project"
#   find_projects_by_member "username"
#   find_projects_updated_since "2025-08-01"
#
# ==============================================================================

# --- CACHE CONFIGURATION ---

##
# Determines the appropriate AppData directory based on the operating system.
#
# DESCRIPTION:
#   This function provides cross-platform detection of the user's application
#   data directory following OS conventions. It creates the directory structure
#   if it doesn't exist and ensures proper permissions are set.
#
# DIRECTORY LOCATIONS:
#   Windows (Git Bash/WSL): $APPDATA/gitlab-api-helper/
#   Linux: ~/.local/share/gitlab-api-helper/
#   macOS: ~/Library/Application Support/gitlab-api-helper/
#   Fallback: ~/.gitlab-api-helper/
#
# OUTPUT:
#   stdout - Full path to the GitLab API Helper cache directory
#
# SIDE EFFECTS:
#   - Creates the cache directory if it doesn't exist
#   - Sets directory permissions to 755 (user rwx, group/other rx)
#
get_cache_directory() {
    local cache_dir
    
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "${APPDATA:-}" ]]; then
        # Windows (Git Bash/WSL)
        cache_dir="${APPDATA:-$HOME/AppData/Roaming}/gitlab-api-helper"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        cache_dir="$HOME/Library/Application Support/gitlab-api-helper"
    elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ -n "${XDG_DATA_HOME:-}" ]]; then
        # Linux
        cache_dir="${XDG_DATA_HOME:-$HOME/.local/share}/gitlab-api-helper"
    else
        # Fallback for other Unix-like systems
        cache_dir="$HOME/.gitlab-api-helper"
    fi
    
    # Create directory if it doesn't exist
    mkdir -p "$cache_dir"
    chmod 755 "$cache_dir"
    
    echo "$cache_dir"
}

##
# Returns the full path to the projects cache file.
#
get_cache_file_path() {
    local cache_dir
    cache_dir=$(get_cache_directory)
    echo "$cache_dir/projects-cache.json"
}

##
# Returns the path to the cache metadata file.
#
get_cache_metadata_path() {
    local cache_dir
    cache_dir=$(get_cache_directory)
    echo "$cache_dir/cache-metadata.json"
}

# --- CACHE INITIALIZATION AND MANAGEMENT ---

##
# Initializes the project cache by fetching all projects from GitLab API.
#
# DESCRIPTION:
#   This function fetches all projects from GitLab, sorts them by last activity
#   date (newest first), and stores them in a local cache file. It also creates
#   metadata about the cache including timestamp and project count.
#
# PARAMETERS:
#   $1 (string, required) - GitLab Personal Access Token
#   $2 (string, optional) - Force refresh flag ("force" to skip cache check)
#
# CACHE STRUCTURE:
#   projects-cache.json: Array of project objects sorted by last_activity_at
#   cache-metadata.json: Metadata about cache (timestamp, count, etc.)
#
init_project_cache() {
    local gitlab_pat="$1"
    local force_refresh="${2:-}"
    local cache_file
    cache_file=$(get_cache_file_path)
    local metadata_file
    metadata_file=$(get_cache_metadata_path)
    
    if [ -z "$gitlab_pat" ]; then
        echo "Error: GitLab Personal Access Token required" >&2
        return 1
    fi
    
    # Check if cache exists and is recent (unless force refresh)
    if [ "$force_refresh" != "force" ] && [ -f "$cache_file" ] && [ -f "$metadata_file" ]; then
        local cache_age
        cache_age=$(jq -r '.cache_timestamp // 0' "$metadata_file" 2>/dev/null || echo "0")
        local current_time
        current_time=$(date +%s)
        local age_hours=$(( (current_time - cache_age) / 3600 ))
        
        if [ $age_hours -lt 4 ]; then
            echo "Cache is recent (${age_hours}h old), use 'force' to refresh" >&2
            return 0
        fi
    fi
    
    echo "Fetching all projects from GitLab API..." >&2
    
    # Source the main GitLab API functions
    if ! declare -f get_list_of_projects >/dev/null 2>&1; then
        echo "Error: GitLab API functions not loaded. Source gitlab-api.sh first." >&2
        return 1
    fi
    
    # Fetch projects in JSON format
    local projects_json
    if ! projects_json=$(get_list_of_projects "$gitlab_pat" "json" 2>/dev/null); then
        echo "Error: Failed to fetch projects from GitLab API" >&2
        return 1
    fi
    
    # Sort projects by last_activity_at (newest first)
    local sorted_projects
    sorted_projects=$(echo "$projects_json" | jq 'sort_by(.last_activity_at) | reverse')
    
    # Write to cache file
    echo "$sorted_projects" > "$cache_file"
    chmod 644 "$cache_file"
    
    # Create metadata
    local project_count
    project_count=$(echo "$sorted_projects" | jq length)
    local metadata
    metadata=$(cat << EOF
{
  "cache_timestamp": $(date +%s),
  "cache_created": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
  "project_count": $project_count,
  "gitlab_api_version": "v4",
  "cache_file": "$cache_file",
  "last_api_call": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
}
EOF
)
    
    echo "$metadata" > "$metadata_file"
    chmod 644 "$metadata_file"
    
    echo "✅ Cache initialized with $project_count projects" >&2
    echo "📁 Cache location: $cache_file" >&2
    
    return 0
}

##
# Updates a single project in the cache or adds it if it doesn't exist.
#
# PARAMETERS:
#   $1 (string, required) - Project JSON object to update/add
#
update_project_in_cache() {
    local project_json="$1"
    local cache_file
    cache_file=$(get_cache_file_path)
    
    if [ -z "$project_json" ]; then
        echo "Error: Project JSON required" >&2
        return 1
    fi
    
    # Initialize cache if it doesn't exist
    if [ ! -f "$cache_file" ]; then
        echo "[]" > "$cache_file"
    fi
    
    local project_id
    project_id=$(echo "$project_json" | jq -r '.id')
    
    if [ -z "$project_id" ] || [ "$project_id" = "null" ]; then
        echo "Error: Invalid project JSON - missing ID" >&2
        return 1
    fi
    
    # Read current cache
    local current_cache
    current_cache=$(cat "$cache_file")
    
    # Update or add project, then re-sort
    local updated_cache
    updated_cache=$(echo "$current_cache" | jq --argjson new_project "$project_json" '
        map(select(.id != ($new_project.id))) + [$new_project] | sort_by(.last_activity_at) | reverse
    ')
    
    # Write back to cache
    echo "$updated_cache" > "$cache_file"
    
    echo "✅ Project updated in cache: $(echo "$project_json" | jq -r '.name')" >&2
    return 0
}

##
# Refreshes the entire project cache by re-fetching from GitLab API.
#
refresh_project_cache() {
    local gitlab_pat="$1"
    
    if [ -z "$gitlab_pat" ]; then
        echo "Error: GitLab Personal Access Token required" >&2
        return 1
    fi
    
    echo "🔄 Refreshing project cache..." >&2
    init_project_cache "$gitlab_pat" "force"
}

# --- LOOKUP AND SEARCH FUNCTIONS ---

##
# Checks if a project with the given name already exists in the cache.
#
# DESCRIPTION:
#   This function performs a case-insensitive search through the cached projects
#   to determine if a project with the specified name already exists. This is
#   essential for preventing duplicate project creation.
#
# PARAMETERS:
#   $1 (string, required) - Project name to check
#
# OUTPUT:
#   stdout - "exists" if found, "not_found" if not found
#   stderr - Error messages or project details if found
#
# RETURN VALUES:
#   0 - Project exists in cache
#   1 - Project not found or cache error
#
check_project_exists() {
    local project_name="$1"
    local cache_file
    cache_file=$(get_cache_file_path)
    
    if [ -z "$project_name" ]; then
        echo "Error: Project name required" >&2
        return 1
    fi
    
    if [ ! -f "$cache_file" ]; then
        echo "Error: Cache not initialized. Run init_project_cache first." >&2
        return 1
    fi
    
    # Case-insensitive search for project name
    local found_project
    found_project=$(cat "$cache_file" | jq --arg name "$project_name" '
        .[] | select(.name | ascii_downcase == ($name | ascii_downcase))
    ')
    
    if [ -n "$found_project" ] && [ "$found_project" != "null" ]; then
        echo "exists"
        local project_url
        project_url=$(echo "$found_project" | jq -r '.web_url')
        echo "Project '$project_name' already exists at: $project_url" >&2
        return 0
    else
        echo "not_found"
        return 1
    fi
}

##
# Finds projects that have been updated since a specific date.
#
# PARAMETERS:
#   $1 (string, required) - Date in YYYY-MM-DD format
#   $2 (string, optional) - Output format: "names", "full", "count" (default: "names")
#
find_projects_updated_since() {
    local since_date="$1"
    local output_format="${2:-names}"
    local cache_file
    cache_file=$(get_cache_file_path)
    
    if [ -z "$since_date" ]; then
        echo "Error: Date required (YYYY-MM-DD format)" >&2
        return 1
    fi
    
    if [ ! -f "$cache_file" ]; then
        echo "Error: Cache not initialized. Run init_project_cache first." >&2
        return 1
    fi
    
    # Convert date to ISO format for comparison
    local iso_date="${since_date}T00:00:00.000Z"
    
    local filtered_projects
    filtered_projects=$(cat "$cache_file" | jq --arg date "$iso_date" '
        [.[] | select(.last_activity_at >= $date)]
    ')
    
    case "$output_format" in
        names)
            echo "$filtered_projects" | jq -r '.[] | .name'
            ;;
        full)
            echo "$filtered_projects" | jq '.'
            ;;
        count)
            echo "$filtered_projects" | jq length
            ;;
        summary)
            echo "$filtered_projects" | jq -r '.[] | "\(.name) - \(.last_activity_at) - \(.visibility)"'
            ;;
        *)
            echo "Error: Invalid format. Use: names, full, count, summary" >&2
            return 1
            ;;
    esac
}

##
# Finds projects where a specific member is involved.
#
# DESCRIPTION:
#   Searches through project data to find projects where a specific user
#   appears as owner, maintainer, or in the namespace. This requires the
#   cache to contain member information from the GitLab API.
#
# PARAMETERS:
#   $1 (string, required) - Username to search for
#   $2 (string, optional) - Output format: "names", "full", "count" (default: "names")
#
find_projects_by_member() {
    local username="$1"
    local output_format="${2:-names}"
    local cache_file
    cache_file=$(get_cache_file_path)
    
    if [ -z "$username" ]; then
        echo "Error: Username required" >&2
        return 1
    fi
    
    if [ ! -f "$cache_file" ]; then
        echo "Error: Cache not initialized. Run init_project_cache first." >&2
        return 1
    fi
    
    # Search for user in owner, namespace, or description fields
    local member_projects
    member_projects=$(cat "$cache_file" | jq --arg user "$username" '
        [.[] | select(
            (.owner.username // "" | ascii_downcase) == ($user | ascii_downcase) or
            (.namespace.path // "" | ascii_downcase) == ($user | ascii_downcase) or
            (.description // "" | ascii_downcase | contains($user | ascii_downcase))
        )]
    ')
    
    case "$output_format" in
        names)
            echo "$member_projects" | jq -r '.[] | .name'
            ;;
        full)
            echo "$member_projects" | jq '.'
            ;;
        count)
            echo "$member_projects" | jq length
            ;;
        summary)
            echo "$member_projects" | jq -r '.[] | "\(.name) - \(.owner.username // "unknown") - \(.last_activity_at)"'
            ;;
        *)
            echo "Error: Invalid format. Use: names, full, count, summary" >&2
            return 1
            ;;
    esac
}

##
# Searches projects by name pattern (case-insensitive).
#
# PARAMETERS:
#   $1 (string, required) - Search pattern (can include wildcards)
#   $2 (string, optional) - Output format: "names", "full", "count" (default: "names")
#
search_projects_by_name() {
    local search_pattern="$1"
    local output_format="${2:-names}"
    local cache_file
    cache_file=$(get_cache_file_path)
    
    if [ -z "$search_pattern" ]; then
        echo "Error: Search pattern required" >&2
        return 1
    fi
    
    if [ ! -f "$cache_file" ]; then
        echo "Error: Cache not initialized. Run init_project_cache first." >&2
        return 1
    fi
    
    # Case-insensitive search with pattern matching
    local matching_projects
    matching_projects=$(cat "$cache_file" | jq --arg pattern "$search_pattern" '
        [.[] | select(.name | ascii_downcase | contains($pattern | ascii_downcase))]
    ')
    
    case "$output_format" in
        names)
            echo "$matching_projects" | jq -r '.[] | .name'
            ;;
        full)
            echo "$matching_projects" | jq '.'
            ;;
        count)
            echo "$matching_projects" | jq length
            ;;
        summary)
            echo "$matching_projects" | jq -r '.[] | "\(.name) - \(.visibility) - \(.last_activity_at)"'
            ;;
        *)
            echo "Error: Invalid format. Use: names, full, count, summary" >&2
            return 1
            ;;
    esac
}

##
# Gets detailed information about a specific project from cache.
#
# PARAMETERS:
#   $1 (string, required) - Project name (exact match, case-insensitive)
#
get_project_details() {
    local project_name="$1"
    local cache_file
    cache_file=$(get_cache_file_path)
    
    if [ -z "$project_name" ]; then
        echo "Error: Project name required" >&2
        return 1
    fi
    
    if [ ! -f "$cache_file" ]; then
        echo "Error: Cache not initialized. Run init_project_cache first." >&2
        return 1
    fi
    
    # Find exact project match (case-insensitive)
    local project_details
    project_details=$(cat "$cache_file" | jq --arg name "$project_name" '
        .[] | select(.name | ascii_downcase == ($name | ascii_downcase))
    ')
    
    if [ -n "$project_details" ] && [ "$project_details" != "null" ]; then
        echo "$project_details" | jq '.'
        return 0
    else
        echo "Error: Project '$project_name' not found in cache" >&2
        return 1
    fi
}

# --- CACHE STATISTICS AND INFORMATION ---

##
# Displays cache statistics and information.
#
show_cache_info() {
    local cache_file
    cache_file=$(get_cache_file_path)
    local metadata_file
    metadata_file=$(get_cache_metadata_path)
    
    echo "📊 GitLab Project Cache Information"
    echo "========================================"
    
    if [ -f "$metadata_file" ]; then
        local metadata
        metadata=$(cat "$metadata_file")
        
        echo "Cache File: $cache_file"
        echo "Created: $(echo "$metadata" | jq -r '.cache_created')"
        echo "Project Count: $(echo "$metadata" | jq -r '.project_count')"
        
        local cache_timestamp
        cache_timestamp=$(echo "$metadata" | jq -r '.cache_timestamp')
        local current_time
        current_time=$(date +%s)
        local age_hours=$(( (current_time - cache_timestamp) / 3600 ))
        echo "Cache Age: ${age_hours} hours"
        
        if [ -f "$cache_file" ]; then
            local file_size
            file_size=$(wc -c < "$cache_file")
            echo "File Size: ${file_size} bytes"
        fi
    else
        echo "❌ Cache not initialized"
        echo "Run: init_project_cache \"\$GITLAB_API_TOKEN\""
    fi
    
    echo "========================================"
}

##
# Lists the most recently updated projects.
#
# PARAMETERS:
#   $1 (integer, optional) - Number of projects to show (default: 10)
#   $2 (string, optional) - Output format: "summary", "names", "full" (default: "summary")
#
list_recent_projects() {
    local limit="${1:-10}"
    local output_format="${2:-summary}"
    local cache_file
    cache_file=$(get_cache_file_path)
    
    if [ ! -f "$cache_file" ]; then
        echo "Error: Cache not initialized. Run init_project_cache first." >&2
        return 1
    fi
    
    local recent_projects
    recent_projects=$(cat "$cache_file" | jq --argjson limit "$limit" '.[:$limit]')
    
    case "$output_format" in
        summary)
            echo "🕒 Recently Updated Projects (Last $limit):"
            echo "$recent_projects" | jq -r '.[] | "\(.name) - \(.last_activity_at) - \(.visibility)"'
            ;;
        names)
            echo "$recent_projects" | jq -r '.[] | .name'
            ;;
        full)
            echo "$recent_projects" | jq '.'
            ;;
        *)
            echo "Error: Invalid format. Use: summary, names, full" >&2
            return 1
            ;;
    esac
}

# --- SAFE PROJECT CREATION WITH DUPLICATE CHECK ---

##
# Creates a new GitLab project after checking for duplicates in cache.
#
# DESCRIPTION:
#   This function combines duplicate checking with project creation. It first
#   checks the local cache for existing projects with the same name, then
#   creates the project via GitLab API if no duplicate is found. After
#   successful creation, it updates the cache with the new project data.
#
# PARAMETERS:
#   $1 (string, required) - Project name
#   $2 (string, required) - GitLab Personal Access Token
#   $3 (string, optional) - Force creation flag ("force" to skip duplicate check)
#
create_project_safe() {
    local project_name="$1"
    local gitlab_pat="$2"
    local force_create="${3:-}"
    
    if [ -z "$project_name" ] || [ -z "$gitlab_pat" ]; then
        echo "Usage: create_project_safe <project_name> <gitlab_pat> [force]" >&2
        return 1
    fi
    
    # Check for duplicates unless force flag is set
    if [ "$force_create" != "force" ]; then
        echo "🔍 Checking for existing projects named '$project_name'..." >&2
        
        if check_project_exists "$project_name" >/dev/null 2>&1; then
            echo "❌ Project '$project_name' already exists!" >&2
            echo "Use 'force' flag to override this check." >&2
            return 1
        else
            echo "✅ Project name '$project_name' is available" >&2
        fi
    fi
    
    # Source the main GitLab API functions if not already loaded
    if ! declare -f make_new_project >/dev/null 2>&1; then
        echo "Error: GitLab API functions not loaded. Source gitlab-api.sh first." >&2
        return 1
    fi
    
    # Create the project
    echo "🏗️ Creating project '$project_name'..." >&2
    local new_project_json
    if new_project_json=$(make_new_project "$project_name" "$gitlab_pat" 2>/dev/null); then
        echo "✅ Project created successfully!" >&2
        
        # Update cache with new project
        if update_project_in_cache "$new_project_json"; then
            echo "✅ Cache updated with new project" >&2
        fi
        
        # Output project details
        echo "$new_project_json" | jq '.'
        return 0
    else
        echo "❌ Failed to create project '$project_name'" >&2
        return 1
    fi
}

# --- ADVANCED SEARCH AND FILTERING ---

##
# Searches projects with multiple criteria.
#
# PARAMETERS:
#   $1 (string, optional) - Name pattern to search for
#   $2 (string, optional) - Visibility filter: "public", "internal", "private"
#   $3 (string, optional) - Updated since date (YYYY-MM-DD)
#   $4 (string, optional) - Updated before date (YYYY-MM-DD)
#   $5 (string, optional) - Output format (default: "summary")
#
search_projects_advanced() {
    local name_pattern="${1:-}"
    local visibility_filter="${2:-}"
    local updated_since="${3:-}"
    local updated_before="${4:-}"
    local output_format="${5:-summary}"
    local cache_file
    cache_file=$(get_cache_file_path)
    
    if [ ! -f "$cache_file" ]; then
        echo "Error: Cache not initialized. Run init_project_cache first." >&2
        return 1
    fi
    
    echo "🔍 Advanced project search..." >&2
    [ -n "$name_pattern" ] && echo "  Name pattern: $name_pattern" >&2
    [ -n "$visibility_filter" ] && echo "  Visibility: $visibility_filter" >&2
    [ -n "$updated_since" ] && echo "  Updated since: $updated_since" >&2
    [ -n "$updated_before" ] && echo "  Updated before: $updated_before" >&2
    
    # Build jq filter expression
    local jq_filter='.'
    
    if [ -n "$name_pattern" ]; then
        jq_filter="$jq_filter | map(select(.name | ascii_downcase | contains(\"${name_pattern,,}\")))"
    fi
    
    if [ -n "$visibility_filter" ]; then
        jq_filter="$jq_filter | map(select(.visibility == \"$visibility_filter\"))"
    fi
    
    if [ -n "$updated_since" ]; then
        local since_iso="${updated_since}T00:00:00.000Z"
        jq_filter="$jq_filter | map(select(.last_activity_at >= \"$since_iso\"))"
    fi
    
    if [ -n "$updated_before" ]; then
        local before_iso="${updated_before}T23:59:59.999Z"
        jq_filter="$jq_filter | map(select(.last_activity_at <= \"$before_iso\"))"
    fi
    
    # Execute search
    local search_results
    search_results=$(cat "$cache_file" | jq "$jq_filter")
    
    local result_count
    result_count=$(echo "$search_results" | jq length)
    echo "📊 Found $result_count matching projects" >&2
    
    case "$output_format" in
        names)
            echo "$search_results" | jq -r '.[] | .name'
            ;;
        full)
            echo "$search_results" | jq '.'
            ;;
        count)
            echo "$result_count"
            ;;
        summary)
            echo "$search_results" | jq -r '.[] | "\(.name) [\(.visibility)] - \(.last_activity_at) - \(.owner.username // "unknown")"'
            ;;
        csv)
            echo "name,visibility,last_activity_at,owner,web_url"
            echo "$search_results" | jq -r '.[] | [.name, .visibility, .last_activity_at, (.owner.username // ""), .web_url] | @csv'
            ;;
        *)
            echo "Error: Invalid format. Use: names, full, count, summary, csv" >&2
            return 1
            ;;
    esac
}

##
# Gets projects grouped by visibility level.
#
get_projects_by_visibility() {
    local cache_file
    cache_file=$(get_cache_file_path)
    
    if [ ! -f "$cache_file" ]; then
        echo "Error: Cache not initialized. Run init_project_cache first." >&2
        return 1
    fi
    
    echo "📊 Projects by Visibility:"
    echo "=========================="
    
    for visibility in "public" "internal" "private"; do
        local count
        count=$(cat "$cache_file" | jq --arg vis "$visibility" '[.[] | select(.visibility == $vis)] | length')
        echo "$visibility: $count projects"
        
        # Show project names for each category
        if [ "$count" -gt 0 ]; then
            cat "$cache_file" | jq -r --arg vis "$visibility" '
                [.[] | select(.visibility == $vis)] | .[] | "  - \(.name)"
            '
        fi
        echo ""
    done
}

# --- UTILITY FUNCTIONS ---

##
# Validates and repairs the cache file if needed.
#
validate_cache() {
    local cache_file
    cache_file=$(get_cache_file_path)
    local metadata_file
    metadata_file=$(get_cache_metadata_path)
    
    echo "🔍 Validating cache integrity..." >&2
    
    if [ ! -f "$cache_file" ]; then
        echo "❌ Cache file missing" >&2
        return 1
    fi
    
    # Test if cache file is valid JSON
    if ! jq empty "$cache_file" 2>/dev/null; then
        echo "❌ Cache file contains invalid JSON" >&2
        return 1
    fi
    
    # Check if cache is an array
    if [ "$(cat "$cache_file" | jq type)" != '"array"' ]; then
        echo "❌ Cache file is not a JSON array" >&2
        return 1
    fi
    
    # Validate metadata
    if [ -f "$metadata_file" ]; then
        if ! jq empty "$metadata_file" 2>/dev/null; then
            echo "⚠️ Metadata file contains invalid JSON" >&2
        fi
    fi
    
    local project_count
    project_count=$(cat "$cache_file" | jq length)
    echo "✅ Cache validation passed: $project_count projects" >&2
    
    return 0
}

##
# Clears the project cache and metadata.
#
clear_cache() {
    local cache_file
    cache_file=$(get_cache_file_path)
    local metadata_file
    metadata_file=$(get_cache_metadata_path)
    
    echo "🗑️ Clearing project cache..." >&2
    
    [ -f "$cache_file" ] && rm "$cache_file"
    [ -f "$metadata_file" ] && rm "$metadata_file"
    
    echo "✅ Cache cleared" >&2
}

##
# Exports cache data in various formats.
#
# PARAMETERS:
#   $1 (string, required) - Export format: "csv", "json", "txt"
#   $2 (string, optional) - Output file path (default: stdout)
#
export_cache() {
    local export_format="$1"
    local output_file="${2:-}"
    local cache_file
    cache_file=$(get_cache_file_path)
    
    if [ -z "$export_format" ]; then
        echo "Usage: export_cache <format> [output_file]" >&2
        echo "Formats: csv, json, txt" >&2
        return 1
    fi
    
    if [ ! -f "$cache_file" ]; then
        echo "Error: Cache not initialized. Run init_project_cache first." >&2
        return 1
    fi
    
    local export_data
    
    case "$export_format" in
        csv)
            export_data="name,id,visibility,last_activity_at,owner_username,web_url,description
$(cat "$cache_file" | jq -r '.[] | [.name, .id, .visibility, .last_activity_at, (.owner.username // ""), .web_url, (.description // "")] | @csv')"
            ;;
        json)
            export_data=$(cat "$cache_file" | jq '.')
            ;;
        txt)
            export_data="GitLab Projects Export - $(date)
========================================
$(cat "$cache_file" | jq -r '.[] | "\(.name) - \(.visibility) - \(.last_activity_at)"')"
            ;;
        *)
            echo "Error: Invalid export format. Use: csv, json, txt" >&2
            return 1
            ;;
    esac
    
    if [ -n "$output_file" ]; then
        echo "$export_data" > "$output_file"
        echo "✅ Cache exported to: $output_file" >&2
    else
        echo "$export_data"
    fi
}

# --- BATCH OPERATIONS ---

##
# Updates multiple projects in the cache from fresh API data.
#
# PARAMETERS:
#   $1 (string, required) - GitLab Personal Access Token
#   $2 (string, optional) - Space-separated list of project names to update
#                          If empty, updates all projects in cache
#
update_specific_projects() {
    local gitlab_pat="$1"
    local project_names="${2:-}"
    local cache_file
    cache_file=$(get_cache_file_path)
    
    if [ -z "$gitlab_pat" ]; then
        echo "Error: GitLab Personal Access Token required" >&2
        return 1
    fi
    
    if [ ! -f "$cache_file" ]; then
        echo "Error: Cache not initialized. Run init_project_cache first." >&2
        return 1
    fi
    
    # If no specific projects provided, update all
    if [ -z "$project_names" ]; then
        echo "🔄 Refreshing all projects in cache..." >&2
        refresh_project_cache "$gitlab_pat"
        return $?
    fi
    
    echo "🔄 Updating specific projects: $project_names" >&2
    
    # Split project names and update each
    for project_name in $project_names; do
        echo "  Updating: $project_name" >&2
        
        # Get project ID from cache
        local project_id
        project_id=$(cat "$cache_file" | jq -r --arg name "$project_name" '
            .[] | select(.name | ascii_downcase == ($name | ascii_downcase)) | .id
        ')
        
        if [ -n "$project_id" ] && [ "$project_id" != "null" ]; then
            # Fetch fresh data for this project
            local fresh_data
            if fresh_data=$(curl -s --header "PRIVATE-TOKEN: $gitlab_pat" \
                "https://gitlab.com/api/v4/projects/$project_id"); then
                
                # Update in cache
                update_project_in_cache "$fresh_data"
            else
                echo "    ❌ Failed to fetch fresh data for $project_name" >&2
            fi
        else
            echo "    ⚠️ Project $project_name not found in cache" >&2
        fi
    done
    
    echo "✅ Project updates completed" >&2
}

##
# Removes projects from cache that no longer exist on GitLab.
#
cleanup_deleted_projects() {
    local gitlab_pat="$1"
    local cache_file
    cache_file=$(get_cache_file_path)
    
    if [ -z "$gitlab_pat" ]; then
        echo "Error: GitLab Personal Access Token required" >&2
        return 1
    fi
    
    if [ ! -f "$cache_file" ]; then
        echo "Error: Cache not initialized. Run init_project_cache first." >&2
        return 1
    fi
    
    echo "🧹 Cleaning up deleted projects from cache..." >&2
    
    local current_projects
    current_projects=$(cat "$cache_file")
    local cleaned_projects="[]"
    local removed_count=0
    
    # Check each project in cache
    echo "$current_projects" | jq -r '.[] | .id' | while read -r project_id; do
        if curl -s --header "PRIVATE-TOKEN: $gitlab_pat" \
            "https://gitlab.com/api/v4/projects/$project_id" \
            | jq -e '.id' >/dev/null 2>&1; then
            # Project still exists, keep it
            continue
        else
            # Project deleted, remove from cache
            local project_name
            project_name=$(echo "$current_projects" | jq -r --arg id "$project_id" '.[] | select(.id == ($id | tonumber)) | .name')
            echo "  Removing deleted project: $project_name" >&2
            ((removed_count++))
        fi
    done
    
    # Rebuild cache without deleted projects
    cleaned_projects=$(echo "$current_projects" | jq '[.[] | select(
        . as $project | 
        ($project.id | tostring) as $id |
        $id | test("^[0-9]+$")  # Only valid numeric IDs
    )]')
    
    echo "$cleaned_projects" > "$cache_file"
    echo "✅ Cleanup completed: $removed_count projects removed" >&2
}

# --- REPORTING FUNCTIONS ---

##
# Generates a comprehensive project activity report.
#
generate_activity_report() {
    local days_back="${1:-30}"
    local cache_file
    cache_file=$(get_cache_file_path)
    
    if [ ! -f "$cache_file" ]; then
        echo "Error: Cache not initialized. Run init_project_cache first." >&2
        return 1
    fi
    
    local since_date
    since_date=$(date -d "$days_back days ago" +%Y-%m-%d 2>/dev/null || date -v-"$days_back"d +%Y-%m-%d 2>/dev/null)
    
    echo "📈 GitLab Project Activity Report"
    echo "=================================="
    echo "Report Date: $(date)"
    echo "Period: Last $days_back days (since $since_date)"
    echo ""
    
    # Activity summary
    local total_projects
    total_projects=$(cat "$cache_file" | jq length)
    local active_projects
    active_projects=$(find_projects_updated_since "$since_date" "count")
    local inactive_projects=$((total_projects - active_projects))
    
    echo "📊 Summary:"
    echo "  Total Projects: $total_projects"
    echo "  Active Projects: $active_projects"
    echo "  Inactive Projects: $inactive_projects"
    echo ""
    
    # Visibility breakdown
    echo "🔒 Visibility Breakdown:"
    for visibility in "public" "internal" "private"; do
        local vis_count
        vis_count=$(cat "$cache_file" | jq --arg vis "$visibility" '[.[] | select(.visibility == $vis)] | length')
        echo "  $visibility: $vis_count projects"
    done
    echo ""
    
    # Recent activity
    echo "🕒 Recent Activity (Last $days_back days):"
    if [ "$active_projects" -gt 0 ]; then
        find_projects_updated_since "$since_date" "summary" | head -20
        [ "$active_projects" -gt 20 ] && echo "  ... and $((active_projects - 20)) more"
    else
        echo "  No recent activity found"
    fi
    echo ""
    
    # Top contributors (by project ownership)
    echo "👥 Top Project Owners:"
    cat "$cache_file" | jq -r '.[] | .owner.username // "unknown"' | \
        sort | uniq -c | sort -nr | head -10 | \
        awk '{printf "  %-20s %d projects\n", $2, $1}'
}

##
# Shows projects that might need attention (very old or inactive).
#
show_stale_projects() {
    local stale_days="${1:-90}"
    local cache_file
    cache_file=$(get_cache_file_path)
    
    if [ ! -f "$cache_file" ]; then
        echo "Error: Cache not initialized. Run init_project_cache first." >&2
        return 1
    fi
    
    local cutoff_date
    cutoff_date=$(date -d "$stale_days days ago" +%Y-%m-%d 2>/dev/null || date -v-"$stale_days"d +%Y-%m-%d 2>/dev/null)
    local cutoff_iso="${cutoff_date}T00:00:00.000Z"
    
    echo "🕰️ Stale Projects (No activity for $stale_days+ days):"
    echo "================================================"
    
    local stale_projects
    stale_projects=$(cat "$cache_file" | jq --arg cutoff "$cutoff_iso" '
        [.[] | select(.last_activity_at < $cutoff)]
    ')
    
    local stale_count
    stale_count=$(echo "$stale_projects" | jq length)
    
    if [ "$stale_count" -eq 0 ]; then
        echo "✅ No stale projects found"
        return 0
    fi
    
    echo "Found $stale_count stale projects:"
    echo ""
    echo "$stale_projects" | jq -r '.[] | "\(.name) - Last updated: \(.last_activity_at) - \(.web_url)"'
}

# --- INTEGRATION HELPERS ---

##
# Quick command to check if a project name is available before creation.
#
# PARAMETERS:
#   $1 (string, required) - Project name to check
#
is_project_name_available() {
    local project_name="$1"
    
    if check_project_exists "$project_name" >/dev/null 2>&1; then
        echo "no"
        return 1
    else
        echo "yes"
        return 0
    fi
}

##
# Lists all project names from cache (useful for autocomplete/scripting).
#
list_all_project_names() {
    local cache_file
    cache_file=$(get_cache_file_path)
    
    if [ ! -f "$cache_file" ]; then
        echo "Error: Cache not initialized. Run init_project_cache first." >&2
        return 1
    fi
    
    cat "$cache_file" | jq -r '.[] | .name' | sort
}

##
# Gets cache statistics for monitoring and debugging.
#
get_cache_stats() {
    local cache_file
    cache_file=$(get_cache_file_path)
    local metadata_file
    metadata_file=$(get_cache_metadata_path)
    
    if [ ! -f "$cache_file" ]; then
        echo "Error: Cache not initialized" >&2
        return 1
    fi
    
    local stats
    stats=$(cat << EOF
{
  "cache_file": "$cache_file",
  "file_exists": $([ -f "$cache_file" ] && echo "true" || echo "false"),
  "file_size_bytes": $(wc -c < "$cache_file" 2>/dev/null || echo 0),
  "project_count": $(cat "$cache_file" | jq length 2>/dev/null || echo 0),
  "cache_directory": "$(get_cache_directory)",
  "last_modified": "$(date -r "$cache_file" +%Y-%m-%dT%H:%M:%S.000Z 2>/dev/null || echo "unknown")"
}
EOF
)
    
    echo "$stats" | jq '.'
}

# --- MAIN EXECUTION SUPPORT ---

##
# Main function for command-line usage of the cache system.
#
# USAGE:
#   bash gitlab-project-cache.sh init <token>
#   bash gitlab-project-cache.sh search <pattern>
#   bash gitlab-project-cache.sh check <project-name>
#
main() {
    local command="${1:-help}"
    
    case "$command" in
        init)
            local token="${2:-}"
            if [ -z "$token" ]; then
                echo "Usage: $0 init <gitlab_token>" >&2
                exit 1
            fi
            init_project_cache "$token"
            ;;
        refresh)
            local token="${2:-}"
            if [ -z "$token" ]; then
                echo "Usage: $0 refresh <gitlab_token>" >&2
                exit 1
            fi
            refresh_project_cache "$token"
            ;;
        check)
            local project_name="${2:-}"
            if [ -z "$project_name" ]; then
                echo "Usage: $0 check <project_name>" >&2
                exit 1
            fi
            if check_project_exists "$project_name" >/dev/null; then
                echo "Project '$project_name' exists"
                exit 0
            else
                echo "Project '$project_name' not found"
                exit 1
            fi
            ;;
        search)
            local pattern="${2:-}"
            if [ -z "$pattern" ]; then
                echo "Usage: $0 search <pattern>" >&2
                exit 1
            fi
            search_projects_by_name "$pattern" "summary"
            ;;
        recent)
            local limit="${2:-10}"
            list_recent_projects "$limit" "summary"
            ;;
        info)
            show_cache_info
            ;;
        stats)
            get_cache_stats
            ;;
        export)
            local format="${2:-csv}"
            local output="${3:-}"
            export_cache "$format" "$output"
            ;;
        report)
            local days="${2:-30}"
            generate_activity_report "$days"
            ;;
        stale)
            local days="${2:-90}"
            show_stale_projects "$days"
            ;;
        validate)
            validate_cache
            ;;
        clear)
            clear_cache
            ;;
        help|*)
            cat << 'EOF'
GitLab Project Cache System

USAGE:
    source ./gitlab-project-cache.sh    # Load functions
    bash gitlab-project-cache.sh <command> [args...]

COMMANDS:
    init <token>           Initialize cache with GitLab data
    refresh <token>        Force refresh cache from GitLab API
    check <project>        Check if project exists
    search <pattern>       Search projects by name pattern
    recent [limit]         Show recently updated projects
    info                   Show cache information
    stats                  Show detailed cache statistics
    export <format> [file] Export cache (csv, json, txt)
    report [days]          Generate activity report
    stale [days]           Show projects with no recent activity
    validate               Validate cache integrity
    clear                  Clear cache completely
    help                   Show this help message

EXAMPLES:
    # Initialize cache
    bash gitlab-project-cache.sh init "glpat-xxxxxxxxxxxxxxxxxxxx"
    
    # Check if project exists before creating
    bash gitlab-project-cache.sh check "my-new-project"
    
    # Search for API-related projects
    bash gitlab-project-cache.sh search "api"
    
    # Export to CSV
    bash gitlab-project-cache.sh export csv projects.csv
    
    # Generate 30-day activity report
    bash gitlab-project-cache.sh report 30

INTEGRATION EXAMPLES:
    # In scripts - check before creating
    if [ "$(is_project_name_available "new-project")" = "yes" ]; then
        create_project_safe "new-project" "$GITLAB_API_TOKEN"
    fi
    
    # Find projects by team member
    find_projects_by_member "john.doe" "summary"
    
    # Advanced search
    search_projects_advanced "api" "private" "2025-08-01" "" "csv"

EOF
            exit 0
            ;;
    esac
}

# Allow script to be run directly or sourced
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # Make sure gitlab-api.sh is available
    if [ -f "./gitlab-api.sh" ]; then
        source ./gitlab-api.sh
    elif [ -f "../gitlab-api.sh" ]; then
        source ../gitlab-api.sh
    else
        echo "Error: gitlab-api.sh not found. Please ensure it's in the current directory." >&2
        exit 1
    fi
    
    main "$@"
fi