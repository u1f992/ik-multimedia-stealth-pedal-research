# 既存調査の探索

StealthPedalをLinuxで動作させた記録と、動作を見積もる根拠になる一次資料を探した結果をまとめる。調査日は2026年10月12日である。

Linuxでの動作報告は、公開されているものが見つからなかった。公式資料からは、オーディオ部はOS標準のUSBオーディオクラスドライバで動き、ペダル・スイッチ・ノブの制御部はホスト側の専用ソフトとドライバに依存する構造が読み取れる。Linuxでの見込みは、オーディオ部は高く、制御部は専用ソフトの代替を自作しない限り成立しない。

## 対象機器の同定

StealthPedalは2009年に発売され、同梱ソフトの違いで三つの名前がある。2009年のStealthPedal（AmpliTube 2 Live同梱）、同年のStealthPedal Deluxe（AmpliTube 2などのフル同梱）、2011年のStealthPedal CS（AmpliTube Custom Shop同梱）である。IK公式サイトの2010年時点のVersionsページは、前二者を同じ説明文の本体に異なるソフトを同梱した2バージョンとして並べている。CS版のユーザーマニュアルに載る適合宣言は型番IK000007、発行日2009年4月21日で、CS版発売より前の日付のままなので、本体の設計は2009年から変わっていないと見てよい。

USBのベンダーIDは0x1963で、usb.idsでIK Multimediaに割り当てられている。プロダクトIDは、Windows用ドライバを集めるサードパーティサイト（DriverMax）が示す「USB\VID_1963&PID_0003」（ドライババージョン1.1.0.8、2009年6月23日付）が唯一の情報源で、0x0003と推定される。usb.ids（2026.06.26版）の0x1963配下には0x0005 iRig KEYSと0x0046 UNO Synthしか登録されておらず、0x0003は未登録である。実機で確認するまで暫定値として扱う。

公式マニュアルの仕様表（CS版ユーザーマニュアル第4章）から、USBに関わる項目を抜き出す。

| 項目 | 値 |
| --- | --- |
| USB | USB 1.1 Full Speed、2 In / 2 Out、24ビット、32〜48kHzのオーディオストリーム + Interface I/O |
| 電源 | USBバスパワー、最大2.5W（5V 500mA） |
| 接続 | USBハブ経由の接続を禁止、PC本体のポートに直結 |
| 内蔵コントローラー | エクスプレッションペダル1、フットスイッチ1、ポテンショメータ1（ボリューム兼用） |
| 外部エクスプレッションペダル入力 | 1/4インチTRS。Tip: 入力信号、Ring: 3.3V出力、Sleeve: GND |
| 外部デュアルフットスイッチ入力 | 1/4インチTRS。Tip: スイッチ1、Ring: スイッチ2、Sleeve: GND |

公式のシステム要件（2009年のIKサイト）は、Mac OS X 10.4以降（Intel Macは10.4.4以降）とWindows XP/Vista以降で、Linuxの記載はない。

## 公式資料から読み取れるホスト側の構造

### オーディオ部

Macではドライバを必要としない。CS版ユーザーマニュアル2.3節は「No drivers are needed for the Mac」と明記し、設定はApple標準のAudio MIDI Setupから行う（2.10節）。設定項目は入力ゲイン（スライダー値0〜6dBで0dB固定、7〜12dBで+12dB固定の2段）、出力ボリューム、出力フォーマット（32〜48kHz、24ビット、入出力の周波数は連動）である。レイテンシはホストアプリ側で設定する。

Windowsでは専用ドライバを使う。ドライバはAmpliTubeのインストーラーに同梱され、本体を接続する前にインストールする手順になっている（2.3節）。提供されるのはASIOだけで、WDM/MMEドライバは無い（MusicRadarのレビュー）。コントロールパネルの項目はASIOバッファサイズ、ASIO Processing Time、ASIOドライバのOpen/Streaming表示、Input Gain Boost（+12dB）、Output Volumeである（2.9節）。64ビットWindows（Vista/XP）用ドライバは2009年8月に登録ユーザー向けにUser Areaで公開された（GearjunkiesとAudiofanzineが伝えるIKの発表）。

