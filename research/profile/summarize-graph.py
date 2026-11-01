"""Summarize existing graph logs; no hardware access or raw device/file paths."""
import hashlib
import json
from pathlib import Path
import re
import sys

KEYS = {
    'console': {'out', 'error', 'input'}, 'handle': {'id'},
    'opens': {'status', 'count'}, 'open': {'agent', 'controller', 'attributes', 'count'},
    'driver': {'image', 'binding', 'version', 'stop-address'},
    'image': {'parent', 'device', 'base', 'size', 'code-type'},
    'gop': {'framebuffer', 'bytes', 'mode', 'max-mode', 'width', 'height', 'stride', 'pixel-format', 'info-bytes'},
    'pci': {'location-status', 'segment', 'bus', 'device', 'function', 'config-status'},
}


# Fixed diagnostic labels only: never copy arbitrary reason strings or paths.
REASONS = {
    'path-node-length', 'path-end', 'path-trailing-data', 'path-limit-or-missing-end',
    'variable-size', 'variable-allocate', 'variable-read', 'variable-free',
    'interface-read', 'gop-null-mode', 'gop-info', 'pci-location', 'pci-read',
    'handle-snapshot', 'protocol-snapshot', 'protocol-null-guid', 'open-snapshot',
    'handle-snapshot-changed', 'handle-identity-changed', 'opens-free',
    'protocols-free', 'after-free', 'handles-free',
}


def summarize(data):
    if len(data) > 8 * 1024 * 1024:
        raise ValueError('Log too large')
    text = data.decode('utf-8-sig').replace('\r\n', '\n')
    records = []
    for line in text.splitlines():
        if re.fullmatch(r'pci config-dwords=(?:[0-9a-f]{8} ){16}', line):
            records.append(line.rstrip())
            continue
        prefix, _, fields = line.partition(' ')
        if prefix in KEYS and fields:
            parts = fields.split(' ')
            if all(re.fullmatch(r'[a-z-]+=0x[0-9a-f]{1,16}', p) and
                   p.split('=', 1)[0] in KEYS[prefix] for p in parts):
                records.append(line)
        elif re.fullmatch(r'protocol guid=[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', line):
            records.append(line)
    if len(records) > 100000:
        raise ValueError('Too many records')
    reasons = [
        {'reason': reason, 'status': status}
        for reason, status in re.findall(
            r'^incomplete reason=([a-z-]+) status=(0x[0-9a-f]{16})$', text, re.M)
        if reason in REASONS
    ]
    reason_count = len(re.findall(r'^incomplete reason=', text, re.M))
    return {
        'sha256': hashlib.sha256(data).hexdigest(),
        'graph_only_marker': text.count('capture-scope=graph-only no-gpu-mmio no-prom no-image-dump') == 1,
        'complete_markers': re.findall(r'^capture-complete=([01])$', text, re.M),
        'diagnostic_statuses': re.findall(r'^diagnostic-result status=(0x[0-9a-f]{16})$', text, re.M),
        'incomplete_reason_count': reason_count,
        'incomplete_reasons': reasons,
        'unexported_reason_count': reason_count - len(reasons),
        'records': records,
    }


def main():
    folder, output = map(Path, sys.argv[1:])
    paths = sorted(folder.glob('DIAG[0-9][0-9].TXT'))
    if not 1 <= len(paths) <= 4:
        raise ValueError('Need 1 to 4 existing DIAG logs; no new boot requested')
    reports = []
    for path in paths:
        with path.open('rb') as stream:
            data = stream.read(8 * 1024 * 1024 + 1)
        reports.append({'capture': path.name, **summarize(data)})
    output.write_text(json.dumps({'test': 'graph-only-v2', 'hardware_verified': False,
                                 'write_eligible': False, 'captures': reports}, indent=2), encoding='utf-8')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, UnicodeError):
        print('Graph summary could not finish. Keep original files local; report this message.', file=sys.stderr)
        sys.exit(1)
