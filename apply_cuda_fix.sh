#!/bin/bash
# apply_cuda_fix.sh — Fix CUDA rsqrt/rsqrtf noexcept + create missing folder
# Run from physx/ directory: ./apply_cuda_fix.sh

set -e

echo "=============================================================="
echo "PhysX CUDA noexcept fix + missing folder"
echo "=============================================================="

# === PART 1: Fix CUDA math_functions.h (requires sudo) ===
echo "Searching for CUDA installation..."
FILE=$(find /usr/local /opt -type f -path "*/targets/x86_64-linux/include/crt/math_functions.h" 2>/dev/null | head -1)

if [ -z "$FILE" ]; then
  echo "ERROR: CUDA Toolkit not found."
  echo "   Please install NVIDIA CUDA Toolkit."
  exit 1
fi

echo "Found: $FILE"

echo "Creating backup..."
sudo cp "$FILE" "$FILE.backup"
echo "Backup saved: $FILE.backup"

echo "Patching math_functions.h..."
sudo sed -i '
  s|extern __DEVICE_FUNCTIONS_DECL__ __device_builtin__ double                 rsqrt(double x);|extern __DEVICE_FUNCTIONS_DECL__ __device_builtin__ double rsqrt(double x) noexcept (true);\nextern __DEVICE_FUNCTIONS_DECL__ __device_builtin__ double __rsqrt(double x) noexcept (true);|
  s|extern __DEVICE_FUNCTIONS_DECL__ __device_builtin__ float                  rsqrtf(float x);|extern __DEVICE_FUNCTIONS_DECL__ __device_builtin__ float rsqrtf(float x) noexcept (true);\nextern __DEVICE_FUNCTIONS_DECL__ __device_builtin__ float __rsqrtf(float x) noexcept (true);|
' "$FILE"

echo "CUDA noexcept fix applied!"

# === PART 2: Create missing include folder (no sudo) ===
echo "Creating include/foundation/linux..."
mkdir -p \
  include/foundation/linux\
  source/common/src/linux\
  source/Common/src/linux \
  source/GpuBroadPhase/include\
  source/GpuBroadPhase/src\
  source/lowlevel/common/include/pipeline/linux\
  source/lowlevel/software/include/linux\
  source/lowleveldynamics/include/linux\
  source/LowLevel/software/include/linux \
  source/LowLevelAABB/linux/include\
  source/LowLevelDynamics/include/linux \
  source/LowLevel/common/include/pipeline/linux
echo "Missing folders created."

# === PART 3: Fix printf format in GuBV4Build.cpp (no sudo) ===
CPP_FILE="source/geomutils/src/mesh/GuBV4Build.cpp"

if [ ! -f "$CPP_FILE" ]; then
  echo "ERROR: File not found: $CPP_FILE"
  echo "   Make sure you are running the script from the physx/ directory."
  exit 1
fi

# Check if already patched
if grep -q 'printf("Tree depth: %u\\n"' "$CPP_FILE"; then
  echo "printf format already fixed — skipping."
else
  echo "Fixing printf format in $CPP_FILE..."
  sed -i 's/printf("Tree depth: %d\\n"/printf("Tree depth: %u\\n"/' "$CPP_FILE"
  echo "printf fix applied!"
fi

echo ""
echo "All fixes applied!"
echo "To revert CUDA changes:"
echo "   sudo cp \"$FILE.backup\" \"$FILE\""
echo "=============================================================="