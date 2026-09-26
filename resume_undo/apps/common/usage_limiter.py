from datetime import timedelta
from typing import Tuple, Optional
from django.utils import timezone
from django.db import transaction
from common.models import FeatureUsageLog

FREE_QUOTA_LIMIT = 3
ROLLING_WINDOW_HOURS = 5


def is_quota_exempt(user) -> bool:
    """Admin, staff, superuser, and active Pro subscribers bypass limits."""
    if not user or not user.is_authenticated:
        return False
    if user.is_superuser or user.is_staff or getattr(user, "role", "USER") == "ADMIN":
        return True

    from subscriptions.models import UserSubscription
    now = timezone.now()
    has_active_sub = UserSubscription.objects.filter(
        user=user,
        status="active",
        start_date__lte=now,
        end_date__gte=now,
    ).exclude(plan__price=0).exists()
    return has_active_sub


def get_usage_status(user) -> Tuple[bool, int, Optional[str]]:
    """
    Returns (allowed, remaining_count, reset_at_iso).
    Rolling window: calculates remaining slots within the last 5 hours.
    """
    if is_quota_exempt(user):
        return True, 9999, None

    now = timezone.now()
    window_start = now - timedelta(hours=ROLLING_WINDOW_HOURS)

    # Fetch active usage events in the last 5 hours ordered oldest first
    active_logs = list(FeatureUsageLog.objects.filter(
        user=user,
        created_at__gte=window_start,
    ).order_by("created_at"))

    active_count = len(active_logs)

    # When all 3 free scans are used (0/3), the 5-hour cooldown timer starts from the 3rd scan
    if active_count >= FREE_QUOTA_LIMIT:
        exhaustion_log = active_logs[FREE_QUOTA_LIMIT - 1]
        reset_time = exhaustion_log.created_at + timedelta(hours=ROLLING_WINDOW_HOURS)
        if now < reset_time:
            return False, 0, reset_time.isoformat()
        else:
            # 5-hour cooldown has elapsed - restore full 3 scans
            return True, FREE_QUOTA_LIMIT, None

    # User still has remaining scans (3, 2, or 1 left) - 5hr timer has not started
    remaining = FREE_QUOTA_LIMIT - active_count
    return True, remaining, None


def consume_usage(user, action_type: str) -> Tuple[bool, int, Optional[str]]:
    """
    Logs an action if non-exempt. Uses row locking to prevent limit bypass race conditions.
    """
    if is_quota_exempt(user):
        return True, 9999, None

    with transaction.atomic():
        from django.contrib.auth import get_user_model
        User = get_user_model()
        User.objects.select_for_update().get(id=user.id)

        allowed, remaining, reset_at = get_usage_status(user)
        if not allowed:
            return False, 0, reset_at

        FeatureUsageLog.objects.create(user=user, action_type=action_type)
        # Recalculate remaining post-consumption
        _, new_remaining, new_reset_at = get_usage_status(user)
        return True, new_remaining, new_reset_at
