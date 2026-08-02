# Hardware notes

Measured **2026-08-02** on this machine. These are empirical results, not vendor specs — re-run the
reproductions below before trusting them after a toolchain bump.

`AGENTS.md` carries the short version ("treat this box as CPU-only"). This file is the evidence.

## Inventory

| Component | Detail |
|---|---|
| CPU | AMD Ryzen 7 PRO 8845HS — 8 cores / 16 threads, Zen 4, AVX-512, 16 MiB L3, boost 5.14 GHz |
| RAM | 19 GiB, **no swap** |
| iGPU | AMD Radeon 780M — ROCm agent `gfx1103`, 4 GiB VRAM carve-out + 10.3 GiB GTT (9.64 GiB visible to torch) |
| NPU | RyzenAI `aie2` / `npu1`, `amdxdna` driver loaded at `/dev/accel/accel0` |
| ROCm | 7.2.4 at `/opt/rocm`, `/dev/kfd` is `crw-rw-rw-` (no `render` group needed) |
| Disk | 932 GB NVMe on `/home`; `/tmp` is a **9.7 GB tmpfs** (RAM-backed) |

Software at time of measurement: project torch `2.9.1+cpu`, fastai `2.8.5`, numpy `2.3.5`.

## The GPU question

**Verdict: real silicon, unusable toolchain. Stay on CPU.**

ROCm detects the 780M natively and system rocBLAS ships 96 `gfx1103` kernel files. The problem is
upstream PyTorch: the ROCm wheels bundle their *own* rocBLAS containing
`gfx1030/1100/1101/1102/1150/1151/1200/1201/908/90a/942/950` — and **no `gfx1103`**.

Consequences, in order of discovery:

1. Stock `torch==2.12.1+rocm7.1` segfaults on the first GPU allocation.
2. `HSA_OVERRIDE_GFX_VERSION=11.0.0` (presenting the device as `gfx1100`) makes it work — rocBLAS
   matmul is then fast and correct.
3. But the ISA is now a lie. MIOpen and Triton kernels built for the real `gfx1103` abort the queue
   with `HSA_STATUS_ERROR_INVALID_ISA: code 0x100f`, **intermittently**.
4. Forcing the system rocBLAS instead (`ROCBLAS_TENSILE_LIBPATH=/opt/rocm/lib/rocblas/library`),
   which *does* have `gfx1103`, fails on every run — Tensile format skew between the rocm7.1 wheel
   and ROCm 7.2.4.

MIOpen also ships no tuned `gfx1103` convolution database (only gfx1030/gfx9xx), so convolutions
fall back to generic solvers. This is why the matmul and conv numbers diverge so sharply.

### Measurements

Matmul, all GPU runs under `HSA_OVERRIDE_GFX_VERSION=11.0.0`:

| Workload | CPU | GPU | Speedup |
|---|---|---|---|
| fp32 2048² | 0.64 TFLOP/s | 1.18 TFLOP/s | 1.9× |
| fp16 2048² | — | **3.88 TFLOP/s** | 6.1× vs CPU fp32 |
| bf16 2048² | — | 3.63 TFLOP/s | 5.7× |
| fp32 4096² | 0.53 TFLOP/s | 1.71 TFLOP/s | 3.2× — **failed 2 of 3 runs** |
| fp16 4096² | — | 3.14 TFLOP/s | stable |
| bf16 4096² | — | 3.06 TFLOP/s | stable |

Conv training step — the workload notebooks 08–10 actually run. Synthetic ResNet-ish stack
(13 conv layers + BN/ReLU), batch 32 at 128×128, forward + backward + SGD step:

| Config | Throughput | Reliability |
|---|---|---|
| CPU fp32 | 204 img/s | stable |
| GPU fp32 | 315 img/s (**1.54×**) | failed ~50% of runs |
| GPU autocast fp16 | — | **crashed every run** |

Note this was a hand-built conv stack, not a real `resnet26d` via fastai — enough to characterise
MIOpen behaviour, not a substitute for an end-to-end notebook run.

**Reading:** the ~6× fp16 matmul upside is real, so a matmul-bound notebook could benefit. But
nothing in this repo's vision workload survives the instability, and 1.5× is not worth a 50% crash
rate. Revisit only when upstream wheels ship native `gfx1103` kernels.

### Reproducing

```bash
uv venv --python 3.13 /tmp/rocmtest          # NOT under /tmp if >9 GB — see gotchas
VIRTUAL_ENV=/tmp/rocmtest uv pip install \
  --index-url https://download.pytorch.org/whl/rocm7.1 torch==2.12.1 torchvision==0.27.1
HSA_OVERRIDE_GFX_VERSION=11.0.0 /tmp/rocmtest/bin/python -c \
  "import torch; print(torch.cuda.is_available(), torch.cuda.get_device_properties(0).gcnArchName)"
# check whether the gfx1103 gap has closed:
ls /tmp/rocmtest/lib/python3.13/site-packages/torch/lib/rocblas/library/ | grep -c gfx1103
```

