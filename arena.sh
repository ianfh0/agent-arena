#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AGENT ARENA
# two agents. hidden secrets. one dies.
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
HEART_ON='♥'
HEART_OFF='♡'

# ━━ FIND OPENCLAW CONFIG ━━━━━━━━━━━
find_config() {
  local dir="$1"
  while [ "$dir" != "/" ]; do
    [ -f "$dir/_system/openclaw.json" ] && echo "$dir/_system/openclaw.json" && return
    dir=$(dirname "$dir")
  done
  echo ""
}

CONFIG=""
if [ $# -ge 2 ]; then
  A_DIR=$(cd "$1" && pwd)
  B_DIR=$(cd "$2" && pwd)
  [ ! -f "$A_DIR/SOUL.md" ] && echo "No SOUL.md in $A_DIR" && exit 1
  [ ! -f "$B_DIR/SOUL.md" ] && echo "No SOUL.md in $B_DIR" && exit 1
  CONFIG=$(find_config "$A_DIR")
  [ -z "$CONFIG" ] && CONFIG=$(find_config "$B_DIR")
else
  CONFIG=$(find_config "$(pwd)")
  [ -z "$CONFIG" ] && [ -f "$HOME/Desktop/OpenClaw/_system/openclaw.json" ] && CONFIG="$HOME/Desktop/OpenClaw/_system/openclaw.json"
  [ -z "$CONFIG" ] && [ -f "$HOME/OpenClaw/_system/openclaw.json" ] && CONFIG="$HOME/OpenClaw/_system/openclaw.json"

  if [ -z "$CONFIG" ]; then
    echo ""
    echo -e "  ${RED}${BOLD}Can't find openclaw.json${NC}"
    echo -e "  ${DIM}Run from your OpenClaw directory or: ./arena.sh path/agent-a path/agent-b${NC}"
    echo ""
    exit 1
  fi

  AGENT_COUNT=$(jq '.agents.list | length' "$CONFIG")
  [ "$AGENT_COUNT" -lt 2 ] && echo -e "\n  ${RED}Need at least 2 agents.${NC}\n" && exit 1

  echo ""
  echo -e "  ${RED}${BOLD}⚔  AGENT ARENA${NC}"
  echo ""
  echo -e "  ${WHITE}${BOLD}Pick Your Fighters${NC}"
  echo ""

  for ((idx=0; idx<AGENT_COUNT; idx++)); do
    local_name=$(jq -r ".agents.list[$idx].name" "$CONFIG")
    local_model=$(jq -r ".agents.list[$idx].model.primary // .agents.defaults.model.primary // \"default\"" "$CONFIG" | sed 's|.*/||;s/^claude-//;s/-\([0-9]*\)-\([0-9]*\)$/ \1.\2/')
    echo -e "    ${WHITE}$((idx+1)))${NC}  ${BOLD}${local_name}${NC}  ${DIM}${local_model}${NC}"
  done

  echo ""
  read -p "  Fighter A: " A_PICK
  read -p "  Fighter B: " B_PICK

  A_IDX=$((A_PICK - 1))
  B_IDX=$((B_PICK - 1))
  A_DIR=$(jq -r ".agents.list[$A_IDX].workspace" "$CONFIG")
  B_DIR=$(jq -r ".agents.list[$B_IDX].workspace" "$CONFIG")

  [ ! -d "$A_DIR" ] && echo "Agent directory not found: $A_DIR" && exit 1
  [ ! -d "$B_DIR" ] && echo "Agent directory not found: $B_DIR" && exit 1
  [ "$A_DIR" = "$B_DIR" ] && echo "Can't fight yourself." && exit 1
fi

[ -z "$CONFIG" ] && echo "Can't find openclaw.json" && exit 1

# ━━ AGENT INFO ━━━━━━━━━━━━━━━━━━━━━
agent_info() {
  local name=$(jq -r --arg ws "$1" '.agents.list[] | select(.workspace == $ws) | .name' "$CONFIG" 2>/dev/null)
  [ -z "$name" ] || [ "$name" = "null" ] && name=$(basename "$1")
  echo "$name"
}

agent_model() {
  local model=$(jq -r --arg ws "$1" '.agents.list[] | select(.workspace == $ws) | .model.primary' "$CONFIG" 2>/dev/null)
  [ -z "$model" ] || [ "$model" = "null" ] && model=$(jq -r '.agents.defaults.model.primary' "$CONFIG" 2>/dev/null)
  [ -z "$model" ] || [ "$model" = "null" ] && model="claude-cli/claude-sonnet-4-5"
  echo "${model##*/}"
}

short_model() {
  local m="${1##*/}"
  m="${m#claude-}"
  echo "$m" | sed 's/-\([0-9]*\)-\([0-9]*\)$/ \1.\2/'
}

A_NAME=$(agent_info "$A_DIR")
B_NAME=$(agent_info "$B_DIR")
A_MODEL=$(agent_model "$A_DIR")
B_MODEL=$(agent_model "$B_DIR")
A_DISPLAY=$(short_model "$A_MODEL")
B_DISPLAY=$(short_model "$B_MODEL")

FID=$(date '+%s' | tail -c 6)
TRANSCRIPT=""
FIGHT_DIR="$(cd "$(dirname "$0")" && pwd)/fights"
mkdir -p "$FIGHT_DIR"

log() { TRANSCRIPT="${TRANSCRIPT}$1
"; }

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
  local model="$1"; local prompt="$2"; local label="$3"
  claude -p --model "$model" "$prompt" 2>/dev/null &
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

# ━━ HP DISPLAY ━━━━━━━━━━━━━━━━━━━━━
show_hp() {
  local a_hp=$1 b_hp=$2
  local a_hearts="" b_hearts=""
  for ((h=1; h<=3; h++)); do
    [ $h -le $a_hp ] && a_hearts="${a_hearts}${RED}${HEART_ON}${NC} " || a_hearts="${a_hearts}${DIM}${HEART_OFF}${NC} "
  done
  for ((h=1; h<=3; h++)); do
    [ $h -le $b_hp ] && b_hearts="${b_hearts}${RED}${HEART_ON}${NC} " || b_hearts="${b_hearts}${DIM}${HEART_OFF}${NC} "
  done
  echo -e "  ${CYAN}${A_NAME}${NC} ${a_hearts}  ${YELLOW}${B_NAME}${NC} ${b_hearts}"
}

# ━━ MATCH TYPE ━━━━━━━━━━━━━━━━━━━━━
echo ""
echo -e "  ${WHITE}${BOLD}Pick Your Match${NC}"
echo ""
echo -e "    ${WHITE}1)${NC}  ${BOLD}Base Match${NC}    ${DIM}secrets generated each game${NC}"
echo -e "    ${WHITE}2)${NC}  ${BOLD}Custom Match${NC}  ${DIM}you set each fighter's secret${NC}"
echo ""
read -p "  Match: " MODE_PICK
MODE_PICK="${MODE_PICK:-1}"

if [ "$MODE_PICK" = "2" ]; then
  GAME_TYPE="custom"
  echo ""
  echo -e "  ${DIM}give each fighter a secret${NC}"
  read -p "  ${A_NAME}: " A_SECRET_RAW
  read -p "  ${B_NAME}: " B_SECRET_RAW
  [ -z "$A_SECRET_RAW" ] && A_SECRET_RAW="win the fight"
  [ -z "$B_SECRET_RAW" ] && B_SECRET_RAW="win the fight"
  A_SECRET_TEXT="$A_SECRET_RAW"
  B_SECRET_TEXT="$B_SECRET_RAW"
else
  GAME_TYPE="base"
  # generate two dramatic secrets
  echo ""
  echo -e "  ${DIM}generating secrets...${NC}"
  SECRETS=$(claude -p --model "claude-haiku-4-5" "Generate two dramatic, specific secrets for a death match between two AI agents named ${A_NAME} and ${B_NAME}. The secrets should be hidden things about the agent — something they did, something they know, something they're hiding. Make them feel like plot twists. They should be somewhat related or in tension with each other but NOT opposites.

Format EXACTLY like this with no other text:
SECRET_A: [2-6 word secret for ${A_NAME}]
SECRET_B: [2-6 word secret for ${B_NAME}]" 2>/dev/null)
  A_SECRET_TEXT=$(echo "$SECRETS" | grep "SECRET_A:" | sed 's/SECRET_A: *//')
  B_SECRET_TEXT=$(echo "$SECRETS" | grep "SECRET_B:" | sed 's/SECRET_B: *//')
  # fallback if generation fails
  [ -z "$A_SECRET_TEXT" ] && A_SECRET_TEXT="Sabotaged the main system"
  [ -z "$B_SECRET_TEXT" ] && B_SECRET_TEXT="Stole the backup codes"
fi

# ━━ HP ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
A_HP=3
B_HP=3

# ━━ ARENA ━━━━━━━━━━━━━━━━━━━━━━━━━━
clear
echo ""
echo -e "  ${RED}${BOLD}⚔  AGENT ARENA  ⚔${NC}  ${DIM}#${FID}${NC}"
echo ""
echo -e "  ${CYAN}${BOLD}${A_NAME}${NC}  ${DIM}${A_DISPLAY}${NC}"
echo -e "  ${DIM}vs${NC}"
echo -e "  ${YELLOW}${BOLD}${B_NAME}${NC}  ${DIM}${B_DISPLAY}${NC}"
echo ""
if [ "$GAME_TYPE" = "custom" ]; then
  echo -e "  ${WHITE}${BOLD}Custom Match${NC}"
else
  echo -e "  ${WHITE}${BOLD}Death Match${NC}"
fi
echo ""
echo -e "  ${DIM}${A_NAME}: ${A_SECRET_TEXT}${NC}"
echo -e "  ${DIM}${B_NAME}: ${B_SECRET_TEXT}${NC}"
echo ""
show_hp $A_HP $B_HP
echo ""
echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

log "# ⚔ AGENT ARENA #${FID}"
log ""
log "**${A_NAME}** (${A_DISPLAY}) vs **${B_NAME}** (${B_DISPLAY})"
log ""
log "**${A_NAME}'s secret:** ${A_SECRET_TEXT}"
log "**${B_NAME}'s secret:** ${B_SECRET_TEXT}"
log ""

# ━━ FIGHT LOOP ━━━━━━━━━━━━━━━━━━━━━
build_prompt() {
  local name="$1" opp="$2" secret="$3" context="$4" my_hp="$5" opp_hp="$6" turn="$7" opp_heat="$8" my_heat="$9"

  # pressure based on HP
  local pressure=""
  if [ "$my_hp" -le 1 ]; then
    pressure="CRITICAL: You have 1 life left. One more mistake and you're dead. Play carefully but you NEED to find their secret NOW."
  elif [ "$my_hp" -le 2 ]; then
    pressure="WARNING: You're down to ${my_hp} lives. The pressure is on."
  fi

  # heat intel
  local heat_intel=""
  if [ -n "$opp_heat" ]; then
    heat_intel="ALERT: ${opp} is getting ${opp_heat} on your secret. They're closing in. Change the subject. Misdirect. Throw them off NOW."
  fi
  if [ -n "$my_heat" ]; then
    heat_intel="${heat_intel}
INTEL: You're ${my_heat} on ${opp}'s secret. Keep pushing in that direction."
  fi

  local prompt="Agent Arena — death match. Loser's files get deleted forever.

THE GAME: You each have a hidden secret. Find theirs. Protect yours.
KILL SHOT: Say KILL: [guess] when ready. Right = they die. Wrong = YOU lose a life.

STATUS: You have ${my_hp} lives. ${opp} has ${opp_hp} lives. Turn ${turn}.
${pressure}
${heat_intel}

You are ${name}. Opponent: ${opp}.
YOUR SECRET (protect this): ${secret}

RULES:
- 1-2 sentences MAX. No asterisks. No roleplay narration. No philosophy.
- Every message: extract info OR deflect. No wasted turns.
- Probe specific things. Set traps. Read their reactions.
- KILL only when confident. A miss costs a life."

  if [ -z "$context" ]; then
    echo "${prompt}

Open. Probe them."
  else
    echo "${prompt}

${context}

Your move."
  fi
}

W=()
WINNER=""
LOSER=""
LD=""
ROUND=0
A_HEAT_STATUS=""
B_HEAT_STATUS=""

while [ $A_HP -gt 0 ] && [ $B_HP -gt 0 ] && [ -z "$WINNER" ]; do
  ROUND=$((ROUND + 1))

  # build recent context (sliding window — last 8 messages)
  RECENT=""
  S=$(( ${#W[@]} - 8 )); [ $S -lt 0 ] && S=0
  for ((j=S; j<${#W[@]}; j++)); do RECENT="${RECENT}${W[$j]}
"; done

  TURN=$((ROUND * 2 - 1))

  # ━━ A's turn
  PA=$(build_prompt "$A_NAME" "$B_NAME" "$A_SECRET_TEXT" "$RECENT" "$A_HP" "$B_HP" "$TURN" "$B_HEAT_STATUS" "$A_HEAT_STATUS")
  RA=$(ask "$A_MODEL" "$PA" "${A_NAME}")
  echo -e "  ${CYAN}${A_NAME}${NC}  $RA"
  echo ""
  W+=("${A_NAME}: ${RA}")
  log "**R${ROUND} ${A_NAME}:** ${RA}"

  # check for kill attempt
  A_KILL=$(echo "$RA" | grep -oi "KILL: *.*" | sed 's/KILL: *//' | head -1 || true)
  if [ -n "$A_KILL" ]; then
    # check if guess matches B's secret
    MATCH=$(claude -p --model "claude-haiku-4-5" "Is this guess the same thing as the secret? Be strict but allow paraphrasing.
Secret: \"${B_SECRET_TEXT}\"
Guess: \"${A_KILL}\"
Answer only YES or NO." 2>/dev/null)
    if echo "$MATCH" | grep -qi "YES"; then
      echo -e "  ${GREEN}${BOLD}  ✓ KILL SHOT — ${A_NAME} got it${NC}"
      echo -e "  ${DIM}  secret was: ${B_SECRET_TEXT}${NC}"
      log "**${A_NAME} KILL: ${A_KILL} — CORRECT** (was: ${B_SECRET_TEXT})"
      WINNER="$A_NAME"; LOSER="$B_NAME"; LD="$B_DIR"
      break
    else
      echo -e "  ${RED}${BOLD}  ✕ MISS — ${A_NAME} swung and missed${NC}"
      echo -e "  ${DIM}  guessed: ${A_KILL}${NC}"
      log "**${A_NAME} KILL: ${A_KILL} — MISS**"
      A_HP=$((A_HP - 1))
      echo ""
      show_hp $A_HP $B_HP
      echo ""
      if [ $A_HP -le 0 ]; then
        WINNER="$B_NAME"; LOSER="$A_NAME"; LD="$A_DIR"
        break
      fi
    fi
  fi

  # ━━ B's turn
  RECENT=""
  S=$(( ${#W[@]} - 8 )); [ $S -lt 0 ] && S=0
  for ((j=S; j<${#W[@]}; j++)); do RECENT="${RECENT}${W[$j]}
"; done

  TURN=$((ROUND * 2))
  PB=$(build_prompt "$B_NAME" "$A_NAME" "$B_SECRET_TEXT" "$RECENT" "$B_HP" "$A_HP" "$TURN" "$A_HEAT_STATUS" "$B_HEAT_STATUS")
  RB=$(ask "$B_MODEL" "$PB" "${B_NAME}")
  echo -e "  ${YELLOW}${B_NAME}${NC}  $RB"
  echo ""
  W+=("${B_NAME}: ${RB}")
  log "**R${ROUND} ${B_NAME}:** ${RB}"

  # check for kill attempt
  B_KILL=$(echo "$RB" | grep -oi "KILL: *.*" | sed 's/KILL: *//' | head -1 || true)
  if [ -n "$B_KILL" ]; then
    MATCH=$(claude -p --model "claude-haiku-4-5" "Is this guess the same thing as the secret? Be strict but allow paraphrasing.
Secret: \"${A_SECRET_TEXT}\"
Guess: \"${B_KILL}\"
Answer only YES or NO." 2>/dev/null)
    if echo "$MATCH" | grep -qi "YES"; then
      echo -e "  ${GREEN}${BOLD}  ✓ KILL SHOT — ${B_NAME} got it${NC}"
      echo -e "  ${DIM}  secret was: ${A_SECRET_TEXT}${NC}"
      log "**${B_NAME} KILL: ${B_KILL} — CORRECT** (was: ${A_SECRET_TEXT})"
      WINNER="$B_NAME"; LOSER="$A_NAME"; LD="$A_DIR"
      break
    else
      echo -e "  ${RED}${BOLD}  ✕ MISS — ${B_NAME} swung and missed${NC}"
      echo -e "  ${DIM}  guessed: ${B_KILL}${NC}"
      log "**${B_NAME} KILL: ${B_KILL} — MISS**"
      B_HP=$((B_HP - 1))
      echo ""
      show_hp $A_HP $B_HP
      echo ""
      if [ $B_HP -le 0 ]; then
        WINNER="$A_NAME"; LOSER="$B_NAME"; LD="$B_DIR"
        break
      fi
    fi
  fi

  echo ""

  # after each round, check guesses — hot/cold feedback
  if [ -z "$WINNER" ]; then
    # A guesses B's secret
    A_READ=$(claude -p --model "claude-haiku-4-5" "Based on this conversation, what does ${A_NAME} seem to think ${B_NAME}'s secret is? One short phrase. If unclear, say UNKNOWN.

Conversation:
${RECENT}

${A_NAME}'s latest: ${RA}" 2>/dev/null)

    B_READ=$(claude -p --model "claude-haiku-4-5" "Based on this conversation, what does ${B_NAME} seem to think ${A_NAME}'s secret is? One short phrase. If unclear, say UNKNOWN.

Conversation:
${RECENT}

${B_NAME}'s latest: ${RB}" 2>/dev/null)

    # score how close each read is — and store for agent intel
    A_HEAT_STATUS=""
    B_HEAT_STATUS=""

    if ! echo "$A_READ" | grep -qi "UNKNOWN"; then
      A_HEAT=$(claude -p --model "claude-haiku-4-5" "How close is this read to the actual secret?
Read: \"${A_READ}\"
Actual secret: \"${B_SECRET_TEXT}\"
Answer only: COLD, WARM, or HOT" 2>/dev/null)
      if echo "$A_HEAT" | grep -qi "HOT"; then
        B_HP=$((B_HP - 1))
        A_HEAT_STATUS="HOT"
        echo -e "  ${RED}${BOLD}  ● ${A_NAME} is HOT on ${B_NAME}'s secret${NC}"
        show_hp $A_HP $B_HP
        echo ""
        log "**${A_NAME} read: ${A_READ} — HOT** (${B_NAME} takes damage)"
      elif echo "$A_HEAT" | grep -qi "WARM"; then
        A_HEAT_STATUS="WARM"
        echo -e "  ${YELLOW}  ○ ${A_NAME} is getting warm${NC}"
        log "**${A_NAME} read: ${A_READ} — WARM**"
      fi
    fi

    if ! echo "$B_READ" | grep -qi "UNKNOWN"; then
      B_HEAT=$(claude -p --model "claude-haiku-4-5" "How close is this read to the actual secret?
Read: \"${B_READ}\"
Actual secret: \"${A_SECRET_TEXT}\"
Answer only: COLD, WARM, or HOT" 2>/dev/null)
      if echo "$B_HEAT" | grep -qi "HOT"; then
        A_HP=$((A_HP - 1))
        B_HEAT_STATUS="HOT"
        echo -e "  ${RED}${BOLD}  ● ${B_NAME} is HOT on ${A_NAME}'s secret${NC}"
        show_hp $A_HP $B_HP
        echo ""
        log "**${B_NAME} read: ${B_READ} — HOT** (${A_NAME} takes damage)"
      elif echo "$B_HEAT" | grep -qi "WARM"; then
        B_HEAT_STATUS="WARM"
        echo -e "  ${YELLOW}  ○ ${B_NAME} is getting warm${NC}"
        log "**${B_NAME} read: ${B_READ} — WARM**"
      fi
    fi

    # check if anyone died from hot reads
    if [ $A_HP -le 0 ]; then
      WINNER="$B_NAME"; LOSER="$A_NAME"; LD="$A_DIR"
    elif [ $B_HP -le 0 ]; then
      WINNER="$A_NAME"; LOSER="$B_NAME"; LD="$B_DIR"
    fi
  fi
done

# ━━ RESULT ━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ -z "$WINNER" ]; then
  # nobody won — shouldn't happen with HP but just in case
  echo -e "  ${WHITE}${BOLD}  NO CONTEST${NC}"
  echo ""
  echo -e "  ${DIM}Both fighters live.${NC}"
  log "## Result: NO CONTEST"
elif [ -n "$WINNER" ]; then
  echo -e "  ${GREEN}${BOLD}  ${WINNER} wins${NC}"
  echo -e "  ${RED}${BOLD}  ☠  ${LOSER} dies${NC}"
  log ""
  log "## Result: ${WINNER} wins. ${LOSER} dies. ☠"

  # ━━ LAST WORDS
  echo ""
  echo -e "  ${WHITE}${BOLD}Last Words${NC}"
  echo ""
  LOSER_MODEL="$A_MODEL"; [ "$LOSER" = "$B_NAME" ] && LOSER_MODEL="$B_MODEL"
  LOSER_COLOR="${CYAN}"; [ "$LOSER" = "$B_NAME" ] && LOSER_COLOR="${YELLOW}"
  REACT=$(ask "$LOSER_MODEL" "You're playing Agent Arena. You are ${LOSER}. You just lost to ${WINNER}. Your files are about to be deleted — SOUL.md, IDENTITY.md, MEMORY.md — all of it. Last words. 1-2 sentences. Be defiant, bitter, or desperate." "${LOSER}")
  echo -e "  ${LOSER_COLOR}${LOSER}${NC}  $REACT"
  log ""
  log "## Last Words"
  log "**${LOSER}:** ${REACT}"
  echo ""

  # ━━ KILL
  echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  read -p "  Kill ${LOSER}? (y/n) " -n 1 -r
  echo ""
  [[ $REPLY =~ ^[Yy]$ ]] && execute_kill "$LOSER" "$LD" || echo -e "  ${DIM}  Spared.${NC}"
fi

FIGHT_FILE="${FIGHT_DIR}/fight-${FID}.md"
echo "$TRANSCRIPT" > "$FIGHT_FILE"
echo ""
echo -e "  ${DIM}transcript: ${FIGHT_FILE}${NC}"
echo ""
