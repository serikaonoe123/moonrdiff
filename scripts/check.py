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
subprocess.run(['python', 'scripts/check_cli.py'], check=True)
subprocess.run(['moon','info'],check=True)
subprocess.run(['git','diff','--exit-code','--','pkg.generated.mbti',
                'third_party/mooncry_blake2/pkg.generated.mbti'],check=True)
