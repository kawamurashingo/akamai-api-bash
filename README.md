# Akamai プロパティ取得スクリプト

このスクリプトは、Akamai API を使用して GTM（Global Traffic Management）のプロパティ情報を取得し、各プロパティを個別の整形された JSON ファイルとして保存します。

## 特徴

- **Akamai EdgeGrid 認証**：`akamai_edgegrid.sh` スクリプトを使用して、認証付きで API にアクセスします。
- **プロパティ情報の取得**：各 GTM ドメイン内のプロパティ情報を取得し、個別のファイルに保存します。
- **並列処理**：複数のドメインやプロパティを効率的に処理するために並列処理を実装しています。

## 前提条件

- **Bash シェル環境**
- **`jq` コマンド**（JSON データを処理するため）
- **Akamai EdgeGrid 認証情報**が設定された `.edgerc` ファイル
- **`akamai_edgegrid.sh` スクリプト**（EdgeGrid 認証を行うため）

## インストールと設定

### 1. `jq` のインストール

**Ubuntu/Debian 系の場合**

```bash
sudo apt-get install jq
```

**CentOS/RHEL 系の場合**

```bash
sudo yum install jq
```

### 2. `.edgerc` ファイルの設定

ホームディレクトリに `.edgerc` ファイルを作成し、以下の内容で認証情報を記述します。

```
client_token = your_client_token
client_secret = your_client_secret
access_token = your_access_token
host = your_host
```

- `your_client_token`、`your_client_secret`、`your_access_token`、`your_host` を自身の認証情報に置き換えてください。
- ファイルのパーミッションを適切に設定してください。

```bash
chmod 600 ~/.edgerc
```

### 3. `akamai_edgegrid.sh` スクリプトの配置

- このスクリプトと同じディレクトリに `akamai_edgegrid.sh` を配置します。
- このスクリプトは、Akamai EdgeGrid 認証を行うために必要です。
- 必要に応じて、公式の EdgeGrid ライブラリやツールを使用してください。

## スクリプトの実行方法

1. スクリプトに実行権限を付与します。

   ```bash
   chmod +x your_script_name.sh
   ```

2. スクリプトを実行します。

   ```bash
   ./your_script_name.sh
   ```

   - `your_script_name.sh` を実際のスクリプト名に置き換えてください。

3. 実行が完了すると、`gtm_domains` ディレクトリ内に各ドメインとプロパティの情報が保存されます。

## 出力結果

- `gtm_domains` ディレクトリが作成されます。
- 各 GTM ドメインごとにディレクトリが作成され、その中にプロパティ名をファイル名とした JSON ファイルが保存されます。
- JSON ファイルは整形されており、読みやすい形式になっています。

**ディレクトリ構造の例：**

```
gtm_domains/
├── example-domain1.com/
│   ├── property1.json
│   ├── property2.json
│   └── ...
├── example-domain2.net/
│   ├── propertyA.json
│   ├── propertyB.json
│   └── ...
└── ...
```

## スクリプトの詳細説明

### 環境変数と設定

- `BASE_URL`：`.edgerc` ファイルから取得した `host` を基に API のベース URL を設定します。
- `OUTPUT_DIR`：出力先のディレクトリを指定します（デフォルトは `gtm_domains`）。
- `MAX_JOBS`：同時に実行する最大ジョブ数を指定します。

### 主な処理の流れ

1. **GTM ドメインの一覧を取得**

   - API エンドポイント `/config-gtm/v1/domains` にリクエストを送り、ドメインのリストを取得します。

2. **各ドメインの詳細情報を取得**

   - 取得したドメイン名ごとに、詳細情報を取得します。

3. **プロパティ情報の抽出と保存**

   - ドメインの詳細情報から、各プロパティの情報を抽出します。
   - プロパティ名をファイル名として、整形された JSON ファイルを保存します。

4. **並列処理の管理**

   - バックグラウンドジョブの数を `MAX_JOBS` で制限し、効率的に処理します。

### ファイル名の安全性

- ファイル名に使用できない文字（制御文字や特殊文字）を除去しています。
- 必要に応じて、追加の文字除去やエンコーディングを実装してください。

## 注意事項

- **API レート制限**

  - Akamai API のレート制限に注意してください。`MAX_JOBS` の値を調整することで、API へのリクエスト数を制御できます。

- **セキュリティ**

  - `.edgerc` ファイルには機密情報が含まれるため、適切なパーミッション設定（例：`chmod 600 ~/.edgerc`）を行ってください。
  - 認証情報が第三者に漏洩しないよう、取り扱いには十分ご注意ください。

- **依存関係**

  - このスクリプトは `jq` コマンドを使用しています。事前にインストールしてください。

- **`akamai_edgegrid.sh` の設定**

  - Akamai EdgeGrid 認証を正しく行うために、`akamai_edgegrid.sh` スクリプトが必要です。
  - このスクリプトが正しく動作するように、必要な設定や修正を行ってください。

## トラブルシューティング

- **認証エラーが発生する**

  - `.edgerc` ファイルの認証情報が正しいか確認してください。
  - `akamai_edgegrid.sh` スクリプトが正しく設定されているか確認してください。

- **`jq` が見つからない**

  - `jq` がインストールされているか確認し、インストールされていない場合は前述の方法でインストールしてください。

- **API リクエストがタイムアウトする**

  - ネットワーク接続を確認し、必要に応じて `MAX_JOBS` の値を減らして再試行してください。

## ライセンス

このスクリプトは自由に使用、変更、配布することができます。
