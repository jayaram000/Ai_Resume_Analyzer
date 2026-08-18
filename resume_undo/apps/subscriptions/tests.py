from django.contrib.auth import get_user_model
from django.urls import reverse
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase
from subscriptions.models import SubscriptionPlan, UserSubscription

User = get_user_model()

class SubscriptionsAPITests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email="subscriber@career.ai",
            username="subscriber",
            password="password123"
        )
        self.client.force_authenticate(user=self.user)
        
        self.plan = SubscriptionPlan.objects.create(
            name="Test Premium",
            price=299,
            duration_days=30,
            features=["Feature A", "Feature B"],
            is_active=True
        )
        self.plans_url = reverse("subscription-plans")
        self.checkout_url = reverse("subscription-checkout")
        self.verify_url = reverse("subscription-verify")
        self.active_url = reverse("subscription-active")

    def test_get_subscription_plans(self):
        response = self.client.get(self.plans_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data["success"])
        self.assertEqual(len(response.data["data"]), 1)
        self.assertEqual(response.data["data"][0]["name"], "Test Premium")

    def test_create_checkout_session(self):
        response = self.client.post(self.checkout_url, {
            "plan_id": str(self.plan.id)
        }, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data["success"])
        self.assertIn("order_id", response.data)
        # Should return mock = True since credentials are not configured
        self.assertTrue(response.data["mock"])

    def test_verify_mock_payment_activation(self):
        # Trigger checkout session
        checkout_response = self.client.post(self.checkout_url, {
            "plan_id": str(self.plan.id)
        }, format="json")
        order_id = checkout_response.data["order_id"]
        
        # Verify payment
        response = self.client.post(self.verify_url, {
            "razorpay_payment_id": "pay_mock_12345",
            "razorpay_order_id": order_id,
            "plan_id": str(self.plan.id)
        }, format="json")
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data["success"])
        self.assertEqual(response.data["data"]["status"], "active")
        
        # Check database directly
        sub = UserSubscription.objects.get(user=self.user)
        self.assertEqual(sub.status, "active")
        self.assertEqual(sub.plan, self.plan)

    def test_active_subscription_retrieval(self):
        # Initially none
        response = self.client.get(self.active_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIsNone(response.data["data"])
        
        # Create subscription record
        UserSubscription.objects.create(
            user=self.user,
            plan=self.plan,
            start_date=timezone.now(),
            end_date=timezone.now() + timezone.timedelta(days=30),
            status="active"
        )
        
        response = self.client.get(self.active_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIsNotNone(response.data["data"])
        self.assertEqual(response.data["data"]["plan_name"], "Test Premium")
