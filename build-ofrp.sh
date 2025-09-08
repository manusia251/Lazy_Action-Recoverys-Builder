#!/bin/bash
#
# Skrip Build OrangeFox Recovery - VERSI OTOMATIS FINAL
# Skrip ini mengotomatiskan semua langkah yang diperlukan.
# =================================================================

set -e

# --- 1. Mengambil Variabel Lingkungan ---
echo "========================================"
echo "Memulai Build OrangeFox Recovery"
echo "----------------------------------------"
export MANIFEST_BRANCH="${MANIFEST_BRANCH}"
export DEVICE_TREE_URL="${DEVICE_TREE}"
export DEVICE_TREE_BRANCH="${DEVICE_BRANCH}"
export DEVICE_CODENAME="${DEVICE_CODENAME}"
export BUILD_TARGET="${TARGET_RECOVERY_IMAGE}"

echo "Manifest Branch   : ${MANIFEST_BRANCH}"
echo "Device Tree URL   : ${DEVICE_TREE_URL}"
echo "Device Branch     : ${DEVICE_TREE_BRANCH}"
echo "Device Codename   : ${DEVICE_CODENAME}"
echo "Build Target      : ${BUILD_TARGET}image"
echo "========================================"

# Variabel tambahan
WORKDIR=$(pwd)
export GITHUB_WORKSPACE=$WORKDIR
export VENDOR_NAME="infinix"

# --- 2. Persiapan Lingkungan Build ---
echo "--- Berada di direktori `$(pwd)` ---"
echo "--- Membuat dan masuk ke direktori twrp... ---"
cd ..
mkdir -p "$WORKDIR/twrp"
cd "$WORKDIR/twrp"
echo "--- Direktori saat ini: `$(pwd)` ---"

git config --global user.name "manusia251"
git config --global user.email "darkside@gmail.com"

# --- 3. Inisialisasi dan Konfigurasi Repo ---
echo "--- Langkah 1: Inisialisasi manifest OrangeFox/TWRP... ---"
repo init -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git -b ${MANIFEST_BRANCH} --depth=1

echo "--- Langkah 2: Membuat local manifest untuk device tree... ---"
mkdir -p .repo/local_manifests
cat > .repo/local_manifests/twrp_device_tree.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
    <project name="${DEVICE_TREE_URL#https://github.com/}" path="device/generic/twrp" remote="github" revision="${DEVICE_TREE_BRANCH}" />
</manifest>
EOF

echo "--- Langkah 3: Memulai sinkronisasi repositori. Mohon tunggu... ---"
repo sync -j$(nproc) --force-sync --no-clone-bundle --no-tags --optimized-fetch --prune
echo "--- Sinkronisasi selesai. ---"

# --- 4. Memindahkan Device Tree ke Lokasi yang Benar ---
echo "--- Memeriksa keberadaan device tree di direktori sementara... ---"
if [ -d "device/generic/twrp" ]; then
    echo "--- Direktori ditemukan. Memindahkan ke lokasi permanen... ---"
    mkdir -p "device/${VENDOR_NAME}"
    mv "device/generic/twrp" "device/${VENDOR_NAME}/${DEVICE_CODENAME}"
    echo "--- Pemindahan selesai. Device tree sekarang di: device/${VENDOR_NAME}/${DEVICE_CODENAME} ---"
else
    echo "--- ERROR: Direktori device tree TIDAK DITEMUKAN. Membatalkan build. ---"
    exit 1
fi

# --- 5. Menerapkan Patch Otomatis ---
# Patch ini memperbaiki masalah 'Android.host_config.mk'
echo "--- Langkah 4: Menerapkan patch untuk memperbaiki bug VTS... ---"
mkdir -p "$WORKDIR/builder/patches"
cat > "$WORKDIR/builder/patches/fix-vts.patch" << 'EOF'
--- a/frameworks/base/core/xsd/vts/Android.mk
+++ b/frameworks/base/core/xsd/vts/Android.mk
@@ -19,7 +19,7 @@
 LOCAL_C_INCLUDES += $(LOCAL_PATH)/../../../../test/vts-testcases/hal/xsdc
 
 LOCAL_STATIC_LIBRARIES := libvts_hal_driver
-
-include $(TEST_VTS_PATH)/build/Android.host_config.mk
+ 
+
+include $(BUILD_HOST_STATIC_LIBRARY)
 
 LOCAL_MODULE := libvts_driver_xsd
 
EOF

git apply -v --directory=frameworks/base "$WORKDIR/builder/patches/fix-vts.patch"
echo "--- Patch berhasil diterapkan. ---"

# --- 6. Proses Kompilasi ---
echo "--- Langkah 5: Memulai proses kompilasi... ---"
source build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true
export OF_PATH=${PWD}
export FOX_PATH=${PWD}
export RECOVERY_VARIANT=twrp

echo "--- Menjalankan lunch... ---"
lunch twrp_${DEVICE_CODENAME}-eng
echo "--- Menjalankan make... ---"
mka adbd ${BUILD_TARGET}image

# --- 7. Persiapan Hasil Build ---
echo "--- Langkah 6: Menyiapkan hasil build... ---"
RESULT_DIR="$WORKDIR/twrp/out/target/product/${DEVICE_CODENAME}"
OUTPUT_DIR="$WORKDIR/output"
mkdir -p "$OUTPUT_DIR"

if [ -f "$RESULT_DIR/twrp.img" ] || ls $RESULT_DIR/twrp*.zip 1> /dev/null 2>&1; then
    echo "--- File output TWRP ditemukan! Menyalin ke direktori output... ---"
    cp -f "$RESULT_DIR/twrp.img" "$OUTPUT_DIR/" 2>/dev/null || true
    cp -f "$RESULT_DIR/twrp-*.zip" "$OUTPUT_DIR/" 2>/dev/null || true
    cp -f "$RESULT_DIR/${BUILD_TARGET}.img" "$OUTPUT_DIR/" 2>/dev/null || true
else
    echo "--- Peringatan: File output build tidak ditemukan di ${RESULT_DIR} ---"
fi

# --- 8. Selesai ---
echo "--- Build selesai! Cek folder output. ---"
ls -lh "$OUTPUT_DIR"
echo "========================================"
