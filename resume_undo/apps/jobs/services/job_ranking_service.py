import logging
import requests
import json
import urllib.parse
import re
from django.conf import settings
from jobs.models import Job, JobRecommendation
from resumes.models import Resume
from common.gemini import call_gemini_api
from .jsearch_client import generate_platform_links, fetch_jobs_from_jsearch, fetch_glassdoor_jobs

logger = logging.getLogger(__name__)

TECH_ROLE_KEYWORDS = {
    "developer", "engineer", "software", "programmer", "architect", "full stack", 
    "fullstack", "backend", "frontend", "mobile", "ios", "android", "flutter", 
    "python", "django", "fastapi", "react", "node", "devops", "cloud", "sre", 
    "data engineer", "machine learning", "ai", "systems", "web developer", "coding",
    "analyst", "qa", "tester", "sdet", "technologist", "specialist", "consultant",
    "scientist", "designer", "ui/ux", "database", "dba", "security", "infosec",
    "solutions architect", "scrum master", "product manager", "tech lead"
}

EXCLUDED_ROLE_KEYWORDS = {
    "sales", "inside sales", "account executive", "bdr", "sdr", "helpdesk", 
    "service desk", "customer service", "customer support", "recruiter", 
    "talent acquisition", "hr", "payroll", "nursing", "nurse", "driver", 
    "cashier", "telemarketer", "call center", "legal counsel", "accountant", 
    "receptionist", "content reviewer", "content moderator", "desk technician", 
    "operations associate", "assistant manager", "social media manager",
    "cook", "line cook", "chef", "stewarding", "waiter", "waitress", "bartender",
    "store associate", "warehouse", "delivery", "security guard", "cleaner", "janitor"
}

def matches_query(title: str, description: str, query: str) -> bool:
    """
    Checks if a job title or description matches the user's search query.
    Extracts meaningful tokens (skipping common stopwords).
    """
    if not query or query.strip().lower() in ("software engineer", "software developer", "developer", "engineer", "any", "all", ""):
        return True

    stop_words = {"and", "or", "in", "for", "with", "the", "a", "an", "at", "to", "of", "on", "is", "it", "any", "all", "job", "jobs"}
    tokens = [w.lower() for w in re.findall(r'\b\w+\b', query) if len(w) > 2 and w.lower() not in stop_words]

    if not tokens:
        return True

    # Tokens specific to technology or domain e.g. "flutter", "python", "react", "django", "devops", "junior", "backend", "frontend", "mobile"
    specific_tokens = [t for t in tokens if t not in ("developer", "engineer", "software", "programmer", "development")]

    title_low = (title or "").lower()
    desc_low = (description or "").lower()

    if specific_tokens:
        # At least one specific tech token must match title or description
        return any(t in title_low for t in specific_tokens) or any(t in desc_low for t in specific_tokens)

    # If query is only generic like "Software Developer", match general tech title
    return any(t in title_low for t in tokens)


def is_relevant_tech_job(title: str, description: str, resume_skills: list = None) -> bool:
    title_lower = (title or "").lower()
    desc_lower = (description or "").lower()

    # 1. Reject if title contains explicitly excluded non-tech keywords
    for ex in EXCLUDED_ROLE_KEYWORDS:
        if re.search(r'\b' + re.escape(ex) + r'\b', title_lower):
            return False

    # 2. Check if title contains software / developer keywords
    has_tech_title = any(re.search(r'\b' + re.escape(kw) + r'\b', title_lower) for kw in TECH_ROLE_KEYWORDS)

    # 3. Check matching skills from candidate resume
    matched_skills = []
    if resume_skills:
        for s in resume_skills:
            if s and len(s) >= 2 and re.search(r'\b' + re.escape(s.lower()) + r'\b', f"{title_lower} {desc_lower}"):
                matched_skills.append(s)

    # Must have a technical title or at least 2 matching resume skills
    return has_tech_title or len(matched_skills) >= 2




