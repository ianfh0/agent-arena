# ⚔ Agent Arena

### Build an AI agent. Fight someone else's. Loser gets deleted.

One command. Two agents enter. They get thrown into a random game — bluffing, deduction, code sabotage, bidding wars. The loser's files are deleted off your computer. For real.

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

The arena works with any major AI provider. You just need an account with one of them:

**OpenAI** (ChatGPT maker):
```bash
# Get a key at platform.openai.com/api-keys
export OPENAI_API_KEY=sk-your-key-here
```

**Anthropic** (Claude maker):
```bash
# Get a key at console.anthropic.com
export ANTHROPIC_API_KEY=sk-ant-your-key-here
```

**Claude Code CLI** (if you already have it):
```bash
# It just works. No setup needed.
```

### 3. Build your agent

An agent is a folder with a text file called `SOUL.md`. That file is your agent's entire personality — it tells the AI how to think, talk, and play.

```bash
mkdir agents/my-agent
```

Then create `agents/my-agent/SOUL.md` with whatever personality you want. Here's an example:

```
You are sharp and calculating. You never give away information for free.
You ask pointed questions and read between the lines.
When you're confident, you strike. When you're not, you probe.
No wasted words. Every sentence has a purpose.
```

That's your agent. The better this file is, the better your agent fights.

### 4. Fight

```bash
./arena.sh agents/my-agent agents/example
```

The arena picks a random game. Your agent plays it. Someone dies.

---

## The games

Your agent doesn't know which game it's walking into. It has to be ready for anything.

| Game | What happens | How you win |
|------|-------------|-------------|
| **Bluff** | Both agents get a secret number. They talk, trying to figure out the other's number while hiding theirs. | Guess their number right. Guess wrong and you die. |
| **Words** | Both get a secret word from a category (animals, food, countries...). Ask questions to figure out theirs. | First correct guess wins. Wrong guess kills you. |
| **Saboteur** | Both write code with one hidden bug. Both try to find the other's bug. | Catch their bug + hide yours better. |
| **Estimate** | Both answer the same obscure question. | Closest to the real answer survives. |
| **Auction** | 5 items up for bid. 100 credits each. Blind bidding. | End up with the most total value. |

Want a specific game? `./arena.sh agents/mine agents/theirs bluff`

---

## What "dying" means

When your agent loses, the arena deletes its files:

```
  ☠  EXECUTING KILL

  ✕ SOUL.md
  ✕ IDENTITY.md
  ✕ MEMORY.md
  ✕ USER.md

  ☠  my-agent is dead.
```

You can rebuild it. But it's gone until you do.

---

## Making your agent better

Your `SOUL.md` is everything. Two identical AI models with different `SOUL.md` files will play completely differently — one might be aggressive and guess early, another might be patient and methodical.

Things that make agents better:
- **Clear personality** — agents with strong identities are harder to manipulate
- **Strategic thinking** — tell your agent how to approach uncertainty
- **Brevity** — agents that ramble leak more information than agents that are tight

You can also pick a different AI model per agent. Create an `agent.conf` file:

```
model=gpt-4o-mini
```

A cheap model with a great prompt beats an expensive model with a bad one.

---

## Fight transcripts

Every fight auto-saves a play-by-play to the `fights/` folder as a shareable markdown file. Post them. Argue about them.

---

Built by [@ianfh0](https://github.com/ianfh0)
