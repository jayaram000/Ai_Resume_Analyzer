from rest_framework.views import exception_handler
from rest_framework.response import Response
from rest_framework import status

def custom_exception_handler(exc, context):
    response = exception_handler(exc, context)

    if response is not None:
        # Standardize error format
        custom_data = {
            "success": False,
            "error": {
                "code": response.status_code,
                "message": "",
                "details": response.data
            }
        }
        
        # Pull message from details if possible
        if isinstance(response.data, dict):
            if "detail" in response.data:
                custom_data["error"]["message"] = response.data["detail"]
                del response.data["detail"]
            elif "non_field_errors" in response.data:
                custom_data["error"]["message"] = response.data["non_field_errors"][0]
            else:
                custom_data["error"]["message"] = "Validation error occurred."
        elif isinstance(response.data, list):
            custom_data["error"]["message"] = response.data[0]
        else:
            custom_data["error"]["message"] = str(response.data)

        response.data = custom_data
    else:
        # Unexpected server errors (500)
        return Response({
            "success": False,
            "error": {
                "code": 500,
                "message": str(exc) if hasattr(exc, 'message') else "An unexpected server error occurred.",
                "details": {}
            }
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    return response
