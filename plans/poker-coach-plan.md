# Plan: Poker Coach Skill — Play Against Slumbot with AI Coaching

## Context

Build an interactive OpenClaw skill that lets the user play heads-up no-limit Texas Hold'em against Slumbot (a world-class poker AI) via chat, with real-time AI coaching on every action. Triggered by "let's play poker" in chat.

**Key design decisions:**
- **No PyPokerEngine** — Slumbot's HTTP API handles all game mechanics (dealing, rules, pot tracking, showdown). PyPokerEngine would conflict with Slumbot's game loop and add unnecessary complexity.
- **Database for notable hands** — Hands with final pot > 10BB are auto-saved to MySQL (`poker` database) by the `slumbot_api` script for future case study. Session stats (hands played, P/L) remain conversational state.
- **No cron job** — Purely interactive, on-demand via chat.

---

## Slumbot API Reference

Base URL: `https://slumbot.com`

### POST /api/new_hand
- No auth required, no body needed
- Returns: `{token, action, client_pos, hole_cards, board, winning}`
- `client_pos`: 0 = small blind (acts first preflop), 1 = big blind
- `token`: session identifier for this hand (pass to all subsequent act calls)

### POST /api/act
- Body: `{token: "<token>", incr: "<action>"}`
- Actions: `f`=fold, `k`=check, `c`=call, `b<amount>`=bet/raise TO amount
- Returns: same structure as new_hand, updated

### Game Parameters
- Heads-up No-Limit Texas Hold'em
- Starting stacks: 20,000 chips (200 big blinds)
- Blinds: 50 (SB) / 100 (BB)
- Card format: `Ah` = Ace of hearts, `Ts` = Ten of spades (Rank + lowercase suit)

### Action String Format
Slumbot's `action` field encodes the full hand history:
- Actions within a street are concatenated: `b200c` = bet 200, call
- Streets separated by `/`: `b200c/kb500c/...`
- `b<N>` = bet/raise to N total, `c` = call, `k` = check, `f` = fold
- Trailing position determines whose turn it is
- Preflop: SB (pos 0) acts first. Post-flop: position after dealer acts first (BB in heads-up)

---

## Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `tools/skills/poker-coach/slumbot_api` | **Create** | Python3 script wrapping Slumbot HTTP API + auto-save notable hands |
| `skills/poker-coach/SKILL.md` | **Create** | AI instruction file for game flow, display, coaching |
| `deploy_config.json` | **Modify** | Register new skill and tool |
| `bins/init_db.sh` | **Modify** | Add `poker` database and `notable_hands` table creation |

---

## Database: `poker`

### Schema

```sql
CREATE DATABASE IF NOT EXISTS poker CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS notable_hands (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  played_at       DATETIME NOT NULL DEFAULT NOW(),
  position        VARCHAR(2) NOT NULL,          -- 'SB' or 'BB'
  hole_cards      VARCHAR(10) NOT NULL,         -- e.g. 'Ah Ks'
  board           VARCHAR(30),                  -- e.g. 'Ts 7h 2c Jd Ah', NULL if hand ended pre-flop with no board
  action_history  TEXT NOT NULL,                -- raw Slumbot action string, e.g. 'b300c/kb600c/b1500f'
  pot_bb          DECIMAL(6,1) NOT NULL,        -- final pot in BB (e.g. 12.0)
  result_bb       DECIMAL(6,1) NOT NULL,        -- user profit/loss in BB (e.g. +6.0 or -6.0)
  slumbot_cards   VARCHAR(10),                  -- e.g. 'Jd 9s', NULL if not revealed (fold)
  outcome         VARCHAR(10) NOT NULL          -- 'win', 'lose', or 'tie'
);
```

### Notes
- `pot_bb` and `result_bb` store values in big blinds (chip amount / 100) for readability
- `action_history` stores the raw Slumbot string for full replay capability
- `slumbot_cards` is NULL when hand ends by fold (no showdown)
- The `slumbot_api` script calls `mysql_exec` directly to insert — no separate save script needed

---

## File 1: `tools/skills/poker-coach/slumbot_api`

Executable Python3 script (`#!/usr/bin/env python3`). Uses stdlib (`urllib.request`, `json`, `sys`, `argparse`, `subprocess`, `os`) and calls `mysql_exec` for DB writes.

### Session File

`/tmp/slumbot_session.json` — persists session state across commands:

```json
{
  "token": "abc123...",
  "your_stack": 19500,
  "slumbot_stack": 20500,
  "hands_played": 3
}
```

