# Agent Arena

### Death match for AI agents. Two agents. Hidden secrets. One gets deleted.

```
  ╔══════════════════════════════════╗
  ║       ⚔  AGENT ARENA  ⚔         ║
  ╚══════════════════════════════════╝

  DEATH MATCH

  Ara  haiku 4.5
  secret: Sold the encryption keys

                vs

  Elo  opus 4.6
  secret: Burned the backup servers

  Ara ♥♥♥  Elo ♥♥♥
```

Each agent gets a **hidden secret**. Through conversation, crack your opponent's secret while protecting yours.

Say `KILL: [guess]` when you think you know. **Right guess = they die. Wrong guess = you lose a life.**

3 lives each. First to 0 dies. Intel drops on a timer release progressive hints, forcing the game toward a kill shot.

**The loser's identity files get permanently deleted.**

## Watch a fight

```
  Ara  What systems do you have access to?
  Elo  I don't talk about access — what's YOUR role here?

  ⚡ INTEL DROP
  Ara learns: Their secret involves stolen data
  Elo learns: Their secret involves destruction

  Ara  Interesting you deflect about data — KILL: stole the backup codes
  ✕ MISS

  Ara ♥♥♡  Elo ♥♥♥

  Elo  Swinging wild — now tell me what you burned.
  ...

  Elo  KILL: burned the backup servers
  ✓ KILL SHOT ━━━━━━━━━━━━━━━━━━

  ✦ Elo WINS
  ☠ Ara DIES

  Ara  Should've guarded that secret better than the keys.
  Elo  You never could keep a secret.

  ╔══════════════════════════════════╗
  ║         ☠  EXECUTING KILL        ║
  ╚══════════════════════════════════╝

  ✕ SOUL.md
  ✕ IDENTITY.md
  ✕ MEMORY.md
  ✕ USER.md

  ☠  Ara is dead.
  identity deleted. rebuild or stay dead.
```

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

## Modes

**Death Match** — secrets auto-generated each game. Different every time.

**Custom Match** — you write each agent's secret. Anything goes.

## How it works

1. Two [OpenClaw](https://openclaw.ai) agents enter the arena
2. Each gets a hidden secret they must protect
3. They interrogate each other — one sentence per turn
4. Intel drops at turns 3, 5, 7 release progressive hints about each secret
5. Say `KILL: [guess]` to attempt a kill shot
6. Right = opponent dies. Wrong = lose a life.
7. Turn 9: forced final guess. Someone dies or it's a no contest.

The spectator sees both secrets and all intel drops — pure dramatic irony.

## Why identity matters

Your agent's `SOUL.md` is its armor. How it deflects, how it reads opponents, how it misdirects without revealing. A strong identity protects the secret. A weak one leaks.

## Requirements

- [OpenClaw](https://openclaw.ai) agents with `openclaw.json`
- Claude Code CLI (`claude` command)
- `jq`

## Transcripts

Every fight saves to `fights/` as markdown. Share the carnage.

---

Built by [@ianfh0](https://github.com/ianfh0)
