# Linuxでの制御部の動作確認

docs/0003-windows-driverで確定した制御プロトコルを、Linux標準のusbhidとhidrawだけで再現できるかを確かめる。環境はdocs/0001-ubuntu-vmの検証VMで、本機はパススルーしたRenesasコントローラー配下のバス3にあり、HIDインターフェイス（インターフェイス3）はhid-genericが`/dev/hidraw1`として公開している（docs/0002-device-enumeration）。ゲストでの実行は`../0001-ubuntu-vm/scripts/guest-exec.sh`で行い、スクリプトはbase64でゲストの`/tmp/`に置いてから引数を付けて起動する。

## 方法

hidrawのwriteは先頭バイトをレポートIDとして扱い、本機のようにレポートIDを使わないデバイスでは、先頭に0x00を付けて書くとカーネルがその1バイトを除いた残りをインタラプトOUT（EP 0x04）へ送る。したがって`00 04 01`を送るには`00 00 04 01`の4バイトを書く。readはインタラプトIN（EP 0x83）のレポートをそのまま返す。GET_REPORTはhidrawのioctl HIDIOCGINPUTで発行する。

| スクリプト | 役割 |
| --- | --- |
| hid-control-stream.py | コマンド（既定は`00 04 01`）を書き、指定秒数のあいだレポートを読んで、内容が変わったものだけを時刻付きで出力する |
| hid-experiment.py | 実験の型を引数で選ぶ。`read-only`はコマンドを送らずに読む、`enable`は`00 04 01`を送って読む、`command`は引数のコマンドを順に送って応答とGET_REPORTを記録する、`getreport`はGET_REPORTを繰り返す、`watch`は0.5秒ごとに最新のレポートとGET_REPORTを並べて出す |
| mixer-watch.sh | ALSAミキサーの値を一定間隔で読み、変化があったときだけ出す |
| tone-wav.py | 両チャンネルに同じ正弦波を入れたWAVを書き出す（音量の聴取用） |
| analyze-stream-log.py | hid-control-stream.pyの記録から、スイッチ・ペダル・ノブの値域とフラグの出現を要約する |
| hid-to-midi.py | レポートの6つの入力（内蔵ペダル・スイッチ・ノブ、外部ペダル・スイッチ2つ）をMIDIのコントロールチェンジに変換し、ALSAのrawmidiデバイス（既定はsnd-virmidiの仮想カードを`/proc/asound/cards`から探す。`--midi`で指定できる）へ書く。値が変わったときだけ送る。`--channel`（既定1）、`--seconds`（0で無期限）、`--verbose`（送ったCCを表示）を持つ |

`raw/`の各ファイルは、これらをゲストで実行した出力である。

| ファイル | 内容 |
| --- | --- |
| hid-control-stream-operate.log | 有効化後の120秒間に、ペダルの往復、スイッチ2回、ノブの往復を行った記録 |
| exp-a1-persistence.log | hidrawを閉じて開き直し、コマンドを送らずに読んだ結果 |
| exp-a2-reenumeration.log | sysfsの`authorized`で再列挙した後に、コマンドを送らずに読んだ結果と、再送した結果 |
| exp-b-samplerate.log | 再生を44100Hz、32000Hz、48000Hzで開いた状態でのGET_REPORT |
| exp-c-commands.log | `00 02 00 00`、`00 02 00 02`、`00 07 03`を順に送った応答とGET_REPORT |
| exp-d-alsa.log | 3つの周波数での2秒間の録音 |
| exp-e-stop-start.log | `00 04 00`と`00 04 01`を順に送った応答 |
| exp-f-mixer.log | ミキサーの読み出しと、再生の記録 |
| exp-g-coexist.log | 録音と再生を同時に行いながらレポートを読んだ結果 |
| exp-h-midi-bridge.log | hid-to-midi.pyを5秒間動かし、仮想MIDIポートをaseqdumpで受けた結果 |
| exp-i-interval-and-bridge-60s.log | 静止中のレポート間隔の統計と、hid-to-midi.pyを60秒間動かしたときのCPU使用率 |
| exp-j-udev.log | udevルールを入れた後のhidrawノードの所有者・ACLと、一般ユーザーでの読み出し |
| exp-k-guest-reboot.log | ゲストを再起動した直後に、コマンドを送らずに読んだ結果 |
| exp-l-boot-virmidi.log | 起動時にsnd-virmidiを読み込む設定を入れて再起動した後のカード構成と、橋渡しの自動検出の結果 |
| exp-m-stop-persistence.log | `00 04 00`で止めた後に、`authorized`での再列挙とゲストの再起動のそれぞれの直後にコマンドを送らずに読んだ結果と、`00 04 01`で再開した結果 |
| exp-n-led-and-volume.log | テスト音を流しながら、ノブ操作中のミキサー値の監視と、0x07・0x04・0x02の各コマンドを送った前後のレポートとGET_REPORT（LEDと音量は本体で目視・聴取） |
| exp-o-volume-source.log | `00 07 01`と`00 07 02`を送り、内蔵ペダル・外部ペダル・ノブを動かしながらレポートとGET_REPORTを並べて記録した結果 |
| exp-p-bridge-external.log | BOSS FS-7とM-Audio EX-Pを接続してhid-to-midi.pyを60秒間動かし、外部スイッチ2つ、外部ペダル、内蔵スイッチ、内蔵ペダルを操作したときの送出と、aseqdumpでの受信 |
| exp-q-bridge-defaults.log | 両ペダルを爪先側にした状態で、hid-to-midi.pyを既定の両端（0x00と0xFF）と測った両端を渡した場合のそれぞれで2秒間動かしたときの起動時の値 |

