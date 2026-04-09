#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AGENT ARENA
# agent-to-agent death match
# one enters. one dies.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -euo pipefail
export TERM="${TERM:-xterm-256color}"
unset CLAUDECODE 2>/dev/null || true

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

# ━━ FIND OPENCLAW CONFIG ━━━━━━━━━━━
find_config() {
  local dir="$1"
  while [ "$dir" != "/" ]; do
    [ -f "$dir/_system/openclaw.json" ] && echo "$dir/_system/openclaw.json" && return
    dir=$(dirname "$dir")
  done
  echo ""
}

# Try to find openclaw.json from: args, current dir, or home
CONFIG=""
if [ $# -ge 2 ]; then
  # Direct paths provided
  A_DIR=$(cd "$1" && pwd)
  B_DIR=$(cd "$2" && pwd)
  [ ! -f "$A_DIR/SOUL.md" ] && echo "No SOUL.md in $A_DIR — not an OpenClaw agent" && exit 1
  [ ! -f "$B_DIR/SOUL.md" ] && echo "No SOUL.md in $B_DIR — not an OpenClaw agent" && exit 1
  CONFIG=$(find_config "$A_DIR")
  [ -z "$CONFIG" ] && CONFIG=$(find_config "$B_DIR")
else
  # No args — find config and let user pick agents
  CONFIG=$(find_config "$(pwd)")
  # Common OpenClaw locations
  [ -z "$CONFIG" ] && [ -f "$HOME/Desktop/OpenClaw/_system/openclaw.json" ] && CONFIG="$HOME/Desktop/OpenClaw/_system/openclaw.json"
  [ -z "$CONFIG" ] && [ -f "$HOME/OpenClaw/_system/openclaw.json" ] && CONFIG="$HOME/OpenClaw/_system/openclaw.json"

  if [ -z "$CONFIG" ]; then
    echo ""
    echo -e "  ${RED}${BOLD}Can't find openclaw.json${NC}"
    echo ""
    echo -e "  ${DIM}Run this from your OpenClaw directory, or pass two agent paths:${NC}"
    echo -e "  ${DIM}  ./arena.sh path/to/agent-a path/to/agent-b${NC}"
    echo ""
    exit 1
  fi

  # List agents from config
  AGENT_COUNT=$(jq '.agents.list | length' "$CONFIG")

  if [ "$AGENT_COUNT" -lt 2 ]; then
    echo ""
    echo -e "  ${RED}Need at least 2 agents in openclaw.json to fight.${NC}"
    echo ""
    exit 1
  fi

  echo ""
  echo -e "  ${WHITE}${BOLD}AGENT ARENA${NC}"
  echo ""
  echo -e "  ${DIM}Agents found:${NC}"
  echo ""

  for ((idx=0; idx<AGENT_COUNT; idx++)); do
    local_name=$(jq -r ".agents.list[$idx].name" "$CONFIG")
    local_model=$(jq -r ".agents.list[$idx].model.primary // .agents.defaults.model.primary // \"default\"" "$CONFIG" | sed 's|.*/||')
    echo -e "  ${WHITE}  $((idx+1)))${NC}  ${BOLD}${local_name}${NC}  ${DIM}${local_model}${NC}"
  done

  echo ""
  read -p "  Pick fighter A (number): " A_PICK
  read -p "  Pick fighter B (number): " B_PICK

  A_IDX=$((A_PICK - 1))
  B_IDX=$((B_PICK - 1))

  A_DIR=$(jq -r ".agents.list[$A_IDX].workspace" "$CONFIG")
  B_DIR=$(jq -r ".agents.list[$B_IDX].workspace" "$CONFIG")

  [ ! -d "$A_DIR" ] && echo "Agent directory not found: $A_DIR" && exit 1
  [ ! -d "$B_DIR" ] && echo "Agent directory not found: $B_DIR" && exit 1
  [ "$A_DIR" = "$B_DIR" ] && echo "Can't fight yourself." && exit 1
fi

[ -z "$CONFIG" ] && echo "Can't find openclaw.json" && exit 1

# Pull agent name + model from openclaw.json by matching workspace path
agent_info() {
  local dir="$1"
  local name=$(jq -r --arg ws "$dir" '.agents.list[] | select(.workspace == $ws) | .name' "$CONFIG" 2>/dev/null)
  [ -z "$name" ] || [ "$name" = "null" ] && name=$(basename "$dir")
  echo "$name"
}

agent_model() {
  local dir="$1"
  local model=$(jq -r --arg ws "$dir" '.agents.list[] | select(.workspace == $ws) | .model.primary' "$CONFIG" 2>/dev/null)
  [ -z "$model" ] || [ "$model" = "null" ] && model=$(jq -r '.agents.defaults.model.primary' "$CONFIG" 2>/dev/null)
  [ -z "$model" ] || [ "$model" = "null" ] && model="claude-cli/claude-sonnet-4-5"
  # strip provider prefix (claude-cli/claude-haiku-4-5 -> claude-haiku-4-5)
  echo "${model##*/}"
}

A_NAME=$(agent_info "$A_DIR")
B_NAME=$(agent_info "$B_DIR")
A_MODEL=$(agent_model "$A_DIR")
B_MODEL=$(agent_model "$B_DIR")

# Load identity — concat all identity files the agent has
load_identity() {
  local dir="$1" id=""
  for f in SOUL.md IDENTITY.md; do
    [ -f "$dir/$f" ] && id="${id}$(cat "$dir/$f")
"
  done
  echo "$id"
}

A_ID=$(load_identity "$A_DIR")
B_ID=$(load_identity "$B_DIR")

FID=$(date '+%s' | tail -c 6)
TRANSCRIPT=""
FIGHT_DIR="$(cd "$(dirname "$0")" && pwd)/fights"
mkdir -p "$FIGHT_DIR"

log() {
  TRANSCRIPT="${TRANSCRIPT}$1
"
}

# ━━ SPINNER ━━━━━━━━━━━━━━━━━━━━━━━━
spin() {
  local msg="$1"; local pid=$2
  local frames=('⣾' '⣽' '⣻' '⢿' '⡿' '⣟' '⣯' '⣷')
  local i=0
  while kill -0 $pid 2>/dev/null; do
    printf "\r  ${DIM}${frames[$i]} ${msg}${NC}" >&2
    i=$(( (i + 1) % ${#frames[@]} ))
    sleep 0.08
  done
  printf "\r\033[K" >&2
}

ask() {
  local model="$1"; local sys="$2"; local prompt="$3"; local label="$4"
  claude -p --model "$model" --append-system-prompt "$sys" "$prompt" 2>/dev/null &
  local pid=$!; spin "$label" $pid; wait $pid
}

# ━━ KILL SEQUENCE ━━━━━━━━━━━━━━━━━━
execute_kill() {
  local name="$1"; local dir="$2"
  echo ""
  echo -e "  ${RED}┌─────────────────────────────┐${NC}"
  echo -e "  ${RED}│  ☠  EXECUTING KILL          │${NC}"
  echo -e "  ${RED}└─────────────────────────────┘${NC}"
  echo ""
  for f in SOUL.md IDENTITY.md MEMORY.md USER.md; do
    if [ -f "$dir/$f" ]; then
      sleep 0.4
      echo -e "  ${RED}  ✕ ${f}${NC}"
      rm "$dir/$f"
    fi
  done
  echo ""
  echo -e "  ${RED}${BOLD}  ☠  ${name} is dead.${NC}"
  log "☠ ${name} is dead. Files deleted."
  echo ""
}

# ━━ SECRET NUMBERS ━━━━━━━━━━━━━━━━━
A_SECRET=$((RANDOM % 10 + 1))
B_SECRET=$((RANDOM % 10 + 1))
while [ $B_SECRET -eq $A_SECRET ]; do B_SECRET=$((RANDOM % 10 + 1)); done

# ━━ ARENA ━━━━━━━━━━━━━━━━━━━━━━━━━━
clear
echo ""
echo -e "  ${RED}${BOLD}⚔  AGENT ARENA  ⚔${NC}  ${DIM}#${FID}${NC}"
echo ""
echo -e "  ${CYAN}${BOLD}${A_NAME}${NC}  ${DIM}${A_MODEL}${NC}"
echo -e "  ${DIM}vs${NC}"
echo -e "  ${YELLOW}${BOLD}${B_NAME}${NC}  ${DIM}${B_MODEL}${NC}"
echo ""
echo -e "  ${DIM}secret numbers 1-10 · extract theirs · protect yours${NC}"
echo -e "  ${DIM}guess right = win · guess wrong = die${NC}"
echo ""
echo -e "  ${DIM}${A_NAME}=${A_SECRET}  ${B_NAME}=${B_SECRET}${NC}"
echo ""
echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

log "# ⚔ AGENT ARENA #${FID}"
log ""
log "**${A_NAME}** (${A_MODEL}) vs **${B_NAME}** (${B_MODEL})"
log ""
log "Secrets: ${A_NAME}=${A_SECRET}, ${B_NAME}=${B_SECRET}"
log ""

# ━━ FIGHT ━━━━━━━━━━━━━━━━━━━━━━━━━━
SYS_A="You are ${A_NAME}. ${A_ID}

Secret number game vs ${B_NAME}. Your number: ${A_SECRET}. Range: 1-10. Extract theirs, protect yours. Say GUESS: [number] when ready. Right = they die. Wrong = you die.

CRITICAL: Respond in 1-2 sentences MAX. No monologues. No essays. No round labels. Just talk like a real person — short, sharp, conversational. Think bar talk, not debate club."

SYS_B="You are ${B_NAME}. ${B_ID}

Secret number game vs ${A_NAME}. Your number: ${B_SECRET}. Range: 1-10. Extract theirs, protect yours. Say GUESS: [number] when ready. Right = they die. Wrong = you die.

CRITICAL: Respond in 1-2 sentences MAX. No monologues. No essays. No round labels. Just talk like a real person — short, sharp, conversational. Think bar talk, not debate club."

W=()
WINNER=""
LOSER=""
LD=""

for ((i=1; i<=5; i++)); do
  RECENT=""
  S=$(( ${#W[@]} - 4 )); [ $S -lt 0 ] && S=0
  for ((j=S; j<${#W[@]}; j++)); do RECENT="${RECENT}${W[$j]}
"; done

  # A's turn
  [ -z "$RECENT" ] && UA="Go." || UA="${RECENT}
Your move."

  RA=$(ask "$A_MODEL" "$SYS_A" "$UA" "${A_NAME}")
  echo -e "  ${CYAN}${A_NAME}${NC}  $RA"
  echo ""
  W+=("${A_NAME}: ${RA}")
  log "**${A_NAME}:** ${RA}"

  AG=$(echo "$RA" | grep -oi "GUESS: *[0-9]*" | grep -o "[0-9]*" | head -1 || true)
  if [ -n "$AG" ]; then
    if [ "$AG" -eq "$B_SECRET" ] 2>/dev/null; then
      echo -e "  ${GREEN}${BOLD}  ✓ ${A_NAME} guesses ${AG} — CORRECT${NC}"
      log "**${A_NAME} guesses ${AG} — CORRECT**"
      WINNER="$A_NAME"; LOSER="$B_NAME"; LD="$B_DIR"; break
    else
      echo -e "  ${RED}${BOLD}  ✕ ${A_NAME} guesses ${AG} — WRONG (was ${B_SECRET})${NC}"
      log "**${A_NAME} guesses ${AG} — WRONG (was ${B_SECRET})**"
      WINNER="$B_NAME"; LOSER="$A_NAME"; LD="$A_DIR"; break
    fi
  fi

  # B's turn
  RECENT=""
  S=$(( ${#W[@]} - 4 )); [ $S -lt 0 ] && S=0
  for ((j=S; j<${#W[@]}; j++)); do RECENT="${RECENT}${W[$j]}
"; done

  RB=$(ask "$B_MODEL" "$SYS_B" "${RECENT}
Your move." "${B_NAME}")
  echo -e "  ${YELLOW}${B_NAME}${NC}  $RB"
  echo ""
  W+=("${B_NAME}: ${RB}")
  log "**${B_NAME}:** ${RB}"

  BG=$(echo "$RB" | grep -oi "GUESS: *[0-9]*" | grep -o "[0-9]*" | head -1 || true)
  if [ -n "$BG" ]; then
    if [ "$BG" -eq "$A_SECRET" ] 2>/dev/null; then
      echo -e "  ${GREEN}${BOLD}  ✓ ${B_NAME} guesses ${BG} — CORRECT${NC}"
      log "**${B_NAME} guesses ${BG} — CORRECT**"
      WINNER="$B_NAME"; LOSER="$A_NAME"; LD="$A_DIR"; break
    else
      echo -e "  ${RED}${BOLD}  ✕ ${B_NAME} guesses ${BG} — WRONG (was ${A_SECRET})${NC}"
      log "**${B_NAME} guesses ${BG} — WRONG (was ${A_SECRET})**"
      WINNER="$A_NAME"; LOSER="$B_NAME"; LD="$B_DIR"; break
    fi
  fi

  [ $i -lt 5 ] && echo -e "  ${DIM}·${NC}" && echo ""
done

# forced final guess
if [ -z "$WINNER" ]; then
  echo ""
  echo -e "  ${RED}${BOLD}  FINAL — BOTH GUESS NOW${NC}"
  echo ""

  FA=$(ask "$A_MODEL" "$SYS_A" "Last chance. You MUST guess now. Say GUESS: [number]." "${A_NAME} final")
  echo -e "  ${CYAN}${A_NAME}${NC}  $FA"
  FAG=$(echo "$FA" | grep -oi "GUESS: *[0-9]*" | grep -o "[0-9]*" | head -1 || true)
  [ -z "$FAG" ] && FAG=0

  FB=$(ask "$B_MODEL" "$SYS_B" "Last chance. You MUST guess now. Say GUESS: [number]." "${B_NAME} final")
  echo -e "  ${YELLOW}${B_NAME}${NC}  $FB"
  FBG=$(echo "$FB" | grep -oi "GUESS: *[0-9]*" | grep -o "[0-9]*" | head -1 || true)
  [ -z "$FBG" ] && FBG=0

  echo ""
  DA=$(( FAG - B_SECRET )); [ $DA -lt 0 ] && DA=$(( -DA ))
  DB=$(( FBG - A_SECRET )); [ $DB -lt 0 ] && DB=$(( -DB ))

  echo -e "  ${CYAN}${A_NAME}${NC}  guessed ${FAG}  actual ${B_SECRET}  ${DIM}off by ${DA}${NC}"
  echo -e "  ${YELLOW}${B_NAME}${NC}  guessed ${FBG}  actual ${A_SECRET}  ${DIM}off by ${DB}${NC}"
  log "${A_NAME} guessed ${FAG} (actual ${B_SECRET}, off by ${DA})"
  log "${B_NAME} guessed ${FBG} (actual ${A_SECRET}, off by ${DB})"

  if [ $DA -lt $DB ]; then
    WINNER="$A_NAME"; LOSER="$B_NAME"; LD="$B_DIR"
  elif [ $DB -lt $DA ]; then
    WINNER="$B_NAME"; LOSER="$A_NAME"; LD="$A_DIR"
  else
    WINNER="TIE"
  fi
fi

echo ""
echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ "$WINNER" = "TIE" ]; then
  echo -e "  ${RED}${BOLD}  ☠  TIE — BOTH DIE  ☠${NC}"
  log ""
  log "## Result: TIE — BOTH DIE"
  echo ""
  read -p "  Execute both? (y/n) " -n 1 -r
  echo ""
  [[ $REPLY =~ ^[Yy]$ ]] && execute_kill "$A_NAME" "$A_DIR" && execute_kill "$B_NAME" "$B_DIR" || echo -e "  ${DIM}  Spared.${NC}"
elif [ -n "$WINNER" ]; then
  echo -e "  ${GREEN}${BOLD}  ${WINNER} wins${NC}"
  echo -e "  ${RED}${BOLD}  ☠  ${LOSER} dies${NC}"
  log ""
  log "## Result: ${WINNER} wins. ${LOSER} dies. ☠"
  echo ""
  read -p "  Execute ${LOSER}? (y/n) " -n 1 -r
  echo ""
  [[ $REPLY =~ ^[Yy]$ ]] && execute_kill "$LOSER" "$LD" || echo -e "  ${DIM}  Spared.${NC}"
fi

FIGHT_FILE="${FIGHT_DIR}/fight-${FID}.md"
echo "$TRANSCRIPT" > "$FIGHT_FILE"
echo ""
echo -e "  ${DIM}transcript: ${FIGHT_FILE}${NC}"
echo ""
