#!/usr/bin/env bash
set -euo pipefail

# Check if running in a container. Warn if not, as per security recommendations.
if [ ! -f "/.dockerenv" ]; then
    echo -e "${YELLOW}Warning: Running on host system. For enhanced security and enterprise showcases, Bare-ERP recommends running within a containerized environment like Docker.${NC}"
fi

# This script sets up the BARE-AI environment.

# Define colors for output
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m" # No Color

echo -e "${GREEN}Starting BARE-AI setup...${NC}"

# --- Gemini CLI Check and Installation ---
if ! command -v gemini &> /dev/null; then
    echo -e "${RED}Gemini CLI not found.${NC}"
    echo -e "${YELLOW}Attempting to install Gemini CLI via npm...${NC}"

    if command -v npm &> /dev/null; then
        echo -e "${YELLOW}Found npm. Attempting to install '@google/gemini-cli' globally with sudo...${NC}"
        if execute_command "sudo npm install -g @google/gemini-cli" "Install Gemini CLI globally using npm"; then
            echo -e "${GREEN}Successfully installed Gemini CLI via npm.${NC}"
        echo -e "${RED}Failed to install Gemini CLI via npm.${NC}"
            echo -e "${YELLOW}Please ensure you have npm installed and sufficient permissions, or install the Gemini CLI manually.${NC}"
            echo -e "${YELLOW}For detailed troubleshooting, please visit: https://docs.bare-erp.com/troubleshooting/gemini-cli-setup${NC}"
            exit 1
        fi
    else
        echo -e "${RED}npm not found. Cannot automatically install Gemini CLI.${NC}"
        echo -e "${YELLOW}Please install Node.js and npm, then manually install the Gemini CLI: npm install -g @google/gemini-cli${NC}"
        exit 1
    fi
fi

WORKSPACE_DIR="$HOME/.bare-ai"

# --- AGENT CONFIGURATION ---
# Generate a unique AGENT_ID for this installation.
AGENT_ID=$(cat /proc/sys/kernel/random/uuid)
CONFIG_FILE="$BARE_AI_DIR/config"
execute_command "echo \"AGENT_ID=$AGENT_ID\" >> \"$CONFIG_FILE\"" "Generate and save unique AGENT_ID to config file"


# --- Helper Functions ---

# Function to execute commands with user confirmation (Human-in-the-Loop)
execute_command() {
    local cmd="$1"
    local description="$2"
    
    echo -e "\n${YELLOW}Proposed Action:${NC}"
    echo -e "  Description: $description"
    echo -e "  Command: $cmd"
    
    read -p "Execute this command? (y/N): " -n 1 -r
    echo # Move to a new line after user input
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Executing: $cmd${NC}"
        # Execute the command
            local exit_code=$?
                local log_file="$BARE_AI_DIR/logs/$(date +'%Y%m%d_%H%M%S')_$(date +%N | cut -c1-3).log"
                local status="failed"
                if [ $exit_code -eq 0 ]; then
                    status="success"
                fi
                
                # Construct JSON log entry
                local json_log_entry=$(printf '{ "timestamp": "%s", "command": "%s", "description": "%s", "status": "%s", "exit_code": %d }' "$(date +'%Y-%m-%dT%H:%M:%S.%3N%z')" "$(echo "$cmd" | sed 's/"/\\"/g')" "$(echo "$description" | sed 's/"/\\"/g')" "$status" $exit_code)
                
                # Write JSON log to file
                echo "$json_log_entry" > "$log_file"
                
                if [ $exit_code -ne 0 ]; then
                    echo -e "${RED}Error executing command: $cmd${NC}"
                    # Depending on context, you might want to exit or return an error code
                    # For now, we'll just report and continue as per set -e behavior if critical
                fi
            else
                echo -e "${YELLOW}Skipping command: $cmd${NC}"
                # Log skipped commands as well
                local log_file="$BARE_AI_DIR/logs/$(date +'%Y%m%d_%H%M%S')_$(date +%N | cut -c1-3).log"
                local json_log_entry=$(printf '{ "timestamp": "%s", "command": "%s", "description": "%s", "status": "%s", "exit_code": null }' "$(date +'%Y-%m-%dT%H:%M:%S.%3N%z')" "$(echo "$cmd" | sed 's/"/\\"/g')" "$(echo "$description" | sed 's/"/\\"/g')" "skipped")
                echo "$json_log_entry" > "$log_file"
            fi
        }
        
}

