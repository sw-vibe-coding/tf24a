# tf24a: Tiny Forth for COR24 in Assembler

DTC Forth targeting COR24-TB via cor24-run assembler/emulator.
Clean-room implementation, assembler kernel, self-extending in Forth.

## Design Decisions (Frozen)
- DTC (Direct Threaded Code)
- No TOS cache (only 3 GP registers)
- sp = data stack (hardware push/pop in EBR)
- r1 = return stack pointer (SRAM region)
- r2 = IP (instruction pointer)
- r0 = W / scratch
- 24-bit cell (3 bytes)
- Little-endian
- Entry point at address 0

## Memory Layout
- 0x000000+: bootstrap code, primitives, dictionary (grows up via HERE)
- ~0x0F0000: return stack (grows down via r1)
- EBR (sp): data stack (hardware push/pop)
- 0xFF0100: UART data, 0xFF0101: UART status

## Phases

### Phase 1: Bootstrap & Stacks
- Entry point, register init, UART I/O (KEY, EMIT)
- Data stack (push/pop) and return stack (r1-based) primitives
- NEXT macro, halt pattern
- Test: echo characters, stack push/pop verified via --dump

### Phase 2: Inner Interpreter & Primitives
- NEXT, DOCOL (inline per colon word), EXIT
- LIT, BRANCH, 0BRANCH
- Arithmetic: + - AND OR XOR = < 0=
- Stack ops: DROP DUP SWAP OVER >R R> R@
- Memory: @ ! C@ C!
- Test: hand-assembled colon definitions execute correctly

### Phase 3: Dictionary & Compiler
- Dictionary header layout (link, flags+len, name, code field)
- HERE, LATEST, STATE, BASE variables
- FIND (dictionary search)
- Number parser
- : and ; (colon compiler)
- , (comma - compile cell) and ALLOT
- CREATE, IMMEDIATE, [ ]
- Test: define and run : SQUARE DUP * ;

### Phase 4: Text Interpreter (QUIT)
- Token parser (WORD equivalent)
- Interpret/compile dispatch
- QUIT outer loop
- Error handling (? for unknown words)
- Test: interactive session via --terminal: 1 2 + . prints 3

### Phase 5: Self-Hosted Growth (Forth source)
- . (dot - print number), CR, SPACE, SPACES
- IF ELSE THEN, BEGIN UNTIL AGAIN WHILE REPEAT
- VARIABLE, CONSTANT
- DO LOOP (optional)
- .S, WORDS (debugging tools)
- Test: Forth-defined words work, fibonacci in Forth

### Phase 6: Board Integration (future)
- IO@ IO! for memory-mapped I/O
- LED/button words
- Interrupt support (deferred)