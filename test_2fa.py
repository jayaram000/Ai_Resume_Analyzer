import requests
import json
import base64
import os

BASE_URL = "http://127.0.0.1:8000/api/auth"

# Change these to your test user's credentials
EMAIL = "premium@example.com"
PASSWORD = "premium123"

def main():
    print(f"1. Logging in as {EMAIL}...")
    login_resp = requests.post(f"{BASE_URL}/login/", json={"email": EMAIL, "password": PASSWORD})
    
    if "requires_2fa" in login_resp.text:
        print("-> This account already has 2FA enabled! Try logging in through the Flutter App.")
        return
        
    if login_resp.status_code != 200:
        print(f"Login failed: {login_resp.text}")
        return
        
    token = login_resp.json()["access"]
    print("-> Login successful!")
    
    print("\n2. Setting up TOTP / 2FA...")
    headers = {"Authorization": f"Bearer {token}"}
    setup_resp = requests.post(f"{BASE_URL}/totp/setup/", headers=headers)
    
    if setup_resp.status_code != 200:
        print(f"Setup failed: {setup_resp.text}")
        return
        
    data = setup_resp.json()
    secret = data["secret"]
    b64_qr = data["qr_code"].split(",")[1]
    
    # Save QR code to a file so you can scan it
    with open("2fa_qrcode.png", "wb") as f:
        f.write(base64.b64decode(b64_qr))
        
    print(f"-> 2FA Secret: {secret}")
    print("-> QR Code saved as '2fa_qrcode.png'. Open this file and scan it with Google Authenticator!")
    
    code = input("\n3. Enter the 6-digit code from your Authenticator app to verify and enable 2FA: ")
    
    verify_resp = requests.post(
        f"{BASE_URL}/totp/verify/", 
        json={"email": EMAIL, "code": code}
    )
    
    if verify_resp.status_code == 200:
        print("\nSUCCESS! 2FA is now permanently enabled for this account.")
        print("Now, go to your Flutter app and try logging in. It will intercept the login and redirect you to the new 2FA Screen!")
    else:
        print(f"\nVerification failed: {verify_resp.text}")

if __name__ == "__main__":
    main()
