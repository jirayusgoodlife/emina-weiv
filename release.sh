#!/usr/bin/env bash
# ==============================================================================
# Emina-Weiv (AnimeView) - Automatic Version Bump & GitHub Release Script
# ==============================================================================
set -euo pipefail

# Text colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${CYAN}${BOLD}======================================================${NC}"
echo -e "${CYAN}${BOLD}       Emina-Weiv Version Bump & GitHub Releaser      ${NC}"
echo -e "${CYAN}${BOLD}======================================================${NC}"

# 1. Check prerequisites
for cmd in git flutter gh; do
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${RED}Error: '$cmd' is not installed or not in PATH.${NC}"
        exit 1
    fi
done

# 2. Extract current version from pubspec.yaml
PUBSPEC="pubspec.yaml"
if [ ! -f "$PUBSPEC" ]; then
    echo -e "${RED}Error: pubspec.yaml not found.${NC}"
    exit 1
fi

CURRENT_RAW_VER=$(grep -E '^version:' "$PUBSPEC" | awk '{print $2}' | tr -d '"'\'' ')
if [ -z "$CURRENT_RAW_VER" ]; then
    echo -e "${RED}Error: Could not parse version from pubspec.yaml${NC}"
    exit 1
fi

CURRENT_VER="${CURRENT_RAW_VER%%+*}"
CURRENT_BUILD="${CURRENT_RAW_VER##*+}"
if [ "$CURRENT_BUILD" = "$CURRENT_RAW_VER" ]; then
    CURRENT_BUILD="1"
fi

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VER"
MAJOR=${MAJOR:-1}
MINOR=${MINOR:-0}
PATCH=${PATCH:-0}
CURRENT_BUILD=${CURRENT_BUILD:-1}

echo -e "Current Version: ${YELLOW}${BOLD}v${CURRENT_VER}${NC} (Build: ${YELLOW}${CURRENT_BUILD}${NC})"

# 3. Determine Bump Type
BUMP_TYPE="${1:-}"

if [ -z "$BUMP_TYPE" ]; then
    echo ""
    echo -e "${BOLD}Select version bump type:${NC}"
    echo -e "  ${GREEN}1) patch${NC}   -> v${MAJOR}.${MINOR}.$((PATCH + 1)) (Bug fixes / minor adjustments)"
    echo -e "  ${BLUE}2) minor${NC}   -> v${MAJOR}.$((MINOR + 1)).0 (New features / additions)"
    echo -e "  ${RED}3) major${NC}   -> v$((MAJOR + 1)).0.0 (Breaking changes / major overhaul)"
    echo -e "  ${YELLOW}4) current${NC} -> v${CURRENT_VER} (Keep current version and build/release now)"
    echo -e "  ${CYAN}5) custom${NC}  -> Enter a specific version"
    echo ""
    read -rp "Enter choice [1-5 or patch/minor/major/current]: " CHOICE

    case "$CHOICE" in
        1|patch)   BUMP_TYPE="patch" ;;
        2|minor)   BUMP_TYPE="minor" ;;
        3|major)   BUMP_TYPE="major" ;;
        4|current) BUMP_TYPE="current" ;;
        5|custom)  BUMP_TYPE="custom" ;;
        *)
            echo -e "${RED}Invalid choice. Exiting.${NC}"
            exit 1
            ;;
    esac
fi

NEW_MAJOR="$MAJOR"
NEW_MINOR="$MINOR"
NEW_PATCH="$PATCH"
NEW_BUILD="$CURRENT_BUILD"

