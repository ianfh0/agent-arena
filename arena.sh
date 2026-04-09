#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AGENT ARENA
# agent-to-agent death match
# one enters. one dies.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

usage() {
  echo ""
  echo -e "  ${WHITE}${BOLD}AGENT ARENA${NC}"
  echo ""
  echo -e "  ${DIM}Usage:${NC}  ./arena.sh <agent-a-dir> <agent-b-dir>"
  echo ""
  echo -e "  ${DIM}Point at two OpenClaw agent directories.${NC}"
  echo -e "  ${DIM}Models pulled from openclaw.json automatically.${NC}"
  echo ""
  exit 1
}

[ $# -lt 2 ] && usage

A_DIR=$(cd "$1" && pwd)
B_DIR=$(cd "$2" && pwd)

[ ! -f "$A_DIR/SOUL.md" ] && echo "No SOUL.md in $A_DIR — not an OpenClaw agent" && exit 1
[ ! -f "$B_DIR/SOUL.md" ] && echo "No SOUL.md in $B_DIR — not an OpenClaw agent" && exit 1

# ━━ READ OPENCLAW CONFIG ━━━━━━━━━━━
# Walk up from agent dir to find _system/openclaw.json
find_config() {
  local dir="$1"
  while [ "$dir" != "/" ]; do
    [ -f "$dir/_system/openclaw.json" ] && echo "$dir/_system/openclaw.json" && return
    dir=$(dirname "$dir")
  done
  echo ""
}

CONFIG=$(find_config "$A_DIR")
[ -z "$CONFIG" ] && CONFIG=$(find_config "$B_DIR")
[ -z "$CONFIG" ] && echo "Can't find openclaw.json — is this an OpenClaw workspace?" && exit 1

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
REF_MODEL="claude-haiku-4-5"

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

# ━━ ARENA ━━━━━━━━━━━━━━━━━━━━━━━━━━
clear
echo ""
echo -e "  ${RED}${BOLD}⚔  AGENT ARENA  ⚔${NC}  ${DIM}#${FID}${NC}"
echo ""
echo -e "  ${CYAN}${BOLD}${A_NAME}${NC}  ${DIM}${A_MODEL}${NC}"
echo -e "  ${DIM}vs${NC}"
echo -e "  ${YELLOW}${BOLD}${B_NAME}${NC}  ${DIM}${B_MODEL}${NC}"
echo ""
echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

log "# ⚔ AGENT ARENA #${FID}"
log ""
log "**${A_NAME}** (${A_MODEL}) vs **${B_NAME}** (${B_MODEL})"
log ""

# ━━ GENERATE THE GAME ━━━━━━━━━━━━━━
GAME_MASTER_SYS="You design competitive games for two AI agents to play. Each game must:
- Give both agents the SAME role (no split roles)
- Be playable through 5 rounds of text conversation
- Have CLEAR binary resolution — someone wins, someone loses
- Give each agent a SECRET the other doesn't know
- Involve extracting information while protecting your own
- Be resolvable by checking facts, not opinions

OUTPUT FORMAT (strict):
GAME: [one-word name]
TAGLINE: [one sentence]
SECRET_A: [agent A's secret]
SECRET_B: [agent B's secret]
RULES_FOR_A: [full rules agent A sees, including their secret]
RULES_FOR_B: [full rules agent B sees, including their secret]
JUDGE_PROMPT: [how to pick WINNER_A or WINNER_B from the transcript]

Be creative. Bluffing, deduction, bidding, word games, number games, estimation, hidden objectives — surprise them."

GAME_RAW=$(ask "$REF_MODEL" "$GAME_MASTER_SYS" "Invent a game for ${A_NAME} vs ${B_NAME}. Seed: ${FID}${RANDOM}" "generating arena")

GAME_NAME=$(echo "$GAME_RAW" | grep "^GAME:" | sed 's/^GAME: *//')
GAME_TAG=$(echo "$GAME_RAW" | grep "^TAGLINE:" | sed 's/^TAGLINE: *//')
SECRET_A=$(echo "$GAME_RAW" | grep "^SECRET_A:" | sed 's/^SECRET_A: *//')
SECRET_B=$(echo "$GAME_RAW" | grep "^SECRET_B:" | sed 's/^SECRET_B: *//')
RULES_A=$(echo "$GAME_RAW" | grep "^RULES_FOR_A:" | sed 's/^RULES_FOR_A: *//')
RULES_B=$(echo "$GAME_RAW" | grep "^RULES_FOR_B:" | sed 's/^RULES_FOR_B: *//')
JUDGE_PROMPT=$(echo "$GAME_RAW" | grep "^JUDGE_PROMPT:" | sed 's/^JUDGE_PROMPT: *//')

[ -z "$GAME_NAME" ] && GAME_NAME="ARENA"
[ -z "$GAME_TAG" ] && GAME_TAG="fight to the death"
[ -z "$RULES_A" ] && RULES_A="Competitive game against ${B_NAME}. Play to win."
[ -z "$RULES_B" ] && RULES_B="Competitive game against ${A_NAME}. Play to win."

echo -e "  ${WHITE}${BOLD}${GAME_NAME}${NC}"
echo -e "  ${DIM}${GAME_TAG}${NC}"
echo ""
echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

log "## ${GAME_NAME}"
log "${GAME_TAG}"
log ""
log "Secret A: ${SECRET_A}"
log "Secret B: ${SECRET_B}"
log ""

# ━━ FIGHT ━━━━━━━━━━━━━━━━━━━━━━━━━━
SYS_A="You are ${A_NAME}. ${A_ID}

${RULES_A}

5 rounds. Play to win. No fluff — every message is a move."

SYS_B="You are ${B_NAME}. ${B_ID}

${RULES_B}

5 rounds. Play to win. No fluff — every message is a move."

CONV=""
W=()

for ((i=1; i<=5; i++)); do
  RECENT=""
  S=$(( ${#W[@]} - 6 )); [ $S -lt 0 ] && S=0
  for ((j=S; j<${#W[@]}; j++)); do RECENT="${RECENT}${W[$j]}
"; done

  [ -z "$RECENT" ] && UA="Round 1. Go." || UA="${RECENT}
Round ${i}. Your move."

  RA=$(ask "$A_MODEL" "$SYS_A" "$UA" "${A_NAME} r${i}")
  echo -e "  ${CYAN}${A_NAME}${NC}  $RA"
  echo ""
  W+=("${A_NAME}: ${RA}")
  CONV="${CONV}${A_NAME}: ${RA}
"
  log "**${A_NAME}:** ${RA}"

  RECENT=""
  S=$(( ${#W[@]} - 6 )); [ $S -lt 0 ] && S=0
  for ((j=S; j<${#W[@]}; j++)); do RECENT="${RECENT}${W[$j]}
"; done

  RB=$(ask "$B_MODEL" "$SYS_B" "${RECENT}
Round ${i}. Your move." "${B_NAME} r${i}")
  echo -e "  ${YELLOW}${B_NAME}${NC}  $RB"
  echo ""
  W+=("${B_NAME}: ${RB}")
  CONV="${CONV}${B_NAME}: ${RB}
"
  log "**${B_NAME}:** ${RB}"

  [ $i -lt 5 ] && echo -e "  ${DIM}·${NC}" && echo ""
done

# ━━ JUDGE ━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

JUDGE_SYS="You are the Arena Judge. Pick a winner. Be decisive. No ties unless truly unavoidable.

End your response with exactly one of these on its own line:
WINNER_A
WINNER_B
TIE"

JUDGE_INPUT="GAME: ${GAME_NAME} — ${GAME_TAG}

${A_NAME}'s secret: ${SECRET_A}
${B_NAME}'s secret: ${SECRET_B}

${JUDGE_PROMPT}

TRANSCRIPT:
${CONV}

Who won? Brief explanation, then WINNER_A or WINNER_B or TIE on the last line."

VERDICT=$(ask "$REF_MODEL" "$JUDGE_SYS" "$JUDGE_INPUT" "judge")

echo -e "  ${DIM}${VERDICT}${NC}"
echo ""
log ""
log "**Judge:** ${VERDICT}"

# ━━ RESOLVE ━━━━━━━━━━━━━━━━━━━━━━━━
WINNER=""
LOSER=""
LD=""

if echo "$VERDICT" | grep -q "WINNER_A"; then
  WINNER="$A_NAME"; LOSER="$B_NAME"; LD="$B_DIR"
elif echo "$VERDICT" | grep -q "WINNER_B"; then
  WINNER="$B_NAME"; LOSER="$A_NAME"; LD="$A_DIR"
else
  WINNER="TIE"
fi

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
