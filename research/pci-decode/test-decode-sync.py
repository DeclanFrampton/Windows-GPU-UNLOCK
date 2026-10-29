"""Compile/run a RAM-only experimental cache-sync model; never firmware or GPU code."""
import argparse
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--clang', default='clang')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--mutations', action='store_true', help='Require selected broken guards to fail the host model')
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        parser.error('Output must be a new directory')
    output.mkdir(parents=True)
    executable = output / 'decode-sync-host.exe'
    flags = [args.clang, '-std=c11', '-O1', '-Wall', '-Wextra', '-Werror', '-D_CRT_SECURE_NO_WARNINGS',
             '-I', str(ROOT / 'deps/edk2/MdePkg/Include'), '-I', str(ROOT / 'deps/edk2/MdePkg/Include/X64'), '-I', str(HERE)]
    commands = [
        [*flags, str(HERE / 'test_decode_sync.c'), str(HERE / 'decode-sync.c'), '-o', str(executable)],
        [str(executable)],
    ]
    results = []
    for name, command in zip(('compile', 'run'), commands):
        result = subprocess.run(command, capture_output=True, text=True, cwd=ROOT, timeout=30)
        (output / f'{name}.log').write_text(result.stdout + result.stderr)
        if result.returncode:
            raise RuntimeError(f'{name}: ' + (result.stdout + result.stderr)[-2500:])
        results.append({'stage': name, 'exit': result.returncode})
        if name == 'run':
            print(result.stdout.strip())
    mutations = []
    if args.mutations:
        source = (HERE / 'decode-sync.c').read_text()
        changes = {
            'warning-as-success': [('status!=EFI_SUCCESS', 'EFI_ERROR(status)')],
            'ignore-parent-bus-cycles': [('p->Bus==g->Bus || ', ''), ('p->Bus==s->Parents[j].Bus || ', '')],
            'ignore-late-parent-drift': [('for(UINTN i=0;i<b->ParentCount;i++)if(!DeviceEqual(&a->Parents[i],&b->Parents[i],FALSE))return FALSE;', '')],
            'compare-only-first-config-dword': [('for(UINTN i=0;i<64;i++)if(a->Config[i]!=b->Config[i])return FALSE;',
                                                'if(a->Config[0]!=b->Config[0])return FALSE;')],
            'do-not-record-write-attempt': [('t->Attempted=TRUE;', 't->Attempted=FALSE;')],
            'ignore-final-log-failure': [('if(o.Log(o.Context,"decode-verify-full-snapshot")!=TRUE)return Finish(t,GU_DS_LOG_FAILED);',
                                         '(void)o.Log(o.Context,"decode-verify-full-snapshot");')],
        }
        for name, replacements in changes.items():
            broken = source
            for before, after in replacements:
                if before not in broken:
                    raise RuntimeError(f'Mutation no longer matches: {name}')
                broken = broken.replace(before, after)
            folder = output / name
            folder.mkdir()
            mutated = folder / 'decode-sync.c'
            mutated.write_text(broken)
            binary = folder / 'broken-host.exe'
            compiled = subprocess.run([*flags, str(HERE / 'test_decode_sync.c'), str(mutated), '-o', str(binary)],
                                      capture_output=True, text=True, cwd=ROOT, timeout=30)
            (folder / 'compile.log').write_text(compiled.stdout + compiled.stderr)
            if compiled.returncode:
                raise RuntimeError(f'Mutant must compile before test detection: {name}')
            tested = subprocess.run([str(binary)], capture_output=True, text=True, cwd=ROOT, timeout=30)
            (folder / 'run.log').write_text(tested.stdout + tested.stderr)
            if not tested.returncode:
                raise RuntimeError(f'Host model failed to detect broken guard: {name}')
            mutations.append({'name': name, 'compiled': True, 'detected': True})
        print(f'PASS {len(mutations)} compiled guard mutations detected')
    (output / 'summary.json').write_text(json.dumps({
        'research_only': True, 'hardware_access': False, 'efi_executed': False,
        'shipped_build_wired': False, 'local_evidence_written': False, 'results': results, 'mutations': mutations,
    }, indent=2))


if __name__ == '__main__':
    main()
