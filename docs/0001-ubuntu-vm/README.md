# Ubuntu Desktop VM（USBコントローラーのPCIパススルー）

検証環境として、USBホストコントローラーをVFIOでゲストに渡したUbuntu Desktop VMを用意する。対象機器をこのコントローラーのポートに挿すと、USBの列挙からドライバのバインドまでをゲストのカーネルだけが行い、ホストのカーネルは機器に触れない。ホスト経由のUSBリダイレクト（QEMUのusb-host）では、ホストのUSBスタックが機器を一度列挙してからゲストへ転送するので、この用途には使わない。

ツールはlibvirt（QEMU/KVM）で、ドメイン定義は同じディレクトリの`stealthpedal-ubuntu.xml`に置く。

## ホスト

| 項目 | 値 |
| --- | --- |
| マザーボード | MSI Z390-A PRO（MS-7B98）、UEFI 1.F0（2024年7月10日） |
| CPU | Intel Core i9-9900KF（8コア16スレッド、VT-x対応） |
| メモリ | 125GiB |
| OS | Ubuntu 24.04.5 LTS、カーネル7.0.0-38-generic |
| 仮想化 | libvirt 10.0.0、QEMU 8.2.2、OVMF 2024.02 |
| カーネル起動パラメータ | `intel_iommu=on iommu=pt vfio-pci.ids=10de:1287,10de:0e0f preempt=full` |

USBホストコントローラーは5基ある。オンボードのIntel製1基に加えて、PCIeカード上にRenesas製が4基あり、4基はPericom製PCIeスイッチ（上流04:00.0、下流05:01.0〜05:04.0）の下にぶら下がっている。各Renesasコントローラーのルートハブはポート数1なので、コントローラー1基が物理ポート1個に対応する。

| PCIアドレス | コントローラー | ホストのUSBバス | 接続中の機器（2026年10月12日時点） |
| --- | --- | --- | --- |
| 0000:00:14.0 | Intel Cannon Lake PCH xHCI（8086:a36d） | 1、2 | キーボード、マウス、Webカメラ、Bluetooth、オーディオインターフェイス（UR22C）など |
| 0000:06:00.0 | Renesas uPD720202（1912:0015） | 3（USB 2.0）、4（USB 3.0） | なし（位置の特定時にSound Blaster Play! 4を挿してBus 003に現れることを確認した） |
| 0000:07:00.0 | Renesas uPD720202（1912:0015） | 5、6 | なし |
| 0000:08:00.0 | Renesas uPD720202（1912:0015） | 7、8 | USB HDD（BUFFALO HD-LE-B） |
| 0000:09:00.0 | Renesas uPD720202（1912:0015） | 9、10 | USBハブ（配下にRaspberry Pi Pico、CASIO USB-MIDI、SanDiskメモリ） |

パススルー対象は0000:06:00.0とする。ホスト側の入力機器やストレージを巻き込まない。物理ポートの位置はソフトウェアからは分からないので、機器を挿して`lsusb -t`のBus 003またはBus 004に現れるポートがそれだと特定する。カード上の4ポートのうち、USB HDDのポートが08:00.0、USBハブのポートが09:00.0で、残る2ポートのうちSound Blaster Play! 4を挿してBus 003に現れたほうが06:00.0である。

Renesasコントローラーのファームウェアはカード上のROMから読まれる。ホストのカーネルログに`failed to load firmware renesas_usb_fw.mem, fallback to ROM`と記録されており、ホストに`renesas_usb_fw.mem`は存在しない。ゲストのドライバも同じくROMにフォールバックするので、ゲスト側にファームウェアファイルを用意する必要はない。

## 前提条件: VT-d（IOMMU）

PCIパススルーにはIOMMUが必要で、UEFI設定でVT-dを有効にしてある。有効な状態では、ファームウェアがACPIのDMARテーブルを提供し、カーネルがPCIデバイスをIOMMUグループに分ける。このホストでは0000:06:00.0がグループ18に単独で属する。PCIeスイッチの下流ポート4つと配下のコントローラー4基がそれぞれ別のグループに分かれているのは、PericomスイッチがACS（Access Control Services）を提供しているためで、コントローラー1基だけを渡せる。

