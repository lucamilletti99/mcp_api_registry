# 🔐 Secret Management Guide

## Overview

The app uses **two shared secret scopes** to securely store API credentials:
- `mcp_api_keys` - For API key authentication
- `mcp_bearer_tokens` - For bearer token authentication

The app's **service principal** manages all secrets on behalf of users - no per-user permissions needed!

## Why This Approach?

Creating secret scopes requires **admin permissions**. Instead of:
- ❌ Creating a scope per API (requires admin every time)
- ❌ Granting permissions to every user (admin overhead)

We use:
- ✅ Two shared scopes (one-time admin setup)
- ✅ Service principal manages all secrets (no user friction)

### How It Works

**Before (Broken):**
- Each API gets its own scope: `fred_secrets`, `github_secrets`, etc.
- ❌ Requires admin permissions to create each scope

**After (Fixed):**
- API keys use one scope: `mcp_api_keys`
- Bearer tokens use another scope: `mcp_bearer_tokens`
- Secrets have simple names: just the API name
- ✅ Only requires TWO admin setups, then users can add APIs freely

### Why Two Scopes?

**Better organization:**
```bash
mcp_api_keys/           # Only API keys
  ├── fred              # No suffix needed - scope tells you it's an API key
  ├── alpha_vantage
  └── openweather

mcp_bearer_tokens/      # Only bearer tokens
  ├── github            # No suffix needed - scope tells you it's a bearer token
  ├── stripe
  └── shopify
```

**Benefits:**
- ✅ Clear separation of auth types
- ✅ Simpler secret names (no `_api_key` or `_bearer_token` suffix)
- ✅ Better permissions (can grant different access to each scope)
- ✅ Easier auditing

---

## 🚀 Setup (One-Time, Admin Required)

### Step 1: Find Your App's Service Principal ID

1. Go to your Databricks workspace
2. Navigate to: **Compute > Apps**
3. Click on your app (e.g., `mcp-api-registry`)
4. Look for **Service Principal ID** in the app details
5. Copy the ID (looks like: `12345678-1234-1234-1234-123456789abc`)

### Step 2: Run the Setup Script

```bash
./setup_shared_secrets.sh
# When prompted, paste your service principal ID
```

**The script will:**
- Create `mcp_api_keys` and `mcp_bearer_tokens` scopes
- Grant WRITE access to your app's service principal
- Verify everything is set up correctly

### Option: Manual Setup

If you prefer to set up manually:

```bash
# 1. Create the two secret scopes
databricks secrets create-scope mcp_api_keys
databricks secrets create-scope mcp_bearer_tokens

# 2. Grant WRITE access to the app's service principal
databricks secrets put-acl mcp_api_keys <your-service-principal-id> WRITE
databricks secrets put-acl mcp_bearer_tokens <your-service-principal-id> WRITE
```

### Step 3: Redeploy Your App

After setting up the scopes, redeploy to pick up the `secrets` scope:

```bash
./deploy.sh
```

---

## 📝 How Secrets Are Stored

### API Key Authentication

**Example:** Registering FRED API

```python
register_api(
    api_name="fred_economic_data",
    auth_type="api_key",
    secret_value="YOUR_FRED_API_KEY",
    # ...
)
```

**Stored as:**
- Scope: `mcp_api_keys` (dedicated API keys scope)
- Key: `fred_economic_data` (simple API name)
- Value: `YOUR_FRED_API_KEY`

**Used in SQL:**
```sql
SELECT http_request(
    conn => 'fred_connection',
    params => map(
        'api_key', secret('mcp_api_keys', 'fred_economic_data'),
        -- other params...
    )
)
```

---

### Bearer Token Authentication

**Example:** Registering GitHub API

```python
register_api(
    api_name="github_user_repos",
    auth_type="bearer_token",
    secret_value="ghp_YOUR_TOKEN",
    # ...
)
```

**Stored as:**
- Scope: `mcp_bearer_tokens` (dedicated bearer tokens scope)
- Key: `github_user_repos` (simple API name)
- Value: `ghp_YOUR_TOKEN`

**Used in Connection:**
```sql
CREATE CONNECTION github_connection
    bearer_token secret('mcp_bearer_tokens', 'github_user_repos')
```

---

## 🔍 Verifying Setup

### Check if scopes exist:
```bash
databricks secrets list-scopes | grep mcp_api_keys
databricks secrets list-scopes | grep mcp_bearer_tokens
```

### List all stored secrets:
```bash
# API keys
databricks secrets list-secrets --scope mcp_api_keys

# Bearer tokens
databricks secrets list-secrets --scope mcp_bearer_tokens
```

### Check permissions:
```bash
databricks secrets get-acl --scope mcp_api_keys --principal <your-email>
databricks secrets get-acl --scope mcp_bearer_tokens --principal <your-email>
```

---

## 🛠️ Custom Scope Names

You can use different scope names by setting environment variables:

