#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PLUGIN_NAME="DynamicArmorVariants"
MOD_NAME="Dynamic Armor Variants Extended"
MOD_AUTHOR="Parapets, PenguinToast"
MOD_DESCRIPTION="Framework for mods to define armor variants by swapping armor addons dynamically at runtime."
DIST_DIR="${REPO_ROOT}/dist"
STAGE_DIR="${DIST_DIR}/.stage"

BUILD_DLL="${REPO_ROOT}/build_cross/${PLUGIN_NAME}.dll"
BUILD_PDB="${REPO_ROOT}/build_cross/${PLUGIN_NAME}.pdb"
PEX_DIR="${PEX_DIR:-/Volumes/S512/CrossOver/Modding/SSEAE/mods/Dynamic Armor Variants Extended/Scripts}"

# Determine version
SEMVER_REGEX='^v?([0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?)$'
HEAD_TAG=""
while IFS= read -r tag; do
    if [[ "${tag}" =~ ${SEMVER_REGEX} ]]; then
        HEAD_TAG="${tag}"
        break
    fi
done < <(git -C "${REPO_ROOT}" tag --points-at HEAD 2>/dev/null || true)

SHORT_SHA="$(git -C "${REPO_ROOT}" rev-parse --short HEAD)"

if [[ -n "${VERSION:-}" ]]; then
    # Use explicitly passed VERSION
    VERSION="${VERSION#v}"
elif [[ -n "${HEAD_TAG}" ]]; then
    VERSION="${HEAD_TAG#v}"
else
    LAST_TAG=""
    while IFS= read -r tag; do
        if [[ "${tag}" =~ ${SEMVER_REGEX} ]]; then
            LAST_TAG="${tag}"
            break
        fi
    done < <(git -C "${REPO_ROOT}" tag --sort=-version:refname 2>/dev/null || true)
    
    if [[ -z "${LAST_TAG}" ]]; then
        BASE_VERSION="1.8.0"
    else
        BASE_VERSION="${LAST_TAG#v}"
    fi
    VERSION="${BASE_VERSION}-dev+${SHORT_SHA}"
fi

ARCHIVE_NAME="${MOD_NAME} v${VERSION}.zip"
ARCHIVE_PATH="${DIST_DIR}/${ARCHIVE_NAME}"

echo "Packaging version: ${VERSION}"
echo "Archive destination: ${ARCHIVE_PATH}"

if [[ ! -f "${BUILD_DLL}" ]]; then
    echo "Error: DLL not found at ${BUILD_DLL}. Build it first." >&2
    exit 1
fi

if [[ ! -d "${PEX_DIR}" ]]; then
    echo "Error: PEX directory not found at ${PEX_DIR}." >&2
    exit 1
fi

# Clean and stage
rm -rf "${STAGE_DIR}"
mkdir -p \
    "${STAGE_DIR}/Data/Scripts" \
    "${STAGE_DIR}/Data/Source/Scripts" \
    "${STAGE_DIR}/Data/SKSE/Plugins" \
    "${STAGE_DIR}/Data/SKSE/Plugins/DynamicArmorVariants" \
    "${STAGE_DIR}/SkillLevelingHookEnabled" \
    "${STAGE_DIR}/UIExtensions_Menu/Interface/Translations" \
    "${STAGE_DIR}/UIExtensions_Menu/MCM/Config/DynamicArmorMenu" \
    "${STAGE_DIR}/UIExtensions_Menu/Scripts" \
    "${STAGE_DIR}/UIExtensions_Menu/Source/Scripts" \
    "${STAGE_DIR}/HiddenEquipment/Interface/Translations" \
    "${STAGE_DIR}/HiddenEquipment/SKSE/Plugins/DynamicArmorVariants" \
    "${STAGE_DIR}/fomod"

# 1. Copy FOMOD base data
cp -R "${REPO_ROOT}/data/fomod/." "${STAGE_DIR}/fomod/"

# 2. Stage core plugin DLL & PDB
cp "${BUILD_DLL}" "${STAGE_DIR}/Data/SKSE/Plugins/${PLUGIN_NAME}.dll"
if [[ -f "${BUILD_PDB}" ]]; then
    cp "${BUILD_PDB}" "${STAGE_DIR}/Data/SKSE/Plugins/${PLUGIN_NAME}.pdb"
fi
cp "${REPO_ROOT}/data/SKSE/Plugins/DynamicArmorVariants/settings.json" \
    "${STAGE_DIR}/Data/SKSE/Plugins/DynamicArmorVariants/"

