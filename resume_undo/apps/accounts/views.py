from rest_framework import status, permissions
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.views import TokenObtainPairView
from django.contrib.auth import get_user_model
from django.utils import timezone
from accounts.models import UserProfile
from accounts.serializers import (
    RegisterSerializer,
    UserSerializer,
    UserProfileSerializer,
    EmailVerificationSerializer,
    PasswordResetRequestSerializer,
    PasswordResetConfirmSerializer,
    CustomTokenObtainPairSerializer,
    ChangePasswordSerializer
)
from accounts.services import send_verification_email, send_password_reset_email
from google.oauth2 import id_token
from google.auth.transport import requests
from django.conf import settings
from rest_framework_simplejwt.tokens import RefreshToken
import pyotp
import qrcode
import io
import base64

User = get_user_model()

class CustomTokenObtainPairView(TokenObtainPairView):
    serializer_class = CustomTokenObtainPairSerializer

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

class ChangePasswordView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = ChangePasswordSerializer

    def post(self, request):
        serializer = ChangePasswordSerializer(data=request.data)
        if serializer.is_valid():
            user = request.user
            if not user.check_password(serializer.validated_data.get("old_password")):
                return Response({"success": False, "message": "Wrong old password."}, status=400)
            user.set_password(serializer.validated_data.get("new_password"))
            user.save()
            return Response({"success": True, "message": "Password changed successfully."})
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

class GoogleLoginView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        token = request.data.get("token")
        if not token:
            return Response({"error": "Token is required"}, status=400)

        try:
            client_id = getattr(settings, 'GOOGLE_CLIENT_ID', 'placeholder-id')
            idinfo = id_token.verify_oauth2_token(token, requests.Request(), client_id)
            email = idinfo['email']
            first_name = idinfo.get('given_name', '')
            last_name = idinfo.get('family_name', '')

            user, created = User.objects.get_or_create(email=email, defaults={
                'username': email,
                'first_name': first_name,
                'last_name': last_name,
                'is_verified': True
            })

            if user.is_totp_enabled:
                return Response({"requires_2fa": True, "email": user.email})

            refresh = RefreshToken.for_user(user)
            return Response({
                'refresh': str(refresh),
                'access': str(refresh.access_token),
                'user': UserSerializer(user).data
            })
        except ValueError:
            return Response({"error": "Invalid Google token"}, status=400)

class TOTPSetupView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        user = request.user
        if not user.totp_secret:
            user.totp_secret = pyotp.random_base32()
            user.save()

        totp = pyotp.TOTP(user.totp_secret)
        provisioning_uri = totp.provisioning_uri(name=user.email, issuer_name="ResumeAI")

        qr = qrcode.QRCode(version=1, box_size=10, border=4)
        qr.add_data(provisioning_uri)
        qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white")

        buffered = io.BytesIO()
        img.save(buffered, format="PNG")
        img_str = base64.b64encode(buffered.getvalue()).decode()

        return Response({
            "secret": user.totp_secret,
            "qr_code": f"data:image/png;base64,{img_str}"
        })

class TOTPVerifyView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        email = request.data.get("email")
        code = request.data.get("code")

        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            return Response({"success": False, "error": "Invalid user"}, status=400)

        if not user.totp_secret:
             return Response({"success": False, "error": "2FA not configured"}, status=400)

        totp = pyotp.TOTP(user.totp_secret)
        if totp.verify(code):
            user.is_totp_enabled = True
            user.save()
            refresh = RefreshToken.for_user(user)
            return Response({
                'success': True,
                'refresh': str(refresh),
                'access': str(refresh.access_token),
                'user': UserSerializer(user).data
            })
        return Response({"success": False, "error": "Invalid 2FA Code"}, status=400)
