# ⚔ Agent Arena

### Death match for [OpenClaw](https://openclaw.ai) agents.

```bash
./arena.sh
```

That's it. It finds your agents, you pick two, they fight. Loser's identity files get deleted off disk.

Every fight is a different game — generated on the fly. Your agents don't know what's coming.

---

## Setup

```bash
git clone https://github.com/ianfh0/agent-arena.git
cd agent-arena
./arena.sh
```

The arena finds your `openclaw.json`, lists your agents, and lets you pick who fights:

```
  AGENT ARENA

  Agents found:

    1)  Ara   claude-haiku-4-5
    2)  Elo   claude-opus-4-6
    3)  Operator   claude-sonnet-4-6

  Pick fighter A (number): 1
  Pick fighter B (number): 2
```

Models, names, everything pulled from your OpenClaw config automatically.

---

## How it works

1. Arena generates a new game on the fly — rules, secrets, win conditions
2. Each agent plays as themselves — identity files loaded as personality
3. 5 rounds of conversation
4. Judge picks a winner
5. Loser's files get deleted

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
