#!/usr/bin/env bash
# demo.sh — Run tf24a Forth demos
# Usage:
#   ./demo.sh           Run automated demo (non-interactive)
#   ./demo.sh repl      Start interactive REPL
#   ./demo.sh test      Run test suite and check results

set -euo pipefail
FORTH="forth.s"
RUN="cor24-run --run $FORTH --speed 0"

case "${1:-demo}" in
  repl)
    echo "=== tf24a Forth REPL ==="
    echo "Type Forth commands. Ctrl-C to exit."
    echo ""
    cor24-run --run "$FORTH" --terminal --echo --speed 0
    ;;

  test)
    echo "=== tf24a Test Suite ==="
    PASS=0
    FAIL=0

    check() {
      local desc="$1" input="$2" expect="$3"
      local raw result
      raw=$($RUN -u "$input" -n 5000000 2>&1 | grep "^UART output:" -A 20 | tr '\n' ' ')
      # Extract interpreter output: everything after "42 " (boot DOT test)
      result=$(echo "$raw" | sed 's/.*42 //' | sed 's/Executed.*//' | sed 's/  */ /g' | sed 's/^ //;s/ $//')
      expect=$(echo "$expect" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      if [ "$result" = "$expect" ]; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
      else
        echo "  FAIL: $desc"
        echo "    expected: '$expect'"
        echo "    got:      '$result'"
        FAIL=$((FAIL + 1))
      fi
    }

    echo "--- Arithmetic ---"
    check "1 ."           '1 .\n'           '1 ok'
    check "2 3 + ."       '2 3 + .\n'       '5 ok'
    check "-7 ."          '-7 .\n'          '-7 ok'
    check "10 3 - ."      '10 3 - .\n'      '7 ok'

    echo "--- Stack ops ---"
    check "DEPTH (empty)"  'DEPTH .\n'       '0 ok'
    check "1 2 3 DEPTH ."  '1 2 3 DEPTH .\n' '3 ok'
    check "1 2 3 .S"       '1 2 3 .S\n'      '<3> 1 2 3 ok'
    check "DUP"            '5 DUP + .\n'     '10 ok'
    check "SWAP"           '1 2 SWAP . .\n'  '1 2 ok'
    check "OVER"           '1 2 OVER . . .\n' '1 2 1 ok'
    check "DROP"           '1 2 DROP .\n'    '1 ok'

    echo "--- Number base ---"
    check "HEX FF ."       'HEX FF . DECIMAL\n'  'FF ok'
    check "HEX A ."        'HEX A . DECIMAL\n'   'A ok'
    check "DECIMAL 255 ."  '255 .\n'              '255 ok'

    echo "--- LED ---"
    check_led() {
      local desc="$1" input="$2" expect="$3"
      local led
      led=$($RUN -u "$input" -n 5000000 --dump 2>&1 | grep "FF0000 LED" | sed 's/.*0x//' | cut -c1-2)
      if [ "$led" = "$expect" ]; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
      else
        echo "  FAIL: $desc (LED=0x$led, expected 0x$expect)"
        FAIL=$((FAIL + 1))
      fi
    }
    check_led "1 LED!"  '0 LED!\n1 LED!\n'  '01'
    check_led "0 LED!"  '1 LED!\n0 LED!\n'  '00'

    echo "--- Stack stability ---"
    check ".S repeated"     '1 2 3 .S\n.S\n.S\nDEPTH .\n'  '<3> 1 2 3 ok <3> 1 2 3 ok <3> 1 2 3 ok 3 ok'
    check "no REPL leak"    'DEPTH .\nDEPTH .\nDEPTH .\n'   '0 ok 0 ok 0 ok'
    check "no WORDS leak"   'DEPTH .\nWORDS\nDEPTH .\n'     '0 ok WORDS .S DEPTH HEX DECIMAL SPACE CR QUIT INTERPRET NUMBER . LED! IMMEDIATE ; : CREATE WORD FIND ] [ ALLOT C, , BASE STATE LATEST HERE EXECUTE C! C@ ! @ R@ R> >R OVER SWAP DUP DROP 0= < = XOR OR AND - + EXIT KEY EMIT ok 0 ok'

    echo "--- Error handling ---"
    check "unknown word"  'FOO\n'  '? ok'

    echo "--- WORDS ---"
    local_words=$($RUN -u 'WORDS\n' -n 5000000 2>&1 | grep "^UART output:" -A 20 | tr '\n' ' ' | sed 's/.*42 //' | sed 's/Executed.*//')
    if echo "$local_words" | grep -q "EMIT" && echo "$local_words" | grep -q "DUP" && echo "$local_words" | grep -q "LED!"; then
      echo "  PASS: WORDS contains expected entries"
      PASS=$((PASS + 1))
    else
      echo "  FAIL: WORDS output missing expected entries"
      FAIL=$((FAIL + 1))
    fi

    echo ""
    echo "=== Results: $PASS passed, $FAIL failed ==="
    [ "$FAIL" -eq 0 ] && exit 0 || exit 1
    ;;

  demo)
    echo "=== tf24a Forth Demo ==="
    echo ""

    run_line() {
      local input="$1"
      local display="${input//\\n/}"
      local output
      output=$($RUN -u "$input" -n 5000000 2>&1 | grep "^UART output:" -A 20 | tr '\n' ' ' | sed 's/.*42 //' | sed 's/Executed.*//' | sed 's/  */ /g' | sed 's/^ //;s/ $//')
      printf "  %-25s → %s\n" "$display" "$output"
    }

    echo "Arithmetic:"
    run_line '1 .\n'
    run_line '2 3 + .\n'
    run_line '10 3 - .\n'
    run_line '-7 .\n'

    echo ""
    echo "Stack inspection:"
    run_line '1 2 3 .S\n'
    run_line 'DEPTH .\n'
    run_line '1 2 3 DEPTH .\n'

    echo ""
    echo "Hex mode:"
    run_line 'HEX FF . DECIMAL\n'
    run_line 'HEX A0 . DECIMAL\n'

    echo ""
    echo "LED control:"
    led_on=$($RUN -u '1 LED!\n' -n 5000000 --dump 2>&1 | grep "FF0000 LED")
    led_off=$($RUN -u '0 LED!\n' -n 5000000 --dump 2>&1 | grep "FF0000 LED")
    printf "  %-25s → %s\n" "1 LED!" "$(echo "$led_on" | sed 's/.*LED: */LED: /')"
    printf "  %-25s → %s\n" "0 LED!" "$(echo "$led_off" | sed 's/.*LED: */LED: /')"

    echo ""
    echo "Dictionary:"
    words=$($RUN -u 'WORDS\n' -n 5000000 2>&1 | grep "^UART output:" -A 20 | tr '\n' ' ' | sed 's/.*42 //' | sed 's/  ok.*//')
    echo "  WORDS → $words"

    echo ""
    echo "Error handling:"
    run_line 'FOO\n'

    echo ""
    echo "To start an interactive REPL: ./demo.sh repl"
    ;;

  *)
    echo "Usage: ./demo.sh [demo|repl|test]"
    exit 1
    ;;
esac
