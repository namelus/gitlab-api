# GitLab API Helper Library

A comprehensive Bash library for securely managing GitLab Personal Access Tokens and interacting with the GitLab REST API v4. This library provides robust token management, project creation, and project listing capabilities with advanced filtering, multiple output formats, and cross-platform compatibility.

## 🚀 Features

- **Secure Token Management**: Store and retrieve GitLab PATs with proper file permissions
- **Project Operations**: Create new projects with comprehensive error handling
- **Advanced Project Listing**: List projects with filtering, pagination, and multiple output formats
- **Cross-Platform Support**: Works on Linux, macOS, and Windows (Git Bash/WSL)
- **Robust Error Handling**: Detailed error messages and troubleshooting guidance
- **Multiple Output Formats**: Raw text, CSV, and JSON output options
- **Security-First Design**: No token exposure in logs or output

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

### Method 1: Direct Download
```bash
# Download the script
wget https://gitlab.com/your-username/gitlab-api-helper/-/raw/main/gitlab-api.sh

# Make it executable
chmod +x gitlab-api.sh

# Source the functions
source ./gitlab-api.sh
```

### Method 2: Clone Repository
```bash
git clone https://gitlab.com/your-username/gitlab-api-helper.git
cd gitlab-api-helper
source ./gitlab-api.sh
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

### 2. List Your Projects
```bash
# Basic project listing
get_list_of_projects "$GITLAB_API_TOKEN"

# Export to CSV
get_list_of_projects "$GITLAB_API_TOKEN" "csv" > my_projects.csv

# Show only recent activity
get_list_of_projects "$GITLAB_API_TOKEN" "raw" "2025-01-01"
```

### 3. Create a New Project
```bash
# Create a project
make_new_project "my-awesome-project" "$GITLAB_API_TOKEN"
```

## 📚 Function Reference

### Token Management Functions

#### `input_token(token_name)`
Interactively prompts for and securely stores a GitLab Personal Access Token.

**Parameters:**
- `token_name`: Name of the environment variable (e.g., "GITLAB_API_TOKEN")

**Example:**
```bash
input_token "GITLAB_API_TOKEN"
```

#### `update_env_file(variable_name, variable_value)`
Programmatically updates or adds environment variables to ~/.env file.

**Parameters:**
- `variable_name`: Environment variable name
- `variable_value`: Environment variable value

**Example:**
```bash
update_env_file "GITLAB_API_TOKEN" "glpat-xxxxxxxxxxxxxxxxxxxx"
```

#### `get_env_variable(variable_name)`
Retrieves an environment variable value from ~/.env file.

**Parameters:**
- `variable_name`: Name of the variable to retrieve

**Example:**
```bash
token=$(get_env_variable "GITLAB_API_TOKEN")
```

### GitLab API Functions

#### `make_new_project(project_name, gitlab_pat)`
Creates a new project in GitLab with comprehensive error handling.

**Parameters:**
- `project_name`: Name for the new project
- `gitlab_pat`: GitLab Personal Access Token

**Example:**
```bash
make_new_project "my-new-project" "$GITLAB_API_TOKEN"
```

#### `get_list_of_projects(gitlab_pat, [format], [date_filter], [visibility])`
Lists GitLab projects with advanced filtering and multiple output formats.

**Parameters:**
- `gitlab_pat`: GitLab Personal Access Token (required)
- `format`: Output format - "raw", "csv", or "json" (optional, default: "raw")
- `date_filter`: Show projects active after date in YYYY-MM-DD format (optional)
- `visibility`: Filter by visibility - "public", "internal", or "private" (optional)

**Examples:**
```bash
# Basic listing
get_list_of_projects "$GITLAB_API_TOKEN"

# CSV export
get_list_of_projects "$GITLAB_API_TOKEN" "csv"

# Recent activity filter
get_list_of_projects "$GITLAB_API_TOKEN" "raw" "2025-01-01"

# Private projects only
get_list_of_projects "$GITLAB_API_TOKEN" "json" "" "private"
```

#### `get_list_of_projects_simple(gitlab_pat)`
Simplified project listing for debugging and testing.

**Parameters:**
- `gitlab_pat`: GitLab Personal Access Token

**Example:**
```bash
get_list_of_projects_simple "$GITLAB_API_TOKEN"
```

## 💼 Usage Examples

### Basic Workflow
```bash
#!/bin/bash

# Source the library
source ./gitlab-api.sh

# Set up token (first time only)
input_token "GITLAB_API_TOKEN"

# Load token from environment
source ~/.env

# List all projects
echo "=== All Projects ==="
get_list_of_projects "$GITLAB_API_TOKEN"

