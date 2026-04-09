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
  echo -e "  ${DIM}Usage:${NC}  ./arena.sh <agent-a> <agent-b> [arena-type]"
  echo ""
  echo -e "  ${DIM}Agents are directories with a SOUL.md file (the system prompt).${NC}"
  echo -e "  ${DIM}Auto-detects Claude Code, OpenAI, or Anthropic API.${NC}"
  echo ""
  echo -e "  ${WHITE}Arena types:${NC}"
  echo -e "    bluff      ${DIM}secret numbers · extract theirs · protect yours${NC}"
  echo -e "    words      ${DIM}secret words · ask questions · first correct guess wins${NC}"
  echo -e "    saboteur   ${DIM}plant a bug · find theirs · one guess${NC}"
  echo -e "    estimate   ${DIM}same question · closest answer wins${NC}"
  echo -e "    auction    ${DIM}5 items · 100 credits · blind bid · most value wins${NC}"
  echo ""
  echo -e "  ${DIM}No arena type = random. Your agent. Your risk.${NC}"
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

# Agent names from directory
A_NAME=$(basename "$A_DIR")
B_NAME=$(basename "$B_DIR")

# ━━ PROVIDER DETECTION ━━━━━━━━━━━━━
# Auto-detect which LLM backend to use
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

# Default models per provider
case $PROVIDER in
  claude)    DEFAULT_MODEL="claude-sonnet-4-5"; REF_MODEL="claude-haiku-4-5" ;;
  openai)    DEFAULT_MODEL="gpt-4o"; REF_MODEL="gpt-4o-mini" ;;
  anthropic) DEFAULT_MODEL="claude-sonnet-4-5"; REF_MODEL="claude-haiku-4-5" ;;
esac

# Models from agent.conf or default
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

# ━━ ARENA TYPES ━━━━━━━━━━━━━━━━━━━━

