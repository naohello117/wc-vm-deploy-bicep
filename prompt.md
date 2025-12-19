Azure Bicepを使用して、以下の構成図の通りにインフラを構築するコードを作成してください。
すべてのリソースは `japaneast` (東日本) リージョンに作成します。

## 構成要件

1.  **仮想ネットワーク (VNet)**
    * リソース名: `vnet-bicep`
    * アドレス空間: `192.168.0.0/16`
    * サブネット:
        * 名前: `subnet-bicep`
        * アドレス範囲: `192.168.10.0/24`

2.  **ネットワークセキュリティグループ (NSG)**
    * リソース名: `nsg-bicep`
    * ルール:
        * **Inbound**: Internet (`*`) からのSSH (Port 22)を許可
        * **Outbound**: Internetへのすべての通信を許可 (`*`)
    * 関連付け: `subnet-bicep` に適用

3.  **パブリックIP (PIP)**
    * リソース名: `pip-vm-bicep`
    * SKU: Standard
    * ※VMにパブリックアクセスできるように作成してください。

4.  **ネットワークインターフェース (NIC)**
    * リソース名: `nic-vm-bicep`
    * サブネット接続: `subnet-bicep`
    * パブリックIP構成: 上記PIPを関連付け
    * プライベートIP割り当て: Dynamic (動的)
        * ※固定IPではなく、サブネットのレンジから自動割り当てとすること。

5.  **仮想マシン (Virtual Machine)**
    * リソース名: `vm-bicep`
    * サイズ: `Standard_B2ms`
    * OS: **Ubuntu Server 24.04 LTS**
    * OSディスク設定:
        * **サイズ**: 指定なし（OSイメージの既定サイズを使用すること）。
    * 認証方式: `adminUsername` と `adminPassword`をパラメータで受け取る実装にすること。
    * ネットワーク: 上記NICを接続
    * **データディスク接続**: 下記の「データディスク」をLUN 0等にアタッチすること。

6.  **データディスク (Managed Disk)**
    * ※OSディスクとは別に作成し、VMにアタッチする外部ストレージとして定義してください。
    * 名前: `disk-bicep`
    * SKU: Standard SSD (`StandardSSD_LRS`)
    * サイズ: 64GB
    * createOption: Empty (空のディスクを作成)

## 出力要件
* リソース名、ロケーション、管理ユーザー情報は `param` として定義し、再利用性を高めてください。
* **モジュール分割**:
    * `network.bicep` (VNet, Subnet, NSG, PIP, NIC)
    * `virtualMachine.bicep` (VM, Data Disk)
    * `main.bicep` (上記モジュールの呼び出し)
    の形に分割して出力してください。