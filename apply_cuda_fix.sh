#!/bin/bash
# apply_physx_fixes.sh — Полный набор фиксов для PhysX 5.6.1 (CUDA + snippets)
# Запускать из корня physx/
set -e

echo "=============================================================="
echo "PhysX 5.6.1 – фиксы (CUDA + snippets)"
echo "=============================================================="

# ==============================================================
# PART 1: CUDA noexcept (rsqrt/rsqrtf) – требует sudo
# ==============================================================
echo "Ищем CUDA Toolkit..."
MATH_H=$(find /usr/local /opt -type f -path "*/targets/x86_64-linux/include/crt/math_functions.h" 2>/dev/null | head -1)
if [ -z "$MATH_H" ]; then
    echo "ERROR: CUDA Toolkit не найден. Установите его."
    exit 1
fi
echo "Найден: $MATH_H"

if grep -q 'rsqrt([^)]*) noexcept' "$MATH_H"; then
    echo "noexcept уже применён – пропускаем."
else
    echo "Создаём резервную копию..."
    sudo cp "$MATH_H" "$MATH_H.backup"
    echo "Применяем noexcept..."
    sudo sed -i '
        s|extern __DEVICE_FUNCTIONS_DECL__ __device_builtin__ double rsqrt(double x);|extern __DEVICE_FUNCTIONS_DECL__ __device_builtin__ double rsqrt(double x) noexcept (true);\nextern __DEVICE_FUNCTIONS_DECL__ __device_builtin__ double __rsqrt(double x) noexcept (true);|
        s|extern __DEVICE_FUNCTIONS_DECL__ __device_builtin__ float rsqrtf(float x);|extern __DEVICE_FUNCTIONS_DECL__ __device_builtin__ float rsqrtf(float x) noexcept (true);\nextern __DEVICE_FUNCTIONS_DECL__ __device_builtin__ float __rsqrtf(float x) noexcept (true);|
    ' "$MATH_H"
    echo "noexcept применён."
fi

# ==============================================================
# PART 2: Создаём недостающие include-директории
# ==============================================================
echo "Создаём недостающие каталоги..."
mkdir -p \
    include/foundation/linux \
    source/common/src/linux source/Common/src/linux \
    source/GpuBroadPhase/{include,src} \
    source/immediatemode/include \
    source/lowlevel/api/include/windows \
    source/lowlevel/common/include/pipeline/linux \
    source/lowlevel/{linux,software}/include/linux \
    source/lowleveldynamics/include/linux \
    source/LowLevel/software/include/linux \
    source/LowLevelAABB/linux/include \
    source/LowLevelDynamics/include/linux \
    source/LowLevel/common/include/pipeline/linux \
    source/omnipvd \
    source/task/include
echo "Каталоги созданы."

# ==============================================================
# PART 3: GuBV4Build.cpp – Tree depth
# ==============================================================
FILE="source/geomutils/src/mesh/GuBV4Build.cpp"
if [ -f "$FILE" ] && ! grep -q 'printf("Tree depth: %u\\n"' "$FILE"; then
    sed -i 's/printf("Tree depth: %d\\n"/printf("Tree depth: %u\\n"/' "$FILE"
    echo "Tree depth → %u"
fi

# ==============================================================
# PART 4: ExtDelaunayBoundaryInserter.cpp – fprintf
# ==============================================================
FILE="source/physxextensions/src/tet/ExtDelaunayBoundaryInserter.cpp"
if [ -f "$FILE" ] && ! grep -q '%u vertices' "$FILE"; then
    sed -i '
        s/# %d vertices/# %u vertices/;
        s/# %d tetrahedra/# %u tetrahedra/;
        s/t %d %d %d %d/t %u %u %u %u/g;
        s/%d %d 0/%u %u 0/;
    ' "$FILE"
    echo "fprintf → %u"
fi

# ==============================================================
# PART 5: Убираем compute_70 для CUDA ≥13
# ==============================================================
CUDA_MAJOR=$(nvcc --version 2>/dev/null | grep -oP 'release \K[0-9]+' | head -1 || true)
if [ -n "$CUDA_MAJOR" ] && [ "$CUDA_MAJOR" -ge 13 ]; then
    FILE="source/compiler/cmakegpu/CMakeLists.txt"
    if [ -f "$FILE" ] && grep -q 'GENERATE_ARCH_CODE_LIST(SASS "70,' "$FILE"; then
        sed -i 's/GENERATE_ARCH_CODE_LIST(SASS "70,/GENERATE_ARCH_CODE_LIST(SASS "/' "$FILE"
        echo "compute_70 удалён (CUDA $CUDA_MAJOR)."
    fi
fi

