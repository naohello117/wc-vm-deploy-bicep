# Azure VM デプロイ - Bicep + DSC

このプロジェクトは、Azure Bicepを使用してWindows Server 2022仮想マシンとネットワークインフラをデプロイし、PowerShell DSC拡張機能でIIS Webサーバーを完全自動構成します。

## 構成

このプロジェクトは以下のリソースをデプロイします：

- **ストレージアカウント**: DSC設定とWebコンテンツを格納するBLOBストレージ
- **仮想ネットワーク (VNet)**: `vnet-bicep` (192.168.0.0/16)
- **サブネット**: `subnet-bicep` (192.168.10.0/24)
- **ネットワークセキュリティグループ (NSG)**: 特定IPからSSH (Port 22) とInternetからHTTP (Port 8080) を許可
- **パブリックIP**: Standard SKU
- **ネットワークインターフェース (NIC)**: 動的プライベートIP割り当て
- **仮想マシン**: Windows Server 2022 Gen2 (Standard_B2ms)
- **データディスク**: 64GB Standard SSD
- **DSC VM拡張**: IIS Webサーバーの自動構成

## ファイル構成

```
├── main.bicep                      # メインエントリーポイント
├── README.md                       # プロジェクトドキュメント
├── modules/                        # Bicepモジュール
│   ├── network.bicep              # ネットワークリソース (VNet, NSG, PIP, NIC)
│   └── virtualMachine.bicep       # VM、データディスク、DSC拡張
├── web-content/                    # Webサーバーコンテンツ
│   ├── index.html                 # Webページ
│   └── style.css                  # スタイルシート
└── dsc/                           # PowerShell DSC設定
    └── ConfigureIIS.ps1           # IIS構成スクリプト
```

## 前提条件

- PowerShell（Windows PowerShell 5.1以降またはPowerShell 7）
- Azure CLI がインストールされていること
- Azureサブスクリプションへのアクセス権限
- Azure CLIでログイン済みであること (`az login`)

## デプロイ方法（完全自動化）

### 手順概要

1. リソースグループとストレージアカウントを作成
2. DSC設定スクリプトをzip化
3. DSCパッケージとWebコンテンツをBLOBストレージにアップロード
4. Bicepテンプレートをデプロイ（VM作成とDSC自動実行）

### 1. Azure CLIでログイン

```powershell
# Azure CLIでログイン
az login
```

### 2. リソースグループの作成

```powershell
$resourceGroup = "rg-bicep-vm"
$location = "japaneast"

az group create --name $resourceGroup --location $location
```

### 3. DSC設定スクリプトのzip化

```powershell
# ストレージアカウント名（グローバルに一意である必要があります）
$storageAccountName = "stabicep$(Get-Random -Maximum 9999)"
$containerName = "dsc-content-webapp"

# ConfigureIIS.ps1をzipファイルに圧縮
Compress-Archive -Path "dsc\ConfigureIIS.ps1" -DestinationPath "ConfigureIIS.zip" -Force

Write-Host "DSCパッケージ作成完了: ConfigureIIS.zip" -ForegroundColor Green
```

### 4. ストレージアカウントの作成

```powershell
# ストレージアカウントを作成（パブリックBLOBアクセスを有効化）
az storage account create `
  --name $storageAccountName `
  --resource-group $resourceGroup `
  --location $location `
  --sku Standard_LRS `
  --kind StorageV2 `
  --allow-blob-public-access true

# ストレージアカウントのIAM設定からストレージ BLOB データ共同作成者ロールを割り当て（Azure Portal作業）

# コンテナを作成（パブリックアクセス許可）
az storage container create `
  --name $containerName `
  --account-name $storageAccountName `
  --public-access blob `
  --auth-mode login
```

### 5. ファイルをBLOBストレージにアップロード

```powershell
# DSCパッケージをアップロード
az storage blob upload `
  --account-name $storageAccountName `
  --container-name $containerName `
  --name "ConfigureIIS.zip" `
  --file "ConfigureIIS.zip" `
  --auth-mode login `
  --overwrite

# Webコンテンツをアップロード
az storage blob upload `
  --account-name $storageAccountName `
  --container-name $containerName `
  --name "index.html" `
  --file "web-content\index.html" `
  --auth-mode login `
  --overwrite

az storage blob upload `
  --account-name $storageAccountName `
  --container-name $containerName `
  --name "style.css" `
  --file "web-content\style.css" `
  --auth-mode login `
  --overwrite

# アップロードされたファイルを確認
az storage blob list `
  --account-name $storageAccountName `
  --container-name $containerName `
  --auth-mode login `
  --output table
```

