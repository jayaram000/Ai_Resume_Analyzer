import uuid
import logging
from django.conf import settings
from django.contrib.auth import get_user_model
from django.utils import timezone
from django.core.mail import send_mail
from accounts.models import UserProfile

User = get_user_model()
logger = logging.getLogger(__name__)

def send_verification_email(user) -> bool:
    """
    Sends an email verification link using Django SMTP.
    """
    token = str(uuid.uuid4())
    # Save token or pass in query (for simplicity we can save to profile or cache)
    profile = user.profile
    profile.verification_token = token
    profile.save()
    
    verify_url = f"http://localhost:8000/api/auth/verify-email/?token={token}"
    subject = "Verify your AI Career Copilot Account"
    html_body = f"<p>Welcome to AI Career Copilot! Click <a href='{verify_url}'>here</a> to verify your email.</p>"
    
    return send_email_via_smtp(user.email, subject, html_body)

def send_password_reset_email(user) -> bool:
    """
    Sends a password reset link using Django SMTP.
    """
    token = str(uuid.uuid4())
    profile = user.profile
    profile.reset_token = token
    profile.reset_token_expiry = timezone.now() + timezone.timedelta(hours=2)
    profile.save()
    
    reset_url = f"http://localhost:3000/#/reset-password?token={token}"
    subject = "Reset your AI Career Copilot Password"
    html_body = f"<p>You requested a password reset. Click <a href='{reset_url}'>here</a> to set a new password. Link expires in 2 hours.</p>"
    
    return send_email_via_smtp(user.email, subject, html_body)

def send_email_via_smtp(to_email: str, subject: str, html_content: str) -> bool:
    """
    Utility wrapper calling Django's built-in SMTP sender.
    """
    try:
        from_email = getattr(settings, 'EMAIL_HOST_USER', getattr(settings, 'EMAIL_FROM_ADDRESS', 'noreply@example.com'))
        send_mail(
            subject=subject,
            message="Please enable HTML emails to view this message.",
            html_message=html_content,
            from_email=from_email,
            recipient_list=[to_email],
            fail_silently=False,
        )
        return True
    except Exception as e:
        logger.error(f"Failed to send email via SMTP to {to_email}: {str(e)}")
        # Fallback to console print if SMTP fails
        print(f"\n--- [FALLBACK EMAIL PRINT] ---")
        print(f"To: {to_email}")
        print(f"Subject: {subject}")
        print(f"Body: {html_content}")
        print(f"------------------------------\n")
        return False
