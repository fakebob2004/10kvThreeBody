"""Publish a verified replay bundle without touching frozen research outputs."""
import csv
import hashlib
import json
import shutil
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = root / 'artifacts/voc_attribution'
target = Path('/Volumes/MacExtension/Documents/Pf/research/RLsearch/python/rl/'
              'gfm_network_overvoltage_attribution_01/handoff_matlab_voc_20261014')
with (source / 'matlab_parity_summary.csv').open() as f:
    results = list(csv.DictReader(f))
assert len(results) == 3
for row in results:
    assert float(row['shared_sample_max_error']) < 1e-6
    assert abs(float(row['Vpeak_pu'])-float(row['python_Vpeak_pu'])) < 1e-6
with (source / 'simulink_smoke_summary.csv').open() as f:
    assert float(next(csv.DictReader(f))['state_max_error']) < 1e-7
target.mkdir(exist_ok=False)
files = [p for p in source.iterdir() if p.suffix in {'.mat', '.csv', '.png', '.json', '.slx'}]
files += [root/'scripts'/n for n in ['voc_n2_rhs.m', 'voc_n2_simulink_rhs.m',
                                   'README_VOC_REPLAY.md']]
manifest = []
for file in files:
    dest = target/file.name
    shutil.copy2(file, dest)
    manifest.append({'file': file.name, 'sha256': hashlib.sha256(dest.read_bytes()).hexdigest()})
(target/'delivery_manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
print(target)