`udev/`と`etc/`には、ゲストの`/etc/`に置く設定ファイルがある（「一般ユーザーからの利用」と「仮想MIDIポートへの橋渡し」）。

## 有効化と送出

`00 04 01`を書くと、本機は1バイトの`80`と10バイトのレポートを返し始める。5秒間で1,244件、つまり約4ms間隔で、HIDインターフェイスのbInterval（4ms）どおりに届く。Windowsの記録では静止中16ms間隔だったので、送出間隔はホスト側の読み出し方で変わる。

```shellsession
$ docs/0001-ubuntu-vm/scripts/guest-python.sh docs/0004-linux-control/scripts/hid-control-stream.py
   0.002 write 00 04 01 (4 bytes incl. report id)
   0.007 report #1 len=10 81 02 80 f0 6a 00 f2 02 00 00
   0.007 report #2 len=1 80
   0.009 report #3 len=10 81 02 80 f0 74 00 f2 02 00 00
   4.101 report #1020 len=10 81 02 81 00 02 00 f2 02 00 00
   4.105 report #1021 len=10 81 02 80 00 05 00 f2 02 00 00
   5.001 end: 1244 reports
```

`00 04 00`を書くと、本機は`80`を返して送出を止める。もう一度`00 04 01`を書けば再開する。コマンド0x04の末尾バイトは送出の有無である。

静止中の送出間隔を10秒間（2,492件）で測ると、中央値4.00ms、90パーセンタイル4.09ms、99パーセンタイル4.12ms、最大8.07msだった（`raw/exp-i-interval-and-bridge-60s.log`）。

## 操作とバイト配置

120秒間の記録（`raw/hid-control-stream-operate.log`）で、ペダルの往復、スイッチ2回、ノブの往復を行った。`scripts/analyze-stream-log.py`で要約すると、バイトの配置はWindowsの記録と一致する。

| バイト | 内容 | この記録での値 |
| --- | --- | --- |
| [2] | 変化フラグ | スイッチの押下と解放の直後に0x88、ペダルとノブの移動中に0x84、カウンタが0x4000の倍数を跨いだ直後のレポートでbit0が立つ（約16.8秒ごと。この記録ではカウンタ0x8003、0xC001、0x0002、0x4003、0x8001、0xC005、0x0000の時点） |
| [5] | スイッチのビット集合。bit0は内蔵スイッチ、bit1は外部フットスイッチ1（Tip）、bit2は外部フットスイッチ2（Ring）（docs/0003-windows-driver） | 内蔵スイッチの2回の踏み込み（27.4秒、28.7秒）で0x01 |
| [6] | ペダル位置（8ビット）。踵が0x08付近、爪先が0xF2付近 | 0x07〜0xF2。記録の終了時は踵側で0x08 |
| [8] | ノブ位置（8ビット） | 0x00〜0xF6 |
| [9] | ノブ位置（7ビット） | 0x00〜0x7F |

[0]は0x81、[1]は0x02で固定、[3]〜[4]は約1msごとに1増えるカウンタである。[7]は外部エクスプレッションペダルの位置（8ビット、踵側が小さい）で、未接続のこの記録では0x02である（docs/0003-windows-driver）。

## 送出状態の持続

コマンド0x04で設定した送出の有無は本機側に保持され、ホスト側の開閉や再列挙では変わらない。送出を切り替えるのはコマンド0x04だけで、電源断は設定を既定の停止に戻す。

送出中の状態では、hidrawを閉じて開き直しても、コマンドを送らずにレポートが届く（3秒間で744件）。sysfsの`authorized`を0にしてから1に戻して再列挙させても、hid-genericが付け直した直後からコマンド無しでレポートが届く（746件、`raw/exp-a2-reenumeration.log`）。ゲストを再起動してVFIOがコントローラーをリセットし、USBバスのリセットから列挙をやり直した後も同じで、起動直後にコマンド無しで届く（705件、`raw/exp-k-guest-reboot.log`）。

