#!/usr/bin/env python3
"""
Debug script for API authentication issues in the MCP API Registry.

Usage:
    python debug_api_auth.py <api_id> <warehouse_id> <catalog> <schema>

This script will:
1. Check if the API exists in the registry
2. Verify the connection exists
3. Check if secrets are properly configured
4. Test the connection
5. Attempt a test API call
"""

import sys
import os
from databricks.sdk import WorkspaceClient


def debug_api(api_id: str, warehouse_id: str, catalog: str, schema: str):
    """Debug an API registration."""
    
    print("\n" + "="*80)
    print("🔍 API Authentication Debugger")
    print("="*80 + "\n")
    
    # Initialize workspace client
    w = WorkspaceClient()
    
    # Step 1: Check if API exists in registry
    print("📊 Step 1: Checking API registry...")
    table_name = f'{catalog}.{schema}.api_http_registry'
    query = f"""
        SELECT 
            api_id,
            api_name,
            connection_name,
            host,
            base_path,
            api_path,
            auth_type,
            secret_scope,
            http_method,
            status
        FROM {table_name}
        WHERE api_id = '{api_id}'
    """
    
    try:
        result = w.statement_execution.execute_statement(
            warehouse_id=warehouse_id,
            statement=query,
            wait_timeout='30s'
        )
        
        if not result.result or not result.result.data_array or len(result.result.data_array) == 0:
            print(f"❌ API with id '{api_id}' not found in registry!")
            print(f"   Table: {table_name}")
            return
        
        # Parse the result
        columns = [col.name for col in result.manifest.schema.columns]
        row = result.result.data_array[0]
        api_data = {columns[i]: row[i] for i in range(len(columns))}
        
        print("✅ API found in registry:")
        print(f"   Name: {api_data.get('api_name')}")
        print(f"   Connection: {api_data.get('connection_name')}")
        print(f"   Auth Type: {api_data.get('auth_type')}")
        print(f"   Secret Scope: {api_data.get('secret_scope') or 'None'}")
        print(f"   Status: {api_data.get('status')}")
        print(f"   Endpoint: {api_data.get('host')}{api_data.get('base_path') or ''}{api_data.get('api_path')}")
        
        connection_name = api_data.get('connection_name')
        auth_type = api_data.get('auth_type')
        secret_scope = api_data.get('secret_scope')
        
    except Exception as e:
        print(f"❌ Error querying registry: {str(e)}")
        return
    
    # Step 2: Check if connection exists
    print(f"\n🔌 Step 2: Checking UC HTTP Connection...")
    full_connection_name = f"{catalog}.{schema}.{connection_name}"
    
    try:
        # Try to get the connection
        conn = w.connections.get(full_connection_name)
        print(f"✅ Connection exists: {full_connection_name}")
        print(f"   Host: {conn.options.get('host') if conn.options else 'N/A'}")
        print(f"   Base Path: {conn.options.get('base_path') if conn.options else 'N/A'}")
        print(f"   Owner: {conn.owner}")
        
        # Check bearer_token configuration
        if conn.options:
            bearer_token = conn.options.get('bearer_token', 'NOT_SET')
            if bearer_token == '':
                print(f"   Bearer Token: EMPTY ✅ (correct for api_key or none auth)")
            elif 'secret(' in str(bearer_token):
                print(f"   Bearer Token: SECRET REFERENCE ✅ (correct for bearer_token auth)")
            else:
                print(f"   Bearer Token: {bearer_token}")
        
    except Exception as e:
        print(f"❌ Connection not found or error: {str(e)}")
        print(f"   Expected name: {full_connection_name}")
        return
    
    # Step 3: Check secrets (if applicable)
    if secret_scope and auth_type in ['api_key', 'bearer_token']:
        print(f"\n🔐 Step 3: Checking secret scope...")
        
        try:
            # List secrets in the scope
            secrets = list(w.secrets.list_secrets(scope=secret_scope))
            print(f"✅ Secret scope exists: {secret_scope}")
            print(f"   Number of secrets: {len(secrets)}")
            
            # Check for the expected secret key
            expected_key = 'bearer_token' if auth_type == 'bearer_token' else 'api_key'
            secret_keys = [s.key for s in secrets]
            
            if expected_key in secret_keys:
                print(f"   ✅ Expected secret key '{expected_key}' found")
            else:
                print(f"   ❌ Expected secret key '{expected_key}' NOT FOUND")
                print(f"   Available keys: {secret_keys}")
                
        except Exception as e:
            print(f"❌ Error accessing secret scope: {str(e)}")
            if "does not exist" in str(e).lower():
                print(f"   The secret scope '{secret_scope}' doesn't exist!")
                print(f"   Create it with: databricks secrets create-scope {secret_scope}")
    else:
        print(f"\n🔐 Step 3: Secret scope not needed (auth_type={auth_type})")
    
    # Step 4: Test connection (optional - requires serving endpoints API)
    print(f"\n🧪 Step 4: Testing connection...")
    print(f"   (Skipping - would require serving endpoints API)")
    
    # Step 5: Generate test SQL
    print(f"\n📝 Step 5: Generated test SQL:")
    print(f"\n```sql")
    
    if auth_type == 'none':
        print(f"""SELECT http_request(
  conn => '{full_connection_name}',
  method => '{api_data.get('http_method')}',
  path => '{api_data.get('api_path')}',
  headers => map('Accept', 'application/json')
);""")
    elif auth_type == 'api_key':
        print(f"""SELECT http_request(
  conn => '{full_connection_name}',
  method => '{api_data.get('http_method')}',
  path => '{api_data.get('api_path')}',
  params => map(
    'api_key', secret('{secret_scope}', 'api_key'),
    -- Add your parameters here
    'param1', 'value1'
  ),
  headers => map('Accept', 'application/json')
);""")
    elif auth_type == 'bearer_token':
        print(f"""SELECT http_request(
  conn => '{full_connection_name}',
  method => '{api_data.get('http_method')}',
  path => '{api_data.get('api_path')}',
  params => map(
    -- Add your parameters here
    'param1', 'value1'
  ),
  headers => map('Accept', 'application/json')
);""")
    
    print(f"```\n")
    
    # Summary
    print("="*80)
    print("📋 Summary")
    print("="*80)
    
    issues = []
    
    if auth_type == 'api_key':
        print("\n✅ For API key auth, connection should have:")
        print("   - bearer_token: EMPTY string")
        print("   - Secret scope with key 'api_key'")
        print("   - API key passed in params at runtime")
        
        if bearer_token != '':
            issues.append("Connection has non-empty bearer_token for api_key auth")
            
    elif auth_type == 'bearer_token':
        print("\n✅ For bearer token auth, connection should have:")
        print("   - bearer_token: secret reference")
        print("   - Secret scope with key 'bearer_token'")
        print("   - Token automatically included in Authorization header")
        
        if 'secret(' not in str(bearer_token):
            issues.append("Connection doesn't reference secret for bearer_token auth")
            
    elif auth_type == 'none':
        print("\n✅ For public APIs, connection should have:")
        print("   - bearer_token: EMPTY string")
        print("   - No secret scope needed")
        
        if bearer_token != '':
            issues.append("Connection has non-empty bearer_token for public API (should be empty string)")
    
    if issues:
        print("\n⚠️  Potential Issues Found:")
        for issue in issues:
            print(f"   - {issue}")
    else:
        print("\n✅ Configuration looks correct!")
    
    print("\n" + "="*80 + "\n")


if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("Usage: python debug_api_auth.py <api_id> <warehouse_id> <catalog> <schema>")
        print("\nExample:")
        print("  python debug_api_auth.py abc-123 your-warehouse-id my_catalog my_schema")
        sys.exit(1)
    
    api_id = sys.argv[1]
    warehouse_id = sys.argv[2]
    catalog = sys.argv[3]
    schema = sys.argv[4]
    
    debug_api(api_id, warehouse_id, catalog, schema)