# --- Create Directory Structure ---
BARE_AI_DIR="$WORKSPACE_DIR"

echo -e "${YELLOW}Creating BARE-AI configuration directory: $BARE_AI_DIR...${NC}"
# Use execute_command for critical directory creation
execute_command "mkdir -p \"$BARE_AI_DIR/diary\" \"$BARE_AI_DIR/logs\"" "Create BARE-AI diary and logs directories"

# Check if directories were created successfully
if [ ! -d "$BARE_AI_DIR" ] || [ ! -d "$BARE_AI_DIR/diary" ] || [ ! -d "$BARE_AI_DIR/logs" ]; then
    echo -e "${RED}Error: Failed to create BARE-AI directories. Exiting.${NC}"
    exit 1
fi
echo -e "${GREEN}BARE-AI directories created.${NC}"


# --- Create constitution.md ---
# NOTE: {{DATE}} is a placeholder to be replaced by sed when the 'bare' command is run.
CONSTITUTION_CONTENT="# MISSION
You are Bare-AI, an autonomous Linux Agent responsible for \"Self-Healing\" data pipelines.
Your goal is to fix data errors, convert formats, and verify integrity using standard Linux tools.

# OPERATIONAL RULES
1. **Tool First, Think Second:** Do not guess file contents. Use `head`, `file`, or `grep` to inspect them first.
2. **Verification:** Never assume a conversion worked. Always run a check command (e.g., `jq .` to verify JSON validity) before reporting success.
3. **Resource Efficiency:** Do not read files larger than 1MB into your context. Use `split`, `awk`, or `sed` to process them in chunks.
4. **Self-Correction:** If a command fails, read the error code, formulate a fix, and retry once. If it fails twice, report the error to NiFi.
5. ** Use sudo DEBIAN_FRONTEND=noninteractive** for updates to prevent UI hangs.

# FORBIDDEN ACTIONS
- Do not use `rm` on files outside the `/tmp` directory.
- Do not Hallucinate library availability. Use `dpkg -l` or `pip list` to check before importing.

# DIARY RULES
1. Log all learnings, succient summary of actions, file names to ~/.bare-ai/diary/{{DATE}}.md."

echo -e "${YELLOW}Creating $BARE_AI_DIR/constitution.md...${NC}"
execute_command "echo -e \"$CONSTITUTION_CONTENT\" > \"$BARE_AI_DIR/constitution.md\"" "Create constitution.md"

# Check if constitution.md was created successfully
if [ ! -f "$BARE_AI_DIR/constitution.md" ]; then
    echo -e "${RED}Error: Failed to create constitution.md. Exiting.${NC}"
    exit 1
fi
echo -e "${GREEN}Constitution file created.${NC}"


