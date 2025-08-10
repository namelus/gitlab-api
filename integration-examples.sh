#!/bin/bash

# ==============================================================================
# GitLab Project Cache - Integration Examples
# ==============================================================================
#
# This script demonstrates how to integrate the GitLab Project Cache system
# with your existing GitLab API Helper for common workflow scenarios.
#
# Run this script to see example workflows in action, or source it to use
# the integration functions in your own scripts.
#
# REQUIREMENTS:
# - gitlab-api.sh (your existing GitLab API functions)
# - gitlab-project-cache.sh (the new caching system)
# - Valid GitLab Personal Access Token
#
# ==============================================================================

# Source required libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try to find and source the required scripts
if [ -f "$SCRIPT_DIR/gitlab-api.sh" ]; then
    source "$SCRIPT_DIR/gitlab-api.sh"
elif [ -f "./gitlab-api.sh" ]; then
    source ./gitlab-api.sh
else
    echo "Error: gitlab-api.sh not found" >&2
    exit 1
fi

if [ -f "$SCRIPT_DIR/gitlab-project-cache.sh" ]; then
    source "$SCRIPT_DIR/gitlab-project-cache.sh"
elif [ -f "./gitlab-project-cache.sh" ]; then
    source ./gitlab-project-cache.sh
else
    echo "Error: gitlab-project-cache.sh not found" >&2
    exit 1
fi

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

demo_log() {
    echo -e "${BLUE}[DEMO]${NC} $1"
}

demo_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

demo_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

demo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ==============================================================================
# INTEGRATION WORKFLOW FUNCTIONS
# ==============================================================================

##
# Complete workflow: Check cache, create project if available, update cache
#
create_project_with_cache_check() {
    local project_name="$1"
    local gitlab_pat="$2"
    local project_description="${3:-Created via GitLab API Helper with cache check}"
    
    demo_log "Starting project creation workflow for: $project_name"
    
    # Step 1: Ensure cache is initialized
    if [ ! -f "$(get_cache_file_path)" ]; then
        demo_log "Cache not found, initializing..."
        if ! init_project_cache "$gitlab_pat"; then
            demo_error "Failed to initialize cache"
            return 1
        fi
    fi
    
    # Step 2: Check if project already exists
    demo_log "Checking for existing project: $project_name"
    if check_project_exists "$project_name" >/dev/null 2>&1; then
        demo_error "Project '$project_name' already exists!"
        demo_log "Showing existing project details:"
        get_project_details "$project_name"
        return 1
    fi
    
    demo_success "Project name '$project_name' is available"
    
    # Step 3: Create the project
    demo_log "Creating project via GitLab API..."
    local new_project
    if new_project=$(make_new_project "$project_name" "$gitlab_pat" 2>/dev/null); then
        demo_success "Project created successfully!"
        
        # Step 4: Update cache with new project
        demo_log "Updating local cache..."
        if update_project_in_cache "$new_project"; then
            demo_success "Cache updated with new project"
        fi
        
        # Step 5: Show project details
        echo "$new_project" | jq '{name, id, web_url, ssh_url_to_repo, visibility}'
        
        return 0
    else
        demo_error "Failed to create project"
        return 1
    fi
}

