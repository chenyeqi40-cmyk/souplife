# 素材来源与署名

本文件根据项目现有素材记录整理。它保留第三方素材的署名与许可信息，并说明项目中经过修改、裁剪或生成的内容；不对整个游戏、用户提供的参考图或其他项目资产授予新的统一开源许可。

## 录音与厨房拟音

游戏操作声以真实录音为基础剪辑制作。来源是 Freesound 公开提供的高品质 MP3 试听文件，不是本项目重新实录，也不宣称使用原始无损母带。派生文件统一输出为 44.1 kHz 双声道 WAV。

| 原始素材 | 作者与来源 | 本项目相关文件 | 来源许可 |
|---|---|---|---|
| 蛋壳 | [Anthousai](https://freesound.org/people/Anthousai/sounds/336613/) | `egg.wav` | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| 木砧板切洋葱 | [MarleneAyni](https://freesound.org/people/MarleneAyni/sounds/569389/) | `chop1.wav`、`chop2.wav`、`chop3.wav`、`tap.wav` | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| 沸腾 | [aflor](https://freesound.org/people/aflor/sounds/519480/) | `boil.wav` | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| 向金属锅倒水 | [ahriik](https://freesound.org/people/ahriik/sounds/585516/) | `water.wav`、`splash.wav` | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| 雨 | [Duasun](https://freesound.org/people/Duasun/sounds/468025/) | `rain.wav` | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| 金属碗 | [tosha73](https://freesound.org/people/tosha73/sounds/846372/) | `bowl.wav` | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| 包装袋 | [L.i.Z.e.L.l.E_%2B](https://freesound.org/people/L.i.Z.e.L.l.E_%2B/sounds/707734/) | `tear.wav`、`rustle.wav` | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |

本项目对上述录音进行了剪辑、滤波、音量与声像处理，并按用途制作短淡入淡出或循环接缝。切洋葱声用于切肉拟音，包装声用于撕面袋。tosha73 的金属碗素材使用 CC BY 4.0，随素材保留这里的作者、源链接、许可和修改说明。

逐文件片段时间与处理参数见 [`assets/asmr/provenance.json`](../assets/asmr/provenance.json)。立体声声像让砧板稍偏右、锅偏左、培养皿偏右；这是混音设计，不宣称双耳人头录音。

## 项目合成音效与音乐

- `jar.wav`：项目使用软件合成的玻璃共振双音，用于硬币入罐反馈。
- `air_rifle.wav`：项目程序合成的低声气枪反馈，不是实地录音。
- `hearth_road.ogg`《荒路留灯》：24 小节、76 BPM，约 75.79 秒的器乐循环。
- `camp_dawn.ogg`《早饭前的光》：约 93.33 秒循环。
- `camp_lantern.ogg`《灯还为你留着》：约 90 秒循环。
- `hunt_dunes.ogg`《沙坡上的脚步》：约 91.43 秒循环。

按现有制作记录，这四首音乐为本项目程序编曲与软件音色合成，使用拨弦、键盘、低音与铺底等音色，没有使用外部音乐采样，不是真人乐器实录。游戏会按时段和猎场状态切换音乐，并在操作声响起时降低音乐音量。

## 字体

- [`NotoSansSC-Regular.otf`](../assets/fonts/NotoSansSC-Regular.otf)：Noto Sans SC。字体内部版权记录为 **© 2014–2021 Adobe (http://www.adobe.com/)**。
- [`StallSans.otf`](../assets/fonts/StallSans.otf)：从上述 Noto Sans SC 按项目需要裁剪中文字形后重命名为 **Stall Sans**，运行时使用此子集；原字体版权记录保留。
- 两者字体内部均标记 **SIL Open Font License 1.1**；完整许可正文随工程保留于 [`assets/fonts/OFL.txt`](../assets/fonts/OFL.txt)。

Stall Sans 是修改后的字体子集，不是项目从零设计的原始字体。源字体保留在工程中，便于添加新的中文内容后重新生成子集。

## 美术与参考

房车内部和部分公路背景取自用户提供的参考图片，并经过拆分、裁剪与分层。现有制作记录没有为这些用户提供的图片列出额外的第三方作者或统一开源许可；本文件不补造此类授权。

人物、区域、纪念品以及后续厨房和猎场像素资产中，多项使用内置图像生成工具制作，并按项目反馈修改。它们不应被描述为全部手绘或实拍素材。响石岩坡、白盐浅滩、岩兔与泽鸭动作图、对应肉块图均有生成记录；部分图集使用纯洋红背景，由游戏材质抠除。

GLB 文件保留早期 3D 画片布局。最新互动、物件和 UI 部分由 Godot 脚本生成，不能把早期 Blender/GLB 来源标作最新运行画面的完整同步模型。

项目自己的代码、美术、音乐与文本没有在本文件中另行授予开源许可；第三方音频与字体继续适用上面分别列明的来源许可。

## 引擎

项目使用 [Godot Engine](https://godotengine.org/)，引擎许可见 [Godot Engine — License](https://godotengine.org/license/)。引擎的许可与游戏素材的来源许可分别适用。
