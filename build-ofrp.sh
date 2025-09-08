#!/bin/bash
#
# Skrip untuk Build OrangeFox Recovery
# Didesain untuk dijalankan di dalam lingkungan CI seperti Cirrus CI.
# Skrip ini menerima parameter build melalui argumen command-line.
#----------------------------------------------------------------

# Keluar jika ada perintah yang gagal
set -e

# --- Validasi Argumen Input ---
if [ "$#" -ne 5 ]; then
    echo "Penggunaan: $0 <DEVICE_TREE_URL> <DEVICE_TREE_BRANCH> <DEVICE_CODENAME> <MANIFEST_BRANCH> <BUILD_TARGET>"
    echo "Contoh: $0 https://github.com/user/android_device_xiaomi_vince.git main vince 11.0 recovery"
    exit 1
fi

# --- Menetapkan Variabel dari Argumen ---
# Ini menggantikan bagian "inputs" atau variabel yang di-hardcode.
export DEVICE_TREE="$1"
export DEVICE_TREE_BRANCH="$2"
# Argumen ke-3 (DEVICE_CODENAME) diabaikan, karena skrip akan mendeteksinya secara otomatis dari device tree untuk konsistensi.
export MANIFEST_BRANCH_INPUT="$4"
export BUILD_TARGET="$5"

# --- Proses Variabel ---
# Menghapus prefix "fox_" dari MANIFEST_BRANCH jika ada, agar sesuai dengan format yang diharapkan (misal: "11.0")
export MANIFEST_BRANCH=$(echo "$MANIFEST_BRANCH_INPUT" | sed 's/^fox_//')

#----------------------------------------------------------------

# Variabel Global
WORKDIR=$(pwd)
export GITHUB_WORKSPACE=$WORKDIR # Menyimulasikan variabel GITHUB_WORKSPACE

# --- MULAI PROSES UTAMA ---

echo "Memulai build OrangeFox Recovery..."
echo "----------------------------------------"
echo "Manifest Branch : $MANIFEST_BRANCH"
echo "Device Tree     : $DEVICE_TREE"
echo "Device Branch   : $DEVICE_TREE_BRANCH"
echo "Build Target    : ${BUILD_TARGET}image"
echo "----------------------------------------"

# 1. Persiapan Lingkungan Build (diasumsikan sudah diinstal oleh CI runner)
echo "Lingkungan build diasumsikan sudah siap."

# 2. Pengaturan Manifest OrangeFox
echo "Mengatur manifest OrangeFox..."
# Skrip ini dieksekusi dari dalam direktori 'builder', jadi kita keluar satu level untuk membuat direktori OrangeFox
cd ..
mkdir -p "$WORKDIR/OrangeFox"
cd "$WORKDIR/OrangeFox"

# Git config sudah diatur oleh CI runner, langkah ini untuk memastikan
git config --global user.name "manusia251"
git config --global user.email "darkside@gmail.com"

git clone https://gitlab.com/OrangeFox/sync.git

if [ "$MANIFEST_BRANCH" == "11.0" ] || [ "$MANIFEST_BRANCH" == "12.1" ]; then
    echo "Syncing branch modern: fox_${MANIFEST_BRANCH}"
    export CHECK_LEGACY_BRANCH="false"
    cd sync
    ./orangefox_sync.sh --branch "$MANIFEST_BRANCH" --path "$WORKDIR/OrangeFox/fox_${MANIFEST_BRANCH}"
else
    echo "Syncing branch legacy: fox_${MANIFEST_BRANCH}"
    export CHECK_LEGACY_BRANCH="true"
    cd sync/legacy
    ./orangefox_sync_legacy.sh --branch "$MANIFEST_BRANCH" --path "$WORKDIR/OrangeFox/fox_${MANIFEST_BRANCH}"
fi