case "$BUMP_TYPE" in
    patch)
        NEW_PATCH=$((PATCH + 1))
        NEW_BUILD=$((CURRENT_BUILD + 1))
        NEW_VER="${NEW_MAJOR}.${NEW_MINOR}.${NEW_PATCH}"
        ;;
    minor)
        NEW_MINOR=$((MINOR + 1))
        NEW_PATCH=0
        NEW_BUILD=$((CURRENT_BUILD + 1))
        NEW_VER="${NEW_MAJOR}.${NEW_MINOR}.${NEW_PATCH}"
        ;;
    major)
        NEW_MAJOR=$((MAJOR + 1))
        NEW_MINOR=0
        NEW_PATCH=0
        NEW_BUILD=$((CURRENT_BUILD + 1))
        NEW_VER="${NEW_MAJOR}.${NEW_MINOR}.${NEW_PATCH}"
        ;;
    current)
        NEW_VER="${CURRENT_VER}"
        NEW_BUILD="${CURRENT_BUILD}"
        ;;
    custom)
        read -rp "Enter custom version (e.g. 1.2.3): " CUSTOM_VER
        NEW_VER="${CUSTOM_VER#v}"
        NEW_BUILD=$((CURRENT_BUILD + 1))
        ;;
    *)
        # If user passed a specific version as argument, e.g. ./release.sh 1.0.1
        if [[ "$BUMP_TYPE" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            NEW_VER="${BUMP_TYPE#v}"
            if [ "$NEW_VER" != "$CURRENT_VER" ]; then
                NEW_BUILD=$((CURRENT_BUILD + 1))
            fi
        else
            echo -e "${RED}Unknown bump type: $BUMP_TYPE${NC}"
            exit 1
        fi
        ;;
esac

TAG_NAME="v${NEW_VER}"
echo ""
echo -e "Target Release: ${GREEN}${BOLD}${TAG_NAME}${NC} (Build: ${GREEN}${NEW_BUILD}${NC})"

# Check if tag already exists in local or remote git
if git rev-parse "$TAG_NAME" >/dev/null 2>&1 || git ls-remote --tags origin "$TAG_NAME" | grep -q "$TAG_NAME"; then
    echo -e "${YELLOW}Warning: Tag ${TAG_NAME} already exists.${NC}"
    if [ "$BUMP_TYPE" = "current" ]; then
        read -rp "Tag exists. Do you want to re-release/overwrite assets on GitHub for ${TAG_NAME}? [y/N]: " OVERWRITE
        if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
            echo "Aborting."
            exit 0
        fi
    else
        echo -e "${RED}Cannot recreate an existing tag. Please bump version. Aborting.${NC}"
        exit 1
    fi
fi

# 4. Update pubspec.yaml
echo -e "\n${CYAN}==> Updating pubspec.yaml to ${NEW_VER}+${NEW_BUILD}...${NC}"
sed -i -E "s/^version: .*/version: ${NEW_VER}+${NEW_BUILD}/" "$PUBSPEC"

# 5. Update UpdateService fallback if file exists
UPDATE_SERVICE="lib/services/update_service.dart"
if [ -f "$UPDATE_SERVICE" ]; then
    echo -e "${CYAN}==> Updating $UPDATE_SERVICE...${NC}"
    sed -i -E "s/return \{'versionName': '[^']+', 'versionCode': [0-9]+\};/return {'versionName': '${NEW_VER}', 'versionCode': ${NEW_BUILD}\};/" "$UPDATE_SERVICE"
fi

# 6. Ask for release notes / changelog
echo ""
RELEASE_TITLE="Release ${TAG_NAME}"
DEFAULT_NOTES="Emina-Weiv (AnimeView) ${TAG_NAME}

Changes in this release:
- Updates and improvements in version ${NEW_VER}
- Barcode/QR Camera scanner stability fixes
- Performance optimizations"

# If previous tag exists, get git commit summary
PREV_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [ -n "$PREV_TAG" ]; then
    COMMITS_LOG=$(git log "${PREV_TAG}..HEAD" --oneline --no-merges 2>/dev/null || true)
    if [ -n "$COMMITS_LOG" ]; then
        DEFAULT_NOTES="Emina-Weiv (AnimeView) ${TAG_NAME}

Commits since ${PREV_TAG}:
${COMMITS_LOG}"
    fi
fi

if [ -t 0 ]; then
    echo -e "${BOLD}Release Notes preview:${NC}"
    echo "------------------------------------------------------"
    echo "$DEFAULT_NOTES"
    echo "------------------------------------------------------"
    read -rp "Use this release note? [Y/n/custom]: " NOTE_CHOICE
    if [[ "$NOTE_CHOICE" =~ ^[Cc]$ ]]; then
        echo "Enter custom release notes (end with an empty line or EOF):"
        CUSTOM_NOTES=""
        while IFS= read -r line; do
            [ -z "$line" ] && break
            CUSTOM_NOTES+="$line"$'\n'
        done
        RELEASE_NOTES="${CUSTOM_NOTES:-$DEFAULT_NOTES}"
    else
        RELEASE_NOTES="$DEFAULT_NOTES"
    fi
else
    RELEASE_NOTES="$DEFAULT_NOTES"
fi

# 7. Run Unit Tests
echo -e "\n${CYAN}==> Running Flutter tests...${NC}"
flutter test

# 8. Build Release APK
echo -e "\n${CYAN}==> Building Release APK...${NC}"
flutter build apk --release

RELEASE_APK_SRC="build/app/outputs/flutter-apk/app-release.apk"
if [ ! -f "$RELEASE_APK_SRC" ]; then
    echo -e "${RED}Error: Release APK was not found at $RELEASE_APK_SRC${NC}"
    exit 1
fi

NAMED_APK="build/app/outputs/flutter-apk/emina-weiv-${TAG_NAME}.apk"
cp "$RELEASE_APK_SRC" "$NAMED_APK"

echo -e "${GREEN}✓ APK built successfully:${NC}"
echo -e "  - $RELEASE_APK_SRC"
echo -e "  - $NAMED_APK"

# 9. Git commit & Tag
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo -e "\n${CYAN}==> Committing changes and tagging ${TAG_NAME}...${NC}"

git add "$PUBSPEC" "$UPDATE_SERVICE" pubspec.lock android/app/build.gradle.kts android/app/src/main/AndroidManifest.xml android/app/proguard-rules.pro 2>/dev/null || true
if ! git diff --cached --quiet; then
    git commit -m "chore(release): bump version to ${TAG_NAME}"
fi

# Tag locally
if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
    git tag -d "$TAG_NAME" || true
fi
git tag -a "$TAG_NAME" -m "Release ${TAG_NAME}"

# Push to origin
echo -e "\n${CYAN}==> Pushing commits and tag to origin (${CURRENT_BRANCH})...${NC}"
git push origin "$CURRENT_BRANCH"
git push origin "$TAG_NAME" --force

# 10. Create or update GitHub Release
echo -e "\n${CYAN}==> Creating GitHub Release ${TAG_NAME}...${NC}"

if gh release view "$TAG_NAME" >/dev/null 2>&1; then
    echo "Updating existing release..."
    gh release edit "$TAG_NAME" --title "$RELEASE_TITLE" --notes "$RELEASE_NOTES"
    gh release upload "$TAG_NAME" "$RELEASE_APK_SRC" "$NAMED_APK" --clobber
else
    gh release create "$TAG_NAME" \
        "$RELEASE_APK_SRC" \
        "$NAMED_APK" \
        --title "$RELEASE_TITLE" \
        --notes "$RELEASE_NOTES"
fi

echo ""
echo -e "${GREEN}${BOLD}======================================================${NC}"
echo -e "${GREEN}${BOLD}  🎉 Successfully published ${TAG_NAME} to GitHub!   ${NC}"
echo -e "${GREEN}${BOLD}======================================================${NC}"
echo -e "URL: ${CYAN}https://github.com/jirayusgoodlife/emina-weiv/releases/tag/${TAG_NAME}${NC}"
