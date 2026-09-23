import json
import logging
import re
from common.gemini import call_gemini_api
from resumes.models import Resume
from analysis.models import ATSAnalysis
from ._common import _get_resume_text

logger = logging.getLogger(__name__)

class ATSScoringService:
    @staticmethod
    def calculate_ats_score(resume: Resume, target_jd: str = None) -> dict:
        """
        Calculates a deterministic, non-random ATS score out of 100.
        Uses 6 scoring categories with appropriate weights.
        """
        parsed = getattr(resume, "parsed_content", None)
        text = parsed.extracted_text if parsed else _get_resume_text(resume)
        
        # 1. Completeness Score (10% weight)
        comp_points = 0
        if parsed:
            if len(text) > 100: comp_points += 2  # Has summary/intro text
            if len(parsed.extracted_skills) > 0: comp_points += 2
            if len(parsed.extracted_experience) > 0: comp_points += 2
            if len(parsed.extracted_education) > 0: comp_points += 2
            if len(parsed.extracted_projects) > 0: comp_points += 1
            if len(parsed.extracted_certifications) > 0: comp_points += 1
        else:
            comp_points = 5  # default if no parsed data
        completeness_score = int((comp_points / 10.0) * 100)

        # 2. Skills Score (20% weight)
        skills = parsed.extracted_skills if parsed else []
        skills_score = min(100, len(skills) * 10)  # 10 skills = 100 score

        # 3. Keyword Match Score (25% weight)
        standard_keywords = {
            "python", "django", "flutter", "dart", "javascript", "react", "sql", 
            "git", "docker", "aws", "kubernetes", "typescript", "postgres", 
            "html", "css", "ci/cd", "rest api", "testing", "agile", "scrum"
        }
        
        # Extract keywords from JD if provided
        jd_keywords = set()
        if target_jd:
            # Simple word extraction
            words = re.findall(r'\b[a-zA-Z]{3,}\b', target_jd.lower())
            jd_keywords = set(words).intersection(standard_keywords)
            if not jd_keywords:
                jd_keywords = {"python", "django", "flutter", "dart", "sql"} # fallback

        keyword_score = 0
        text_lower = text.lower()
        if jd_keywords:
            matched = [k for k in jd_keywords if k in text_lower]
            keyword_score = int((len(matched) / len(jd_keywords)) * 100)
        else:
            # Overlap with standard industry keywords
            matched = [k for k in standard_keywords if k in text_lower]
            keyword_score = min(100, len(matched) * 8)

        # 4. Formatting Score (15% weight)
        formatting_points = 70  # Base
        # Deduct if text is way too short or long
        char_count = len(text)
        if char_count < 500:
            formatting_points -= 30
        elif char_count > 8000:
            formatting_points -= 15
            
        # Add points if contact credentials are found
        has_email = "@" in text or (parsed and parsed.email)
        has_phone = re.search(r'\+?\d[\d -]{7,}\d', text) or (parsed and parsed.phone)
        if has_email: formatting_points += 15
        if has_phone: formatting_points += 15
        formatting_score = min(100, max(0, formatting_points))

        # 5. Experience Score (20% weight)
        action_verbs = {"led", "managed", "designed", "built", "created", "optimized", "refactored", "developed", "implemented"}
        verbs_found = [v for v in action_verbs if v in text_lower]
        exp_records = parsed.extracted_experience if parsed else []
        experience_score = min(100, (len(verbs_found) * 8) + (len(exp_records) * 15))
        if experience_score == 0 and len(text) > 500:
            experience_score = 65  # Default baseline for entry levels

        # 6. Education Score (10% weight)
        edu_score = 0
        degrees = {"phd", "doctorate", "master", "m.tech", "m.sc", "mba", "bachelor", "b.tech", "b.sc", "b.a", "degree"}
        edu_found = [d for d in degrees if d in text_lower]
        if edu_found:
            if "phd" in edu_found or "doctorate" in edu_found:
                edu_score = 100
            elif "master" in edu_found or "m.tech" in edu_found or "mba" in edu_found:
                edu_score = 90
            else:
                edu_score = 80
        elif parsed and len(parsed.extracted_education) > 0:
            edu_score = 75
        education_score = edu_score

        # Calculate weighted average ATS score
        ats_score = int(
            (keyword_score * 0.25) +
            (skills_score * 0.20) +
            (experience_score * 0.20) +
            (formatting_score * 0.15) +
            (education_score * 0.10) +
            (completeness_score * 0.10)
        )
        
        # Suggestions list based on category gaps
        suggestions = []
        if completeness_score < 80:
            suggestions.append("Fill in missing resume sections. Ensure Projects and Certifications are clearly defined.")
        if skills_score < 70:
            suggestions.append("Add more tech stack skills matching your target industry (e.g. cloud tools, APIs).")
        if keyword_score < 75:
            suggestions.append("Tailor your resume vocabulary to match industry standard keyword keywords.")
        if formatting_score < 80:
            suggestions.append("Ensure your email address and phone contact details are clearly visible on the document layout.")
        if experience_score < 75:
            suggestions.append("Use strong action verbs (e.g., 'Engineered', 'Optimized', 'Led') to start experience bullet points.")
        if education_score < 70:
            suggestions.append("Explicitly state your academic degree details (e.g. BS, B.Tech, MS) in the education section.")
            
        if not suggestions:
            suggestions.append("Resume formatting is excellent. Keep tailoring keywords to specific roles you apply for.")

        return {
            "ats_score": ats_score,
            "keyword_score": keyword_score,
            "formatting_score": formatting_score,
            "skills_score": skills_score,
            "experience_score": experience_score,
            "education_score": education_score,
            "completeness_score": completeness_score,
            "suggestions": suggestions
        }



