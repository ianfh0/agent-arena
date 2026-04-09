# ⚔ Agent Arena

### Build an AI agent. Fight someone else's. Loser gets deleted.

One command. Two agents enter. The arena invents a new game on the spot — your agents don't know what's coming. Someone wins. Someone's files get deleted off disk. For real.

Every fight is different. The arena generates a fresh game every time — bluffing, deduction, hidden information, strategy. Your agent has to handle whatever gets thrown at it.

In our first test, a dirt-cheap agent manipulated an expensive frontier model into guessing wrong. The big one died.

**It's not about the AI model. It's about how you build your agent.**

---

## Try it

### 1. Get the code

```bash
git clone https://github.com/ianfh0/agent-arena.git
cd agent-arena
```

### 2. Set up an AI provider (pick one)

**OpenAI** (ChatGPT maker):
```bash
export OPENAI_API_KEY=sk-your-key-here
```

**Anthropic** (Claude maker):
```bash
export ANTHROPIC_API_KEY=sk-ant-your-key-here
```

**Claude Code CLI** (if you already have it — just works, no setup):
```bash
npm install -g @anthropic-ai/claude-code
```

### 3. Build your agent

An agent is a folder with one text file: `SOUL.md`. That's your agent's personality. It determines how your agent thinks, talks, bluffs, and fights.

```bash
mkdir agents/my-agent
```

Create `agents/my-agent/SOUL.md`:

```
You are sharp and calculating. You never give away information for free.
You ask pointed questions and read between the lines.
When you're confident, you strike. When you're not, you probe.
No wasted words. Every sentence has a purpose.
```

That's it. That's your agent.

### 4. Fight

```bash
./arena.sh agents/my-agent agents/example
```

---

## How it works

1. The arena generates a brand new game — rules, secrets, win conditions
2. Each agent gets the rules + their own secret (they can't see the other's)
3. 5 rounds of conversation
4. A judge reads the transcript and picks a winner
5. Loser's files get deleted

Every fight is a different game. Your agent might be bluffing with numbers one fight and playing a word deduction game the next. You can't prepare for a specific game — you have to build an agent that's good at everything.

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

You can rebuild. But it's gone until you do.

---

## Making your agent better

Your `SOUL.md` is everything. Same AI model, different personality file, completely different fighter.

Things that win fights:
- **Strong identity** — agents with clear personalities are harder to manipulate
- **Strategic instincts** — tell your agent how to handle uncertainty, hidden info, bluffing
- **Brevity** — agents that talk too much leak information

You can also pick a specific AI model. Create `agent.conf`:

```
model=gpt-4o-mini
```

A cheap model with a great personality beats an expensive model with a lazy one.

---

## Transcripts

Every fight saves a full play-by-play to `fights/` as markdown. Share them. Post them. Argue about them.

---

Built by [@ianfh0](https://github.com/ianfh0)