### 6. BLOBストレージのURLを取得

```powershell
# ストレージアカウントのエンドポイントを取得
$blobEndpoint = az storage account show `
  --name $storageAccountName `
  --resource-group $resourceGroup `
  --query "primaryEndpoints.blob" `
  --output tsv

# URLを構築
$dscPackageUrl = "${blobEndpoint}${containerName}/ConfigureIIS.zip"
$blobStorageUrl = "${blobEndpoint}${containerName}"

Write-Host "DSC Package URL: $dscPackageUrl" -ForegroundColor Green
Write-Host "Blob Storage URL: $blobStorageUrl" -ForegroundColor Green
```

### 7. Bicepテンプレートのデプロイ

```powershell
az deployment group create `
  --resource-group $resourceGroup `
  --template-file main.bicep `
  --parameters location=$location `
               vnetName=vnet-bicep `
               nsgName=nsg-bicep `
               pipName=pip-vm-bicep `
               nicName=nic-vm-bicep `
               vmName=vm-bicep `
               dataDiskName=disk-bicep `
               adminUsername=<VMユーザー名> `
               adminPassword='<VMパスワード>' `
               dscPackageUrl=$dscPackageUrl `
               blobStorageUrl=$blobStorageUrl
```

**注意**: 
- `adminPassword` は強力なものを使用してください（大文字、小文字、数字、特殊文字を含む12文字以上）
- DSC拡張のインストールとIIS構成には数分かかります

### 8. デプロイ状況の確認

```powershell
# デプロイ状況
az deployment group list --resource-group $resourceGroup --output table

# VM拡張の状態を確認
az vm extension list --resource-group $resourceGroup --vm-name vm-bicep --output table
```

### 9. パブリックIPアドレスの取得とアクセス

```powershell
# パブリックIPアドレスを取得
$publicIP = az network public-ip show `
  --resource-group $resourceGroup `
  --name pip-vm-bicep `
  --query ipAddress `
  --output tsv

Write-Host "Public IP: $publicIP" -ForegroundColor Cyan
Write-Host "Web Server: http://${publicIP}:8080" -ForegroundColor Green

# ブラウザで開く
Start-Process "http://${publicIP}:8080"
```

## 完全自動デプロイスクリプト（オールインワン）

全手順を実行するスクリプト例（PowerShell 7で実行）：

```powershell
# 変数設定
$resourceGroup = "rg-bicep-vm"
$location = "japaneast"
$storageAccountName = "stabicep$(Get-Random -Maximum 9999)"
$containerName = "dsc-content"
$adminUsername = "adminUser"
$adminPassword = "StrongPass123!"  # 強力なパスワードに変更してください

# 1. リソースグループ作成
az group create --name $resourceGroup --location $location

# 2. DSCパッケージビルド
.\Build-DSCPackage.ps1

# 3. ストレージアカウント作成
az storage account create `
  --name $storageAccountName `
  --resource-group $resourceGroup `
  --location $location `
  --sku Standard_LRS

az storage container create `
  --name $containerName `
  --account-name $storageAccountName `
  --public-access blob `
  --auth-mode login

# 4. ファイルアップロード
az storage blob upload --account-name $storageAccountName --container-name $containerName --name "ConfigureIIS.zip" --file "ConfigureIIS.zip" --auth-mode login --overwrite
az storage blob upload --account-name $storageAccountName --container-name $containerName --name "index.html" --file "web-content\index.html" --auth-mode login --overwrite
az storage blob upload --account-name $storageAccountName --container-name $containerName --name "style.css" --file "web-content\style.css" --auth-mode login --overwrite

# 5. URL取得
$blobEndpoint = az storage account show --name $storageAccountName --resource-group $resourceGroup --query "primaryEndpoints.blob" --output tsv
$dscPackageUrl = "${blobEndpoint}${containerName}/ConfigureIIS.zip"
$blobStorageUrl = "${blobEndpoint}${containerName}"

# 6. デプロイ
az deployment group create `
  --resource-group $resourceGroup `
  --template-file main.bicep `
  --parameters location=$location `
               storageAccountName=$storageAccountName `
               adminUsername=$adminUsername `
               adminPassword=$adminPassword `
               dscPackageUrl=$dscPackageUrl `
               blobStorageUrl=$blobStorageUrl

