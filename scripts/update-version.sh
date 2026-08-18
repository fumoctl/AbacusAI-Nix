#!/usr/bin/env nix-shell
#!nix-shell -i bash -p jq curl

set -euo pipefail

cd "$(dirname "$0")/.."

OUTPUT_JSON="artifacts/versions.json"

log_info() { echo -e "\033[0;32m[INFO]\033[0m $*" >&2; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }

mkdir -p artifacts
if [[ ! -f "$OUTPUT_JSON" ]]; then
    echo "{}" > "$OUTPUT_JSON"
fi

# 1. Fetch latest desktop version from github releases
log_info "Fetching latest Abacus AI Desktop version..."
AUTH_HEADER=()
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    AUTH_HEADER=(-H "Authorization: Bearer $GITHUB_TOKEN")
elif [[ -n "${GH_TOKEN:-}" ]]; then
    AUTH_HEADER=(-H "Authorization: Bearer $GH_TOKEN")
fi
DESKTOP_VER=$(curl -sL "${AUTH_HEADER[@]}" "https://api.github.com/repos/abacusai/deepagent-releases/releases/latest" | jq -r '.tag_name')

# 2. Fetch latest CLI version from API
log_info "Fetching latest Abacus AI CLI version..."
CLI_VER=$(curl -sL "https://apps.abacus.ai/api/v0/_getCodellmCliVersion?channel=latest" | jq -r '.result.version')

if [[ -z "$DESKTOP_VER" || "$DESKTOP_VER" == "null" ]]; then log_error "Failed to fetch Desktop version"; exit 1; fi
if [[ -z "$CLI_VER" || "$CLI_VER" == "null" ]]; then log_error "Failed to fetch CLI version"; exit 1; fi

get_hash() {
    local url=$1
    nix-prefetch-url --type sha256 "$url" || echo ""
}

# Process desktop app
process_desktop() {
    local current_url=$(jq -r '."AbacusAI Desktop"."x86_64-linux".url' "$OUTPUT_JSON" 2>/dev/null || echo "null")
    local current_version=$(echo "$current_url" | grep -oP 'download/\K[0-9.]+' || echo "unknown")

    if [[ "$current_version" == "$DESKTOP_VER" ]]; then
        log_info "AbacusAI Desktop is already at latest version ($DESKTOP_VER). Skipping..."
    else
        log_info "Updating AbacusAI Desktop to $DESKTOP_VER..."
        local platforms=(
            "x86_64-linux:x64"
            "aarch64-linux:arm64"
        )
        local payload="{}"
        for plat in "${platforms[@]}"; do
            IFS=':' read -r nix_os api_arch <<< "$plat"
            log_info "Prefetching hash for Desktop ($nix_os)..."
            local url="https://github.com/abacusai/deepagent-releases/releases/download/${DESKTOP_VER}/AbacusAIDesktop-linux-${api_arch}-${DESKTOP_VER}.AppImage"
            local hash=$(get_hash "$url")
            if [[ -z "$hash" ]]; then
                log_error "Failed to prefetch hash for $url"
                exit 1
            fi
            payload=$(echo "$payload" | jq --arg plat "$nix_os" --arg url "$url" --arg hash "$hash" \
                '.[$plat] = {url: $url, hash: $hash}')
        done
        local tmp_json=$(mktemp)
        jq --argjson payload "$payload" '.["AbacusAI Desktop"] = $payload' "$OUTPUT_JSON" > "$tmp_json"
        mv "$tmp_json" "$OUTPUT_JSON"
    fi
}

# Process CLI
process_cli() {
    local current_url=$(jq -r '."AbacusAI CLI"."x86_64-linux".url' "$OUTPUT_JSON" 2>/dev/null || echo "null")
    local current_version=$(echo "$current_url" | grep -oP 'releases/\K[0-9.]+' || echo "unknown")

    if [[ "$current_version" == "$CLI_VER" ]]; then
        log_info "AbacusAI CLI is already at latest version ($CLI_VER). Skipping..."
    else
        log_info "Updating AbacusAI CLI to $CLI_VER..."
        local platforms=(
            "x86_64-linux:x64"
            "aarch64-linux:arm64"
        )
        local payload="{}"
        for plat in "${platforms[@]}"; do
            IFS=':' read -r nix_os api_arch <<< "$plat"
            log_info "Prefetching hash for CLI ($nix_os)..."
            local url="https://static.abacus.ai/cli/releases/${CLI_VER}/abacusai-linux-${api_arch}.tar.gz"
            local hash=$(get_hash "$url")
            if [[ -z "$hash" ]]; then
                log_error "Failed to prefetch hash for $url"
                exit 1
            fi
            payload=$(echo "$payload" | jq --arg plat "$nix_os" --arg url "$url" --arg hash "$hash" \
                '.[$plat] = {url: $url, hash: $hash}')
        done
        local tmp_json=$(mktemp)
        jq --argjson payload "$payload" '.["AbacusAI CLI"] = $payload' "$OUTPUT_JSON" > "$tmp_json"
        mv "$tmp_json" "$OUTPUT_JSON"
    fi
}

process_desktop
process_cli

log_info "Done! Updated $OUTPUT_JSON"