# ==============================================================
# PART 6: cuCtxCreate → CUctxCreateParams (CUDA 12.5+)
# ==============================================================
FILE="source/cudamanager/src/CudaContextManager.cpp"
if [ -f "$FILE" ] && ! grep -q "CUctxCreateParams ctxParams" "$FILE"; then
    cp "$FILE" "$FILE.backup"
    sed -i '
        s|status = cuCtxCreate(&mCtx, (unsigned int)flags, mDevHandle);|\
      CUctxCreateParams ctxParams;\n      memset(\&ctxParams, 0, sizeof(ctxParams));\n      status = cuCtxCreate(\&mCtx, \&ctxParams, (unsigned int)flags, mDevHandle);|
    ' "$FILE"
    echo "cuCtxCreate → CUctxCreateParams"
fi

#!/bin/bash
# apply_physx_fixes.sh — Полный набор фиксов для PhysX 5.6.1 (CUDA + snippets)
# Запускать из корня physx/
set -e
echo "=============================================================="
echo "PhysX 5.6.1 – фиксы (CUDA + snippets)"
echo "=============================================================="

# ==============================================================
# PART 7: Универсальный фикс printf/sprintf → %u + опечатки
# ==============================================================
echo "Фиксим printf/sprintf в snippets..."
FIXED=0

for src in snippets/*/Snippet*.cpp; do
    [ -f "$src" ] || continue
    CHANGED=0

    # --- 1. Конкретные строки ---
    if grep -q 'visible objects' "$src"; then
        sed -i 's/"%d visible objects\\n"/"%u visible objects\\n"/' "$src" && CHANGED=1
    fi
    if grep -q 'contact reports' "$src"; then
        sed -i 's/"%d contact reports\\n"/"%u contact reports\\n"/' "$src" && CHANGED=1
    fi
    if grep -q 'Create convex mesh with %d triangles' "$src"; then
        sed -i 's/Create convex mesh with %d triangles/Create convex mesh with %u triangles/' "$src" && CHANGED=1
    fi
    if grep -q 'Create triangle mesh with %d triangles' "$src"; then
        sed -i 's/Create triangle mesh with %d triangles/Create triangle mesh with %u triangles/' "$src" && CHANGED=1
    fi
    if grep -q 'Num triangles per leaf: %d' "$src"; then
        sed -i 's/Num triangles per leaf: %d/Num triangles per leaf: %u/' "$src" && CHANGED=1
    fi
    if grep -q 'Gauss map limit: %d' "$src"; then
        sed -i 's/Gauss map limit: %d /Gauss map limit: %u /' "$src" && CHANGED=1
    fi
    if grep -q 'Created hull number of vertices: %d' "$src"; then
        sed -i 's/Created hull number of vertices: %d /Created hull number of vertices: %u /' "$src" && CHANGED=1
    fi
    if grep -q 'Created hull number of polygons: %d' "$src"; then
        sed -i 's/Created hull number of polygons: %d /Created hull number of polygons: %u /' "$src" && CHANGED=1
    fi
    if grep -q 'Mesh size: %d' "$src"; then
        sed -i 's/Mesh size: %d /Mesh size: %u /' "$src" && CHANGED=1
    fi
    if grep -q 'Completed %d simulate steps with %d substeps per simulate step' "$src"; then
        sed -i 's/Completed %d simulate steps with %d substeps per simulate step/Completed %u simulate steps with %d substeps per simulate step/' "$src" && CHANGED=1
    fi

    # --- 2. Опечатка: %du → %u ---
    if grep -q '%du contacts' "$src"; then
        sed -i 's/%du contacts/%u contacts/' "$src" && CHANGED=1
    fi

    # --- 3. SnippetMultiPruners: %d actors / %d: time → %u ---
    if grep -q 'actors\\n"' "$src"; then
        sed -i 's/%d actors/%u actors/' "$src" && CHANGED=1
    fi
    if grep -q '%d: time' "$src"; then
        sed -i 's/%d: time/%u: time/' "$src" && CHANGED=1
    fi

    # --- 5. SnippetProfilerConverter: %d.%d → %u.%u только в строках с versionInfo.major ---
    if grep -q 'It is version %d.%d' "$src"; then
        sed -i 's/It is version %d\.%d/It is version %u.%u/' "$src" && CHANGED=1
    fi

    # --- 4. Агрессивный: любой %d перед PxU32 / getNb* / size() ---
    if grep -Eq '%d.*(size\(\)|getNb|P[xX]U32)' "$src"; then
        sed -Ei 's/(%d)([^%]*)(size\(\)|getNb[^)]*\(\)|P[xX]U32\([^)]*\))/\1u\2\3/g' "$src"
        CHANGED=1
    fi

    (( CHANGED )) && (( FIXED++ )) && echo "  → $src"
done

(( FIXED )) && echo "Исправлено $FIXED файлов." || echo "snippets уже в порядке."

# ==============================================================
# Финал
# ==============================================================
echo ""
echo "Все фиксы применены!"
echo "Для отката CUDA: sudo cp \"$MATH_H.backup\" \"$MATH_H\""
echo "=============================================================="