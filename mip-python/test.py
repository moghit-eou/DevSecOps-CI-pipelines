import os, json

# Add this temporarily to debug
creds_json = os.getenv("GOOGLE_CREDENTIALS")
print("Raw env var:", creds_json[:100])  # First 100 chars
creds_data = json.loads(creds_json)
print("Parsed structure:", creds_data.keys())
print("Has 'web' or 'installed'?:", 'web' in creds_data or 'installed' in creds_data)