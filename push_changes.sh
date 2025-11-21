#!/bin/bash
cd /Users/luca.milletti/demos/mcp_server_api_registry

echo "=== Git Status ==="
git status

echo ""
echo "=== Adding changes ==="
git add client/src/pages/ChatPage.tsx client/src/pages/ChatPageAgent.tsx server/routers/chat.py client/src/App.tsx

echo ""
echo "=== Committing ==="
git commit -m "Update chat pages with step-by-step workflow guide, GPT-5 model configuration, and demo defaults"

echo ""
echo "=== Pushing to origin ==="
git push origin main

echo ""
echo "=== Pushing to lucamilletti99 repository ==="
git remote add lucamilletti99 https://github.com/lucamilletti99/mcp_api_registry_http.git 2>/dev/null || echo "Remote already exists"
git push lucamilletti99 main

echo ""
echo "=== Done ==="