第三者のレビューも、オーディオ部がクラスコンプライアントである点で一致する。Sonic Stateのレビュー（2009年11月17日）は「クラスコンプライアントなので、ドライバなしでも基本的なオーディオインターフェイスとして使える」と書いている。

これらから、本機のオーディオ部はUSB Audio Class 1.0の機器としてOS標準ドライバに列挙され、入力ゲインと出力ボリュームもクラス標準のFeature Unitとして公開されていると推定できる。Macの標準ドライバがそれらを操作できるのは、クラス標準の制御要求に応答する機器だけだからである。Linuxのsnd-usb-audioはUSB Audio Class 1.0の機器を汎用に扱うので、オーディオ部が動作する見込みは高い。Linuxカーネルに本機向けのquirkが存在しないこと（後述）は、動作しない根拠にはならない。

### 制御部（ペダル・スイッチ・ノブ）

本体はMIDIを送出しない。MIDI Controlマニュアル第2章によれば、本機はMIDI対応アプリから「IK StealthPedal MIDI」というMIDI入力ポートとして見えるが、これはStealthPedal MIDI Controlアプリが起動している間だけ、コントローラー操作のデータをそのポートに流す仕組みである。アプリが起動していなければMIDIメッセージは送られない（第5章トラブルシューティング）。同章の図2.1はこのポートを「MIDI driver: IK StealthPedal MIDI」と表記している。

制御データの受け手は一つに限られる。AmpliTubeとMIDI Controlは同時に本体から制御データを受け取れず、片方で「Control ON」にすると他方は自動的にOFFになる（MIDI Controlマニュアル第2章）。オーディオ部と制御部は互いに独立で、MIDI Controlを動かしながら別のASIO/Core Audioアプリでオーディオ部を使える（同2.2節）。

以上を合わせると、本体はUSB MIDIクラスのエンドポイントを持たず、制御データは仕様表の「Interface I/O」にあたる別経路で流れ、ホスト側のドライバとアプリが仮想MIDIポートへ変換している。その経路がHIDなのかベンダー固有インターフェイスなのかは、公開資料に記載が無い。

Mac側では、この変換にカーネル拡張（kext）が使われていた。GitHub上のHackintosh設定リポジトリに複製されたOS X Mavericks世代のAppleKextExcludeList（Appleが読み込みを除外するkextの一覧）には、com.ikmultimedia.driver.StealthPedalとcom.ikmultimedia.driver.IKStealthPedalMIDIがバージョン1.0で登録されている。IK公式フォーラムの2018年の報告では、OS X El Capitan（10.11）でMIDI制御を動かすには、リカバリモードで`csrutil enable --without kext`を実行してSIPのkext保護を外す必要があった。Yosemite（10.10）向けのMIDI Control 1.1.1はUser Areaに掲載されず、サポートに依頼したユーザーにだけ送られている。ユーザーが転載したIKサポートの回答は「macOS 10.11以降では動作しない」であり、IKのモデレーターは2018年3月14日に「かなり前に生産終了した製品」と述べている。

Linuxにはこの変換を担うものが無い。制御部を使うには、USB上の制御データの形式を実機で観察し、仮想MIDIポートへの変換を自作することになる。

### 初期化の指標

本体の赤LEDは電源投入とOS起動の間に点灯し、初期化が完了すると緑LEDに変わる。赤のままなら「ドライバをインストールするか再インストールする必要がある」（CS版ユーザーマニュアル2.7節）。Macではドライバなしで緑になるはずなので、初期化はOS標準のオーディオクラスドライバによる列挙と設定で完了すると推定できる。Linuxに接続して緑になるかどうかが、最初の観察項目になる。

## Linuxでの動作記録の探索

