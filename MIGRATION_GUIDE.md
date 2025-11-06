# Migration Guide: V1 (Per-Endpoint) → V2 (API-Level)

## 🎯 What Changed?

### Architecture Shift

**V1 (Old):** Per-Endpoint Registration
- Each endpoint registered separately
- Multiple registry rows per API
- Rigid, doesn't scale

**V2 (New):** API-Level Registration  
- Register API once with host + base_path
- One registry row per API
- Call any path dynamically at runtime

## 📊 Schema Changes

### New Table Structure

**Removed Columns:**
- `api_path` - No longer needed (paths are dynamic)
- `http_method` - Methods specified at call-time
- `request_headers` - Headers specified at call-time
- `parameters` - Not needed for API-level registration

**Added Columns:**
- `available_endpoints` - JSON array of endpoint info (informational only)
- `example_calls` - JSON array of usage examples (informational only)

**Modified Columns:**
- `api_name` - Now API-level (e.g., "github_api" not "github_repos")
- Added UNIQUE constraint on `api_name` to prevent duplicates

### New Table Schema

```sql
CREATE TABLE IF NOT EXISTS {catalog}.{schema}.api_http_registry (
  api_id STRING NOT NULL,
  api_name STRING NOT NULL,  -- API-level name
  description STRING,
  connection_name STRING NOT NULL,
  host STRING NOT NULL,
  base_path STRING,
  auth_type STRING NOT NULL,
  secret_scope STRING,
  documentation_url STRING,
  available_endpoints STRING,  -- NEW: JSON array (informational)
  example_calls STRING,  -- NEW: JSON array (informational)
  status STRING,
  validation_message STRING,
  user_who_requested STRING,
  created_at TIMESTAMP,
  modified_date TIMESTAMP,
  PRIMARY KEY (api_id),
  UNIQUE (api_name)  -- NEW: Prevent duplicate APIs
);
```

## 🔄 Migration Steps

### Option 1: Fresh Start (Recommended for Testing)

1. **Drop old table:**
```sql
DROP TABLE IF EXISTS {catalog}.{schema}.api_http_registry;
```

2. **Create new table:**
```sql
-- Run setup_api_http_registry_table.sql
```

3. **Re-register APIs** using new workflow (see examples below)

### Option 2: Migrate Existing Data

If you have important existing registrations:

```sql
-- 1. Backup old data
CREATE TABLE {catalog}.{schema}.api_http_registry_backup AS
SELECT * FROM {catalog}.{schema}.api_http_registry;

-- 2. Create new table with new schema
-- (Run setup_api_http_registry_table.sql with new table name temporarily)

-- 3. Migrate data (example - customize based on your data)
INSERT INTO {catalog}.{schema}.api_http_registry_new
SELECT 
  api_id,
  -- Derive API-level name from endpoint name
  REGEXP_REPLACE(api_name, '_.*', '') as api_name,  
  description,
  connection_name,
  host,
  base_path,
  auth_type,
  secret_scope,
  documentation_url,
  -- Group endpoints by API (you'll need to manually construct these)
  NULL as available_endpoints,  
  NULL as example_calls,
  status,
  validation_message,
  user_who_requested,
  created_at,
  modified_date
FROM {catalog}.{schema}.api_http_registry
-- Only take one row per unique API (deduplicate)
GROUP BY host, base_path, auth_type;

-- 4. Drop old table and rename new one
DROP TABLE {catalog}.{schema}.api_http_registry;
ALTER TABLE {catalog}.{schema}.api_http_registry_new 
RENAME TO api_http_registry;
```

**Note:** Manual cleanup will be needed as V1 had multiple rows per API.

## 🔧 Code Changes

### Tool Usage Changes

**V1 - register_api (Old):**
```python
# Had to register each endpoint
register_api(
    api_name="fred_series_observations",  # Endpoint-specific
    host="api.stlouisfed.org",
    api_path="/series/observations",  # Specific path
    base_path="/fred",
    auth_type="api_key",
    ...
)
```

