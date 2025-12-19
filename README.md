# Azure VM デプロイ - Bicep

このプロジェクトは、Azure Bicepを使用してUbuntu Server 24.04 LTS仮想マシンとネットワークインフラをデプロイします。

## 構成

このプロジェクトは以下のリソースをデプロイします：

- **仮想ネットワーク (VNet)**: `vnet-bicep` (192.168.0.0/16)
- **サブネット**: `subnet-bicep` (192.168.10.0/24)
- **ネットワークセキュリティグループ (NSG)**: SSH (Port 22) を許可
- **パブリックIP**: Standard SKU
- **ネットワークインターフェース (NIC)**: 動的プライベートIP割り当て
- **仮想マシン**: Ubuntu Server 24.04 LTS (Standard_B2ms)
- **データディスク**: 64GB Standard SSD

## ファイル構成

```
├── main.bicep              # メインエントリーポイント
├── network.bicep           # ネットワークリソース (VNet, NSG, PIP, NIC)
└── virtualMachine.bicep    # VM とデータディスクリソース
```

**注意**: セキュリティのため、パラメータファイル（.bicepparam）は使用していません。すべてのパラメータはコマンドラインで指定します。

## 前提条件

- Azure CLI がインストールされていること
- Azureサブスクリプションへのアクセス権限
- Azure CLIでログイン済みであること (`az login`)

## デプロイ方法

### 1. Azure CLIでログイン

```powershell
az login
```

### 2. リソースグループの作成

```powershell
az group create --name rg-bicep-vm --location japaneast
```

### 3. デプロイの実行

**重要**: すべてのパラメータをコマンドラインで直接指定してください。

```powershell
az deployment group create `
  --resource-group rg-bicep-vm `
  --template-file main.bicep `
  --parameters location=japaneast `
               vnetName=vnet-bicep `
               nsgName=nsg-bicep `
               pipName=pip-vm-bicep `
               nicName=nic-vm-bicep `
               vmName=vm-bicep `
               dataDiskName=disk-bicep `
               adminUsername=<ユーザー名> `
               adminPassword=<パスワード>
```

**注意**: パスワードは強力なものを使用してください（大文字、小文字、数字、特殊文字を含む12文字以上）。

### 4. デプロイ状況の確認

```powershell
az deployment group list --resource-group rg-bicep-vm --output table
```

## デプロイ後の確認

### パブリックIPアドレスの取得

```powershell
az network public-ip show --resource-group rg-bicep-vm --name pip-vm-bicep --query ipAddress --output tsv
```

### SSH接続

```powershell
ssh <ユーザー名>@<パブリックIPアドレス>
```

## パラメータ

| パラメータ名 | 説明 | デフォルト値 |
|------------|------|------------|
| `location` | リソースのデプロイ先リージョン | `japaneast` |
| `adminUsername` | VM管理者ユーザー名 (コマンドラインで指定) | なし |
| `adminPassword` | VM管理者パスワード (コマンドラインで指定) | なし |
| `vnetName` | 仮想ネットワーク名 | `vnet-bicep` |
| `nsgName` | NSG名 | `nsg-bicep` |
| `pipName` | パブリックIP名 | `pip-vm-bicep` |
| `nicName` | NIC名 | `nic-vm-bicep` |
| `vmName` | VM名 | `vm-bicep` |
| `dataDiskName` | データディスク名 | `disk-bicep` |

## 出力

デプロイが成功すると、以下の情報が出力されます：

- `publicIPAddress`: VMのパブリックIPアドレス
- `vmName`: デプロイされたVM名

## クリーンアップ

リソースグループを削除してすべてのリソースを削除：

```powershell
az group delete --name rg-bicep-vm --yes --no-wait
```

## セキュリティに関する注意

- パスワードは強力なものを使用してください（大文字、小文字、数字、特殊文字を含む12文字以上）
- **管理者のユーザー名とパスワードは、パラメータファイルに記載せず、必ずコマンドライン引数で渡してください**
- 本番環境では、SSH鍵認証の使用を推奨します
- NSGルールは必要最小限に制限することを推奨します
- 機微情報をGitリポジトリにコミットしないよう注意してください