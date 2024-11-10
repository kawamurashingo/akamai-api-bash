#!/bin/bash

# .edgerc ファイルから変数を読み込む関数
BASE_URL="https://$(grep host $HOME/.edgerc | awk '{print $3}')"

# 出力ディレクトリを設定
OUTPUT_DIR="gtm_domains"

# 出力ディレクトリを作成
mkdir -p "$OUTPUT_DIR"

# 最大並列ジョブ数
MAX_JOBS=4

# バックグラウンドジョブの PID を格納する配列
declare -a JOB_PIDS=()

# 並列実行を管理する関数
wait_for_jobs() {
    while [ "${#JOB_PIDS[@]}" -ge "$MAX_JOBS" ]; do
        # 最初に終了したジョブを待つ
        wait -n
        # 終了したジョブの PID を配列から削除
        local tmp_pids=()
        for pid in "${JOB_PIDS[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                tmp_pids+=("$pid")
            fi
        done
        JOB_PIDS=("${tmp_pids[@]}")
    done
}

# GTM ドメインの情報を取得する関数
fetch_gtm_domain() {
    local DOMAIN_NAME="$1"

    echo "Processing GTM Domain: $DOMAIN_NAME"

    SAFE_DOMAIN_NAME=$(echo "$DOMAIN_NAME" | tr -d '[:cntrl:]/:*?"<>|')
    DOMAIN_DIR="$OUTPUT_DIR/${SAFE_DOMAIN_NAME// /_}"
    mkdir -p "$DOMAIN_DIR"

    # GTM ドメインの詳細情報を取得
    DOMAIN_JSON=$(./akamai_edgegrid.sh -X GET "$BASE_URL/config-gtm/v1/domains/$DOMAIN_NAME" 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$DOMAIN_JSON" ] || [ "$DOMAIN_JSON" == "null" ]; then
        echo "    GTM ドメイン $DOMAIN_NAME の詳細情報取得に失敗しました。"
        return
    fi

    # プロパティの情報を保存
    PROPERTIES=$(echo "$DOMAIN_JSON" | jq -c '.properties[]?')
    if [ -n "$PROPERTIES" ]; then
        echo "$PROPERTIES" | while read -r prop; do
            PROP_NAME=$(echo "$prop" | jq -r '.name')
            SAFE_PROP_NAME=$(echo "$PROP_NAME" | tr -d '[:cntrl:]/:*?"<>|')
            # JSON を整形して保存
            echo "$prop" | jq '.' > "$DOMAIN_DIR/$SAFE_PROP_NAME.json"
            echo "    Saved property $PROP_NAME to $DOMAIN_DIR/$SAFE_PROP_NAME.json"
        done
    fi
}

# GTM ドメインのリストを取得
DOMAINS_JSON=$(./akamai_edgegrid.sh -X GET "$BASE_URL/config-gtm/v1/domains" 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$DOMAINS_JSON" ] || [ "$DOMAINS_JSON" == "null" ]; then
    echo "GTM ドメインの取得に失敗しました。"
    exit 1
fi

# ドメイン名のリストを抽出
DOMAIN_NAMES=($(echo "$DOMAINS_JSON" | jq -r '.items[]? | .name'))

# 各 GTM ドメインを並列で処理
for DOMAIN_NAME in "${DOMAIN_NAMES[@]}"; do
    # 並列ジョブが制限を超えたら待機
    wait_for_jobs

    # ドメインの情報を取得
    fetch_gtm_domain "$DOMAIN_NAME" &
    JOB_PIDS+=("$!")
done

# すべてのジョブが完了するのを待つ
wait
