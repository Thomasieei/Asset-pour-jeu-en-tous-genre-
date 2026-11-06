#!/bin/bash
# Android emulator play-test: install, launch, real touch swipes via adb, screenshots + logcat.
set -x
OUT=emu_shots
mkdir -p $OUT
adb install -r apk/legion-ombre-x86_64.apk
adb logcat -c
adb shell monkey -p com.thomas.legionombre -c android.intent.category.LAUNCHER 1
sleep 50
shot() { adb exec-out screencap -p > $OUT/$1.png; }
shot 01_start
read W H < <(python3 -c "import struct;d=open('$OUT/01_start.png','rb').read(24);print(*struct.unpack('>II',d[16:24]))")
echo "screen ${W}x${H}"
S=$(python3 -c "print($H/720)")
px() { python3 -c "print(int($1))"; }
JX=$(px "170*$S"); JY=$(px "$H-170*$S"); JY2=$(px "$H-170*$S-110*$S")
adb shell input swipe $JX $JY $JX $JY2 4000 &
sleep 2.5; shot 02_joystick_hold
wait
sleep 1; shot 03_after_joystick
AX=$(px "$W-150*$S"); AY=$(px "$H-150*$S")
for i in 1 2 3; do adb shell input tap $AX $AY; sleep 0.25; done
shot 04_attack
CX=$(px "$W*0.62"); CY=$(px "$H*0.45"); CX2=$(px "$W*0.62-250*$S")
adb shell input swipe $CX $CY $CX2 $CY 600
sleep 1; shot 05_camera
MX=$(px "$W-246*$S"); MY=$(px "56*$S")
adb shell input tap $MX $MY
sleep 2; shot 06_menu_ombres
adb logcat -d > $OUT/logcat_full.txt
grep -iE "godot|SCRIPT ERROR|USER ERROR" $OUT/logcat_full.txt | tail -300 > $OUT/logcat_godot.txt
ls -la $OUT