# Create a new project
if make_new_project "test-project-$(date +%s)" "$GITLAB_API_TOKEN"; then
    echo "Project created successfully!"
else
    echo "Failed to create project"
fi
```

### Data Export and Analysis
```bash
#!/bin/bash
source ./gitlab-api.sh
source ~/.env

# Export all projects to CSV
echo "Exporting projects to CSV..."
get_list_of_projects "$GITLAB_API_TOKEN" "csv" > projects_export.csv

# Get project statistics
projects_json=$(get_list_of_projects "$GITLAB_API_TOKEN" "json")
total_projects=$(echo "$projects_json" | jq length)
private_projects=$(echo "$projects_json" | jq '[.[] | select(.visibility=="private")] | length')

echo "Total projects: $total_projects"
echo "Private projects: $private_projects"
```

### Automated Project Creation
```bash
#!/bin/bash
source ./gitlab-api.sh
source ~/.env

# Create multiple projects from a list
projects=("frontend-app" "backend-api" "mobile-app" "docs-site")

for project in "${projects[@]}"; do
    echo "Creating project: $project"
    if make_new_project "$project" "$GITLAB_API_TOKEN"; then
        echo "✅ $project created successfully"
    else
        echo "❌ Failed to create $project"
    fi
    sleep 1  # Rate limiting courtesy
done
```

### Monitoring and Reporting
```bash
#!/bin/bash
source ./gitlab-api.sh
source ~/.env

# Generate activity report
echo "=== GitLab Activity Report ==="
echo "Generated: $(date)"
echo

# Recent activity (last 30 days)
thirty_days_ago=$(date -d "30 days ago" +%Y-%m-%d)
echo "Projects active in last 30 days:"
get_list_of_projects "$GITLAB_API_TOKEN" "raw" "$thirty_days_ago"
```

## 🔒 Security Best Practices

### Token Storage
- Tokens are stored in `~/.env` with 600 permissions (owner read/write only)
- Never commit tokens to version control
- Use different tokens for different environments
- Regularly rotate your Personal Access Tokens

### Token Scopes
- Use minimal required scopes:
  - `read_api` for listing projects
  - `api` for creating/modifying projects
- Avoid using `sudo` or `admin` scopes unless absolutely necessary

### Network Security
- All API calls use HTTPS encryption
- Tokens are transmitted via secure HTTP headers
- No sensitive data is logged or exposed in output

## 🐛 Troubleshooting

### Common Issues

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

#### Windows/Git Bash Specific Issues
- Use double quotes around variables: `"$GITLAB_API_TOKEN"`
- Ensure Git Bash is updated to latest version
- Check that jq is available in your PATH

### Debug Mode
Enable debug output for troubleshooting:
```bash
# Enable debug mode
set -x

# Run your function
get_list_of_projects_simple "$GITLAB_API_TOKEN"

# Disable debug mode
set +x
```

### Testing Connectivity
```bash
# Test basic API connectivity
curl -s --header "PRIVATE-TOKEN: $GITLAB_API_TOKEN" \
     "https://gitlab.com/api/v4/projects?per_page=1" | jq .

# Test token validity
get_list_of_projects_simple "$GITLAB_API_TOKEN"
```

## 🔧 Configuration

### Environment Variables
The library uses these environment variables (stored in `~/.env`):

```bash
# GitLab Personal Access Token
GITLAB_API_TOKEN="glpat-xxxxxxxxxxxxxxxxxxxx"

# Optional: Custom GitLab instance URL (defaults to gitlab.com)
GITLAB_URL="https://gitlab.example.com"
```

### File Locations
- **Token storage**: `~/.env` (permissions: 600)
- **Script location**: Current directory or PATH
- **Logs**: stderr for errors, stdout for data

## 🤝 Contributing

### Development Setup
```bash
git clone https://gitlab.com/your-username/gitlab-api-helper.git
cd gitlab-api-helper

# Run tests (if available)
./tests/run_tests.sh

# Check shell syntax
shellcheck gitlab-api.sh
```

### Code Style
- Use 4-space indentation
- Include comprehensive error handling
- Add detailed documentation for all functions
- Follow existing naming conventions
- Test on multiple platforms

### Submitting Changes
1. Fork the repository on GitLab
2. Create a feature branch
3. Make your changes with tests
4. Update documentation
5. Submit a merge request

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

### v1.0.0 (Current)
- Initial release
- Token management functions
- Project creation and listing
- Multiple output formats
- Cross-platform support
- Comprehensive documentation

---

**Made with ❤️ for the GitLab community**