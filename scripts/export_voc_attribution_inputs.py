"""Read frozen Pf cases; export an explicit MATLAB handoff without changing research."""
import hashlib
import json
import sys
from pathlib import Path
import numpy as np
from scipy.io import savemat

research = Path('/Volumes/MacExtension/Documents/Pf/research/RLsearch/python')
sys.path.insert(0, str(research))
from rl.gfm_network_overvoltage_attribution_01 import study

out = Path(__file__).resolve().parents[1] / 'artifacts/voc_attribution'
out.mkdir(parents=True, exist_ok=True)
manifest = []
for cid, (b, metadata) in study.pool().items():
    n = study.c.bind_network(b, 3.)
    event = b['event']
    values = dict(x0=np.asarray(b['x0']), edges=np.asarray(b['edges']),
                  load_g=np.asarray(b['load_g']), cap=np.asarray(n.cap),
                  pref=np.asarray(b['refs']['P']), qref=np.asarray(b['refs']['Q']),
                  pm=np.asarray(b['refs']['Pm']), sg_E=float(b['sg_E']),
                  sg_H=float(b['sg_H']), sg_D=float(b['sg_D']),
                  entry=float(event['entry']), clear=float(event['clear']),
                  trip_time=float(event['trip_time']), fault_g=np.asarray(event['fault_g']),
                  trip_mask=np.asarray(event['trip_mask']))
    # Independent pointwise RHS oracle at initial and native clearing states.
    clear_state=np.asarray(study.capture(b, 6.25e-6))
    states=np.stack([np.asarray(b['x0']), clear_state, clear_state])
    times=np.array([0., values['clear']-1e-8, values['clear']])
    values['oracle_states']=states
    values['oracle_times']=times
    values['oracle_rhs']=np.stack([np.asarray(n.rhs(study.j.asarray(x),b['refs'],t,event))
                                   for x,t in zip(states,times)])
    original=study.OUT/cid/'native_6.25e-06.npz'
    with np.load(original) as z:
        values['oracle_post_time']=z['time']
        values['oracle_post_electrical']=z['electrical']
    savemat(out/(cid+'.mat'),values)
    manifest.append(dict(case_id=cid,metadata=metadata,source_npz=str(original),
                         source_sha256=hashlib.sha256(original.read_bytes()).hexdigest()))
(out/'inputs_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('VOC_INPUT_EXPORT_PASS=1',flush=True)