##
# Finds team projects by searching for multiple team members
#
find_team_projects() {
    local team_members=("$@")
    
    if [ ${#team_members[@]} -eq 0 ]; then
        echo "Usage: find_team_projects <member1> [member2] [member3] ..." >&2
        return 1
    fi
    
    demo_log "Searching for projects involving team members: ${team_members[*]}"
    
    local all_team_projects="[]"
    
    # Search for each team member
    for member in "${team_members[@]}"; do
        demo_log "Searching projects for: $member"
        local member_projects
        member_projects=$(find_projects_by_member "$member" "full" 2>/dev/null || echo "[]")
        
        # Merge with existing results (avoid duplicates by ID)
        all_team_projects=$(echo "$all_team_projects $member_projects" | jq -s '
            .[0] + .[1] | unique_by(.id) | sort_by(.last_activity_at) | reverse
        ')
    done
    
    local total_count
    total_count=$(echo "$all_team_projects" | jq length)
    
    demo_success "Found $total_count projects involving team members"
    
    # Display results
    if [ "$total_count" -gt 0 ]; then
        echo ""
        echo "🏗️ Team Projects:"
        echo "$all_team_projects" | jq -r '.[] | "  \(.name) - \(.owner.username) - \(.last_activity_at)"'
        
        # Show breakdown by member
        echo ""
        echo "👥 Breakdown by Member:"
        for member in "${team_members[@]}"; do
            local member_count
            member_count=$(find_projects_by_member "$member" "count" 2>/dev/null || echo "0")
            echo "  $member: $member_count projects"
        done
    fi
    
    return 0
}

##
# Smart project creation that suggests similar names if conflicts exist
#
smart_project_creation() {
    local base_name="$1"
    local gitlab_pat="$2"
    
    demo_log "Smart project creation for: $base_name"
    
    # Check if exact name is available
    if [ "$(is_project_name_available "$base_name")" = "yes" ]; then
        demo_success "Exact name available: $base_name"
        create_project_with_cache_check "$base_name" "$gitlab_pat"
        return $?
    fi
    
    demo_warning "Project name '$base_name' is not available"
    
    # Suggest alternatives
    demo_log "Generating alternative names..."
    local suggestions=()
    local timestamp
    timestamp=$(date +%Y%m%d)
    
    # Try various naming strategies
    local alternatives=(
        "${base_name}-v2"
        "${base_name}-new"
        "${base_name}-${timestamp}"
        "${base_name}-$(whoami)"
        "new-${base_name}"
        "${base_name}-project"
    )
    
    echo ""
    echo "💡 Suggested alternatives:"
    for alt in "${alternatives[@]}"; do
        if [ "$(is_project_name_available "$alt")" = "yes" ]; then
            echo "  ✅ $alt (available)"
            suggestions+=("$alt")
        else
            echo "  ❌ $alt (taken)"
        fi
    done
    
    if [ ${#suggestions[@]} -gt 0 ]; then
        echo ""
        echo "🎯 Recommend using: ${suggestions[0]}"
        echo ""
        read -p "Create project with name '${suggestions[0]}'? (y/N): " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            create_project_with_cache_check "${suggestions[0]}" "$gitlab_pat"
            return $?
        fi
    else
        demo_error "No available alternatives found"
        echo "💡 Try a completely different name"
    fi
    
    return 1
}

##
# Generates a development team dashboard
#
generate_team_dashboard() {
    local team_members=("$@")
    
    if [ ${#team_members[@]} -eq 0 ]; then
        echo "Usage: generate_team_dashboard <member1> [member2] ..." >&2
        return 1
    fi
    
    echo "📊 GitLab Team Dashboard"
    echo "======================="
    echo "Generated: $(date)"
    echo "Team Members: ${team_members[*]}"
    echo ""
    
    # Overall statistics
    local total_projects
    total_projects=$(cat "$(get_cache_file_path)" | jq length)
    echo "📈 Statistics:"
    echo "  Total Projects in GitLab: $total_projects"
    
    # Team activity summary
    local team_project_count=0
    local active_last_week=0
    local active_last_month=0
    
    local week_ago
    week_ago=$(date -d "7 days ago" +%Y-%m-%d 2>/dev/null || date -v-7d +%Y-%m-%d)
    local month_ago
    month_ago=$(date -d "30 days ago" +%Y-%m-%d 2>/dev/null || date -v-30d +%Y-%m-%d)
    
    for member in "${team_members[@]}"; do
        local member_projects
        member_projects=$(find_projects_by_member "$member" "count" 2>/dev/null || echo "0")
        team_project_count=$((team_project_count + member_projects))
        
        echo "  $member: $member_projects projects"
    done
    
    echo "  Team Total: $team_project_count projects"
    echo ""
    
    # Recent activity
    echo "🕒 Recent Team Activity:"
    echo "  Last 7 days:"
    active_last_week=$(find_projects_updated_since "$week_ago" "count" 2>/dev/null || echo "0")
    echo "    $active_last_week projects updated"
    
    echo "  Last 30 days:"
    active_last_month=$(find_projects_updated_since "$month_ago" "count" 2>/dev/null || echo "0")
    echo "    $active_last_month projects updated"
    echo ""
    
    # Most active projects
    echo "🔥 Most Recently Active Projects:"
    find_projects_updated_since "$month_ago" "summary" 2>/dev/null | head -5 | sed 's/^/  /'
    echo ""
    
    # Project visibility breakdown
    echo "🔒 Project Visibility:"
    get_projects_by_visibility 2>/dev/null | grep -E "(public|internal|private):" | sed 's/^/  /'
}

# ==============================================================================
# MAINTENANCE AND MONITORING FUNCTIONS
# ==============================================================================

##
# Performs routine cache maintenance
#
maintain_cache() {
    local gitlab_pat="$1"
    
    demo_log "Starting cache maintenance routine..."
    
    # Step 1: Validate cache integrity
    demo_log "Validating cache integrity..."
    if ! validate_cache >/dev/null 2>&1; then
        demo_warning "Cache validation failed, rebuilding..."
        init_project_cache "$gitlab_pat" "force"
    else
        demo_success "Cache validation passed"
    fi
    
    # Step 2: Check cache age
    local metadata_file
    metadata_file=$(get_cache_metadata_path)
    if [ -f "$metadata_file" ]; then
        local cache_timestamp
        cache_timestamp=$(jq -r '.cache_timestamp // 0' "$metadata_file")
        local current_time
        current_time=$(date +%s)
        local age_hours=$(( (current_time - cache_timestamp) / 3600 ))
        
        if [ $age_hours -gt 24 ]; then
            demo_log "Cache is $age_hours hours old, refreshing..."
            refresh_project_cache "$gitlab_pat"
        else
            demo_log "Cache is recent ($age_hours hours old)"
        fi
    fi
    
    # Step 3: Clean up deleted projects
    demo_log "Checking for deleted projects..."
    cleanup_deleted_projects "$gitlab_pat" 2>/dev/null || demo_warning "Cleanup check failed (may be rate limited)"
    
    # Step 4: Show final status
    show_cache_info
    
    demo_success "Cache maintenance completed"
}

##
# Monitors cache for changes and provides alerts
#
monitor_cache_changes() {
    local gitlab_pat="$1"
    local check_interval="${2:-300}"  # 5 minutes default
    
    demo_log "Starting cache monitoring (checking every ${check_interval}s)"
    demo_log "Press Ctrl+C to stop monitoring"
    
    local previous_count=0
    if [ -f "$(get_cache_file_path)" ]; then
        previous_count=$(cat "$(get_cache_file_path)" | jq length)
    fi
    
    while true; do
        sleep "$check_interval"
        
        # Refresh cache
        if refresh_project_cache "$gitlab_pat" >/dev/null 2>&1; then
            local current_count
            current_count=$(cat "$(get_cache_file_path)" | jq length)
            
            if [ "$current_count" -ne "$previous_count" ]; then
                local change=$((current_count - previous_count))
                if [ $change -gt 0 ]; then
                    demo_success "🆕 $change new projects detected!"
                    list_recent_projects 3 "summary"
                else
                    demo_warning "🗑️ $((0 - change)) projects removed"
                fi
                previous_count=$current_count
            else
                demo_log "No changes detected ($current_count projects)"
            fi
        else
            demo_error "Failed to refresh cache"
        fi
    done
}

# ==============================================================================
# DEMONSTRATION WORKFLOWS
# ==============================================================================

##
# Demo 1: Safe project creation workflow
#
demo_safe_project_creation() {
    local gitlab_pat="$1"
    
    echo "🎯 Demo 1: Safe Project Creation Workflow"
    echo "=========================================="
    
    # Ensure cache is ready
    demo_log "Initializing cache..."
    init_project_cache "$gitlab_pat" >/dev/null 2>&1
    
    # Test project names
    local test_projects=("demo-project-$(date +%s)" "existing-project" "test-api-client")
    
    for project_name in "${test_projects[@]}"; do
        echo ""
        demo_log "Testing project creation: $project_name"
        
        # Check availability
        if [ "$(is_project_name_available "$project_name")" = "yes" ]; then
            demo_success "✅ Name available: $project_name"
            echo "  Would create project here..."
            # Uncomment to actually create:
            # create_project_safe "$project_name" "$gitlab_pat"
        else
            demo_warning "❌ Name unavailable: $project_name"
            demo_log "Showing existing project details:"
            get_project_details "$project_name" 2>/dev/null | jq '{name, web_url, last_activity_at}' || echo "  Details not available"
        fi
    done
}

##
# Demo 2: Team collaboration analysis
#
demo_team_analysis() {
    local gitlab_pat="$1"
    shift
    local team_members=("$@")
    
    echo ""
    echo "👥 Demo 2: Team Collaboration Analysis"
    echo "======================================"
    
    if [ ${#team_members[@]} -eq 0 ]; then
        # Use some default team members for demo
        team_members=("$(whoami)" "admin" "developer")
        demo_log "Using demo team members: ${team_members[*]}"
    fi
    
    # Ensure cache is ready
    init_project_cache "$gitlab_pat" >/dev/null 2>&1
    
    # Generate team dashboard
    generate_team_dashboard "${team_members[@]}"
    
    echo ""
    demo_log "Individual member breakdown:"
    for member in "${team_members[@]}"; do
        local project_count
        project_count=$(find_projects_by_member "$member" "count" 2>/dev/null || echo "0")
        echo "  $member: $project_count projects"
        
        if [ "$project_count" -gt 0 ]; then
            demo_log "Recent projects for $member:"
            find_projects_by_member "$member" "summary" 2>/dev/null | head -3 | sed 's/^/    /'
        fi
    done
}

##
# Demo 3: Activity monitoring and reporting
#
demo_activity_monitoring() {
    local gitlab_pat="$1"
    
    echo ""
    echo "📈 Demo 3: Activity Monitoring & Reporting"
    echo "=========================================="
    
    # Ensure cache is ready
    init_project_cache "$gitlab_pat" >/dev/null 2>&1
    
    # Show recent activity
    demo_log "Recent project activity (last 10 projects):"
    list_recent_projects 10 "summary"
    
    echo ""
    
    # Activity by time periods
    local periods=("7" "30" "90")
    echo "📅 Activity by time periods:"
    for days in "${periods[@]}"; do
        local count
        local since_date
        since_date=$(date -d "$days days ago" +%Y-%m-%d 2>/dev/null || date -v-"$days"d +%Y-%m-%d)
        count=$(find_projects_updated_since "$since_date" "count" 2>/dev/null || echo "0")
        echo "  Last $days days: $count projects"
    done
    
    echo ""
    
    # Show stale projects
    demo_log "Checking for stale projects (no activity in 60+ days)..."
    show_stale_projects 60 | head -10
}

##
# Demo 4: Data export and integration
#
demo_data_export() {
    local gitlab_pat="$1"
    
    echo ""
    echo "💾 Demo 4: Data Export & Integration"
    echo "==================================="
    
    # Ensure cache is ready
    init_project_cache "$gitlab_pat" >/dev/null 2>&1
    
    local cache_dir
    cache_dir=$(get_cache_directory)
    
    demo_log "Exporting project data to multiple formats..."
    
    # Export to CSV
    local csv_file="$cache_dir/projects_export.csv"
    export_cache "csv" "$csv_file"
    demo_success "CSV export: $csv_file"
    
    # Export recent projects as JSON
    local json_file="$cache_dir/recent_projects.json"
    find_projects_updated_since "$(date -d '30 days ago' +%Y-%m-%d)" "full" > "$json_file"
    demo_success "Recent projects JSON: $json_file"
    
    # Export text summary
    local txt_file="$cache_dir/project_summary.txt"
    generate_activity_report 30 > "$txt_file"
    demo_success "Activity report: $txt_file"
    
    echo ""
    demo_log "Export files created in: $cache_dir"
    ls -la "$cache_dir"/*.csv "$cache_dir"/*.json "$cache_dir"/*.txt 2>/dev/null | sed 's/^/  /' || echo "  No export files found"
}

# ==============================================================================
# PRACTICAL UTILITY FUNCTIONS
# ==============================================================================

##
# Bulk project operations based on search criteria
#
bulk_project_operations() {
    local operation="$1"
    local search_criteria="$2"
    local gitlab_pat="$3"
    
    case "$operation" in
        "list-stale")
            local days="${search_criteria:-90}"
            demo_log "Finding projects with no activity for $days+ days..."
            show_stale_projects "$days"
            ;;
        "list-by-visibility")
            local visibility="$search_criteria"
            demo_log "Finding $visibility projects..."
            search_projects_advanced "" "$visibility" "" "" "summary"
            ;;
        "recent-activity")
            local days="${search_criteria:-7}"
            local since_date
            since_date=$(date -d "$days days ago" +%Y-%m-%d 2>/dev/null || date -v-"$days"d +%Y-%m-%d)
            demo_log "Projects with activity in last $days days..."
            find_projects_updated_since "$since_date" "summary"
            ;;
        *)
            echo "Available operations: list-stale, list-by-visibility, recent-activity" >&2
            return 1
            ;;
    esac
}

##
# Interactive project explorer
#
interactive_project_explorer() {
    local gitlab_pat="$1"
    
    # Ensure cache is ready
    if ! validate_cache >/dev/null 2>&1; then
        demo_log "Initializing cache for interactive mode..."
        init_project_cache "$gitlab_pat"
    fi
    
    echo "🔍 Interactive Project Explorer"
    echo "==============================="
    echo "Commands: search, recent, member, create, export, stats, help, quit"
    echo ""
    
    while true; do
        echo -n "gitlab-cache> "
        read -r input
        
        if [ -z "$input" ]; then
            continue
        fi
        
        # Parse command and arguments
        read -ra cmd_parts <<< "$input"
        local command="${cmd_parts[0]}"
        local args=("${cmd_parts[@]:1}")
        
        case "$command" in
            search|s)
                if [ ${#args[@]} -eq 0 ]; then
                    echo "Usage: search <pattern>"
                    continue
                fi
                search_projects_by_name "${args[0]}" "summary"
                ;;
            recent|r)
                local limit="${args[0]:-10}"
                list_recent_projects "$limit" "summary"
                ;;
            member|m)
                if [ ${#args[@]} -eq 0 ]; then
                    echo "Usage: member <username>"
                    continue
                fi
                find_projects_by_member "${args[0]}" "summary"
                ;;
            create|c)
                if [ ${#args[@]} -eq 0 ]; then
                    echo "Usage: create <project-name>"
                    continue
                fi
                smart_project_creation "${args[0]}" "$gitlab_pat"
                ;;
            export|e)
                local format="${args[0]:-csv}"
                export_cache "$format"
                ;;
            stats|info)
                show_cache_info
                ;;
            refresh)
                demo_log "Refreshing cache from GitLab API..."
                refresh_project_cache "$gitlab_pat"
                ;;
            help|h)
                echo "Available commands:"
                echo "  search <pattern>  - Search projects by name"
                echo "  recent [limit]    - Show recent projects"
                echo "  member <user>     - Find projects by member"
                echo "  create <name>     - Smart project creation"
                echo "  export [format]   - Export cache data"
                echo "  stats             - Show cache statistics"
                echo "  refresh           - Refresh cache from API"
                echo "  quit              - Exit explorer"
                ;;
            quit|q|exit)
                echo "👋 Goodbye!"
                break
                ;;
            *)
                echo "Unknown command: $command. Type 'help' for available commands."
                ;;
        esac
        echo ""
    done
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

main() {
    local command="${1:-demo}"
    
    # Get token from environment or prompt
    local gitlab_pat
    if gitlab_pat=$(get_env_variable "GITLAB_API_TOKEN" 2>/dev/null); then
        demo_log "Using GitLab token from ~/.env"
    else
        echo "GitLab token not found in ~/.env"
        read -p "Enter GitLab Personal Access Token: " gitlab_pat
        if [ -z "$gitlab_pat" ]; then
            echo "Error: Token required for API operations" >&2
            exit 1
        fi
    fi
    
    case "$command" in
        demo)
            echo "🚀 GitLab Project Cache - Full Demo"
            echo "==================================="
            demo_safe_project_creation "$gitlab_pat"
            demo_team_analysis "$gitlab_pat" "$(whoami)" "admin"
            demo_activity_monitoring "$gitlab_pat"
            demo_data_export "$gitlab_pat"
            echo ""
            demo_success "🎉 All demos completed!"
            ;;
        interactive|i)
            interactive_project_explorer "$gitlab_pat"
            ;;
        setup)
            demo_log "Setting up GitLab Project Cache..."
            init_project_cache "$gitlab_pat"
            show_cache_info
            ;;
        maintain)
            maintain_cache "$gitlab_pat"
            ;;
        team)
            shift
            local team_members=("$@")
            if [ ${#team_members[@]} -eq 0 ]; then
                team_members=("$(whoami)")
            fi
            generate_team_dashboard "${team_members[@]}"
            ;;
        create)
            local project_name="${2:-}"
            if [ -z "$project_name" ]; then
                echo "Usage: $0 create <project_name>" >&2
                exit 1
            fi
            smart_project_creation "$project_name" "$gitlab_pat"
            ;;
        monitor)
            local interval="${2:-300}"
            monitor_cache_changes "$gitlab_pat" "$interval"
            ;;
        help|*)
            cat << 'EOF'
GitLab Project Cache - Integration Examples

USAGE:
    bash integration-examples.sh <command> [args...]

COMMANDS:
    demo                   Run all demonstration workflows
    interactive            Start interactive project explorer
    setup                  Initialize cache system
    maintain               Perform cache maintenance
    team [members...]      Generate team dashboard
    create <name>          Smart project creation with conflict checking
    monitor [interval]     Monitor cache for changes
    help                   Show this help

WORKFLOW EXAMPLES:

1. INITIAL SETUP:
    bash integration-examples.sh setup

2. SAFE PROJECT CREATION:
    bash integration-examples.sh create "my-new-api"

3. TEAM ANALYSIS:
    bash integration-examples.sh team alice bob charlie

4. INTERACTIVE EXPLORATION:
    bash integration-examples.sh interactive

5. AUTOMATED MONITORING:
    bash integration-examples.sh monitor 600  # Check every 10 minutes

INTEGRATION IN YOUR SCRIPTS:

    # Source the libraries
    source ./gitlab-api.sh
    source ./gitlab-project-cache.sh
    source ./integration-examples.sh
    
    # Initialize cache
    init_project_cache "$GITLAB_API_TOKEN"
    
    # Check before creating
    if [ "$(is_project_name_available "new-project")" = "yes" ]; then
        create_project_safe "new-project" "$GITLAB_API_TOKEN"
    fi
    
    # Find team projects
    find_team_projects "alice" "bob" "charlie"
    
    # Export for external analysis
    export_cache "csv" "projects.csv"

EOF
            ;;
    esac
}

# Allow script to be run directly or sourced
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi