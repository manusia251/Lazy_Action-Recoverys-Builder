#!/bin/bash
#
# Skrip Build OrangeFox Recovery (diadaptasi untuk Cirrus CI)
#----------------------------------------------------------------

set -e # Menghentikan skrip jika ada perintah yang gagal

# --- 1. Mendapatkan Variabel dari Lingkungan Cirrus CI ---
echo "========================================"
echo "Memulai Build OrangeFox Recovery"
echo "----------------------------------------"
# Variabel yang diambil langsung dari .cirrus.yml
export MANIFEST_BRANCH="${MANIFEST_BRANCH}"
export DEVICE_TREE_URL="${DEVICE_TREE}"
export DEVICE_TREE_BRANCH="${DEVICE_BRANCH}"
export DEVICE_CODENAME="${DEVICE_CODENAME}"
export BUILD_TARGET="${TARGET_RECOVERY_IMAGE}"

# Variabel tambahan yang penting
WORKDIR=$(pwd)
export GITHUB_WORKSPACE=$WORKDIR
export VENDOR_NAME="infinix" # Ini nama folder produsen. Sesuaikan jika perlu.

echo "Manifest Branch   : ${MANIFEST_BRANCH}"
echo "Device Tree URL   : ${DEVICE_TREE_URL}"
echo "Device Branch     : ${DEVICE_TREE_BRANCH}"
echo "Device Codename   : ${DEVICE_CODENAME}"
echo "Build Target      : ${BUILD_TARGET}image"
echo "========================================"

# --- 2. Persiapan Lingkungan Build ---
echo "Persiapan lingkungan..."
cd ..
mkdir -p "$WORKDIR/twrp"
cd "$WORKDIR/twrp"

git config --global user.name "manusia251"
git config --global user.email "darkside@gmail.com"

# --- 3. Inisialisasi dan Konfigurasi Repo ---
echo "Inisialisasi manifest OrangeFox/TWRP..."
repo init -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git -b ${MANIFEST_BRANCH} --depth=1

# Membuat local manifest agar repo otomatis mengambil device tree
echo "Membuat local manifest untuk device tree..."
mkdir -p .repo/local_manifests
cat > .repo/local_manifests/twrp_device_tree.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
    <project name="${DEVICE_TREE_URL#https://github.com/}" path="device/${VENDOR_NAME}/${DEVICE_CODENAME}" remote="github" revision="${DEVICE_TREE_BRANCH}" />
</manifest>
EOF

# Melakukan sinkronisasi repo
echo "Sinkronisasi repositori. Ini mungkin butuh waktu..."
repo sync -j$(nproc) --force-sync --no-clone-bundle --no-tags --optimized-fetch --prune

# --- 4. Proses Kompilasi ---
echo "Memulai proses kompilasi..."
source build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true
export OF_PATH=${PWD}
export FOX_PATH=${PWD}
export RECOVERY_VARIANT=twrp

lunch twrp_${DEVICE_CODENAME}-eng
mka adbd ${BUILD_TARGET}image

# --- 5. Persiapan Hasil Build ---
echo "Menyiapkan hasil build..."
RESULT_DIR="$WORKDIR/twrp/out/target/product/${DEVICE_CODENAME}"
OUTPUT_DIR="$WORKDIR/output"
mkdir -p "$OUTPUT_DIR"

if [ -f "$RESULT_DIR/twrp.img" ] || ls $RESULT_DIR/twrp*.zip 1> /dev/null 2>&1; then
    echo "File output TWRP ditemukan. Menyalin ke direktori output..."
    cp -f "$RESULT_DIR/twrp.img" "$OUTPUT_DIR/" 2>/dev/null || true
    cp -f "$RESULT_DIR/twrp-*.zip" "$OUTPUT_DIR/" 2>/dev/null || true
    cp -f "$RESULT_DIR/${BUILD_TARGET}.img" "$OUTPUT_DIR/" 2>/dev/null || true
else
    echo "Peringatan: File output build tidak ditemukan di ${RESULT_DIR}"
fi

# --- 6. Selesai ---
echo "========================================"
echo "Build Selesai!"
echo "File hasil build telah disalin ke direktori 'output'."
ls -lh "$OUTPUT_DIR"
echo "========================================"
