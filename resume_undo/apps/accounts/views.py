from rest_framework import status, permissions
from rest_framework.response import Response
from rest_framework.views import APIView
from django.contrib.auth import get_user_model
from django.utils import timezone
from accounts.models import UserProfile
from accounts.serializers import (
    RegisterSerializer,
    UserSerializer,
    UserProfileSerializer,
    EmailVerificationSerializer,
    PasswordResetRequestSerializer,
    PasswordResetConfirmSerializer
)
from accounts.services import send_verification_email, send_password_reset_email

User = get_user_model()

class RegisterView(APIView):
    permission_classes = [permissions.AllowAny]
    serializer_class = RegisterSerializer

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            # Send verification email asynchronously/mocked
            send_verification_email(user)
            return Response({
                "success": True,
                "message": "User registered successfully. Verification email sent.",
                "data": UserSerializer(user).data
            }, status=status.HTTP_201_CREATED)
        return Response({
            "success": False,
            "error": {
                "code": 400,
                "message": "Validation failed",
                "details": serializer.errors
            }
        }, status=status.HTTP_400_BAD_REQUEST)

class EmailVerificationView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        token = request.query_params.get("token")
        if not token:
            return Response({"success": False, "message": "Token query parameter is required."}, status=400)
            
        try:
            profile = UserProfile.objects.get(verification_token=token)
            user = profile.user
            user.is_verified = True
            user.save()
            profile.verification_token = None
            profile.save()
            return Response({"success": True, "message": "Email verified successfully."})
        except UserProfile.DoesNotExist:
            return Response({"success": False, "message": "Invalid or expired verification token."}, status=400)

class PasswordResetRequestView(APIView):
    permission_classes = [permissions.AllowAny]
    serializer_class = PasswordResetRequestSerializer

    def post(self, request):
        serializer = PasswordResetRequestSerializer(data=request.data)
        if serializer.is_valid():
            email = serializer.validated_data["email"]
            try:
                user = User.objects.get(email=email)
                send_password_reset_email(user)
            except User.DoesNotExist:
                # To prevent user enumeration, we return success even if email is not registered.
                pass
            return Response({"success": True, "message": "If this email is registered, a password reset link has been sent."})
        return Response(serializer.errors, status=400)

class PasswordResetConfirmView(APIView):
    permission_classes = [permissions.AllowAny]
    serializer_class = PasswordResetConfirmSerializer

    def post(self, request):
        serializer = PasswordResetConfirmSerializer(data=request.data)
        if serializer.is_valid():
            token = serializer.validated_data["token"]
            new_password = serializer.validated_data["new_password"]
            try:
                profile = UserProfile.objects.get(
                    reset_token=token,
                    reset_token_expiry__gt=timezone.now()
                )
                user = profile.user
                user.set_password(new_password)
                user.save()
                
                profile.reset_token = None
                profile.reset_token_expiry = None
                profile.save()
                return Response({"success": True, "message": "Password reset successfully."})
            except UserProfile.DoesNotExist:
                return Response({"success": False, "message": "Invalid or expired reset token."}, status=400)
        return Response(serializer.errors, status=400)

class UserProfileView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = UserProfileSerializer

    def get(self, request):
        serializer = UserSerializer(request.user)
        return Response({"success": True, "data": serializer.data})

    def put(self, request):
        profile = request.user.profile
        serializer = UserProfileSerializer(profile, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response({
                "success": True,
                "message": "Profile updated successfully.",
                "data": UserSerializer(request.user).data
            })
        return Response(serializer.errors, status=400)