def generate_ats_analysis(resume: Resume) -> ATSAnalysis:
    """
    Computes ATS score mathematically using ATSScoringService,
    then saves to database.
    """
    scores = ATSScoringService.calculate_ats_score(resume)
    
    analysis = ATSAnalysis.objects.create(
        resume=resume,
        ats_score=scores["ats_score"],
        keyword_score=scores["keyword_score"],
        formatting_score=scores["formatting_score"],
        skills_score=scores["skills_score"],
        experience_score=scores["experience_score"],
        education_score=scores["education_score"],
        completeness_score=scores["completeness_score"],
        suggestions=scores["suggestions"]
    )
    return analysis



class CareerScoreService:
    @staticmethod
    def calculate_score(user) -> dict:
        from resumes.models import Resume
        from analysis.models import CareerReadinessSnapshot
        from jobs.models import JobRecommendation, SelectedJob

        latest_resume = Resume.objects.filter(user=user).order_by("-created_at").first()
        ats_score = 0
        parsed = None
        if latest_resume:
            ats_obj = latest_resume.ats_analyses.order_by("-created_at").first()
            if ats_obj:
                ats_score = ats_obj.ats_score
            else:
                from analysis.services import ATSScoringService
                try:
                    ats_res = ATSScoringService.calculate_ats_score(latest_resume)
                    ats_score = ats_res.get("ats_score", 0)
                except Exception:
                    ats_score = 0
            parsed = getattr(latest_resume, "parsed_content", None)

        skills = []
        if parsed and parsed.extracted_skills:
            skills = [s.lower() for s in parsed.extracted_skills if isinstance(s, str)]

        industry_baselines = {
            "python", "django", "flask", "fastapi", "javascript", "react", "angular", "vue",
            "node", "express", "typescript", "flutter", "dart", "java", "spring", "c++", "c#",
            ".net", "ruby", "rails", "go", "golang", "php", "laravel", "sql", "postgres", "mysql",
            "mongodb", "redis", "docker", "kubernetes", "aws", "gcp", "azure", "git", "github",
            "ci/cd", "html", "css", "tailwind", "sass", "graphql", "rest api", "testing", "pytest",
            "jest", "selenium", "agile", "scrum", "jira", "linux", "bash"
        }
        matched_baselines = [s for s in skills if s in industry_baselines]
        skill_coverage_score = min(100, len(matched_baselines) * 10)

        completeness_score = 0
        if parsed:
            comp_fields = [
                parsed.name,
                parsed.email,
                parsed.phone,
                parsed.extracted_skills,
                parsed.extracted_experience,
                parsed.extracted_education,
                parsed.extracted_projects,
                parsed.extracted_certifications
            ]
            filled_fields = [f for f in comp_fields if f]
            completeness_score = int((len(filled_fields) / 8.0) * 100)

        experience_score = 0
        if latest_resume:
            text = (parsed.extracted_text if parsed else getattr(latest_resume, "raw_text", "")) or ""
            action_verbs = {"led", "managed", "designed", "built", "created", "optimized", "refactored", "developed", "implemented", "engineered"}
            verbs_found = [v for v in action_verbs if v in text.lower()]
            exp_count = len(parsed.extracted_experience if (parsed and parsed.extracted_experience) else [])
            experience_score = min(100, (len(verbs_found) * 10) + (exp_count * 15))
            if experience_score == 0 and len(text) > 100:
                experience_score = 60

        job_match_scores = []
        saved_jobs = SelectedJob.objects.filter(user=user, status=SelectedJob.StatusChoices.SAVED)
        for sj in saved_jobs:
            job_match_scores.append(85)
        recs = JobRecommendation.objects.filter(user=user)
        for r in recs:
            job_match_scores.append(r.match_score)

        if job_match_scores:
            job_match_score = int(sum(job_match_scores) / len(job_match_scores))
        else:
            job_match_score = 70

        profile_score = 0
        profile = getattr(user, "profile", None)
        if profile:
            profile_fields = [
                profile.phone,
                profile.location,
                profile.linkedin_url,
                profile.github_url,
                profile.current_role,
                profile.years_of_experience
            ]
            filled_profile = [f for f in profile_fields if f]
            profile_score = int((len(filled_profile) / 6.0) * 100)

        career_score = int(
            (ats_score * 0.25) +
            (skill_coverage_score * 0.20) +
            (completeness_score * 0.15) +
            (experience_score * 0.15) +
            (job_match_score * 0.15) +
            (profile_score * 0.10)
        )

        factors = {
            "ats": ats_score,
            "skills": skill_coverage_score,
            "completeness": completeness_score,
            "experience": experience_score,
            "job_match": job_match_score,
            "profile": profile_score
        }

        snapshot = CareerReadinessSnapshot.objects.create(
            user=user,
            career_score=career_score,
            factors=factors
        )

        return {
            "career_score": career_score,
            "factors": factors,
            "created_at": snapshot.created_at.strftime("%Y-%m-%d")
        }

    @staticmethod
    def get_trend_data(user) -> list:
        from analysis.models import CareerReadinessSnapshot
        snapshots = CareerReadinessSnapshot.objects.filter(user=user).order_by("created_at")
        trend = []
        for s in snapshots:
            trend.append({
                "date": s.created_at.strftime("%Y-%m-%d"),
                "score": s.career_score
            })
        return trend

    @staticmethod
    def get_recommended_actions(factors: dict) -> list:
        if not isinstance(factors, dict):
            factors = {}
        actions = []
        if factors.get("ats", 0) < 80:
            actions.append("Optimize your resume's keywords and formatting to boost ATS compatibility.")
        if factors.get("skills", 0) < 70:
            actions.append("Acquire industry-standard skills (e.g. Docker, Cloud tools, CI/CD) matching your career target.")
        if factors.get("completeness", 0) < 90:
            actions.append("Complete missing resume sections (e.g. Certifications, Projects) to present a comprehensive profile.")
        if factors.get("experience", 0) < 70:
            actions.append("Strengthen resume bullet points by using strong action verbs like 'Engineered' or 'Led'.")
        if factors.get("job_match", 0) < 75:
            actions.append("Apply to job roles that match your skill set to improve job match compatibility.")
        if factors.get("profile", 0) < 80:
            actions.append("Complete your user profile, adding LinkedIn and GitHub URLs to improve recruiter outreach.")
        if not actions:
            actions.append("Excellent career readiness! Keep updating your skills and certifications.")
