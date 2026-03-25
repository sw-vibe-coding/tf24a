Instruction reference
MakerLisp COR24 — Assembly Emulator
Assembler
C
Rust
Tutorial
ISA Ref
Help
Blog ↗
Discord ↗
MakerLisp ↗
Examples
Challenges
Program Editor — Blink LED
; Blink LED: Toggle LED D2
; Hover D2 to see duty cycle (~50%)
; Use Step to watch each instruction
; Use Run speed slider to control rate
;
; Try editing nop count to change duty:
;   more ON nops = higher duty cycle
;   more OFF nops = lower duty cycle

        la      r1,-65536   ; LED I/O address

loop:
        lc      r0,1
        sb      r0,0(r1)    ; LED on
        ; --- on-time: 5 instructions ---
        nop
        nop
        nop
        nop
        nop

        lc      r0,0
        sb      r0,0(r1)    ; LED off
        ; --- off-time: 4 instructions + bra ---
        nop
        nop
        nop
        nop
        bra     loop

Assemble
Emulator:
Step

×1
Run
Reset
Run Speed:

100/s
Registers
r0
0x000000
r1
0x000000
r2
0x000000
fp
0x000000
sp
0x000000
z
0
iv
0x000000
ir
0x000000
PC
0x000000
C
0
READY
Instructions: 0
RELEASED
D2
OFF
RX:
type here...
TX:
 
×
ISA Reference
COR24 Instruction Set Reference
C-Oriented RISC, 24-bit. 32 opcodes, 211 instruction forms (1, 2, or 4 bytes). See makerlisp.com for the hardware specification.

CPU State
All registers and addresses are 24 bits wide (values 0 to 16,777,215).

State	Description
PC	Program counter — address of next instruction. Starts at 0.
C	Condition flag — single bit, set by compare instructions (ceq, clu, cls), tested by branches (brt, brf). Also writable via mov ra, c and clu z, ra.
Registers
Register	Name	Width	Purpose
r0		24-bit	General purpose
r1		24-bit	General purpose / return address (jal convention)
r2		24-bit	General purpose
fp		24-bit	Frame pointer — base for stack-frame locals
sp		24-bit	Stack pointer — init 0xFEEC00, grows downward (3 bytes per push)
z		24-bit	Hardwired to zero. Readable in compares: ceq r0, z
iv		24-bit	Interrupt vector — address of interrupt service routine
ir		24-bit	Interrupt return — saved PC when interrupt fires. Return with jmp (ir)
Only r0, r1, r2 can be destinations for most ALU/load instructions. fp can be pushed/popped and used as a memory base register. sp is modified by push, pop, and sub sp.

Load Constants
Instruction	Bytes	Description
lc ra, dd	2	Load signed 8-bit constant (-128..127). Sign-extends to 24 bits.
lcu ra, dd	2	Load unsigned 8-bit constant (0..255). Zero-extends to 24 bits.
la ra, addr	4	Load 24-bit address/constant. Any value 0..16777215.
Arithmetic
Instruction	Bytes	Description
add ra, rb	1	ra = ra + rb
add ra, dd	2	ra = ra + dd (signed 8-bit immediate)
sub ra, rb	1	ra = ra - rb
sub sp, addr	4	sp = sp - addr (24-bit; allocate stack space)
mul ra, rb	1	ra = ra * rb (24-bit result, overflow wraps)
Logic & Shifts
Instruction	Bytes	Description
and ra, rb	1	ra = ra AND rb
or ra, rb	1	ra = ra OR rb
xor ra, rb	1	ra = ra XOR rb
shl ra, rb	1	ra = ra << rb (shift left)
srl ra, rb	1	ra = ra >> rb (shift right, zero fill)
sra ra, rb	1	ra = ra >> rb (shift right, sign fill)
Compare (set C flag)
Instruction	Bytes	Description
ceq ra, rb	1	C = (ra == rb)
clu ra, rb	1	C = (ra < rb) unsigned
cls ra, rb	1	C = (ra < rb) signed
Use z register for zero tests: ceq r0, z sets C if r0 == 0.

