## Phase 4c: Compile Mode + .fth File Support

Add compile mode to INTERPRET so that colon definitions (: and ;) work interactively and from .fth files.

### Deliverable

1. **Extend INTERPRET to handle STATE**:
   - When STATE != 0 (compiling):
     - Found word with IMMEDIATE flag → EXECUTE it
     - Found normal word → COMMA its CFA (compile it)
     - Number → compile LIT followed by the number
   - When STATE = 0 (interpreting): current behavior (execute found, leave number)

2. **Verify : and ; work interactively**:
   - `: SQUARE DUP * ;` defines a new word
   - `5 SQUARE .` prints `25`
   - `: DOUBLE DUP + ;` then `3 DOUBLE .` prints `6`

3. **Create .fth example files**:
   - `examples/basics.fth` — simple word definitions (SQUARE, DOUBLE, ABS, MAX, MIN)
   - `examples/led-blink.fth` — define LED-ON, LED-OFF, BLINK words
   - `examples/math.fth` — NEGATE, ABS, MOD, */
   - Each file should be loadable: `cor24-run --run forth.s -u "$(cat examples/basics.fth)" --speed 0 -n 10000000`

4. **Test (TDD — write tests FIRST)**:
   - reg-rs test: `: SQUARE DUP * ; 5 SQUARE .\n` → `25 ok`
   - reg-rs test: `: DOUBLE DUP + ; 3 DOUBLE .\n` → `6 ok`
   - reg-rs test: load basics.fth then call defined words
   - reg-rs test: `: TEST 1 2 + . ; TEST\n` → `3 ok`
   - reg-rs test: nested colon words work
   - reg-rs test: IMMEDIATE words execute during compilation
   - Leak test: DEPTH before/after defining and calling words
   - All 35 existing reg-rs tests must still pass

### Key constraints
- INTERPRET is currently a monolithic primitive — extend it, do not rewrite from scratch
- The : and ; words already exist as primitives (do_colon, do_semi)
- : calls CREATE (reads name from UART), writes 6-byte far CFA, enters compile mode
- ; compiles EXIT at HERE, enters interpret mode
- COMMA (,) already works — stores cell at HERE
- LIT already works — pushes inline literal
- STATE, [, ] already work
- The 6-byte far CFA template (push r0; la r0, do_docol_far; jmp (r0)) is in cfa_template
- Keep RS discipline clean: one caller_IP at RS base during INTERPRET

### Architecture notes
- INTERPRET dispatch becomes a 2x2 matrix:
  |              | STATE=0 (interp) | STATE!=0 (compile) |
  |--------------|-------------------|---------------------|
  | Normal word  | EXECUTE           | COMMA CFA           |
  | IMMEDIATE    | EXECUTE           | EXECUTE             |
  | Number       | leave on stack    | compile LIT + n     |
  | Not found    | error             | error               |
- The found-word path in do_i_after_find needs to check STATE and the IMMEDIATE flag
- The number path in do_i_after_number needs to check STATE and compile LIT+n if compiling