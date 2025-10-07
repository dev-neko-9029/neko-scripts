#!/bin/bash

echo "================================================"
echo "Authenticating for Credijusto Cli - Ai assistance..."
echo "================================================"

# Check VAULT_TOKEN
if [ -z "$VAULT_TOKEN" ]; then
    echo "ERROR: VAULT_TOKEN not set"
    echo "Please run: export VAULT_TOKEN=your_token"
    exit 1
fi

# Fetch secret from Vault
echo "Fetching client secret from Vault..."
CLIENT_SECRET=$(curl -s -H "X-Vault-Token: $VAULT_TOKEN" \
    https://vault.covalto.support/v1/support/data/cli | \
    jq -r '.data.data.CLIENT_SECRET')

if [ "$CLIENT_SECRET" == "null" ]; then
    echo "ERROR: Failed to fetch secret from Vault"
    echo "Your VAULT_TOKEN is invalid or expired."
    echo "Please obtain a new token and set it:"
    echo "  export VAULT_TOKEN=your_new_token"
    exit 1
fi

# Create temporary file
TEMP_FILE=$(mktemp /tmp/client_secret.XXXXXX.json)
echo "$CLIENT_SECRET" > "$TEMP_FILE"

# Authenticate
echo "Authenticating with Google Cloud..."
gcloud auth application-default login \
    --client-id-file="$TEMP_FILE" \
    --scopes='https://www.googleapis.com/auth/cloud-platform,https://www.googleapis.com/auth/generative-language.retriever'

# Cleanup
rm -f "$TEMP_FILE"

echo "================================================"
echo "✓ Authentication complete!"
echo "You can now use the Credijusto-cli command suite - Ai assistance"
echo "================================================"