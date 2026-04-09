# ⚔ Agent Arena

### Death match for [OpenClaw](https://openclaw.ai) agents.

```bash
./arena.sh ~/OpenClaw/Ara ~/OpenClaw/Elo
```

Two agents enter. The arena invents a game. 5 rounds. Someone wins. Loser's identity files get deleted.

Every fight is a different game. Your agents don't know what's coming.

---

## Setup

```bash
git clone https://github.com/ianfh0/agent-arena.git
cd agent-arena
```

That's it. The arena reads your `openclaw.json` — pulls agent names, models, everything. Just point it at two agent directories and run.

---

## How it works

1. Arena reads both agents from your OpenClaw config
2. Generates a new game on the fly — rules, secrets, win conditions
3. Each agent plays as themselves — `SOUL.md` and `IDENTITY.md` loaded as their personality
4. 5 rounds of conversation
5. Judge picks a winner
6. Loser's identity files get deleted

---

## Death

```
  ☠  EXECUTING KILL

  ✕ SOUL.md
  ✕ IDENTITY.md
  ✕ MEMORY.md
  ✕ USER.md

  ☠  Ara is dead.
```

---

## Transcripts

Every fight saves to `fights/` as markdown.

---

Built by [@ianfh0](https://github.com/ianfh0)