| 探索先 | 確認した内容 | 結果 |
| --- | --- | --- |
| Linuxカーネル（torvalds/linux master、コミット24a19b953e2a、2026年10月11日） | sound/usb、drivers/usb/core、drivers/hidで0x1963、IK Multimedia、StealthPedalを検索 | 該当なし。quirkやデバイス固有の処理は登録されていない |
| alsa-project/alsa-ucm-conf | 1963、IK Multimediaを検索 | 該当なし |
| usb.ids（2026.06.26版） | 0x1963配下の登録 | 0x0005 iRig KEYS、0x0046 UNO Synthのみ |
| Linux Hardware Database（linux-hardware.org） | ベンダー「IK Multimedia」の記録 | 13機種の記録あり。AXE I/O（1963:0041）とiRig PRO I/O（1963:0038）はsnd-usb-audioで検出されている。1963:0003の記録は無い |
| GitHub（リポジトリ検索とコード検索、stealthpedal） | 関連プロジェクト | Teensy 4.0で中身を置き換えるプロジェクト（SanMichele/MATMidiCCSpinner）のみ。元の電子回路を全て撤去して筐体だけ流用し、専用ドライバ不要のUSB MIDI機器にしている |
| Web検索（英語と日本語。LinuxMusicians、Arch Linux、Ubuntuのフォーラムを含む） | Linuxでの使用報告 | 該当なし |

Linux Hardware Databaseの記録は、IKの他機種がLinuxでクラスドライバにより検出されている事実を示す。本機の設計は2009年で、それらと同じチップセットとは限らないため、傍証にとどまる。

## 他OSでのユーザー報告

IK公式フォーラムのスレッド「Stealth pedal doesn't work as midi」（2011年5月〜2018年5月、35投稿）は、報告がオーディオ部と制御部で分かれる構造を裏付けている。投稿者は一貫して「オーディオインターフェイスとしては動くが、MIDI制御だけが動かない」と報告し、MIDI Controlアプリの「Control」ボタンが点灯後すぐ消える症状を共通して挙げている。解決した例は、AmpliTube X-GEAR 1.5.1のインストール（2011年、Thunderbolt搭載のMacBook Pro）、MIDI Control 1.1.1の入手（2018年、Yosemite）、SIPのkext保護解除（2018年、El Capitan）、App Napの無効化（アプリが背面に回ると送信が止まる症状への対処）である。

## 参照した資料

一次資料は次のとおりで、取得日はいずれも2026年10月12日である。取得したファイルのSHA-256、サイズ、取得日の一覧は`raw/sources-sha256.txt`にある（ファイル本体はリポジトリに含めない）。

- StealthPedal CS User Manual（PN: MNU-PDLCS-0001）: https://g1.ikmultimedia.com/html/stealthpedal/download/StealthPedal_CS_User_Manual.pdf
- StealthPedal CS MIDI Control User Manual（PN: MNU-PDLCSMIDI-0001）: https://g1.ikmultimedia.com/html/stealthpedal/download/StealthPedal_CS_MIDI_Control_User_Manual.pdf
- IK公式製品ページ（Wayback Machine保存版）
  - Features（2009年4月15日保存）: https://web.archive.org/web/20090415051859/http://www.ikmultimedia.com/stealthpedal/features
  - Specs（2009年8月23日保存）: https://web.archive.org/web/20090823061629/http://www.ikmultimedia.com/stealthpedal/specs/
  - System Requirements（2009年8月5日保存）: https://web.archive.org/web/20090805204158/http://www.ikmultimedia.com/stealthpedal/system/
  - Versions（2010年1月7日保存）: https://web.archive.org/web/20100107010417/http://www.ikmultimedia.com/stealthpedal/versions
  - CS版Specs（2011年12月21日保存）: https://web.archive.org/web/20111221180849/http://www.ikmultimedia.com/stealthpedal/specs/
- IK公式フォーラム スレッド「Stealth pedal doesn't work as midi」（Wayback Machine 2024年3月5日保存版）
  - 1ページ目: https://web.archive.org/web/20240305002400/https://cgi.ikmultimedia.com/ikforum/viewtopic.php?f=9&t=1359
  - 2ページ目: https://web.archive.org/web/20240305014418/https://cgi.ikmultimedia.com/ikforum/viewtopic.php?f=9&t=1359&start=15
  - 3ページ目: https://web.archive.org/web/20240305010950/https://cgi.ikmultimedia.com/ikforum/viewtopic.php?f=9&t=1359&start=30
