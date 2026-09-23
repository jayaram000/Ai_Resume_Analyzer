import re
from typing import Optional, Dict, Any

class SalaryNormalizationService:
    @staticmethod
    def normalize_salary(raw_salary: str) -> Dict[str, Any]:
        """
        Parses raw salary strings (e.g. '$120,000 - $150,000 / year', '₹15 - ₹25 LPA', '$60/hr')
        into normalized annual min, max, and currency.
        """
        if not raw_salary or not isinstance(raw_salary, str):
            return {"min": None, "max": None, "currency": None, "period": "yearly", "raw": raw_salary}
        
        currency = "USD"
        if "₹" in raw_salary or "inr" in raw_salary.lower() or "lpa" in raw_salary.lower():
            currency = "INR"
        elif "€" in raw_salary or "eur" in raw_salary.lower():
            currency = "EUR"
        elif "£" in raw_salary or "gbp" in raw_salary.lower():
            currency = "GBP"

        # LPA handling (Lakhs per annum in INR)
        lpa_match = re.findall(r'(\d+(?:\.\d+)?)\s*(?:-|to)?\s*(\d+(?:\.\d+)?)?\s*lpa', raw_salary.lower())
        if lpa_match:
            val1 = float(lpa_match[0][0]) * 100000
            val2 = float(lpa_match[0][1]) * 100000 if lpa_match[0][1] else val1
            return {"min": int(min(val1, val2)), "max": int(max(val1, val2)), "currency": "INR", "period": "yearly", "raw": raw_salary}

        # Numbers extraction
        clean_salary = raw_salary.replace(',', '')
        nums = [int(n) for n in re.findall(r'\b\d+\b', clean_salary)]
        if not nums:
            return {"min": None, "max": None, "currency": currency, "period": "yearly", "raw": raw_salary}

        min_val = min(nums)
        max_val = max(nums)
        period = "yearly"
        if re.search(r'/\s*hr|\bhourly\b|\bhour\b', raw_salary.lower()):
            period = "hourly"
            min_val = min_val * 2080
            max_val = max_val * 2080
        elif re.search(r'/\s*mo|\bmonthly\b|\bmonth\b', raw_salary.lower()):
            period = "monthly"
            min_val = min_val * 12
            max_val = max_val * 12

        return {"min": min_val, "max": max_val, "currency": currency, "period": period, "raw": raw_salary}