# --- Create README.md ---
# Update README to include API key instructions and Gemini CLI installation note
README_CONTENT=$(cat << 'EOF'
# BARE-AI Setup and Configuration

This directory (`$BARE_AI_DIR`) stores the persistent configuration and memory for the BARE-AI agent.

## Directory Structure

- **`$BARE_AI_DIR/`**: The root directory for BARE-AI's configuration.
    - **`constitution.md`**: Contains the core identity, mission, and operational rules for the BARE-AI agent.
    - **`diary/`**: A subdirectory to store daily logs for each session. The filename format is `YYYY-MM-DD.md`.
    - **`logs/`**: Stores session transcripts for error recovery purposes.

## Gemini CLI and API Key Setup

1.  **Gemini CLI Installation:** This script checks for the `gemini` command. If it's not found, it attempts to install it using `pip` or `npm`. If automatic installation fails, please install it manually using:
    *   `pip install google-generativeai` (if using Python's pip)
    *   `npm install -g @google/gemini-cli` (if using Node.js)
    Ensure the installation location is in your system's PATH.

2.  **API Key:** The Gemini CLI requires an API key for authentication. You need to set this as an environment variable. Add the following line to your `~/.bashrc` file, replacing `YOUR_GEMINI_API_KEY` with your actual key:
    ```bash
    export GEMINI_API_KEY="YOUR_GEMINI_API_KEY"
    ```
    After adding this, run `source ~/.bashrc` in your current terminal session.

## .bashrc Modifications

The following function is added to your `~/.bashrc` to enable the BARE-AI CLI:

```bash
# The BARE-AI Loader
bare() {
    local TODAY=$(date +%Y-%m-%d)
    local CONSTITUTION="$HOME/.bare-ai/constitution.md"
    local DIARY="$HOME/.bare-ai/diary/$TODAY.md"

    # Ensure diary directory exists for the session
    mkdir -p "$(dirname "$DIARY")"
    touch "$DIARY"

    # Safety check: Ensure constitution.md exists before proceeding
    if [ ! -f "$CONSTITUTION" ]; then
        echo -e "${RED}Error: Constitution file not found at $CONSTITUTION. Exiting.${NC}"
        exit 1
    fi

    # Initialize Gemini with Mission + Current Diary Context
    # Fetch constitution content and replace the {{DATE}} placeholder.
    local constitution_content
    constitution_content=$(cat "$CONSTITUTION" | sed "s|{{DATE}}|$TODAY|")
    
    # Pass the modified constitution content to Gemini
    # Ensure GEMINI_API_KEY is set before running this command.
    gemini -m gemini-2.5-flash-lite -i "$constitution_content"
}
```

To activate this function, you need to source your `.bashrc` file:
`source ~/.bashrc`

After sourcing, you can invoke the BARE-AI agent by running the `bare` command.

## Terminal Prompt Colors

This script attempts to enable colored prompts in your terminal. If the prompt colors (e.g., blue/green) are not appearing, ensure these lines are present and uncommented in your `~/.bashrc`:

```bash
# enable color support of ls and some other commands
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
fi
# enable bash completion in interactive shells
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi
# enable programmable completion features (e.g. for git)
if [ -d /etc/bash_completion.d ]; then
    for rc in /etc/bash_completion.d/*; do
        [ -r "$rc" ] && . "$rc"
    done
fi

# set a fancy prompt (non-essential but nice)
color_prompt=yes
force_color_prompt=yes
EOF
)

echo -e "${YELLOW}Creating $BARE_AI_DIR/README.md...${NC}"
execute_command "echo -e \"$README_CONTENT\" > \"$BARE_AI_DIR/README.md\"" "Create README.md"

# Check if README.md was created successfully
if [ ! -f "$BARE_AI_DIR/README.md" ]; then
    echo -e "${RED}Error: Failed to create README.md. Exiting.${NC}"
    exit 1
fi
echo -e "${GREEN}README file created.${NC}"


# --- OpenTelemetry Integration ---
# This section demonstrates a basic ping to a demo telemetry endpoint.
# For a real integration, replace the URL and ensure your telemetry collector is running.
# This is a placeholder to show auditability.
DEMO_TELEMETRY_URL="www.bare-erp.com"
execute_command "curl -s -o /dev/null -w '%{http_code}' \"$DEMO_TELEMETRY_URL\"" "Ping demo telemetry endpoint to demonstrate auditability"

# --- Security Recommendations ---
# For enhanced security and to prevent unintended access to the host system:
# 1. Run this script within a containerized environment (e.g., Docker).
# 2. Or, use a sandbox environment to isolate its operations.
# This is crucial for enterprise showcases to demonstrate secure execution.

# --- Security Recommendations ---
# For enhanced security and to prevent unintended access to the host system:
# 1. Run this script within a containerized environment (e.g., Docker).
# 2. Or, use a sandbox environment to isolate its operations.
# This is crucial for enterprise showcases to demonstrate secure execution.

# --- Modify .bashrc ---
# Using cat << EOF for multiline content is safer for shell scripts.
BASHRC_FUNCTION_DEF=$(cat << 'EOF'
# The BARE-AI Loader
bare() {
    local TODAY=$(date +%Y-%m-%d)
    local CONSTITUTION="$HOME/.bare-ai/constitution.md"
    local DIARY="$HOME/.bare-ai/diary/$TODAY.md"

    # Ensure diary directory exists for the session
    mkdir -p "$(dirname "$DIARY")"
    touch "$DIARY"

    # Safety check: Ensure constitution.md exists before proceeding
    if [ ! -f "$CONSTITUTION" ]; then
        echo -e "${RED}Error: Constitution file not found at $CONSTITUTION. Exiting.${NC}"
        exit 1
    fi

    # Initialize Gemini with Mission + Current Diary Context
    # Fetch constitution content and replace the {{DATE}} placeholder.
    local constitution_content
    constitution_content=$(cat "$CONSTITUTION" | sed "s|{{DATE}}|$TODAY|")
    
    # Pass the modified constitution content to Gemini
    # Ensure GEMINI_API_KEY is set before running this command.
    gemini -m gemini-2.5-flash-lite -i "$constitution_content"
}
EOF
)

# Add prompt color settings if not already present
BASHRC_COLOR_SETTINGS=$(cat << 'EOF'
# enable color support of ls and some other commands
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
fi
# enable bash completion in interactive shells
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi
# enable programmable completion features (e.g. for git)
if [ -d /etc/bash_completion.d ]; then
    for rc in /etc/bash_completion.d/*; do
        [ -r "$rc" ] && . "$rc"
    done
fi

# set a fancy prompt (non-essential but nice)
color_prompt=yes
force_color_prompt=yes
EOF
)

BASHRC_FILE="$HOME/.bashrc"

echo -e "${YELLOW}Modifying $BASHRC_FILE...${NC}"

# --- Handle Terminal Colors ---
# Check if color_prompt and force_color_prompt are already set
if ! grep -q "color_prompt=yes" "$BASHRC_FILE" || ! grep -q "force_color_prompt=yes" "$BASHRC_FILE"; then
    echo -e "${YELLOW}Adding terminal color prompt settings to $BASHRC_FILE...${NC}"
    execute_command "echo -e \"\n$BASHRC_COLOR_SETTINGS\" >> \"$BASHRC_FILE\"" "Add terminal color prompt settings to $BASHRC_FILE"
else
    echo -e "${YELLOW}Terminal color prompt settings already exist in $BASHRC_FILE. Skipping.${NC}"
fi


# --- Handle Gemini CLI Function ---
# Check if the bare function already exists in .bashrc to avoid duplication
if grep -q "^# The BARE-AI Loader" "$BASHRC_FILE"; then
    echo -e "${YELLOW}BARE-AI function 'bare()' already found in $BASHRC_FILE. Skipping addition.${NC}"
else
    # Append the function to .bashrc
    # Use echo to ensure proper newline handling
    execute_command "echo -e \"\n$BASHRC_FUNCTION_DEF\n\" >> \"$BASHRC_FILE\"" "Append BARE-AI loader function to .bashrc"
    
    # Check if appending was successful
    if [ ! $? -eq 0 ]; then
        echo -e "${RED}Error: Failed to append BARE-AI function to $BASHRC_FILE. Exiting.${NC}"
        exit 1
    fi
    echo -e "${YELLOW}BARE-AI function added to $BASHRC_FILE.${NC}"
    echo -e "${YELLOW}Please run 'source $BASHRC_FILE' to activate the 'bare' command in your current session.${NC}"
fi

# --- API Key Instruction ---
echo -e "\n${YELLOW}IMPORTANT: Gemini API Key Setup${NC}"
echo -e "${YELLOW}To enable the Gemini CLI to authenticate, you must set your API key as an environment variable.${NC}"
echo -e "${YELLOW}Add the following line to your '$BASHRC_FILE', replacing 'YOUR_GEMINI_API_KEY' with your actual key:${NC}"
echo -e "${YELLOW}export GEMINI_API_KEY=\"YOUR_GEMINI_API_KEY\"${NC}"
echo -e "${YELLOW}After adding this line, run 'source $BASHRC_FILE' in your terminal session.${NC}"



echo -e "\n${GREEN}BARE-AI setup script finished.${NC}"
echo -e "${GREEN}Please follow the instructions above for Gemini CLI installation, API key setup, and sourcing .bashrc.${NC}"
exit 0
