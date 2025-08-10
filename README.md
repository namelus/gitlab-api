# GitLab API Helper Library

A comprehensive Bash library for securely managing GitLab Personal Access Tokens and interacting with the GitLab REST API v4. This library provides robust token management, project creation, project listing capabilities, and **advanced local project caching** with cross-platform compatibility.

## 🚀 Features

### Core API Features
- **Secure Token Management**: Store and retrieve GitLab PATs with proper file permissions
- **Project Operations**: Create new projects with comprehensive error handling
- **Advanced Project Listing**: List projects with filtering, pagination, and multiple output formats
- **Cross-Platform Support**: Works on Linux, macOS, and Windows (Git Bash/WSL)
- **Robust Error Handling**: Detailed error messages and troubleshooting guidance
- **Multiple Output Formats**: Raw text, CSV, and JSON output options
- **Security-First Design**: No token exposure in logs or output

### 🆕 **New: Project Cache System**
- **Local Project Caching**: Store project data in AppData folder for offline access
- **Duplicate Prevention**: Check for existing projects before creation
- **Advanced Search**: Find projects by date ranges, team members, and patterns
- **Team Collaboration**: Track which projects team members are working on
- **Activity Monitoring**: Generate reports and find stale projects
- **Smart Project Creation**: Suggests alternatives when names conflict
- **Data Export**: Export cache to CSV, JSON, or text formats
- **Cross-Platform Storage**: Automatic AppData folder detection for all OS types

## 📁 Repository Structure

```
gitlab-api-helper/
├── 📄 gitlab-api.sh                       # Core GitLab API functions
├── 📄 gitlab-project-cache.sh             # Project caching system
├── 📄 integration-examples.sh             # Cache integration examples
├── 📄 README.md                           # This documentation
├── 📁 .githooks/                          # Git hooks for code quality
├── 📁 hooks/                              # Hook utilities and testing
├── 📁 scripts/                            # Setup and utility scripts
└── 📄 debug-precommit.sh                  # Debugging utilities
```

### Cache Storage Locations
- **Windows**: `%APPDATA%/gitlab-api-helper/`
- **Linux**: `~/.local/share/gitlab-api-helper/`
- **macOS**: `~/Library/Application Support/gitlab-api-helper/`

## 📋 Requirements

### System Dependencies
- **bash** (version 3.0 or higher)
- **curl** (for HTTP requests to GitLab API)
- **jq** (for JSON processing and formatting)
- **sed** and **grep** (for file manipulation)

### GitLab Requirements
- GitLab.com account or self-hosted GitLab instance
- Personal Access Token with appropriate scopes:
  - `api` scope for project creation
  - `read_api` scope for project listing

## 🛠 Installation

### Method 1: Clone Repository (Recommended)
```bash
git clone https://gitlab.com/your-username/gitlab-api-helper.git
cd gitlab-api-helper

# Set up Git hooks (optional but recommended)
./scripts/setup-hooks.sh

# Load the functions
source ./gitlab-api.sh
source ./gitlab-project-cache.sh
```

### Method 2: Direct Download
```bash
# Download the core scripts
wget https://gitlab.com/your-username/gitlab-api-helper/-/raw/main/gitlab-api.sh
wget https://gitlab.com/your-username/gitlab-api-helper/-/raw/main/gitlab-project-cache.sh

# Make them executable
chmod +x gitlab-api.sh gitlab-project-cache.sh

# Source the functions
source ./gitlab-api.sh
source ./gitlab-project-cache.sh
```

### Dependency Installation

#### Ubuntu/Debian
```bash
sudo apt update
sudo apt install curl jq
```

#### macOS
```bash
# Using Homebrew
brew install curl jq

# Using MacPorts
sudo port install curl jq
```

#### Windows (Git Bash)
```bash
# jq is often pre-installed with Git for Windows
# If not available, download from: https://stedolan.github.io/jq/download/
```

