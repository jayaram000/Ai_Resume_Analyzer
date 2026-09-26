from rest_framework.permissions import BasePermission
from rest_framework.exceptions import APIException
from rest_framework import status
from django.utils import timezone
from django.conf import settings


class UsageQuotaExceeded(APIException):
    status_code = status.HTTP_429_TOO_MANY_REQUESTS
    default_code = "quota_exceeded"

    def __init__(self, usage_remaining=0, reset_at=None):
        detail = {
            "success": False,
            "error": "Usage quota exceeded",
            "message": "Please upgrade to Premium or wait for 5 hours.",
            "usage_remaining": usage_remaining,
            "reset_at": reset_at,
        }
        super().__init__(detail=detail)


class HasUsageQuota(BasePermission):
    """
    Checks if the user has remaining free quota before allowing gated requests.
    Attaches `usage_remaining` and `usage_reset_at` to the request object.
    """
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False

        from common.usage_limiter import get_usage_status
        allowed, remaining, reset_at = get_usage_status(request.user)

        request.usage_remaining = remaining
        request.usage_reset_at = reset_at

        if not allowed:
            raise UsageQuotaExceeded(usage_remaining=remaining, reset_at=reset_at)
        return True


class IsPremiumUser(BasePermission):
    message = "Premium subscription required to access this resource."

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        
        # Admins/Staff/Superusers bypass premium restriction
        if getattr(request.user, 'role', 'USER') == 'ADMIN' or request.user.is_staff or request.user.is_superuser:
            return True

        # Avoid circular imports by importing inside the method
        from subscriptions.models import UserSubscription
        
        now = timezone.now()
        active_sub = UserSubscription.objects.filter(
            user=request.user,
            status='active',
            start_date__lte=now,
            end_date__gte=now
        ).exclude(plan__price=0).exists()

        return active_sub

