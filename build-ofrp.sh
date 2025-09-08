#!/bin/bash
#
# Skrip untuk Build TWRP Recovery
# Didesain untuk dijalankan di dalam lingkungan CI seperti Cirrus CI.
# Skrip ini menerima parameter build melalui argumen command-line.
#----------------------------------------------------------------

# Keluar jika ada perintah yang gagal
set -e

# --- Validasi Argumen Input ---
if [ "$#" -ne 5 ]; then
    echo "Penggunaan: $0 <DEVICE_TREE_URL> <DEVICE_TREE_BRANCH> <DEVICE_CODENAME> <MANIFEST_BRANCH> <BUILD_TARGET>"
    echo "Contoh: $0 https://github.com/user/android_device_xiaomi_vince.git main vince android-11 recovery"
    exit 1
fi

# --- Menetapkan Variabel dari Argumen ---
export DEVICE_TREE="$1"
export DEVICE_TREE_BRANCH="$2"
export DEVICE_CODENAME="$3"
export MANIFEST_BRANCH="$4"
export BUILD_TARGET="$5"

#----------------------------------------------------------------

# Variabel Global
WORKDIR=$(pwd)
export GITHUB_WORKSPACE=$WORKDIR # Menyimulasikan variabel GITHUB_WORKSPACE

# --- MULAI PROSES UTAMA ---

echo "Memulai build TWRP Recovery..."
echo "----------------------------------------"
echo "Manifest Branch : $MANIFEST_BRANCH"
echo "Device Tree     : $DEVICE_TREE"
echo "Device Branch   : $DEVICE_TREE_BRANCH"
echo "Build Target    : ${BUILD_TARGET}image"
echo "----------------------------------------"

# 1. Persiapan Lingkungan Build (diasumsikan sudah diinstal oleh CI runner)
echo "Lingkungan build diasumsikan sudah siap."

# 2. Pengaturan Manifest TWRP
echo "Mengatur manifest TWRP..."
cd ..
mkdir -p "$WORKDIR/twrp"
cd "$WORKDIR/twrp"

# Git config
git config --global user.name "manusia251"
git config --global user.email "darkside@gmail.com"

# --- PERHATIAN: Ini bagian yang diperbaiki! ---
# Kita harus clone manifest TWRP dari repositori yang benar, bukan dari device tree kamu.
# Repositori manifest TWRP ada di GitHub TheMuppets.

echo "Cloning manifest TWRP dari TheMuppets..."
git clone --depth=1 --single-branch https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git -b "${MANIFEST_BRANCH}" .

# 3. Clone Device Tree
# --- PERHATIAN: Ini bagian yang diperbaiki juga! ---
# Clone device tree dari repositori kamu sendiri.

echo "Cloning device tree..."
mkdir -p "device/${DEVICE_CODENAME}/"
cd "device/${DEVICE_CODENAME}/"
git clone --depth=1 --single-branch "$DEVICE_TREE" -b "$DEVICE_TREE_BRANCH" .
cd ..
cd ..

export COMMIT_ID=$(git rev-parse HEAD)
echo "Commit ID Device Tree: $COMMIT_ID"

# 4. Proses Build
echo "Memulai proses kompilasi..."
source build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true
export RECOVERY_VARIANT=twrp

lunch twrp_${DEVICE_CODENAME}-eng
make clean && mka adbd ${BUILD_TARGET}image

# 5. Persiapan Hasil Build untuk Artifacts
echo "Memeriksa dan menyiapkan hasil build untuk artifacts..."
RESULT_DIR="$WORKDIR/twrp/out/target/product/${DEVICE_CODENAME}"
OUTPUT_DIR="$WORKDIR/output"
mkdir -p "$OUTPUT_DIR"

if [ -f "$RESULT_DIR/twrp.img" ] || [ -f "$RESULT_DIR/twrp*.zip" ]; then
    echo "File output TWRP ditemukan. Menyalin ke direktori output..."
    cp -f "$RESULT_DIR/twrp.img" "$OUTPUT_DIR/" 2>/dev/null || true
    cp -f "$RESULT_DIR/twrp-*.zip" "$OUTPUT_DIR/" 2>/dev/null || true
    cp -f "$RESULT_DIR/${BUILD_TARGET}.img" "$OUTPUT_DIR/" 2>/dev/null || true
else
    echo "Peringatan: File output build (img atau zip) tidak ditemukan di $RESULT_DIR"
fi

# 6. Selesai
echo "--------------------------------------------------"
echo "Build Selesai!"
echo "File hasil build telah disalin ke direktori 'output' untuk diunggah sebagai artifacts."
ls -lh "$OUTPUT_DIR"
echo "--------------------------------------------------"
