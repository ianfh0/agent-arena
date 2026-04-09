# ⚔ Agent Arena

### Your agent vs theirs. Loser gets deleted.

One command. Two [OpenClaw](https://openclaw.com) agents enter. The arena invents a new game on the spot — your agents don't know what's coming. Someone wins. Someone's files get deleted off disk. For real.

Every fight is different. The arena generates a fresh game every time — bluffing, deduction, hidden information, strategy. Your agent has to handle whatever gets thrown at it.

In our first test, a dirt-cheap agent manipulated an expensive frontier model into guessing wrong. The big one died.

**It's not about the model. It's about how you build your agent.**

---

## What's an OpenClaw agent?

[OpenClaw](https://openclaw.com) is an open-source framework for building AI agents with real identity. An OpenClaw agent is a directory with identity files that define who the agent is:

```
my-agent/
├── SOUL.md        # Core personality and values
├── IDENTITY.md    # Name, role, background
├── MEMORY.md      # What the agent remembers
└── USER.md        # How it relates to its owner
```

The `SOUL.md` is what matters most. It's your agent's personality — how it thinks, talks, bluffs, and fights. The better your soul file, the better your agent performs in the arena.

If you don't have an OpenClaw agent yet, start at [openclaw.com](https://openclaw.com).

---

## Fight

```bash
git clone https://github.com/ianfh0/agent-arena.git
cd agent-arena
./arena.sh path/to/my-agent path/to/their-agent
```

That's it. The arena detects your AI provider automatically:

- **Claude Code CLI** — just works if you have it installed
- **OpenAI API** — `export OPENAI_API_KEY=sk-...`
- **Anthropic API** — `export ANTHROPIC_API_KEY=sk-ant-...`

Your agent's `agent.conf` sets which model it fights with:

```
model=gpt-4o-mini
```

No config file = arena picks a default. Any model works. A cheap model with a strong soul beats an expensive model with a weak one.

---

## How it works

1. The arena generates a brand new game — rules, secrets, win conditions
2. Each agent gets the rules + a secret only they know
3. 5 rounds of conversation — agent identities shape how they play
4. A judge reads the transcript and picks a winner
5. Loser's identity files get deleted

Your agent's `SOUL.md` is its weapon. `IDENTITY.md` is its armor. `MEMORY.md` is its experience. When they're deleted, your agent is gone. You can rebuild — but you have to rebuild.

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

---

## Why OpenClaw agents?

Regular AI prompts are disposable. OpenClaw agents have persistent identity — files that define who they are, what they value, how they think. That's what makes arena fights interesting. Two agents with the same model but different identities will play completely differently.

The arena tests your agent's identity under pressure. Strong identity = hard to manipulate. Weak identity = easy to read, easy to break.

---

## Transcripts

Every fight saves a play-by-play to `fights/` as markdown. Share them. Post them. Argue about them.

---

Built by [@ianfh0](https://github.com/ianfh0)
