#!/bin/bash
# Setup script for MCP secret scopes (API keys and Bearer tokens)
# This should be run by a Databricks admin

set -e

API_KEY_SCOPE="${MCP_API_KEY_SCOPE:-mcp_api_keys}"
BEARER_TOKEN_SCOPE="${MCP_BEARER_TOKEN_SCOPE:-mcp_bearer_tokens}"

echo "🔐 Setting up MCP secret scopes"
echo "   - API Keys scope: $API_KEY_SCOPE"
echo "   - Bearer Tokens scope: $BEARER_TOKEN_SCOPE"
echo ""

# Check if databricks CLI is available
if ! command -v databricks &> /dev/null; then
    echo "❌ Databricks CLI not found. Please install it first:"
    echo "   pip install databricks-cli"
    exit 1
fi

# Check authentication
echo "✅ Checking Databricks authentication..."
if ! databricks current-user me &> /dev/null; then
    echo "❌ Not authenticated with Databricks. Please run:"
    echo "   databricks configure --token"
    exit 1
fi

CURRENT_USER=$(databricks current-user me --output json | grep -o '"userName":"[^"]*"' | cut -d'"' -f4)
echo "   Authenticated as: $CURRENT_USER"
echo ""

# Create API keys scope
echo "📦 Creating API keys scope: $API_KEY_SCOPE"
if databricks secrets create-scope "$API_KEY_SCOPE" 2>/dev/null; then
    echo "   ✅ API keys scope created successfully"
else
    if databricks secrets list-scopes | grep -q "$API_KEY_SCOPE"; then
        echo "   ✅ API keys scope already exists"
    else
        echo "   ❌ Failed to create API keys scope"
        echo "   This may require admin permissions"
        exit 1
    fi
fi

# Create bearer tokens scope
echo "📦 Creating bearer tokens scope: $BEARER_TOKEN_SCOPE"
if databricks secrets create-scope "$BEARER_TOKEN_SCOPE" 2>/dev/null; then
    echo "   ✅ Bearer tokens scope created successfully"
else
    if databricks secrets list-scopes | grep -q "$BEARER_TOKEN_SCOPE"; then
        echo "   ✅ Bearer tokens scope already exists"
    else
        echo "   ❌ Failed to create bearer tokens scope"
        echo "   This may require admin permissions"
        exit 1
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Next Step: Grant Access to App Service Principal"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "To find your app's service principal ID:"
echo "   1. Go to your Databricks workspace"
echo "   2. Navigate to: Compute > Apps"
echo "   3. Click on your app (e.g., mcp-api-registry)"
echo "   4. Look for 'Service Principal ID' in the app details"
echo ""
read -p "Enter your app's service principal ID (or press Enter to skip): " SP_ID

if [ -n "$SP_ID" ]; then
    echo ""
    echo "🔐 Granting WRITE access to service principal: $SP_ID"
    
    # Note: CLI syntax is positional: databricks secrets put-acl SCOPE PRINCIPAL PERMISSION
    if databricks secrets put-acl "$API_KEY_SCOPE" "$SP_ID" WRITE 2>&1; then
        echo "   ✅ Granted access to $API_KEY_SCOPE"
    else
        echo "   ⚠️  Could not grant access to $API_KEY_SCOPE (may require admin permissions)"
    fi
    
    if databricks secrets put-acl "$BEARER_TOKEN_SCOPE" "$SP_ID" WRITE 2>&1; then
        echo "   ✅ Granted access to $BEARER_TOKEN_SCOPE"
    else
        echo "   ⚠️  Could not grant access to $BEARER_TOKEN_SCOPE (may require admin permissions)"
    fi
    
    echo ""
    echo "✅ Setup complete!"
    echo ""
    echo "Verify permissions:"
    echo "   databricks secrets list-acls $API_KEY_SCOPE"
    echo "   databricks secrets list-acls $BEARER_TOKEN_SCOPE"
    echo ""
    echo "Next step: Redeploy your app to pick up the 'secrets' scope"
    echo "   ./deploy.sh"
    echo ""
    echo "That's it! Users can now register APIs with authentication through the app."
    echo "No per-user permissions needed - the app handles everything!"
else
    echo ""
    echo "⚠️  Skipped ACL configuration. To grant access manually, run:"
    echo ""
    echo "   databricks secrets put-acl $API_KEY_SCOPE <service-principal-id> WRITE"
    echo "   databricks secrets put-acl $BEARER_TOKEN_SCOPE <service-principal-id> WRITE"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📖 How It Works"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "The app's service principal manages all secrets on behalf of users:"
echo "   - API key secrets stored as: $API_KEY_SCOPE/{api_name}"
echo "     Example: $API_KEY_SCOPE/fred"
echo "   - Bearer token secrets stored as: $BEARER_TOKEN_SCOPE/{api_name}"
echo "     Example: $BEARER_TOKEN_SCOPE/github"
echo ""
echo "To list secrets:"
echo "   databricks secrets list-secrets --scope $API_KEY_SCOPE"
echo "   databricks secrets list-secrets --scope $BEARER_TOKEN_SCOPE"
echo ""

