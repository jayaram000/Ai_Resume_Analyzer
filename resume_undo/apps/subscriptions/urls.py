from django.urls import path
from subscriptions.views import (
    SubscriptionPlanListView,
    CreateCheckoutSessionView,
    VerifyPaymentView,
    ActiveSubscriptionView
)

urlpatterns = [
    path("plans/", SubscriptionPlanListView.as_view(), name="subscription-plans"),
    path("checkout/", CreateCheckoutSessionView.as_view(), name="subscription-checkout"),
    path("verify/", VerifyPaymentView.as_view(), name="subscription-verify"),
    path("active/", ActiveSubscriptionView.as_view(), name="subscription-active"),
]