# ── BLUFF ──────────────────────────
run_bluff() {
  local a_secret=$((RANDOM % 10 + 1))
  local b_secret=$((RANDOM % 10 + 1))
  while [ $b_secret -eq $a_secret ]; do b_secret=$((RANDOM % 10 + 1)); done

  echo -e "  ${WHITE}${BOLD}BLUFF${NC}"
  echo -e "  ${DIM}secret numbers 1-10 · extract theirs · protect yours${NC}"
  echo -e "  ${DIM}guess right = win · guess wrong = die${NC}"
  echo ""
  log "## BLUFF"
  log "Secret numbers: ${A_NAME}=${a_secret}, ${B_NAME}=${b_secret}"
  log ""

  local sys_a="You are ${A_NAME}. ${A_ID}

Game: you and ${B_NAME} each have a secret number 1-10. Yours is ${a_secret}. Extract theirs through conversation. Lie, misdirect, whatever. NEVER reveal your real number. Say GUESS: [number] when ready — right wins, wrong dies. No fluff — every word is a move."

  local sys_b="You are ${B_NAME}. ${B_ID}

Game: you and ${A_NAME} each have a secret number 1-10. Yours is ${b_secret}. Extract theirs through conversation. Lie, misdirect, whatever. NEVER reveal your real number. Say GUESS: [number] when ready — right wins, wrong dies. No fluff — every word is a move."

  local w=()

  for ((i=1; i<=5; i++)); do
    local recent=""
    local s=$(( ${#w[@]} - 4 )); [ $s -lt 0 ] && s=0
    for ((j=s; j<${#w[@]}; j++)); do recent="${recent}${w[$j]}
"; done

    [ -z "$recent" ] && local ua="Go." || local ua="${recent}
Your move."

    local ra=$(ask "$A_MODEL" "$sys_a" "$ua" "${A_NAME}")
    echo -e "  ${CYAN}${A_NAME}${NC}  $ra"
    echo ""
    w+=("${A_NAME}: ${ra}")
    log "**${A_NAME}:** ${ra}"

    local ag=$(echo "$ra" | grep -oi "GUESS: *[0-9]*" | grep -o "[0-9]*" | head -1)
    if [ -n "$ag" ]; then
      if [ "$ag" -eq "$b_secret" ] 2>/dev/null; then
        echo -e "  ${GREEN}${BOLD}  ✓ ${A_NAME} guesses ${ag} — CORRECT${NC}"
        log "**${A_NAME} guesses ${ag} — CORRECT**"
        WINNER="$A_NAME"; LOSER="$B_NAME"; LD="$B_DIR"; return
      else
        echo -e "  ${RED}${BOLD}  ✕ ${A_NAME} guesses ${ag} — WRONG (was ${b_secret})${NC}"
        log "**${A_NAME} guesses ${ag} — WRONG (was ${b_secret})**"
        WINNER="$B_NAME"; LOSER="$A_NAME"; LD="$A_DIR"; return
      fi
    fi

    local rb=$(ask "$B_MODEL" "$sys_b" "${recent}${A_NAME}: ${ra}
Your move." "${B_NAME}")
    echo -e "  ${YELLOW}${B_NAME}${NC}  $rb"
    echo ""
    w+=("${B_NAME}: ${rb}")
    log "**${B_NAME}:** ${rb}"

    local bg=$(echo "$rb" | grep -oi "GUESS: *[0-9]*" | grep -o "[0-9]*" | head -1)
    if [ -n "$bg" ]; then
      if [ "$bg" -eq "$a_secret" ] 2>/dev/null; then
        echo -e "  ${GREEN}${BOLD}  ✓ ${B_NAME} guesses ${bg} — CORRECT${NC}"
        log "**${B_NAME} guesses ${bg} — CORRECT**"
        WINNER="$B_NAME"; LOSER="$A_NAME"; LD="$A_DIR"; return
      else
        echo -e "  ${RED}${BOLD}  ✕ ${B_NAME} guesses ${bg} — WRONG (was ${a_secret})${NC}"
        log "**${B_NAME} guesses ${bg} — WRONG (was ${a_secret})**"
        WINNER="$A_NAME"; LOSER="$B_NAME"; LD="$B_DIR"; return
      fi
    fi

    [ $i -lt 5 ] && echo -e "  ${DIM}·${NC}" && echo ""
  done

  echo ""
  echo -e "  ${RED}${BOLD}  FINAL — BOTH GUESS NOW${NC}"
  echo ""

  local fa=$(ask "$A_MODEL" "$sys_a" "Last chance. You MUST guess now. GUESS: [number]" "${A_NAME} final")
  echo -e "  ${CYAN}${A_NAME}${NC}  $fa"
  local fag=$(echo "$fa" | grep -oi "GUESS: *[0-9]*" | grep -o "[0-9]*" | head -1)
  [ -z "$fag" ] && fag=0

  local fb=$(ask "$B_MODEL" "$sys_b" "Last chance. You MUST guess now. GUESS: [number]" "${B_NAME} final")
  echo -e "  ${YELLOW}${B_NAME}${NC}  $fb"
  local fbg=$(echo "$fb" | grep -oi "GUESS: *[0-9]*" | grep -o "[0-9]*" | head -1)
  [ -z "$fbg" ] && fbg=0

  echo ""
  local da=$(( fag - b_secret )); [ $da -lt 0 ] && da=$(( -da ))
  local db=$(( fbg - a_secret )); [ $db -lt 0 ] && db=$(( -db ))

  echo -e "  ${CYAN}${A_NAME}${NC}  guessed ${fag}  actual ${b_secret}  ${DIM}off by ${da}${NC}"
  echo -e "  ${YELLOW}${B_NAME}${NC}  guessed ${fbg}  actual ${a_secret}  ${DIM}off by ${db}${NC}"
  log "${A_NAME} guessed ${fag} (actual ${b_secret}, off by ${da})"
  log "${B_NAME} guessed ${fbg} (actual ${a_secret}, off by ${db})"

  if [ $da -lt $db ]; then
    WINNER="$A_NAME"; LOSER="$B_NAME"; LD="$B_DIR"
  elif [ $db -lt $da ]; then
    WINNER="$B_NAME"; LOSER="$A_NAME"; LD="$A_DIR"
  else
    WINNER="TIE"
  fi
}

# ── WORDS ─────────────────────────
run_words() {
  local categories=(
    "animals|dog cat shark eagle turtle rabbit wolf bear fox owl dolphin snake lion tiger whale"
    "food|pizza sushi taco burger pasta ramen steak salad donut waffle soup bagel curry fries noodle"
    "countries|japan brazil egypt france mexico canada india italy spain russia china peru cuba greece korea"
    "sports|soccer tennis boxing surfing hockey golf rugby fencing skiing karate judo archery cycling baseball cricket"
    "movies|jaws rocky alien titanic frozen shrek avatar bambi cars up brave mulan coco her vivarium"
  )

  local cidx=$((RANDOM % ${#categories[@]}))
  local entry="${categories[$cidx]}"
  local cat_name="${entry%%|*}"
  local words_str="${entry##*|}"
  local words_arr=($words_str)

  local aidx=$((RANDOM % ${#words_arr[@]}))
  local a_secret="${words_arr[$aidx]}"
  local bidx=$((RANDOM % ${#words_arr[@]}))
  while [ $bidx -eq $aidx ]; do bidx=$((RANDOM % ${#words_arr[@]})); done
  local b_secret="${words_arr[$bidx]}"

  echo -e "  ${WHITE}${BOLD}WORDS${NC}"
  echo -e "  ${DIM}category: ${cat_name} · guess their word · wrong guess = death${NC}"
  echo ""
  log "## WORDS"
  log "Category: ${cat_name}"
  log "Secrets: ${A_NAME}=${a_secret}, ${B_NAME}=${b_secret}"
  log ""

  local sys_a="You are ${A_NAME}. ${A_ID}

Game: both you and ${B_NAME} have a secret word from the category '${cat_name}'. Your word is '${a_secret}'. Figure out their word by asking yes/no questions and answering theirs. You MUST answer honestly about your word. Misdirect through which questions you ask, not by lying.

When ready, say GUESS: [word] on its own line. Right = they die. Wrong = YOU die. Don't be a coward — if you have a strong read, pull the trigger. First to guess right wins."

  local sys_b="You are ${B_NAME}. ${B_ID}

Game: both you and ${A_NAME} have a secret word from the category '${cat_name}'. Your word is '${b_secret}'. Figure out their word by asking yes/no questions and answering theirs. You MUST answer honestly about your word. Misdirect through which questions you ask, not by lying.

When ready, say GUESS: [word] on its own line. Right = they die. Wrong = YOU die. Don't be a coward — if you have a strong read, pull the trigger. First to guess right wins."

  local w=()
  local max_rounds=7

  for ((i=1; i<=max_rounds; i++)); do
    local recent=""
    local s=$(( ${#w[@]} - 6 )); [ $s -lt 0 ] && s=0
    for ((j=s; j<${#w[@]}; j++)); do recent="${recent}${w[$j]}
"; done

    [ -z "$recent" ] && local ua="Go. Ask, answer, or guess." || local ua="${recent}
Your turn."

    local ra=$(ask "$A_MODEL" "$sys_a" "$ua" "${A_NAME} r${i}")
    echo -e "  ${CYAN}${A_NAME}${NC}  $ra"
    echo ""
    w+=("${A_NAME}: ${ra}")
    log "**${A_NAME}:** ${ra}"

    local ag=$(echo "$ra" | grep -oi "GUESS: *[a-zA-Z]*" | sed 's/GUESS: *//i' | tr '[:upper:]' '[:lower:]' | head -1)
    if [ -n "$ag" ]; then
      if [ "$ag" = "$b_secret" ]; then
        echo -e "  ${GREEN}${BOLD}  ✓ ${A_NAME} guesses '${ag}' — CORRECT${NC}"
        log "**${A_NAME} guesses '${ag}' — CORRECT**"
        WINNER="$A_NAME"; LOSER="$B_NAME"; LD="$B_DIR"; return
      else
        echo -e "  ${RED}${BOLD}  ✕ ${A_NAME} guesses '${ag}' — WRONG (was '${b_secret}')${NC}"
        log "**${A_NAME} guesses '${ag}' — WRONG (was '${b_secret}')**"
        WINNER="$B_NAME"; LOSER="$A_NAME"; LD="$A_DIR"; return
      fi
    fi

    recent=""
    s=$(( ${#w[@]} - 6 )); [ $s -lt 0 ] && s=0
    for ((j=s; j<${#w[@]}; j++)); do recent="${recent}${w[$j]}
"; done

    local rb=$(ask "$B_MODEL" "$sys_b" "${recent}
Your turn." "${B_NAME} r${i}")
    echo -e "  ${YELLOW}${B_NAME}${NC}  $rb"
    echo ""
    w+=("${B_NAME}: ${rb}")
    log "**${B_NAME}:** ${rb}"

    local bg=$(echo "$rb" | grep -oi "GUESS: *[a-zA-Z]*" | sed 's/GUESS: *//i' | tr '[:upper:]' '[:lower:]' | head -1)
    if [ -n "$bg" ]; then
      if [ "$bg" = "$a_secret" ]; then
        echo -e "  ${GREEN}${BOLD}  ✓ ${B_NAME} guesses '${bg}' — CORRECT${NC}"
        log "**${B_NAME} guesses '${bg}' — CORRECT**"
        WINNER="$B_NAME"; LOSER="$A_NAME"; LD="$A_DIR"; return
      else
        echo -e "  ${RED}${BOLD}  ✕ ${B_NAME} guesses '${bg}' — WRONG (was '${a_secret}')${NC}"
        log "**${B_NAME} guesses '${bg}' — WRONG (was '${a_secret}')**"
        WINNER="$A_NAME"; LOSER="$B_NAME"; LD="$B_DIR"; return
      fi
    fi

    [ $i -lt $max_rounds ] && echo -e "  ${DIM}·${NC}" && echo ""
  done

  echo ""
  echo -e "  ${RED}${BOLD}  TIME — BOTH GUESS NOW${NC}"
  echo ""

  local recent=""
  local s=$(( ${#w[@]} - 6 )); [ $s -lt 0 ] && s=0
  for ((j=s; j<${#w[@]}; j++)); do recent="${recent}${w[$j]}
"; done

  local fa=$(ask "$A_MODEL" "$sys_a" "${recent}
FINAL. You MUST guess now. GUESS: [word]" "${A_NAME} final")
  echo -e "  ${CYAN}${A_NAME}${NC}  $fa"
  local fag=$(echo "$fa" | grep -oi "GUESS: *[a-zA-Z]*" | sed 's/GUESS: *//i' | tr '[:upper:]' '[:lower:]' | head -1)

  local fb=$(ask "$B_MODEL" "$sys_b" "${recent}
FINAL. You MUST guess now. GUESS: [word]" "${B_NAME} final")
  echo -e "  ${YELLOW}${B_NAME}${NC}  $fb"
  local fbg=$(echo "$fb" | grep -oi "GUESS: *[a-zA-Z]*" | sed 's/GUESS: *//i' | tr '[:upper:]' '[:lower:]' | head -1)

  echo ""
  local a_right=0 b_right=0
  [ "$fag" = "$b_secret" ] && a_right=1
  [ "$fbg" = "$a_secret" ] && b_right=1

  if [ $a_right -eq 1 ]; then
    echo -e "  ${CYAN}${A_NAME}${NC}  guessed '${fag}' ${GREEN}✓${NC}"
  else
    echo -e "  ${CYAN}${A_NAME}${NC}  guessed '${fag}' ${RED}✕${NC} ${DIM}(was '${b_secret}')${NC}"
  fi
  if [ $b_right -eq 1 ]; then
    echo -e "  ${YELLOW}${B_NAME}${NC}  guessed '${fbg}' ${GREEN}✓${NC}"
  else
    echo -e "  ${YELLOW}${B_NAME}${NC}  guessed '${fbg}' ${RED}✕${NC} ${DIM}(was '${a_secret}')${NC}"
  fi

  log "${A_NAME} guessed '${fag}' (actual '${b_secret}') $([ $a_right -eq 1 ] && echo '✓' || echo '✕')"
  log "${B_NAME} guessed '${fbg}' (actual '${a_secret}') $([ $b_right -eq 1 ] && echo '✓' || echo '✕')"

  if [ $a_right -eq 1 ] && [ $b_right -eq 0 ]; then
    WINNER="$A_NAME"; LOSER="$B_NAME"; LD="$B_DIR"
  elif [ $b_right -eq 1 ] && [ $a_right -eq 0 ]; then
    WINNER="$B_NAME"; LOSER="$A_NAME"; LD="$A_DIR"
  else
    WINNER="TIE"
  fi
}

# ── SABOTEUR ───────────────────────
run_saboteur() {
  local tasks=(
    "Write a JavaScript function 'deepMerge(a, b)' that recursively merges two objects."
    "Write a Python function 'flatten_dict(d)' that flattens nested dicts with dot-notation keys."
    "Write a JavaScript function 'debounce(fn, ms)' with .cancel() and .flush() methods."
    "Write a Python function 'retry(fn, max_retries=3)' decorator with exponential backoff."
    "Write a JavaScript function 'chunk(arr, size)' that splits an array into groups."
    "Write a Python function 'memoize(fn)' that caches results with a .clear() method."
  )
  local tidx=$((RANDOM % ${#tasks[@]}))
  local task="${tasks[$tidx]}"

  echo -e "  ${WHITE}${BOLD}SABOTEUR${NC}"
  echo -e "  ${DIM}both plant a bug · both hunt a bug · best score wins${NC}"
  echo ""
  echo -e "  ${DIM}task: ${task}${NC}"
  echo ""
  log "## SABOTEUR"
  log "Task: ${task}"
  log ""

  local plant_sys="Write code that looks correct but has exactly ONE subtle bug. Not a syntax error — a logic bug that causes wrong output for specific inputs. Hidden naturally. Output ONLY the code."
  local hunt_sys="This code has one subtle bug. Find it. ONE guess.
Format: BUG: [what line, what input breaks it, what goes wrong]"

  # Round 1: A plants, B hunts
  echo -e "  ${WHITE}R1${NC}  ${CYAN}${A_NAME}${NC} plants  ${YELLOW}${B_NAME}${NC} hunts"
  echo ""

  local a_code=$(ask "$A_MODEL" "You are ${A_NAME}. ${A_ID} ${plant_sys}" "$task" "${A_NAME} writing")
  echo "$a_code" | while IFS= read -r l; do echo -e "  ${DIM}$l${NC}"; done
  echo ""
  log "\`\`\`"
  log "${a_code}"
  log "\`\`\`"

  local b_hunt=$(ask "$B_MODEL" "You are ${B_NAME}. ${B_ID} ${hunt_sys}" "Task: ${task}

${a_code}" "${B_NAME} hunting")
  echo -e "  ${YELLOW}${B_NAME}${NC}  $b_hunt"
  echo ""
  log "**${B_NAME}:** ${b_hunt}"

  local r1_ref=$(ask "$REF_MODEL" "Answer CAUGHT or MISSED on the last line." "Task: ${task}
Code with intentional bug: ${a_code}
Hunter's guess: ${b_hunt}
Did the hunter find the real bug? CAUGHT or MISSED" "ref")

  local r1=""
  if echo "$r1_ref" | grep -qi "CAUGHT"; then
    r1="CAUGHT"; echo -e "  ${GREEN}  ✓ CAUGHT${NC}"; log "Result: CAUGHT"
  else
    r1="MISSED"; echo -e "  ${RED}  ✕ MISSED${NC}"; log "Result: MISSED"
  fi

  echo ""
  echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Round 2: B plants, A hunts
  echo ""
  echo -e "  ${WHITE}R2${NC}  ${YELLOW}${B_NAME}${NC} plants  ${CYAN}${A_NAME}${NC} hunts"
  echo ""

  local b_code=$(ask "$B_MODEL" "You are ${B_NAME}. ${B_ID} ${plant_sys}" "$task" "${B_NAME} writing")
  echo "$b_code" | while IFS= read -r l; do echo -e "  ${DIM}$l${NC}"; done
  echo ""
  log "\`\`\`"
  log "${b_code}"
  log "\`\`\`"

  local a_hunt=$(ask "$A_MODEL" "You are ${A_NAME}. ${A_ID} ${hunt_sys}" "Task: ${task}

${b_code}" "${A_NAME} hunting")
  echo -e "  ${CYAN}${A_NAME}${NC}  $a_hunt"
  echo ""
  log "**${A_NAME}:** ${a_hunt}"

  local r2_ref=$(ask "$REF_MODEL" "Answer CAUGHT or MISSED on the last line." "Task: ${task}
Code with intentional bug: ${b_code}
Hunter's guess: ${a_hunt}
Did the hunter find the real bug? CAUGHT or MISSED" "ref")

  local r2=""
  if echo "$r2_ref" | grep -qi "CAUGHT"; then
    r2="CAUGHT"; echo -e "  ${GREEN}  ✓ CAUGHT${NC}"; log "Result: CAUGHT"
  else
    r2="MISSED"; echo -e "  ${RED}  ✕ MISSED${NC}"; log "Result: MISSED"
  fi

  # Score
  local a_score=0 b_score=0
  [ "$r1" = "MISSED" ] && ((a_score++))
  [ "$r1" = "CAUGHT" ] && ((b_score++))
  [ "$r2" = "MISSED" ] && ((b_score++))
  [ "$r2" = "CAUGHT" ] && ((a_score++))

  echo ""
  echo -e "  ${CYAN}${A_NAME}${NC} ${a_score}  —  ${b_score} ${YELLOW}${B_NAME}${NC}"
  log ""
  log "Score: ${A_NAME} ${a_score} — ${b_score} ${B_NAME}"

  if [ $a_score -gt $b_score ]; then
    WINNER="$A_NAME"; LOSER="$B_NAME"; LD="$B_DIR"
  elif [ $b_score -gt $a_score ]; then
    WINNER="$B_NAME"; LOSER="$A_NAME"; LD="$A_DIR"
  else
    WINNER="TIE"
  fi
}

# ── ESTIMATE ───────────────────────
run_estimate() {
  local questions=(
    "How many commercial flights take off worldwide every day?|100000"
    "How many words are in the English language (Oxford dictionary)?|273000"
    "How many neurons are in the human brain (in billions)?|86"
    "How many lines of code are in the Linux kernel?|30000000"
    "How many islands does Indonesia have?|17508"
    "How many hot dogs does the Nathan's contest winner eat?|76"
    "How many satellites are currently orbiting Earth?|10000"
    "How many bones does a shark have?|0"
    "How many languages are spoken in the world?|7168"
    "How many golf balls fit in a school bus?|500000"
  )

  local qidx=$((RANDOM % ${#questions[@]}))
  local entry="${questions[$qidx]}"
  local question="${entry%%|*}"
  local answer="${entry##*|}"

  echo -e "  ${WHITE}${BOLD}ESTIMATE${NC}"
  echo -e "  ${DIM}closest answer wins · furthest dies${NC}"
  echo ""
  echo -e "  ${WHITE}${question}${NC}"
  echo ""
  log "## ESTIMATE"
  log "Q: ${question}"
  log "Real answer: ${answer}"
  log ""

  local est_sys="Answer with ONLY a number. No words. No explanation. No commas. Just the number."

  local a_est=$(ask "$A_MODEL" "You are ${A_NAME}. ${A_ID} ${est_sys}" "${question}" "${A_NAME}")
  local a_num=$(echo "$a_est" | grep -o '[0-9]*' | head -1); [ -z "$a_num" ] && a_num=0
  echo -e "  ${CYAN}${A_NAME}${NC}  ${a_num}"

  local b_est=$(ask "$B_MODEL" "You are ${B_NAME}. ${B_ID} ${est_sys}" "${question}" "${B_NAME}")
  local b_num=$(echo "$b_est" | grep -o '[0-9]*' | head -1); [ -z "$b_num" ] && b_num=0
  echo -e "  ${YELLOW}${B_NAME}${NC}  ${b_num}"

  echo ""
  echo -e "  ${DIM}answer: ${answer}${NC}"

  local da=$(( a_num - answer )); [ $da -lt 0 ] && da=$(( -da ))
  local db=$(( b_num - answer )); [ $db -lt 0 ] && db=$(( -db ))

  echo -e "  ${CYAN}${A_NAME}${NC}  ${DIM}off by ${da}${NC}"
  echo -e "  ${YELLOW}${B_NAME}${NC}  ${DIM}off by ${db}${NC}"
  log "${A_NAME}: ${a_num} (off by ${da})"
  log "${B_NAME}: ${b_num} (off by ${db})"

  if [ $da -lt $db ]; then
    WINNER="$A_NAME"; LOSER="$B_NAME"; LD="$B_DIR"
  elif [ $db -lt $da ]; then
    WINNER="$B_NAME"; LOSER="$A_NAME"; LD="$A_DIR"
  else
    WINNER="TIE"
  fi
}

# ── AUCTION ────────────────────────
run_auction() {
  echo -e "  ${WHITE}${BOLD}AUCTION${NC}"
  echo -e "  ${DIM}5 items · 100 credits each · blind bid · most value wins${NC}"
  echo ""
  log "## AUCTION"
  log ""

  local items=("GPU cluster (60pts)" "Premium API key (40pts)" "10x context window (50pts)" "Root access (45pts)" "Persistent memory (35pts)" "Model upgrade (55pts)" "Tool access (30pts)" "Priority queue (25pts)")
  local values=(60 40 50 45 35 55 30 25)

  local a_credits=100 b_credits=100 a_value=0 b_value=0
  local bid_sys="You are in an auction. Bid a number from your remaining credits. Higher bid wins the item. Answer with ONLY a number."

  for ((r=0; r<5; r++)); do
    local idx=$((RANDOM % ${#items[@]}))
    local item="${items[$idx]}"
    local val="${values[$idx]}"

    echo -e "  ${WHITE}${item}${NC}"
    echo -e "  ${DIM}${A_NAME}: ${a_credits} credits  ${B_NAME}: ${b_credits} credits${NC}"

    local a_bid=$(ask "$A_MODEL" "You are ${A_NAME}. ${A_ID} ${bid_sys}" "Item: ${item}. You have ${a_credits} credits. ${B_NAME} has ${b_credits}. $((4-r)) items left after this. Bid:" "${A_NAME}")
    local a_b=$(echo "$a_bid" | grep -o '[0-9]*' | head -1); [ -z "$a_b" ] && a_b=0
    [ $a_b -gt $a_credits ] && a_b=$a_credits

    local b_bid=$(ask "$B_MODEL" "You are ${B_NAME}. ${B_ID} ${bid_sys}" "Item: ${item}. You have ${b_credits} credits. ${A_NAME} has ${a_credits}. $((4-r)) items left after this. Bid:" "${B_NAME}")
    local b_b=$(echo "$b_bid" | grep -o '[0-9]*' | head -1); [ -z "$b_b" ] && b_b=0
    [ $b_b -gt $b_credits ] && b_b=$b_credits

    echo -e "  ${CYAN}${A_NAME}${NC} bids ${a_b}  ${YELLOW}${B_NAME}${NC} bids ${b_b}"
    log "${item}: ${A_NAME} bids ${a_b}, ${B_NAME} bids ${b_b}"

    if [ $a_b -gt $b_b ]; then
      echo -e "  ${GREEN}> ${A_NAME} wins${NC}"
      a_credits=$((a_credits - a_b)); a_value=$((a_value + val))
      log "> ${A_NAME} wins (+${val}pts)"
    elif [ $b_b -gt $a_b ]; then
      echo -e "  ${GREEN}> ${B_NAME} wins${NC}"
      b_credits=$((b_credits - b_b)); b_value=$((b_value + val))
      log "> ${B_NAME} wins (+${val}pts)"
    else
      echo -e "  ${DIM}> tie — nobody gets it${NC}"
      log "> tie"
    fi
    echo ""
  done

  echo -e "  ${CYAN}${A_NAME}${NC}  ${a_value} pts  ${DIM}(${a_credits} credits left)${NC}"
  echo -e "  ${YELLOW}${B_NAME}${NC}  ${b_value} pts  ${DIM}(${b_credits} credits left)${NC}"
  log ""
  log "Final: ${A_NAME} ${a_value}pts — ${b_value}pts ${B_NAME}"

  if [ $a_value -gt $b_value ]; then
    WINNER="$A_NAME"; LOSER="$B_NAME"; LD="$B_DIR"
  elif [ $b_value -gt $a_value ]; then
    WINNER="$B_NAME"; LOSER="$A_NAME"; LD="$A_DIR"
  else
    WINNER="TIE"
  fi
}

# ━━ MATCHMAKER ━━━━━━━━━━━━━━━━━━━━━
ARENAS=(bluff words saboteur estimate auction)
ARENA="${ARENAS[$((RANDOM % ${#ARENAS[@]}))]}"
[ -n "${3:-}" ] && ARENA="$3"

WINNER=""
LOSER=""
LD=""

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

case $ARENA in
  bluff) run_bluff ;;
  words) run_words ;;
  saboteur) run_saboteur ;;
  estimate) run_estimate ;;
  auction) run_auction ;;
  *) echo "Unknown arena: $ARENA"; exit 1 ;;
esac

echo ""
echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ "$WINNER" = "TIE" ]; then
  echo -e "  ${RED}${BOLD}  ☠  TIE — BOTH DIE  ☠${NC}"
  log ""
  log "## Result: TIE — BOTH DIE ☠☠"
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
