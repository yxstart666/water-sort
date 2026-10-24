from pathlib import Path
import json,hashlib,re
R=Path('deliverables/water_sort');O=R/'reference2_production_state_binding_v1';T=R/'reference2_runtime_layouts_v1';source=json.loads((T/'SOURCE_TO_RUNTIME.json').read_text());am=json.loads((T/'ASSET_MAP.json').read_text())['assets'];ev=(O/'LOCAL_SOURCE_EVIDENCE.txt').read_text();states=[]
for ln in ev.splitlines():
 if ln.startswith('| `'):
  cells=[x.strip() for x in ln.strip('|').split('|')];m=re.match(r'`([^`]+)`(.*)',cells[0])
  if m and len(cells)>=3 and len(states)<56:states.append({'state_id':m[1],'description':m[2].strip(),'entry_exit':cells[1],'source_behavior':cells[2],'evidence_class':'original32' if len(states)<32 else 'additional24'})
assert len(states)==56
S={x['state_id']:x for x in states};rows=[]
for m in source:
 p=Path(m['runtime_template']);d=json.loads(p.read_text());n=p.stem.split('__',1)[1];base=re.sub('_(zh|en)$','',n);loc=d['locale'];ids=[];handler=[];gaps=[];status='adapter_required';new=False;entry='Existing entry only';exit='Return to actual existing caller';extra=[]
 if base.startswith('board_'):
  ids=['game','undo'];extra=['selected_source','whole_bottle_locked','whole_lock_receipt_gate','whole_bottle_unlocked','hidden_color_covered','hidden_color_revealed','pour_transaction','full_settle','full_seal','sealed_waiting_order','receipt_queued','receipt_flight','receipt_complete_mark','receipt_replace','order_slot_exhausted'];handler=['order_gameplay_layout.two_rows(total)','bottle_slot(total,index)','order_card(slot,count)','order_anchor','bonus_button','place_art','order_gameplay_assets.UI_SLOTS'];gaps=['940 source to 1080x1920 adapter required; no global scale of existing 941 pause','Production uses one/two rows; candidate13 uses three rows, conditional only until real total mapped','Selected lift candidate16 vs actual22; use actual presentation rule','L3 hidden-color mask missing in candidate state contract; do not substitute L4 lock','Order current white-frame/gold-large-check contract differs ring/check candidate; check transient and exhausted persistent must be separate','Trial bottle and trial slot are independent local_trial flows, not ads']
 elif base=='home':
  ids=['home'];extra=['resume_paid_attempt'];handler=['App.show_home','HomeMenu compositions','App._menu_start'];gaps=['BLOCK candidate logo_en/logo_zh; preserve assets/branding/approved_white_red_blue','Bind Start/Continue from valid paid attempt; retain original digest/checkpoint validation'];entry='Startup or App.show_home';exit='Existing start/continue/levels/records/settings/energy'
 elif base.startswith('levels_'):
  ids=['levels','selector_states'];handler=['scripts/shell/compositions.json','App._menu_start'];gaps=['50 levels / 20 per page; page2 generated, no 51+','Bind completed/current/locked without baked Current or green check from old image','Current level and record fields from actual selector, not QA values']
 elif base.startswith('records_'):
  ids=['ranking_level' if base!='records_overall' else 'ranking_total','ranking_other_origins'];handler=['show_ranking(origin)','App show_page'];gaps=['Default home-only local records; level=continue_index at entry, no arbitrary-level selector','Other origins unreachable by default, do not activate result/game link','Total=sum per-level best times, not global rank'];entry='Home records, level tab by default';exit='Home or existing tab switch'
 elif base=='settings' or base=='pause_with_help':
  ids=['home_settings','audio'] if base=='settings' else ['pause','audio'];extra=['home_language_expanded' if base=='settings' else 'locale_audio_matrix'];handler=['HomeMenu._draw_settings','PauseDialog(home_settings=true)' if base=='settings' else 'PauseDialog.configure(values)','preferences signals'];gaps=['Production pause941x1672 vs source940; explicit coordinate adapter','Candidate pause_with_help adds unreachable game_rules entry: remove/disable that action in production binding','Pause Home caption currently routes to levels; retain actual route and label Choose levels unless owner approves navigation change'];entry='Home gear' if base=='settings' else 'Settings/Escape/playing focus loss';exit='Existing source; pause leaves to levels'
 elif base=='language':
  ids=['pause_language'];extra=['home_language_expanded','locale_audio_matrix'];handler=['PauseDialog.open_language','close_language','cancel'];gaps=['Actual language is expanded dropdown, not automatically a new standalone modal','Outside/Escape closes dropdown first; do not close pause transaction'];exit='Existing settings source with same pause transaction'
 elif base.startswith('help_') or base.startswith('guide_'):
  ids=['home_rules','game_rules'];handler=['show_instructions','OrderHud.tutorial_pointer_center'];status='content_candidate_conditional';gaps=['Full six-step in-game event tutorial not a default existing entry; do not enable new flow','Use home_rules content or API-only game_rules without adding pause button','L3 mask_intro is independent hidden-color explanation; L4 help cannot replace it'];new=True
  if base.startswith('guide_01') or base.startswith('guide_02'):
   ids=['first_guide'];new=False;status='first_guide_adapter_only';entry='Level1 moves=0';exit='First committed pour then normal';gaps=['Bind actual zero-based source3 then target4; no arbitrary visual first/last bottle','After first pour finish actual first_guide, do not chain candidate steps3..6','Use actual glass bounds to position pointer']
  if '_06_lock' in base:extra=['whole_bottle_locked','whole_bottle_unlocked'];gaps.append('Conditional L4 content only; no new automatic L4 tutorial trigger')
 elif base in ['restart_unfinished','replay_settled_enough','replay_settled_insufficient']:
  ids=['restart'];handler=['OrderActionDialog.add_action(id,caption,action)'];gaps=['Map ConfirmRestart/CancelRestart/ResultRestart with existing once lock','Same unfinished attempt no extra debit; settled flow uses actual energy service once'];exit='Original state on cancel; existing restart flow on confirm'
 elif base=='return_home':
  ids=['leave','leave_confirmation'];handler=['prepare_to_leave','App._checkpoint'];status='excluded_no_existing_entry';new=True;gaps=['BLOCK: no exit confirmation exists; direct stable checkpoint and route unchanged','Window close only attempts checkpoint; do not instantiate return_home confirmation']
 elif base in ['result','result_final']:
  ids=['win' if base=='result' else 'final_win'];extra=['win_celebration'];handler=['OrderActionDialog.add_action','App._level_completed','App._settle_pending'];gaps=['Result local-record link candidate has no default production button: do not expose','Presentation never changes ledger or awards; App settles same attempt'];entry='is_solved and all presentation complete';exit='Existing result actions'
  if base=='result_final':gaps+=['BLOCK Choose level replacement: actual actions are ReplayAll, replay last level, Home','Title completed all50, no Next51']
 elif base in ['no_moves','no_moves_no_undo','failure']:
  ids=['stuck'];extra=['stuck_without_undo'] if base=='no_moves_no_undo' else [];handler=['OrderActionDialog.add_action','_has_legal_move'];gaps=['Actual stuck actions include Home and eligible RescueBottle; candidate two-buttons incomplete','Only after transactions finish; cycle deadlock not implemented','BlockedUndo disabled when no history'];
  if base=='failure':status='excluded_unproven_failure';gaps+=['No independent loss state listed; do not create defeat gameplay']
 elif base.startswith('energy_'):
  ids=['energy_full' if base=='energy_full' else 'energy_low','ad_unavailable'];extra=['energy_recovery'];handler=['show_notice','update_energy','App per-second snapshot'];gaps=['No ad claim button binding; disabled artwork not a callable reward flow','Nonfull>=5 supplement title vs <5 insufficient; snapshot unreadable --/30 Energy Unavailable must be distinct'];entry='Energy add or start with <5';exit='Close/later to actual caller'
  if base in ['energy_ready','energy_loading','energy_failed','energy_offline']:status='excluded_no_sdk_network';gaps+=['No SDK playback or network request exists; candidate is future-only, not production route']
  if base=='energy_unavailable':extra+=['energy_unreadable'];gaps+=['Ad unavailable and energy snapshot unreadable are different; current3/30 must never stand in for --/30']
 elif base in ['read_error','save_error','loading']:
  ids=['save_error'];handler=['show_notice','App._checkpoint'];gaps=['Actual errors are dynamic local notices; no network retry page','Only bind existing safe retry/close behavior; do not invent load/reset/cloud action'];
  if base=='loading':status='conditional_loading_visual';gaps+=['No separate loading page listed among production56; only use if actual call site exists']
 elif base=='level_locked':
  ids=['levels','selector_states'];handler=['show_notice'];gaps=['Use actual locked-tile notice; no new unlock or payment flow']
 elif base=='level4_bottle_lock_help':
  ids=['game'];extra=['whole_bottle_locked','whole_lock_receipt_gate','whole_bottle_unlocked'];handler=['can_pour','OrderHud display_delivered'];gaps=['L4 bottle1 unlock after actual first receipt; no hidden-color replacement','Do not add automatic tutorial entry; show only actual lock notice route']
 else:raise ValueError(base)
 # exact asset closure for this template; all effective paths only
 paths=set()
 def walk(v):
  if isinstance(v,dict):
   for z in v.values():walk(z)
  elif isinstance(v,list):
   for z in v:walk(z)
  elif isinstance(v,str) and v.endswith(('.png','.ttf','.otf')):paths.add(v)
 walk(d)
 candidate=Path(m['source']).parent.parent/'qa';shots=[str(x) for x in candidate.glob(n+'*.png')][:4]
 rows.append({'cloud_layout_id':p.stem,'runtime_template':str(p),'runtime_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'fixed_commit':None,'fixed_commit_status':'publisher confirmation pending; local hashes fixed, no guessed commit','original_local_state_ids':ids,'additional_state_ids':extra,'entry':entry,'exit':exit,'locale':loc,'variant':base,'asset_paths_sha256':[{'path':x,'sha256':am[x]['sha256']} for x in sorted(paths)],'source_runtime_handler':handler,'new_business_entry':new,'integration_status':status,'blocking_differences':gaps,'acceptance_screenshot_pair':{'candidate_existing_qa':shots,'local_runtime_acceptance':None,'status':'not executed; candidate QA is not runtime evidence'}})
for s in states:s['mapped_cloud_layout_ids']=[r['cloud_layout_id'] for r in rows if s['state_id'] in r['original_local_state_ids']+r['additional_state_ids']]
(O/'STATE_BINDING_MAP.json').write_text(json.dumps({'evidence_thread':'01a16664-826e-7440-9e3d-5c5169540037','evidence_turn':'01a16b6b-3f9f-77f6-8a1a-017f3d15a14c','evidence_is_source_review_not_gui_acceptance':True,'production_entry':'scenes/water_sort/orders_v3.tscn','production_script':'scripts/water_sort/app_shell.gd','campaign':'water_sort_orders_v3','exclusive_integration_owner':'01a1661d-20ed-7eb2-8d43-64056043204c','templates':rows,'production_states':states},ensure_ascii=False,indent=2));print(len(rows),'templates',len(states),'states','unmapped',[s['state_id'] for s in states if not s['mapped_cloud_layout_ids']])
