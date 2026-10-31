#!/usr/bin/env python3
"""Run maintained tests only in a fresh copy; never use actual player profiles."""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess,tempfile,time
p=argparse.ArgumentParser();p.add_argument('--godot',required=True);p.add_argument('--real-clock',action='store_true');p.add_argument('--full-regression',action='store_true');p.add_argument('--output');args=p.parse_args()
repo=Path(__file__).resolve().parents[1]
manifest=json.loads((repo/'docs/current/SYNC_MANIFEST.json').read_text(encoding='utf8'))
out=Path(args.output).resolve() if args.output else Path(tempfile.mkdtemp(prefix='colorpause-current-checks-'))
out.mkdir(parents=True,exist_ok=True);project=out/'project';assert not project.exists(),'Refusing to reuse a previous test tree'
for n,item in manifest['files'].items():
 source=repo/n;assert hashlib.sha256(source.read_bytes()).hexdigest()==item['sha256'],n
 target=project/n;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
for n in ['c3_evidence','native_reward_evidence','direction_review/final','spacing_integration_evidence','closeout_evidence','qa-private','review_settings_energy']:(project/n).mkdir(parents=True,exist_ok=True)
env=os.environ.copy();env['APPDATA']=str(out/'isolated-appdata');env['XDG_DATA_HOME']=str(out/'isolated-data')
flags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0
exe=str(Path(args.godot).resolve());rows=[]
jobs=[('import',None,[],180),('ui_routes','tests/water_sort_orders/integrated_final_views.gd',['--out=res://direction_review/ui'],90),('full50','tests/water_sort_orders/c3_campaign_replay.gd',[],180),('parallel_fifo','tests/water_sort_orders/spacing_parallel_review.gd',['--out=res://direction_review/parallel'],90),('settings_energy','tests/settings_live_energy_regression.gd',[],90),('energy','tests/energy_entry_qa.gd',['--dev-test-ads'],60),('native_failures','tests/water_sort_orders/native_reward_failure_batch.gd',[],90),('native_negative','tests/water_sort_orders/native_reward_negative_batch.gd',[],60)]
if not args.full_regression:
 jobs=[('import',None,[],180),('victory_reward','tests/victory_reward_dependency_review.gd',[],60),('home_binding','tests/current_home_update_review.gd',[],60),('current_energy','tests/current_entry_qa.gd',['--dev-test-ads'],60),('settings_energy','tests/settings_live_energy_regression.gd',[],90)]
if args.real_clock:jobs.append(('real_clock','tests/energy_wallclock_review.gd',[],155))
for name,script,extra,timeout in jobs:
 cmd=[exe,'--headless','--audio-driver','Dummy','--path',str(project)]
 cmd+=['--editor','--import','--quit'] if script is None else ['--script','res://'+script,'--',*extra]
 start=time.monotonic();print('START',name,flush=True)
 with (out/(name+'.log')).open('wb') as f:
  child=subprocess.Popen(cmd,env=env,stdout=f,stderr=subprocess.STDOUT,creationflags=flags)
  try:child.wait(timeout=timeout);timed_out=False
  except subprocess.TimeoutExpired:child.kill();child.wait();timed_out=True
 log=(out/(name+'.log')).read_text(encoding='utf8',errors='replace')
 row={'name':name,'exit':child.returncode,'timeout':timed_out,'seconds':round(time.monotonic()-start,2),'errors':[x for x in log.splitlines() if x.startswith('ERROR:') or 'SCRIPT ERROR:' in x],'tail':log.splitlines()[-1:]}
 rows.append(row);(out/'RESULTS.json').write_text(json.dumps(rows,indent=2));print(json.dumps(row),flush=True)
 if child.returncode or timed_out or row['errors']:raise SystemExit('FAIL: '+name+'; retained evidence '+str(out))
print('PASS; evidence '+str(out),flush=True)