```shellsession
$ ls /sys/firmware/acpi/tables/ | grep DMAR
DMAR
$ readlink /sys/bus/pci/devices/0000:06:00.0/iommu_group
../../../../../../kernel/iommu_groups/18
$ ls /sys/kernel/iommu_groups/18/devices/
0000:06:00.0
```

## インストールメディア

ISOは同じディレクトリに置き、Gitの追跡から除外している。

```
$ sha256sum ubuntu-26.04.1-desktop-amd64.iso 
601e30fbf5d97759367c632e2c33630665039b7e2158fd068403da3ccf1bda1f  ubuntu-26.04.1-desktop-amd64.iso
```

この値は<https://releases.ubuntu.com/26.04.1/SHA256SUMS>の`ubuntu-26.04.1-desktop-amd64.iso`の行と一致する（SHA256SUMSとその署名の複製は`raw/`にある）。SHA256SUMSの署名（SHA256SUMS.gpg）は、Ubuntu CD Image Automatic Signing Key (2012)、フィンガープリント`8439 38DF 228D 22F7 B374 2BC0 D94A A3F0 EFE2 1092`で検証できた。

このISOは、後述の再マスタISOの元になる。libvirtの既定プール（`/var/lib/libvirt/images/`）にも同名の無改変ISOがあり、`virsh vol-download`で取り出して計算したSHA-256は上の値と一致する。ホームディレクトリ（`/home/mukai`、モード750）はqemuプロセスの実行ユーザーであるlibvirt-qemuが辿れないため、ドメイン定義はプール内のボリュームだけを参照する。

## 自動インストール

インストーラーへの回答は`autoinstall/user-data`に書き、`autoinstall/meta-data`と合わせてシードISOにしてVMに渡す。Ubuntu Desktopのインストーラーはsubiquityをバックエンドにしており、cloud-initのNoCloudデータソース（ボリュームラベルがCIDATAで、ルートに`user-data`と`meta-data`を持つ媒体）から`#cloud-config`形式のユーザーデータを読み、その`autoinstall:`キー配下を設定として使う。`interactive-sections`を指定していないので、インストーラーは画面を出さずに進み、`shutdown: poweroff`により完了後にVMの電源を切る。

| キー | 値 | 理由 |
| --- | --- | --- |
| source | ubuntu-desktop-minimal | 調査に要るのは端末とALSAのツールで、フル構成のアプリケーションは不要 |
| locale | en_US.UTF-8 | ログを英語のまま残す |
| keyboard | jp | ホストと同じ配列 |
| timezone | Asia/Tokyo | |
| identity | ホスト名stealthpedal-ubuntu、ユーザーubuntu、パスワードubuntu | 検証専用VMなので、`openssl passwd -6`で作ったSHA-512ハッシュを平文の値とともに記録する |
| storage | directレイアウト | 単一の仮想ディスクなのでLVMは不要 |
| ssh | openssh-serverを導入し、パスワード認証を許可 | ホストから`ssh`でゲストのコマンドを実行する |
| codecs、drivers、oem | いずれも導入しない | VMに該当する追加パッケージは無く、OEMメタパッケージはカーネルを差し替える可能性がある |
| updates | security | |
| packages | qemu-guest-agent、usbutils、pciutils、alsa-utils | ゲストエージェントでlibvirtからIPアドレスを引けるようにし、USB・PCI・ALSAの調査ツールを揃える |
| shutdown | poweroff | 完了を電源断で判別し、次の起動でディスクから立ち上げる |

シードISOはxorrisoで作り、既定プールへ登録する。

```shellsession
$ cd docs/0001-ubuntu-vm/autoinstall
$ xorriso -as mkisofs -V CIDATA -J -r -o /tmp/stealthpedal-ubuntu-seed.iso user-data meta-data
$ virsh -c qemu:///system vol-create-as default stealthpedal-ubuntu-seed.iso $(stat -c %s /tmp/stealthpedal-ubuntu-seed.iso) --format raw
$ virsh -c qemu:///system vol-upload --pool default stealthpedal-ubuntu-seed.iso /tmp/stealthpedal-ubuntu-seed.iso
```

