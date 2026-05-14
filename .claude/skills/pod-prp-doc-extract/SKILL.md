---
name: pod-prp-doc-extract
description: Extract PRP source documents into Markdown with sibling asset folders. Resolves `prp.path` from `workspace.yaml`, supports `.docx` in v1, and replaces existing generated outputs before regenerating them. Use when the developer asks to extract PRP docs to Markdown, convert `.docx` files inside a PRP, or pull embedded images out of PRP source documents.
client: pod
tags: [pod, prp, docs, markdown, docx]
dependencies: [pandoc]
---

# Pod PRP Doc Extract

Convert `.docx` files inside a configured PRP directory into Markdown plus a
matching `<basename>.assets/` folder.

## Required inputs

You must have:

- a `workspace.yaml` file with:

```yaml
prp:
  path: "product/prps"
```

- either:
  - a PRP directory path at `<workspace_root>/<prp.path>/<prp_id>`
  - one `.docx` file inside that PRP directory

If `prp.path` is missing, stop and ask the developer to add it before
continuing.

## Scope guards

- Supports `.docx` only
- Processes `.docx` files directly inside the target PRP directory
- Writes `<basename>.md` beside the source file
- Writes extracted media under `<basename>.assets/`
- Deletes existing generated `<basename>.md` and `<basename>.assets/` before
  regenerating them

## Workflow

1. Resolve the PRP root from `workspace.yaml`.
2. Validate that the requested PRP directory or `.docx` file is inside that
   root.
3. Locate this skill's helper script and run:

```bash
bash "scripts/extract-doc.sh" --workspace "/absolute/path/to/workspace.yaml" "/absolute/path/to/product/prps/<prp_id>"
```

Or for one file:

```bash
bash "scripts/extract-doc.sh" --workspace "/absolute/path/to/workspace.yaml" "/absolute/path/to/product/prps/<prp_id>/<source>.docx"
```

4. Report which files were converted and where the Markdown outputs were
   written.

## Output contract

For `source.docx`, the helper emits:

- `source.md`
- `source.assets/`

Image references in `source.md` must stay relative so the Markdown can render
the extracted assets immediately.

## Failure rules

- Fail if `pandoc` is unavailable
- Fail if `prp.path` is missing
- Fail if the target path is outside the configured PRP root
- Fail if a PRP directory contains no `.docx` files
- Do not modify the source `.docx`

## Quality check before finishing

- Was `prp.path` resolved from `workspace.yaml`?
- Was the target path confirmed inside the configured PRP root?
- Did the helper script run from the skill directory or an absolute script path?
- Were generated Markdown and asset paths reported?

## Additional resources

- For format notes and future-extension guidance, see
  [references/format-support.md](references/format-support.md)
