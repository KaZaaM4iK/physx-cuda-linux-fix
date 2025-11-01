# PhysX CUDA Fix Script

Fixes CUDA "rsqrt/rsqrtf noexcept" conflicts and creates missing folders for PhysX SDK build on Linux.

## Usage
1. Download apply_cuda_fix.sh
2. Make executable: `chmod +x apply_cuda_fix.sh`
3. Run in PhysX folder: `./apply_cuda_fix.sh`
4. Proceed with `./generate_projects.sh` or `make`.
