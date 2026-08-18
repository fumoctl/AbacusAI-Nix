#!/usr/bin/env nix-shell
#!nix-shell -i bash -p jq curl

set -euo pipefail

cd "$(dirname "$0")/.."

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "Checking Abacus AI versions..."
echo ""

VERSIONS_JSON="artifacts/versions.json"

if [[ ! -f "$VERSIONS_JSON" ]]; then
    echo -e "${RED}Error: $VERSIONS_JSON not found. Run update-version.sh first!${NC}"
    exit 1
fi

check_app() {
    local name="$1"
    local query_url="$2"

    echo "--- $name ---"

    local current
    current=$(jq -r ".\"$name\".\"x86_64-linux\".url" "$VERSIONS_JSON" 2>/dev/null || echo "")
    if [[ -z "$current" || "$current" == "null" ]]; then
        current="none"
    else
        # Extract version
        if [[ "$name" == "AbacusAI Desktop" ]]; then
            # URL like: https://github.com/abacusai/deepagent-releases/releases/download/1.106.22502/AbacusAIDesktop-linux-x64-1.106.22502.AppImage
            current=$(echo "$current" | grep -oP 'download/\K[0-9.]+' || echo "unknown")
        else
            # URL like: https://static.abacus.ai/cli/releases/2.6.0/abacusai-linux-x64.tar.gz
            current=$(echo "$current" | grep -oP 'releases/\K[0-9.]+' || echo "unknown")
        fi
    fi

    echo -e "Current version: $current"

    local latest=""
    if [[ "$name" == "AbacusAI Desktop" ]]; then
        local auth_header=()
        if [[ -n "${GITHUB_TOKEN:-}" ]]; then
            auth_header=(-H "Authorization: Bearer $GITHUB_TOKEN")
        elif [[ -n "${GH_TOKEN:-}" ]]; then
            auth_header=(-H "Authorization: Bearer $GH_TOKEN")
        fi
        latest=$(curl -sL "${auth_header[@]}" "https://api.github.com/repos/abacusai/deepagent-releases/releases/latest" | jq -r '.tag_name' 2>/dev/null || echo "")
    else
        latest=$(curl -sL "https://apps.abacus.ai/api/v0/_getCodellmCliVersion?channel=latest" | jq -r '.result.version' 2>/dev/null || echo "")
    fi

    if [[ -n "$latest" && "$latest" != "null" ]]; then
        echo -e "Latest version:  $latest"

        if [[ "$current" == "$latest" ]]; then
            echo -e "${GREEN}✓ Already at latest version!${NC}"
        else
            echo -e "${YELLOW}⚠ Update available!${NC}"
        fi
    else
        echo -e "${RED}Error: Could not parse version from upstream${NC}"
    fi
    echo ""
}

check_app "AbacusAI Desktop" ""
check_app "AbacusAI CLI" ""