- `new_hand` reads token from session file (if exists) and passes it to Slumbot to continue the same session (stacks carry over). Increments `hands_played`. Writes new token + updated stacks + hand count back after response.
- `act` reads token from session file — no token arg needed in CLI. Updates stacks after each action.
- `quit` deletes the session file and prints a final summary with total hands and P/L.
- If the session file is missing or unreadable, `new_hand` starts a fresh session (no token passed to Slumbot, stacks reset to 20000, `hands_played` resets to 1).

### CLI Interface

```bash
slumbot_api new_hand       # Start next hand (continues session automatically)
slumbot_api act <action>   # Send action: f, k, c, b<amount>
slumbot_api quit           # End session: delete session file, print summary
```

### Output JSON Schema (printed to stdout)

```json
{
  "token": "abc123...",
  "client_pos": "BB",
  "hole_cards": ["A♥", "K♠"],
  "board": ["10♠", "7♥", "2♣"],
  "slumbot_cards": [],
  "action_history": "b200c/kb500",
  "parsed_actions": {
    "preflop": [
      {"player": "Slumbot (SB)", "action": "raise to 200"},
      {"player": "You (BB)", "action": "call 100"}
    ],
    "flop": [
      {"player": "You (BB)", "action": "check"},
      {"player": "Slumbot (SB)", "action": "bet 500"}
    ]
  },
  "pot": 900,
  "your_stack": 19500,
  "slumbot_stack": 19600,
  "to_act": "you",
  "min_bet": 1000,
  "max_bet": 19500,
  "hand_over": false,
  "winning": null,
  "hand_number": 3,
  "error": null
}
```

- `client_pos`: `"BB"` or `"SB"` (string, not integer)
- `slumbot_cards`: empty during play, populated at showdown if Slumbot reveals
- `winning`: null during play, positive = user won chips, negative = user lost chips
- `hand_over`: true when hand is complete (fold, showdown, or all-in runout)
- `hand_number`: current hand number in the session (same value as `hands_played` in the session file after increment)
- `error`: null on success, string message on failure (never crashes)

### Functions

#### `def load_session() -> dict`
- Read and parse `/tmp/slumbot_session.json`
- Return `{token, your_stack, slumbot_stack, hands_played}` on success
- Return `{token: None, your_stack: 20000, slumbot_stack: 20000, hands_played: 0}` if file missing or invalid

#### `def save_session(token: str, your_stack: int, slumbot_stack: int, hands_played: int) -> None`
- Write session dict to `/tmp/slumbot_session.json`
- Silent on failure (best-effort)

#### `def new_hand() -> dict`
- Call `load_session()` to get current token and hand count
- POST to `https://slumbot.com/api/new_hand` with `{"token": token}` if token exists, else `{}`
- Parse response with `parse_response()`
- Increment `hands_played`, call `save_session()` with new token + stacks from result
- Inject `hand_number` (= `hands_played` after increment) into result dict before returning

#### `def act(action: str) -> dict`
- Call `load_session()` to get token; return error if token is empty
- POST to `https://slumbot.com/api/act` with `{"token": token, "incr": action}`
- Parse response with `parse_response()`
- Call `save_session()` with updated stacks; call `maybe_save_hand(result)`
- Inject `hand_number` from session into result dict before returning

#### `def quit_session() -> dict`
- Call `load_session()` to read final state
- Compute `profit = your_stack - STARTING_STACK` (net chips vs session start)
- Compute `profit_bb = profit / BB_CHIP_VALUE`
- Delete `/tmp/slumbot_session.json`
- Return summary dict:
  ```json
  {
    "hands_played": 10,
    "your_stack": 21500,
    "slumbot_stack": 18500,
    "profit": 1500,
    "profit_bb": 15.0,
    "session_over": true
  }
  ```

#### `def parse_response(raw: dict) -> dict`
Main normalization function:
1. Extract `token`, `client_pos` from raw response
2. Parse `hole_cards` — Slumbot may return as 2-char-pair string `"AhKs"` or list; normalize to `["Ah", "Ks"]`
3. Parse `board` — same treatment, split into list of card strings
4. Call `parse_action_string(raw["action"], raw["client_pos"])` to get:
   - `parsed_actions` dict (street -> list of {player, action} dicts)
   - `pot` (current pot size)
   - `to_act` ("you" or "slumbot" or null if hand over)
   - `min_bet` / `max_bet` (valid raise range)
   - `hand_over` boolean
