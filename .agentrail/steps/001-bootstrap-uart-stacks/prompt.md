## Phase 1: Bootstrap, UART I/O, and Stack Primitives

Build the minimal foundation: entry point, register init, UART I/O, and stack operations.

### Deliverable
A single file `forth.s` containing:

1. **Entry point at address 0**: Initialize registers:
   - sp already set by hardware (0xFEEC00)
   - r1 = return stack base (la r1, 0x0F0000 region in SRAM)
   - Load UART addresses into known locations or use inline

2. **EMIT primitive**: Write byte from data stack to UART TX
   - Pop r0 from data stack (pop r0)
   - Poll UART status bit 7 (TX busy) until clear
   - Write r0[7:0] to UART data register
   - Include NEXT tail

3. **KEY primitive**: Read byte from UART RX to data stack
   - Poll UART status bit 0 (RX ready) until set
   - Read byte from UART data register
   - Push r0 to data stack (push r0)
   - Include NEXT tail

4. **Data stack test**: Push literal values and verify via EMIT
   - Push ASCII 'O', 'K', newline onto stack, emit each
   - Should print "OK\n" to UART

5. **Return stack test**: Push/pop to return stack (r1-based)
   - `add r1, -3; sw rX, 0(r1)` to push
   - `lw rX, 0(r1); add r1, 3` to pop
   - Verify round-trip preserves values

### Testing
```bash
# Basic UART output test:
cor24-run --run forth.s --speed 0 --dump
# Should show "OK" in UART output

# Interactive echo test (if time):
cor24-run --run forth.s --terminal --echo --speed 0
```

### Notes
- NEXT is not yet meaningful (no threaded code yet) — just use halt after tests
- Keep code simple and well-commented with ; comments
- Use decimal immediates for all addresses
- Labels on their own lines