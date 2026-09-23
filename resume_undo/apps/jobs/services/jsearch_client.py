import logging
import requests
import json
import urllib.parse
import re
from django.conf import settings
from jobs.models import Job

logger = logging.getLogger(__name__)

# Kept for backward compatibility but deprecated in favor of dynamic live search
REGIONAL_MARKET_COMPANIES = {}

def generate_platform_links(company_name: str, title: str, location: str) -> dict:
    """Generates direct, pre-filtered search links across top hiring platforms."""
    q_search = urllib.parse.quote_plus(f"{company_name} {title}")
    q_loc = urllib.parse.quote_plus(location or "Remote")
    loc_slug = urllib.parse.quote_plus((location or "remote").lower().replace(' ', '-'))
    return {
        "linkedin": f"https://www.linkedin.com/jobs/search/?keywords={q_search}&location={q_loc}",
        "naukri": f"https://www.naukri.com/jobs-in-{loc_slug}?kwd={q_search}",
        "indeed": f"https://www.indeed.com/jobs?q={q_search}&l={q_loc}",
        "foundit": f"https://www.foundit.in/srp/results?query={q_search}&locations={q_loc}",
        "glassdoor": f"https://www.glassdoor.com/Job/jobs.htm?sc.keyword={q_search}&locKeyword={q_loc}",
        "google": f"https://www.google.com/search?q={q_search}+jobs+in+{q_loc}&ibp=htl;jobs"
    }


def fetch_glassdoor_jobs(query: str, location: str = "", page: int = 1) -> list:
    """
    Fetches live, authentic job openings from the Glassdoor Real-Time RapidAPI.
    Uses the configured RapidAPI key from settings (JSEARCH_API_KEY).
    """
    api_key = getattr(settings, "JSEARCH_API_KEY", "")
    if not api_key:
        logger.warning("JSEARCH_API_KEY is not configured in settings. Skipping Glassdoor search.")
        return []

    url = "https://glassdoor-real-time.p.rapidapi.com/jobs/search"
    headers = {
        "X-RapidAPI-Key": api_key,
        "X-RapidAPI-Host": "glassdoor-real-time.p.rapidapi.com"
    }
    params = {"query": (query or "").strip() or "Software Engineer"}
    if location and location.lower() not in ("remote", "any", "all", "worldwide", "global", ""):
        params["location"] = location.strip()

    try:
        response = requests.get(url, headers=headers, params=params, timeout=15)
        if response.status_code != 200:
            logger.warning(f"Glassdoor RapidAPI returned status {response.status_code}: {response.text[:150]}")
            return []

        data = response.json()
        listings = (data.get("data") or {}).get("jobListings") or []
        saved_jobs = []

        for item in listings:
            if not isinstance(item, dict):
                continue
            jv = item.get("jobview") or {}
            header = jv.get("header") or {}
            job_info = jv.get("job") or {}
            overview = jv.get("overview") or {}

            listing_id = job_info.get("listingId") or header.get("adOrderId")
            if not listing_id:
                continue

            title = job_info.get("jobTitleText") or header.get("normalizedJobTitle") or query
            company_info = header.get("employer") or {}
            company_name = header.get("employerNameFromSearch") or company_info.get("name") or "Tech Enterprise"
            company_logo = company_info.get("squareLogoUrl")
            loc_name = header.get("locationName") or location or "Remote"

            # Parse extracted skills and attributes safely
            indeed_attr = header.get("indeedJobAttribute") or {}
            attributes = indeed_attr.get("extractedJobAttributes") or []
            extracted_skills = [
                attr.get("value") for attr in attributes 
                if isinstance(attr, dict) and attr.get("value") and len(str(attr.get("value"))) < 40
            ]

            # Parse salary range safely
            salary_str = None
            pay_data = header.get("payPeriodAdjustedPay")
            currency = header.get("payCurrency", "$")
            currency_symbol = "$" if currency == "USD" else ("₹" if currency == "INR" else f"{currency} ")
            if pay_data and isinstance(pay_data, dict):
                p10 = pay_data.get("p10")
                p90 = pay_data.get("p90")
                period = str(header.get("payPeriod", "ANNUAL")).lower()
                period_label = "/ yr" if "annual" in period or "year" in period else ("/ mo" if "month" in period else "/ hr")
                if p10 and p90:
                    salary_str = f"{currency_symbol}{int(p10):,} - {currency_symbol}{int(p90):,} {period_label}"
                elif p10:
                    salary_str = f"{currency_symbol}{int(p10):,} {period_label}"

            # Construct direct apply link
            job_view_url = header.get("jobViewUrl")
            platform_links = generate_platform_links(company_name, title, loc_name)
            apply_link = f"https://www.glassdoor.com{job_view_url}" if job_view_url else platform_links.get("glassdoor", platform_links.get("linkedin", ""))

            # Description synthesis from real job attributes & industry
            primary_ind = overview.get("primaryIndustry") or {}
            industry_name = primary_ind.get("industryName") or "Technology & Software"
            skills_preview = ", ".join(extracted_skills[:6]) if extracted_skills else "Software Engineering"
            description = (
                f"{company_name} is actively hiring for a {title} in {loc_name}. "
                f"Industry: {industry_name}. Key competencies: {skills_preview}. "
                f"Apply directly via Glassdoor or company portal."
            )

            job_record, _ = Job.objects.update_or_create(
                jsearch_id=f"gd_{listing_id}",
                defaults={
                    "title": title,
                    "company_name": company_name,
                    "company_logo": company_logo,
                    "location": loc_name,
                    "description": description,
                    "apply_link": apply_link,
                    "raw_data": {
                        "source_platform": "Glassdoor Real-Time",
                        "rating": header.get("rating"),
                        "salary": salary_str,
                        "required_skills": extracted_skills,
                        "job_type": "Full-time",
                        "platform_links": platform_links,
                    }
                }
            )
            saved_jobs.append(job_record)

        logger.info(f"Successfully fetched {len(saved_jobs)} live jobs from Glassdoor RapidAPI for query: {query}")
        return saved_jobs
    except Exception as e:
        logger.error(f"Glassdoor RapidAPI fetch exception: {e}")
        return []


def fetch_jobs_from_jsearch(query: str, page: int = 1, location: str = ""):
    from .job_ranking_service import JobAggregationService
    return JobAggregationService.fetch_jobs(query, location=location, page=page)
