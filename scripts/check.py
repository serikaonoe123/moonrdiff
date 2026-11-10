import subprocess

commands = [
    ['moon', 'version', '--all'],
    ['moon', 'fmt', '--check'],
]
for target in ['js', 'native', 'wasm-gc']:
    commands += [['moon', 'check', '--target', target, '--deny-warn'],
                 ['moon', 'test', '--target', target, '--deny-warn'],
                 ['moon', 'build', '--target', target, '--deny-warn']]
for command in commands:
    print(' '.join(command), flush=True)
    subprocess.run(command, check=True)