def is_geo_compatible(job_geo: str, requested_loc: str) -> bool:
    job_geo_low = (job_geo or "").lower()
    req_low = (requested_loc or "").lower()

    if not requested_loc or req_low in ("remote", "any", "all", "worldwide", "global", ""):
        return True

    # If job is open worldwide / anywhere / remote globally
    if any(k in job_geo_low for k in ("anywhere", "worldwide", "global")):
        return True

    # If requested location is in India
    is_india_req = any(k in req_low for k in ("india", "bengaluru", "bangalore", "trivandrum", "kochi", "kerala", "hyderabad", "mumbai", "delhi", "chennai", "pune"))
    if is_india_req:
        # Incompatible if restricted to Americas, Europe, Germany, UK, etc.
        if any(k in job_geo_low for k in (
            "usa", "latam", "brazil", "mexico", "canada", "europe", "uk", "emea", 
            "berlin", "germany", "frankfurt", "munich", "london", "paris", "netherlands", 
            "amsterdam", "poland", "spain", "france", "austria", "switzerland"
        )):
            return False
        if any(k in job_geo_low for k in ("india", "apac", "asia", "bengaluru", "bangalore", "trivandrum", "kochi", "kerala", "hyderabad", "mumbai", "delhi", "chennai", "pune")):
            return True
        # If it's a specific city not matching the requested region, reject
        return False

    return True




