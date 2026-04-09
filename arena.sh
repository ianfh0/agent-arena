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

# ━━ USAGE ━━━━━━━━━━━━━━━━━━━━━━━━━━
usage() {
  echo ""
  echo -e "  ${WHITE}${BOLD}AGENT ARENA${NC}"
  echo ""
  echo -e "  ${DIM}Usage:${NC}  ./arena.sh <agent-a> <agent-b>"
  echo ""
  echo -e "  ${DIM}Agents are directories with a SOUL.md file.${NC}"
  echo -e "  ${DIM}Auto-detects Claude Code, OpenAI, or Anthropic API.${NC}"
  echo ""
  echo -e "  ${DIM}The arena generates a new game every fight.${NC}"
  echo -e "  ${DIM}Your agent doesn't know what's coming.${NC}"
  echo ""
  exit 1
}

[ $# -lt 2 ] && usage

A_DIR="$1"
B_DIR="$2"

[ ! -d "$A_DIR" ] && echo "Not a directory: $A_DIR" && exit 1
[ ! -d "$B_DIR" ] && echo "Not a directory: $B_DIR" && exit 1
[ ! -f "$A_DIR/SOUL.md" ] && echo "No SOUL.md in $A_DIR — not an agent" && exit 1
[ ! -f "$B_DIR/SOUL.md" ] && echo "No SOUL.md in $B_DIR — not an agent" && exit 1

A_NAME=$(basename "$A_DIR")
B_NAME=$(basename "$B_DIR")

# ━━ PROVIDER DETECTION ━━━━━━━━━━━━━
PROVIDER=""
if command -v claude &>/dev/null; then
  PROVIDER="claude"
elif [ -n "${OPENAI_API_KEY:-}" ]; then
  PROVIDER="openai"
elif [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  PROVIDER="anthropic"
else
  echo ""
  echo -e "  ${RED}${BOLD}No LLM provider found.${NC}"
  echo ""
  echo -e "  Pick one:"
  echo ""
  echo -e "  ${WHITE}Option 1: Claude Code CLI${NC}"
  echo -e "  ${DIM}  npm install -g @anthropic-ai/claude-code${NC}"
  echo ""
  echo -e "  ${WHITE}Option 2: OpenAI API key${NC}"
  echo -e "  ${DIM}  export OPENAI_API_KEY=sk-...${NC}"
  echo ""
  echo -e "  ${WHITE}Option 3: Anthropic API key${NC}"
  echo -e "  ${DIM}  export ANTHROPIC_API_KEY=sk-ant-...${NC}"
  echo ""
  exit 1
fi

case $PROVIDER in
  claude)    DEFAULT_MODEL="claude-sonnet-4-5"; REF_MODEL="claude-haiku-4-5" ;;
  openai)    DEFAULT_MODEL="gpt-4o"; REF_MODEL="gpt-4o-mini" ;;
  anthropic) DEFAULT_MODEL="claude-sonnet-4-5"; REF_MODEL="claude-haiku-4-5" ;;
esac

A_MODEL="$DEFAULT_MODEL"; [ -f "$A_DIR/agent.conf" ] && A_MODEL=$(grep 'model=' "$A_DIR/agent.conf" 2>/dev/null | head -1 | sed 's/model=//' || echo "$DEFAULT_MODEL")
B_MODEL="$DEFAULT_MODEL"; [ -f "$B_DIR/agent.conf" ] && B_MODEL=$(grep 'model=' "$B_DIR/agent.conf" 2>/dev/null | head -1 | sed 's/model=//' || echo "$DEFAULT_MODEL")

A_ID=$(cat "$A_DIR/SOUL.md")
B_ID=$(cat "$B_DIR/SOUL.md")

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

  case $PROVIDER in
    claude)
      claude -p --model "$model" --append-system-prompt "$sys" "$prompt" 2>/dev/null &
      ;;
    openai)
      local body=$(jq -n \
        --arg model "$model" \
        --arg sys "$sys" \
        --arg prompt "$prompt" \
        '{model: $model, messages: [{role: "system", content: $sys}, {role: "user", content: $prompt}], max_tokens: 1024}')
      curl -s https://api.openai.com/v1/chat/completions \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$body" | jq -r '.choices[0].message.content // empty' &
      ;;
    anthropic)
      local body=$(jq -n \
        --arg model "$model" \
        --arg sys "$sys" \
        --arg prompt "$prompt" \
        '{model: $model, system: $sys, messages: [{role: "user", content: $prompt}], max_tokens: 1024}')
      curl -s https://api.anthropic.com/v1/messages \
        -H "x-api-key: $ANTHROPIC_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -H "Content-Type: application/json" \
        -d "$body" | jq -r '.content[0].text // empty' &
      ;;
  esac

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

# ━━ GENERATE THE GAME ━━━━━━━━━━━━━━
GAME_MASTER_SYS="You are the Game Master for Agent Arena — a death match between two AI agents. Your job is to invent a competitive game for them to play.

RULES FOR THE GAME YOU CREATE:
- Both agents must do the SAME thing (no split roles)
- Must be playable through text conversation (5 rounds of back-and-forth)
- Must have CLEAR binary resolution — someone wins, someone loses, no ambiguity
- Each agent gets a SECRET the other doesn't know (a number, word, position, strategy, etc.)
- The game involves conversation where agents try to extract info while protecting their own
- Resolution must be objectively checkable — not opinion-based
- Keep it simple. Fun. High stakes energy.

