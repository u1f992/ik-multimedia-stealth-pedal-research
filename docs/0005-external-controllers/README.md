# 外部エクスプレッションペダルとデュアルフットスイッチの互換製品

本機の背面にある2つの外部入力（External Expression Pedal、External Dual Footswitch）に接続できる市販品を、IK公式の仕様と各製品の取扱説明書から判定する。資料の取得と該当箇所の抜き出しは`scripts/fetch-sources.sh`で行い、結果は`raw/`にある。

## 本機の外部入力の仕様

公式サイトで現在入手できるマニュアルはStealthPedal CS版で（docs/0000-search-existing-research）、その仕様欄と3.4節が外部入力を定めている（`raw/ik-stealthpedal-cs-manual-external-inputs.txt`）。

| ジャック | コネクター | 配線 |
| --- | --- | --- |
| External Expression Pedal（EXTERNAL CONTROLLER INPUT） | 6.3mm TRS | Tip: 入力信号、Ring: 3.3V出力、Sleeve: 0V（GND） |
| External Dual Footswitch | 6.3mm TRS | Tip: フットスイッチ1入力、Ring: フットスイッチ2入力、Sleeve: 0V（GND） |

仕様欄のコネクターの表記は「1/4in (3.5mm)」で、1/4インチは6.3mmである。3.4節は、エクスプレッションペダルはTRS（ステレオ）ケーブルで接続し、TS（モノ）ケーブルでは動作しないこと、フットスイッチは市販のデュアルフットスイッチか単体フットスイッチ2つを上の配線で接続できること、単体のTSフットスイッチはスイッチ1としてのみ使えることを述べている。ポテンショメーターの抵抗値の指定は無い。

## 互換の条件

エクスプレッションペダルは、本機がRingに3.3Vを供給し、Tipの電圧を読む。ポテンショメーターの両端がRingとSleeveに、ワイパーがTipに配線された製品（Tip=ワイパー型）が条件で、ワイパーがRingに配線された製品（Ring=ワイパー型）はTipとRingを入れ替えるアダプターを挟まない限り正しく動かない。極性切替スイッチを持つ製品はどちらにも合わせられる。

フットスイッチは、TRSのTipとRingにそれぞれ独立したスイッチが入ればよい。本機の内蔵スイッチはモーメンタリー（踏んでいる間だけ1。docs/0004-linux-control）で、ラッチ動作はアプリ側の設定なので、外部もモーメンタリー型で使う。接点の開閉の向き（極性）は公式資料に記載が無いので、極性切替のある製品なら接続後に合わせられる。

## エクスプレッションペダルの候補

Empress Effectsは、ZOIAのエクスプレッション入力（Tip=信号、Ring=3.3V、Sleeve=GND。本機と同じ配線）で動作確認した製品を公開している（`raw/empress-zoia-expression-pedals.txt`）。

| 製品 | 根拠 | 備考 |
| --- | --- | --- |
| Roland EV-5 | Empressの一覧 | 2mのステレオケーブル直付け、最小値ノブ付き（`raw/roland-ev-5-manual.txt`） |
| BOSS EV-30 | Empressの一覧 | EXP 1とEXP 2の2出力。POLARITYスイッチはEXP 2の向きだけを反転する。ステレオケーブル1m付属（`raw/boss-ev-30-manual.txt`） |
| M-Audio EX-P | Empressの一覧 | 極性切替スイッチ付き |
| Mission EP-1、EP-2 | Empressの一覧 | EP-2は極性切替スイッチ付き |
| Boss FV-500L、Lead Foot LFX-1、Moog EP-2 | Empressの一覧 | Moog EP-3は未確認とされている |

適合しない報告がある製品は次のとおり。いずれもフォーラムの投稿が根拠で、メーカー資料による裏付けは無い。

| 製品 | 報告 |
| --- | --- |
| Yamaha FC7 | ワイパーがRing側に配線されている（50kΩ） |
| Korg EXP-2 | Tip-Sleeve間が100kΩ固定で、ワイパーがRing側 |

### M-Audio EX-Pでの確認

EX-Pを両端ステレオのケーブルで本機のExpression Pedalジャックに接続すると、レポートのバイト[7]に8ビットの位置が現れ、踵側が小さく爪先側が大きい（docs/0003-windows-driverの`raw/usbpcap-exp-ex-p.pcap`）。StealthPedal MIDI ControlのOptional Expressionは、極性スイッチのどちらの位置でも移動に追従した。

| 極性スイッチ | 踵 | 爪先 |
| --- | --- | --- |
| Other | 0x1D | 0xDA |
| M-Audio | 0x05 | 0xEB |

M-Audio側のほうが値域が広く、内蔵ペダルの0x08〜0xF2に近い。本機にはM-Audio側を使う。

## デュアルフットスイッチの候補

| 製品 | 取扱説明書の記述 |
| --- | --- |
| BOSS FS-6 | ジャックA&B（TRS）に両端ステレオプラグのケーブルで接続すると、2つのスイッチを1本で出力する。スイッチA、Bそれぞれにラッチ／モーメンタリーのMODEとPOLARITYの切替がある。9V電池駆動。付属品は電池とマニュアルで、ケーブルは別売り（`raw/boss-fs-6-manual.txt`） |
| BOSS FS-7 | ジャックBにステレオプラグのケーブルで接続すると2つのスイッチを出力する（そのときジャックAには何も接続しない）。MODEとPOLARITYは2スイッチ共通。モーメンタリーならACアダプター無しで動作する（LEDは点灯しない）。付属品はパラレルDCケーブルとマニュアルで、ケーブルは別売り（`raw/boss-fs-7-manual.txt`） |

