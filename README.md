# Akamai API Bash Scripts

このリポジトリには、Akamai API を使用してプロパティ情報を取得し、ファイルに保存または一覧出力するための 3 つの Bash スクリプトが含まれています。

1. **GTM プロパティ取得スクリプト**
   - Akamai GTM（Global Traffic Management）のプロパティ情報を取得し、各プロパティを個別の JSON ファイルとして保存します。
2. **PAPI プロパティルール取得スクリプト**
   - Akamai PAPI（Property Manager API）を使用してプロパティのルール情報を取得し、ステージングおよびプロダクション環境の設定を JSON ファイルとして保存します。
3. **Bot Manager 設定一覧スクリプト**
   - AppSec の Security Policy 単位で Bot Manager（applyBotmanControls）が有効なホスト名を一覧出力します。

## 前提条件

- **Bash シェル環境**
- **`jq` コマンド**（JSON データを処理するため）
- **Akamai EdgeGrid 認証情報**が設定された `.edgerc` ファイル
- **`akamai_edgegrid.sh` スクリプト**（EdgeGrid 認証を行うため）

---

## 目次

- [ファイル構成](#ファイル構成)
- [セットアップ](#セットアップ)
  - [`jq` のインストール](#jq-のインストール)
  - [`.edgerc` ファイルの設定](#edgerc-ファイルの設定)
  - [`akamai_edgegrid.sh` の配置](#akamai_edgegridsh-の配置)
- [スクリプトの詳細](#スクリプトの詳細)
  - [1. GTM プロパティ取得スクリプト](#1-gtm-プロパティ取得スクリプト)
  - [2. PAPI プロパティルール取得スクリプト](#2-papi-プロパティルール取得スクリプト)
  - [3. Bot Manager 設定一覧スクリプト](#3-bot-manager-設定一覧スクリプト)
- [実行方法](#実行方法)
  - [GTM プロパティ取得スクリプトの実行](#gtm-プロパティ取得スクリプトの実行)
  - [PAPI プロパティルール取得スクリプトの実行](#papi-プロパティルール取得スクリプトの実行)
  - [Bot Manager 設定一覧スクリプトの実行](#bot-manager-設定一覧スクリプトの実行)
- [注意事項](#注意事項)
- [トラブルシューティング](#トラブルシューティング)
- [ライセンス](#ライセンス)

---

## ファイル構成

- `gtm_property_fetch.sh`：GTM プロパティ取得スクリプト
- `papi_property_fetch.sh`：PAPI プロパティルール取得スクリプト
- `list_botman_properties.sh`：Bot Manager 設定一覧スクリプト
- `akamai_edgegrid.sh`：Akamai EdgeGrid 認証を行うためのスクリプト
- `README.md`：このファイル

---

## セットアップ

### `jq` のインストール

**Ubuntu/Debian 系の場合**

```bash
sudo apt-get install jq
```

**CentOS/RHEL 系の場合**

```bash
sudo yum install jq
```

### `.edgerc` ファイルの設定
   - [認証情報の作成](https://techdocs.akamai.com/developer/docs/set-up-authentication-credentials)
   - スクリプトは、必要なAkamai API認証情報を含むホームディレクトリ（`$HOME/.edgerc`）内の`.edgerc`ファイルを必要とします。
   - `.edgerc` ファイルに `[default]` セクションが存在し、必要なアクセス情報（host、client_secret、client_token、access_token）が記載されていることを確認してください。
```
[default]
client_secret = C113nt53KR3TN6N90xxxxxxxxxxxxxxxxxxxxxN8eRN=
host = akab-xxxxxxxxxxxxxxxxxxx-kbob3i3v.luna.akamaiapis.net
access_token = akab-acc35t0k3nxxxxxxxxxxxxxxxx-gtm6ij
client_token = akab-c113ntt0k3xxxxxxxxxxxxxxxsl-yvsdj
```

- `your_client_token`、`your_client_secret`、`your_access_token`、`your_host` を自身の認証情報に置き換えてください。
- ファイルのパーミッションを適切に設定してください。

```bash
chmod 600 ~/.edgerc
```

### `akamai_edgegrid.sh` の配置

- このリポジトリ内の `akamai_edgegrid.sh` を使用するか、公式の EdgeGrid ライブラリやツールを使用してください。
- このスクリプトは、Akamai EdgeGrid 認証を行うために必要です。
- スクリプトを実行するディレクトリに配置してください。

---

## スクリプトの詳細

### 1. GTM プロパティ取得スクリプト

ファイル名：`gtm_property_fetch.sh`

#### 概要

- Akamai GTM の各ドメインからプロパティ情報を取得します。
- 各プロパティを個別の整形された JSON ファイルとして保存します。

#### 主な機能

- **GTM ドメインの一覧を取得**
- **各ドメインのプロパティ情報を取得**
- **プロパティ情報をファイルに保存**
- **並列処理による高速化**

#### 出力

- ディレクトリ名：`gtm_domains`
- 各ドメインごとにサブディレクトリが作成され、プロパティ名をファイル名とした JSON ファイルが保存されます。

#### スクリプトの一部

```bash
# 出力ディレクトリを設定
OUTPUT_DIR="gtm_domains"

# プロパティの情報を保存
echo "$prop" | jq '.' > "$DOMAIN_DIR/$SAFE_PROP_NAME.json"
```

### 2. PAPI プロパティルール取得スクリプト

ファイル名：`papi_property_fetch.sh`

#### 概要

- Akamai PAPI を使用して、各プロパティのルール情報を取得します。
- ステージングおよびプロダクション環境のルールを個別の JSON ファイルとして保存します。

#### 主な機能

- **グループと契約 ID の取得**
- **各プロパティのルール情報を取得**
- **ルール情報をファイルに保存**
- **並列処理による高速化**

#### 出力

- ディレクトリ名：`property`
- 各プロパティごとにサブディレクトリが作成され、`staging.json` と `production.json` ファイルが保存されます。

#### スクリプトの一部

```bash
# 出力ディレクトリを設定
OUTPUT_DIR="property"

# ステージングのルール情報を保存
echo "$STAGING_RULES_JSON" > "$DIR_NAME/staging.json"
```

### 3. Bot Manager 設定一覧スクリプト

ファイル名：`list_botman_properties.sh`

#### 概要

- AppSec 設定に紐づく Security Policy を走査し、Bot Manager（`applyBotmanControls`）が有効なホスト名を `property,applyBotmanControls(environment)` 形式で標準出力に一覧します。

#### 主な機能

- **Config の Security Policy を取得**（`staging` または `production` のいずれかを選択可能）
- **Policy 名に含まれるホスト名を抽出**
- **Bot Manager が有効なホストのみを CSV 形式で出力**
- **Config ID を指定して対象を絞り込み可能**

#### 出力

- 標準出力に `example.com,true` のような行を出力します。複数ホストがある場合はホストごとに行を分けます。

#### スクリプトの一部

```bash
echo "# property,applyBotmanControls(${ENV})"

# Config list
CONFIGS_JSON=$(./akamai_edgegrid.sh -X GET "$BASE_URL/appsec/v1/configs")
```

---

## 実行方法

### GTM プロパティ取得スクリプトの実行

1. スクリプトに実行権限を付与します。

   ```bash
   chmod +x gtm_property_fetch.sh
   ```

2. スクリプトを実行します。

   ```bash
   ./gtm_property_fetch.sh
   ```

3. 実行が完了すると、`gtm_domains` ディレクトリ内に各ドメインとプロパティの情報が保存されます。

### PAPI プロパティルール取得スクリプトの実行

1. スクリプトに実行権限を付与します。

   ```bash
   chmod +x papi_property_fetch.sh
   ```

2. スクリプトを実行します。

   ```bash
   ./papi_property_fetch.sh
   ```

3. 実行が完了すると、`property` ディレクトリ内に各プロパティのルール情報が保存されます。

### Bot Manager 設定一覧スクリプトの実行

1. スクリプトに実行権限を付与します。

   ```bash
   chmod +x list_botman_properties.sh
   ```

2. 環境（`staging` または `production`）や Config ID を必要に応じて指定して実行します。

   ```bash
   # 例1: ステージングの全 Config を確認
   ./list_botman_properties.sh

   # 例2: プロダクション環境のみ
   ./list_botman_properties.sh production

   # 例3: 特定の Config ID をプロダクションで確認
   ./list_botman_properties.sh 12345 production
   ```

3. 標準出力に Bot Manager が有効なホスト一覧が表示されます。リダイレクトしてファイル保存も可能です。

---

## 注意事項

- **API レート制限**

  - Akamai API のレート制限に注意してください。`MAX_JOBS` の値を調整することで、API へのリクエスト数を制御できます。

- **セキュリティ**

  - `.edgerc` ファイルには機密情報が含まれるため、適切なパーミッション設定（例：`chmod 600 ~/.edgerc`）を行ってください。
  - 認証情報が第三者に漏洩しないよう、取り扱いには十分ご注意ください。

- **依存関係**

  - これらのスクリプトは `jq` コマンドを使用しています。事前にインストールしてください。

- **`akamai_edgegrid.sh` の設定**

  - Akamai EdgeGrid 認証を正しく行うために、`akamai_edgegrid.sh` スクリプトが必要です。
  - このスクリプトが正しく動作するように、必要な設定や修正を行ってください。

---

## トラブルシューティング

- **認証エラーが発生する**

  - `.edgerc` ファイルの認証情報が正しいか確認してください。
  - `akamai_edgegrid.sh` スクリプトが正しく設定されているか確認してください。

- **`jq` が見つからない**

  - `jq` がインストールされているか確認し、インストールされていない場合は前述の方法でインストールしてください。

- **API リクエストがタイムアウトする**

  - ネットワーク接続を確認し、必要に応じて `MAX_JOBS` の値を減らして再試行してください。

- **スクリプトが途中で停止する**

  - エラーメッセージを確認し、必要に応じてデバッグ情報を追加して問題を特定してください。

---

## ライセンス

これらのスクリプトは自由に使用、変更、配布することができます。

---

**注**：これらのスクリプトはサンプルとして提供されており、運用環境で使用する際には十分なテストと検証を行ってください。
