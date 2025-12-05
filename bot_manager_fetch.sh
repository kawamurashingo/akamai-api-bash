#!/bin/bash

# .edgerc ファイルから変数を読み込む関数
BASE_URL="https://$(grep host $HOME/.edgerc | awk '{print $3}')"

# 出力ディレクトリを設定
OUTPUT_DIR="bot_manager"

# 出力ディレクトリを作成
mkdir -p "$OUTPUT_DIR"

# Bot Manager 設定を取得する関数
fetch_bot_settings() {
    local CONFIG_ID="$1"
    local CONFIG_NAME="$2"
    local VERSION="$3"
    local ENV_LABEL="$4"

    if [ -z "$VERSION" ]; then
        echo "  ${ENV_LABEL}バージョンが存在しません。"
        return
    fi

    echo "  Processing ${ENV_LABEL} version $VERSION"

    SAFE_CONFIG_NAME=$(echo "$CONFIG_NAME" | tr -d '[:cntrl:]/:*?"<>|')
    ENV_DIR="$OUTPUT_DIR/${SAFE_CONFIG_NAME// /_}/$ENV_LABEL"
    mkdir -p "$ENV_DIR"

    POLICIES_JSON=$(./akamai_edgegrid.sh -X GET "$BASE_URL/appsec/v1/configs/$CONFIG_ID/versions/$VERSION/security-policies" 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$POLICIES_JSON" ] || [ "$POLICIES_JSON" == "null" ]; then
        echo "    セキュリティポリシーの取得に失敗しました。"
        return
    fi

    POLICY_ITEMS=$(echo "$POLICIES_JSON" | jq -c '.policies[]?, .securityPolicies[]?')

    echo "$POLICY_ITEMS" | while read -r policy_item; do
        POLICY_ID=$(echo "$policy_item" | jq -r '.policyId')
        POLICY_NAME=$(echo "$policy_item" | jq -r '.policyName // .name // "policy_$POLICY_ID"')

        SAFE_POLICY_NAME=$(echo "$POLICY_NAME" | tr -d '[:cntrl:]/:*?"<>|')
        OUTPUT_FILE="$ENV_DIR/${SAFE_POLICY_NAME// /_}.json"

        echo "    Fetching Bot Manager settings for policy $POLICY_NAME"

        SETTINGS_JSON=$(./akamai_edgegrid.sh -X GET "$BASE_URL/appsec/v1/configs/$CONFIG_ID/versions/$VERSION/security-policies/$POLICY_ID/protections/bot-management" 2>/dev/null)

        if [ $? -eq 0 ] && [ -n "$SETTINGS_JSON" ] && [ "$SETTINGS_JSON" != "null" ]; then
            echo "$SETTINGS_JSON" | jq '.' > "$OUTPUT_FILE"
            echo "      Saved to $OUTPUT_FILE"
        else
            echo "      ポリシー $POLICY_NAME の Bot Manager 設定取得に失敗しました。"
        fi
    done
}

# AppSec Config のリストを取得
CONFIGS_JSON=$(./akamai_edgegrid.sh -X GET "$BASE_URL/appsec/v1/configs" 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$CONFIGS_JSON" ] || [ "$CONFIGS_JSON" == "null" ]; then
    echo "AppSec Config の取得に失敗しました。"
    exit 1
fi

CONFIG_ITEMS=$(echo "$CONFIGS_JSON" | jq -c '.configurations[]?')

# 各 Config を処理
while read -r CONFIG_ITEM; do
    CONFIG_ID=$(echo "$CONFIG_ITEM" | jq -r '.configId')
    CONFIG_NAME=$(echo "$CONFIG_ITEM" | jq -r '.name')
    STAGING_VERSION=$(echo "$CONFIG_ITEM" | jq -r '.stagingVersion // empty')
    PRODUCTION_VERSION=$(echo "$CONFIG_ITEM" | jq -r '.productionVersion // empty')

    echo "Processing Config: $CONFIG_NAME (ID: $CONFIG_ID)"

    fetch_bot_settings "$CONFIG_ID" "$CONFIG_NAME" "$STAGING_VERSION" "staging"
    fetch_bot_settings "$CONFIG_ID" "$CONFIG_NAME" "$PRODUCTION_VERSION" "production"
done <<< "$CONFIG_ITEMS"