`user-data`を変更したときは、シードISOを作り直して同じ名前のボリュームへ`vol-upload`で上書きする。

### カーネルパラメータautoinstallと再マスタISO

設定をシードISOで渡すだけでは、インストーラーはディスクを変更する直前に「Ready to install」の画面で確認を求めて止まる。subiquityのインストールコントローラーは、カーネルコマンドラインに`autoinstall`があるときだけ確認を自動で済ませ、無ければ`NEEDS_CONFIRMATION`状態で利用者の操作を待つ（subiquityリポジトリの`subiquity/server/controllers/install.py`）。無人で完了させるには、このパラメータを付けて起動する必要がある。

配布ISOのGRUBメニューにはこのパラメータを付けた項目が無いので、`/boot/grub/grub.cfg`だけを`autoinstall/grub.cfg`に差し替えた再マスタISOを使う。差し替え後の設定は、先頭に`autoinstall fsck.mode=skip`を付けた「Autoinstall Ubuntu」の項目を既定（タイムアウト5秒）とし、配布ISOの項目はそのまま残している。`fsck.mode=skip`は、ISO内の`md5sum.txt`が差し替え前の`grub.cfg`のハッシュを持つため、casper-md5checkによる媒体検査を省くためのものである。二つのパラメータは`---`より前に置き、インストール後のシステムのカーネルコマンドラインに引き継がれないようにしている。

xorrisoは元のISOのブート構造（BIOS用El Torito、UEFI用El Torito、GPT）をそのまま再現する。

```shellsession
$ xorriso -indev docs/0001-ubuntu-vm/ubuntu-26.04.1-desktop-amd64.iso -outdev /tmp/ubuntu-26.04.1-desktop-amd64-autoinstall.iso -boot_image any replay -map docs/0001-ubuntu-vm/autoinstall/grub.cfg /boot/grub/grub.cfg
$ virsh -c qemu:///system vol-create-as default ubuntu-26.04.1-desktop-amd64-autoinstall.iso $(stat -c %s /tmp/ubuntu-26.04.1-desktop-amd64-autoinstall.iso) --format raw
$ virsh -c qemu:///system vol-upload --pool default ubuntu-26.04.1-desktop-amd64-autoinstall.iso /tmp/ubuntu-26.04.1-desktop-amd64-autoinstall.iso
```

ドメイン定義の光学ドライブはこの再マスタISOを参照する。

## ドメイン定義の設計

| 項目 | 設定 | 理由 |
| --- | --- | --- |
| 名前 | stealthpedal-ubuntu | |
| ファームウェア | UEFI。`<os firmware='efi'>`でSecure Bootを無効に指定し、libvirtが`/usr/share/OVMF/OVMF_CODE_4M.fd`を選ぶ | 調査の過程で署名されていないカーネルモジュールを読み込めるようにするため |
| マシン | q35（定義時にpc-q35-nobleへ解決される） | PCIeデバイスのパススルーにはPCIe対応のチップセットが要る |
| CPU | host-passthrough、1ソケット4コア | |
| メモリ | 8GiB | |
| システムディスク | `/var/lib/libvirt/images/stealthpedal-ubuntu.qcow2`、64GiB、virtio、discard有効 | |
| 光学ドライブ | 既定プールの`ubuntu-26.04.1-desktop-amd64-autoinstall.iso`、SATA、読み取り専用 | GRUB設定だけを差し替えた再マスタISO（「自動インストール」の節） |
| シードISO | 既定プールの`stealthpedal-ubuntu-seed.iso`、SATA、読み取り専用 | cloud-initのNoCloudデータソースとして自動インストール設定を渡す |
| ブート順 | ディスクが1、光学ドライブが2 | 初回はディスクが空なのでインストーラーが起動し、インストール後はISOを外さなくてもディスクから起動する |
| ネットワーク | libvirtのdefaultネットワーク（NAT）、virtio、MACアドレス52:54:00:39:d4:4eを固定 | MACを書かないと`virsh define`のたびにlibvirtが生成し直し、DHCPで配られるアドレスが変わる |
| ゲストエージェント | virtioチャネル`org.qemu.guest_agent.0` | `virsh domifaddr --source agent`でアドレスを引き、`virsh qemu-agent-command`でゲスト内のコマンドを実行する |
| 画面 | SPICE、virtioビデオ、qemu-xhci経由のUSBタブレット | |
| サウンド | 仮想サウンドカードを定義しない | ゲストのALSAカード一覧をパススルーしたUSB機器だけにするため |
| 電源管理 | S3/S4を無効 | パススルー中のデバイスはサスペンドからの復帰で状態を失いやすい |
| パススルー | `<hostdev type='pci' managed='yes'>`で0000:06:00.0 | managed指定により、起動時にlibvirtがxhci-pci-renesasからvfio-pciへ付け替え、停止時に戻す |