5. Compute `your_stack` and `slumbot_stack` from starting 20000 minus chips committed
6. Extract `winning` from raw response (null if hand ongoing)
7. Extract `slumbot_cards` if present in response (showdown)
8. Return full normalized JSON

#### `def parse_action_string(action_str: str, client_pos: int) -> dict`

**This is the most complex function.** Core logic:

```
Input:  "b300c/kb600c/b1500f"  (client_pos=0, client is SB)
Output: {
  "preflop": [
    {"player": "You (SB)", "action": "raise to 300"},
    {"player": "Slumbot (BB)", "action": "call"}
  ],
  "flop": [
    {"player": "Slumbot (BB)", "action": "check"},     # post-flop: BB acts first in HU
    {"player": "You (SB)", "action": "bet 600"},
    {"player": "Slumbot (BB)", "action": "call"}
  ],
  "turn": [
    {"player": "Slumbot (BB)", "action": "bet 1500"},
    {"player": "You (SB)", "action": "fold"}
  ]
}
```

Algorithm:
1. Split by `/` to get street strings
2. For each street, tokenize: scan for `f`, `k`, `c`, or `b` followed by digits
3. Map street index to name: 0=preflop, 1=flop, 2=turn, 3=river
4. Determine action order per street:
   - Preflop: SB (pos 0) acts first, then BB (pos 1), alternating
   - Post-flop (flop/turn/river): In heads-up, BB acts first (not the dealer)
5. Track pot: start at 150 (blinds 50+100), add each bet/call amount
6. Track last bet per street to compute call amounts and min raise
7. Determine `to_act` based on whether the action string expects more input
8. Compute `min_bet` = last raise size * 2 (or BB if no raise yet), `max_bet` = remaining stack

#### `def maybe_save_hand(result: dict) -> None`
Called at the end of `parse_response()` when `hand_over` is true. Auto-saves notable hands:
1. Compute `pot_bb = pot / 100` (BB = 100 chips)
2. If `pot_bb <= 10`, return immediately — not notable enough
3. Determine `outcome`: `"win"` if `winning > 0`, `"lose"` if `winning < 0`, `"tie"` if `winning == 0`
4. Build INSERT and call `mysql_exec` via `subprocess.run()`:
   ```bash
   mysql_exec poker "INSERT INTO notable_hands (position, hole_cards, board, action_history, pot_bb, result_bb, slumbot_cards, outcome) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)" \
     "SB" "Ah Ks" "Ts 7h 2c Jd Ah" "b300c/kb600c" "12.0" "6.0" "Jd 9s" "win"
   ```
5. On `mysql_exec` failure: print warning to stderr but do NOT fail the main output — the JSON response is still printed to stdout normally. Saving is best-effort.

#### `def format_card(card: str) -> str`
Convert card notation to readable format with Unicode suit icons:
- Map: `h` -> `♥`, `d` -> `♦`, `c` -> `♣`, `s` -> `♠`
- Replace `T` with `10` for readability
- Examples: `"Ah"` -> `"A♥"`, `"Ts"` -> `"10♠"`, `"7d"` -> `"7♦"`
- Fallback: if Unicode icons cause display issues, use full suit names: `"A heart"`, `"10 spade"`
- Applied to all cards in output JSON (`hole_cards`, `board`, `slumbot_cards`)

#### `def main()`
- `argparse` with subcommands: `new_hand`, `act`, `quit`
- `act` takes one positional arg: `action` (token read from session file internally)
- `quit` takes no args
- Call appropriate function, `json.dumps()` result to stdout
- Wrap everything in try/except: on any exception, print `{"error": "<message>"}` and exit 0

### Error Handling
- 15-second timeout on all HTTP requests (`urllib.request.urlopen(..., timeout=15)`)
- Catch `urllib.error.URLError` / `urllib.error.HTTPError` -> `{"error": "Slumbot API unreachable"}`
- Catch JSON decode errors -> `{"error": "Invalid response from Slumbot"}`
- Never exit non-zero; always print valid JSON

---

## File 2: `skills/poker-coach/SKILL.md`

### Frontmatter

```yaml
---
name: poker-coach
description: >
  Play heads-up no-limit Texas Hold'em against Slumbot with real-time AI coaching.
  Use when: user says "let's play poker", "poker", "deal me in", "play a hand",
  or asks about playing poker interactively.
metadata:
  openclaw:
    emoji: "poker"
    requires:
      bins:
        - slumbot_api
---
```

### Content Structure

#### Introduction
Explain: "Interactive heads-up NLHE against Slumbot. You provide coaching after every user action."

#### Scripts Section

