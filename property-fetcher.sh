#!/bin/bash

# .edgerc ファイルから変数を読み込む関数
BASE_URL="https://$(grep host $HOME/.edgerc | awk '{print $3}')"

# 出力ディレクトリを設定
OUTPUT_DIR="property"

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

# プロパティのルール情報を取得する関数
fetch_property() {
    local CONTRACT_ID="$1"
    local GROUP_ID="$2"
    local PROPERTY_ID="$3"
    local PROPERTY_NAME="$4"

    echo "  Processing Property: $PROPERTY_NAME (ID: $PROPERTY_ID)"

    SAFE_PROPERTY_NAME=$(echo "$PROPERTY_NAME" | tr -d '[:cntrl:]/:*?"<>|')
    DIR_NAME="$OUTPUT_DIR/${SAFE_PROPERTY_NAME// /_}"
    mkdir -p "$DIR_NAME"

    ACTIVATIONS_JSON=$(./akamai_edgegrid.sh -X GET "$BASE_URL/papi/v1/properties/$PROPERTY_ID/activations?contractId=$CONTRACT_ID&groupId=$GROUP_ID" 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$ACTIVATIONS_JSON" ] || [ "$ACTIVATIONS_JSON" == "null" ]; then
        echo "    プロパティ $PROPERTY_NAME のアクティベーション情報取得に失敗しました。"
        return
    fi

    # jqの配列アクセスに '?' を追加してエラーを回避
    STAGING_VERSION=$(echo "$ACTIVATIONS_JSON" | jq -r '
        [ (.activations.items[]? | select(.network=="STAGING" and .status=="ACTIVE")) ] 
        | sort_by(.updateDate) 
        | last 
        | .propertyVersion // empty')

    PRODUCTION_VERSION=$(echo "$ACTIVATIONS_JSON" | jq -r '
        [ (.activations.items[]? | select(.network=="PRODUCTION" and .status=="ACTIVE")) ] 
        | sort_by(.updateDate) 
        | last 
        | .propertyVersion // empty')

    if [ -n "$STAGING_VERSION" ]; then
        STAGING_RULES_JSON=$(./akamai_edgegrid.sh -X GET "$BASE_URL/papi/v1/properties/$PROPERTY_ID/versions/$STAGING_VERSION/rules?contractId=$CONTRACT_ID&groupId=$GROUP_ID" 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$STAGING_RULES_JSON" ] && [ "$STAGING_RULES_JSON" != "null" ]; then
            echo "$STAGING_RULES_JSON" > "$DIR_NAME/staging.json"
            echo "    Saved staging rules to $DIR_NAME/staging.json"
        else
            echo "    ステージングのルール情報取得に失敗しました。"
        fi
    else
        echo "    ステージング環境にアクティベートされていません。"
    fi

    if [ -n "$PRODUCTION_VERSION" ]; then
        PRODUCTION_RULES_JSON=$(./akamai_edgegrid.sh -X GET "$BASE_URL/papi/v1/properties/$PROPERTY_ID/versions/$PRODUCTION_VERSION/rules?contractId=$CONTRACT_ID&groupId=$GROUP_ID" 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$PRODUCTION_RULES_JSON" ] && [ "$PRODUCTION_RULES_JSON" != "null" ]; then
            echo "$PRODUCTION_RULES_JSON" > "$DIR_NAME/production.json"
            echo "    Saved production rules to $DIR_NAME/production.json"
        else
            echo "    プロダクションのルール情報取得に失敗しました。"
        fi
    else
        echo "    プロダクション環境にアクティベートされていません。"
    fi
}

# グループ情報を取得
GROUPS_JSON=$(./akamai_edgegrid.sh -X GET "$BASE_URL/papi/v1/groups" 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$GROUPS_JSON" ] || [ "$GROUPS_JSON" == "null" ]; then
    echo "グループ情報の取得に失敗しました。"
    exit 1
fi

# グループを一つずつ処理
GROUP_ITEMS=$(echo "$GROUPS_JSON" | jq -c '.groups.items[]')

# 各グループを処理
echo "$GROUP_ITEMS" | while read -r group_item; do
    GROUP_ID=$(echo "$group_item" | jq -r '.groupId')
    CONTRACT_IDS=$(echo "$group_item" | jq -r '.contractIds[]')

    # 各contractIdを処理
    for CONTRACT_ID in $CONTRACT_IDS; do

        # プロパティをページネーションを考慮して取得
        PROPERTIES_URL="$BASE_URL/papi/v1/properties?contractId=$CONTRACT_ID&groupId=$GROUP_ID"
        while [ -n "$PROPERTIES_URL" ]; do
            PROPERTIES_JSON=$(./akamai_edgegrid.sh -X GET "$PROPERTIES_URL" 2>/dev/null)

            if [ $? -ne 0 ] || [ -z "$PROPERTIES_JSON" ] || [ "$PROPERTIES_JSON" == "null" ]; then
                echo "Contract ID: $CONTRACT_ID, Group ID: $GROUP_ID のプロパティ取得に失敗しました。"
                break
            fi

            PROPERTY_ITEMS=$(echo "$PROPERTIES_JSON" | jq -c '.properties.items[]?')

            # 各プロパティを処理
            echo "$PROPERTY_ITEMS" | while read -r property_item; do
                PROPERTY_ID=$(echo "$property_item" | jq -r '.propertyId')
                PROPERTY_NAME=$(echo "$property_item" | jq -r '.propertyName')

                # 並列ジョブが制限を超えたら待機
                wait_for_jobs

                # 並列でプロパティを取得
                fetch_property "$CONTRACT_ID" "$GROUP_ID" "$PROPERTY_ID" "$PROPERTY_NAME" &
                JOB_PIDS+=("$!")
            done

            # 次のページのリンクを取得
            PROPERTIES_URL=$(echo "$PROPERTIES_JSON" | jq -r '.properties.links.next?')
            if [ "$PROPERTIES_URL" != "null" ] && [ -n "$PROPERTIES_URL" ]; then
                # 完全なURLにする
                PROPERTIES_URL="$BASE_URL$PROPERTIES_URL"
            else
                PROPERTIES_URL=""
            fi
        done

    done
done

# すべてのジョブが完了するのを待つ
wait