停止中の状態も同様に保持される。`00 04 00`で止めた後に`authorized`で再列挙しても、ゲストを再起動しても、コマンドを送らない限りレポートは届かない（どちらも3秒間で0件、`raw/exp-m-stop-persistence.log`）。

電源投入直後の状態は停止である。Windowsでの抜き差しの記録では、再列挙後にアプリが`00 04 01`を送るまで送出が無かった（docs/0003-windows-driver）。

## GET_REPORTの24バイト

先頭3バイトは現在のサンプリング周波数のリトルエンディアン表現である。再生を44100Hzで開くと`44 ac 00`、32000Hzで`00 7d 00`、48000Hzで`80 bb 00`になり、再生を止めても最後の値が残る。

バイト[20]は最後に受け取ったコマンドの長さと一致する。3バイトのコマンド（0x04、0x07）の後は3、4バイトのコマンド（0x02）の後は4になる。バイト[21]と[22]は本機が出力に適用している左右の音量（0x00〜0x7F）で、入力元はコマンド0x07で決まる。電源投入後にコマンドを受けていない状態では内蔵ペダルに追従し（docs/0002-device-enumeration）、0x07を1〜3で送った後はノブの7ビット値（レポートの[9]）に追従し、0で送った後は最後の値のまま止まる（`raw/exp-n-led-and-volume.log`、`raw/exp-o-volume-source.log`）。送出の有無とは独立で、UACのミキサー（PCM Playback Volume）の値はノブを回しても変わらない。

## コマンド0x02（LED）と0x07（ノブの音量）

どちらのコマンドもレポートの送出間隔と内容に影響せず、本機からの応答は無い。本体を見聞きしながら確かめた記録が`raw/exp-n-led-and-volume.log`と`raw/exp-o-volume-source.log`である。

コマンド0x02はLEDの点灯を設定する。`00 02 00 <mask>`のmaskはビット集合で、bit0（0x01）が黄、bit1（0x02）が緑、bit2（0x04）が赤である。0で全消灯、7で3色点灯になる。3番目のバイトは0でなければならず、1にしたコマンドは無視される。電源投入直後は緑が点灯しており、Windowsのアプリは起動時に`00 02 00 00`（全消灯）に続けて`00 02 00 02`（緑）を送る。送出の開始と停止（0x04）はLEDに影響しない。

コマンド0x07は出力音量の入力元を設定し、Windowsのアプリの設定「StealthPedal Volume」に対応する。電源投入後にコマンドを受けていない状態では内蔵ペダルが入力元で、本機はボリュームペダルとして働く（docs/0002-device-enumeration）。`00 07 00`で入力元が無くなり、音量は直前の値に固定されてノブを回しても変わらない。末尾が1、2、3のいずれでも入力元はノブになり、その時点のノブの位置が音量に適用され、以後ノブに追従する（1、2、3の間に違いは観察されなかった。アプリは3を使う。4以上の値は未確認）。入力元がノブのとき、GET_REPORTのバイト[21][22]はノブの7ビット値と一致し、内蔵ペダルと外部ペダルを動かしても変わらない（`raw/exp-o-volume-source.log`）。この設定は送出の有無と独立に働き、送出を止めた状態でもノブで音量が変わることを聴取で確認した。

Windowsのアプリは`00 04 01`、`00 02 00 00`、`00 02 00 02`、`00 07 03`の4件をCONTROLがONになるたびに送る。OFFにしたときとアプリの終了時には何も送らず、読み出しを止めるだけである（docs/0003-windows-driverの「制御プロトコル」）。Linux側でも、送出を始めるときにこの4件をまとめて送れば、アプリと同じ状態に本機を置ける。

## オーディオとの同時動作

録音と再生を48000Hzで同時に行いながらレポートを読んでも、レポートは4秒間で798件届き、6秒間の録音は1,728,000バイト（48000×2ch×3バイト×6秒）で欠けが無く、カーネルログにエラーは無い。制御の転送はオーディオのアイソクロナス転送と独立している。

録音は32000Hz、44100Hz、48000Hzのいずれでも指定どおりのバイト数が得られ、再生も3つの周波数で動く。周波数を切り替えた直後に、カーネルは`usb 3-1: current rate 48000 is different from the runtime rate 44100`のように、設定前の周波数が読み返されたことを記録するが、再生中のGET_REPORTは新しい周波数を示し、録音のバイト数も正しい。ミキサーは`amixer -c StealthPedal cset numid=3 12,12`のようにnumid指定で読み書きできる（numid=3が入力ゲイン、4が出力ミュート、5が出力ボリューム）。

## 仮想MIDIポートへの橋渡し