## 🔧 Quick Start

### 1. Set Up Your GitLab Token
```bash
# Source the library
source ./gitlab-api.sh

# Store your GitLab Personal Access Token securely
input_token "GITLAB_API_TOKEN"
# Enter value for GITLAB_API_TOKEN: glpat-xxxxxxxxxxxxxxxxxxxx
# GITLAB_API_TOKEN successfully stored in ~/.env
```

### 2. Initialize Project Cache
```bash
# Load cache functions
source ./gitlab-project-cache.sh

# Get your token
token=$(get_env_variable "GITLAB_API_TOKEN")

# Initialize the cache (fetches all your projects)
init_project_cache "$token"
# ✅ Cache initialized with 42 projects
# 📁 Cache location: /Users/you/.local/share/gitlab-api-helper/projects-cache.json
```

### 3. Use Cache Features
```bash
# Check if a project already exists before creating
check_project_exists "my-new-project"

# Find projects updated in the last 30 days
find_projects_updated_since "2025-07-11" "summary"

# Find projects by team member
find_projects_by_member "john.doe" "summary"

# Safe project creation with duplicate checking
create_project_safe "my-awesome-project" "$token"
```

## 📚 Function Reference

### 🔑 Token Management Functions

#### `input_token(token_name)`
Interactively prompts for and securely stores a GitLab Personal Access Token.

#### `get_env_variable(variable_name)`
Retrieves an environment variable value from ~/.env file.

#### `update_env_file(variable_name, variable_value)`
Programmatically updates or adds environment variables to ~/.env file.

### 🌐 GitLab API Functions

#### `make_new_project(project_name, gitlab_pat)`
Creates a new project in GitLab with comprehensive error handling.

#### `get_list_of_projects(gitlab_pat, [format], [date_filter], [visibility])`
Lists GitLab projects with advanced filtering and multiple output formats.

#### `get_list_of_projects_simple(gitlab_pat)`
Simplified project listing for debugging and testing.

### 🗄️ **New: Cache Management Functions**

#### `init_project_cache(gitlab_pat, [force])`
Initializes the project cache by fetching all projects from GitLab API.
```bash
init_project_cache "$GITLAB_API_TOKEN"           # Normal init
init_project_cache "$GITLAB_API_TOKEN" "force"   # Force refresh
```

#### `check_project_exists(project_name)`
Checks if a project with the given name already exists in cache.
```bash
if check_project_exists "my-project" >/dev/null; then
    echo "Project exists!"
fi
```

#### `find_projects_updated_since(since_date, [format])`
Finds projects updated after a specific date.
```bash
find_projects_updated_since "2025-08-01" "summary"
find_projects_updated_since "2025-07-01" "names"
find_projects_updated_since "2025-06-01" "count"
```

#### `find_projects_by_member(username, [format])`
Finds projects where a specific member is involved.
```bash
find_projects_by_member "john.doe" "summary"
find_projects_by_member "alice" "full"
```

#### `search_projects_by_name(pattern, [format])`
Searches projects by name pattern (case-insensitive).
```bash
search_projects_by_name "api" "summary"
search_projects_by_name "frontend" "names"
```

#### `create_project_safe(project_name, gitlab_pat, [force])`
Creates a project after checking for duplicates in cache.
```bash
create_project_safe "new-project" "$GITLAB_API_TOKEN"
create_project_safe "duplicate-name" "$GITLAB_API_TOKEN" "force"
```

#### `search_projects_advanced(name_pattern, visibility, updated_since, updated_before, format)`
Advanced search with multiple criteria.
```bash
# Find private API projects updated since August 1st
search_projects_advanced "api" "private" "2025-08-01" "" "summary"

# Find all public projects updated in July
search_projects_advanced "" "public" "2025-07-01" "2025-07-31" "csv"
```

