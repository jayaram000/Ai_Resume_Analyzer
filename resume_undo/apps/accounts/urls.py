from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from accounts.views import (
    RegisterView,
    EmailVerificationView,
    PasswordResetRequestView,
    PasswordResetConfirmView,
    UserProfileView,
    CustomTokenObtainPairView,
    GoogleLoginView,
    TOTPSetupView,
    TOTPVerifyView,
    ChangePasswordView
)

urlpatterns = [
    path("register/", RegisterView.as_view(), name="auth-register"),
    path("login/", CustomTokenObtainPairView.as_view(), name="auth-login"),
    path("token/refresh/", TokenRefreshView.as_view(), name="auth-token-refresh"),
    path("verify-email/", EmailVerificationView.as_view(), name="auth-verify-email"),
    path("forgot-password/", PasswordResetRequestView.as_view(), name="auth-forgot-password"),
    path("reset-password/", PasswordResetConfirmView.as_view(), name="auth-reset-password"),
    path("profile/", UserProfileView.as_view(), name="user-profile"),
    path("google/", GoogleLoginView.as_view(), name="auth-google"),
    path("totp/setup/", TOTPSetupView.as_view(), name="auth-totp-setup"),
    path("totp/verify/", TOTPVerifyView.as_view(), name="auth-totp-verify"),
    path("change-password/", ChangePasswordView.as_view(), name="auth-change-password"),
]
