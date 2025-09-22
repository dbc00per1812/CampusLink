#!/usr/bin/env python3
"""
Simple APNs key test script
Run this to test if your Apple Push Notifications key works
"""

import jwt
import time
import requests
import json

# Your credentials (replace with actual values)
TEAM_ID = "39QG7MQD33"
KEY_ID = "J89TH2Q724"  # Your new key ID
BUNDLE_ID = "darragh.CampusLink"

# You'll need to paste your .p8 file content here
PRIVATE_KEY = """
-----BEGIN PRIVATE KEY-----
[PASTE YOUR .p8 FILE CONTENT HERE]
-----END PRIVATE KEY-----
"""

def create_jwt():
    """Create JWT token for APNs"""
    now = int(time.time())
    
    payload = {
        'iss': TEAM_ID,
        'iat': now,
        'exp': now + 3600  # 1 hour
    }
    
    headers = {
        'kid': KEY_ID,
        'alg': 'ES256'
    }
    
    token = jwt.encode(payload, PRIVATE_KEY, algorithm='ES256', headers=headers)
    return token

def test_apns():
    """Test APNs connection"""
    try:
        # Create JWT
        jwt_token = create_jwt()
        print(f"✅ JWT created successfully")
        print(f"JWT length: {len(jwt_token)}")
        
        # Test with sandbox
        url = f"https://api.sandbox.push.apple.com/3/device/0000000000000000000000000000000000000000000000000000000000000000"
        
        headers = {
            'authorization': f'bearer {jwt_token}',
            'apns-topic': BUNDLE_ID,
            'apns-push-type': 'alert',
            'apns-priority': '10'
        }
        
        payload = {
            'aps': {
                'alert': 'Test notification',
                'sound': 'default'
            }
        }
        
        response = requests.post(url, headers=headers, json=payload)
        
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")
        
        if response.status_code == 400:
            print("✅ Key is valid! (400 expected for dummy device token)")
        elif response.status_code == 401:
            print("❌ InvalidProviderToken - Key authentication failed")
        else:
            print(f"Status: {response.status_code}")
            
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    print("🧪 Testing APNs Key...")
    print(f"Team ID: {TEAM_ID}")
    print(f"Key ID: {KEY_ID}")
    print(f"Bundle ID: {BUNDLE_ID}")
    print()
    
    test_apns()