**V2 - register_api (New):**
```python
# Register API once
register_api(
    api_name="fred_api",  # API-level name
    host="api.stlouisfed.org",
    base_path="/fred",  # Base path only
    auth_type="api_key",
    available_endpoints=[  # INFORMATIONAL ONLY
        {"path": "/series", "description": "Series data", "method": "GET"},
        {"path": "/category", "description": "Categories", "method": "GET"}
    ],
    example_calls=[  # INFORMATIONAL ONLY
        {"description": "Get GDP", "path": "/series/GDPC1", "params": {"file_type": "json"}}
    ],
    ...
)
```

### Calling APIs

**V1 - execute_dbsql/call_parameterized_api (Old):**
```python
# Used SQL http_request directly
execute_dbsql(
    query="""
    SELECT http_request(
        conn => 'fred_series_observations_connection',
        method => 'GET',
        path => '/series/observations',
        ...
    )
    """,
    ...
)
```

**V2 - execute_api_call (New):**
```python
# Dedicated tool with dynamic path
execute_api_call(
    api_name="fred_api",  # API from registry
    path="/series/GDPC1",  # ANY path - dynamic!
    params={"file_type": "json"},
    ...
)

# Call different path - no new registration needed!
execute_api_call(
    api_name="fred_api",
    path="/category/32991",  # Different path
    ...
)
```

## 📝 Workflow Changes

### Registration Workflow

**V1 (Old):**
1. Check registry for specific endpoint
2. If not found, register that endpoint
3. Repeat for each endpoint

**V2 (New):**
1. Check registry for API
2. If not found, register API once
3. Call any path dynamically

### Example Migration

**Before (V1):**
```
User: "Get GitHub repos"
1. check_api_http_registry() → Look for "github_repos"
2. Not found → Register "github_repos" with path="/user/repos"
3. Call execute_dbsql with "github_repos_connection"

User: "Get repo commits"
1. check_api_http_registry() → Look for "github_commits"
2. Not found → Register "github_commits" with path="/repos/{owner}/{repo}/commits"
3. Call execute_dbsql with "github_commits_connection"
```

**After (V2):**
```
User: "Get GitHub repos"
1. check_api_http_registry() → Look for "github_api"
2. Not found → Register "github_api" ONCE
3. execute_api_call(api_name="github_api", path="/user/repos")

User: "Get repo commits"
1. check_api_http_registry() → Look for "github_api"
2. FOUND! No registration needed
3. execute_api_call(api_name="github_api", path="/repos/databricks/mlflow/commits")
```

## ✅ Benefits of V2

1. **Scalability**: One registration supports infinite endpoints
2. **Flexibility**: Call any path without pre-registration
3. **Simplicity**: Fewer registry entries to manage
4. **Maintainability**: One entry to update for auth changes
5. **Speed**: No need to register before every new endpoint
6. **True REST**: Matches how APIs actually work

## 🎯 Best Practices

### API Naming

**Good:**
- `github_api`
- `fred_api`
- `weather_api`

**Bad:**
- `github_repos_api`
- `fred_series_observations`
- `weather_current_conditions`

### available_endpoints Structure

```json
[
  {
    "path": "/repos",
    "description": "Repository operations",
    "method": "GET"
  },
  {
    "path": "/user",
    "description": "User operations",  
    "method": "GET"
  }
]
```

### example_calls Structure

```json
[
  {
    "description": "Get specific repo",
    "path": "/repos/databricks/mlflow",
    "params": {"type": "public"}
  },
  {
    "description": "List user repos",
    "path": "/user/repos",
    "params": {}
  }
]
```

## 🚨 Breaking Changes

1. **Tool signature changed**: `register_api` no longer accepts `api_path`, `http_method`, `parameters`
2. **New tool**: Use `execute_api_call` instead of `execute_dbsql` for API calls
3. **Registry structure**: Different columns, unique constraint on `api_name`
4. **Naming convention**: API names should be API-level, not endpoint-specific

## 📞 Need Help?

- Check the new workflow: `prompts/api_registry_workflow.md`
- Review examples in the prompt
- Old workflow saved as: `prompts/api_registry_workflow_v1_old.md`

## 🎉 Summary

V2 is a **massive improvement**:
- Register once, call infinitely
- Scales to APIs with 100+ endpoints
- More flexible and maintainable
- Matches how REST APIs actually work

The migration requires recreating the table and re-registering APIs, but the benefits far outweigh the one-time effort!

