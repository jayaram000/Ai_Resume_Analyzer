import uuid

# pyrefly: ignore [missing-import]
from django.db import models
# pyrefly: ignore [missing-import]
from django.contrib.auth.models import AbstractUser


class User(AbstractUser):

    class Role(models.TextChoices):
        USER = "USER", "User"
        ADMIN = "ADMIN", "Admin"

    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False
    )

    email = models.EmailField(
        unique=True
    )

    role = models.CharField(
        max_length=20,
        choices=Role.choices,
        default=Role.USER
    )

    is_verified = models.BooleanField(
        default=False
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    updated_at = models.DateTimeField(
        auto_now=True
    )

    USERNAME_FIELD = "email"

    REQUIRED_FIELDS = ["username"]


class UserProfile(models.Model):

    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name="profile"
    )

    phone = models.CharField(
        max_length=20,
        blank=True
    )

    location = models.CharField(
        max_length=255,
        blank=True
    )

    linkedin_url = models.URLField(
        blank=True
    )

    github_url = models.URLField(
        blank=True
    )

    current_role = models.CharField(
        max_length=100,
        blank=True
    )

    years_of_experience = models.PositiveIntegerField(
        default=0
    )

    preferences = models.JSONField(
        default=dict,
        blank=True
    )

    verification_token = models.CharField(
        max_length=255,
        blank=True,
        null=True
    )

    reset_token = models.CharField(
        max_length=255,
        blank=True,
        null=True
    )

    reset_token_expiry = models.DateTimeField(
        blank=True,
        null=True
    )

    def __str__(self):
        return self.user.email