XMLにはUUIDを含めている。libvirtは同名で別UUIDのドメイン定義を拒否するので、XMLを編集したあとに`virsh define`で上書きするにはUUIDの一致が要る。

## 作成手順

手順は、ボリュームの用意、ドメインの定義、無人インストール、インストール済みシステムの起動の順である。ボリュームはシステムディスク、再マスタISO、シードISOの三つで、後の二つの作り方は「自動インストール」の節にある。

```shellsession
$ virsh -c qemu:///system vol-create-as default stealthpedal-ubuntu.qcow2 64G --format qcow2
Vol stealthpedal-ubuntu.qcow2 created
$ virt-xml-validate docs/0001-ubuntu-vm/stealthpedal-ubuntu.xml domain
docs/0001-ubuntu-vm/stealthpedal-ubuntu.xml validates
$ virsh -c qemu:///system define docs/0001-ubuntu-vm/stealthpedal-ubuntu.xml
Domain 'stealthpedal-ubuntu' defined from docs/0001-ubuntu-vm/stealthpedal-ubuntu.xml
```

起動すると、libvirtが0000:06:00.0をホストから切り離し、そのポートの機器はホストから見えなくなる。ホスト側では0000:06:00.0のドライバがvfio-pciに変わり、USBバス3と4が消える。VMが停止するとxhci-pci-renesasに戻り、バス3と4が再登録される。

初回起動ではシステムディスクが空なので、OVMFは再マスタISOへ進み、GRUBの「Autoinstall Ubuntu」が5秒後に選ばれる。インストーラーはシードISOの設定を読んで無人で進み、完了するとゲストが電源を切る。この機体では起動から電源断まで約11分だった。画面を見たいときは`virt-viewer -c qemu:///system stealthpedal-ubuntu`で接続する。

```shellsession
$ virsh -c qemu:///system start stealthpedal-ubuntu
Domain 'stealthpedal-ubuntu' started
$ lspci -k -s 06:00.0 | grep 'Kernel driver'
	Kernel driver in use: vfio-pci
$ ls /sys/bus/usb/devices/ | grep -E '^usb[34]$'
$ virsh -c qemu:///system event --domain stealthpedal-ubuntu --event lifecycle --timeout 1200
event 'lifecycle' for domain 'stealthpedal-ubuntu': Shutdown Finished after guest request
events received: 1
$ lspci -k -s 06:00.0 | grep 'Kernel driver'
	Kernel driver in use: xhci-pci-renesas
$ ls /sys/bus/usb/devices/ | grep -E '^usb[34]$'
usb3
usb4
```

もう一度起動すると、ブート順によりシステムディスクから立ち上がり、GDMのログイン画面（ユーザーubuntu）になる。ゲストエージェントが接続したらアドレスを引ける。`ssh ubuntu@<アドレス>`（パスワードubuntu）で入るか、`virsh qemu-agent-command`のguest-execでコマンドを実行する。

```shellsession
$ virsh -c qemu:///system start stealthpedal-ubuntu
Domain 'stealthpedal-ubuntu' started
$ virsh -c qemu:///system event --domain stealthpedal-ubuntu --event agent-lifecycle --timeout 180
event 'agent-lifecycle' for domain 'stealthpedal-ubuntu': state: 'connected' reason: 'channel event'
events received: 1
$ virsh -c qemu:///system domifaddr stealthpedal-ubuntu --source agent | grep ipv4 | grep -v 127.0.0.1
 enp1s0     52:54:00:39:d4:4e    ipv4         192.168.122.109/24
```

