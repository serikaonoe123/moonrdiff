"""Reproduce source-bundle updates from committed, allowlisted project files.

No network, archive extraction, existing-file overwrite or registry upload.
"""
import argparse
import gzip
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import platform
import subprocess
import tarfile
import uuid
import zipfile
import zlib

ROOT = Path(__file__).resolve().parents[1]
BASIS = 'e09db0b71ef6386f30aa5e5aebd2a2c619013be9'
TARGET = '4013e9ca62b54eb314a0444f902962eebbdd039f'


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def snapshot(ref):
    commit = git('rev-parse', '--verify', ref + '^{commit}').decode().strip()
    paths = git('show', commit + ':packaging/files.txt').decode().splitlines()
    if not paths or len(paths) != len(set(paths)):
        raise ValueError('Snapshot inventory must contain distinct files.')
    files = []
    for name in sorted(paths):
        path = PurePosixPath(name)
        if path.is_absolute() or '..' in path.parts or '\\' in name:
            raise ValueError('Unsupported snapshot path.')
        entry = git('ls-tree', commit, '--', name).decode().split()
        if len(entry) < 3 or entry[0:2] != ['100644', 'blob']:
            raise ValueError('Snapshot inputs must be regular committed files: ' + name)
        files.append((name, git('show', commit + ':' + name)))
    return commit, files


