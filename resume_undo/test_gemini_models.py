import os
import requests
import json

api_key = os.getenv("GEMINI_API_KEY", "AIzaSyCexAzyR5h03zgXIdWTt0pbUqeirRCkAZ4")
url = f"https://generativelanguage.googleapis.com/v1beta/models?key={api_key}"
response = requests.get(url)
models = response.json().get("models", [])
for m in models:
    if "flash" in m["name"].lower():
        print(m["name"])