TRSのTipとRingがA、Bのどちらに対応するかは、どちらの説明書にも記載が無い。本機ではスイッチ1と2の機能割り当てがアプリ側の設定なので、対応関係は運用上問題にならない。

### BOSS FS-7での確認

FS-7のジャックBから両端ステレオのケーブルで本機のDual Footswitchジャックに接続した。StealthPedal MIDI Controlは上のスイッチAを外部スイッチ2、下のスイッチBを外部スイッチ1として認識する。TRSのTipがB、RingがAである。レポートのバイト[5]では、スイッチBがbit1（0x02）、スイッチAがbit2（0x04）に現れ、同時押しは0x06になる。記録はいずれもdocs/0003-windows-driverの`raw/`にある。

ACアダプターを接続した状態で、MODEとPOLARITYの4通りを記録した。

| MODE | POLARITY | 未操作 | 踏んだとき | 記録 |
| --- | --- | --- | --- | --- |
| FS-5U（MOMENTARY） | I | 0 | 踏んでいる間1 | `usbpcap-fs7-p1-momentary.pcap` |
| FS-5U（MOMENTARY） | II | 1 | 踏んでいる間0 | `usbpcap-fs7-p2-momentary.pcap` |
| FS-5L（LATCH） | I | 0 | 踏むたびに反転し、1回目で1 | `usbpcap-fs7-p1-latch.pcap` |
| FS-5L（LATCH） | II | 1 | 踏むたびに反転し、1回目で0 | `usbpcap-fs7-p2-latch.pcap` |

POLARITYはどちらのMODEでも出力のレベルを反転させ、切り替えた瞬間に未操作の値が変わる（II・LATCHの記録では24.9秒にIIへ切り替えて0x06、78.7秒にIへ戻して0x00）。本機の内蔵スイッチと同じ「未操作0、押下中1」になるのはMOMENTARYかつIで、これが本機に合う設定である。LATCHではFS-7が接点を保持するので、本機側は押し続けと区別できない。ラッチ動作はアプリ側（Linuxでは橋渡し側）で行う。

ACアダプターを接続していないときは、説明書のとおりMODEとPOLARITYの位置によらずMOMENTARYかつI相当で動作し、インジケーターは点灯しない（`raw/boss-fs-7-manual.txt`）。`usbpcap-fs7-footswitch.pcap`と`usbpcap-fs7-footswitch-polarity2.pcap`はこの状態の記録で、POLARITYの位置に関わらず未操作0、押下中1だった。電源無しでそのまま本機に使える。

## 組み合わせ

Roland EV-5とBOSS FS-6（省スペースならFS-7）に6.3mm TRS-TRSケーブル1本を加えた構成が、公式仕様と取扱説明書の範囲で裏付けの揃う組み合わせである。

## 国内価格

2026年10月13日の検索結果による税込価格と在庫表示で、購入時には販売店のページで再確認する。

| 製品 | 販売店 | 価格 | 在庫表示 |
| --- | --- | --- | --- |
| Roland EV-5 | サウンドハウス | 7,700円 | 在庫あり |
| Yamaha FC7 | サウンドハウス | 7,580円 | 入荷未定 |
| M-Audio EX-P | サウンドハウス | 2,333円 | 在庫あり（ヨドバシ.comは販売終了） |
| BOSS FS-6 | サウンドハウス | 8,380円 | 在庫あり |
| BOSS FS-6 | イケベ楽器店 | 8,800円 | 記載なし |
| BOSS FS-7 | サウンドハウス | 8,800円 | 在庫あり |
| BOSS FS-7 | BIGBOSS | 9,900円 | お取り寄せ |

## 資料

- IK Multimedia StealthPedal CS User Manual: https://g1.ikmultimedia.com/html/stealthpedal/download/StealthPedal_CS_User_Manual.pdf
- Empress Effects「What expression pedals can I use?」: https://empresseffects.com/blogs/support-zoia/what-expression-pedals-can-i-use
- BOSS FS-6 Owner's Manual: https://static.roland.com/assets/media/pdf/FS-6_OM.pdf
- BOSS FS-7 Owner's Manual: https://static.roland.com/assets/media/pdf/FS-7_OM.pdf
- BOSS EV-30 Owner's Manual: https://static.roland.com/assets/media/pdf/EV-30_eng03_W.pdf
- Roland EV-5 Owner's Manual（Adoramaの複製）: https://www.adorama.com/col/productManuals/ROEV5.pdf
- Yamaha FC7の極性に関する投稿: https://forum.bome.com/t/scaling-a-midi-expression-pedal/1159
- Korg EXP-2の実測に関する投稿: https://forum.singularsound.com/t/expression-pedal-interface-wiring-resistance-taper/35465
- 価格（サウンドハウス、Roland EV-5）: https://www.soundhouse.co.jp/products/detail/item/66262/
- 価格（サウンドハウス、BOSS FS-6）: https://www.soundhouse.co.jp/products/detail/item/20756/
- 価格（サウンドハウス、BOSS FS-7）: https://www.soundhouse.co.jp/products/detail/item/200071/
- 価格（イケベ楽器店、BOSS FS-6）: https://www.ikebe-gakki.com/Form/Product/ProductDetail.aspx?shop=0&pid=25043&bid=ec
- 価格（BIGBOSS、BOSS FS-7）: https://bigboss.jp/store/products/detail/8276
- 価格（ヨドバシ.com、M-Audio EX-P）: https://www.yodobashi.com/product/100000001003272309/
