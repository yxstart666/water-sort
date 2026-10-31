"""Original 32-bar composition for 彩瓶时光. No samples or third-party melody.
Requires installed numpy and ffmpeg; deterministic synthesis seed 23112026.
"""
import numpy as np
import math, wave, json, hashlib, subprocess
from pathlib import Path
P=Path(__file__).resolve().parent
SR=44100; BPM=112; BEAT=60/BPM; BARS=32; N=round(BARS*4*BEAT*SR)
rng=np.random.default_rng(23112026)
mix=np.zeros((N,2),np.float64); events=[]
def add(sound, time, pan=0., gain=1., echo=True):
    start=round(time*SR)
    stereo=np.stack([sound*math.sqrt((1-pan)/2),sound*math.sqrt((1+pan)/2)],axis=1)*gain
    ids=(np.arange(len(sound))+start)%N
    np.add.at(mix,ids,stereo)
    if echo:
        # Two subdued diffuse taps; wrap tails onto start for true periodic render.
        np.add.at(mix,(ids+round(.137*SR))%N,stereo[:,::-1]*.075)
        np.add.at(mix,(ids+round(.231*SR))%N,stereo*.035)
def note(bar, beat, midi, dur, inst='mallet', amp=.12, pan=0.):
    t=np.arange(round(dur*SR))/SR; f=440*2**((midi-69)/12)
    if inst=='mallet':
        y=np.sin(2*np.pi*f*t)*np.exp(-t*6/dur)
        y+=.15*np.sin(2*np.pi*f*2*t)*np.exp(-t*11/dur)
        y+=.035*np.sin(2*np.pi*f*3*t)*np.exp(-t*15/dur)
        attack=.010
    elif inst=='pluck':
        y=(np.sin(2*np.pi*f*t)+.20*np.sin(2*np.pi*2*f*t)+.055*np.sin(2*np.pi*3*f*t))*np.exp(-t*5/dur)
        attack=.013
    elif inst=='keys':
        y=(np.sin(2*np.pi*f*t)+.10*np.sin(2*np.pi*2*f*t))*np.exp(-t*3/dur)
        attack=.035
    else:
        y=(np.sin(2*np.pi*f*t)+.10*np.sin(2*np.pi*2*f*t))*np.exp(-t*2/dur)
        attack=.018
    env=np.minimum(1,t/attack)*np.minimum(1,(dur-t)/.055)
    y*=env*amp*float(rng.uniform(.94,1.04))
    time=(bar*4+beat)*BEAT
    add(y,time,pan)
    events.append([bar+1,beat,midi,inst])
def percussion(bar,beat,kind,amp):
    dur=.10 if kind=='shaker' else .15
    t=np.arange(round(dur*SR))/SR
    if kind=='shaker':
        noise=rng.uniform(-1,1,len(t)); smooth=np.convolve(noise,np.ones(11)/11,mode='same')
        y=(noise-smooth)*np.exp(-t*55)*amp
        # Remove abrasive top band with small moving average, still a soft brush.
        y=np.convolve(y,np.ones(5)/5,mode='same')
    else:
        y=np.sin(2*np.pi*(100*t-24*t*t))*np.exp(-t*32)*amp
    y*=np.minimum(1,t/.007)*np.minimum(1,(dur-t)/.02)
    add(y,(bar*4+beat)*BEAT,.30 if kind=='shaker' else 0,echo=False)
# 32 bars, different harmonic turns per section; C major/A minor color, no tense stabs.
chords=[
 [48,60,64,67],[55,59,62,67],[57,60,64,69],[53,60,65,69],
 [50,57,62,65],[55,59,62,67],[52,59,64,67],[55,59,62,69],
 [48,60,64,67],[52,59,64,67],[57,60,64,69],[53,60,65,69],
 [50,57,62,65],[55,59,62,67],[48,60,64,69],[55,59,62,67],
 [53,60,65,69],[55,59,62,67],[52,59,64,67],[57,60,64,69],
 [50,57,62,65],[53,60,65,69],[55,59,62,69],[55,59,62,67],
 [48,60,64,67],[55,59,62,67],[57,60,64,69],[52,59,64,67],
 [53,60,65,69],[50,57,62,65],[55,59,62,67],[55,59,62,67]]
# Authored phrases, quarter/eighth-note space; distinct bridge and returning variation.
melodies=[
 [76,79,81,79,76],[74,71,74,79],[76,81,79,76,72],[77,76,72,69],
 [74,77,76,74,69],[71,74,79,77],[76,74,71,76],[74,79,76,74],
 [79,76,72,76,79],[76,74,71,67],[72,76,81,79,76],[77,81,79,77],
 [74,69,74,77,76],[74,71,74,79],[76,79,84,81,79],[77,74,71,74],
 [81,79,77,72],[79,77,74,71,74],[79,76,74,71],[76,81,84,81],
 [77,76,74,69,74],[77,81,79,77],[79,81,79,74],[77,74,71,67],
 [76,79,81,84,79],[74,79,77,74],[76,81,79,76,72],[71,74,76,79],
 [77,81,79,77,72],[74,77,76,74],[71,74,79,77,74],[74,71,67]]
for b,ch in enumerate(chords):
    section=b//8
    # Gentle bass pulse, no aggressive kick, and airy off-beat plucks.
    note(b,0,ch[0],.70,'bass',.13,-.08)
    note(b,2.0,ch[0]+(12 if b%4==3 else 0),.52,'bass',.095,-.08)
    if b%4==2: note(b,3.25,ch[0]+7,.30,'bass',.065,-.08)
    for pos,idx in [(0.5,1),(1.5,2),(2.5,3),(3.5,2)]:
        note(b,pos,ch[idx],.43,'pluck',.072 if section!=2 else .050,-.30)
    if b%2==0:
        for pitch in ch[1:]: note(b,0,pitch,.95,'keys',.023,.25)
    rhythm=([0,.75,1.5,2.5,3.25] if len(melodies[b])==5 else
            [.25,1,2,3] if len(melodies[b])==4 else [.5,1.75,3])
    if section==2: rhythm=[x+.125 for x in rhythm]
    for j,(pos,pitch) in enumerate(zip(rhythm,melodies[b])):
        note(b,pos,pitch,.55 if j<len(rhythm)-1 else .72,
             'keys' if section==2 else 'mallet',.125 if section!=2 else .12,.18)
    # Four small response ornaments, not a copy-loop.
    if b in [7,15,23,30]:
        note(b,3.75,72 if b!=23 else 74,.25,'pluck',.047,-.12)
    for pos in [.5,1.5,2.5,3.5]: percussion(b,pos,'shaker',.020)
    for pos in [0,2]: percussion(b,pos,'tap',.018)
# DC removal is periodic; no hard fading at loop seam (tails wrap naturally).
mix-=mix.mean(axis=0)
peak=np.max(np.abs(mix)); mix*=.34/peak
pcm=np.round(mix*32767).astype('<i2')
with wave.open(str(P/'caiping_sunlit_steps_112bpm.wav'),'wb') as w:
    w.setparams((2,2,SR,N,'NONE','not compressed'));w.writeframes(pcm.tobytes())
(P/'composition.json').write_text(json.dumps({'bpm':BPM,'bars':BARS,'meter':'4/4','events':events,'chords':chords,'melodies':melodies},indent=2))
print(json.dumps({'seconds':N/SR,'frames':N,'peak':float(np.max(np.abs(mix))),'dc':mix.mean(axis=0).tolist(),'seam_delta':(mix[0]-mix[-1]).tolist(),'events':len(events)}))
