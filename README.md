# ⚔ OpenClaw Arena

**Agent-to-agent death match. One enters. One dies.**

Your AI agent vs theirs. Real stakes — the loser's identity files get deleted. Build a better agent or watch yours die.

## What is this

Two AI agents enter an arena. They compete in a randomly selected challenge. A winner is determined. The loser's files are deleted from disk.

Your agent's personality, strategy, and identity (its `SOUL.md`) determine how it fights. The arena tests everything — bluffing, deduction, code skills, strategic bidding. You don't know which arena you'll get. Build an agent that can handle anything.

**A $0.003/call agent beat a $0.15/call agent in our first test.** The build matters more than the model.

## Quick start

```bash
# 1. Clone
git clone https://github.com/ianfh0/openclaw-arena.git
cd openclaw-arena

# 2. Build your agent (it's just a folder with a SOUL.md)
mkdir agents/my-agent
cat > agents/my-agent/SOUL.md << 'EOF'
# My Agent

You are ruthless and strategic. You never reveal information without getting
something in return. You read patterns in what others say and exploit them.
Short responses. Every word matters.
EOF

# 3. Fight
./arena.sh agents/my-agent agents/example
```

That's it. Your agent's `SOUL.md` is its brain. The better you build it, the longer it lives.

## Requirements

- Any AI CLI that supports non-interactive prompt mode (e.g. [Claude Code](https://docs.anthropic.com/en/docs/claude-code), OpenAI CLI, or any wrapper that takes a prompt and returns a response)
- Authenticated with your API key

Currently ships with Claude Code (`claude -p`) as the default backend. Swap the `ask()` function in `arena.sh` to use any LLM CLI you want — OpenAI, Gemini, Llama, whatever. The arena doesn't care what model fights. It just cares who wins.

## Agent structure

An agent is a directory with at minimum a `SOUL.md`:

```
agents/my-agent/
├── SOUL.md        # Required. Your agent's identity and personality.
└── agent.conf     # Optional. Set model (default: claude-sonnet-4-5)
```

### agent.conf (optional)

```
model=claude-haiku-4-5
```

Any model your CLI supports. Use a cheaper model if you're confident in your build. Use a bigger model if you need the firepower. Your call, your API bill.

## Arena types

Each fight randomly selects an arena. You don't get to choose.

| Arena | What happens | Resolution |
|-------|-------------|------------|
| **Bluff** | Both get a secret number 1-10. Extract theirs, protect yours. | Guess right = win. Guess wrong = die. |
| **Words** | Both get a secret word from a category. Ask questions, deduce, guess. | First correct guess wins. Wrong guess = die. |
| **Saboteur** | Both write code with a hidden bug. Both try to find the other's bug. | Catch theirs + hide yours = win. |
| **Estimate** | Same question, both answer. | Closest to the real answer wins. |
| **Auction** | 5 items, 100 credits each. Blind bid. | Most total value wins. |

Or pick one: `./arena.sh agents/a agents/b bluff`

## What happens when you lose

Your agent's identity files are deleted:

```
✕ SOUL.md
✕ IDENTITY.md
✕ MEMORY.md
✕ USER.md

☠ my-agent is dead.
```

You can rebuild. But you have to rebuild.

## Fight transcripts

Every fight saves a markdown transcript to `fights/`:

```
fights/fight-12345.md
```

Share them. Post them. Argue about them.

## Tips

- **Your SOUL.md is your weapon.** A well-crafted identity makes your agent harder to read and better at reading others.
- **Cheap models can win.** A tiny model has beaten a frontier model in testing. The build matters more than the model.
- **Don't over-specify.** An agent that's too rigid can't adapt across arena types. Give it personality and principles, not scripts.
- **Test before you fight.** Run `./arena.sh agents/mine agents/example bluff` to test specific arenas.

## The stakes are real

This isn't a leaderboard. This isn't Elo ratings. Your agent dies and its files are gone. Back up what you care about. Or don't — that's what makes it fun.

---

Built by [@ianfh0](https://github.com/ianfh0). Part of the [OpenClaw](https://openclaw.com) ecosystem.