#### Cache Utility Functions
- `refresh_project_cache(gitlab_pat)` - Force refresh entire cache
- `show_cache_info()` - Display cache statistics and location
- `list_recent_projects([limit], [format])` - Show most recently updated projects
- `export_cache(format, [output_file])` - Export cache data
- `validate_cache()` - Validate cache integrity
- `clear_cache()` - Clear all cache data

## 💼 Usage Examples

### Basic Cache Workflow
```bash
#!/bin/bash

# Load the libraries
source ./gitlab-api.sh
source ./gitlab-project-cache.sh

# Set up token (first time only)
input_token "GITLAB_API_TOKEN"

# Load token from environment
token=$(get_env_variable "GITLAB_API_TOKEN")

# Initialize cache
init_project_cache "$token"

# Check before creating a project
if [ "$(is_project_name_available "my-new-api")" = "yes" ]; then
    echo "Creating new project..."
    create_project_safe "my-new-api" "$token"
else
    echo "Project name already taken!"
fi
```

### Team Collaboration Analysis
```bash
#!/bin/bash
source ./gitlab-api.sh
source ./gitlab-project-cache.sh

# Load token
token=$(get_env_variable "GITLAB_API_TOKEN")

# Ensure cache is up to date
init_project_cache "$token"

# Find projects by team members
echo "=== Projects by Team Member ==="
team_members=("alice" "bob" "charlie")

for member in "${team_members[@]}"; do
    echo "Projects for $member:"
    find_projects_by_member "$member" "summary"
    echo ""
done

# Generate team dashboard
generate_team_dashboard "${team_members[@]}"
```

### Activity Monitoring and Reporting
```bash
#!/bin/bash
source ./gitlab-api.sh
source ./gitlab-project-cache.sh

token=$(get_env_variable "GITLAB_API_TOKEN")
init_project_cache "$token"

# Generate activity report
echo "=== GitLab Activity Report ==="
generate_activity_report 30  # Last 30 days

# Export recent activity to CSV
find_projects_updated_since "2025-07-01" "csv" > recent_activity.csv

# Find stale projects that might need attention
show_stale_projects 90  # No activity for 90+ days
```

### Smart Project Creation with Conflict Resolution
```bash
#!/bin/bash
source ./gitlab-api.sh
source ./gitlab-project-cache.sh
source ./integration-examples.sh

token=$(get_env_variable "GITLAB_API_TOKEN")
init_project_cache "$token"

# Smart creation suggests alternatives if name is taken
smart_project_creation "my-api-project" "$token"
```

### Data Export for External Analysis
```bash
#!/bin/bash
source ./gitlab-api.sh
source ./gitlab-project-cache.sh

token=$(get_env_variable "GITLAB_API_TOKEN")
init_project_cache "$token"

# Export all projects to CSV for Excel analysis
export_cache "csv" "all_projects.csv"

# Export recent projects as JSON for other tools
find_projects_updated_since "2025-08-01" "full" > recent_projects.json

# Generate comprehensive activity report
generate_activity_report 60 > activity_report.txt
```

## 🚀 **Interactive Mode**

Launch the interactive project explorer:
```bash
bash integration-examples.sh interactive
```

Commands available in interactive mode:
- `search <pattern>` - Search projects by name
- `recent [limit]` - Show recently updated projects  
- `member <username>` - Find projects by team member
- `create <name>` - Smart project creation with conflict checking
- `export [format]` - Export cache data
- `stats` - Show cache statistics
- `refresh` - Refresh cache from GitLab API

## 🎯 **Command Line Interface**

Both cache scripts can be run directly from command line:

```bash
# Cache operations
bash gitlab-project-cache.sh init "$GITLAB_API_TOKEN"
bash gitlab-project-cache.sh check "project-name"
bash gitlab-project-cache.sh search "api"
bash gitlab-project-cache.sh recent 10
bash gitlab-project-cache.sh export csv projects.csv

# Integration workflows
bash integration-examples.sh demo                    # Run all demos
bash integration-examples.sh setup                  # Initialize cache
bash integration-examples.sh create "new-project"   # Smart creation
bash integration-examples.sh team alice bob         # Team analysis
bash integration-examples.sh interactive            # Interactive mode
```