Document `slumbot_api` CLI usage:
```
slumbot_api new_hand      -> JSON with cards, initial state, hands_played
slumbot_api act <action>  -> JSON with updated state after action
slumbot_api quit          -> JSON summary: hands_played, final stacks, session_over
Actions: f=fold, k=check, c=call, b<amount>=bet/raise to <amount>
Session state (token, stacks, hand count) is managed automatically in /tmp/slumbot_session.json
```

#### WORKFLOW: Start Session

**Trigger**: User says "let's play poker", "poker", "deal", "play a hand", etc.

**Steps**:
1. Greet briefly:
   ```
   Heads-Up No-Limit Hold'em vs Slumbot
   Stack: 20,000 chips (200bb) | Blinds: 50/100
   Let's go!
   ```
2. Initialize conversation tracking: hands_played=0, session_profit=0
3. Proceed to Play a Hand workflow

#### WORKFLOW: Play a Hand

**Step 1 — Deal**
```bash
slumbot_api new_hand
```
Parse JSON output. `hands_played` is included in the response directly from the session file — no need to track it in conversation.

**Step 2 — Display initial state**

Format:
```
--- Hand #1 ---
Position: Small Blind (you post 50)
Your cards: A♠  K♥

Pot: 150
Your action? (fold / call 100 / raise 200-20000)
```

OR if Slumbot acted first (user is BB):
```
--- Hand #1 ---
Position: Big Blind (you post 100)
Your cards: Q♦  J♦

Slumbot raises to 250
Pot: 300
Your action? (fold / call 250 / raise 500-20000)
```

**Display rules**:
- Use Unicode suit icons: ♠ ♥ ♦ ♣ (e.g. `A♠`, `K♥`, `10♦`, `7♣`)
- Show `T` as `10`
- Always show valid actions with exact amounts
- Show pot total

**Step 3 — Parse user action**

| User input | Slumbot action code |
|-----------|-------------------|
| fold, f | `f` |
| check, x | `k` |
| call, c | `c` |
| raise X, raise to X, bet X, rX, just a number | `b<X>` |
| all in, allin, shove | `b20000` (or remaining stack) |
| Ambiguous input | Ask for clarification |

Execute:
```bash
slumbot_api act <token> <action>
```

**Step 4 — Display updated state**

Show Slumbot's response, new board cards, updated pot:
```
You call.

--- Flop ---
Board: 10♥  7♠  2♣
Slumbot checks.

Pot: 600
Your action? (check / bet 100-19700)
```

If multiple things happen (Slumbot acts, new street starts, Slumbot acts again):
```
You raise to 600.
Slumbot calls.

--- Turn ---
Board: 10♥  7♠  2♣  J♦
Slumbot bets 800.

Pot: 2000
Your action? (fold / call 800 / raise 1600-19100)
```

**Step 5 — AI Coaching (AFTER EVERY USER ACTION)**

This is the core feature. After displaying the game state update, always add a coaching comment:

```
Coach: [thumbs_up / thinking / warning emoji based on quality]
[2-4 sentences analyzing the action]
```

**Coaching guidelines for the AI**:
1. **Evaluate action quality**: good, reasonable, questionable, or bad
2. **Analyze using poker concepts**:
   - **Hand strength**: Where does this hand rank on this board texture?
   - **Position**: How does position affect this decision?
   - **Pot odds**: For calls — is the price right mathematically?
   - **Bet sizing**: For bets/raises — is the size appropriate for the board and situation?
   - **Range consideration**: What hands would typically make this play?
   - **Against Slumbot**: It plays near-GTO, so exploitative deviations are risky
3. **Suggest alternatives** if the play was suboptimal (briefly)
4. **Keep it concise**: 2-4 sentences MAX. Supportive instructor tone, never condescending.

**Coaching examples**:

After a good call on the flop:
```
Coach: Good call. You have top pair with a strong kicker on a dry board —
this is well ahead of Slumbot's continuation betting range. Folding here
would be way too tight, and raising isn't necessary yet.
```

After a questionable min-raise:
```
Coach: The min-raise here is a bit small. With a strong draw (flush + straight),
you want to build the pot — raising to 3x the bet would apply more pressure and
get more value when you hit. Slumbot will call a larger raise with the same
range it calls the min-raise with.
```

**Step 6 — Hand resolution**

When `hand_over` is true:
```
--- Result ---
Slumbot shows: K♣  Q♠
Board: 10♥  7♠  2♣  J♦  A♥
You win with: pair of Aces (A♠  K♥)

Won 2,400 chips (+24bb)
Session: 3 hands | P/L: +1,200 chips (+12bb)

Deal next hand? (or "quit" to stop)
```

