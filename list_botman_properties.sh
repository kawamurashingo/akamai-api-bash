#!/bin/bash

BASE_URL="https://$(grep host "$HOME/.edgerc" | awk '{print $3}')"

TARGET_CONFIG_ID=""
ENV="staging"

# 引数解釈
# 1つ目の引数が staging / production なら環境、
# それ以外なら CONFIG_ID とみなす
if [ $# -ge 1 ]; then
  if [[ "$1" == "staging" || "$1" == "production" ]]; then
    ENV="$1"
  else
    TARGET_CONFIG_ID="$1"
  fi
fi

if [ $# -ge 2 ]; then
  ENV="$2"
fi

echo "# property,applyBotmanControls(${ENV})"

# Config list
CONFIGS_JSON=$(./akamai_edgegrid.sh -X GET "$BASE_URL/appsec/v1/configs")

echo "$CONFIGS_JSON" | jq -c '.configurations[]?' | while read CONFIG_ITEM; do
  CONFIG_ID=$(echo "$CONFIG_ITEM"   | jq -r '.id // .configId')
  CONFIG_NAME=$(echo "$CONFIG_ITEM" | jq -r '.name')

  # CONFIG_ID 指定がある場合はそれだけ
  if [ -n "$TARGET_CONFIG_ID" ] && [ "$CONFIG_ID" != "$TARGET_CONFIG_ID" ]; then
    continue
  fi

  if [ "$ENV" = "staging" ]; then
    VERSION=$(echo "$CONFIG_ITEM" | jq -r '.stagingVersion // empty')
  else
    VERSION=$(echo "$CONFIG_ITEM" | jq -r '.productionVersion // empty')
  fi

  [ -z "$VERSION" ] && continue

  POLICIES_JSON=$(./akamai_edgegrid.sh -X GET \
    "$BASE_URL/appsec/v1/configs/$CONFIG_ID/versions/$VERSION/security-policies")

  echo "$POLICIES_JSON" \
    | jq -r '.policies[]? | "\(.policyId) \(.policyName)"' \
    | while read PID PNAME; do
        HOSTS=$(echo "$PNAME" \
          | grep -Eo '\b[A-Za-z0-9*.-]+\.[A-Za-z]{2,}\b' \
          | sort -u)

        # ホスト名が1つも見つからなければスキップ
        [ -z "$HOSTS" ] && continue

        VALUE=$(./akamai_edgegrid.sh -X GET \
          "$BASE_URL/appsec/v1/configs/$CONFIG_ID/versions/$VERSION/security-policies/$PID/protections" \
          | jq -r '.applyBotmanControls // false')

        # Bot Manager ON のものだけ出したいので true のみ
        [ "$VALUE" != "true" ] && continue

        # 1ポリシーに複数ホスト名があれば1行ずつ
        for host in $HOSTS; do
          echo "${host},${VALUE}"
        done
      done
done

