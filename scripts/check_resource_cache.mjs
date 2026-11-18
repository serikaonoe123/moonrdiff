// Real-data acceptance for the separately resolved public-package application.
import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import * as fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const source = process.argv[2];
assert(source, 'Usage: node scripts/check_resource_cache.mjs MOONFFI_GIT_CHECKOUT');
const revisions = ['23893d5bb3a231a21df10db506d8da821a7e984d', '20b608d6d8546873d5d66786dc8e12642dd70e9c'];
const out = path.join(root, 'results', 'resource-cache-' + randomUUID());
fs.mkdirSync(out, { recursive: true });
const application = path.join(root, 'examples', 'resource-cache');
const sha = data => createHash('sha256').update(data).digest('hex');
const bytes = file => fs.readFileSync(file);
const log = path.join(out, 'commands.log');
function run(program, args, cwd = root, expected = 0) {
  const r = spawnSync(program, args, { cwd, encoding: 'utf8', shell: false, timeout: 120000, maxBuffer: 8 * 1024 * 1024 });
  fs.appendFileSync(log, JSON.stringify([program, ...args]) + '\n' + r.stdout + r.stderr + '\n');
  assert.ifError(r.error);
  assert.equal(r.signal, null);
  assert.equal(r.status, expected, r.stderr);
  return r.stdout;
}
const resolution = JSON.parse(run('moon', ['tree', '--json'], application));
const engine = resolution.modules.filter(m => m.name === 'serikaonoe123/moonrdiff');
assert.equal(engine.length, 1);
assert.equal(engine[0].version, '0.1.2');
assert.equal(engine[0].source.kind, 'registry');
fs.writeFileSync(path.join(out, 'resolution.json'), JSON.stringify(resolution, null, 2));
run('moon', ['fmt', '--check'], application);
run('moon', ['check', '--target', 'js', '--deny-warn'], application);
function app(args, expected = 0) {
  const text = run('moon', ['run', '.', '--target', 'js', '--release', '--', ...args], application, expected);
  if (expected !== 0) assert.equal(text, '', 'failure must not emit success JSON');
  return expected === 0 ? JSON.parse(text) : text;
}
const fixtures = [];
for (const [i, revision] of revisions.entries()) {
  assert.equal(run('git', ['rev-parse', revision + '^{commit}'], source).trim(), revision);
  const names = run('git', ['ls-tree', '-r', '--name-only', revision, '--', 'LICENSE', 'moon.mod', 'core'], source).trim().split('\n');
  assert(names.includes('LICENSE') && names.includes('core/types.mbt'));
  const inventory = names.map(name => {
    const r = spawnSync('git', ['show', revision + ':' + name], { cwd: source, maxBuffer: 2 * 1024 * 1024 });
    assert.equal(r.status, 0);
    return { path: name, bytes: r.stdout.length, sha256: sha(r.stdout) };
  });
  const archive = path.join(out, i ? 'new-source.tar' : 'old-source.tar');
  run('git', ['-c', 'core.autocrlf=false', '-c', 'core.eol=lf', 'archive', '--format=tar', '--mtime=@0', '-o', archive, revision, 'LICENSE', 'moon.mod', 'core'], source);
  fixtures.push({ revision, archive: path.basename(archive), bytes: bytes(archive).length, sha256: sha(bytes(archive)), inventory });
}
const empty = path.join(out, 'empty-cache'); fs.writeFileSync(empty, '');
const target = path.join(out, 'new-source.tar');
const original = path.join(out, 'old-source.tar');
const expectedHash = sha(bytes(target));
const report = {
  schema_version: 1, application: 'independent MoonBit JS resource-cache consumer',
  package: 'serikaonoe123/moonrdiff@0.1.2', resolution: 'registry',
  source_repository: 'https://github.com/serikaonoe123/moonffi-lab',
  source_license: 'MIT; each archive contains its original LICENSE',
  archive_checkout_policy: 'command-local core.autocrlf=false, core.eol=lf',
  source_commit: run('git', ['rev-parse', 'HEAD']).trim(),
  node_version: process.version,
  moon_version: run('moon', ['version', '--all']).trim(),
  git_version: run('git', ['--version']).trim(),
  fixtures, cases: [], controls: [], passed: false,
};
function reject(name, args, output, diagnostic) {
  assert(!fs.existsSync(output));
  app(args, 2);
  const recorded = fs.readFileSync(log, 'utf8');
  assert(recorded.slice(recorded.lastIndexOf('["moon"')).includes(diagnostic), diagnostic);
  assert(!fs.existsSync(output));
  assert.equal(sha(bytes(original)), fixtures[0].sha256);
  report.controls.push({ name, diagnostic, output_absent: true, basis_preserved: true });
}
for (const [name, basis, delivery] of [['historical-update', original, 'delta'], ['empty-cache', empty, 'full']]) {
  const client = path.join(out, name + '-client');
  const publisher = path.join(out, name + '-publisher');
  fs.mkdirSync(client); fs.mkdirSync(publisher);
  const basisPath = path.join(client, 'basis.tar'); fs.copyFileSync(basis, basisPath);
  const clientOffer = path.join(client, 'offer.json');
  app(['offer', basisPath, clientOffer]);
  const serverOffer = path.join(publisher, 'offer.json'); fs.copyFileSync(clientOffer, serverOffer);
  const serverTarget = path.join(publisher, 'target.tar'); fs.copyFileSync(target, serverTarget);
  assert.deepEqual(fs.readdirSync(publisher).sort(), ['offer.json', 'target.tar']);
  const transfer = app(['build', serverOffer, serverTarget, publisher]);
  assert.equal(transfer.delivery, delivery);
  assert.equal(transfer.first_delta_bytes, transfer.offer_bytes + transfer.delta_bytes + transfer.delta_manifest_bytes);
  assert.equal(transfer.direct_full_bytes, transfer.target_bytes + transfer.full_manifest_bytes);
  assert.equal(transfer.delivery === 'delta', transfer.first_delta_bytes < transfer.direct_full_bytes);
  const manifest = path.join(client, 'manifest.json');
  const payload = path.join(client, 'payload.bin');
  fs.copyFileSync(path.join(publisher, 'manifest.json'), manifest);
  fs.copyFileSync(path.join(publisher, 'payload.bin'), payload);
  assert.equal(transfer.actual_exchange_bytes, bytes(clientOffer).length + bytes(manifest).length + bytes(payload).length);
  const restored = path.join(client, 'cache-next.tar');
  const applied = app(['apply', basisPath, manifest, payload, expectedHash, restored]);
  assert(applied.verified);
  assert.deepEqual(bytes(restored), bytes(target));
  assert.deepEqual(bytes(basisPath), bytes(basis));
  report.cases.push({ name, ...transfer, restored_sha256: sha(bytes(restored)), basis_preserved: true, publisher_basis_file_absent: true });
  // Every failed apply gets a distinct output. Keep all evidence on failure.
  const args = output => ['apply', basisPath, manifest, payload, expectedHash, output];
  let output = path.join(client, 'wrong-trust-output');
  reject(name + ':wrong-trust', ['apply', basisPath, manifest, payload, '0'.repeat(64), output], output, 'trusted target identity mismatch');
  const damaged = path.join(client, 'damaged-payload');
  const corrupt = Buffer.from(bytes(payload)); corrupt[0] ^= 1; fs.writeFileSync(damaged, corrupt);
  output = path.join(client, 'corrupt-output');
  reject(name + ':corrupt-payload', ['apply', basisPath, manifest, damaged, expectedHash, output], output, 'payload identity mismatch');
  for (const [control, changes, diagnostic] of [
    ['budget', { target_bytes: 8 * 1024 * 1024 + 1 }, 'invalid manifest or target budget'],
    ['schema', { schema: 99 }, 'invalid manifest or target budget'],
    ['delivery', { delivery: 'unknown' }, 'unknown delivery'],
    ['target-size', { target_bytes: transfer.target_bytes + 1 }, 'restored target identity mismatch'],
    ['target-identity', { target_sha256: '0'.repeat(64) }, 'trusted target identity mismatch'],
  ]) {
    const changed = path.join(client, control + '-manifest.json');
    fs.writeFileSync(changed, JSON.stringify({ ...JSON.parse(bytes(manifest)), ...changes }));
    output = path.join(client, control + '-output');
    reject(name + ':' + control, ['apply', basisPath, changed, payload, expectedHash, output], output, diagnostic);
  }
  if (delivery === 'delta') {
    output = path.join(client, 'wrong-basis-output');
    reject(name + ':wrong-basis', ['apply', empty, manifest, payload, expectedHash, output], output, 'basis identity mismatch');
  }
  const before = sha(bytes(restored)); app(args(restored), 2);
  const existingLog = fs.readFileSync(log, 'utf8');
  assert(existingLog.slice(existingLog.lastIndexOf('["moon"')).includes('EEXIST'));
  assert.equal(sha(bytes(restored)), before);
  report.controls.push({ name: name + ':existing-output', existing_output_preserved: true });
}
assert.equal(sha(bytes(original)), fixtures[0].sha256);
report.passed = true;
fs.writeFileSync(path.join(out, 'report.json'), JSON.stringify(report, null, 2) + '\n');
console.log('Resource cache accepted: 2 real-data cases, ' + report.controls.length + ' rejection controls.');
console.log('Report: ' + path.join(out, 'report.json'));