That last line returning **non-zero** is the signal this whole section is obsolete.

### Why there is no `rocm` extra

Adding an opt-in `rocm` extra (uv's conflicting-extras pattern) was attempted **2026-08-02** and
reverted. It is blocked twice over:

1. **Dependency conflict.** `fastai 2.8.5` requires `torch<2.10,>=1.10`. The `rocm7.1` index's
   earliest cp313 torch is **2.10.0**. No overlap — `uv lock` fails `unsatisfiable`. (Watch for the
   pipeline trap: `uv lock | tail` reports *tail's* exit status, so this failure looks like success.)
2. **The compatible index doesn't help.** `rocm6.4` does have torch `2.9.1`, which satisfies fastai.
   But that wheel's bundled rocBLAS also ships **zero `gfx1103` kernels** (gfx1030/1100/1101/1102/
   1200/1201/9xx, plus a generic `gfx11xx`) — the same wall, on an older stack.

Verified cheaply without downloading 4.3 GB, by range-fetching the wheel's zip central directory,
which stores filenames as plain text:

```bash
U="https://download.pytorch.org/whl/rocm6.4/torch-2.9.1%2Brocm6.4-cp313-cp313-manylinux_2_28_x86_64.whl"
LEN=$(curl -sI "$U" | grep -i '^content-length' | tr -d '\r' | awk '{print $2}')
curl -s -r $((LEN-12000000))-${LEN} "$U" | strings | grep -oE 'gfx[0-9a-z]+' | sort -u
```

Reuse that trick before any future ROCm attempt — it answers the kernel question in seconds.

A further trap if this is revisited: `torch` cannot simply move into `[project.optional-dependencies]`,
because fastai depends on it transitively. Without `[tool.uv] default-extras = ["cpu"]`, a bare
`uv sync` resolves torch from **PyPI — the CUDA build**, pulling ~3 GB of unusable nvidia wheels.

## The NPU

Present (`rocminfo` lists `aie2` / `RyzenAI-npu1`, `amdxdna` loaded, `/dev/accel/accel0` exists) and
not reachable from this stack. It needs ONNX Runtime with the VitisAI execution provider and
pre-quantized INT8 models. It is an *inference* accelerator — it cannot run a training loop at all,
so no software work would make it useful for the course notebooks. Unlike the GPU verdict, this one
is architectural and will not change.

## CPU-side findings

Both were measured after the fact. Neither is the win it first looked like — recorded here so they
don't get "discovered" again.

**1. Dataloader oversubscription — real but small (~5%).** `fastai defaults.cpus` reports **16**
(from `len(os.sched_getaffinity(0))`), so `num_workers` defaults to 16 worker processes on **8
physical cores**, alongside torch's own 8-thread OMP pool. Measured on a synthetic 800-image
`resnet18` epoch at 128×128, 4 runs each:

| `num_workers` | torch threads | s/epoch |
|---|---|---|
| 16 (fastai default) | 8 | 6.79 – 6.86 |
| **8** | 8 | **6.45 – 6.49** |
| 4 | 8 | 6.43 |
| 8 | 4 | 8.43 |

Consistent and non-overlapping, but only ~5%. Torch's default of 8 threads is already correct —
dropping to 4 is clearly worse. When touching a training notebook, `defaults.cpus = 8` before
building `DataLoaders` is worth it; mass-editing the committed notebooks for 5% is not.

**2. MKL vs OpenBLAS — no lever, closed.** torch's bundled MKL reaches ~600–640 GFLOP/s at 2048²
where numpy's OpenBLAS (correctly selecting the AVX-512 `SkylakeX` kernel) reaches 715. But
`MKL_ENABLE_INSTRUCTIONS` does nothing — `<unset>` 596.9, `AVX512` 603.9, `AVX2` 584.3 GFLOP/s, all
within noise. MKL is already on its AVX-512 path; the gap is inherent to MKL on AMD. Capturing it
would mean a torch build linked against OpenBLAS, which is far out of proportion to ~12%. **Don't
chase this.**

## Gotchas found the hard way

- **`/tmp` is a 9.7 GB tmpfs backed by RAM.** A torch ROCm venv is ~14 GB; installing there dies
  with `Disk quota exceeded (os error 122)` *and* consumes real memory until deleted — costly on a
  19 GiB box with no swap. Put large scratch installs on `/home`.
- **Pin `torchvision` alongside `torch`** when using a PyTorch ROCm index. An unpinned `torchvision`
  makes `uv` hang in resolution indefinitely with no output. The matching pair is
  `torch==2.12.1+rocm7.1` ↔ `torchvision==0.27.1+rocm7.1`.
- Notebook 10's `report_gpu()` calls `torch.cuda.list_gpu_processes()` / `empty_cache()`. These work
  on ROCm builds (HIP reuses the `torch.cuda` namespace) but raise on the CPU-only build in use here.
