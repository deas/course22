# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A fork of [fastai/course22](https://github.com/fastai/course22) — the notebooks, slides, and spreadsheets for the 2022 edition of *Practical Deep Learning for Coders*. The upstream notebooks were authored as **Kaggle kernels**; the purpose of this fork is to make them run **locally** on current library versions via `uv`.

There is no application, package, or test suite here. The deliverable is working notebooks.

## Commands

```bash
just sync            # uv sync — create/refresh .venv from pyproject.toml + uv.lock
just start-jupyter   # uv run jupyter lab --ip=0.0.0.0
just format          # ruff check --fix + ruff format (ruff is not a declared dep; install separately)
just                 # list all recipes
```

`mise` (`mise.toml`) activates `.venv`, pins `python` to 3.13, exports `OPENAI_BASE_URL=https://openrouter.ai/api/v1` (for the `jupyter-ai` extension via OpenRouter) and loads the untracked `.env` (`OPENROUTER_API_KEY`, `JUPYTER_TOKEN`). Outside a mise-activated shell, prefix commands with `uv run`.

To run a single notebook non-interactively: `uv run jupyter execute <notebook>.ipynb`.

### Jupyter MCP

`.mcp.json` registers `jupyter-mcp-server` (via `uvx`, pinned). Its tools operate on a **live Lab
session**, not on files: `just start-jupyter` must already be running, and the MCP client must have
been started after it. `JUPYTER_TOKEN` in the untracked `.env` authenticates both ends.

Prefer these tools over hand-editing `.ipynb` JSON when the task is "run this cell and see what
happens" — they execute against a real kernel and write outputs back the way Lab would. Editing the
file on disk while a Lab session has it open will fight the RTC layer.

## Environment constraints

Measured benchmarks and the full reasoning behind the GPU/NPU verdicts live in `HARDWARE.md`.

- **Python >= 3.13**, and `[tool.uv] required-environments` pins resolution to `linux` + `x86_64`.
- **torch/torchvision resolve from the `pytorch-cpu` index** (`[tool.uv.sources]` in `pyproject.toml`). **Treat this box as CPU-only** — but know *why*, so it doesn't get "fixed": there **is** an AMD Radeon 780M iGPU, which ROCm 7.x detects natively as `gfx1103` (`/dev/kfd` is world-readable, so no `render` group setup is needed). The blocker is that the PyTorch ROCm wheels bundle a rocBLAS with **no `gfx1103` kernels** (gfx1100/1101/1102/1150/1151 only). It runs at all only under `HSA_OVERRIDE_GFX_VERSION=11.0.0`, and that ISA mismatch makes MIOpen/Triton kernels abort intermittently with `HSA_STATUS_ERROR_INVALID_ISA`. Pointing at the system rocBLAS (which *does* have gfx1103) fails outright on Tensile format skew. Measured on this machine: conv training ~1.5× CPU with a ~50% crash rate, and autocast/AMP crashes every run. Raw fp16 matmul does reach ~6× CPU, so the silicon is real — but nothing in this repo's vision workload survives the instability. Don't re-litigate this without new upstream wheels.
- Notebooks 08–10 (paddy-disease, "Road to the Top") train large vision models and are impractically slow or will not finish on CPU — expect that, don't "fix" it by rewriting the training loop. The iGPU does not rescue them either (see above).
- **The RyzenAI NPU is present and also unusable here.** `rocminfo` lists an `aie2` / `RyzenAI-npu1` agent and the `amdxdna` driver is loaded (`/dev/accel/accel0`), but reaching it requires the Ryzen AI stack (ONNX Runtime + VitisAI EP) running pre-quantized INT8 models. There is no fastai or torch path to it — it cannot run a training loop at all. Ignore it.
- `.devcontainer/` is upstream's Codespaces setup (Python 3.10, `pip install -r requirements.txt`). It is **not** the local path and its `requirements.txt` is not kept in sync with `pyproject.toml` — treat `pyproject.toml` as the source of truth.

## Notebook conventions (important when editing)

Upstream cells assume Kaggle. Local migration follows these patterns — match them rather than inventing new ones:

- **`!pip install` cells are commented out, not deleted** (e.g. `# !pip install -Uqq fastai`). Dependencies belong in `pyproject.toml`; keeping the commented line preserves fidelity with the Kaggle original.
- **`duckduckgo_search` → `ddgs`** (`from ddgs import DDGS`). The old package is dead; `ddgs` is the declared dependency.
- **`iskaggle` branches stay.** Several notebooks (05, 06, 07, 08–10) switch on `os.environ.get('KAGGLE_KERNEL_RUN_TYPE', '')` to pick between `../input/<comp>` and a local `kaggle` API download. Keep both branches working; only the `else:` path is exercised here.
- Notebooks 08–10 use `fastkaggle`'s `setup_comp()` / `push_notebook()`. `push_notebook` calls target Jeremy Howard's Kaggle account and are guarded by `if not iskaggle:` — leave them alone.
- **When adding a training cell, set `defaults.cpus = 8` before building `DataLoaders`.** fastai
  derives `num_workers` from `sched_getaffinity` and picks 16 on this 8-physical-core box, costing a
  measured ~5% (`HARDWARE.md`). Not worth retrofitting into already-committed notebooks.
- Notebooks are committed **with outputs**, re-executed locally. Diffs are therefore huge and noisy (base64 images, timings, absolute venv paths in warnings). Inspect changes by extracting `source` from code cells, not by reading `git diff` output.

### Migration status

Notebooks `00`–`06` have been re-run and adapted locally. `07`–`10` are still as-forked from upstream. See the README's TODO list for known issues (markdown cell rendering, pytorch/sympy version drift, shell magics `%!` misbehaving under nushell).

## Directory map

- Repo root — the notebooks, numbered `00`–`10`.
- `clean/` — generated stripped copies (code cells + headers only, no prose, no outputs). Regenerate with `tools/clean.py`; never edit by hand.
- `tools/` — upstream maintenance scripts: `download.py` pulls the kernels listed in `kaggles.txt` from Kaggle, `clean.py` produces `clean/`. Not part of local development.
- `xl/`, `slides/` — course spreadsheets and decks (binary, read-only).
