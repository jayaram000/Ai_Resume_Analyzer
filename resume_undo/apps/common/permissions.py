from rest_framework.permissions import BasePermission
from django.utils import timezone
from django.conf import settings

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
