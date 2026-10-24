# 彩瓶时光 · 晴光小步

原创轻快BGM提案，112 BPM、4/4、32小节、68.571秒。不是旧曲倍速，不是短循环重复灌长。四段旋律和配器变化，32小节含29种不同音高序列，392个旋律/和声/低音音符事件，另有轻刷沙锤与柔和点拍。全部振荡器/滤波噪声合成，无人声、无外采样、无引用旋律、无付费生成。

## 试听
- preview_first12bars.ogg：前12小节25.714秒，末尾为试听方便淡出；不用于游戏循环。
- caiping_sunlit_steps_112bpm.ogg：完整曲，约734KB，建议运行时使用。
- caiping_sunlit_steps_112bpm.wav：44.1kHz立体声16-bit无损母版。
- loop_seam_audition.wav：最后4秒直接接最初4秒，无交叉淡化掩盖循环缝；用于试听接缝。

## 参数和接线
music_delivery.json含循环采样点、建议初始游戏增益、响度、来源和SHA256。整曲循环[0,3024000)采样帧，不能用秒级定时器重启播放器；用音频引擎原生loop。OGG内也写入LOOPSTART/LOOPEND元数据，但引擎可能忽略，须明确设置。曲子已经温和混音到-22.7 LUFS、true peak -9.4 dBFS；建议先以-3dB游戏增益试听，与倒水音效平衡后调整，勿机械沿用旧版-13dB导致过小。

## 验收边界
已数值确认WAV与OGG解码后皆68.571秒、无削波、近零DC、循环接缝单采样差<0.00013；尾音周期回卷，非尾部截断。validation.json给出详细值。
当前执行环境没有可供本worker真实听音的路径，不能宣称已经听过、好听或无机械感。上述“无爆音/接缝”仅为波形数值检查，最终音色、节奏感、循环听感及手机扬声器平衡须实际试听。独立交付，未替换任何游戏工程或雷霆音乐。

## 重现
已安装Python/numpy及ffmpeg，无本次安装需求：

python3 generate_bgm.py
ffmpeg -y -i caiping_sunlit_steps_112bpm.wav -c:a libvorbis -q:a 5 -metadata LOOPSTART=0 -metadata LOOPEND=3024000 caiping_sunlit_steps_112bpm.ogg
ffmpeg -y -i caiping_sunlit_steps_112bpm.ogg -c:a pcm_s16le decoded_check.wav
python3 validate_delivery.py

generate_bgm.py为原始合成源码，composition.json为完整旋律/和声/事件清单。随机种子固定；所有外发素材hash在music_delivery.json中。