### In `app.yaml`:
```yaml
environment:
  - name: MCP_API_KEY_SCOPE
    value: "my_custom_api_keys"
  - name: MCP_BEARER_TOKEN_SCOPE
    value: "my_custom_bearer_tokens"
```

### Or in `.env.local` for local development:
```bash
MCP_API_KEY_SCOPE=my_custom_api_keys
MCP_BEARER_TOKEN_SCOPE=my_custom_bearer_tokens
```

Then run the setup script, which will use your custom names.

---

## 🎯 For Different Environments

Create separate scopes for dev/staging/prod:

```bash
# Development
databricks secrets create-scope mcp_api_keys_dev
databricks secrets create-scope mcp_bearer_tokens_dev

# Staging  
databricks secrets create-scope mcp_api_keys_staging
databricks secrets create-scope mcp_bearer_tokens_staging

# Production
databricks secrets create-scope mcp_api_keys_prod
databricks secrets create-scope mcp_bearer_tokens_prod
```

Set via environment variables per deployment:
```yaml
# app.yaml for prod
environment:
  - name: MCP_API_KEY_SCOPE
    value: "mcp_api_keys_prod"
  - name: MCP_BEARER_TOKEN_SCOPE
    value: "mcp_bearer_tokens_prod"
```

---

## ⚠️ Security Notes

### Scope Organization
Separating API keys from bearer tokens means:
- ✅ Clear separation of auth types
- ✅ Granular permission management (different users can access different scopes)
- ✅ Easier auditing (see all API keys or all bearer tokens separately)
- ✅ Two-time admin setup (still better than per-API scopes)
- ⚠️ Users with WRITE can see API names in their scope (not secret values)
- ⚠️ Users with WRITE can update any secret in their scope

### Secret Naming Convention
Secrets are named simply with the API name:
- API Keys: `mcp_api_keys/fred`, `mcp_api_keys/alpha_vantage`
- Bearer Tokens: `mcp_bearer_tokens/github`, `mcp_bearer_tokens/stripe`

The scope name indicates the auth type, so no suffix is needed.

### Best Practices
1. **Grant READ to app service principal** - For reading secrets at runtime
2. **Grant WRITE to trusted users** - For registering new APIs
3. **Use different scopes per environment** - Dev/staging/prod isolation
4. **Audit secret access** - Monitor who's accessing secrets

---

## 🔄 Migration from Old Approach

If you had APIs registered with the old per-API scope approach:

### 1. List old secrets:
```bash
databricks secrets list-scopes | grep _secrets
```

### 2. Copy secrets to shared scope:
```bash
# For each API
OLD_SCOPE="fred_secrets"
NEW_SCOPE="mcp_api_secrets"
API_NAME="fred"

# Get the secret value (if you have access)
SECRET_VALUE=$(databricks secrets get --scope $OLD_SCOPE --key api_key)

# Put in new shared scope
databricks secrets put --scope $NEW_SCOPE \
  --key "${API_NAME}_api_key" \
  --string-value "$SECRET_VALUE"
```

### 3. Re-register APIs:
After copying secrets, re-register the API (it will use the new shared scope).

---

## 🐛 Troubleshooting

### Error: "Secret scope 'mcp_api_keys' or 'mcp_bearer_tokens' does not exist"
**Solution:** Run `./setup_shared_secrets.sh` or manually create both scopes

### Error: "Permission denied" or "Failed to store secret"
**Solution:** The app's service principal doesn't have WRITE access to the secret scopes yet.

Ask an admin to run the setup script:
```bash
./setup_shared_secrets.sh
# Enter the app's service principal ID when prompted
```

Or manually grant access:
```bash
databricks secrets put-acl mcp_api_keys <app-service-principal-id> WRITE
databricks secrets put-acl mcp_bearer_tokens <app-service-principal-id> WRITE
```

**Find your service principal ID:**
Databricks UI → Compute → Apps → Your App → Service Principal ID

### APIs registered but not working
**Solution:** Check the secret exists in the correct scope:
```bash
# For API key auth
databricks secrets list-secrets --scope mcp_api_keys

# For bearer token auth
databricks secrets list-secrets --scope mcp_bearer_tokens
```

### Wrong scope being used
**Solution:** Check environment variables in `app.yaml`:
```yaml
environment:
  - name: MCP_API_KEY_SCOPE
    value: "mcp_api_keys"  # Must match created scope
  - name: MCP_BEARER_TOKEN_SCOPE
    value: "mcp_bearer_tokens"  # Must match created scope
```

---

## 📚 Additional Resources

- [Databricks Secret Scopes Documentation](https://docs.databricks.com/security/secrets/secret-scopes.html)
- [Secret ACLs](https://docs.databricks.com/security/secrets/secret-acl.html)
- [Unity Catalog HTTP Connections](https://docs.databricks.com/sql/language-manual/sql-ref-syntax-ddl-create-connection.html)

