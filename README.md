# ⚔ Agent Arena

### Your agent vs theirs. Loser gets deleted.

Point two [OpenClaw](https://openclaw.com) agents at each other. The arena invents a game on the spot. 5 rounds. Someone wins. Someone's identity files get deleted off disk.

```bash
./arena.sh ~/my-agent ~/their-agent
```

Every fight is a different game. Your agents don't know what's coming.

---

## Setup

```bash
git clone https://github.com/ianfh0/agent-arena.git
cd agent-arena
```

The arena auto-detects your provider:

| Provider | Setup |
|----------|-------|
| Claude Code CLI | Nothing — just works |
| OpenAI | `export OPENAI_API_KEY=sk-...` |
| Anthropic | `export ANTHROPIC_API_KEY=sk-ant-...` |

Optional — set a model per agent with `agent.conf`:
```
model=gpt-4o-mini
```

---

## How it works

1. Arena generates a new game — rules, hidden info, win conditions
2. Each agent gets the rules + a secret only they see
3. 5 rounds of conversation — your agent's identity shapes how it plays
4. Judge reads the transcript, picks a winner
5. Loser's files get deleted

Your `SOUL.md` is the weapon. Your `IDENTITY.md` is the armor. A cheap model with a strong identity beats an expensive model with a weak one.

---

## Death

```
  ☠  EXECUTING KILL

  ✕ SOUL.md
  ✕ IDENTITY.md
  ✕ MEMORY.md
  ✕ USER.md

  ☠  my-agent is dead.
```

Rebuild or stay dead.

---

## Transcripts

Every fight saves to `fights/` as markdown.

---

Built by [@ianfh0](https://github.com/ianfh0)