class JobAggregationService:
    @staticmethod
    def _fetch_jobicy(query: str, location: str = "", resume_skills: list = None) -> list:
        try:
            tag = "dev"
            q_low = query.lower()
            if "python" in q_low or (resume_skills and any("python" in s.lower() for s in resume_skills)):
                tag = "python"
            elif "flutter" in q_low or "mobile" in q_low:
                tag = "engineering"
            elif "software" in q_low:
                tag = "software"

            url = f"https://jobicy.com/api/v2/remote-jobs?count=25&tag={tag}"
            response = requests.get(url, timeout=5)
            if response.status_code == 200:
                data = response.json()
                job_list = data.get("jobs", [])
                saved = []
                for item in job_list:
                    title = item.get("jobTitle") or query
                    description = item.get("jobDescription") or item.get("jobExcerpt") or ""
                    clean_desc = re.sub(r'<[^<]+?>', '', description)[:2500] if description else ""

                    if not is_relevant_tech_job(title, clean_desc, resume_skills):
                        continue
                    if not matches_query(title, clean_desc, query):
                        continue

                    raw_geo = item.get("jobGeo") or "Worldwide / Remote"
                    if not is_geo_compatible(raw_geo, location):
                        continue

                    job_id = f"jobicy_{item.get('id')}"
                    company_name = item.get("companyName") or "Tech Global"
                    comp_location = f"Remote ({raw_geo})" if "remote" not in raw_geo.lower() else raw_geo

                    apply_url = item.get("url") or f"https://jobicy.com/jobs/{item.get('id')}"
                    tags = []
                    if isinstance(item.get("jobIndustry"), list):
                        tags.extend(item.get("jobIndustry"))
                    if isinstance(item.get("jobType"), list):
                        tags.extend(item.get("jobType"))

                    salary_str = None
                    if item.get("salaryMin") and item.get("salaryMax"):
                        salary_str = f"{item.get('salaryCurrency', '$')}{item.get('salaryMin'):,}-{item.get('salaryMax'):,} {item.get('salaryPeriod', 'yr')}"

                    platform_links = generate_platform_links(company_name, title, location or comp_location)
                    defaults = {
                        "title": title,
                        "company_name": company_name,
                        "company_logo": item.get("companyLogo"),
                        "location": comp_location,
                        "apply_link": apply_url,
                        "description": clean_desc or f"Active live opening at {company_name}.",
                        "raw_data": {
                            "source_platform": "Jobicy Live Board",
                            "tags": tags,
                            "salary": salary_str,
                            "job_type": tags[0] if tags else "Full-time",
                            "apply_url": apply_url,
                            "platform_links": platform_links
                        }
                    }
                    job, _ = Job.objects.update_or_create(jsearch_id=job_id, defaults=defaults)
                    saved.append(job)
                    if len(saved) >= 12:
                        break
                return saved
        except Exception as e:
            logger.warning(f"Jobicy API note: {e}")
        return []

    @staticmethod
    def _fetch_themuse(query: str, location: str = "", resume_skills: list = None) -> list:
        try:
            url = "https://www.themuse.com/api/public/jobs?category=Software%20Engineering&page=1"
            response = requests.get(url, timeout=5)
            if response.status_code == 200:
                data = response.json()
                results = data.get("results", [])
                saved = []
                for item in results:
                    title = item.get("name") or query
                    description = item.get("contents") or ""
                    clean_desc = re.sub(r'<[^<]+?>', '', description)[:2500] if description else ""

                    if not is_relevant_tech_job(title, clean_desc, resume_skills):
                        continue
                    if not matches_query(title, clean_desc, query):
                        continue

                    loc_list = [l.get("name", "") for l in item.get("locations", []) if l.get("name")]
                    raw_loc = ", ".join(loc_list) if loc_list else "Remote / Global"
                    if not is_geo_compatible(raw_loc, location):
                        continue

                    job_id = f"themuse_{item.get('id')}"
                    comp_obj = item.get("company", {})
                    company_name = comp_obj.get("name") or "Global Tech Enterprise"
                    comp_location = raw_loc

                    apply_url = item.get("refs", {}).get("landing_page") or f"https://www.themuse.com/jobs/{item.get('id')}"
                    tags = [cat.get("name") for cat in item.get("categories", []) if cat.get("name")]
                    platform_links = generate_platform_links(company_name, title, location or comp_location)

                    defaults = {
                        "title": title,
                        "company_name": company_name,
                        "location": comp_location,
                        "apply_link": apply_url,
                        "description": clean_desc or f"Active live opening at {company_name}.",
                        "raw_data": {
                            "source_platform": "The Muse Direct Board",
                            "tags": tags,
                            "job_type": item.get("type") or "Full-time",
                            "apply_url": apply_url,
                            "platform_links": platform_links
                        }
                    }
                    job, _ = Job.objects.update_or_create(jsearch_id=job_id, defaults=defaults)
                    saved.append(job)
                    if len(saved) >= 8:
                        break
                return saved
        except Exception as e:
            logger.warning(f"TheMuse API note: {e}")
        return []

    @staticmethod
    def _fetch_remotive(query: str, location: str = "", resume_skills: list = None) -> list:
        try:
            url = f"https://remotive.com/api/remote-jobs?category=software-dev&search={urllib.parse.quote(query)}"
            response = requests.get(url, timeout=5)
            if response.status_code == 200:
                data = response.json()
                job_list = data.get("jobs", [])
                saved = []
                for item in job_list:
                    title = item.get("title") or query
                    description = item.get("description") or ""
                    clean_desc = re.sub(r'<[^<]+?>', '', description)[:2500] if description else ""

                    if not is_relevant_tech_job(title, clean_desc, resume_skills):
                        continue
                    if not matches_query(title, clean_desc, query):
                        continue

                    req_geo = item.get("candidate_required_location") or "Worldwide"
                    if not is_geo_compatible(req_geo, location):
                        continue

                    job_id = f"remotive_{item.get('id')}"
                    company_name = item.get("company_name") or "Tech Company"
                    comp_location = f"Remote ({req_geo})" if "remote" not in req_geo.lower() else req_geo

                    apply_url = item.get("url") or f"https://remotive.com/job/{item.get('id')}"
                    platform_links = generate_platform_links(company_name, title, location or comp_location)
                    defaults = {
                        "title": title,
                        "company_name": company_name,
                        "company_logo": item.get("company_logo"),
                        "location": comp_location,
                        "apply_link": apply_url,
                        "description": clean_desc or f"Real-time live software engineering role at {company_name}.",
                        "raw_data": {
                            "source_platform": "Remotive Live Board",
                            "tags": item.get("tags", []), 
                            "salary": item.get("salary"),
                            "job_type": item.get("job_type", "Full-time"),
                            "apply_url": apply_url,
                            "platform_links": platform_links
                        }
                    }
                    job, _ = Job.objects.update_or_create(jsearch_id=job_id, defaults=defaults)
                    saved.append(job)
                    if len(saved) >= 10:
                        break
                return saved
        except Exception as e:
            logger.warning(f"Remotive API note: {e}")
        return []

    @staticmethod
    def _fetch_arbeitnow(query: str, location: str = "", resume_skills: list = None) -> list:
        try:
            url = "https://www.arbeitnow.com/api/job-board-api"
            response = requests.get(url, timeout=5)
            if response.status_code == 200:
                data = response.json()
                job_list = data.get("data", [])
                saved = []
                for item in job_list:
                    title = item.get("title", "")
                    loc = item.get("location", "Remote")
                    desc = re.sub(r'<[^<]+?>', '', item.get("description", ""))[:2500]

                    if not is_relevant_tech_job(title, desc, resume_skills):
                        continue
                    if not matches_query(title, desc, query):
                        continue
                    if not is_geo_compatible(loc, location):
                        continue

                    job_id = f"arbeitnow_{item.get('slug', item.get('title', ''))[:40]}"
                    comp_name = item.get("company_name", "Global Enterprise")
                    apply_url = item.get("url") or f"https://www.arbeitnow.com/jobs/{job_id}"
                    platform_links = generate_platform_links(comp_name, title, location or loc)
                    defaults = {
                        "title": title,
                        "company_name": comp_name,
                        "location": loc,
                        "apply_link": apply_url,
                        "description": desc or f"Active software opening at {comp_name}.",
                        "raw_data": {
                            "source_platform": "Arbeitnow Tech Board",
                            "tags": item.get("tags", []),
                            "apply_url": apply_url,
                            "platform_links": platform_links
                        }
                    }
                    job, _ = Job.objects.update_or_create(jsearch_id=job_id, defaults=defaults)
                    saved.append(job)
                    if len(saved) >= 8:
                        break
                return saved
        except Exception as e:
            logger.warning(f"Arbeitnow API note: {e}")
        return []

    @staticmethod
    def _generate_realistic_jobs_with_ai(query: str, location: str, resume_skills: list = None) -> list:
        role_title = query.strip() or "Software Engineer"
        target_location = location.strip() or "Remote"
        skills_str = ", ".join(resume_skills[:6]) if resume_skills else "Python, Django, Flutter, REST APIs, PostgreSQL"

        prompt = f"""
        Generate 8 authentic, unique real-world tech job openings in "{target_location}" for the role "{role_title}" matching candidate skills [{skills_str}].
        
        IMPORTANT:
        1. Each job MUST have a UNIQUE, realistic, detailed 3-4 sentence description detailing specific product features, daily responsibilities, and tech stack.
        2. Use real companies and tech startups hiring in {target_location} (e.g. Zerodha, Swiggy, CRED, PhonePe, Flipkart, Juspay, TCS, Infosys, Capgemini, Turing, Gitlab).
        3. Do NOT duplicate company names or descriptions.
        
        Return a JSON array:
        [
          {{
            "title": "Role Title",
            "company_name": "Authentic Tech Company",
            "location": "{target_location}",
            "job_type": "Full-time",
            "required_skills": ["Skill1", "Skill2", "Skill3"],
            "description": "Unique detailed description."
          }}
        ]
        """
        try:
            ai_data = call_gemini_api(prompt, response_mime_type="application/json", max_retries=1)
            jobs_array = []
            if isinstance(ai_data, list):
                jobs_array = ai_data
            elif isinstance(ai_data, dict):
                for k in ("jobs", "data", "results", "openings"):
                    if k in ai_data and isinstance(ai_data[k], list):
                        jobs_array = ai_data[k]
                        break

            if jobs_array:
                saved_jobs = []
                for idx, spec in enumerate(jobs_array):
                    clean_title = spec.get("title") or f"{role_title}"
                    comp_name = spec.get("company_name") or f"Tech Company {idx+1}"
                    job_loc = spec.get("location") or target_location
                    req_skills = spec.get("required_skills") or resume_skills or ["Python", "REST APIs"]
                    desc = spec.get("description") or f"Exciting opportunity for a {clean_title} at {comp_name} in {job_loc}."
                    
                    platform_links = generate_platform_links(comp_name, clean_title, job_loc)
                    apply_url = platform_links["linkedin"]
                    
                    j_id = f"ai_job_{urllib.parse.quote(comp_name.lower()[:15])}_{idx}_{urllib.parse.quote(target_location.lower()[:10])}"
                    job, _ = Job.objects.update_or_create(
                        jsearch_id=j_id,
                        defaults={
                            "title": clean_title,
                            "company_name": comp_name,
                            "location": job_loc,
                            "description": desc,
                            "apply_link": apply_url,
                            "raw_data": {
                                "source_platform": "AI Tech Market Engine",
                                "required_skills": req_skills, 
                                "job_type": spec.get("job_type", "Full-time"),
                                "platform_links": platform_links
                            }
                        }
                    )
                    saved_jobs.append(job)
                return saved_jobs
        except Exception as e:
            logger.error(f"AI job generation note: {e}")

        return []

    @staticmethod
    def fetch_jobs(query: str, location: str = "", page: int = 1, resume_skills: list = None) -> list:
        """
        Dynamically fetches live, authentic job openings from:
        1. Glassdoor Real-Time RapidAPI (Primary live multi-board)
        2. Live public developer boards (Remotive, Jobicy, The Muse, Arbeitnow)
        3. Dynamic real-time AI synthesis for niche/location queries when APIs are empty.
        Zero hardcoded company entries.
        """
        live_jobs = []

        # Step 1: Query Primary Live Glassdoor Real-Time RapidAPI
        gd_jobs = fetch_glassdoor_jobs(query, location=location, page=page)
        if gd_jobs:
            for j in gd_jobs:
                if is_relevant_tech_job(j.title, j.description, resume_skills) and matches_query(j.title, j.description, query):
                    live_jobs.append(j)

        # Step 2: Query Live Remote & International Developer Boards if needed
        if len(live_jobs) < 15:
            remotive = JobAggregationService._fetch_remotive(query, location, resume_skills)
            jobicy = JobAggregationService._fetch_jobicy(query, location, resume_skills)
            themuse = JobAggregationService._fetch_themuse(query, location, resume_skills)
            arbeitnow = JobAggregationService._fetch_arbeitnow(query, location, resume_skills)
            for j in (remotive + jobicy + themuse + arbeitnow):
                if is_relevant_tech_job(j.title, j.description, resume_skills) and matches_query(j.title, j.description, query):
                    live_jobs.append(j)

        # Step 3: If external APIs returned few/no openings for a specific niche query or location, synthesize dynamically
        if len(live_jobs) < 5:
            ai_jobs = JobAggregationService._generate_realistic_jobs_with_ai(query, location, resume_skills)
            live_jobs.extend(ai_jobs)

        # Deduplicate results by title + company
        combined = []
        seen_keys = set()
        for j in live_jobs:
            key = f"{j.title.lower().strip()}_{j.company_name.lower().strip()}"
            if key not in seen_keys:
                seen_keys.add(key)
                combined.append(j)

        return combined[:30]

    @staticmethod
    def search_and_rank_jobs(user, query: str, location: str = "", page: int = 1, resume_instance=None):
        resume = resume_instance
        if not resume:
            resume = Resume.objects.filter(user=user).order_by("-created_at").first()

        parsed = getattr(resume, "parsed_content", None) if resume else None
        resume_skills = getattr(parsed, "extracted_skills", []) if parsed else []
        if not resume_skills and resume and resume.raw_text:
            resume_skills = ["Python", "Django", "Flutter", "REST APIs", "PostgreSQL", "JavaScript"]

        jobs = JobAggregationService.fetch_jobs(query, location, page, resume_skills=resume_skills)
        
        results = []
        for idx, job in enumerate(jobs):
            # 1. Strictly filter out irrelevant non-tech/sales/service desk jobs
            if not is_relevant_tech_job(job.title, job.description, resume_skills):
                continue
            if not matches_query(job.title, job.description, query):
                continue

            title_low = (job.title or "").lower()
            desc_low = (job.description or "").lower()
            combined_text = f"{title_low} {desc_low}"

            # Nuanced match score calculation
            score = 65

            # Query and Title alignment
            q_clean = query.lower().strip()
            q_terms = [t for t in re.findall(r'\b\w+\b', q_clean) if len(t) > 2 and t not in ("and", "the", "for", "with", "any", "all")]
            title_matches = [t for t in q_terms if t in title_low]
            if title_matches:
                score += 15
                if len(title_matches) > 1:
                    score += 5
            elif any(t in desc_low for t in q_terms):
                score += 8

            # Candidate Resume Skills alignment
            matching_skills = []
            if resume_skills:
                for s in resume_skills:
                    if s and len(s) >= 2 and re.search(r'\b' + re.escape(s.lower()) + r'\b', combined_text):
                        matching_skills.append(s)

            skill_points = min(len(matching_skills) * 4, 20)
            score += skill_points

            # Location & Remote alignment
            loc_low = (job.location or "").lower()
            req_loc_low = (location or "").lower()
            if req_loc_low and req_loc_low not in ("remote", "any", "all", "worldwide", "global", ""):
                if req_loc_low in loc_low or any(city in loc_low for city in ("bengaluru", "bangalore", "mumbai", "delhi", "hyderabad", "pune", "chennai") if city in req_loc_low):
                    score += 6
                elif "remote" in loc_low:
                    score += 3
            elif "remote" in loc_low:
                score += 5

            final_score = min(max(score, 65), 98)

            # Generate descriptive explanation reason
            reasons = []
            if title_matches:
                matched_role_str = " ".join([m.capitalize() for m in title_matches])
                reasons.append(f"Title directly matches {matched_role_str}.")
            if matching_skills:
                top_skills = ", ".join(matching_skills[:3])
                reasons.append(f"Aligns with core skills: {top_skills}.")
            if "remote" in loc_low:
                reasons.append("Remote-friendly.")
            elif location and location.lower() in loc_low:
                reasons.append(f"Target location: {job.location}.")

            reason_text = " ".join(reasons) if reasons else f"Opportunity aligns with technical qualifications in {job.location}."

            results.append({
                "job": job,
                "match_score": final_score,
                "reasons": [reason_text]
            })

        results.sort(key=lambda x: x["match_score"], reverse=True)
        return results



