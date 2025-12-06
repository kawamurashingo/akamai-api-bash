#!/bin/bash

# Function to load variables from the .edgerc file
CLIENT_TOKEN="$(grep client_token "$HOME/.edgerc" | awk '{print $3}')"
CLIENT_SECRET="$(grep client_secret "$HOME/.edgerc" | awk '{print $3}')"
ACCESS_TOKEN="$(grep access_token "$HOME/.edgerc" | awk '{print $3}')"
MAX_BODY=131072

# Function to encode HMAC-SHA256 in Base64
hmac_sha256_base64() {
    local data="$1"
    local key="$2"
    echo -n "$data" | openssl dgst -binary -sha256 -hmac "$key" | openssl base64 | tr -d '\n'
}

# Function to encode SHA256 in Base64
sha256_base64() {
    local data="$1"
    echo -n "$data" | openssl dgst -binary -sha256 | openssl base64 | tr -d '\n'
}

# Function to generate a timestamp
generate_timestamp() {
    date -u +"%Y%m%dT%H:%M:%S+0000"
}

# Function to generate a nonce (UUID)
generate_nonce() {
    uuidgen | tr -d '-'
}

# Function to create a signing key
create_signing_key() {
    local timestamp="$1"
    local client_secret="$2"
    hmac_sha256_base64 "$timestamp" "$client_secret"
}

# Function to generate a content hash
make_content_hash() {
    local method="$1"
    local body="$2"
    local max_body="$3"
    if [ "$method" = "POST" ] && [ -n "$body" ]; then
        local body_length=${#body}
        if [ "$body_length" -gt "$max_body" ]; then
            body="${body:0:$max_body}"
        fi
        sha256_base64 "$body"
    else
        echo ""
    fi
}

# Function to create data for signing
make_data_to_sign() {
    local method="$1"
    local scheme="$2"
    local host="$3"
    local path_query="$4"
    local headers="$5"
    local content_hash="$6"
    local auth_header="$7"
    echo -ne "$method\t$scheme\t$host\t$path_query\t$headers\t$content_hash\t$auth_header"
}

# Function to sign the request
sign_request() {
    local data_to_sign="$1"
    local signing_key="$2"
    hmac_sha256_base64 "$data_to_sign" "$signing_key"
}

# Function to create the authentication header
make_auth_header() {
    local client_token="$1"
    local access_token="$2"
    local timestamp="$3"
    local nonce="$4"
    local signature="$5"
    echo "EG1-HMAC-SHA256 client_token=$client_token;access_token=$access_token;timestamp=$timestamp;nonce=$nonce;signature=$signature"
}

# Function to parse the URL
parse_url() {
    local url="$1"
    scheme="$(echo "$url" | awk -F:// '{print $1}')"
    rest="$(echo "$url" | awk -F:// '{print $2}')"
    host="$(echo "$rest" | cut -d/ -f1)"
    path_query="/$(echo "$rest" | cut -d/ -f2-)"
}

main() {
    METHOD="GET"
    DATA=""
    HEADERS=()
    URL=""

    # parse args (簡易 curl ラッパ)
    while [[ $# -gt 0 ]]; do
        key="$1"
        case "$key" in
            -X)
                METHOD="$2"
                shift 2
                ;;
            -H)
                HEADERS+=("$2")
                shift 2
                ;;
            --data|-d)
                DATA="$2"
                shift 2
                ;;
            *)
                URL="$1"
                shift
                ;;
        esac
    done

    if [ -z "$URL" ]; then
        echo "Usage: $0 -X METHOD [-H 'Header: Value'] [--data 'DATA'] URL" >&2
        exit 1
    fi

    timestamp=$(generate_timestamp)
    nonce=$(generate_nonce)
    auth_header="EG1-HMAC-SHA256 client_token=$CLIENT_TOKEN;access_token=$ACCESS_TOKEN;timestamp=$timestamp;nonce=$nonce;"

    signing_key=$(create_signing_key "$timestamp" "$CLIENT_SECRET")

    parse_url "$URL"

    # Header normalization is omitted here
    canonicalized_headers=""

    content_hash=$(make_content_hash "$METHOD" "$DATA" "$MAX_BODY")

    data_to_sign=$(make_data_to_sign "$METHOD" "$scheme" "$host" "$path_query" "$canonicalized_headers" "$content_hash" "$auth_header")

    signature=$(sign_request "$data_to_sign" "$signing_key")

    auth_header=$(make_auth_header "$CLIENT_TOKEN" "$ACCESS_TOKEN" "$timestamp" "$nonce" "$signature")

    # curl 実行引数を配列で構築（サイレント -sS）
    curl_args=( -sS -X "$METHOD" -H "Authorization: $auth_header" )

    # ユーザ指定ヘッダもちゃんと付ける
    for h in "${HEADERS[@]}"; do
        curl_args+=( -H "$h" )
    done

    if [ "$METHOD" = "GET" ]; then
        curl "${curl_args[@]}" "$URL"
    elif [ "$METHOD" = "POST" ]; then
        curl "${curl_args[@]}" --data "$DATA" "$URL"
    else
        echo "Unsupported method: $METHOD" >&2
        exit 1
    fi
}

main "$@"