- Linuxカーネル: <https://github.com/torvalds/linux>（コミット24a19b953e2a3d0ea5a8c4951a0ab8f32720c907）
- usb.ids: http://www.linux-usb.org/usb.ids
- Linux Hardware Database（ベンダー検索）: https://linux-hardware.org/?view=search&vendor=IK%20Multimedia
- Linux Hardware Database（1963:0041）: https://linux-hardware.org/?id=usb:1963-0041
- Linux Hardware Database（1963:0038）: https://linux-hardware.org/?id=usb:1963-0038
- SanMichele/MATMidiCCSpinner: https://github.com/SanMichele/MATMidiCCSpinner
- AppleKextExcludeListの複製: https://github.com/dimones/Clevo-W370ET-Mavericks/blob/master/Extensions/AppleKextExcludeList.kext/Contents/Info.plist

二次資料は次のとおりである。

- DriverMax（プロダクトIDとWindowsドライバのバージョン）: https://www.drivermax.com/IK-Multimedia-StealthPedal-IK-Multimedia-USB-VID-1963-PID-0003-1_1_0_8-2009-06-23-1070855-driver.htm
- Sonic State「Amped Review: IK Stealth Pedal」（2009年11月17日）: https://sonicstate.com/amped/2009/11/17/amped-review-ik-stealth-pedal/
- MusicRadar「IK Multimedia StealthPedal review」: https://www.musicradar.com/reviews/tech/ik-multimedia-stealthpedal-215406
- Gearjunkies「IK releases 64-bit drivers for the StealthPedal」（2009年8月）: https://www.gearjunkies.com/2009/08/ik-releases-64-bit-drivers-for-the-stealthpedal/
- Audiofanzine「IK StealthPedal 64-bit Drivers」: https://en.audiofanzine.com/electric-guitar-multi-effects/ik-multimedia/StealthPedal/news/a.play,n.4383.html

## 取得できなかった資料

- IK公式フォーラムの他のスレッド（t=20005「Stealth Pedal Installation in Windows 10」、t=11997「Stealth pedal midi program」、t=22586「Help Needed for Stealth Pedal Drivers」、t=11596「Stealth Pedal & Windows 10」、t=10995「Amplitube 4 Midi/Stealth Pedal Issue」、t=22547「StealthPedal software」、t=50470「Stealth Pedal」）。現行フォーラム（forum.ikmultimedia.com）では404、旧ホスト（cgi.ikmultimedia.com）は接続拒否、Wayback Machineにも保存が無い。検索エンジンの要約では「ドライバはUser Areaの登録ユーザー限定」「Windows 10でAmpliTube 4が本機を検出しない」という内容が読めるが、本文は未確認である。
- KVR Audioのスレッド（t=510140、t=374169）、SweetwaterのinSync FAQ「StealthPedal Drivers」、Cockosフォーラム（t=66692）、rekkerd.orgの記事。ボット対策により403または検証ページが返り、Wayback Machineにも保存が無い。
- IKのレガシー製品FAQページ。404が返る。
- Windows用ドライバパッケージとMIDI Controlアプリ本体。IK User Areaの登録ユーザー限定で、INFファイルによるインターフェイス構成の確認ができていない。
- 2009年版のユーザーマニュアルとMIDI Controlマニュアル。当時のDownloadページの保存版には項目名だけが残り、リンク先を辿れなかった。CS版マニュアルの適合宣言が2009年4月付けであることから、CS版で代替した。

## 次の調査で確認する事項

- 実機のUSBディスクリプタ（`lsusb -v`）。プロダクトID、各インターフェイスのクラス（Audio Control、Audio Streaming、HID、Vendor Specific）、エンドポイント構成、bMaxPowerの値。
- 接続時にLEDが赤から緑に変わるか。変わらなければ、Linux標準のドライバによる列挙と設定では初期化が完了しないことになる。
- snd-usb-audioでの認識内容。32/44.1/48kHzと24ビットの対応、入力ゲインと出力ボリュームのFeature Unitの有無。
- 制御データの経路。HIDならhidraw経由で読める。ベンダー固有インターフェイスならlibusbで観察する。
- WindowsまたはmacOS上での専用ソフトとのUSBパケットキャプチャ。専用ソフトの入手がIK User Areaまたはサポート経由に限られるため、入手できた場合に限る。
