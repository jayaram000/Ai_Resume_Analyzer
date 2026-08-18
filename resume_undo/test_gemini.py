import os
import sys
import django
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from common.gemini import call_gemini_api

try:
    res = call_gemini_api("say hi")
    print(res)
except Exception as e:
    import traceback
    traceback.print_exc()
