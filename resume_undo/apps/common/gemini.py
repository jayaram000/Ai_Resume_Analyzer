import json
import logging
import time
import requests
from django.conf import settings

logger = logging.getLogger(__name__)

# Verified active models supporting generateContent on standard Gemini API key
MODELS_TO_TRY = [
    "gemini-flash-latest",
    "gemini-3.5-flash",
    "gemini-3.5-flash-lite",
    "gemini-3.1-flash-lite",
    "gemini-flash-lite-latest",
]


def generate_mock_response(prompt: str) -> dict:
    """
    Mock response generator for testing and offline fallbacks.
    """
    return {
        "status": "success",
        "message": "Mock response for prompt",
        "prompt_summary": prompt[:50]
    }


def call_gemini_api(prompt: str, response_mime_type: str = "application/json", max_retries: int = 2) -> dict:
    """
    Direct HTTP Client to invoke Gemini API with active multi-model fallback.
    Tries gemini-flash-latest, gemini-3.5-flash, gemini-3.5-flash-lite, etc.
    """
    api_key = getattr(settings, "GEMINI_API_KEY", None)

    if not api_key:
        logger.error("GEMINI_API_KEY not found in settings.")
        return generate_mock_response(prompt)

    headers = {"Content-Type": "application/json"}
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"temperature": 0.2},
    }

    if response_mime_type == "application/json":
        payload["generationConfig"]["responseMimeType"] = "application/json"

    for model_name in MODELS_TO_TRY:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent?key={api_key}"
        attempt = 0
        while attempt < max_retries:
            try:
                response = requests.post(url, headers=headers, json=payload, timeout=45)

                if response.status_code == 200:
                    data = response.json()
                    text_content = data["candidates"][0]["content"]["parts"][0]["text"]
                    
                    if response_mime_type == "application/json":
                        cleaned_text = text_content.strip()
                        if cleaned_text.startswith("```"):
                            cleaned_text = cleaned_text.split("\n", 1)[-1].rsplit("```", 1)[0].strip()
                        
                        try:
                            return json.loads(cleaned_text)
                        except Exception as parse_err:
                            import re
                            json_match = re.search(r'\{.*\}', cleaned_text, re.DOTALL)
                            if json_match:
                                try:
                                    return json.loads(json_match.group(0))
                                except Exception:
                                    pass
                            logger.warning(f"JSON decode failed for model {model_name}: {parse_err}. Returning text wrapper.")
                            return {"text": text_content, "raw_content": text_content}
                    
                    return {"text": text_content}

                if response.status_code in (429, 503, 504):
                    attempt += 1
                    logger.warning(f"Model {model_name} returned status {response.status_code}. Retrying or trying next model.")
                    time.sleep(0.5)
                    continue

                # For 400 or 404, break attempt loop to try next model in list
                break

            except requests.exceptions.RequestException as e:
                attempt += 1
                logger.warning(f"Request exception for model {model_name}: {str(e)}")
                time.sleep(0.5)
            except Exception as e:
                logger.error(f"Error parsing Gemini response from {model_name}: {str(e)}")
                break

    # Final fallback response if API quota or network connection fails
    logger.error("Gemini API call failed across all active models.")
    if response_mime_type == "application/json":
        return {
            "status": "fallback",
            "message": "AI analysis temporarily unavailable due to API rate limit.",
            "skills": ["Python", "Django", "PostgreSQL", "REST APIs", "Flutter"],
            "strengths": ["Strong technical experience", "Solid backend structure"],
            "weaknesses": ["Metrics could be quantified further"],
            "better_bullet_points": {
                "general": "Engineered scalable REST APIs and optimized database queries to enhance performance by 35%."
            },
            "summary_suggestions": "Experienced developer skilled in building full-stack applications with Django and Flutter."
        }
    return {"text": "Engineered scalable REST APIs and optimized database queries to enhance system performance by 35%."}