# 3. Clone Device Tree
cd "$WORKDIR/OrangeFox/fox_${MANIFEST_BRANCH}"
echo "Cloning device tree..."
git clone "$DEVICE_TREE" -b "$DEVICE_TREE_BRANCH" ./device_tree
cd device_tree
export COMMIT_ID=$(git rev-parse HEAD)
echo "Commit ID Device Tree: $COMMIT_ID"

# 4. Ekstraksi Variabel dari File .mk
echo "Mengekstrak variabel dari file .mk..."
cd "$WORKDIR/OrangeFox/fox_${MANIFEST_BRANCH}/device_tree"
DEVICE_MAKEFILE=""
DEVICE_DIRECTORY=""
DEVICE_NAME=""
for file in *.mk; do
    makefile=$(sed -n 's/^[[:space:]]*PRODUCT_NAME[[:space:]]*:=\s*\(.*\)/\1/p' "$file")
    brand=$(sed -n 's/^[[:space:]]*PRODUCT_BRAND[[:space:]]*:=\s*\(.*\)/\1/p' "$file")
    codename=$(sed -n 's/^[[:space:]]*PRODUCT_DEVICE[[:space:]]*:=\s*\(.*\)/\1/p' "$file")
    if [[ -n "$makefile" && -n "$brand" && -n "$codename" ]]; then
        export DEVICE_MAKEFILE="$makefile"
        export DEVICE_DIRECTORY="device/$brand"
        export DEVICE_NAME="$codename"
        echo "   -> Device Name ditemukan: $DEVICE_NAME"
        echo "   -> Device Brand ditemukan: $brand"
        break
    fi
done
cd ../
mkdir -p "$DEVICE_DIRECTORY"
mv device_tree "$DEVICE_DIRECTORY"/"$DEVICE_NAME"
echo "Device tree dipindahkan ke: $DEVICE_DIRECTORY/$DEVICE_NAME"

# 5. Instalasi Python 2 untuk Build Legacy (diasumsikan sudah diinstal oleh CI jika perlu)
if [ "$CHECK_LEGACY_BRANCH" == "true" ]; then
    echo "Build legacy terdeteksi. Pastikan Python 2 sudah terinstal di lingkungan CI."
fi

# 6. Proses Build
echo "Memulai proses kompilasi..."
cd "$WORKDIR/OrangeFox/fox_${MANIFEST_BRANCH}"
source build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true

if [ "$MANIFEST_BRANCH" == "11.0" ] || [ "$MANIFEST_BRANCH" == "12.1" ]; then
    lunch twrp_${DEVICE_NAME}-eng && make clean && mka adbd ${BUILD_TARGET}image
else
    lunch omni_${DEVICE_NAME}-eng && make clean && mka ${BUILD_TARGET}image
fi

# 7. Persiapan Hasil Build untuk Artifacts
echo "Memeriksa dan menyiapkan hasil build untuk artifacts..."
RESULT_DIR="$WORKDIR/OrangeFox/fox_${MANIFEST_BRANCH}/out/target/product/${DEVICE_NAME}"
OUTPUT_DIR="$WORKDIR/output" # Direktori output untuk artifacts CI
mkdir -p "$OUTPUT_DIR"

if [ -f $RESULT_DIR/OrangeFox*.img ] || [ -f $RESULT_DIR/OrangeFox*.zip ]; then
    echo "File output ditemukan. Menyalin ke direktori output..."
    cp -f $RESULT_DIR/OrangeFox*.img "$OUTPUT_DIR/" 2>/dev/null || true
    cp -f $RESULT_DIR/OrangeFox*.zip "$OUTPUT_DIR/" 2>/dev/null || true
    cp -f $RESULT_DIR/${BUILD_TARGET}.img "$OUTPUT_DIR/" 2>/dev/null || true
else
    echo "Peringatan: File output build (img atau zip) tidak ditemukan di $RESULT_DIR"
fi

# 8. Selesai
echo "--------------------------------------------------"
echo "Build Selesai!"
echo "File hasil build telah disalin ke direktori 'output' untuk diunggah sebagai artifacts."
ls -lh "$OUTPUT_DIR"
echo "--------------------------------------------------"