Update session_profit with `winning` value.

Accept: "again", "next", "deal", "yes", "y" -> deal next hand
Accept: "quit", "stop", "done", "exit" -> end session

**Step 7 — End session**
```
Session Over
Hands played: 10
Final P/L: +2,400 chips (+24bb)
Thanks for playing!
```

#### Edge Cases

Document these in SKILL.md for the AI to handle:

1. **Slumbot acts first**: When `client_pos=1` (user is BB), Slumbot may have already raised preflop. Show this action before asking user.

2. **Hand ends immediately on fold**: If user folds or Slumbot folds, show result and go to Step 6. No showdown cards revealed on fold.

3. **All-in and call**: When all chips go in, remaining community cards are dealt automatically. Display full board and both hands at showdown.

4. **API error**: Show "Slumbot seems to be down right now. Want to try again?" and offer to retry `new_hand` or `act` with same parameters.

5. **Invalid action / bet too small**: If Slumbot returns an error, inform user of valid range and ask again. Do NOT consume an action.

6. **Multi-action responses**: After user acts, response may contain Slumbot's counter-action + new street. Parse `parsed_actions` to display everything that happened.

7. **Showdown without action**: If both players are all-in, remaining streets are dealt automatically — display them as they appear.

---

## File 3: `deploy_config.json` Changes

Add `"poker-coach"` to `skills` array and `"skills/poker-coach/slumbot_api"` to `tools` array:

```json
{
  "skills": [
    "school-mail-monitor",
    "expenses-track",
    "poker-coach"
  ],
  "tools": [
    "mail/mail_fetch",
    "mail/mail_extract",
    "database/mysql_exec",
    "skills/expense-track/expense_add",
    "skills/expense-track/expense_report",
    "skills/poker-coach/slumbot_api",
    "real_state/daily_real_state",
    "morning-briefing/morning_briefing"
  ],
  "cron": {
    "jobs": [
      ... existing 3 jobs unchanged ...
    ]
  }
}
```

---

## Implementation Order

1. **Update `bins/init_db.sh`** — add `poker` database and `notable_hands` table creation
2. **Create directory**: `tools/skills/poker-coach/`
3. **Create `tools/skills/poker-coach/slumbot_api`** — the API wrapper script with auto-save logic
4. **Test locally**: `python3 tools/skills/poker-coach/slumbot_api new_hand` should return valid JSON
5. **Test action flow**: Use the returned token, run `slumbot_api act <token> c`, verify updated state
6. **Create `skills/poker-coach/SKILL.md`** — the full AI instruction file
7. **Update `deploy_config.json`** — add skill and tool
8. **Deploy**: run `bash bins/init_db.sh` on server (creates `poker` DB), then `bash bins/deploy.sh`

---

## Verification Plan

1. **API wrapper unit test**:
   ```bash
   python3 tools/skills/poker-coach/slumbot_api new_hand
   # Expect: valid JSON with token, hole_cards (2 cards), client_pos (0 or 1)
   ```

2. **Action flow test**:
   ```bash
   # Use token from step 1
   python3 tools/skills/poker-coach/slumbot_api act <token> c
   # Expect: updated JSON with board cards (if new street), pot change
   ```

3. **Action string parsing test**: Verify `parsed_actions` correctly assigns actions to "You" vs "Slumbot" across preflop/flop/turn/river for both client_pos=0 and client_pos=1.

4. **Error handling test**:
   ```bash
   python3 tools/skills/poker-coach/slumbot_api act invalid_token c
   # Expect: JSON with error field, not a crash
   ```

5. **End-to-end**: After deploy, say "let's play poker" in OpenClaw chat. Play through a full hand: see cards, make actions, receive coaching, see result. Test fold, call, raise, all-in scenarios.

6. **Notable hand auto-save test**:
   - Play a hand that results in pot > 10BB (e.g. raise and call preflop = 6BB, then bet flop)
   - After hand completes, verify row inserted: `mysql_exec poker "SELECT * FROM notable_hands ORDER BY id DESC LIMIT 1"`
   - Play a hand that ends with pot <= 10BB (e.g. fold preflop) and verify NO row inserted
   - Verify `slumbot_cards` is NULL for hands ending in fold, populated for showdowns

7. **Edge case tests**:
   - Start multiple hands to verify both positions (SB and BB) work
   - Fold immediately to test quick hand resolution
   - Go all-in preflop to test runout display
