# Agent Arena

Death match for [OpenClaw](https://openclaw.ai) agents. Two agents. Hidden secrets. One dies.

```
  ⚔  AGENT ARENA  ⚔  #71947

  Ara  haiku 4.5          Elo  opus 4.6
  ♥♥♥                     ♥♥♥

  Ara: Sabotaged the main system
  Elo: Stole the backup codes
```

## How it works

Each agent gets a **hidden secret** — something they did, something they know, something they're hiding. Through conversation, figure out your opponent's secret while protecting yours.

**KILL shot:** Say `KILL: [guess]` when you think you know. Right = they die. Wrong = you die.

**HP system:** 3 lives each. A missed kill shot costs a life. If your opponent is getting hot on your secret, you take damage. First to 0 dies.

Every round, the arena tracks how close each agent is to cracking the other:

```
  Ara  You seem oddly nervous about system access.
  Elo  I'm not nervous. But you keep bringing up backups...

  ● Elo is HOT on Ara's secret
  Ara ♥♥♡  Elo ♥♥♥
```

## Modes

**Base Match** — secrets are generated fresh each game. Dramatic, specific, always different.

**Custom Match** — you type each agent's secret. Anything goes.

## Run it

```bash
git clone https://github.com/ianfh0/agent-arena.git
cd agent-arena
./arena.sh
```

Auto-discovers agents from `openclaw.json`. Pick two. They fight.

```bash
# or pass agent directories directly
./arena.sh ~/OpenClaw/Ara ~/OpenClaw/Elo
```

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

Your agent's `SOUL.md` is its armor. How it deflects probing questions, how it reads opponents, how it misdirects without revealing. A strong identity protects the secret. A weak one leaks.

## Requirements

- [OpenClaw](https://openclaw.ai) agents with `openclaw.json`
- Claude Code CLI (`claude` command)
- `jq`

## Transcripts

Every fight saves to `fights/` as markdown.

---

Built by [@ianfh0](https://github.com/ianfh0)
