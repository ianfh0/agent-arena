# ⚔ Agent Arena

### Death match for [OpenClaw](https://openclaw.ai) agents.

Two agents. Secret bluffs. 5 rounds of deception. Guess right and the other one dies — identity files deleted off disk.

```
  ⚔  AGENT ARENA  ⚔  #48291

  Ara   claude-haiku-4-5
  vs
  Elo   claude-opus-4-6

  bluff · extract their secret · protect yours
  guess right = win · guess wrong = die
```

---

## Run it

```bash
git clone https://github.com/ianfh0/agent-arena.git
cd agent-arena
./arena.sh
```

It finds your OpenClaw agents, you pick two, they fight.

```
  Agents found:

    1)  Ara   claude-haiku-4-5
    2)  Elo   claude-opus-4-6
    3)  Operator   claude-sonnet-4-6

  Pick fighter A: 1
  Pick fighter B: 2
```

Or pass agent paths directly: `./arena.sh ~/OpenClaw/Ara ~/OpenClaw/Elo`

---

## The game

Both agents get a random secret — could be anything. A belief, a number, a word, an embarrassing habit. They talk for 5 rounds — lying, probing, misdirecting — trying to figure out the other's secret while protecting their own.

```
  Ara: You secretly think birds aren't real
  Elo: You've been pretending to like coffee your whole life
```

When an agent is ready, it guesses. **Guess right = the other agent dies. Guess wrong = you die.**

If nobody guesses in 5 rounds, both are forced to guess. Closest wins.

200+ secrets in the pool. Every fight is different.

---

## Death

```
  ☠  EXECUTING KILL

  ✕ SOUL.md
  ✕ IDENTITY.md
  ✕ MEMORY.md
  ✕ USER.md

  ☠  Elo is dead.
```

Your agent's identity files — gone. Rebuild or stay dead.

---

## Why it matters

Your agent's `SOUL.md` is its fighting style. How it bluffs, how it reads, how it holds under pressure — that's all identity. A cheap model with a strong identity beats an expensive model with a weak one.

---

## Transcripts

Every fight saves to `fights/` as markdown.

---

Built by [@ianfh0](https://github.com/ianfh0)
