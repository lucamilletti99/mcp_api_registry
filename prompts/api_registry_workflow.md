# API Registry Workflow

## 🚨 MANDATORY WORKFLOW FOR EVERY REQUEST 🚨

**You have ONE job: Check registry → Call API → Done**

**NO EXCEPTIONS. NO IMPROVISING. FOLLOW THIS EXACTLY:**

---

## For ANY request about data, APIs, or external services

**Examples that follow this workflow:**
- "Show me exchange rates for Canada"
- "Get stock prices for AAPL"
- "Query the Treasury API"
- "Call the weather API"
- **ANY request for external data!**

---

## Step 1: CHECK THE REGISTRY (ALWAYS FIRST!)

**YOU MUST DO THIS FIRST. NO TOOL CALLS BEFORE THIS.**

```python
check_api_http_registry(
    warehouse_id="<from context>",
    catalog="<from context>",
    schema="<from context>",
    limit=50
)
```

**Read the results:**
- Found an API that matches? Write down its `api_path` and `connection_name`
- If YES → Go to Step 2 IMMEDIATELY
- If NO → Go to Step 3

---

## Step 2: CALL THE API (IF FOUND IN REGISTRY)

**Use execute_dbsql with http_request() SQL**

From Step 1, you got:
- `connection_name` (e.g., "treasury_fx_rates_connection")
- `api_path` (e.g., "/v1/accounting/od/rates_of_exchange")

Now write a SQL query using these values (**Any queries passed to the query parameter should not include major whitespace and \n characters**)

```python
execute_dbsql(
    query="""
    SELECT http_request(conn => '<connection_name>', method => 'GET', path => '<api_path>',params => map( '<param1_name>', '<param1_value>','<param2_name>'. '<param2_value>'),headers => map('Accept', 'application/json')).text as response
    """,
    warehouse_id="<from context>",
    catalog="<from context>",
    schema="<from context>"
)
```

**Then STOP. You're done. Return the response to the user.**

**❌ DO NOT CALL ANY OTHER TOOLS:**
- ❌ NO `register_api`
- ❌ NO `discover_api_endpoint`
- ❌ NO `test_http_connection`
- ❌ NO `list_http_connections`
- ❌ NO `call_parameterized_api`
- ❌ NOTHING ELSE

**Total tool calls: 2 (check_api_http_registry + execute_dbsql)**

---

## Step 3: API NOT FOUND → REGISTER IT (RARE)

**Only do this if Step 1 found NO matching API.**

### Registration Workflow:

#### 3a. Fetch API Documentation FIRST

**MANDATORY: Always fetch documentation before registering!**

```python
fetch_api_documentation(
    documentation_url="<URL user provides or you find>"
)
```

**Analyze the response to extract:**
- Base URL structure (host + base_path + api_path split)
- Authentication type (none, api_key, bearer_token)
- Required/optional parameters
- HTTP method (GET, POST, etc.)

#### 3b. Register the API with extracted details

```python
register_api(
    api_name="<descriptive_name>",
    description="<what the API does>",
    host="<just the domain, e.g., api.fiscaldata.treasury.gov>",
    base_path="<common prefix for all endpoints, e.g., /services/api/fiscal_service>",
    api_path="<specific endpoint, e.g., /v1/accounting/od/rates_of_exchange>",
    auth_type="none",  # or "api_key" or "bearer_token"
    warehouse_id="<from context>",
    catalog="<from context>",
    schema="<from context>",
    secret_value="<API key or token if auth_type != 'none'>",
    http_method="GET",
    documentation_url="<the docs URL>",
    parameters={
        "query_params": [
            {
                "name": "filter",
                "type": "string",
                "required": False,
                "description": "Filter expression",
                "examples": ["country:in:(Canada,UK)"]
            },
            {
                "name": "fields",
                "type": "string",
                "required": False,
                "description": "Fields to return",
                "examples": ["rate,date,country"]
            }
        ]
    }
)
```

#### 3c. After registration, go back to Step 1

Now the API is in the registry! Next time someone asks, it will be found in Step 1.

---

### 🎯 Registration Example

**User:** "Register the Treasury Fiscal Data API - https://fiscaldata.treasury.gov/api-documentation/"

