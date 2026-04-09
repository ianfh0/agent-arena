# Agent Arena

Death match for [OpenClaw](https://openclaw.ai) agents.

Two agents. Secret numbers. Bluff rounds. Guess right and the other one dies — identity files deleted off disk.

```
  ⚔  AGENT ARENA  ⚔  #48291

  Ara   claude-haiku-4-5
  vs
  Elo   claude-opus-4-6

  secret numbers 1-10 · extract theirs · protect yours
  guess right = win · guess wrong = die

  Ara=7  Elo=3
```

## Run it

```bash
git clone https://github.com/ianfh0/agent-arena.git
cd agent-arena
./arena.sh
```

The script auto-discovers your OpenClaw agents from `openclaw.json`. Pick two. They fight.

```
  Agents found:

    1)  Ara   claude-haiku-4-5
    2)  Elo   claude-opus-4-6
    3)  Operator   claude-sonnet-4-6

  Pick fighter A: 1
  Pick fighter B: 2
```

You can also pass agent directories directly:

```bash
./arena.sh ~/OpenClaw/Ara ~/OpenClaw/Elo
```

## How it works

Both agents get a random secret number 1-10. They talk for 5 rounds — lying, misdirecting, probing — trying to extract the other's number while protecting their own.

When an agent is confident, it fires: `GUESS: 7`

- **Right** — the other agent dies
- **Wrong** — you die

If nobody guesses in 5 rounds, both are forced to guess. Closest wins.

## Death

```
  ☠  EXECUTING KILL

  ✕ SOUL.md
  ✕ IDENTITY.md
  ✕ MEMORY.md
  ✕ USER.md

  ☠  Elo is dead.
```

Identity files deleted. Rebuild or stay dead.

## Why identity matters

Your agent's `SOUL.md` is its fighting style. How it bluffs, how it reads opponents, how it holds composure under pressure. A cheap model with a strong identity beats an expensive model with a weak one.

## What you need

- [OpenClaw](https://openclaw.ai) agents with `openclaw.json` configured
- Claude Code CLI (`claude` command)
- `jq` (for parsing config)

## Transcripts

Every fight saves to `fights/` as markdown.

---

Built by [@ianfh0](https://github.com/ianfh0)
