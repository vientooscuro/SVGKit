#!/usr/bin/env python3
"""Compile the real Objective-C path parser in Release and check bounded completion."""
from pathlib import Path
import os
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
env = dict(os.environ, DEVELOPER_DIR='/Applications/Xcode26.app/Contents/Developer')
sdk = subprocess.check_output(['xcrun', '--sdk', 'macosx', '--show-sdk-path'], env=env, text=True).strip()
env['SDKROOT'] = sdk
with tempfile.TemporaryDirectory(prefix='svg-path-regressions-') as directory:
    binary = str(Path(directory) / 'parser')
    subprocess.run(['xcrun', 'clang', '-isysroot', sdk, '-O2', '-DNS_BLOCK_ASSERTIONS=1', '-fobjc-arc',
                    '-framework', 'Foundation', '-framework', 'QuartzCore', '-framework', 'CoreGraphics',
                    '-I', str(root / 'Source/Parsers'), '-I', str(root / 'Source/Foundation additions'),
                    '-I', str(root / 'Tests/PathParser'),
                    '-include', str(root / 'Tests/PathParser/Logging.h'),
                    str(root / 'Source/Parsers/SVGKPointsAndPathsParser.m'),
                    str(root / 'Source/Foundation additions/NSCharacterSet+SVGKExtensions.m'),
                    str(root / 'Tests/PathParser/main.m'), '-o', binary], env=env, check=True)
    failures = 0
    for axis in ['horizontal', 'vertical']:
        for variant in ['absolute', 'relative', 'malformed', 'nonfinite', 'trailing']:
            case = f'{axis}-{variant}'
            try:
                result = subprocess.run([binary, case], timeout=0.5, capture_output=True, text=True)
                print(result.stdout + result.stderr, end='')
                failures += result.returncode != 0
            except subprocess.TimeoutExpired:
                print(f'FAIL {case}: parser did not complete within 0.5 seconds')
                failures += 1
    raise SystemExit(1 if failures else 0)
