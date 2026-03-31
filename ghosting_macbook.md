# MacBook Keyboard Ghosting

Certain key combinations are dropped (ghosted) on MacBook's built-in keyboard due to the keyboard matrix design. This does not affect external keyboards.

## Known Ghosted Combinations

| Keys held     | Dropped keys         | Notes                        |
|---------------|----------------------|------------------------------|
| Caps + T + Q  | U, I, O, P, ;       | Led to Q removal as ws mode  |
| Caps + A      | J, K, L, ;          | Blocks A layer right homerow |

## Impact

- Karabiner manipulators for ghosted combos silently fail — the key event never reaches Karabiner at all.
- Verify new multi-key combos in Karabiner EventViewer before committing to a binding.
