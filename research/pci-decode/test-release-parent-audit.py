"""Compile actual release phases with typed parent collection; RAM-only synthetic inputs."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--clang', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--mismatch', action='store_true')
    parser.add_argument('--mutations', action='store_true')
    args = parser.parse_args()
    out = args.output.resolve()
    if out.exists():
        parser.error('Output must be new')
    out.mkdir(parents=True)
    paths = subprocess.check_output(['git', 'ls-files', '--', 'internal-boot', 'deps', 'research/profile', 'research/pci-decode'],
                                   cwd=ROOT, text=True).splitlines()
    paths += ['internal-boot/boot/release-parent-audit.h', 'internal-boot/boot/release-ownership-audit.h', 'internal-boot/boot/test_release_parent_audit.c',
              'research/pci-decode/test-release-parent-audit.py']
    before = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in sorted(set(paths))}
    data = load('release_audit_data', ROOT / 'research/profile/test_local_topology.py')
    images = load('release_audit_images', ROOT / 'research/profile/test_compatibility.py')
    text = data.synthetic_capture(bus=0x2b, children=1, command=2, no_edid=True)
    admitted = data.analyze(text)
    header = out / 'profile-local.h'
    header.write_text('/* Synthetic RAM model, not LOCAL qualification. */\n'
        '#define GU_LOCAL_PROFILE_GENERATOR 1\n#define GU_PROFILE_NAME "SYNTHETIC-PARENT-AUDIT"\n'
        '#define GU_NVGOP_TEXT_BYTES 0x24426U\n#define GU_NVGOP_TEXT_SHA256 "' +
        hashlib.sha256(bytes(0x24426)).hexdigest() + '"\n' +
        '\n'.join(f'#define {key} {value}' for key, value in admitted['defines']) + '\n', encoding='ascii')
    capture = out / 'capture.txt'
    capture.write_text(text, encoding='ascii')
    nv = out / 'nvgop.bin'
    nv.write_bytes(images.driver_image(0x2be40, 0x280, 0x24426))
    prom = out / 'prom.bin'
    prom.write_bytes(bytes(1048576))
    config = out / 'config.bin'
    config.write_bytes(struct.pack('<64I', *data.configuration(2)))
    platform = out / 'platform-config.h'
    platform.write_text('#define GU_INTERNAL_PARTITION_INITIALIZER {0}\n#define GU_WINDOWS_PARTITION_INITIALIZER {0}\n', encoding='ascii')
    fixture = out / 'replay-fixture.h'

    def run(name, command):
        r = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=90)
        (out / (name + '.log')).write_text(r.stdout + r.stderr, encoding='utf-8')
        if r.returncode:
            raise RuntimeError(name + ': ' + (r.stdout + r.stderr)[-2500:])
        return r.stdout.strip()

    run('fixture', [sys.executable, '-I', str(ROOT / 'internal-boot/boot/make-console-fixture.py'),
        str(capture), '--single-rtx', '--no-igpu', '--no-edid-driver', '--no-edid-child', '--output=' + str(fixture)])
    boot = ROOT / 'internal-boot/boot'
    overlay = out / 'overlay.json'
    overlay.write_text(json.dumps({'version': 0, 'roots': [
        {'type': 'file', 'name': str(path), 'external-contents': str(source), 'use-external-name': False}
        for path, source in [(boot / 'platform-config.h', platform),
            (ROOT / 'internal-boot/unlock/profile-local.h', header), (boot / 'build/r2/replay-fixture.h', fixture)]]}), encoding='utf-8')
    flags = ['-std=c11', '-O1', '-Wall', '-Wextra', '-Werror', '-Wno-unused-function',
        '-D_CRT_SECURE_NO_WARNINGS', '-DGU_PROFILE_LOCAL', '-DGU_HEADLESS_RESEARCH',
        '-DGU_SINGLE_RTX_CONSOLE', '-DGU_FULL_UNLOCK', '-DGU_AUTOMATIC_BOOT',
        '-DGU_RELEASE_PARENT_AUDIT=1', '-DGU_DS_POST_STOP_CAPTURE=1', '-ivfsoverlay', str(overlay),
        '-I' + str(ROOT / 'deps/edk2/MdePkg/Include'), '-I' + str(ROOT / 'deps/edk2/MdePkg/Include/X64')]
    sources = [boot / 'test_release_parent_audit.c', boot / 'console-flow.c',
        *(ROOT / 'internal-boot/unlock' / p for p in ['checks.c', 'sha256.c']),
        *(ROOT / 'research/pci-decode' / p for p in ['efi-capture.c', 'snapshot.c', 'stop-transition.c'])]
    if args.mismatch:
        flags.append('-DGU_RELEASE_MISMATCH_RESEARCH=1')
    exe = out / 'audit.exe'
    run('compile', [args.clang, *flags, *map(str, sources), '-o', str(exe)])
    result = run('run', [str(exe), str(nv), str(prom), str(config)])
    print(result)
    guards = []
    for name, omit, add, diagnostic in [
        ('freestanding', [], ['-ffreestanding'], 'hosted research only'),
        ('audit-zero', ['-DGU_RELEASE_PARENT_AUDIT=1'], ['-DGU_RELEASE_PARENT_AUDIT=0'], 'hosted research only'),
        ('missing-capture', ['-DGU_DS_POST_STOP_CAPTURE=1'], [], 'requires the opt-in post-Stop collector'),
        ('standalone-mismatch', ['-DGU_RELEASE_PARENT_AUDIT=1'], ['-DGU_RELEASE_MISMATCH_RESEARCH=1'], 'requires the host-only parent audit')]:
        guard_flags = [f for f in flags if f not in omit and f != '-DGU_RELEASE_MISMATCH_RESEARCH=1']
        guard = subprocess.run([args.clang, *guard_flags, *add, '-fsyntax-only', str(boot / 'full-release.c')],
                               cwd=ROOT, text=True, capture_output=True, timeout=30)
        (out / (name + '.log')).write_text(guard.stdout + guard.stderr, encoding='utf-8')
        if not guard.returncode or diagnostic not in guard.stderr:
            raise RuntimeError('Expected feature refusal: ' + name)
        guards.append(name)
    mutants = []
    if args.mutations:
        if not args.mismatch:
            parser.error('--mutations requires --mismatch')
        flow = boot / 'full-release.c'
        history = boot / 'release-parent-audit.h'
        ownership = boot / 'release-ownership-audit.h'
        changes = {
            'acquire-after-failed-baseline': (ownership, '!a->OwnershipStarted || !a->OwnerBaselineReady || a->OpenInvoked',
                '!a->OwnershipStarted || a->OpenInvoked'),
            'free-borrowed-parent-handle': (ownership, 'AuditRangeOverlap(p,bytes,a->Devices[i].Pin.Handle,1)', 'FALSE'),
            'free-borrowed-prepared-graph': (ownership,
                '(PreparedGraph && AuditRangeOverlap(p,bytes,PreparedGraph,sizeof(*PreparedGraph)))', 'FALSE'),
            'accept-open-warning': (ownership, 'if(a->OpenStatus!=EFI_SUCCESS)return a->OpenStatus;',
                'if(EFI_ERROR(a->OpenStatus))return a->OpenStatus;'),
            'close-ambiguous-self': (ownership, '*present=own==1 && precise;', '*present=own>=1; (void)precise;'),
            'promote-close-error': (ownership, 'if(a->CloseInvoked && a->CloseStatus!=EFI_SUCCESS)return a->CloseStatus;',
                'if(FALSE)return a->CloseStatus;'),
            'free-owner-proof-before-enable': (ownership,
                'if(s==EFI_SUCCESS && needed)s=a->Devices[0].Attributes(a->ClaimIo,EfiPciIoAttributeOperationEnable,needed,NULL);\n  EFI_STATUS freed=AuditOwnerFree(held);',
                'EFI_STATUS freed=AuditOwnerFree(held);\n  if(s==EFI_SUCCESS && needed)s=a->Devices[0].Attributes(a->ClaimIo,EfiPciIoAttributeOperationEnable,needed,NULL);'),
            'skip-final-parent-comparison': (flow,
                'if(!FinalAuditDevice(&current->Snapshot.Parents[i],&before->Parents[i],\n                        before->Parents[i].Attributes,FALSE,checkCold))',
                'if(FALSE)'),
            'allow-parent-status-clear': (flow,
                'else if(observed->Config[i]!=before->Config[i])return FALSE;',
                'else if(!VerifyConfigWord(i,before->Config[i],observed->Config[i],checkCold))return FALSE;'),
            'skip-recursive-verify-guard': (flow,
                'if(ReleaseAudit.Verifying)return EFI_ALREADY_STARTED;',
                'if(FALSE)return EFI_ALREADY_STARTED;'),
            'overwrite-observed-attributes': (flow, 'Full.TargetAttributes=targetAttributes;',
                'Full.Attributes=targetAttributes;Full.TargetAttributes=targetAttributes;'),
            'skip-effect-binding': (history, 'a->Boot->OpenProtocol!=a->Open', 'FALSE'),
            'skip-active-release-guard': (flow, 'ReleaseAudit.Active || ReleaseAudit.ReleaseUsed', 'ReleaseAudit.ReleaseUsed'),
            'skip-pre-nv-audit': (flow, 'if(s==EFI_SUCCESS)s=ReleaseAuditObserve(FALSE);', '(void)0;'),
            'skip-final-claim-graph': (flow,
                'if(s==EFI_SUCCESS && !FullExpected(&claimGraph,4))s=EFI_NOT_READY;\n#ifdef GU_RELEASE_PARENT_AUDIT\n  if(s==EFI_SUCCESS && !ReleaseAuditBound())s=EFI_NOT_READY;\n  if(s==EFI_SUCCESS)s=AuditOwnershipEnable(needed);',
                'if(FALSE)s=EFI_NOT_READY;\n#ifdef GU_RELEASE_PARENT_AUDIT\n  if(s==EFI_SUCCESS && !ReleaseAuditBound())s=EFI_NOT_READY;\n  if(s==EFI_SUCCESS)s=AuditOwnershipEnable(needed);'),
        }
        roots = json.loads(overlay.read_text(encoding='utf-8'))['roots']
        for name, (source, old, new) in changes.items():
            text_source = source.read_text(encoding='utf-8')
            if text_source.count(old) != 1:
                raise RuntimeError('Mutation anchor changed: ' + name)
            folder = out / name
            folder.mkdir()
            replacement = folder / source.name
            replacement.write_text(text_source.replace(old, new), encoding='utf-8')
            mutant_overlay = folder / 'overlay.json'
            mutant_overlay.write_text(json.dumps({'version': 0, 'roots': roots + [
                {'type': 'file', 'name': str(source), 'external-contents': str(replacement), 'use-external-name': False}]}), encoding='utf-8')
            mutant_exe = folder / 'mutant.exe'
            mutant_flags = [str(mutant_overlay) if f == str(overlay) else f for f in flags]
            run(name + '-compile', [args.clang, *mutant_flags, *map(str, sources), '-o', str(mutant_exe)])
            bad = subprocess.run([str(mutant_exe), str(nv), str(prom), str(config)], cwd=ROOT,
                                 text=True, capture_output=True, timeout=30)
            (folder / 'run.log').write_text(bad.stdout + bad.stderr, encoding='utf-8')
            if bad.returncode != 1 or 'FAIL ' not in bad.stderr:
                raise RuntimeError('Mutant must fail an assertion: ' + name)
            mutants.append(name)
            print(name + ': compiled mutant detected', flush=True)
    if any(hashlib.sha256((ROOT / p).read_bytes()).hexdigest() != sha for p, sha in before.items()):
        raise RuntimeError('Source changed during test')
    (out / 'summary.json').write_text(json.dumps({'passed': True, 'ram_only': True,
        'efi_executed': False, 'mismatch_admission_enabled': args.mismatch, 'host_only': True, 'result': result,
        'compile_refusals': guards, 'compiled_mutations_detected': mutants, 'source_sha256': before}, indent=2), encoding='utf-8')


if __name__ == '__main__':
    main()
