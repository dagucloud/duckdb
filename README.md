# Dagu DuckDB Action

Official Dagu action for running DuckDB SQL through the DuckDB CLI.

This action keeps DuckDB out of the Dagu core binary, so Dagu can remain
portable and cgo-free. The action pins the DuckDB CLI with Dagu `tools`, which
uses aqua internally.

## Usage

```yaml
type: graph

steps:
  - id: query
    action: duckdb@v1
    with:
      query: |
        SELECT 42 AS answer, 'duckdb' AS engine;

  - id: print_result
    depends: [query]
    run: printf '%s\n' '${query.outputs.result}'
```

The default output format is DuckDB JSON mode, so `result` is a JSON string:

```json
[{"answer":42,"engine":"duckdb"}]
```

## Inputs

| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `query` | string | Yes | | SQL passed to `duckdb -c`. |
| `database` | string | No | transient in-memory database | Database file path. Use an absolute path when the file lives outside the action workspace. |
| `workdir` | string | No | action workspace | Directory to `cd` into before running DuckDB. Use this when SQL references local files with relative paths. |
| `format` | string | No | `json` | Output format: `json`, `csv`, `table`, `markdown`, `line`, `list`, or `column`. |
| `readonly` | boolean | No | `false` | Open the database in read-only mode. |

## Outputs

| Name | Type | Description |
|------|------|-------------|
| `result` | string | Raw DuckDB stdout in the selected format. |

## Local Development

Use `source:` to call a local checkout:

```yaml
steps:
  - id: query
    action: source:file:///path/to/duckdb@local
    with:
      query: SELECT 1 AS ok;
```

Remote actions run in their own action workspace. If a query needs files from a
caller workspace, pass `workdir` and use paths that exist on the worker running
the action.