# 7. パブリックIP取得
$publicIP = az network public-ip show --resource-group $resourceGroup --name pip-vm-bicep --query ipAddress --output tsv
Write-Host "`nWeb Server: http://${publicIP}:8080" -ForegroundColor Green
Start-Process "http://${publicIP}:8080"
```

## DSC拡張の動作原理

このプロジェクトでは、以下のようにDSCが自動的に実行されます：

1. **ローカルマシン**: `Build-DSCPackage.ps1` でDSC設定をコンパイルし、MOFファイルを含むzipパッケージを作成
2. **BLOBストレージ**: DSCパッケージとWebコンテンツをアップロード
3. **Bicepデプロイ**: VMを作成し、DSC拡張機能を自動インストール
4. **DSC拡張**: BLOBストレージからDSCパッケージをダウンロードし、VM上で自動実行
5. **IIS構成**: DSCがIISをインストールし、BLOBストレージからWebコンテンツをダウンロードして配置

**メリット**:
- 完全なInfrastructure as Code（IaC）
- 手動操作不要（RDP接続不要）
- 再現性と一貫性の確保
- 複数VM環境への展開が容易

## トラブルシューティング

### DSC拡張の状態確認

```powershell
# VM拡張のステータス確認
az vm extension show `
  --resource-group rg-bicep-vm `
  --vm-name vm-bicep `
  --name Microsoft.Powershell.DSC

# VM拡張のログ確認（RDP接続後、VM内で）
Get-Content "C:\WindowsAzure\Logs\Plugins\Microsoft.Powershell.DSC\*\*\*.log"
```

### DSC設定の確認（VM内）

```powershell
# DSCの現在の構成を確認
Get-DscConfiguration

# DSC構成のステータス確認
Get-DscConfigurationStatus

# IISのインストール状態確認
Get-WindowsFeature Web-Server
Get-Service W3SVC
```

### BLOBストレージへのアクセス確認

```powershell
# BLOBの一覧を表示
az storage blob list `
  --account-name $storageAccountName `
  --container-name $containerName `
  --auth-mode login `
  --output table

# BLOBのURLを確認（ブラウザでアクセス可能か確認）
$blobEndpoint = az storage account show --name $storageAccountName --query "primaryEndpoints.blob" --output tsv
Write-Host "${blobEndpoint}dsc-content/ConfigureIIS.zip"
Write-Host "${blobEndpoint}dsc-content/index.html"
```

## パラメータ

| パラメータ名 | 説明 | デフォルト値 |
|------------|------|------------|
| `location` | リソースのデプロイ先リージョン | `japaneast` |
| `adminUsername` | VM管理者ユーザー名 | 必須 |
| `adminPassword` | VM管理者パスワード | 必須 |
| `storageAccountName` | ストレージアカウント名（グローバルで一意） | 必須 |
| `vnetName` | 仮想ネットワーク名 | `vnet-bicep` |
| `nsgName` | NSG名 | `nsg-bicep` |
| `pipName` | パブリックIP名 | `pip-vm-bicep` |
| `nicName` | NIC名 | `nic-vm-bicep` |
| `vmName` | VM名 | `vm-bicep` |
| `dataDiskName` | データディスク名 | `disk-bicep` |
| `dscPackageUrl` | DSCパッケージのURL | 空（DSCをスキップ） |
| `blobStorageUrl` | BLOBストレージのベースURL | 空（Webコンテンツなし） |

## 出力

デプロイが成功すると、以下の情報が出力されます：

- `publicIPAddress`: VMのパブリックIPアドレス
- `vmName`: デプロイされたVM名
- `storageAccountName`: ストレージアカウント名
- `blobEndpoint`: BLOBストレージエンドポイント

## クリーンアップ

リソースグループを削除してすべてのリソースを削除：

```powershell
az group delete --name rg-bicep-vm --yes --no-wait
```

## セキュリティに関する注意

- パスワードは強力なものを使用してください（大文字、小文字、数字、特殊文字を含む12文字以上）
- BLOBストレージのコンテナはパブリックアクセスを許可していますが、本番環境ではSAS トークンやManaged Identityの使用を推奨します
- NSGルールは必要最小限に制限することを推奨します
- 機微情報をGitリポジトリにコミットしないよう注意してください
- 本番環境では、Azure Key VaultでシークレットとDSC構成を管理することを推奨します
