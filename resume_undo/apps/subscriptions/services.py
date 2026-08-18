import hmac
import hashlib
import logging
import uuid
from django.conf import settings
from django.utils import timezone
from subscriptions.models import SubscriptionPlan, UserSubscription

logger = logging.getLogger(__name__)

def create_razorpay_order(plan: SubscriptionPlan) -> dict:
    """
    Creates a Razorpay Order ID for standard pay-as-you-go checkout.
    Falls back to generating mock details if credentials are not configured.
    """
    key_id = getattr(settings, "RAZORPAY_KEY_ID", None)
    key_secret = getattr(settings, "RAZORPAY_KEY_SECRET", None)
    
    amount_in_paise = int(plan.price * 100)
    
    if not key_id or not key_secret:
        logger.warning("Razorpay credentials missing. Using Mock Checkout.")
        return {
            "id": f"order_mock_{plan.id.hex[:10]}",
            "amount": amount_in_paise,
            "currency": "INR",
            "mock": True
        }
        
    try:
        import razorpay
        client = razorpay.Client(auth=(key_id, key_secret))
        data = {
            "amount": amount_in_paise,
            "currency": "INR",
            "receipt": f"receipt_{plan.name[:10]}",
            "payment_capture": 1
        }
        order = client.order.create(data=data)
        return order
    except Exception as e:
        logger.error(f"Failed to create Razorpay order: {str(e)}")
        # Fallback to mock
        return {
            "id": f"order_mock_{plan.id.hex[:10]}",
            "amount": amount_in_paise,
            "currency": "INR",
            "mock": True
        }

def verify_razorpay_payment(payment_id: str, order_id: str, signature: str) -> bool:
    """
    Verifies Razorpay payment signature authenticity.
    """
    key_secret = getattr(settings, "RAZORPAY_KEY_SECRET", None)
    if not key_secret:
        # local dev mock verification
        return order_id.startswith("order_mock_")
        
    try:
        import razorpay
        client = razorpay.Client(auth=(settings.RAZORPAY_KEY_ID, key_secret))
        # This will raise an error if verification fails
        client.utility.verify_payment_signature({
            'razorpay_order_id': order_id,
            'razorpay_payment_id': payment_id,
            'razorpay_signature': signature
        })
        return True
    except Exception as e:
        logger.error(f"Razorpay signature verification failed: {str(e)}")
        return False

def activate_user_subscription(user, plan: SubscriptionPlan, payment_id: str = None, subscription_id: str = None) -> UserSubscription:
    """
    Activates or updates the user subscription record in the database.
    """
    now = timezone.now()
    end_date = now + timezone.timedelta(days=plan.duration_days)
    
    # Deactivate existing subscriptions
    UserSubscription.objects.filter(user=user, status=UserSubscription.Status.ACTIVE).update(
        status=UserSubscription.Status.CANCELLED
    )
    
    sub, created = UserSubscription.objects.update_or_create(
        user=user,
        plan=plan,
        defaults={
            "start_date": now,
            "end_date": end_date,
            "status": UserSubscription.Status.ACTIVE,
            "razorpay_subscription_id": subscription_id or f"sub_local_{uuid.uuid4().hex[:10]}",
            "razorpay_payment_id": payment_id
        }
    )
    return sub
