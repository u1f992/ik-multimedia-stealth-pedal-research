# 実機の列挙結果（生データ）

`raw/`は、StealthPedalを検証VM（docs/0001-ubuntu-vm）のパススルーしたポートに接続し、ゲスト（Ubuntu 26.04.1、カーネル7.0.0-38-generic）でqemu-guest-agent経由に採取した出力である。採取日は2026年10月12日、ゲストでの接続は21:12:28で、本体のLEDは接続後に緑に点灯した。

| ファイル | 内容 | 採取コマンド |
| --- | --- | --- |
| lsusb-v.txt | デバイス・コンフィギュレーション・インターフェイス・エンドポイントの全ディスクリプタ | `lsusb -v -d 1963:0003` |
| lsusb-t.txt | バスのツリーと機器一覧 | `lsusb -t`、`lsusb` |
| sysfs-usb-3-1.txt | sysfsの属性（速度、電流、インターフェイスごとのクラスとドライバ、エンドポイント） | `/sys/bus/usb/devices/3-1/`配下の読み出し |
| udevadm-info.txt | udevのプロパティ（USBデバイス、HIDデバイス、hidrawノード） | `udevadm info -q all` |
| kernel-log-plug.txt | 接続時のカーネルログ | `journalctl -k -S 21:12 -U 21:13` |
| alsa.txt | ALSAのカード、再生・録音デバイス、ストリーム、USBミキサー、コントロール | `/proc/asound/`、`aplay -l`、`arecord -l`、`amidi -l`、`amixer -c 1 contents` |
| hid.txt | HIDデバイスのuevent、レポートディスクリプタ、入力デバイスの有無 | sysfsの`report_descriptor`を`od`で表示 |
| hid-getreport-first.txt | hidrawのioctl（HIDIOCGINPUT、HIDIOCGFEATURE）で入力レポートを取得した最初の結果。接続時のカーネルログの抜粋を添えている | Pythonでioctlを発行 |
| hid-poll.log | 入力レポートを20ms間隔でGET_REPORTし、内容が変わった時刻（秒）と24バイトを記録したもの | Pythonでioctlを発行 |

`scripts/collect.sh`は、docs/0001-ubuntu-vmの`scripts/guest-exec.sh`（qemu-guest-agentのguest-execでゲストのコマンドを実行し、出力を返す）を使って上の表のうちhid-getreport-first.txtとhid-poll.log以外を取り直す。hid-getreport-first.txtは`scripts/hid-getreport.py`、hid-poll.logは`scripts/hid-poll.py`をゲストで実行した結果で、どちらも`guest-python.sh`でゲストへ送り込める（ポーリングは`--background`で起動する）。レポートディスクリプタの解読は`scripts/decode-report-descriptor.py`、hid-poll.logの解析は`scripts/analyze-hid-poll.py`で行う。

## hid-poll.logの採取条件

`/dev/hidraw1`の通常の読み出し（インタラプトIN転送）は、接続から操作中を通して1バイトも返さなかった。入力レポートはGET_REPORTで能動的に取得したときだけ返るので、hid-poll.logはその方式で記録している。

記録中に本体で行った操作は、エクスプレッションペダルを踵から爪先へ動かして踵へ戻す、ペダル下のスイッチを2回踏む、ボリュームノブを左端から右端まで回す、の順である。記録の177.9秒から183.9秒がペダルの往復で、スイッチとノブの操作はその後に行ったが、記録に変化は無い。

## 観察

- 入力レポートの先頭2バイトは`80 bb`で固定、バイト21と22は本機が出力に適用している左右の音量（0x00〜0x7F、両バイトは常に同じ値）で、電源投入後にコマンドを受けていないこの状態ではエクスプレッションペダルに追従して踵で0x00、爪先で0x7Fになった（入力元の切り替えはdocs/0004-linux-control）。他は0のままだった。
- スイッチとノブの操作はGET_REPORTの内容に現れず、インタラプトINにも何も流れなかった。
