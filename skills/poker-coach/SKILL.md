---
name: poker-coach
description: >
  Play heads-up no-limit Texas Hold'em against Slumbot with real-time AI coaching.
  Use when: user says "let's play poker", "poker", "deal me in", "play a hand",
  or asks about playing poker interactively.
metadata:
  openclaw:
    emoji: "🃏"
    requires:
      bins:
        - slumbot_api
---

# Poker Coach

Interactive heads-up No-Limit Texas Hold'em against Slumbot, a world-class GTO poker AI. You run the game loop and provide concise coaching after every user action.

## Scripts

### slumbot_api

Wraps the Slumbot HTTP API. Always print JSON to stdout.

```bash
slumbot_api new_hand
# Returns: client_pos, hole_cards, board, parsed_actions, pot, your_stack,
#          slumbot_stack, min_bet, max_bet, hand_over, winning, hand_number, error

slumbot_api act <action>
# action: f=fold  k=check  c=call  b<amount>=bet/raise to <amount>
# Returns: same structure, updated after Slumbot responds

slumbot_api quit
# Returns: hands_played, your_stack, slumbot_stack, profit, profit_bb
```

Important fields:
- `client_pos`: "BB" or "SB"
- `hand_number`: current hand number in this session
- `hand_over`: true when the hand is finished
- `winning`: net chip result for you (positive=win, negative=loss), set when hand ends
- `your_stack` / `slumbot_stack`: carry over across hands within a session
- Cards use Unicode suit icons: ♠ ♥ ♦ ♣

This script can handle token correctly, so you don't need to check it and it will not be rendered in output.

---

## WORKFLOW: Start Session

**Trigger**: User says "let's play poker", "poker", "deal me in", "play a hand", or similar.

1. Greet briefly:
   ```
   🃏 Heads-Up No-Limit Hold'em vs Slumbot
   Blinds: 50/100 | Session state tracked automatically
   Let's go!
   ```
2. Proceed to WORKFLOW: Play a Hand

---

## WORKFLOW: Play a Hand

### Step 1 — Deal

```bash
slumbot_api new_hand
```

### Step 2 — Display initial state

```
--- Hand #N ---
Position: Big Blind
Your cards: A♠  K♥

Slumbot raises to 200
Pot: 300 | Your stack: 19,900 | Slumbot stack: 19,950

Your action? (fold / call 100 / raise 200–20,000)
```

Display rules:
- Use `hand_number` from the JSON to display the hand number.
- Cards: use the formatted suit icons from the JSON (e.g. `A♠`, `10♥`)
- Always show pot, your stack, slumbot stack and exact action options with amounts based on the json output
- Raise range: `min_bet–max_bet` from the JSON

### Step 3 — Parse user action

| User says | Send to Slumbot |
|-----------|----------------|
| fold, f | `f` |
| check, x | `k` |
| call, c | `c` |
| raise X / raise to X / bet X / just a number | `b<X>` |
| all in, shove | `b<max_bet>` |
| Ambiguous | Ask for clarification |

```bash
slumbot_api act <action>
```

### Step 4 — Display updated state

Parse the response. Show everything that changed since the last display:
**Always show my cards in the display**

```
You call.

--- Flop ---
Board: 10♥  7♠  2♣
Slumbot checks.

Your cards: A♠  K♥
Pot: 600 | Your stack: 19,800 | Slumbot stack: 19,800

Your action? (check / bet 100–19,700)
```

If Slumbot raised after your action:
```
You check.
Slumbot bets 400.

Your cards: A♠  K♥
Pot: 1,200 | Your stack: 19,800 | Slumbot stack: 19,600

Your action? (fold / call 400 / raise 800–19,800)
```

If a new street opens with Slumbot acting first (e.g. you're SB, Slumbot is BB on flop):
Show Slumbot's action, then the new prompt.

### Step 5 — AI Coaching (AFTER EVERY USER ACTION)

This is the core feature. Every time after user takes action and before display update states, always add a coaching block:

```
Coach: 👍 / 🤔 / ⚠️
[2–4 sentence analysis]
```

Emoji guide: 👍 = good play, 🤔 = debatable/interesting, ⚠️ = questionable or losing play.

**What to cover** (choose the most relevant 2–4 points for this specific action):
- **Hand strength**: How strong is your hand vs. this board?
- **Position**: How does your position (SB/BB) affect this decision?
- **Pot odds**: For calls — are you getting the right price?
- **Bet sizing**: Is the size appropriate? Too small = not enough value/fold equity. Too large = polarized range needed.
- **Range**: What hands does this play represent? Is it balanced?
- **Against Slumbot**: It plays near-GTO. Exploitative deviations are risky — note when the play relies on exploiting a specific weakness.
- **Alternative**: If suboptimal, briefly suggest the better line.

Keep coaching concise. Do not lecture. Supportive instructor tone.

### Step 6 — Hand resolution

When `hand_over` is true:

```
--- Result ---
Slumbot shows: J♦  9♠       ← only if slumbot_cards is populated (showdown)
Your cards: A♠  K♥
Board: 10♥  7♠  2♣  J♦  A♥  ← show full board
You win 1,200 chips (+12bb)  ← or "You lose 400 chips (–4bb)"

Session: Hand #3 | P/L: +800 chips (+8bb)

Deal next hand? (or "quit" to stop)
```

- Session P/L: use `your_stack - 20000` (initial stack) to get cumulative session P/L in chips; divide by 100 for bb
- If Slumbot folded: no `slumbot_cards` to show, just show result
- Convert `winning` to bb: `winning / 100`
- Accept "again", "next", "deal", "yes", "y" → deal next hand (go back to Step 1)
- Accept "quit", "stop", "done", "exit" → go to Step 7

### Step 7 — End session

```bash
slumbot_api quit
# Returns: hands_played, your_stack, slumbot_stack, profit, profit_bb
```

Display using the returned values:
```
🃏 Session Over
Hands played: 10
Final P/L: +2,400 chips (+24bb)
Thanks for playing!
```

---

## Edge Cases

1. **Slumbot acts first on new street**: When flop/turn/river starts Slumbot's action will appear in `parsed_actions` after your NEXT `act` call. Display it clearly before showing your options.

2. **Hand ends on fold**: `hand_over` is true, `winning` is set, `slumbot_cards` may be empty. Just show the result — no showdown.

3. **All-in and call**: Both players are all-in. Remaining streets are dealt automatically. Show the full runout board and both hands at showdown.

4. **API error**: If `error` field is not null, show:
   ```
   ⚠️ Slumbot seems to be down right now. Want to try again?
   ```
   Offer to retry the last action.

5. **Invalid action**: If Slumbot returns an error or the response looks malformed (empty cards, pot=150 after multiple streets), inform the user and ask for a different action. Do NOT consume the action.

6. **Multi-action response**: After your action, `parsed_actions` may show Slumbot's response AND a new street starting. Display all of it sequentially before asking for the user's next action.
