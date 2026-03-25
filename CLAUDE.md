# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## CRITICAL: AgentRail Session Protocol (MUST follow exactly)

This project uses AgentRail. Every session follows this exact sequence:

### 1. START (do this FIRST, before anything else)
```bash
agentrail next
```
Read the output carefully. It tells you your current step, prompt, skill docs, and past trajectories.

### 2. BEGIN (immediately after reading the next output)
```bash
agentrail begin
```

### 3. WORK (do what the step prompt says)
Do NOT ask the user "want me to proceed?" or "shall I start?". The step prompt IS your instruction. Execute it.

### 4. COMMIT (after the work is done)
Commit your code changes with git.

### 5. COMPLETE (LAST thing, after committing)
```bash
agentrail complete --summary "what you accomplished" \
  --reward 1 \
  --actions "tools and approach used"
```
If the step failed: `--reward -1 --failure-mode "what went wrong"`
If the saga is finished: add `--done`

### 6. STOP (after complete, DO NOT continue working)
Do NOT make any further code changes after running agentrail complete.
Any changes after complete are untracked and invisible to the next session.
If you see more work to do, it belongs in the NEXT step, not this session.

Do NOT skip any of these steps. The next session depends on your trajectory recording.

## Project: tf24a — Tiny Forth for COR24 in Assembler

Clean-room DTC Forth for the COR24 24-bit RISC ISA. Assembler kernel, self-extending in Forth.

### Tools
- `cor24-run --run file.s [opts]` — assemble and run COR24 assembly
- `cor24-run --run file.s --dump --speed 0 -n N` — run N instructions, dump state
- `cor24-run --run file.s --terminal --echo --speed 0` — interactive UART session
- `cor24-run --run file.s -u 'input' --speed 0 --dump` — feed UART input, dump state

### COR24 Assembly Syntax
- Labels on own line: `label:` (no inline `label: instr`)
- Comments: `;` only (not `#`)
- Decimal immediates (not hex): `la r0, -65280` not `la r0, 0xFF0100`
- `.word label` — emits 24-bit address (one label per directive)
- `.byte 72, 101, 108` — raw bytes (no string literals)
- No `.align` directive; manually pad with `.byte 0`

### Register Allocation (Frozen)
- r0 = W (work register) / scratch
- r1 = RSP (return stack pointer, SRAM ~0x0F0000 growing down)
- r2 = IP (instruction pointer for threaded code)
- sp = DSP (data stack, hardware push/pop in EBR)
- fp = available as extra scratch

### Key ISA Constraints
- Only r0, r1, r2, sp support `add rX, imm8`; fp does NOT
- push/pop only work with sp (1-byte instructions)
- Branch offset ±127 bytes (signed 8-bit)
- `jal r1,(r0)` sets r1=PC+1, jumps to r0 — conflicts with r1=RSP
- Cell size = 3 bytes (24-bit words)

### DTC Inner Interpreter
```
; NEXT (inline everywhere or as tail of each primitive):
;   lw r0, 0(r2)    ; W = mem[IP] — fetch CFA from thread
;   add r2, 3       ; IP += cell
;   jmp (r0)        ; execute code at CFA
```

### UART I/O
- Data register: address -65280 (0xFF0100)
- Status register: address -65279 (0xFF0101)
- TX busy: bit 7 of status
- RX ready: bit 0 of status
