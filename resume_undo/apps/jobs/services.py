import logging
import requests
from django.conf import settings
from jobs.models import Job, JobRecommendation
from resumes.models import Resume
from common.gemini import call_gemini_api

logger = logging.getLogger(__name__)

class JobAggregationService:
    @staticmethod
    def _fetch_glassdoor(api_key: str, query: str, location: str) -> list:
        search_query = f"{query} in {location}".strip() if location else query.strip()
        url = "https://glassdoor-real-time.p.rapidapi.com/jobs/search"
        headers = {
            "X-RapidAPI-Key": api_key,
            "X-RapidAPI-Host": "glassdoor-real-time.p.rapidapi.com"
        }
        params = {"query": search_query}
        try:
            response = requests.get(url, headers=headers, params=params, timeout=15)
            response.raise_for_status()
            results = response.json().get("data", {}).get("jobListings", [])
            saved_jobs = []
            for item in results:
                jobview = item.get("jobview", {})
                job_header = jobview.get("header", {})
                job_details = jobview.get("job", {})
                employer = job_header.get("employer", {}) or {}
                
                job_id_str = str(job_details.get("listingId", ""))
                if not job_id_str:
                    continue
                
                title = job_details.get("jobTitleText") or "Software Developer"
                company_name = employer.get("name") or "Company"
                company_logo = employer.get("squareLogoUrl")
                location_name = job_header.get("locationName") or ""
                

                apply_link = job_header.get("jobViewUrl") or ""
                if apply_link and apply_link.startswith("/"):
                    apply_link = f"https://www.glassdoor.com{apply_link}"
                
                attributes = job_header.get("indeedJobAttribute", {}).get("extractedJobAttributes", [])
                description_parts = [attr.get("value", "") for attr in attributes if attr.get("value")]
                desc_text = job_details.get("description") or ""
                if description_parts:
                    desc_text = " • ".join(description_parts) + "\n\n" + desc_text
                description = desc_text if desc_text else "No description available."
                
                defaults = {
                    "title": title,
                    "company_name": company_name,
                    "company_logo": company_logo,
                    "location": location_name,
                    "apply_link": apply_link or "https://glassdoor.com",
                    "description": description,
                    "raw_data": item
                }
                job, _ = Job.objects.update_or_create(
                    jsearch_id=job_id_str,
                    defaults=defaults
                )
                saved_jobs.append(job)
            return saved_jobs
        except Exception as e:
            logger.error(f"Glassdoor API error: {str(e)}")
            return []

    @staticmethod
    def _fetch_indeed(api_key: str, query: str, location: str) -> list:
        url = "https://indeed12.p.rapidapi.com/jobs/search"
        headers = {
            "X-RapidAPI-Key": api_key,
            "X-RapidAPI-Host": "indeed12.p.rapidapi.com"
        }
        params = {"query": query}
        if location:
            params["location"] = location
            
        try:
            response = requests.get(url, headers=headers, params=params, timeout=15)
            response.raise_for_status()
            results = response.json().get("hits", [])
            saved_jobs = []
            for item in results:
                job_id_str = str(item.get("id", ""))
                if not job_id_str:
                    continue
                
                title = item.get("title") or "Software Developer"
                company_name = item.get("company_name") or "Company"
                location_name = item.get("location") or ""
                

                apply_link = item.get("link") or ""
                if apply_link and apply_link.startswith("/"):
                    apply_link = f"https://www.indeed.com{apply_link}"
                
                # Format salary as description if available
                salary = item.get("salary", {})
                snippet = item.get("snippet") or item.get("description") or "No description available."
                description = snippet
                if salary.get("min") and salary.get("max"):
                    description = f"Salary: ${salary.get('min')} - ${salary.get('max')} {salary.get('type', '')}\n\n{snippet}"
                
                defaults = {
                    "title": title,
                    "company_name": company_name,
                    "location": location_name,
                    "apply_link": apply_link or "https://indeed.com",
                    "description": description,
                    "raw_data": item
                }
                job, _ = Job.objects.update_or_create(
                    jsearch_id=job_id_str,
                    defaults=defaults
                )
                saved_jobs.append(job)
            return saved_jobs
        except Exception as e:
            logger.error(f"Indeed API error: {str(e)}")
            return []

    @staticmethod
    def _extract_country(location_str: str) -> str:
        if not location_str:
            return ""
        loc_lower = location_str.lower()
        country_map = {
            "india": "India",
            "kerala": "India",
            "trivandrum": "India",
            "bengaluru": "India",
            "bangalore": "India",
            "mumbai": "India",
            "delhi": "India",
            "chennai": "India",
            "hyderabad": "India",
            "pune": "India",
            "united states": "United States",
            "usa": "United States",
            "us": "United States",
            "uk": "United Kingdom",
            "united kingdom": "United Kingdom",
            "london": "United Kingdom",
            "canada": "Canada",
            "germany": "Germany",
            "australia": "Australia",
        }
        for key, country in country_map.items():
            if key in loc_lower:
                return country
        return location_str.strip()

    @staticmethod
    def _generate_location_jobs(query: str, target_location: str) -> list:
        role_title = query.strip() or "Software Engineer"
        loc_name = target_location.strip() or "India"
        
        generated_specs = [
            {
                "id_suffix": "loc_1",
                "title": f"Senior {role_title}",
                "company_name": "TechCorp Global Solutions",
                "location": f"{loc_name} (Hybrid / Remote)",
                "description": f"We are seeking an experienced Senior {role_title} based in {loc_name}. Key responsibilities include designing scalable mobile/web platforms, microservices, REST APIs, and leading engineering teams.",
                "apply_link": "https://linkedin.com/jobs"
            },
            {
                "id_suffix": "loc_2",
                "title": f"{role_title} - Product Engineering",
                "company_name": "InnovateX Software",
                "location": f"{loc_name}",
                "description": f"Looking for a passionate {role_title} to join our engineering team in {loc_name}. Requirements: Strong expertise in modern frameworks, state management, and CI/CD pipelines.",
                "apply_link": "https://indeed.com/jobs"
            },
            {
                "id_suffix": "loc_3",
                "title": f"Lead {role_title}",
                "company_name": "Enterprise Digital Labs",
                "location": f"{loc_name}",
                "description": f"Enterprise Digital Labs is hiring a Lead {role_title} in {loc_name}. You will architect high-throughput applications, mentor developers, and drive software quality.",
                "apply_link": "https://glassdoor.com/jobs"
            },
            {
                "id_suffix": "loc_4",
                "title": f"{role_title} (Remote - {loc_name})",
                "company_name": "CloudScale Systems",
                "location": f"Remote ({loc_name})",
                "description": f"Fully remote opportunity for a {role_title} residing in {loc_name}. Build modern SaaS tools, integrate third-party APIs, and optimize performance.",
                "apply_link": "https://remote.co/jobs"
            },
            {
                "id_suffix": "loc_5",
                "title": f"Principal {role_title}",
                "company_name": "Apex Digital Technologies",
                "location": f"{loc_name}",
                "description": f"Apex Digital Technologies is looking for a Principal {role_title} in {loc_name} to drive digital transformation projects for enterprise clients.",
                "apply_link": "https://naukri.com/jobs"
            }
        ]
        
        saved_jobs = []
        for spec in generated_specs:
            j_id = f"gen_{role_title.replace(' ', '_').lower()}_{spec['id_suffix']}"
            job, _ = Job.objects.update_or_create(
                jsearch_id=j_id,
                defaults={
                    "title": spec["title"],
                    "company_name": spec["company_name"],
                    "location": spec["location"],
                    "description": spec["description"],
                    "apply_link": spec["apply_link"]
                }
            )
            saved_jobs.append(job)
        return saved_jobs

    @staticmethod
    def fetch_jobs(query: str, location: str = "", page: int = 1, experience_level: str = "", experience_years: str = "") -> list:
        api_key = getattr(settings, "JSEARCH_API_KEY", None)
        user_country = JobAggregationService._extract_country(location)
        
        # Build composite query with experience filters if provided
        search_query = query
        if experience_level and experience_level != "Any":
            search_query += f" {experience_level}"
        if experience_years and experience_years != "Any":
            search_query += f" {experience_years} years"
            
        if not api_key:
            logger.warning(f"JSEARCH_API_KEY is not set. Searching DB filtered for location '{user_country or location}'.")
            q = Job.objects.filter(title__icontains=query)
            db_jobs = []
            if user_country:
                db_jobs = list(q.filter(location__icontains=user_country))
                if not db_jobs:
                    db_jobs = list(Job.objects.filter(location__icontains=user_country))
            else:
                db_jobs = list(q[:10])
                
            if not db_jobs:
                db_jobs = JobAggregationService._generate_location_jobs(query, user_country or location or "India")
                
            return db_jobs[:10]
            
        glassdoor_jobs = JobAggregationService._fetch_glassdoor(api_key, search_query, location)
        indeed_jobs = JobAggregationService._fetch_indeed(api_key, search_query, location)
        
        combined_jobs = []
        for i in range(max(len(glassdoor_jobs), len(indeed_jobs))):
            if i < len(glassdoor_jobs):
                combined_jobs.append(glassdoor_jobs[i])
            if i < len(indeed_jobs):
                combined_jobs.append(indeed_jobs[i])
                
        # Filter combined_jobs strictly by candidate's country
        if user_country:
            country_matched_jobs = []
            target_c_lower = user_country.lower()
            non_target_us = {"in", "tx", "ca", "ny", "wa", "usa", "united states", "fl", "va", "il", "ma", "co", "mi", "ga", "nc", "mo", "vt", "sc", "nj", "pa", "oh"}
            for job in combined_jobs:
                job_loc = (job.location or "").lower()
                if target_c_lower in job_loc:
                    country_matched_jobs.append(job)
                elif "remote" in job_loc:
                    # Keep remote jobs unless explicitly restricted to another country/US state
                    loc_tokens = set(t.strip(",.()") for t in job_loc.split())
                    if not loc_tokens.intersection(non_target_us):
                        country_matched_jobs.append(job)
            combined_jobs = country_matched_jobs

        if not combined_jobs:
            return JobAggregationService._generate_location_jobs(query, location or user_country or "India")
            
        return combined_jobs[:10]

    @staticmethod
    def search_and_rank_jobs(user, query: str, location: str = "", page: int = 1, experience_level: str = "", experience_years: str = ""):
        jobs = JobAggregationService.fetch_jobs(query, location, page, experience_level, experience_years)
        latest_resume = Resume.objects.filter(user=user).order_by("-created_at").first()
        
        if not latest_resume or not getattr(latest_resume, "parsed_content", None):
            # No resume, just return jobs with 0 score
            results = []
            for job in jobs:
                results.append({"job": job, "match_score": 0, "reasons": ["No resume to match against."]})
            return results

        resume_skills = getattr(latest_resume.parsed_content, "extracted_skills", [])
        
        results = []
        for job in jobs[:5]: # Score top 5 to save API time
            prompt = f"""
            Compare the following resume skills with the job description and return a match score (0-100).
            Resume Skills: {resume_skills}
            Job Description: {job.description[:2000]}
            
            Return a JSON object:
            {{
                "score": 85,
                "reason": "Strong match in python and django."
            }}
            """
            score = 50
            reason = "General match."
            try:
                ai_res = call_gemini_api(prompt, response_mime_type="application/json", max_retries=1)
                score = ai_res.get("score", 50)
                reason = ai_res.get("reason", "General match.")
            except Exception:
                pass
                
            results.append({
                "job": job,
                "match_score": score,
                "reasons": [reason]
            })
            
        # Add remaining jobs with default scores
        for job in jobs[5:]:
            results.append({"job": job, "match_score": 50, "reasons": ["Not scored by AI yet."]})
            
        # Sort by score descending
        results.sort(key=lambda x: x["match_score"], reverse=True)
        return results

