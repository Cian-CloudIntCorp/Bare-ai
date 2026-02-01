#!/usr/bin/env bash
############################################################
#    ____ _                  _ _       _        ____       #
#   / ___| | ___  _    _  ___| (_)_ __ | |_      / ___|___   #
#  | |   | |/ _ \| | | |/ __| | | '_ \| __|     | |   / _ \  #
#  | |___| | (_) | |_| | (__| | | | | | |_      | |__| (_) | #
#   \____|_|\___/ \__,_|\___|_|_|_| |_|\__|      \____\___/  #
#                                                          #
#   by the Cloud Integration Corporation                   #
############################################################
# ==============================================================================
# SCRIPT NAME:    setup_bare-ai-dev.sh
# DESCRIPTION:    Bare-AI Developer Console ("The Architect")
# VERSION:        4.5.5-Dev (Visual Confirmation Edition)
#
# PURPOSE:
#   Transforms a developer machine (e.g., Penguin) into the control center.
#   1. Safety: Disables autonomous loops.
#   2. Deployment: Installs 'bare-enroll' (Pointing to EXTENSIONLESS installer).
#   3. Audit: Installs 'bare-audit'.
#   4. Logging: Forwards Gemini chat logs to the daily diary.
# ==============================================================================
set -euo pipefail

# --- CONFIGURATION ---
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
NC="\033[0m"

BARE_AI_DIR="$HOME/.bare-ai"
BIN_DIR="$BARE_AI_DIR/bin"
REPO_DIR="$HOME/Bare-ai"

echo -e "${GREEN}Initializing BARE-AI ARCHITECT CONSOLE (v4.5.5)...${NC}"

# 1. Directory Setup
mkdir -p "$BIN_DIR" "$BARE_AI_DIR/diary"

# 2. Install 'bare-audit'
WORKER_ARTIFACT="$REPO_DIR/scripts/worker/bare-summarize"

if [ -f "$WORKER_ARTIFACT" ]; then
    echo -e "${YELLOW}Installing bare-audit...${NC}"
    cp "$WORKER_ARTIFACT" "$BIN_DIR/bare-audit"
    chmod +x "$BIN_DIR/bare-audit"
else
    echo "⚠️  Warning: Worker artifact not found at $WORKER_ARTIFACT"
    echo "   (This is unexpected as your screenshots show it exists)"
fi

# 3. Create 'bare-enroll' (The Deployment Tool)
cat << 'EnrollEOF' > "$BIN_DIR/bare-enroll"
#!/bin/bash
# Usage: bare-enroll user@192.168.1.50
TARGET=$1
if [ -z "$TARGET" ]; then
    echo "Usage: bare-enroll <user@host>"
    echo "Deploys the v4.5 Enterprise Worker logic to a remote node."
    exit 1
fi

echo "🚀 Enrolling Node: $TARGET"
REPO_PATH="$HOME/Bare-ai"

# --- VISUAL CONFIRMATION MATCH: No extensions ---
WORKER_SCRIPT="$REPO_PATH/scripts/worker/setup_bare-ai-worker.sh"
ARTIFACT="$REPO_PATH/scripts/worker/bare-summarize"

# Validation
if [ ! -f "$WORKER_SCRIPT" ]; then
    echo "❌ Error: Worker installer not found at $WORKER_SCRIPT"
    exit 1
fi
if [ ! -f "$ARTIFACT" ]; then
    echo "❌ Error: Artifact not found at $ARTIFACT"
    exit 1
fi

# Step 1: Create Staging
echo "   -> Preparing staging area..."
ssh "$TARGET" "mkdir -p /tmp/bare-install"

# Step 2: Upload Payload
echo "📦 -> Uploading Payload..."
scp "$WORKER_SCRIPT" "$TARGET:/tmp/bare-install/setup"
scp "$ARTIFACT" "$TARGET:/tmp/bare-install/bare-summarize"

# Step 3: Execute
echo "⚡ -> Executing Remote Installer..."
ssh -t "$TARGET" "bash /tmp/bare-install/setup"

echo "✅ Enrollment Complete."
EnrollEOF
chmod +x "$BIN_DIR/bare-enroll"

# 4. Enforce Architect Constitution
CONSTITUTION="# MISSION
You are the **Bare-AI Architect Assistant**.
You run on the Developer Console (Penguin).
Your goal is to help write code, manage Git, and debug the fleet.

# RULES
1. **Context:** You are on a Dev Machine, NOT a server.
2. **Safety:** Do not restart system services (systemd) on this machine.
3. **Capabilities:** You can use 'git', 'ssh', and 'bare-enroll'.
4. **Style:** Be concise, technical, and accurate.

# DIARY
Logs are stored in ~/.bare-ai/diary/."

echo -e "${YELLOW}Updating Identity to Architect Mode...${NC}"
echo "$CONSTITUTION" > "$BARE_AI_DIR/constitution.md"

# 5. .bashrc Updates (Log Forwarding)
cat << 'BashrcEOF' > "$BARE_AI_DIR/dev_aliases"
# BARE-AI DEV TOOLS
if [ -d "$HOME/.bare-ai/bin" ] ; then PATH="$HOME/.bare-ai/bin:$PATH"; fi

# The Local Assistant (With Log Forwarding)
bare() {
    local TODAY=$(date +%Y-%m-%d)
    local CONST="$HOME/.bare-ai/constitution.md"
    local DIARY="$HOME/.bare-ai/diary/$TODAY.md"
    
    mkdir -p "$(dirname "$DIARY")"
    touch "$DIARY"
    
    # 1. Run Gemini
    gemini -m gemini-2.5-flash-lite -i "$(cat "$CONST")"
    
    # 2. Log Forwarding
    if [ -f "GEMINI.md" ]; then
        echo -e "\n--- SESSION APPENDED: $(date) ---" >> "$DIARY"
        cat "GEMINI.md" >> "$DIARY"
        rm "GEMINI.md"
        echo "📝 Session saved to Diary ($TODAY.md)."
    fi
}

alias bare-status='echo "🔍 Local Telemetry Audit:"; bare-audit | jq .'
alias bare-cd='cd ~/Bare-ai'
BashrcEOF

# Idempotent append to .bashrc
if ! grep -q "BARE-AI DEV TOOLS" "$HOME/.bashrc"; then
    echo -e "${YELLOW}Adding tools to .bashrc...${NC}"
    cat "$BARE_AI_DIR/dev_aliases" >> "$HOME/.bashrc"
fi
rm "$BARE_AI_DIR/dev_aliases"

echo -e "${GREEN}ARCHITECT SETUP COMPLETE.${NC}"
echo -e "1. Reload:  source ~/.bashrc"
echo -e "2. Verify:  bare-status"