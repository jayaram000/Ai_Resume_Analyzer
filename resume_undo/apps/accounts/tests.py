from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase
from accounts.models import UserProfile

User = get_user_model()

class AccountsAPITests(APITestCase):
    def setUp(self):
        self.register_url = reverse("auth-register")
        self.login_url = reverse("auth-login")
        self.profile_url = reverse("user-profile")
        self.token_refresh_url = reverse("auth-token-refresh")
        
        self.user_data = {
            "email": "user@career.ai",
            "username": "user",
            "password": "password123",
            "profile": {
                "phone": "+1234567890",
                "location": "New York",
                "linkedin_url": "https://linkedin.com/in/user",
                "github_url": "https://github.com/user",
                "current_role": "Flutter Developer",
                "years_of_experience": 2
            }
        }
        
    def test_user_registration(self):
        response = self.client.post(self.register_url, self.user_data, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(response.data["success"])
        self.assertEqual(response.data["data"]["email"], self.user_data["email"])
        
        # Verify profile creation
        user = User.objects.get(email=self.user_data["email"])
        self.assertEqual(user.profile.location, "New York")
        self.assertEqual(user.profile.years_of_experience, 2)

    def test_user_login_and_profile_retrieval(self):
        # Create user
        user = User.objects.create_user(
            email="login@career.ai",
            username="loginuser",
            password="securepassword"
        )
        UserProfile.objects.update_or_create(user=user, defaults={"location": "San Francisco"})
        
        # Login
        response = self.client.post(self.login_url, {
            "email": "login@career.ai",
            "password": "securepassword"
        }, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("access", response.data)
        self.assertIn("refresh", response.data)
        
        # Access profile
        access_token = response.data["access"]
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {access_token}")
        profile_response = self.client.get(self.profile_url)
        self.assertEqual(profile_response.status_code, status.HTTP_200_OK)
        self.assertTrue(profile_response.data["success"])
        self.assertEqual(profile_response.data["data"]["profile"]["location"], "San Francisco")
        
    def test_user_profile_update(self):
        user = User.objects.create_user(
            email="update@career.ai",
            username="updateuser",
            password="securepassword"
        )
        UserProfile.objects.update_or_create(user=user)
        self.client.force_authenticate(user=user)
        
        response = self.client.put(self.profile_url, {
            "phone": "+999999",
            "location": "Boston",
            "years_of_experience": 5
        }, format="json")
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data["success"])
        self.assertEqual(user.profile.location, "Boston")
        self.assertEqual(user.profile.years_of_experience, 5)

    def test_email_verification_token(self):
        user = User.objects.create_user(
            email="verify@career.ai",
            username="verifyuser",
            password="securepassword"
        )
        profile = UserProfile.objects.create(user=user, verification_token="secret_token_123")
        
        url = reverse("auth-verify-email")
        response = self.client.get(f"{url}?token=secret_token_123")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data["success"])
        
        user.refresh_from_db()
        self.assertTrue(user.is_verified)
