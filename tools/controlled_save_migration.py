"""Reversible file-copy migration candidate. Controlled samples ONLY.

No default user paths, no discovery and no automatic startup integration.
Godot Progress validates the resulting sample with the new/legacy board bindings.
"""
from pathlib import Path
import argparse,hashlib,json,os

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def root_at(value):
    root=Path(value).resolve()
    if not (root/'CONTROLLED_SAMPLES_ONLY').is_file():raise ValueError('Controlled-sample sentinel required')
    return root
def inside(root,value):
    p=(root/value).resolve()
    if p==root or not p.is_relative_to(root):raise ValueError('Path escapes controlled sample root')
    return p
def plan(root,source,target):
    src=inside(root,source);dst=inside(root,target)
    if src==dst or dst.exists():raise ValueError('Target must be separate and absent')
    data=json.loads(src.read_text(encoding='utf8'))
    if data.get('schema')!=2 or data.get('campaign')!='water_sort_orders_v3':raise ValueError('Wrong save family')
    if not isinstance(data.get('pending_attempt'),dict) or not isinstance(data.get('records'),dict):raise ValueError('Malformed save')
    return {'schema':1,'source':source,'target':target,'source_sha256':sha(src),'source_bytes':src.stat().st_size,'mode':'copy_legacy_bytes_keep_digest_for_current_progress_validation','godot_validation_required':True}
def atomic_new(path,data):
    path.parent.mkdir(parents=True,exist_ok=True)
    temp=path.with_name(path.name+'.migration.tmp')
    if path.exists() or temp.exists():raise ValueError('Existing target/temp: inspect previous outcome')
    with temp.open('xb') as f:f.write(data);f.flush();os.fsync(f.fileno())
    # Windows rename is atomic on this same-directory filesystem and fails
    # if the destination exists. Never use replace() or a hard-link privilege.
    try:
        if os.name!='nt':raise NotImplementedError('This controlled candidate is Windows-only')
        os.rename(temp,path)
    finally:
        if temp.exists():temp.unlink()
def apply(root,description):
    src=inside(root,description['source']);dst=inside(root,description['target'])
    if sha(src)!=description['source_sha256']:raise ValueError('Source changed after plan')
    if dst.exists():raise ValueError('Target already exists; no writes')
    payload=src.read_bytes()
    archive=root/'migration_backups'/description['source_sha256']
    saved=archive/'legacy.json'
    if saved.exists():
        if sha(saved)!=description['source_sha256']:raise ValueError('Backup integrity conflict')
    else:atomic_new(saved,payload)
    atomic_new(dst,payload)
    return {**description,'backup':saved.relative_to(root).as_posix(),'target_sha256':sha(dst),'committed':True,'source_preserved':sha(src)==description['source_sha256']}
def rollback(root,receipt):
    dst=inside(root,receipt['target']);src=inside(root,receipt['source']);saved=inside(root,receipt['backup'])
    if dst==src or dst==saved:raise ValueError('Rollback target must be a separate candidate copy')
    if sha(saved)!=receipt['source_sha256'] or sha(src)!=receipt['source_sha256']:raise ValueError('Original/backup changed; no rollback writes')
    if not dst.exists():return {'rolled_back':True,'already_absent':True}
    if sha(dst)!=receipt['target_sha256']:raise ValueError('New save advanced; preserve it and require explicit reconciliation')
    dst.unlink() # Only the hash-verified controlled candidate copy; original never moved.
    return {'rolled_back':True,'original_preserved':True}
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--samples-root',required=True);p.add_argument('action',choices=['plan','apply','rollback']);p.add_argument('--source');p.add_argument('--target');p.add_argument('--json',dest='json_path');a=p.parse_args()
    root=root_at(a.samples_root)
    if a.action=='plan':r=plan(root,a.source,a.target)
    else:
        d=json.loads(inside(root,a.json_path).read_text(encoding='utf8'));r=apply(root,d) if a.action=='apply' else rollback(root,d)
    print(json.dumps(r,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
