"""Compare controlled release measurements, requiring identical fixtures/bytes."""
import json
from pathlib import Path
import statistics
import argparse

parser=argparse.ArgumentParser()
parser.add_argument('--baseline-commit',default='79b18247f0b30438c0474cfe80f60fd406554558')
args=parser.parse_args()

ROOT=Path(__file__).resolve().parents[1]
reports={}
for path in (ROOT/'results').glob('benchmark-*/report.json'):
    data=json.loads(path.read_text(encoding='utf8'))
    if data.get('label') in ['baseline','candidate']:
        assert data['label'] not in reports,'Ambiguous reports: use a fresh results directory.'
        assert data['status']=='success' and not data['generation_only']
        assert data['profile']=='release' and data['repetitions']==3
        reports[data['label']]=(path,data)
assert set(reports)=={'baseline','candidate'}
before=reports['baseline'][1]
after=reports['candidate'][1]
assert before['source_commit']==args.baseline_commit
for field in ['seed','block_size','strong_length','python','platform','cpu','logical_cpus',
              'compiler','reference_version','zlib_compile_version','zlib_runtime_version']:
    assert before[field]==after[field],field

expected={(m,s) for m in [1,16,128] for s in ['identical','modified','insert-delete','random','compressed']}
def index(report):
    records={(x['nominal_mib'],x['scenario']):x for x in report['records']}
    assert len(records)==len(report['records'])==15 and set(records)==expected
    for row in records.values():
        assert row['restores_verified']
        if row['nominal_mib']==128: assert row['default_limit_controls']==[True]*4
        for tool in ['moon','ref']:
            for stage in ['signature','delta','patch']:
                metric=row[f'{tool}_{stage}']
                assert len(metric['samples'])==3
                assert metric['elapsed_seconds']==statistics.median(x['elapsed_seconds'] for x in metric['samples'])
                assert metric['peak_rss_kib']==max(x['peak_rss_kib'] for x in metric['samples'])
    return records
old,new=index(before),index(after)
assert len(before['rejection_diagnostics'])==len(after['rejection_diagnostics'])==20
legacy=args.baseline_commit=='79b18247f0b30438c0474cfe80f60fd406554558'
assert all(x['specific_reason_verified']==(not legacy) for x in before['rejection_diagnostics'])
assert all(x['specific_reason_verified'] for x in after['rejection_diagnostics'])
records=[]
for key in sorted(expected):
    a,b=old[key],new[key]
    for field in ['basis_bytes','target_bytes','basis_sha256','target_sha256','signature_bytes',
                  'signature_sha256','delta_bytes','delta_sha256','first_exchange_bytes']:
        assert a[field]==b[field],(key,field)
    row={'nominal_mib':key[0],'scenario':key[1],'fixture_and_output_hashes_equal':True}
    for stage in ['signature','delta','patch']:
        ma,mb=a['moon_'+stage],b['moon_'+stage]
        row[stage]={'baseline_median_seconds':ma['elapsed_seconds'],
                    'candidate_median_seconds':mb['elapsed_seconds'],
                    'baseline_over_candidate':ma['elapsed_seconds']/mb['elapsed_seconds'] if mb['elapsed_seconds']>0 else None,
                    'baseline_max_rss_kib':ma['peak_rss_kib'],'candidate_max_rss_kib':mb['peak_rss_kib']}
    records.append(row)
report={'schema_version':1,'status':'success','profile':'release','repetitions':3,
        'baseline_commit':before['source_commit'],'candidate_commit':after['source_commit'],
        'baseline_executable_sha256':before['executable_sha256'],
        'candidate_executable_sha256':after['executable_sha256'],
        'rejection_diagnostics':('Historical baseline verifies opaque error constructors; candidate verifies specific budget reasons.' if legacy else 'Both versions verify specific budget reasons.')+' Both require exit 2, empty stdout and no output file.',
        'limitations':'Fixed order on one runner, median of three; no confidence intervals or isolated algorithm ranking. Ratios near timer resolution are not meaningful.',
        'records':records}
path=ROOT/'results/performance-comparison.json'
path.write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
print(f'Comparison passed: {len(records)} matched cases; identical signature/delta hashes; all restores and default-limit controls passed.')
for row in records:
    if row['nominal_mib']==128: print('PERFORMANCE_COMPARISON '+json.dumps(row),flush=True)
