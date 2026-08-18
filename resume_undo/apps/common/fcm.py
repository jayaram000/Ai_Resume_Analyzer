import logging
import requests
from django.conf import settings

logger = logging.getLogger(__name__)

def send_push_notification(user, title: str, body: str, data: dict = None) -> bool:
    """
    Sends a push notification via Firebase Cloud Messaging.
    Logs the message and returns True in development/mock mode.
    """
    # In development/mock mode, we log to stdout
    logger.info(f"FCM PUSH NOTIFICATION to user {user.email}: Title='{title}', Body='{body}', Data={data}")
    
    fcm_key = getattr(settings, "FIREBASE_FCM_SERVER_KEY", None)
    if not fcm_key:
        # Development fallback
        print(f"\n--- [MOCK FCM NOTIFICATION SENT] ---")
        print(f"To: {user.email}")
        print(f"Title: {title}")
        print(f"Body: {body}")
        print(f"Data: {data}")
        print(f"------------------------------------\n")
        return True
        
    # Standard Firebase FCM HTTP v1 API call
    # Note: Requires service account token authorization in a full production setup.
    # The HTTP legacy API uses a simple Server Key header:
    url = "https://fcm.googleapis.com/fcm/send"
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"key={fcm_key}"
    }
    
    payload = {
        "to": getattr(user.profile, "fcm_token", "/topics/all"),
        "notification": {
            "title": title,
            "body": body,
            "sound": "default"
        },
        "data": data or {}
    }
    
    try:
        response = requests.post(url, headers=headers, json=payload, timeout=10)
        response.raise_for_status()
        return True
    except Exception as e:
        logger.error(f"Failed to send FCM push notification: {str(e)}")
        return False