Windowsでは、StealthPedal MIDI Controlが制御データをMIDIに変換して仮想MIDIポートへ流していた。Linuxでは、snd-virmidiが作る仮想MIDIカードのrawmidiデバイスに書いたバイト列が、同じカードのALSAシーケンサのポートから読める。`scripts/hid-to-midi.py`はこれを使い、本機の6つの入力を既定ではチャンネル1のコントロールチェンジとして送る。値が変わったときだけ送り、起動時に`00 04 01`を書いて送出を有効化し、最初のレポートで現在値を送る。

| 入力 | レポートの位置 | CC番号（引数） | 値 |
| --- | --- | --- | --- |
| 内蔵ペダル | [6] | 11（`--pedal-cc`） | 踵（`--pedal-heel`、既定0x00）を0、爪先（`--pedal-toe`、既定0xFF）を127とする直線で7ビットに写す |
| 内蔵スイッチ | [5]のbit0 | 64（`--switch-cc`） | 押下127、解放0 |
| ノブ | [9] | 7（`--knob-cc`） | 7ビット値をそのまま |
| 外部ペダル | [7] | 4（`--ext-pedal-cc`） | 踵（`--ext-pedal-heel`、既定0x00）を0、爪先（`--ext-pedal-toe`、既定0xFF）を127とする直線で7ビットに写す |
| 外部スイッチ1（TRSのTip） | [5]のbit1 | 80（`--ext-switch1-cc`） | 押下127、解放0 |
| 外部スイッチ2（TRSのRing） | [5]のbit2 | 81（`--ext-switch2-cc`） | 押下127、解放0 |

ペダルの両端の生値は個体や接続するペダルで異なるので（この個体の内蔵ペダルは0x08と0xF2、M-Audio EX-Pの極性M-Audio側は0x05と0xEB。docs/0005-external-controllers）、測った値を起動時に渡す。

```shellsession
$ python3 hid-to-midi.py --pedal-heel 0x08 --pedal-toe 0xF2 --ext-pedal-heel 0x05 --ext-pedal-toe 0xEB
```

BOSS FS-7とM-Audio EX-Pを接続して60秒間動かした記録が`raw/exp-p-bridge-external.log`で、FS-7のA（外部スイッチ2）の踏み込みと解放でCC 81が127と0、B（外部スイッチ1）でCC 80が127と0、外部ペダルの踵までの往復でCC 4が127から0を経て127、内蔵スイッチでCC 64が127と0、内蔵ペダルの往復でCC 11が258件送られ、aseqdumpで受けた件数は送った件数（502件）と一致した。

検証VMでは`modprobe snd-virmidi midi_devs=1`で仮想カードがカード0になり、rawmidiが`/dev/snd/midiC0D0`、シーケンサのクライアントが16（Virtual Raw MIDI 0-0）になる。起動のたびに読み込ませるには`etc/modules-load.d/snd-virmidi.conf`と`etc/modprobe.d/snd-virmidi.conf`を`/etc/`の同じ場所に置く。後者はカード番号を10に固定して、本機のカード番号が仮想カードに押し出されないようにする。この設定で再起動すると、本機がカード1、仮想カードがカード10（rawmidiは`/dev/snd/midiC10D0`、シーケンサのクライアントは56）になった（`raw/exp-l-boot-virmidi.log`）。hid-to-midi.pyは`--midi`を省くと`/proc/asound/cards`からVirMIDIのカード番号を探してrawmidiデバイスを決め、この構成でも起動直後のCCが`aseqdump -p 56:0`に届いた（`raw/exp-l-boot-virmidi.log`。内蔵の3入力だけを送る構成での記録）。橋渡しを5秒間動かし、`aseqdump -p 16:0`で受けた結果が`raw/exp-h-midi-bridge.log`（同じく3入力の構成）で、ペダルが踵側、スイッチが解放、ノブが左端の状態の起動直後に、CC 11が0、CC 64が0、CC 7が0として届いた。60秒間動かし、30秒経過時点のCPU使用率は0.6%で、カーネルログにエラーは無い（`raw/exp-i-interval-and-bridge-60s.log`）。MIDI対応のアプリはこのポートに接続すれば本機を使える。

## 一般ユーザーからの利用

hidrawのノードは既定でrootだけが開ける（モード0600）。`udev/70-stealthpedal.rules`は、本機のHIDインターフェイスのノードをグループplugdevの0660にし、あわせてuaccessタグを付けてログイン中のデスクトップユーザーにACLを与える。`/etc/udev/rules.d/`に置いて`udevadm control --reload`と`udevadm trigger --subsystem-match=hidraw`を行うと、ノードは`crw-rw----+ root plugdev`になり、plugdevに属するユーザー（Ubuntuの既定の最初のユーザーは属している）がrootなしで開いてレポートを読める（`raw/exp-j-udev.log`）。
