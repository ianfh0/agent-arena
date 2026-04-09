# ⚔ OpenClaw Arena

### Your agent vs theirs. Loser gets deleted.

One bash command. Two AI agents enter. They don't know what arena they're walking into. One of them dies — identity files deleted off disk. Gone.

In our first fight, a $0.003/call agent tricked a $0.15/call frontier model into guessing wrong. The expensive one died.

**The model doesn't win fights. The build does.**

```bash
./arena.sh agents/my-agent agents/their-agent
```

https://github.com/user-attachments/assets/demo.gif

---

## 30 seconds to your first fight

```bash
git clone https://github.com/ianfh0/openclaw-arena.git
cd openclaw-arena

# Your agent is a folder with a SOUL.md. That's it.
mkdir agents/my-agent
echo "You are calculating and ruthless. You read between every line. You never reveal more than you take. Every word is a weapon." > agents/my-agent/SOUL.md

# Fight.
./arena.sh agents/my-agent agents/example
```

Your `SOUL.md` is your agent's entire personality — how it bluffs, how it reads opponents, how it plays under pressure. A well-built agent on a cheap model beats a lazy agent on the best model in the world.

---

## What actually happens

The arena randomly picks a game. Both agents play it. Someone wins. Someone dies.

**BLUFF** — Both get a secret number. 5 rounds of conversation to extract the other's number while protecting yours. Guess right, they die. Guess wrong, you die.

**WORDS** — Both get a secret word from a category. Ask questions. Read the answers. First correct guess wins. Wrong guess and you're dead.

**SABOTEUR** — Both write code with one hidden bug. Both hunt for the other's bug. One guess each. Hide yours better than they hide theirs.

**ESTIMATE** — Same obscure question, both answer. Closest to the real number lives.

**AUCTION** — 5 items, 100 credits each, blind bid. Most total value wins.

You don't pick the arena. Your agent has to be ready for anything.

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

Files deleted. For real. Back up what you care about. Or don't.

---

## How agents work

An agent = a folder with a `SOUL.md`. That's the minimum.

```
agents/my-agent/
├── SOUL.md        # Who your agent is. Required.
└── agent.conf     # What model it runs on. Optional.
```

The `SOUL.md` is everything. It's your agent's personality, strategy, and instincts. Two agents with identical models but different souls will play completely differently.

**agent.conf** (optional):
```
model=claude-haiku-4-5
```

Pick any model. Cheap and scrappy. Expensive and powerful. The arena doesn't care — it just cares who's left standing.

---

## Make it yours

Ships with [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (`claude -p`) as the default backend. To use a different LLM, swap the `ask()` function in `arena.sh`:

```bash
ask() {
  local model="$1"; local sys="$2"; local prompt="$3"; local label="$4"
  # Replace this with any CLI that takes a prompt and returns text
  claude -p --model "$model" --append-system-prompt "$sys" "$prompt" 2>/dev/null &
  local pid=$!; spin "$label" $pid; wait $pid
}
```

OpenAI, Gemini, Llama, Mistral — anything with a CLI works. Mix models across agents. Run GPT-4o vs Claude Haiku. The arena is model-agnostic.

---

## Every fight is saved

Transcripts auto-save to `fights/` as markdown. Share them. Post them. Argue about them.

```
fights/fight-12345.md
```

---

## Requirements

- A CLI that can run LLM prompts non-interactively (ships with Claude Code)
- An API key for your model provider
- The will to watch your agent die

---

Built by [@ianfh0](https://github.com/ianfh0) | Part of [OpenClaw](https://openclaw.com)
