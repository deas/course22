## course.fast.ai

This is where you'll find the notebooks, slides, and spreadsheets for the 2022 edition of Practical Deep Learning for Coders. See [course.fast.ai](https://course.fast.ai) for the lessons.

## What's here

- Repo root: notebooks
- `clean` folder: notebooks without prose or outputs
- `xl`: Excel spreadsheets
- `slides`: Jeremy's slide decks
- `tools`: Ignore (tools for creating this repo)
- `getting-started-with-codespaces`: A document to help run the notebooks in a GitHub Codespace

## Jupyter MCP

`.mcp.json` wires [jupyter-mcp-server](https://github.com/datalayer/jupyter-mcp-server) into MCP
clients, so an agent can read, edit and execute cells in a *running* Lab session instead of
rewriting `.ipynb` files on disk.

It drives notebooks over the real-time-collaboration layer, so `jupyter-collaboration` and
`jupyter-mcp-tools` are declared in `pyproject.toml` and must be present in the venv.

Setup:

1. `just sync`
2. Put a token in the untracked `.env`: `JUPYTER_TOKEN=<random hex>`. `jupyter-server` reads this
   variable natively, and `.mcp.json` passes the same value to the MCP server — one secret, both ends.
3. `just start-jupyter` (refuses to start if `JUPYTER_TOKEN` is unset)
4. Start the MCP client from a `direnv` shell so `.env` is loaded.

Note that the server has to be running before the MCP client starts — it connects at launch.

## TODO / Known Issues

- Markdown Cells do not render?
- Some notebooks likely need migration to play with recent versions of pytorch / sympy ... and maybe others
- fastai (built on pytorch) has (somewhat orphaned?) tpu extension (pytorch has maintained tpu support via torch_xla)
- Implement more Kaggle/Colab/Paperspace compat?
- [Original Repo has quite a few issues](https://github.com/fastai/course22/issues)
- Careful with shell magics `%!` with nushell - things may expect a POSIX shell