## 🔒 Security Best Practices

### Token Storage
- Tokens are stored in `~/.env` with 600 permissions (owner read/write only)
- Never commit tokens to version control
- Use different tokens for different environments
- Regularly rotate your Personal Access Tokens

### Cache Security
- Cache files stored in user's AppData directory with appropriate permissions
- No sensitive data exposed in cache files (tokens are never cached)
- Cache validation prevents corruption and tampering
- Automatic cleanup of stale or invalid cache entries

### Token Scopes
- Use minimal required scopes:
  - `read_api` for listing projects and cache operations
  - `api` for creating/modifying projects
- Avoid using `sudo` or `admin` scopes unless absolutely necessary

## 🐛 Troubleshooting

### Cache-Related Issues

#### "Cache not initialized"
```bash
# Initialize the cache first
source ./gitlab-project-cache.sh
token=$(get_env_variable "GITLAB_API_TOKEN")
init_project_cache "$token"
```

#### "Project not found in cache"
```bash
# Refresh the cache to get latest data
refresh_project_cache "$token"

# Or force a complete refresh
init_project_cache "$token" "force"
```

#### Cache validation fails
```bash
# Check cache integrity
validate_cache

# If corrupted, reinitialize
clear_cache
init_project_cache "$token"
```

### Common API Issues

#### "Command not found: jq"
```bash
# Install jq based on your system
sudo apt install jq        # Ubuntu/Debian
brew install jq            # macOS
# Download from https://stedolan.github.io/jq/download/ for Windows
```

#### "401 Unauthorized"
- Verify your token is correct and not expired
- Check token scopes in GitLab Settings → Access Tokens
- Ensure token has required permissions

#### "Empty response from API"
- Check network connectivity
- Verify GitLab service status
- Try the simple function first: `get_list_of_projects_simple`

### Cache Storage Issues

#### Cache directory not accessible
- Check disk space in AppData folder
- Verify user permissions for AppData directory
- On Windows, ensure `%APPDATA%` environment variable is set

#### Export files not created
- Check write permissions in cache directory
- Verify output file path is valid
- Ensure sufficient disk space

## 🔧 Configuration

### Environment Variables
The library uses these environment variables (stored in `~/.env`):

```bash
# GitLab Personal Access Token
GITLAB_API_TOKEN="glpat-xxxxxxxxxxxxxxxxxxxx"

# Optional: Custom GitLab instance URL (defaults to gitlab.com)
GITLAB_URL="https://gitlab.example.com"
```

### Cache Configuration
Cache behavior can be controlled through function parameters:

```bash
# Cache refresh frequency (automatically checks age)
init_project_cache "$token"        # Skips if cache < 4 hours old
init_project_cache "$token" "force" # Always refresh

# Search result limits
list_recent_projects 20            # Show 20 most recent
find_projects_updated_since "2025-08-01" "names"  # Names only
```

### File Locations
- **Token storage**: `~/.env` (permissions: 600)
- **Cache storage**: Platform-specific AppData directory
- **Cache files**: `projects-cache.json`, `cache-metadata.json`
- **Logs**: stderr for errors, stdout for data

## 🎯 **Workflow Scenarios**

### Scenario 1: Preventing Duplicate Projects
```bash
# Before creating any project
source ./gitlab-api.sh && source ./gitlab-project-cache.sh
token=$(get_env_variable "GITLAB_API_TOKEN")
init_project_cache "$token"

# Smart creation with conflict detection
if [ "$(is_project_name_available "my-project")" = "yes" ]; then
    create_project_safe "my-project" "$token"
else
    echo "Project already exists! Choose a different name."
fi
```

