// Real-data acceptance for the separately resolved public-package application.
import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import * as fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { gzipSync, gunzipSync } from 'node:zlib';

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const source = process.argv[2];
const luaArchives = process.argv[3];
assert(source && process.argv.length <= 4,
  'Usage: node scripts/check_resource_cache.mjs MOONFFI_GIT_CHECKOUT [LUA_ARCHIVE_DIRECTORY]');
const revisions = ['23893d5bb3a231a21df10db506d8da821a7e984d', '20b608d6d8546873d5d66786dc8e12642dd70e9c'];
const out = path.join(root, 'results', 'resource-cache-' + randomUUID());
fs.mkdirSync(out, { recursive: true });
const application = path.join(root, 'examples', 'resource-cache');
const sha = data => createHash('sha256').update(data).digest('hex');
const bytes = file => fs.readFileSync(file);
const log = path.join(out, 'commands.log');
const approvedBytes = bytes(path.join(root, 'packaging', 'candidate-0.1.3.json'));
const approved = JSON.parse(approvedBytes);
// Independent TAR reader: verify the archive, not only Git's source inventory.
function verifyTar(file, inventory) {
  const data = bytes(file), pending = new Map(inventory.map(i => [i.path, i]));
  const string = b => b.toString('utf8').split('\0')[0];
  const octal = b => Number.parseInt(string(b).trim() || '0', 8);
  let offset = 0, ended = false;
  while (offset + 512 <= data.length) {
    const header = data.subarray(offset, offset + 512);
    if (header.every(b => b === 0)) {
      assert(data.subarray(offset).every(b => b === 0)); ended = true; break;
    }
    let checksum = 0;
    for (let i = 0; i < 512; i++) checksum += i >= 148 && i < 156 ? 32 : header[i];
    assert.equal(checksum, octal(header.subarray(148, 156)));
    const name = string(header.subarray(0, 100));
    assert.equal(string(header.subarray(345, 500)), '', 'no long path prefix expected');
    const size = octal(header.subarray(124, 136));
    assert(Number.isSafeInteger(size) && size >= 0 && offset + 512 + size <= data.length);
    assert.equal(octal(header.subarray(136, 148)), 0, 'TAR timestamp must be epoch zero');
    const kind = header[156];
    if (kind === 0 || kind === 48) {
      const item = pending.get(name); assert(item, 'unexpected/duplicate member: ' + name);
      assert.equal(size, item.bytes);
      assert.equal(sha(data.subarray(offset + 512, offset + 512 + size)), item.sha256, name);
      pending.delete(name);
    } else if (kind === 53) {
      assert.equal(name, 'core/'); assert.equal(size, 0);
    } else {
      assert.equal(kind, 103, 'only Git global PAX metadata may accompany files');
    }
    offset += 512 + Math.ceil(size / 512) * 512;
  }
  assert(ended && pending.size === 0, 'incomplete TAR');
}
function run(program, args, cwd = root, expected = 0) {
  const r = spawnSync(program, args, { cwd, encoding: 'utf8', shell: false, timeout: 120000, maxBuffer: 8 * 1024 * 1024 });
  fs.appendFileSync(log, JSON.stringify([program, ...args]) + '\n' + r.stdout + r.stderr + '\n');
  assert.ifError(r.error);
  assert.equal(r.signal, null);
  assert.equal(r.status, expected, r.stderr || r.stdout);
  return r.stdout;
}
const resolution = JSON.parse(run('moon', ['tree', '--json'], application));
const engine = resolution.modules.filter(m => m.name === approved.module);
assert.equal(engine.length, 1);
assert.equal(engine[0].version, approved.version);
assert.equal(engine[0].source.kind, 'registry');
fs.writeFileSync(path.join(out, 'resolution.json'), JSON.stringify(resolution, null, 2));
run('moon', ['fmt', '--check'], application);
run('moon', ['check', '--target', 'js', '--deny-warn'], application);
const installed = path.join(application, '.mooncakes', approved.module);
const approvedPaths = fs.readFileSync(path.join(root, 'packaging', 'files.txt'), 'utf8').trim().split(/\r?\n/);
assert.deepEqual(approved.files.map(item => item.path).sort(), approvedPaths.sort());
for (const item of approved.files) {
  const data = bytes(path.join(installed, item.path));
  assert.equal(data.length, item.bytes, item.path);
  assert.equal(sha(data), item.sha256, item.path);
}
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
  run('git', ['-c', 'core.autocrlf=false', '-c', 'core.eol=lf', 'archive', '--format=tar', '--mtime=1970-01-01T00:00:00Z', '-o', archive, revision, 'LICENSE', 'moon.mod', 'core'], source);
  verifyTar(archive, inventory);
  fixtures.push({ revision, archive: path.basename(archive), bytes: bytes(archive).length, sha256: sha(bytes(archive)), inventory, archive_members_verified: true, archive_mtime: 0 });
}
const empty = path.join(out, 'empty-cache'); fs.writeFileSync(empty, '');
const target = path.join(out, 'new-source.tar');
const original = path.join(out, 'old-source.tar');
function compressedArchive(tar) {
  const data = bytes(tar);
  const file = tar + '.gz';
  fs.writeFileSync(file, gzipSync(data, { level: 9 }));
  assert.deepEqual(gunzipSync(bytes(file)), data);
  return file;
}
const compressedBasis = compressedArchive(original);
const compressedTarget = compressedArchive(target);
const cases = [
  ['historical-update', original, target, 'delta'],
  ['empty-cache', empty, target, 'full'],
  ['gzip-update', compressedBasis, compressedTarget, null],
];
const luaFixtures = [];
if (luaArchives) {
  const luaReleases = [
    ['5.4.7', 374097, '9fbf5e28ef86c69858f6d3d34eccc32e911c1a28b4120ff3e84aaa70cfbf1e30'],
    ['5.4.8', 374332, '4f18ddae154e793e46eeab727c59ef1c0c0c2b744e7b94219710d76f530629ae'],
  ];
  for (const [version, expectedBytes, expectedHash] of luaReleases) {
    const filename = `lua-${version}.tar.gz`;
    const input = path.join(luaArchives, filename);
    assert.equal(fs.statSync(input).size, expectedBytes, filename);
    const gzip = bytes(input);
    assert.equal(gzip.length, expectedBytes, filename);
    assert.equal(sha(gzip), expectedHash, filename);
    const tar = gunzipSync(gzip, { maxOutputLength: 8 * 1024 * 1024 });
    const tarName = filename.slice(0, -3);
    fs.writeFileSync(path.join(out, filename), gzip);
    fs.writeFileSync(path.join(out, tarName), tar);
    luaFixtures.push({
      version, url: `https://www.lua.org/ftp/${filename}`, license: 'https://www.lua.org/license.html',
      gzip: { archive: filename, bytes: gzip.length, sha256: expectedHash },
      tar: { archive: tarName, bytes: tar.length, sha256: sha(tar) },
    });
  }
  const [oldLua, newLua] = luaFixtures;
  cases.push(
    ['lua-gzip-update', path.join(out, oldLua.gzip.archive), path.join(out, newLua.gzip.archive), null],
    ['lua-tar-update', path.join(out, oldLua.tar.archive), path.join(out, newLua.tar.archive), null],
  );
}
const report = {
  schema_version: 5, application: 'independent MoonBit JS resource-cache consumer',
  package: `${approved.module}@${approved.version}`, resolution: 'registry',
  registry_inventory: {
    source_commit: approved.source_commit,
    sha256: sha(approvedBytes),
    files_verified: approved.files.length,
  },
  source_repository: 'https://github.com/serikaonoe123/moonffi-lab',
  source_license: 'MIT; each archive contains its original LICENSE',
  archive_checkout_policy: 'command-local core.autocrlf=false, core.eol=lf',
  archive_backend: 'git-archive-explicit-epoch-v2',
  source_commit: run('git', ['rev-parse', 'HEAD']).trim(),
  node_version: process.version,
  gzip: { level: 9, zlib_version: process.versions.zlib,
    archives: [compressedBasis, compressedTarget].map(file => ({
      archive: path.basename(file), bytes: bytes(file).length, sha256: sha(bytes(file)),
    })) },
  moon_version: run('moon', ['version', '--all']).trim(),
  git_version: run('git', ['--version']).trim(),
  fixtures, lua_fixtures: luaFixtures, cases: [], controls: [], passed: false,
};
function reject(name, args, output, diagnostic) {
  assert(!fs.existsSync(output));
  const basisBefore = sha(bytes(args[1]));
  app(args, 2);
  const recorded = fs.readFileSync(log, 'utf8');
  assert(recorded.slice(recorded.lastIndexOf('["moon"')).includes(diagnostic), diagnostic);
  assert(!fs.existsSync(output));
  assert.equal(sha(bytes(args[1])), basisBefore);
  assert.equal(sha(bytes(original)), fixtures[0].sha256);
  report.controls.push({ name, diagnostic, output_absent: true, basis_preserved: true });
}
for (const [name, basis, targetFile, expectedDelivery] of cases) {
  const expectedHash = sha(bytes(targetFile));
  const commandMs = {};
  const measure = (phase, args) => {
    const started = performance.now();
    const result = app(args);
    commandMs[phase] = Math.round(performance.now() - started);
    return result;
  };
  const client = path.join(out, name + '-client');
  const publisher = path.join(out, name + '-publisher');
  fs.mkdirSync(client); fs.mkdirSync(publisher);
  const basisPath = path.join(client, 'basis.tar'); fs.copyFileSync(basis, basisPath);
  const clientOffer = path.join(client, 'offer.json');
  measure('offer', ['offer', basisPath, clientOffer]);
  const serverOffer = path.join(publisher, 'offer.json'); fs.copyFileSync(clientOffer, serverOffer);
  const serverTarget = path.join(publisher, 'target.tar'); fs.copyFileSync(targetFile, serverTarget);
  assert.deepEqual(fs.readdirSync(publisher).sort(), ['offer.json', 'target.tar']);
  const transfer = measure('build', ['build', serverOffer, serverTarget, publisher]);
  assert.equal(transfer.target_bytes, bytes(targetFile).length);
  assert.equal(transfer.offer_bytes, bytes(clientOffer).length);
  const delivery = transfer.delivery;
  assert.equal(delivery, transfer.first_delta_bytes < transfer.direct_full_bytes ? 'delta' : 'full');
  if (expectedDelivery !== null) assert.equal(delivery, expectedDelivery);
  assert.equal(transfer.first_delta_bytes, transfer.offer_bytes + transfer.delta_bytes + transfer.delta_manifest_bytes);
  assert.equal(transfer.direct_full_bytes, transfer.target_bytes + transfer.full_manifest_bytes);
  const manifest = path.join(client, 'manifest.json');
  const payload = path.join(client, 'payload.bin');
  fs.copyFileSync(path.join(publisher, 'manifest.json'), manifest);
  fs.copyFileSync(path.join(publisher, 'payload.bin'), payload);
  assert.equal(transfer.actual_exchange_bytes, bytes(clientOffer).length + bytes(manifest).length + bytes(payload).length);
  const restored = path.join(client, 'cache-next.tar');
  const applied = measure('apply', ['apply', basisPath, manifest, payload, expectedHash, restored]);
  assert(applied.verified);
  assert.deepEqual(bytes(restored), bytes(targetFile));
  assert.deepEqual(bytes(basisPath), bytes(basis));
  report.cases.push({ name, ...transfer, restored_sha256: sha(bytes(restored)), basis_preserved: true,
    publisher_basis_file_absent: true, moon_run_wall_ms: commandMs });
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
  assert.deepEqual(bytes(basisPath), bytes(basis));
  report.controls.push({ name: name + ':existing-output', existing_output_preserved: true });
}
assert.equal(sha(bytes(original)), fixtures[0].sha256);
report.passed = true;
fs.writeFileSync(path.join(out, 'report.json'), JSON.stringify(report, null, 2) + '\n');
console.log('Resource cache accepted: ' + report.cases.length + ' real-data cases, ' + report.controls.length + ' rejection controls.');
console.log('Report: ' + path.join(out, 'report.json'));
