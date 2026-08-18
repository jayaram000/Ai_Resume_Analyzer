from rest_framework import serializers
from subscriptions.models import SubscriptionPlan, UserSubscription

class SubscriptionPlanSerializer(serializers.ModelSerializer):
    class Meta:
        model = SubscriptionPlan
        fields = ["id", "name", "price", "duration_days", "features", "is_active"]

class UserSubscriptionSerializer(serializers.ModelSerializer):
    plan_name = serializers.CharField(source="plan.name", read_only=True)

    class Meta:
        model = UserSubscription
        fields = [
            "id",
            "plan",
            "plan_name",
            "start_date",
            "end_date",
            "status",
            "razorpay_subscription_id",
            "razorpay_payment_id"
        ]
        read_only_fields = ["id", "start_date", "end_date", "status"]

class CreateCheckoutSessionSerializer(serializers.Serializer):
    plan_id = serializers.UUIDField()

class VerifyPaymentSerializer(serializers.Serializer):
    razorpay_payment_id = serializers.CharField()
    razorpay_order_id = serializers.CharField()
    razorpay_signature = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    plan_id = serializers.UUIDField()

