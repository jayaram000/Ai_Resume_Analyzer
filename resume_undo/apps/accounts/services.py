import uuid
import logging
from django.conf import settings
from django.contrib.auth import get_user_model
from django.utils import timezone
from accounts.models import UserProfile

User = get_user_model()
logger = logging.getLogger(__name__)

def send_verification_email(user) -> bool:
    """
    Sends an email verification link using Resend.
    Falls back to console prints if API keys are missing.
    """
    token = str(uuid.uuid4())
    # Save token or pass in query (for simplicity we can save to profile or cache)
    profile = user.profile
    profile.verification_token = token
    profile.save()
    
    verify_url = f"http://localhost:8000/api/auth/verify-email/?token={token}"
    subject = "Verify your AI Career Copilot Account"
    html_body = f"<p>Welcome to AI Career Copilot! Click <a href='{verify_url}'>here</a> to verify your email.</p>"
    
    return send_email_via_resend(user.email, subject, html_body)

def send_password_reset_email(user) -> bool:
    """
    Sends a password reset link using Resend.
    """
    token = str(uuid.uuid4())
    profile = user.profile
    profile.reset_token = token
    profile.reset_token_expiry = timezone.now() + timezone.timedelta(hours=2)
    profile.save()
    
    reset_url = f"http://localhost:8000/api/auth/reset-password/?token={token}"
    subject = "Reset your AI Career Copilot Password"
    html_body = f"<p>You requested a password reset. Click <a href='{reset_url}'>here</a> to set a new password. Link expires in 2 hours.</p>"
    
    return send_email_via_resend(user.email, subject, html_body)

def send_email_via_resend(to_email: str, subject: str, html_content: str) -> bool:
    """
    Utility wrapper calling Resend Email API.
    Logs email to console if RESEND_API_KEY is not defined.
    """
    api_key = getattr(settings, "RESEND_API_KEY", None)
    if not api_key:
        print(f"\n--- [MOCK EMAIL SENT VIA RESEND] ---")
        print(f"To: {to_email}")
        print(f"Subject: {subject}")
        print(f"Body: {html_content}")
        print(f"-------------------------------------\n")
        return True
        
    try:
        import resend
        resend.api_key = api_key
        params = {
            "from": getattr(settings, "EMAIL_FROM_ADDRESS", "onboarding@resend.dev"),
            "to": [to_email],
            "subject": subject,
            "html": html_content
        }
        resend.Emails.send(params)
        return True
    except Exception as e:
        logger.error(f"Failed to send email via Resend to {to_email}: {str(e)}")
        # Fallback to local printing to prevent blocking operations
        print(f"\n--- [FALLBACK EMAIL PRINT] ---")
        print(f"To: {to_email}")
        print(f"Subject: {subject}")
        print(f"------------------------------\n")
        return False
