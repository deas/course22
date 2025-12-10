## course.fast.ai

This is where you'll find the notebooks, slides, and spreadsheets for the 2022 edition of Practical Deep Learning for Coders. See [course.fast.ai](https://course.fast.ai) for the lessons.

## What's here

- Repo root: notebooks
- `clean` folder: notebooks without prose or outputs
- `xl`: Excel spreadsheets
- `slides`: Jeremy's slide decks
- `tools`: Ignore (tools for creating this repo)
- `getting-started-with-codespaces`: A document to help run the notebooks in a GitHub Codespace

## TODO / Known Issues

- Markdown Cells do not render?
- Some notebooks likely need migration to play with recent versions of pytorch / sympy ... and maybe others
- fastai (built on pytorch) has (somewhat orphaned?) tpu extension (pytorch has maintained tpu support via torch_xla)
- Implement more Kaggle/Colab/Paperspace compat?
- [Original Repo has quite a few issues](https://github.com/fastai/course22/issues)
- Careful with shell magics `%!` with nushell - things may expect a POSIX shell
