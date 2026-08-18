from django.urls import path
from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)
from accounts.views import (
    RegisterView,
    EmailVerificationView,
    PasswordResetRequestView,
    PasswordResetConfirmView,
    UserProfileView
)

urlpatterns = [
    path("register/", RegisterView.as_view(), name="auth-register"),
    path("login/", TokenObtainPairView.as_view(), name="auth-login"),
    path("token/refresh/", TokenRefreshView.as_view(), name="auth-token-refresh"),
    path("verify-email/", EmailVerificationView.as_view(), name="auth-verify-email"),
    path("forgot-password/", PasswordResetRequestView.as_view(), name="auth-forgot-password"),
    path("reset-password/", PasswordResetConfirmView.as_view(), name="auth-reset-password"),
    path("profile/", UserProfileView.as_view(), name="user-profile"),
]