ゲストで確認した結果は次のとおりである。ホスト名、ロケール、キーボード配列、タイムゾーンは`user-data`どおりで、Renesasコントローラーはゲストの05:00.0に現れ、ゲストのxhci-pci-renesasがルートハブ（バス3と4）を登録している。カーネルコマンドラインに`autoinstall`と`fsck.mode=skip`は引き継がれていない。

```shellsession
ubuntu@stealthpedal-ubuntu:~$ cat /proc/cmdline
BOOT_IMAGE=/boot/vmlinuz-7.0.0-38-generic root=UUID=a01de0dc-f509-4655-94f7-38f3b42b0a48 ro quiet splash crashkernel=2G-4G:320M,4G-32G:512M,32G-64G:1024M,64G-128G:2048M,128G-:4096M
ubuntu@stealthpedal-ubuntu:~$ lspci -nnk | grep -A3 -i 'usb controller'
02:00.0 USB controller [0c03]: Red Hat, Inc. QEMU XHCI Host Controller [1b36:000d] (rev 01)
	Subsystem: Red Hat, Inc. Device [1af4:1100]
	Kernel driver in use: xhci_hcd
	Kernel modules: xhci_pci
--
05:00.0 USB controller [0c03]: Renesas Electronics Corp. uPD720202 USB 3.0 Host Controller [1912:0015] (rev 02)
	Subsystem: Renesas Electronics Corp. uPD720202 USB 3.0 Host Controller [1912:0015]
	Kernel driver in use: xhci-pci-renesas
	Kernel modules: xhci_pci_renesas
ubuntu@stealthpedal-ubuntu:~$ lsusb -t
/:  Bus 001.Port 001: Dev 001, Class=root_hub, Driver=xhci_hcd/15p, 480M
    |__ Port 001: Dev 002, If 0, Class=Human Interface Device, Driver=usbhid, 480M
/:  Bus 002.Port 001: Dev 001, Class=root_hub, Driver=xhci_hcd/15p, 5000M
/:  Bus 003.Port 001: Dev 001, Class=root_hub, Driver=xhci-pci-renesas/1p, 480M
/:  Bus 004.Port 001: Dev 001, Class=root_hub, Driver=xhci-pci-renesas/1p, 5000M
```

インストール後のシステムにもcloud-initは入っているが、`/etc/cloud/cloud-init.disabled`が置かれて無効になっているので、シードISOを接続したままでも初回起動で再処理されない。opensshはソケット起動（ssh.socket）で、接続があるまで`systemctl is-active ssh`はinactiveを返す。

対象機器を0000:06:00.0のポートに挿し、ゲストの`lsusb`に現れてホストの`lsusb`に現れないことを確認する。

ドメインを削除するときはNVRAMも一緒に消す。

```shellsession
$ virsh -c qemu:///system undefine --nvram stealthpedal-ubuntu
```

## ゲスト操作と監視のスクリプト

`scripts/`には、このVMをホストから扱うための道具を置いている。環境変数`GUEST_DOMAIN`（既定はstealthpedal-ubuntu）と`LIBVIRT_URI`（既定はqemu:///system）で対象を変えられる。

| スクリプト | 役割 |
| --- | --- |
| guest-exec.sh | 引数のシェルコマンドをqemu-guest-agentのguest-execでゲストのrootとして実行し、標準出力・標準エラー・終了コードを返す。`--no-capture`を付けると出力を待たずにPIDだけ返す |
| guest-python.sh | Pythonスクリプトをbase64でゲストへ送って実行する。`--background`で常駐させ、出力は`/tmp/<名前>.out`に残る |
| guest-usb-watch.sh | ゲストのバス3と4（パススルーしたRenesasコントローラー）に現れる機器を一定間隔で確認し、変化があったときだけ1行出力する |
| host-usb-watch.py | ホストのudevイベントを監視し、USB機器の接続・切断をコントローラーのPCIアドレス付きで1行出力する。物理ポートの特定に使う |