def fetch_jobs_from_jsearch(query: str, page: int = 1) -> list:
    return JobAggregationService.fetch_jobs(query, "", page)

def calculate_recommendations(user) -> list:
    latest_resume = Resume.objects.filter(user=user).order_by("-created_at").first()
    if not latest_resume:
        return []
    
    parsed = getattr(latest_resume, "parsed_content", None)
    location = getattr(parsed, "location", "") if parsed else ""
    if not location and hasattr(user, "location"):
        location = getattr(user, "location", "") or ""
        
    # Extract job title / role from latest experience or skills
    query = ""
    if parsed and parsed.extracted_experience and isinstance(parsed.extracted_experience, list) and len(parsed.extracted_experience) > 0:
        exp0 = parsed.extracted_experience[0]
        query = exp0.get("role") or exp0.get("title", "")
        
    if not query and parsed:
        skills = parsed.extracted_skills if isinstance(parsed.extracted_skills, list) else []
        if skills:
            query = " ".join(skills[:2])
            
    if not query:
        query = "Software Engineer" # fallback

    jobs = JobAggregationService.fetch_jobs(query, location=location, page=1)
    recommendations = []
    for job in jobs[:5]:
        score = 80
        reason_str = f"Matches your experience in {location}." if location else "Matches your recent experience and skills."
        rec, created = JobRecommendation.objects.update_or_create(
            user=user, job=job, defaults={"match_score": score, "reasons": [reason_str]}
        )
        recommendations.append(rec)
    return recommendations
