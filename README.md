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

## Existing DuckDB Files

Use `database` to run SQL against an existing DuckDB file:

```yaml
type: graph

steps:
  - id: query_existing_db
    action: duckdb@v1
    with:
      database: /data/analytics.duckdb
      query: |
        SELECT count(*) AS users FROM users;
```

Use `workdir` when the database path or files referenced by SQL should be
resolved relative to a directory:

```yaml
type: graph

steps:
  - id: query_project_db
    action: duckdb@v1
    with:
      workdir: /data/project
      database: analytics.duckdb
      query: |
        SELECT * FROM read_csv_auto('events.csv') LIMIT 10;
```

The database file must exist on the worker that runs the action. In distributed
shared-nothing mode, use a shared mount or an absolute path available on that
worker. `:memory:` is scoped to one action invocation, so it cannot share state
between multiple action steps.

## Multiple Operations

For tightly coupled operations, run multiple SQL statements in one action. This
keeps them in one DuckDB process and lets you use a transaction boundary:

```yaml
type: graph

steps:
  - id: update_metrics
    action: duckdb@v1
    with:
      database: /data/analytics.duckdb
      query: |
        BEGIN TRANSACTION;

        CREATE TABLE IF NOT EXISTS metrics (
          name VARCHAR,
          value INTEGER
        );

        INSERT INTO metrics VALUES ('runs', 1);

        UPDATE metrics
        SET value = value + 1
        WHERE name = 'runs';

        COMMIT;

        SELECT * FROM metrics;
```

For separate DAG visibility, use multiple action steps against the same database
file and connect them with `depends`:

```yaml
type: graph

steps:
  - id: insert_rows
    action: duckdb@v1
    with:
      database: /data/analytics.duckdb
      query: |
        INSERT INTO metrics VALUES ('jobs', 10);

  - id: update_rows
    depends: [insert_rows]
    action: duckdb@v1
    with:
      database: /data/analytics.duckdb
      query: |
        UPDATE metrics SET value = value + 5 WHERE name = 'jobs';

  - id: select_rows
    depends: [update_rows]
    action: duckdb@v1
    with:
      database: /data/analytics.duckdb
      readonly: true
      query: |
        SELECT * FROM metrics WHERE name = 'jobs';

  - id: print_result
    depends: [select_rows]
    run: printf '%s\n' '${select_rows.outputs.result}'
```

Keep write operations ordered with `depends`. Parallel writes to the same DuckDB
file can conflict because DuckDB uses file-level locking semantics.

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