# 3. Stage SkillLeveling option
cp -R "${REPO_ROOT}/installer/SkillLevelingHookEnabled/." \
    "${STAGE_DIR}/SkillLevelingHookEnabled/"

# 4. Stage Core Papyrus scripts
cp "${PEX_DIR}/DynamicArmor.pex" "${STAGE_DIR}/Data/Scripts/"
cp "${REPO_ROOT}/scripts/DynamicArmor.psc" "${STAGE_DIR}/Data/Source/Scripts/"

# 5. Stage UIExtensions Menu option
cp "${PEX_DIR}/DynamicArmor_MCM.pex" "${STAGE_DIR}/UIExtensions_Menu/Scripts/"
cp "${PEX_DIR}/DynamicArmor_Menu.pex" "${STAGE_DIR}/UIExtensions_Menu/Scripts/"
cp "${PEX_DIR}/DynamicArmor_MenuPower.pex" "${STAGE_DIR}/UIExtensions_Menu/Scripts/"
cp "${REPO_ROOT}/scripts/DynamicArmor_MCM.psc" "${STAGE_DIR}/UIExtensions_Menu/Source/Scripts/"
cp "${REPO_ROOT}/scripts/DynamicArmor_Menu.psc" "${STAGE_DIR}/UIExtensions_Menu/Source/Scripts/"
cp "${REPO_ROOT}/scripts/DynamicArmor_MenuPower.psc" "${STAGE_DIR}/UIExtensions_Menu/Source/Scripts/"

cp "${REPO_ROOT}/data/DynamicArmorMenu.esp" "${STAGE_DIR}/UIExtensions_Menu/"
cp "${REPO_ROOT}/data/Interface/Translations/DynamicArmorMenu_ENGLISH.txt" \
    "${STAGE_DIR}/UIExtensions_Menu/Interface/Translations/"
cp -R "${REPO_ROOT}/data/MCM/Config/DynamicArmorMenu/." \
    "${STAGE_DIR}/UIExtensions_Menu/MCM/Config/DynamicArmorMenu/"

# 6. Stage Hidden Equipment option
cp "${REPO_ROOT}/data/DAV_HiddenEquipment.esp" "${STAGE_DIR}/HiddenEquipment/"
cp "${REPO_ROOT}/data/Interface/Translations/DAV_HiddenEquipment_ENGLISH.txt" \
    "${STAGE_DIR}/HiddenEquipment/Interface/Translations/"
cp "${REPO_ROOT}/data/SKSE/Plugins/DynamicArmorVariants/DAV_HiddenEquipment.json" \
    "${STAGE_DIR}/HiddenEquipment/SKSE/Plugins/DynamicArmorVariants/"

# 7. Convert FOMOD xml files to clean UTF-8
python3 - <<'PY' "${STAGE_DIR}/fomod"
from pathlib import Path
import sys

fomod_dir = Path(sys.argv[1])
if fomod_dir.is_dir():
    for xml_path in fomod_dir.glob("*.xml"):
        raw = xml_path.read_bytes()
        text = None
        if raw.startswith(b"\xff\xfe\xef\xbb\xbf"):
            text = raw[2:].decode("utf-8-sig")
        for encoding in ("utf-8-sig", "utf-16", "utf-16-le", "utf-16-be"):
            if text is not None:
                break
            try:
                text = raw.decode(encoding)
                break
            except UnicodeDecodeError:
                continue
        if text is None:
            raise SystemExit(f"Could not decode {xml_path}")
        xml_path.write_text(text.lstrip("\ufeff"), encoding="utf-8", newline="\n")
PY

REMOTE_URL="$(git -C "${REPO_ROOT}" remote get-url origin 2>/dev/null || echo "https://github.com/kxgcayh/DynamicArmorVariants-Extended")"
if [[ "${REMOTE_URL}" =~ ^git@github\.com:(.+)/(.+)\.git$ ]]; then
    REMOTE_URL="https://github.com/${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
fi

cat > "${STAGE_DIR}/fomod/info.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<fomod>
  <Name>${MOD_NAME}</Name>
  <Author>${MOD_AUTHOR}</Author>
  <Version>${VERSION}</Version>
  <Website>${REMOTE_URL}</Website>
  <Description>${MOD_DESCRIPTION}</Description>
</fomod>
EOF

# 8. Create Zip package
mkdir -p "${DIST_DIR}"
rm -f "${ARCHIVE_PATH}"

(cd "${STAGE_DIR}" && zip -r -q "${ARCHIVE_PATH}" .)

rm -rf "${STAGE_DIR}"

echo "Successfully created package: ${ARCHIVE_PATH}"
