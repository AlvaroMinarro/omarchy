#!/bin/bash

source "$(dirname "$0")/base-test.sh"

TEST_HOME=$(mktemp -d)
trap 'rm -rf "$TEST_HOME"' EXIT

FAKE_BIN="$TEST_HOME/bin"
CURRENT_THEME="$TEST_HOME/.local/state/omarchy/current/theme"
QMK_LOG="$TEST_HOME/qmk.log"
mkdir -p "$FAKE_BIN" "$CURRENT_THEME"

cat >"$FAKE_BIN/omarchy-cmd-present" <<'EOF'
#!/bin/bash
[[ $1 == "qmk_hid" ]]
EOF

cat >"$FAKE_BIN/qmk_hid" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$QMK_LOG"
[[ $2 == "--save" && -n $QMK_SAVE_FAILS ]] && exit 1
[[ $2 == "--rgb-hue" && -n $QMK_HUE_FAILS ]] && exit 1
exit 0
EOF

cat >"$FAKE_BIN/python3" <<'EOF'
#!/bin/bash
echo "python3 started" >>"$QMK_LOG"
exit 1
EOF

chmod +x "$FAKE_BIN"/*

apply_keyboard_color() {
  rm -f "$QMK_LOG"
  QMK_LOG="$QMK_LOG" PATH="$FAKE_BIN:$ROOT/bin:$PATH" HOME="$TEST_HOME" "$ROOT/bin/omarchy-theme-set-keyboard-f16"
}

qmk_calls() {
  [[ -f $QMK_LOG ]] && cat "$QMK_LOG"
}

expected_calls() {
  printf '%s\n' "via --rgb-effect 1" "via --rgb-hue $1" "via --rgb-saturation $2" "via --rgb-brightness 100" "via --save"
}

echo "#7aa2f7" >"$CURRENT_THEME/keyboard.rgb"
apply_keyboard_color
[[ $(qmk_calls) == "$(expected_calls 156 129)" ]] || fail "Framework 16 keyboard gets the theme colour as QMK hue and saturation" "$(qmk_calls)"
pass "Framework 16 keyboard gets the theme colour as QMK hue and saturation"

apply_keyboard_color
[[ -z $(qmk_calls) ]] || fail "Framework 16 keyboard skips a colour it already holds" "$(qmk_calls)"
pass "Framework 16 keyboard skips a colour it already holds"

echo "FF9F0A" >"$CURRENT_THEME/keyboard.rgb"
QMK_SAVE_FAILS=1 apply_keyboard_color
[[ $(qmk_calls) == "$(expected_calls 25 245)" ]] || fail "Framework 16 keyboard gets a changed theme colour" "$(qmk_calls)"
apply_keyboard_color
[[ $(qmk_calls) == "$(expected_calls 25 245)" ]] || fail "Framework 16 keyboard retries a colour it failed to save" "$(qmk_calls)"
pass "Framework 16 keyboard retries a colour it failed to save"

apply_keyboard_color
[[ -z $(qmk_calls) ]] || fail "Framework 16 keyboard skips a saved colour" "$(qmk_calls)"
pass "Framework 16 keyboard skips a saved colour"

echo "#7aa2f7" >"$CURRENT_THEME/keyboard.rgb"
QMK_HUE_FAILS=1 apply_keyboard_color
[[ $(qmk_calls) == "$(expected_calls 156 129)" ]] || fail "Framework 16 keyboard still sends every write when one fails" "$(qmk_calls)"
apply_keyboard_color
[[ $(qmk_calls) == "$(expected_calls 156 129)" ]] || fail "Framework 16 keyboard retries a colour one of its writes missed" "$(qmk_calls)"
pass "Framework 16 keyboard retries a colour one of its writes missed"

# A failed save still changed the live colour, so the earlier record no
# longer describes the keyboard.
echo "#ff9f0a" >"$CURRENT_THEME/keyboard.rgb"
QMK_SAVE_FAILS=1 apply_keyboard_color
echo "#7aa2f7" >"$CURRENT_THEME/keyboard.rgb"
apply_keyboard_color
[[ $(qmk_calls) == "$(expected_calls 156 129)" ]] || fail "Framework 16 keyboard forgets its saved colour once a later write fails" "$(qmk_calls)"
pass "Framework 16 keyboard forgets its saved colour once a later write fails"
