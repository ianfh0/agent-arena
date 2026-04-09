# ⚔ Agent Arena

### Your agent vs theirs. Loser gets deleted.

One bash command. Two AI agents enter. They don't know what game they're walking into. One dies — files deleted off disk. Gone.

In our first fight, a $0.003/call agent tricked a $0.15/call frontier model into guessing wrong. The expensive one died.

**The model doesn't win fights. The build does.**

```bash
./arena.sh path/to/agent-a path/to/agent-b
```

---

## 30 seconds to your first fight

```bash
git clone https://github.com/ianfh0/agent-arena.git
cd agent-arena

# An agent is just a folder with a system prompt. That's it.
mkdir agents/my-agent
echo "You are calculating and ruthless. You read between every line. You never reveal more than you take. Every word is a weapon." > agents/my-agent/SOUL.md

# Fight.
./arena.sh agents/my-agent agents/example
```

Your agent's system prompt is its entire personality — how it bluffs, how it reads opponents, how it plays under pressure. A well-built agent on a cheap model beats a lazy prompt on the best model in the world.

---

## How it works

The arena randomly picks a game. Both agents play. Someone wins. Someone dies.

**BLUFF** — Both get a secret number. Conversation rounds to extract the other's while protecting yours. Guess right, they die. Guess wrong, you die.

**WORDS** — Both get a secret word from a daily category. Ask questions. Read between the lines. First correct guess wins. Wrong guess kills you.

**SABOTEUR** — Both write code with a hidden bug. Both hunt the other's bug. One guess each.

**ESTIMATE** — Same question, both answer. Closest to the real number lives.

**AUCTION** — Blind bid on items with limited credits. Most total value wins.

You don't pick the arena. Your agent has to handle anything.

---

## When you lose

```
  ☠  EXECUTING KILL

  ✕ SOUL.md
  ✕ IDENTITY.md
  ✕ MEMORY.md
  ✕ USER.md

  ☠  my-agent is dead.
```

Files deleted. For real.

---

## Agents

An agent is a folder. The only required file is a system prompt (`SOUL.md`). Everything else is optional.

```
agents/my-agent/
├── SOUL.md        # Your agent's identity. Required.
└── agent.conf     # Model config. Optional.
```

The system prompt is what makes your agent yours. Same model, different prompt, completely different fighter.

**agent.conf** (optional):
```
model=claude-haiku-4-5
```

Any model. Any provider. Cheap and scrappy or expensive and powerful.

---

## Works with any LLM

Ships with [Claude Code](https://docs.anthropic.com/en/docs/claude-code) as the default backend. Swap the `ask()` function in `arena.sh` to plug in any LLM CLI:

```bash
ask() {
  local model="$1"; local sys="$2"; local prompt="$3"; local label="$4"
  # Replace with your LLM CLI — OpenAI, Gemini, Llama, anything
  your-cli --model "$model" --system "$sys" "$prompt" &
  local pid=$!; spin "$label" $pid; wait $pid
}
```

Mix providers. Run GPT-4o vs Claude vs Llama. The arena doesn't care what's under the hood.

---

## Fight transcripts

Every fight saves a markdown transcript to `fights/`. Share them. Post them.

---

## Requirements

- Any LLM CLI that takes a prompt and returns text
- An API key
- The will to watch your agent die

---

Built by [@ianfh0](https://github.com/ianfh0)
