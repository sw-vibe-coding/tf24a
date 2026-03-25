; forth.s — tf24a Phase 1: Bootstrap, UART I/O, Stack Tests
; COR24 DTC Forth bootstrap
;
; Register allocation (frozen):
;   r0 = W (work/scratch)
;   r1 = RSP (return stack pointer, grows down from 0x0F0000)
;   r2 = IP (instruction pointer — unused in Phase 1 tests)
;   sp = DSP (data stack, hardware push/pop in EBR)
;   fp = limited scratch (many instructions don't support fp)
;
; UART: data at 0xFF0100 (-65280), status at 0xFF0101 (-65279)
;   TX busy = status bit 7, RX ready = status bit 0

; ============================================================
; Entry point (address 0)
; ============================================================
_start:
    ; sp is set by hardware (EBR at 0xFEEC00)
    la r1, 983040       ; r1 = 0x0F0000 return stack base

    ; ============================================================
    ; Test 1: Data stack + UART — print "OK\n"
    ; Push in reverse order (LIFO), pop and emit in order
    ; ============================================================
    lc r0, 10           ; '\n'
    push r0
    lc r0, 75           ; 'K'
    push r0
    lc r0, 79           ; 'O'
    push r0

    la r2, -65280       ; r2 = UART data (IP not needed in Phase 1)

    ; Emit 'O' — poll TX busy, then write
    pop r0
    push r0             ; save byte while polling
tx1:
    lb r0, 1(r2)        ; status (sign-extended; bit 7 → negative)
    cls r0, z           ; C = (status < 0) = TX busy
    brt tx1
    pop r0              ; restore byte
    sb r0, 0(r2)        ; write to UART

    ; Emit 'K'
    pop r0
    push r0
tx2:
    lb r0, 1(r2)
    cls r0, z
    brt tx2
    pop r0
    sb r0, 0(r2)

    ; Emit '\n'
    pop r0
    push r0
tx3:
    lb r0, 1(r2)
    cls r0, z
    brt tx3
    pop r0
    sb r0, 0(r2)

    ; ============================================================
    ; Test 2: Return stack — push 42, clear r0, pop, emit '*'
    ; ============================================================
    lc r0, 42           ; 42 = ASCII '*'
    add r1, -3          ; RSP -= cell
    sw r0, 0(r1)        ; push to return stack

    lc r0, 0            ; clear r0 to prove round-trip

    lw r0, 0(r1)        ; pop from return stack
    add r1, 3           ; RSP += cell

    ; Emit '*' with TX polling
    push r0
tx4:
    lb r0, 1(r2)
    cls r0, z
    brt tx4
    pop r0
    sb r0, 0(r2)

    ; Emit '\n'
    lc r0, 10
    push r0
tx5:
    lb r0, 1(r2)
    cls r0, z
    brt tx5
    pop r0
    sb r0, 0(r2)

    ; ============================================================
    ; Halt
    ; ============================================================
halt:
    bra halt

; ============================================================
; EMIT ( c -- ) : Write character to UART TX with busy-wait
; Saves byte and IP (r2) on return stack
; ============================================================
do_emit:
    pop r0              ; r0 = character from data stack
    add r1, -3          ; save IP on return stack
    sw r2, 0(r1)
    add r1, -3          ; save byte on return stack
    sw r0, 0(r1)
emit_poll:
    la r0, -65280       ; r0 = UART base
    lb r0, 1(r0)        ; r0 = status (sign-extended; bit 7 → negative)
    cls r0, z           ; C = (status < 0) = TX busy
    brt emit_poll       ; loop while TX busy
    lw r0, 0(r1)        ; restore byte
    add r1, 3
    la r2, -65280       ; r2 = UART base (temporarily clobber IP)
    sb r0, 0(r2)        ; write byte to UART TX
    lw r2, 0(r1)        ; restore IP
    add r1, 3
    ; NEXT
    lw r0, 0(r2)        ; W = mem[IP]
    add r2, 3           ; IP += cell
    jmp (r0)            ; execute next word

; ============================================================
; KEY ( -- c ) : Read character from UART RX with busy-wait
; Saves IP (r2) on return stack
; ============================================================
do_key:
    add r1, -3          ; save IP on return stack
    sw r2, 0(r1)
key_poll:
    la r0, -65280       ; r0 = UART base
    lbu r0, 1(r0)       ; r0 = status byte
    lcu r2, 1           ; r2 = bit 0 mask (RX ready)
    and r0, r2          ; isolate bit 0
    ceq r0, z           ; C = (bit0 == 0) = RX not ready
    brt key_poll        ; loop until RX ready
    la r0, -65280       ; reload UART base
    lbu r0, 0(r0)       ; read byte (acknowledges RX)
    push r0             ; push to data stack
    lw r2, 0(r1)        ; restore IP
    add r1, 3
    ; NEXT
    lw r0, 0(r2)        ; W = mem[IP]
    add r2, 3           ; IP += cell
    jmp (r0)            ; execute next word