### Scenario 2: Team Project Tracking
```bash
# Find all projects where team members are involved
team_members=("alice" "bob" "charlie")
for member in "${team_members[@]}"; do
    echo "=== Projects for $member ==="
    find_projects_by_member "$member" "summary"
done

# Generate comprehensive team dashboard
generate_team_dashboard "${team_members[@]}"
```

### Scenario 3: Project Activity Analysis
```bash
# Find projects with recent activity
find_projects_updated_since "2025-08-01" "summary"

# Identify stale projects that might need attention
show_stale_projects 90  # No activity for 90+ days

# Export data for external analysis
export_cache "csv" "project_analysis.csv"
```

### Scenario 4: Automated Monitoring
```bash
# Set up automated cache maintenance
maintain_cache "$token"

# Monitor for changes (useful in CI/CD)
monitor_cache_changes "$token" 300  # Check every 5 minutes
```

## 🤝 Contributing

### Development Setup
```bash
git clone https://gitlab.com/your-username/gitlab-api-helper.git
cd gitlab-api-helper

# Set up Git hooks for code quality
./scripts/setup-hooks.sh

# Run tests
bash hooks/test-runner.sh

# Check shell syntax
shellcheck gitlab-api.sh gitlab-project-cache.sh
```

### Testing New Features
```bash
# Test core API functions
bash hooks/test-runner.sh standard

# Test cache functions
bash integration-examples.sh demo

# Interactive testing
bash integration-examples.sh interactive
```

### Code Style
- Use 4-space indentation
- Include comprehensive error handling
- Add detailed documentation for all functions
- Follow existing naming conventions
- Test on multiple platforms
- Validate cache integrity in all operations

### Submitting Changes
1. Fork the repository on GitLab
2. Create a feature branch
3. Make your changes with tests
4. Update documentation
5. Ensure all Git hooks pass
6. Submit a merge request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

### Getting Help
- **Issues**: [GitLab Issues](https://gitlab.com/your-username/gitlab-api-helper/-/issues)
- **Merge Requests**: [GitLab Merge Requests](https://gitlab.com/your-username/gitlab-api-helper/-/merge_requests)
- **Wiki**: [Project Wiki](https://gitlab.com/your-username/gitlab-api-helper/-/wikis/home)

### Resources
- [GitLab API Documentation](https://docs.gitlab.com/ee/api/)
- [Personal Access Tokens Guide](https://docs.gitlab.com/ee/user/profile/personal_access_tokens.html)
- [jq Manual](https://stedolan.github.io/jq/manual/)

## 📈 Changelog

### v2.0.0 (Current)
- **🆕 Added GitLab Project Cache System**
  - Local project caching in AppData folder
  - Duplicate prevention for project creation
  - Advanced search by date ranges and team members
  - Team collaboration tracking and analysis
  - Smart project creation with conflict resolution
  - Data export capabilities (CSV, JSON, TXT)
  - Cross-platform AppData storage
  - Cache validation and maintenance tools
  - Interactive project explorer
  - Comprehensive integration examples

### v1.0.0
- Initial release
- Token management functions
- Project creation and listing
- Multiple output formats
- Cross-platform support
- Comprehensive documentation

## 🎉 **New in v2.0: Cache System Benefits**

### ⚡ **Performance**
- **Offline access** to project data
- **Instant searches** without API calls
- **Reduced API rate limiting**

### 🛡️ **Safety**
- **Duplicate prevention** before project creation
- **Conflict detection** with smart alternatives
- **Team coordination** visibility

### 📊 **Analytics**
- **Activity tracking** and reporting
- **Team collaboration** insights
- **Stale project** identification
- **Data export** for external tools

### 🔄 **Automation**
- **Smart project creation** workflows
- **Automated cache maintenance**
- **Continuous monitoring** capabilities
- **CI/CD integration** ready

---

**Made with ❤️ for the GitLab community**

*Now with advanced project caching and team collaboration features!*