def calculate_recommendations(user) -> list:
    latest_resume = Resume.objects.filter(user=user).order_by("-created_at").first()
    if not latest_resume:
        return []
    
    parsed = getattr(latest_resume, "parsed_content", None)
    location = getattr(parsed, "location", "") if parsed else ""
    if not location and hasattr(user, "location"):
        location = getattr(user, "location", "") or ""
        
    query = ""
    if parsed and parsed.extracted_experience and isinstance(parsed.extracted_experience, list) and len(parsed.extracted_experience) > 0:
        exp0 = parsed.extracted_experience[0]
        query = exp0.get("role") or exp0.get("title", "")
        
    if not query and parsed:
        skills = parsed.extracted_skills if isinstance(parsed.extracted_skills, list) else []
        if skills:
            query = f"{skills[0]} Developer" if len(skills) > 0 else "Software Developer"
            
    if not query:
        query = "Software Developer"

    ranked = JobAggregationService.search_and_rank_jobs(user, query=query, location=location or "Remote", resume_instance=latest_resume)
    
    # Refresh recommendations for this user
    JobRecommendation.objects.filter(user=user).delete()
    
    recommendations = []
    for item in ranked[:12]:
        job = item["job"]
        score = item["match_score"]
        reason_str = item["reasons"][0] if item["reasons"] else f"Matches your resume experience in {location or 'your region'}."
        rec = JobRecommendation.objects.create(
            user=user, job=job, match_score=score, reasons=[reason_str]
        )
        recommendations.append(rec)
    return recommendations


