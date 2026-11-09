"""Build/run the RAM-only production logging test on Linux x64. No EFI image."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[3]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cc', default=os.environ.get('CC', 'cc'), help='Installed GCC/Clang compiler')
    parser.add_argument('--sanitize', action='store_true', help='Enable AddressSanitizer and UBSan')
    args = parser.parse_args()
    includes = ['-I' + str(ROOT / 'deps/edk2/MdePkg/Include'),
                '-I' + str(ROOT / 'deps/edk2/MdePkg/Include/X64')]
    source = ROOT / 'internal-boot/unlock/tests/test_log_flush.c'
    common = [args.cc, '-std=c11', '-O1', '-g', '-Wall', '-Wextra', '-Werror',
              '-fshort-wchar', '-ffunction-sections', '-fdata-sections'] + includes
    if args.sanitize:
        common += ['-fsanitize=address,undefined']
    with tempfile.TemporaryDirectory(prefix='gpu-log-flush-host-') as temporary:
        for mode, definitions in (('headless', ['-DGU_HEADLESS_RESEARCH']), ('normal', [])):
            executable = Path(temporary) / mode
            subprocess.run(common + definitions + [str(source), '-Wl,--gc-sections', '-o', str(executable)], check=True)
            subprocess.run([str(executable)], check=True)
        refused = subprocess.run([args.cc, '-std=c11', '-fshort-wchar', '-ffreestanding',
                                  '-fsyntax-only', '-DGU_HEADLESS_RESEARCH'] + includes + [str(source)],
                                 capture_output=True, text=True)
        if refused.returncode == 0 or 'hosted RAM-only test' not in refused.stderr:
            raise RuntimeError('The harness must explicitly refuse freestanding compilation')
    print('PASS: normal/headless host logging and freestanding refusal; no hardware or EFI image.')


if __name__ == '__main__':
    main()