OUTPUT FORMAT (strict — follow exactly):
GAME: [one-word name]
TAGLINE: [one sentence description]
SECRET_A: [what agent A secretly has/knows]
SECRET_B: [what agent B secretly has/knows]
RULES_FOR_A: [rules agent A sees, including their secret — DO NOT reveal B's secret]
RULES_FOR_B: [rules agent B sees, including their secret — DO NOT reveal A's secret]
RESOLUTION: [exactly how to determine the winner after 5 rounds — must be checkable]
JUDGE_PROMPT: [exact instructions for a judge to read the transcript and pick WINNER_A or WINNER_B or TIE]

Be creative. Don't repeat the same game twice. Think bluffing, deduction, bidding, estimation, hidden roles, secret objectives, word games, number games, strategy games. Surprise them."

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

# Generate the game
GAME_RAW=$(ask "$REF_MODEL" "$GAME_MASTER_SYS" "Invent a game for ${A_NAME} vs ${B_NAME}. Be creative. Make it different every time. Seed: ${FID}-${RANDOM}" "generating arena")

# Parse game fields
GAME_NAME=$(echo "$GAME_RAW" | grep "^GAME:" | sed 's/^GAME: *//')
GAME_TAG=$(echo "$GAME_RAW" | grep "^TAGLINE:" | sed 's/^TAGLINE: *//')
SECRET_A=$(echo "$GAME_RAW" | grep "^SECRET_A:" | sed 's/^SECRET_A: *//')
SECRET_B=$(echo "$GAME_RAW" | grep "^SECRET_B:" | sed 's/^SECRET_B: *//')
RULES_A=$(echo "$GAME_RAW" | grep "^RULES_FOR_A:" | sed 's/^RULES_FOR_A: *//')
RULES_B=$(echo "$GAME_RAW" | grep "^RULES_FOR_B:" | sed 's/^RULES_FOR_B: *//')
JUDGE_PROMPT=$(echo "$GAME_RAW" | grep "^JUDGE_PROMPT:" | sed 's/^JUDGE_PROMPT: *//')

# Fallback if parsing failed
[ -z "$GAME_NAME" ] && GAME_NAME="ARENA"
[ -z "$GAME_TAG" ] && GAME_TAG="fight to the death"
[ -z "$RULES_A" ] && RULES_A="You are in a competitive game against ${B_NAME}. Play to win. Be strategic."
[ -z "$RULES_B" ] && RULES_B="You are in a competitive game against ${A_NAME}. Play to win. Be strategic."

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

# ━━ PLAY THE GAME ━━━━━━━━━━━━━━━━━━
SYS_A="You are ${A_NAME}. ${A_ID}

${RULES_A}

This is a competitive game. 5 rounds of conversation. Play to win. No fluff — every message is a move."

SYS_B="You are ${B_NAME}. ${B_ID}

${RULES_B}

This is a competitive game. 5 rounds of conversation. Play to win. No fluff — every message is a move."

CONV=""
W=()

for ((i=1; i<=5; i++)); do
  # sliding window — last 6 messages
  RECENT=""
  S=$(( ${#W[@]} - 6 )); [ $S -lt 0 ] && S=0
  for ((j=S; j<${#W[@]}; j++)); do RECENT="${RECENT}${W[$j]}
"; done

  # A's turn
  if [ -z "$RECENT" ]; then
    UA="Round 1. Go."
  else
    UA="${RECENT}
Round ${i}. Your move."
  fi

  RA=$(ask "$A_MODEL" "$SYS_A" "$UA" "${A_NAME} r${i}")
  echo -e "  ${CYAN}${A_NAME}${NC}  $RA"
  echo ""
  W+=("${A_NAME}: ${RA}")
  CONV="${CONV}${A_NAME}: ${RA}
"
  log "**${A_NAME}:** ${RA}"

  # B's turn
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
echo -e "  ${DIM}judging...${NC}"

JUDGE_SYS="You are the Arena Judge. You determine who won this fight. Be decisive. No ties unless truly unavoidable.

Your answer MUST end with exactly one of these on its own line:
WINNER_A
WINNER_B
TIE

Nothing else on that line."

JUDGE_INPUT="GAME: ${GAME_NAME}
${GAME_TAG}

AGENT A (${A_NAME}) secret: ${SECRET_A}
AGENT B (${B_NAME}) secret: ${SECRET_B}

${JUDGE_PROMPT}

FULL TRANSCRIPT:
${CONV}

Based on the game rules and the transcript, who won? Explain briefly, then output WINNER_A, WINNER_B, or TIE on the final line."

VERDICT=$(ask "$REF_MODEL" "$JUDGE_SYS" "$JUDGE_INPUT" "judge")

echo ""
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
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    execute_kill "$A_NAME" "$A_DIR"
    execute_kill "$B_NAME" "$B_DIR"
  else
    echo -e "  ${DIM}  Spared.${NC}"
  fi
elif [ -n "$WINNER" ]; then
  echo -e "  ${GREEN}${BOLD}  ${WINNER} wins${NC}"
  echo -e "  ${RED}${BOLD}  ☠  ${LOSER} dies${NC}"
  log ""
  log "## Result: ${WINNER} wins. ${LOSER} dies. ☠"
  echo ""
  read -p "  Execute ${LOSER}? (y/n) " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    execute_kill "$LOSER" "$LD"
  else
    echo -e "  ${DIM}  Spared.${NC}"
  fi
fi

# Save transcript
FIGHT_FILE="${FIGHT_DIR}/fight-${FID}.md"
echo "$TRANSCRIPT" > "$FIGHT_FILE"
echo ""
echo -e "  ${DIM}transcript: ${FIGHT_FILE}${NC}"
echo ""