def bundle(files, kind):
    if kind == 'tar.gz':
        return gzip.compress(bundle(files, 'tar'), compresslevel=9, mtime=0)
    output = io.BytesIO()
    if kind == 'tar':
        with tarfile.open(fileobj=output, mode='w', format=tarfile.USTAR_FORMAT) as archive:
            for name, data in files:
                entry = tarfile.TarInfo(name)
                entry.size = len(data)
                entry.mode = 0o644
                entry.mtime = 0
                archive.addfile(entry, io.BytesIO(data))
    else:
        with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED,
                             compresslevel=9) as archive:
            for name, data in files:
                entry = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
                entry.create_system = 3
                entry.external_attr = 0o100644 << 16
                archive.writestr(entry, data, compress_type=zipfile.ZIP_DEFLATED,
                                 compresslevel=9)
    return output.getvalue()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--basis-ref', default=BASIS)
    parser.add_argument('--target-ref', default=TARGET)
    parser.add_argument('--profile', choices=['debug', 'release'], default='release')
    args = parser.parse_args()
    exe = ROOT / f'_build/native/{args.profile}/build/cmd/moonrdiff/moonrdiff.exe'
    if not exe.is_file():
        raise SystemExit('Build the native CLI for the selected profile first.')
    old_commit, old_files = snapshot(args.basis_ref)
    new_commit, new_files = snapshot(args.target_ref)
    out = ROOT / 'results' / ('source-update-' + uuid.uuid4().hex)
    out.mkdir(parents=True)
    report = {
        'status': 'running', 'source_commit': git('rev-parse', 'HEAD').decode().strip(),
        'basis_commit': old_commit, 'target_commit': new_commit,
        'profile': args.profile, 'executable_sha256': digest(exe.read_bytes()),
        'python': platform.python_version(), 'platform': platform.platform(),
        'zlib': zlib.ZLIB_RUNTIME_VERSION,
        'input_files': {
            label: [{'path': name, 'bytes': len(data), 'sha256': digest(data)}
                    for name, data in files]
            for label, files in [('basis', old_files), ('target', new_files)]
        }, 'cases': [],
    }

    def save():
        (out / 'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf8')

    def run(argv, cwd):
        result = subprocess.run([str(exe), *argv], cwd=cwd, capture_output=True,
                                timeout=120)
        with (out / 'commands.log').open('ab') as log:
            log.write((json.dumps(argv) + '\n').encode() + result.stdout + result.stderr + b'\n')
        result.check_returncode()
        return json.loads(result.stdout)

    save()
    try:
        for kind in ['tar', 'zip', 'tar.gz']:
            directory = out / kind
            receiver, sender = directory / 'receiver', directory / 'sender'
            receiver.mkdir(parents=True)
            sender.mkdir()
            old, new = bundle(old_files, kind), bundle(new_files, kind)
            basis, target = receiver / ('old.' + kind), sender / ('new.' + kind)
            basis.write_bytes(old)
            target.write_bytes(new)
            sig, delta = sender / 'basis.sig', sender / 'update.delta'
            manifest, restored = receiver / 'binding.json', receiver / ('restored.' + kind)
            records = [run(['signature', str(basis), str(sig), '--block-size', '2048'], receiver)]
            # The delta invocation receives only signature, target and old size.
            assert {p.name for p in sender.iterdir()} == {target.name, sig.name}
            records.append(run(['delta', sig.name, target.name, delta.name,
                                '--basis-size', str(len(old))], sender))
            records.append(run(['manifest', str(basis), str(target), str(delta), str(manifest)], directory))
            records.append(run(['patch', str(basis), str(delta), str(restored),
                                '--manifest', str(manifest)], receiver))
            records.append(run(['verify', str(target), str(restored)], directory))
            if restored.read_bytes() != new:
                raise AssertionError('Restored bundle differs from target.')
            if basis.read_bytes() != old:
                raise AssertionError('Original bundle changed.')
            first = sig.stat().st_size + delta.stat().st_size + manifest.stat().st_size
            payload = delta.stat().st_size + manifest.stat().st_size
            # A full-file delivery also needs target identity metadata. This
            # sidecar is example-only; both metadata sources must be trusted.
            full_manifest = receiver / 'full-target.json'
            full_manifest.write_text(json.dumps({
                'schema': 'moonrdiff-example-full-v1', 'bytes': len(new),
                'blake2b256': hashlib.blake2b(new, digest_size=32).hexdigest(),
            }, sort_keys=True, separators=(',', ':')) + '\n', encoding='utf8')
            full_cost = len(new) + full_manifest.stat().st_size
            # Offline planning: neither signature nor payload has been sent yet.
            # Ties choose the simpler full-file delivery. This is an example
            # policy, not an automatic transfer feature of the core CLI.
            choice = 'delta' if first < full_cost else 'full'
            if choice == 'full':
                selected = receiver / ('full-delivery.' + kind)
                with selected.open('xb') as stream:
                    stream.write(target.read_bytes())
                identity = json.loads(full_manifest.read_text(encoding='utf8'))
                delivered = selected.read_bytes()
                if (len(delivered) != identity['bytes'] or
                        hashlib.blake2b(delivered, digest_size=32).hexdigest() != identity['blake2b256']):
                    raise AssertionError('Full-file delivery identity mismatch.')
                records.append(run(['verify', str(target), str(selected)], directory))
            else:
                selected = restored
            if selected.read_bytes() != new:
                raise AssertionError('Selected delivery differs from target.')
            after_signature_choice = 'delta' if payload < full_cost else 'full'
            case = {
                'format': kind, 'basis_bytes': len(old), 'target_bytes': len(new),
                'basis_sha256': digest(old), 'target_sha256': digest(new),
                'restored_sha256': digest(restored.read_bytes()),
                'signature_bytes': sig.stat().st_size, 'delta_bytes': delta.stat().st_size,
                'manifest_bytes': manifest.stat().st_size,
                'full_target_manifest_bytes': full_manifest.stat().st_size,
                'full_delivery_bytes': full_cost,
                'first_exchange_bytes': first, 'first_exchange_ratio': first / len(new),
                'delta_plus_manifest_bytes': payload,
                'offline_plan': {
                    'choice': choice,
                    'file_bytes': first if choice == 'delta' else full_cost,
                },
                'signature_reuse_plan': {
                    'choice': after_signature_choice,
                    'remaining_file_bytes': min(payload, full_cost),
                },
                'signature_already_sent_total_bytes': sig.stat().st_size + min(payload, full_cost),
                'selected_result_sha256': digest(selected.read_bytes()),
                'matched': True, 'original_preserved': True,
                'sender_directory_has_no_basis': not (sender / basis.name).exists(),
                'commands': records,
            }
            report['cases'].append(case)
            save()
            print(json.dumps({key: case[key] for key in [
                'format', 'target_bytes', 'first_exchange_bytes', 'first_exchange_ratio',
                'offline_plan', 'signature_reuse_plan', 'matched'
            ]}), flush=True)
        report['status'] = 'success'
        save()
    except Exception as error:
        report['status'] = 'failed'
        report['error'] = str(error)
        save()
        raise
    print(f'Report: {out / "report.json"}')


if __name__ == '__main__':
    main()
