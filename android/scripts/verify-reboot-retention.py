#!/usr/bin/env python3
"""Test-only storage fixture and full emulator reboot; refuses physical devices."""
import json
import subprocess
import sys
import time
import re
import xml.etree.ElementTree as ET

serial = sys.argv[1]

def adb(*args):
    return subprocess.check_output(['adb', '-s', serial, *args], text=True).strip()

def shell(*args):
    return adb('shell', *args)

assert shell('getprop', 'ro.kernel.qemu') == '1', 'Emulator only'
original = shell('settings', 'get', 'secure', 'default_input_method')
ime = 'com.clipkit.prototype/.ClipKitIme'

def click_text(label):
    shell('uiautomator', 'dump', '/sdcard/clipkit-verification.xml')
    xml = shell('cat', '/sdcard/clipkit-verification.xml')
    for node in ET.fromstring(xml).iter('node'):
        if node.attrib.get('text') == label:
            x1, y1, x2, y2 = map(int, re.findall(r'\d+', node.attrib['bounds']))
            shell('input', 'tap', str((x1+x2)//2), str((y1+y2)//2))
            return
    raise AssertionError('Missing fixture UI: ' + label)
try:
    shell('am', 'force-stop', 'com.clipkit.prototype')
    now = int(shell('date', '+%s')) * 1000
    entries = [dict(text='expired-fixture', capturedAt=now-3*86400000-1000), dict(text='fresh-fixture', capturedAt=now), dict(text='future-fixture', capturedAt=now+86400000)]
    # Shell stdin redirection is test-only run-as, never shipped app behavior.
    payload = json.dumps(entries).encode()
    subprocess.run(['adb', '-s', serial, 'shell', 'run-as com.clipkit.prototype sh -c "cat > files/history.json"'], input=payload, check=True)
    shell('am', 'start', '-n', 'com.clipkit.prototype/.MainActivity')
    time.sleep(2)
    kept = json.loads(shell('run-as', 'com.clipkit.prototype', 'cat', 'files/history.json'))
    assert [e['text'] for e in kept] == ['fresh-fixture']
    print('PASS: device read prunes >3-day and future-dated records (seeded clock-boundary fixture)', flush=True)
    shell('ime', 'enable', ime)
    shell('ime', 'set', ime)
    shell('am', 'start', '-n', 'com.clipkit.fixture/.EditorActivity', '-f', '0x10008000', '--es', 'text', 'hidden-measured')
    time.sleep(2)
    click_text('Test destination')
    time.sleep(2)
    assert 'mInputShown=true' in shell('dumpsys', 'input_method')
    shell('input', 'keyevent', 'BACK')
    time.sleep(2)
    state = shell('dumpsys', 'input_method')
    assert 'mInputShown=false' in state
    click_text('Copy test text')
    time.sleep(2)
    hidden = json.loads(shell('run-as', 'com.clipkit.prototype', 'cat', 'files/history.json'))
    assert any(e['text'] == 'hidden-measured' for e in hidden)
    print('PASS: IME shown true -> false via dumpsys; copy while hidden saved', flush=True)
    # Set a test clip in a separate app before reboot.
    shell('am', 'start', '-n', 'com.clipkit.fixture/.EditorActivity', '-f', '0x10008000', '--es', 'text', 'before-reboot', '--ez', 'autoCopy', 'true')
    time.sleep(2)
    shell('ime', 'enable', ime)
    shell('ime', 'set', ime)
    shell('input', 'tap', '200', '290')
    time.sleep(2)
    before = json.loads(shell('run-as', 'com.clipkit.prototype', 'cat', 'files/history.json'))
    assert any(e['text'] == 'before-reboot' for e in before)
    adb('reboot')
    adb('wait-for-device')
    for _ in range(120):
        if shell('getprop', 'sys.boot_completed') == '1':
            break
        time.sleep(1)
    else:
        raise RuntimeError('Boot timeout')
    shell('input', 'keyevent', '82')
    # boot_completed can precede package/activity resolution readiness on this image.
    for _ in range(30):
        resolved = shell('cmd', 'package', 'resolve-activity', '--brief', '-n', 'com.clipkit.fixture/.EditorActivity')
        if 'com.clipkit.fixture/.EditorActivity' in resolved:
            break
        time.sleep(1)
    else:
        raise RuntimeError('Fixture activity unavailable after boot')
    print('Default IME after reboot: ' + shell('settings', 'get', 'secure', 'default_input_method'), flush=True)
    after = json.loads(shell('run-as', 'com.clipkit.prototype', 'cat', 'files/history.json'))
    assert any(e['text'] == 'before-reboot' for e in after)
    print('PASS: persisted history survives full emulator reboot', flush=True)
    shell('am', 'start', '-n', 'com.clipkit.fixture/.EditorActivity', '-f', '0x10008000', '--es', 'text', 'after-reboot', '--ez', 'autoCopy', 'true')
    time.sleep(3)
    final = json.loads(shell('run-as', 'com.clipkit.prototype', 'cat', 'files/history.json'))
    assert any(e['text'] == 'after-reboot' for e in final)
    print('PASS: copy captured after reboot and editor focus', flush=True)
finally:
    shell('ime', 'set', original)
    print('Restored emulator IME: ' + original, flush=True)
