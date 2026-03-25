## Phase 4b: Debugging and Convenience Words

Add utility words that work in interpret-only mode. These help with interactive debugging and make the REPL more usable.

### Deliverable
Add these primitives to forth.s:

1. **CR** ( -- ) : Emit newline (ASCII 10)
2. **SPACE** ( -- ) : Emit space (ASCII 32)
3. **DECIMAL** ( -- ) : Set BASE to 10
4. **HEX** ( -- ) : Set BASE to 16
5. **.S** ( -- ) : Print the data stack contents non-destructively, format: "<n> x1 x2 ... xn"
   - Need DEPTH or SP@ to know stack depth
   - Print from bottom to top
6. **WORDS** ( -- ) : Walk dictionary from LATEST, print all non-hidden word names
7. **DEPTH** ( -- n ) : Push current stack depth

### Key constraints
- All words are primitives (assembler, not colon definitions)
- Must not corrupt the data or return stack
- .S must be non-destructive (leave stack unchanged)
- WORDS walks the link chain from LATEST to 0
- For .S, you need a way to read stack entries without popping. COR24 EBR stack only supports push/pop, so you may need to pop all, save on RS, print, and restore.
- HEX sets BASE=16. NUMBER already handles digits 0-9 only, so extend NUMBER to also accept A-F (uppercase) for hex digits.
- All new words need dictionary headers chained from the previous LATEST entry

### Test
Feed via UART:
- "DECIMAL 255 . HEX 255 . DECIMAL\n" → should print "255 FF " (or "255 ff ")
- ".S\n" after pushing values → prints stack contents
- "WORDS\n" → lists all defined words
- Verify all previous tests still pass (regression)