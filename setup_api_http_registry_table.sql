-- API HTTP Registry Table Schema (Refactored for API-level registration)
-- This table stores ONE ENTRY PER API (not per endpoint)
-- Credentials are stored in Secret Scopes, referenced by connections via secret() function
-- Supports three authentication flavors: none, api_key, bearer_token
--
-- ARCHITECTURE: Register API once, call dynamically
-- - Register: github_api with host="api.github.com", base_path=""
-- - Call: http_request(conn => 'github_api', path => '/repos/owner/repo/commits')
-- - Call: http_request(conn => 'github_api', path => '/user/repos')
-- - Call: http_request(conn => 'github_api', path => '/orgs/databricks/members')
-- All without registering each endpoint separately!

CREATE TABLE IF NOT EXISTS {catalog}.{schema}.api_http_registry (
  -- Unique identifier for the API
  api_id STRING NOT NULL,

  -- API metadata
  api_name STRING NOT NULL COMMENT 'Unique name for the API (e.g., "github_api", "fred_api")',
  description STRING,

  -- Connection configuration (API-level, not endpoint-specific)
  connection_name STRING NOT NULL COMMENT 'Name of the UC HTTP Connection (created via SQL)',
  host STRING NOT NULL COMMENT 'API host (e.g., "api.github.com")',
  base_path STRING COMMENT 'Base path for API (e.g., "/v1", "/api", or empty string)',

  -- Authentication configuration
  auth_type STRING NOT NULL COMMENT 'Authentication type: "none", "api_key", or "bearer_token"',
  secret_scope STRING COMMENT 'Secret scope name: "mcp_api_keys" for api_key auth, "mcp_bearer_tokens" for bearer_token auth, NULL for auth_type=none',

  -- Documentation and reference
  documentation_url STRING COMMENT 'API documentation URL for reference',
  available_endpoints STRING COMMENT 'JSON array of available endpoints with metadata: [{"path":"/repos","description":"Repository operations","method":"GET"},{"path":"/user","description":"User operations","method":"GET"}]',
  example_calls STRING COMMENT 'JSON array of concrete usage examples: [{"description":"Get a repo","path":"/repos/databricks/mlflow","params":{"type":"public"}},{"description":"List user repos","path":"/user/repos","params":{}}]',

  -- Status tracking
  status STRING,
  validation_message STRING,

  -- Audit fields
  user_who_requested STRING,
  created_at TIMESTAMP,
  modified_date TIMESTAMP,

  -- Primary key
  CONSTRAINT api_http_registry_pk PRIMARY KEY (api_id)
  
  -- Note: API name uniqueness is enforced at application level (check_registry tool)
  -- Database-level UNIQUE constraint requires spark.databricks.sql.dsv2.unique.enabled=true
)
COMMENT 'API Registry - ONE ENTRY PER API. Register once (host+base_path), call dynamically with any path at runtime.'
-- Default value features
TBLPROPERTIES (
  'delta.enableChangeDataFeed' = 'true',
  'delta.feature.allowColumnDefaults' = 'supported'
);
