# Format Support

## v1 format contract

- Supported source format: `.docx`
- Conversion engine: `pandoc`
- Markdown writer: `gfm`
- Media extraction target: `<basename>.assets/`
- Existing generated outputs are replaced on every rerun

## Markdown and assets

The helper script runs `pandoc` from the source document's directory and uses a
relative `--extract-media` path. That keeps generated image links relative to
the Markdown file, for example:

```md
![](example.assets/media/image1.png)
```

This lets the Markdown render extracted images without any manual path fixes.

## Workspace contract

The skill expects `workspace.yaml` to contain:

```yaml
prp:
  path: "product/prps"
```

The target PRP directory resolves as:

```text
<workspace_root>/<prp.path>/<prp_id>
```

## Future extension guidance

If additional formats are added later:

1. Keep `prp.path` as the workspace-level discovery contract.
2. Isolate format-specific logic in the helper script behind a small dispatcher.
3. Preserve the same output contract:
   - `<basename>.md`
   - `<basename>.assets/`
4. Preserve rerun behavior by replacing existing generated outputs before
   writing new ones.

## Dependency note

`pandoc` is required in v1. If the command is unavailable, fail clearly instead
of silently skipping extraction.