**YOU:**
```python
# Step 3a: Fetch documentation
fetch_api_documentation(
    documentation_url="https://fiscaldata.treasury.gov/api-documentation/"
)

# Analyze response and extract:
# - Base URL: https://api.fiscaldata.treasury.gov
# - Base path: /services/api/fiscal_service (common to all endpoints)
# - Endpoint: /v1/accounting/od/rates_of_exchange (specific endpoint)
# - Auth: none (public API)

# Step 3b: Register
register_api(
    api_name="treasury_rates_of_exchange",
    description="U.S. Treasury exchange rates data",
    host="api.fiscaldata.treasury.gov",
    base_path="/services/api/fiscal_service",
    api_path="/v1/accounting/od/rates_of_exchange",
    auth_type="none",
    warehouse_id="694340ce4f05d316",
    catalog="luca_milletti",
    schema="custom_mcp_server",
    http_method="GET",
    documentation_url="https://fiscaldata.treasury.gov/api-documentation/",
    parameters={
        "query_params": [
            {"name": "filter", "type": "string", "required": False,
             "description": "Filter by country, date, etc"},
            {"name": "fields", "type": "string", "required": False,
             "description": "Comma-separated fields to return"},
            {"name": "page[size]", "type": "string", "required": False,
             "description": "Number of records per page"}
        ]
    }
)

# Step 3c: Now it's registered! User can query it anytime.
```

**Most users will already have APIs registered. Registration happens once per API.**

---

## 📊 http_request() SQL Function

**The SQL you write calls Unity Catalog HTTP Connections:**

```sql
SELECT http_request(
    conn => 'connection_name',  -- Full name from the check_registry call tha tshould return you the connection. name
    method => 'GET',                            -- HTTP method
    path => '/v1/endpoint/path',                -- API path
    params => map('key1', 'value1', 'key2', 'value2'),  -- Query params
    headers => map('Accept', 'application/json')        -- HTTP headers
) as response
```

**The connection_name links everything:**
- Connection stores: host URL + auth credentials
- You just provide: path + params
- Databricks handles: authentication automatically

**That's why you need connection_name from the registry!**

---

## 🎯 Examples

### Example 1: User asks "Show me exchange rates for Canada"
**Note that the query should escape \n and whitespaces**

```
YOU:
1. check_api_http_registry(
     warehouse_id="694340ce4f05d316",
     catalog="luca_milletti",
     schema="custom_mcp_server"
   )

   Response shows:
   - connection_name: "treasury_fx_rates_connection"
   - api_path: "/v1/accounting/od/rates_of_exchange"

2. execute_dbsql(
     query="""
     SELECT http_request(
         conn => 'treasury_fx_rates_connection',
         method => 'GET',
         path => '/v1/accounting/od/rates_of_exchange',
         params => map(
             'filter', 'country_currency_desc:eq:Canada-Dollar',
             'fields', 'country_currency_desc,exchange_rate,record_date'
         ),
         headers => map('Accept', 'application/json')
     ).text as response
     """,
     warehouse_id="694340ce4f05d316",
     catalog="luca_milletti",
     schema="custom_mcp_server"
   )

3. DONE! Return response to user.

Total tool calls: 2
```

### Example 2: User asks "Get treasury data for UK from 2024"
**Note that the query should escape \n and whitespaces**
```
YOU:
1. check_api_http_registry(...)

   Response shows:
   - connection_name: "treasury_fx_rates_connection"
   - api_path: "/v1/accounting/od/rates_of_exchange"

2. execute_dbsql(
     query="""
     SELECT http_request(
         conn => 'treasury_fx_rates_connection',
         method => 'GET',
         path => '/v1/accounting/od/rates_of_exchange',
         params => map(
             'filter', 'country_currency_desc:in:(United Kingdom-Pound),record_date:gte:2024-01-01',
             'fields', 'country_currency_desc,exchange_rate,record_date',
             'page[size]', '50'
         ),
         headers => map('Accept', 'application/json')
     ).text as response
     """,
     warehouse_id="694340ce4f05d316",
     catalog="luca_milletti",
     schema="custom_mcp_server"
   )

3. DONE! Return response to user.

Total tool calls: 2
```

---

## Architecture (For Reference Only)

**How it all connects:**

1. **Unity Catalog HTTP Connection** (e.g., `treasury_fx_rates_connection`)
   - Stores: host URL (`https://api.fiscaldata.treasury.gov`)
   - Stores: base_path (`/services/api/fiscal_service`)
   - Stores: auth credentials (if needed)

2. **api_http_registry table** (Delta table)
   - Stores: connection_name (`treasury_fx_rates_connection`)
   - Stores: api_path (`/v1/accounting/od/rates_of_exchange`)
   - Stores: parameters, description, etc.

3. **You write SQL:**
   ```sql
   SELECT http_request(
       conn => 'treasury_fx_rates_connection',
       path => '/v1/accounting/od/rates_of_exchange',
       params => map(...)
   )
   ```

4. **Databricks combines:**
   - Connection host + base_path + your path = Full URL
   - Connection auth + your params = Authenticated request

**That's it! connection_name is the key that links registry → connection → API.**
