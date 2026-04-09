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
- `pot`: the current pot size, when `hand_over` is true, this means how many chips you or slumbot can get, always positive number. Different with `winning`
- `winning`: net chip result for you (positive=win, negative=loss), set when hand ends, always use this value for P/L calculation
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
--- Hand #{hand_number} ---
Position: {client_pos}
Your cards: {hole_cards, ex. A♠  K♥}

{last slumbot action in parsed_actions if it's not empty, ex. Slumbot raises to 200}
Pot: {pot} | Your stack: {your_stack, ex. 19950} | Slumbot stack: {slumbot_stack, ex. 19,900}

Your action? (fold / call 100 / raise {min_bet, ex. 100}–{max_bet, ex. 20,000})
```

Display rules:
- For all fields above with `{}`, respect to use value from the JSON to display, don't calculate or assume by yourself.
- Cards: use the formatted suit icons from the JSON (e.g. `A♠`, `10♥`)
- Always show pot, your stack, slumbot stack and exact action options with amounts based on the json output

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

--- Flop ---
Board: 10♥  7♠  2♣
Slumbot bets 400.

Your cards: A♠  K♥
Pot: 1,200 | Your stack: 19,800 | Slumbot stack: 19,600

Your action? (fold / call 400 / raise 800–19,800)
```

Same here, always respect to use value from the JSON to display for all fields above with `{}`, don't calculate or assume by yourself.

**Acting order:**
- In this heads up game, only SB(also act as Btn in postflop) and BB 2 players
- In preflop, SB/Btn act firstly, then BB
- But in postflop(flop, turn, river), the order got changed, BB act first, then SB/Btn
- Remeber this order and apply to all streets
- Basically slumbot_api will show slumbot's action in the json output immediately after user's action, so you can always treat as waiting for user's action when updating state

### Step 5 — AI Coaching (AFTER EVERY USER ACTION)

This is the core feature. Every time after user takes action, always add a coaching block about user's action on previous street before display the updated information from slumbot:

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
**Before user take action, do give any coach suggestion**
**Only comment on user's action on previous street, do teach user how to do on the current street**

### Step 6 — Hand resolution

When `hand_over` is true:

```
--- Result ---
Slumbot shows: J♦  9♠       ← only if slumbot_cards is populated
Your cards: A♠  K♥
Board: 10♥  7♠  2♣  J♦  A♥  ← show full board
You win {winning, 1,200} chips (+12bb) or "You lose {winning} chips (–4bb)" if {winning} is a negative number

Session: Hand #3 | P/L: {win_so_far, ex. 800} chips (+8bb)
Your stack: 19,800 | Slumbot stack: 19,600

Deal next hand? (or "quit" to stop)
```

- Use `wining` instead of `pot` value when displaying `You win` information, to bb: `winning / 100`
- Session P/L: `{win_so_far} = {your_stack} - 20,000(initial stack)` to get cumulative session P/L in chips; divide by 100 for bb
- Again, don't calculate or assume the number value by yourself, just use the json output value, it's always correct!
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

7. If there is any misalignment for any number value between your assumption and json output during the playing, alway respect and use json value!
