from rest_framework import status, permissions
from rest_framework.response import Response
from rest_framework.views import APIView
from drf_spectacular.utils import extend_schema
from subscriptions.models import SubscriptionPlan, UserSubscription
from subscriptions.serializers import (
    SubscriptionPlanSerializer,
    UserSubscriptionSerializer,
    CreateCheckoutSessionSerializer,
    VerifyPaymentSerializer
)
from subscriptions.services import (
    create_razorpay_order,
    verify_razorpay_payment,
    activate_user_subscription
)

class SubscriptionPlanListView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        plans = SubscriptionPlan.objects.filter(is_active=True)
        serializer = SubscriptionPlanSerializer(plans, many=True)
        return Response({"success": True, "data": serializer.data})

class CreateCheckoutSessionView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(request=CreateCheckoutSessionSerializer)
    def post(self, request):
        serializer = CreateCheckoutSessionSerializer(data=request.data)
        if serializer.is_valid():
            plan_id = serializer.validated_data["plan_id"]
            try:
                plan = SubscriptionPlan.objects.get(id=plan_id, is_active=True)
                order = create_razorpay_order(plan)
                return Response({
                    "success": True,
                    "order_id": order["id"],
                    "amount": order["amount"],
                    "currency": order["currency"],
                    "mock": order.get("mock", False)
                })
            except SubscriptionPlan.DoesNotExist:
                return Response({"success": False, "message": "Plan not found or inactive."}, status=404)
        return Response(serializer.errors, status=400)

class VerifyPaymentView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(request=VerifyPaymentSerializer)
    def post(self, request):
        payment_id = request.data.get("razorpay_payment_id")
        order_id = request.data.get("razorpay_order_id")
        signature = request.data.get("razorpay_signature")
        plan_id = request.data.get("plan_id")
        
        if not all([payment_id, order_id, plan_id]):
            return Response({"success": False, "message": "payment_id, order_id, and plan_id are required."}, status=400)
            
        try:
            plan = SubscriptionPlan.objects.get(id=plan_id)
            # If signature is missing, check if it's a mock checkout
            if not signature and order_id.startswith("order_mock_"):
                # Mock path
                sub = activate_user_subscription(request.user, plan, payment_id=payment_id, subscription_id=f"sub_mock_{order_id[11:]}")
                return Response({
                    "success": True,
                    "message": "Mock payment verified and subscription activated successfully.",
                    "data": UserSubscriptionSerializer(sub).data
                })
                
            # Real path
            verified = verify_razorpay_payment(payment_id, order_id, signature)
            if verified:
                sub = activate_user_subscription(request.user, plan, payment_id=payment_id, subscription_id=order_id)
                return Response({
                    "success": True,
                    "message": "Payment verified and subscription activated successfully.",
                    "data": UserSubscriptionSerializer(sub).data
                })
            else:
                return Response({"success": False, "message": "Payment verification failed."}, status=400)
        except SubscriptionPlan.DoesNotExist:
            return Response({"success": False, "message": "Plan not found."}, status=404)

class ActiveSubscriptionView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        try:
            sub = UserSubscription.objects.filter(
                user=request.user, 
                status=UserSubscription.Status.ACTIVE
            ).latest('start_date')
            return Response({"success": True, "data": UserSubscriptionSerializer(sub).data})
        except UserSubscription.DoesNotExist:
            return Response({"success": True, "data": None})
