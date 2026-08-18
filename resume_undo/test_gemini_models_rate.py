import os
import requests
import json
import time

api_key = os.getenv("GEMINI_API_KEY", "AIzaSyCexAzyR5h03zgXIdWTt0pbUqeirRCkAZ4")

for model in ["gemini-3.5-flash", "gemini-2.0-flash", "gemini-flash-latest"]:
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
    payload = {
        "contents": [{"parts": [{"text": "say hi"}]}],
        "generationConfig": {"temperature": 0.2}
    }
    response = requests.post(url, headers={"Content-Type": "application/json"}, json=payload)
    print(f"Model: {model}, Status: {response.status_code}")
    if response.status_code == 200:
        print("Success:", response.json()["candidates"][0]["content"]["parts"][0]["text"])
    else:
        print(response.text)
    time.sleep(1)
