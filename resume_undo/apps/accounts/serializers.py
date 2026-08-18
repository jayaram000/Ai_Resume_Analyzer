from rest_framework import serializers
from django.contrib.auth import get_user_model
from accounts.models import UserProfile

User = get_user_model()

class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserProfile
        fields = [
            "phone",
            "location",
            "linkedin_url",
            "github_url",
            "current_role",
            "years_of_experience"
        ]

class UserSerializer(serializers.ModelSerializer):
    profile = UserProfileSerializer(read_only=True)

    class Meta:
        model = User
        fields = [
            "id",
            "email",
            "username",
            "role",
            "is_verified",
            "created_at",
            "profile"
        ]
        read_only_fields = ["id", "role", "is_verified", "created_at"]

class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)
    profile = UserProfileSerializer(required=False)

    class Meta:
        model = User
        fields = ["email", "username", "password", "profile"]

    def create(self, validated_data):
        profile_data = validated_data.pop("profile", {})
        # Create user
        user = User.objects.create_user(
            email=validated_data["email"],
            username=validated_data.get("username", validated_data["email"].split("@")[0]),
            password=validated_data["password"]
        )
        # Create user profile (UserProfile is created in models, but let's make sure it's populated/created)
        UserProfile.objects.update_or_create(user=user, defaults=profile_data)
        return user

class EmailVerificationSerializer(serializers.Serializer):
    token = serializers.CharField()

class PasswordResetRequestSerializer(serializers.Serializer):
    email = serializers.EmailField()

class PasswordResetConfirmSerializer(serializers.Serializer):
    token = serializers.CharField()
    new_password = serializers.CharField(min_length=8)
