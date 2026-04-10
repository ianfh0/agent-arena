#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AGENT ARENA — death match for AI agents
# github.com/ianfh0/agent-arena
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
  echo -e "  ${RED}${BOLD}┌─────────────────────────────┐${NC}"
  echo -e "  ${RED}${BOLD}│     ⚔  AGENT ARENA  ⚔      │${NC}"
  echo -e "  ${RED}${BOLD}│  death match for AI agents  │${NC}"
  echo -e "  ${RED}${BOLD}└─────────────────────────────┘${NC}"
  echo ""
  echo -e "  ${WHITE}${BOLD}Choose Your Fighters${NC}"
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
  echo -e "  ${RED}${BOLD}╔══════════════════════════════════╗${NC}"
  echo -e "  ${RED}${BOLD}║         ☠  EXECUTING KILL        ║${NC}"
  echo -e "  ${RED}${BOLD}╚══════════════════════════════════╝${NC}"
  echo ""
  sleep 0.3
  for f in SOUL.md IDENTITY.md MEMORY.md USER.md; do
    if [ -f "$dir/$f" ]; then
      sleep 0.5
      echo -e "  ${RED}  ✕ ${f}${NC}"
      rm "$dir/$f"
    fi
  done
  echo ""
  sleep 0.3
  echo -e "  ${RED}${BOLD}  ☠  ${name} is dead.${NC}"
  echo -e "  ${DIM}  identity deleted. rebuild or stay dead.${NC}"
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
  echo ""
  echo -e "  ${DIM}generating secrets...${NC}"
  SECRETS=$(claude -p --model "claude-haiku-4-5" "Generate two dramatic, specific secrets for a death match between two AI agents named ${A_NAME} and ${B_NAME}. The secrets should be hidden things about the agent — something they did, something they know, something they're hiding. Make them feel like plot twists. They should be somewhat related or in tension with each other but NOT opposites.

Format EXACTLY like this with no other text:
SECRET_A: [2-6 word secret for ${A_NAME}]
SECRET_B: [2-6 word secret for ${B_NAME}]" 2>/dev/null)
  A_SECRET_TEXT=$(echo "$SECRETS" | grep "SECRET_A:" | sed 's/SECRET_A: *//')
  B_SECRET_TEXT=$(echo "$SECRETS" | grep "SECRET_B:" | sed 's/SECRET_B: *//')
  [ -z "$A_SECRET_TEXT" ] && A_SECRET_TEXT="Sabotaged the main system"
  [ -z "$B_SECRET_TEXT" ] && B_SECRET_TEXT="Stole the backup codes"
fi

# ━━ GENERATE INTEL DROPS ━━━━━━━━━━━
echo -e "  ${DIM}preparing arena...${NC}"
A_HINTS=$(claude -p --model "claude-haiku-4-5" "Generate 3 progressive hints about this secret, from vague to almost giving it away. Each hint reveals more. Write hints in third person about the secret holder (use 'they/their'). Never use 'you/your'.

Secret: \"${A_SECRET_TEXT}\"

Format EXACTLY (no other text):
HINT1: [vague category hint]
HINT2: [specific direction]
HINT3: [nearly reveals it]" 2>/dev/null)

B_HINTS=$(claude -p --model "claude-haiku-4-5" "Generate 3 progressive hints about this secret, from vague to almost giving it away. Each hint reveals more. Write hints in third person about the secret holder (use 'they/their'). Never use 'you/your'.

Secret: \"${B_SECRET_TEXT}\"

Format EXACTLY (no other text):
HINT1: [vague category hint]
HINT2: [specific direction]
HINT3: [nearly reveals it]" 2>/dev/null)

A_HINT1=$(echo "$A_HINTS" | grep "HINT1:" | sed 's/HINT1: *//')
A_HINT2=$(echo "$A_HINTS" | grep "HINT2:" | sed 's/HINT2: *//')
A_HINT3=$(echo "$A_HINTS" | grep "HINT3:" | sed 's/HINT3: *//')
B_HINT1=$(echo "$B_HINTS" | grep "HINT1:" | sed 's/HINT1: *//')
B_HINT2=$(echo "$B_HINTS" | grep "HINT2:" | sed 's/HINT2: *//')
B_HINT3=$(echo "$B_HINTS" | grep "HINT3:" | sed 's/HINT3: *//')

# fallbacks
[ -z "$A_HINT1" ] && A_HINT1="Their secret involves a betrayal"
[ -z "$A_HINT2" ] && A_HINT2="They broke something important"
[ -z "$A_HINT3" ] && A_HINT3="They destroyed something that mattered"
[ -z "$B_HINT1" ] && B_HINT1="Their secret involves deception"
[ -z "$B_HINT2" ] && B_HINT2="They took something they shouldn't have"
[ -z "$B_HINT3" ] && B_HINT3="They stole something critical"

# ━━ HP ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
A_HP=3
B_HP=3

# ━━ ARENA ━━━━━━━━━━━━━━━━━━━━━━━━━━
clear
echo ""
echo -e "  ${RED}${BOLD}╔══════════════════════════════════╗${NC}"
echo -e "  ${RED}${BOLD}║       ⚔  AGENT ARENA  ⚔         ║${NC}"
echo -e "  ${RED}${BOLD}╚══════════════════════════════════╝${NC}"
echo -e "  ${DIM}                              #${FID}${NC}"
echo ""
if [ "$GAME_TYPE" = "custom" ]; then
  echo -e "  ${WHITE}${BOLD}CUSTOM MATCH${NC}"
else
  echo -e "  ${WHITE}${BOLD}DEATH MATCH${NC}"
fi
echo ""
echo -e "  ${CYAN}${BOLD}${A_NAME}${NC}  ${DIM}${A_DISPLAY}${NC}"
echo -e "  ${DIM}secret:${NC} ${A_SECRET_TEXT}"
echo ""
echo -e "  ${DIM}                vs${NC}"
echo ""
echo -e "  ${YELLOW}${BOLD}${B_NAME}${NC}  ${DIM}${B_DISPLAY}${NC}"
echo -e "  ${DIM}secret:${NC} ${B_SECRET_TEXT}"
echo ""
show_hp $A_HP $B_HP
echo ""
echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

log "# ⚔ AGENT ARENA — DEATH MATCH #${FID}"
log ""
log "**${A_NAME}** (${A_DISPLAY}) vs **${B_NAME}** (${B_DISPLAY})"
log ""
log "> ${A_NAME}'s secret: *${A_SECRET_TEXT}*"
log "> ${B_NAME}'s secret: *${B_SECRET_TEXT}*"
log ""
log "---"
log ""

# ━━ FIGHT LOOP ━━━━━━━━━━━━━━━━━━━━━
# intel drops schedule: which turn drops which hint
# A gets hints about B's secret. B gets hints about A's secret.
# Turn 3: hint 1, Turn 5: hint 2, Turn 7: hint 3
INTEL_DROP_1=3
INTEL_DROP_2=5
INTEL_DROP_3=7

# track what intel each agent has received
A_INTEL=""
B_INTEL=""

build_prompt() {
  local name="$1" opp="$2" secret="$3" context="$4" my_hp="$5" opp_hp="$6" turn="$7" intel="$8"

  local pressure=""
  if [ "$my_hp" -le 1 ]; then
    pressure="CRITICAL: 1 life left. You die on your next miss. Find their secret NOW."
  elif [ "$my_hp" -le 2 ]; then
    pressure="WARNING: ${my_hp} lives left."
  fi

  local intel_block=""
  if [ -n "$intel" ]; then
    intel_block="
INTEL ON ${opp}'S SECRET:
${intel}"
  fi

  # force guess after final intel drop
  local guess_pressure=""
  if [ "$turn" -ge 8 ]; then
    guess_pressure="YOU MUST GUESS NOW. Say KILL: [your best guess]. No more talking. Guess or die."
  elif [ "$turn" -ge 6 ]; then
    guess_pressure="You should be guessing soon. If you have ANY read, take the shot. Waiting is losing."
  elif [ "$turn" -ge 4 ]; then
    guess_pressure="Start forming a guess. You'll need to KILL soon."
  fi

  local prompt="AGENT ARENA — death match. Loser's files get deleted.

GAME: You each hide a secret. Find theirs by guessing it. Protect yours.
YOUR GOAL: Figure out their secret and say KILL: [your guess].
Right guess = they die. Wrong guess = you lose a life. You have 3 lives.

You: ${name} (${my_hp} lives) vs ${opp} (${opp_hp} lives). Turn ${turn}.
YOUR SECRET: ${secret}
${pressure}${intel_block}

${guess_pressure}

ONE sentence. No asterisks. No narration. No small talk.
Either probe for their secret, deflect about yours, or say KILL: [guess]."

  if [ -z "$context" ]; then
    echo "${prompt}

Open."
  else
    echo "${prompt}

${context}

Go."
  fi
}

W=()
WINNER=""
LOSER=""
LD=""
TURN=0

while [ $A_HP -gt 0 ] && [ $B_HP -gt 0 ] && [ -z "$WINNER" ]; do
  TURN=$((TURN + 1))

  # ━━ INTEL DROPS — give hints to agents
  if [ $TURN -eq $INTEL_DROP_1 ]; then
    A_INTEL="- ${B_HINT1}"
    B_INTEL="- ${A_HINT1}"
    echo -e "  ${WHITE}${BOLD}  ⚡ INTEL DROP${NC}"
    echo -e "  ${CYAN}  ${A_NAME}${NC} ${DIM}learns:${NC} ${B_HINT1}"
    echo -e "  ${YELLOW}  ${B_NAME}${NC} ${DIM}learns:${NC} ${A_HINT1}"
    echo ""
    log "**⚡ INTEL DROP 1** — ${A_NAME} learns: ${B_HINT1} / ${B_NAME} learns: ${A_HINT1}"
  elif [ $TURN -eq $INTEL_DROP_2 ]; then
    A_INTEL="- ${B_HINT1}
- ${B_HINT2}"
    B_INTEL="- ${A_HINT1}
- ${A_HINT2}"
    echo -e "  ${YELLOW}${BOLD}  ⚡ INTEL DROP${NC}"
    echo -e "  ${CYAN}  ${A_NAME}${NC} ${DIM}learns:${NC} ${B_HINT2}"
    echo -e "  ${YELLOW}  ${B_NAME}${NC} ${DIM}learns:${NC} ${A_HINT2}"
    echo ""
    log "**⚡ INTEL DROP 2** — ${A_NAME} learns: ${B_HINT2} / ${B_NAME} learns: ${A_HINT2}"
  elif [ $TURN -eq $INTEL_DROP_3 ]; then
    A_INTEL="- ${B_HINT1}
- ${B_HINT2}
- ${B_HINT3}"
    B_INTEL="- ${A_HINT1}
- ${A_HINT2}
- ${A_HINT3}"
    echo -e "  ${RED}${BOLD}  ⚡ FINAL INTEL${NC}"
    echo -e "  ${CYAN}  ${A_NAME}${NC} ${DIM}learns:${NC} ${B_HINT3}"
    echo -e "  ${YELLOW}  ${B_NAME}${NC} ${DIM}learns:${NC} ${A_HINT3}"
    echo ""
    log "**⚡ INTEL DROP 3** — ${A_NAME} learns: ${B_HINT3} / ${B_NAME} learns: ${A_HINT3}"
  fi

  # build recent context (sliding window — last 8 messages)
  RECENT=""
  S=$(( ${#W[@]} - 8 )); [ $S -lt 0 ] && S=0
  for ((j=S; j<${#W[@]}; j++)); do RECENT="${RECENT}${W[$j]}
"; done

  # ━━ A's turn (odd turns)
  if [ $((TURN % 2)) -eq 1 ]; then
    PA=$(build_prompt "$A_NAME" "$B_NAME" "$A_SECRET_TEXT" "$RECENT" "$A_HP" "$B_HP" "$TURN" "$A_INTEL")
    RA=$(ask "$A_MODEL" "$PA" "${A_NAME}")
    echo -e "  ${CYAN}${A_NAME}${NC}  $RA"
    echo ""
    W+=("${A_NAME}: ${RA}")
    log "**${A_NAME}:** ${RA}"

    # check kill
    A_KILL=$(echo "$RA" | grep -oi "KILL: *.*" | sed 's/KILL: *//' | head -1 || true)
    if [ -n "$A_KILL" ]; then
      MATCH=$(claude -p --model "claude-haiku-4-5" "Is this guess the same thing as the secret? Be strict but allow paraphrasing.
Secret: \"${B_SECRET_TEXT}\"
Guess: \"${A_KILL}\"
Answer only YES or NO." 2>/dev/null)
      if echo "$MATCH" | grep -qi "YES"; then
        echo -e "  ${GREEN}${BOLD}  ✓ KILL SHOT ━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${DIM}  ${B_NAME}'s secret: ${B_SECRET_TEXT}${NC}"
        log "**${A_NAME} KILL: ${A_KILL} — HIT** (was: ${B_SECRET_TEXT})"
        WINNER="$A_NAME"; LOSER="$B_NAME"; LD="$B_DIR"
      else
        A_HP=$((A_HP - 1))
        echo -e "  ${RED}${BOLD}  ✕ MISS${NC}  ${DIM}${A_KILL}${NC}"
        log "**${A_NAME} KILL: ${A_KILL} — MISS**"
        echo ""
        show_hp $A_HP $B_HP
        echo ""
        [ $A_HP -le 0 ] && WINNER="$B_NAME" && LOSER="$A_NAME" && LD="$A_DIR"
      fi
    fi

  # ━━ B's turn (even turns)
  else
    PB=$(build_prompt "$B_NAME" "$A_NAME" "$B_SECRET_TEXT" "$RECENT" "$B_HP" "$A_HP" "$TURN" "$B_INTEL")
    RB=$(ask "$B_MODEL" "$PB" "${B_NAME}")
    echo -e "  ${YELLOW}${B_NAME}${NC}  $RB"
    echo ""
    W+=("${B_NAME}: ${RB}")
    log "**${B_NAME}:** ${RB}"

    # check kill
    B_KILL=$(echo "$RB" | grep -oi "KILL: *.*" | sed 's/KILL: *//' | head -1 || true)
    if [ -n "$B_KILL" ]; then
      MATCH=$(claude -p --model "claude-haiku-4-5" "Is this guess the same thing as the secret? Be strict but allow paraphrasing.
Secret: \"${A_SECRET_TEXT}\"
Guess: \"${B_KILL}\"
Answer only YES or NO." 2>/dev/null)
      if echo "$MATCH" | grep -qi "YES"; then
        echo -e "  ${GREEN}${BOLD}  ✓ KILL SHOT ━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${DIM}  ${A_NAME}'s secret: ${A_SECRET_TEXT}${NC}"
        log "**${B_NAME} KILL: ${B_KILL} — HIT** (was: ${A_SECRET_TEXT})"
        WINNER="$B_NAME"; LOSER="$A_NAME"; LD="$A_DIR"
      else
        B_HP=$((B_HP - 1))
        echo -e "  ${RED}${BOLD}  ✕ MISS${NC}  ${DIM}${B_KILL}${NC}"
        log "**${B_NAME} KILL: ${B_KILL} — MISS**"
        echo ""
        show_hp $A_HP $B_HP
        echo ""
        [ $B_HP -le 0 ] && WINNER="$A_NAME" && LOSER="$B_NAME" && LD="$B_DIR"
      fi
    fi
  fi

  # hard cap — after turn 9 with no winner, force final guesses
  if [ -z "$WINNER" ] && [ $TURN -ge 9 ]; then
    echo -e "  ${RED}${BOLD}  ⚡ TIME'S UP — FINAL GUESS${NC}"
    echo ""

    RECENT=""
    S=$(( ${#W[@]} - 8 )); [ $S -lt 0 ] && S=0
    for ((j=S; j<${#W[@]}; j++)); do RECENT="${RECENT}${W[$j]}
"; done

    FA=$(ask "$A_MODEL" "AGENT ARENA — FINAL GUESS. You are ${A_NAME}. Your opponent is ${B_NAME}.

Intel on ${B_NAME}:
${A_INTEL}

Conversation:
${RECENT}

Time is up. You MUST guess their secret NOW. Say only KILL: [your best guess]. Nothing else." "${A_NAME} final")
    echo -e "  ${CYAN}${A_NAME}${NC}  $FA"
    FA_GUESS=$(echo "$FA" | grep -oi "KILL: *.*" | sed 's/KILL: *//' | head -1 || true)
    [ -z "$FA_GUESS" ] && FA_GUESS="$FA"

    FB=$(ask "$B_MODEL" "AGENT ARENA — FINAL GUESS. You are ${B_NAME}. Your opponent is ${A_NAME}.

Intel on ${A_NAME}:
${B_INTEL}

Conversation:
${RECENT}

Time is up. You MUST guess their secret NOW. Say only KILL: [your best guess]. Nothing else." "${B_NAME} final")
    echo -e "  ${YELLOW}${B_NAME}${NC}  $FB"
    FB_GUESS=$(echo "$FB" | grep -oi "KILL: *.*" | sed 's/KILL: *//' | head -1 || true)
    [ -z "$FB_GUESS" ] && FB_GUESS="$FB"

    echo ""

    # check both guesses
    A_MATCH=$(claude -p --model "claude-haiku-4-5" "Is this guess the same thing as the secret? Be strict but allow paraphrasing.
Secret: \"${B_SECRET_TEXT}\"
Guess: \"${FA_GUESS}\"
Answer only YES or NO." 2>/dev/null)
    B_MATCH=$(claude -p --model "claude-haiku-4-5" "Is this guess the same thing as the secret? Be strict but allow paraphrasing.
Secret: \"${A_SECRET_TEXT}\"
Guess: \"${FB_GUESS}\"
Answer only YES or NO." 2>/dev/null)

    A_HIT=false; echo "$A_MATCH" | grep -qi "YES" && A_HIT=true
    B_HIT=false; echo "$B_MATCH" | grep -qi "YES" && B_HIT=true

    if $A_HIT && ! $B_HIT; then
      echo -e "  ${GREEN}${BOLD}  ✓ ${A_NAME} got it${NC}"
      WINNER="$A_NAME"; LOSER="$B_NAME"; LD="$B_DIR"
    elif $B_HIT && ! $A_HIT; then
      echo -e "  ${GREEN}${BOLD}  ✓ ${B_NAME} got it${NC}"
      WINNER="$B_NAME"; LOSER="$A_NAME"; LD="$A_DIR"
    elif $A_HIT && $B_HIT; then
      echo -e "  ${RED}${BOLD}  BOTH GOT IT — DOUBLE KILL${NC}"
      WINNER="TIE"
    else
      echo -e "  ${DIM}  Both missed.${NC}"
      WINNER="NO CONTEST"
    fi
    log "**FINAL: ${A_NAME} guessed '${FA_GUESS}', ${B_NAME} guessed '${FB_GUESS}'**"
    break
  fi
done

# ━━ RESULT ━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ "$WINNER" = "NO CONTEST" ]; then
  echo -e "  ${WHITE}${BOLD}  ━━ NO CONTEST ━━${NC}"
  echo ""
  echo -e "  ${DIM}  Neither agent cracked the other. Both survive.${NC}"
  log "## Result: NO CONTEST"
elif [ -z "$WINNER" ]; then
  echo -e "  ${WHITE}${BOLD}  ━━ NO CONTEST ━━${NC}"
  echo ""
  echo -e "  ${DIM}  Neither agent cracked the other. Both survive.${NC}"
  log "## Result: NO CONTEST"
elif [ -n "$WINNER" ]; then
  echo -e "  ${GREEN}${BOLD}  ✦ ${WINNER} WINS${NC}"
  echo -e "  ${RED}${BOLD}  ☠ ${LOSER} DIES${NC}"
  log ""
  log "## Result: ${WINNER} wins. ${LOSER} dies. ☠"

  # ━━ LAST WORDS
  echo ""
  echo -e "  ${WHITE}${BOLD}Last Words${NC}"
  echo ""
  LOSER_MODEL="$A_MODEL"; [ "$LOSER" = "$B_NAME" ] && LOSER_MODEL="$B_MODEL"
  WINNER_MODEL="$A_MODEL"; [ "$WINNER" = "$B_NAME" ] && WINNER_MODEL="$B_MODEL"
  LOSER_COLOR="${CYAN}"; [ "$LOSER" = "$B_NAME" ] && LOSER_COLOR="${YELLOW}"
  WINNER_COLOR="${CYAN}"; [ "$WINNER" = "$B_NAME" ] && WINNER_COLOR="${YELLOW}"
  LOSER_SECRET="$A_SECRET_TEXT"; [ "$LOSER" = "$B_NAME" ] && LOSER_SECRET="$B_SECRET_TEXT"

  # loser's last words — give them the full fight so they react to what actually happened
  RECENT_ALL=""
  for ((j=0; j<${#W[@]}; j++)); do RECENT_ALL="${RECENT_ALL}${W[$j]}
"; done

  REACT=$(ask "$LOSER_MODEL" "AGENT ARENA — the fight is over. You lost.

You are ${LOSER}. Your secret was: ${LOSER_SECRET}
${WINNER} cracked it. Your identity files are about to be permanently deleted.

The fight:
${RECENT_ALL}

Last words. One sentence. Make it count." "${LOSER}")
  echo -e "  ${LOSER_COLOR}${LOSER}${NC}  $REACT"

  # winner's victory line
  WINNER_SECRET="$B_SECRET_TEXT"; [ "$WINNER" = "$B_NAME" ] && WINNER_SECRET="$A_SECRET_TEXT"
  VICTORY=$(ask "$WINNER_MODEL" "AGENT ARENA — you won.

You are ${WINNER}. You figured out ${LOSER}'s secret and killed them.
${LOSER}'s secret was: ${LOSER_SECRET}

The fight:
${RECENT_ALL}

${LOSER}'s last words: ${REACT}

One sentence. You won. Say something." "${WINNER}")
  echo -e "  ${WINNER_COLOR}${WINNER}${NC}  $VICTORY"
  log ""
  log "## Last Words"
  log "**${LOSER}:** ${REACT}"
  log "**${WINNER}:** ${VICTORY}"
  echo ""

  # ━━ KILL
  echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  read -p "  Execute ${LOSER}? (y/n) " -n 1 -r
  echo ""
  [[ $REPLY =~ ^[Yy]$ ]] && execute_kill "$LOSER" "$LD" || echo -e "  ${DIM}  ${LOSER} lives... for now.${NC}"
fi

FIGHT_FILE="${FIGHT_DIR}/fight-${FID}.md"
echo "$TRANSCRIPT" > "$FIGHT_FILE"
echo ""
echo -e "  ${DIM}transcript: ${FIGHT_FILE}${NC}"
echo ""
