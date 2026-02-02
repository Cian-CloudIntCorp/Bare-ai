#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# SCRIPT NAME:    setup_bare-brain.sh
# VERSION:        4.5.1-Hotfix (Variable Fix)
# DESCRIPTION:    Installs the Brain and purges legacy configuration drift.
# ==============================================================================

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
NC="\033[0m"

WORKSPACE_DIR="$HOME/.bare-ai"
BIN_DIR="$WORKSPACE_DIR/bin"
LOG_DIR="$WORKSPACE_DIR/logs"
FLEET_FILE="$WORKSPACE_DIR/fleet.conf"
CONSTITUTION_SRC="constitution.md" 
# FIX: Added missing variable definition below
BASHRC_FILE="$HOME/.bashrc"

echo -e "${GREEN}Installing Bare-AI Brain (v4.5.1)...${NC}"
mkdir -p "$LOG_DIR" "$BIN_DIR"

# --- 1. PURGE DEBRIS ---
if [ -f "$WORKSPACE_DIR/brain_constitution.md" ]; then
    echo -e "${YELLOW}Removing legacy file: brain_constitution.md${NC}"
    rm -f "$WORKSPACE_DIR/brain_constitution.md"
fi

# --- 2. INSTALL CONSTITUTION ---
TARGET_CONST="$WORKSPACE_DIR/constitution.md"
if [ -f "$CONSTITUTION_SRC" ]; then
    cp "$CONSTITUTION_SRC" "$TARGET_CONST"
    echo -e "${GREEN}Installed Constitution v2.0.${NC}"
else
    echo -e "${YELLOW}Warning: Source constitution not found. Using default.${NC}"
fi

# --- 3. COMPILE BRAIN LOGIC ---
BRAIN_SCRIPT="$BIN_DIR/bare-brain"

cat << 'EOF' > "$BRAIN_SCRIPT"
#!/bin/bash
set -e

# Config
CONSTITUTION="$HOME/.bare-ai/constitution.md"
FLEET_FILE="$HOME/.bare-ai/fleet.conf"
LOG_FILE="$HOME/.bare-ai/reflex_history.log"
TARGET_USER="bare-ai"

# Circuit Breaker
should_block_reflex() {
    local target=$1
    local time_pattern=$(date +%Y-%m-%d\ %H:)
    local recent=$(grep "$target" "$LOG_FILE" 2>/dev/null | grep "REFLEX" | grep "$time_pattern" | tail -n 1)
    if [[ -n "$recent" ]]; then echo "YES"; else echo "NO"; fi
}

echo "🧠 Brain v4.5: Scanning Fleet..."

while IFS= read -r WORKER_HOST || [[ -n "$WORKER_HOST" ]]; do
    [[ "$WORKER_HOST" =~ ^#.*$ ]] && continue
    [[ -z "$WORKER_HOST" ]] && continue
    
    echo -e "\n📡 Targeting: $WORKER_HOST"
    
    # 1. Harvest
    RAW_DATA=$(ssh -q -o ConnectTimeout=5 $TARGET_USER@$WORKER_HOST "bare-summarize" || echo "")
    if [ -z "$RAW_DATA" ]; then echo "❌ Unreachable."; continue; fi

    # 2. Circuit Breaker
    if [[ $(should_block_reflex "$WORKER_HOST") == "YES" ]]; then
        echo "⚠️  Circuit Breaker: Skipping (Already fixed this hour)."
        continue
    fi

    # 3. Analyze
    PROMPT="$(cat $CONSTITUTION)
    URGENT TASK: Analyze this telemetry.
    DATA: $RAW_DATA"

    # Call Gemini
    RESPONSE=$(gemini -m gemini-2.5-flash-lite "$PROMPT" 2>/dev/null || echo "")

    # Fallback (Spinal Cord)
    if [ -z "$RESPONSE" ]; then
        echo "⚠️  Offline Mode: Engaging Spinal Cord."
        if echo "$RAW_DATA" | grep -q '"rke2_status": "inactive"'; then
            RESPONSE=$'REASON: Spinal Cord detected inactive service.\nCOMMAND: sudo systemctl start rke2-server'
        else
            RESPONSE=$'REASON: Spinal Cord nominal.\nCOMMAND: NONE'
        fi
    fi

    # 4. Reflex Action
    REASON=$(echo "$RESPONSE" | grep "REASON:" | cut -d':' -f2- | xargs)
    FIX_CMD=$(echo "$RESPONSE" | grep "COMMAND:" | cut -d':' -f2- | xargs)

    if [[ "$FIX_CMD" != "NONE" && ! -z "$FIX_CMD" ]]; then
        echo "⚡ REFLEX TRIGGERED"
        echo "   Reason: $REASON"
        echo "   Action: $FIX_CMD"
        ssh -t -q $TARGET_USER@$WORKER_HOST "$FIX_CMD"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] REFLEX | $WORKER_HOST | $REASON | $FIX_CMD" >> "$LOG_FILE"
    else
        echo "🟢 Healthy ($REASON)"
    fi
done < "$FLEET_FILE"
EOF

chmod +x "$BRAIN_SCRIPT"

# --- 4. ENV SETUP ---
if [ ! -f "$FLEET_FILE" ]; then echo "100.64.0.3" > "$FLEET_FILE"; fi
TEMP_PATH="$WORKSPACE_DIR/path_frag"
echo 'if [ -d "$HOME/.bare-ai/bin" ] ; then PATH="$HOME/.bare-ai/bin:$PATH"; fi' > "$TEMP_PATH"
if ! grep -q "BARE-AI PATH" "$BASHRC_FILE"; then cat "$TEMP_PATH" >> "$BASHRC_FILE"; fi
rm -f "$TEMP_PATH"

echo -e "${GREEN}Brain v4.5.1 Update Complete.${NC}"