Branch (PC-relative, signed 8-bit offset)
Instruction	Bytes	Description
bra label	2	Branch always
brt label	2	Branch if C = true
brf label	2	Branch if C = false
Memory Access (base + signed 8-bit offset)
Instruction	Bytes	Description
lb ra, dd(rb)	2	Load byte, sign-extend to 24 bits
lbu ra, dd(rb)	2	Load byte, zero-extend to 24 bits
lw ra, dd(rb)	2	Load word (3 bytes, little-endian)
sb ra, dd(rb)	2	Store byte (low 8 bits of ra)
sw ra, dd(rb)	2	Store word (3 bytes, little-endian)
Valid base registers: r0, r1, r2, fp. (Not sp — use mov fp, sp then fp.)

Stack
Instruction	Bytes	Description
push ra	1	sp -= 3; store ra at sp (word)
pop ra	1	Load ra from sp; sp += 3 (word)
Can push/pop: r0, r1, r2, fp.

Jump & Call
Instruction	Bytes	Description
jmp (ra)	1	PC = ra (unconditional jump)
jal ra, (rb)	1	ra = return addr; PC = rb (jump and link)
Register Move
Instruction	Bytes	Description
mov ra, rb	1	ra = rb (copy register)
mov ra, c	1	ra = condition flag (0 or 1)
mov iv, ra	1	Set interrupt vector
mov fp, sp	1	Save stack pointer to frame pointer
mov sp, fp	1	Restore stack pointer from frame pointer
Extensions
Instruction	Bytes	Description
sxt ra	1	Sign-extend byte: bits 8..23 = bit 7
zxt ra	1	Zero-extend byte: bits 8..23 = 0
nop	1	No operation (0xFF)
Idioms
Pattern	Meaning
halt:
        bra halt
Halt (branch-to-self; emulator detects this)
        la  r2, func
        jal r1, (r2)
Call function (r1 = return address)
        jmp (r1)
Return from function
        jmp (ir)
Return from interrupt
Interrupts
COR24 supports one interrupt source: UART RX data ready.

Step	Action
Setup	Load ISR address into iv: la r0, isr then mov iv, r0
Enable	Write 1 to interrupt enable register at 0xFF0010
Trigger	When UART receives a byte, CPU saves PC to ir and jumps to iv
ISR body	Save registers (push), read UART data (acknowledges interrupt), process, restore (pop)
Return	jmp (ir) — resumes execution at the interrupted instruction
Interrupts do not nest — a second interrupt cannot fire while an ISR is running. Reading the UART data register at 0xFF0100 acknowledges the interrupt.

Memory Map
Address Range	Region	Notes
000000-0FFFFF	SRAM (1 MB)	Code at low addresses, data/globals above
FEE000-FEFFFF	EBR (8 KB range)	3 KB on MachXO FPGA; used for stack
FEEC00	Initial SP	Top of 3 KB EBR stack
FF0000	LED / Button	Write bit 0 = LED D2. Read bit 0 = button S2
FF0010	Interrupt enable	Write bit 0 = enable UART RX interrupt
FF0100	UART data	Write = TX. Read = RX (acknowledges interrupt)
FF0101	UART status	Bit 7 = TX busy. Bit 1 = RX data ready
Assembly Syntax
; Comments start with semicolon
label:                   ; labels on own line (as24 compatible)
        lc  r0, 42      ; instruction with operands
.local:                  ; local labels start with dot
        bra .local
Numbers: decimal (42) or signed decimal for addresses (la r1, -65536 = 0xFF0000).

MIT License
·
© 2026 Michael A Wright
·
manager
·
36f0d99
·
2026-03-22T23:17:07Z
·
Changes
