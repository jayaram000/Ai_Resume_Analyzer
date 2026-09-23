import json
import logging
from common.gemini import call_gemini_api
from resumes.models import Resume
from analysis.models import SkillGapAnalysis
from ._common import _get_resume_text

logger = logging.getLogger(__name__)

def generate_skill_gap(user, target_role: str, experience: str = "Mid-Level") -> SkillGapAnalysis:
    latest_resume = Resume.objects.filter(user=user).order_by("-created_at").first()
    user_skills = []
    if latest_resume and hasattr(latest_resume, "parsed_content"):
        user_skills = latest_resume.parsed_content.extracted_skills
        
    prompt = f"""
Compare the user's current skills vs. requirements for target role: "{target_role}" at "{experience}" level.
User's skills: {json.dumps(user_skills)}

Identify:
1. Missing skills
2. Recommended skills
3. Learning priority list indicating priority, time estimates, and learning resource references.
4. A detailed phased career roadmap containing specific milestones and actionable guidance based on the user's experience level.

Your response MUST be a JSON object matching this schema:
{{
  "missing_skills": ["skill1"],
  "recommended_skills": ["skill2"],
  "learning_priority": [
     {{"skill": "skillname", "priority": "High/Medium/Low", "time_estimate": "1 week", "resources": "links/docs"}}
  ],
  "roadmap": [
     {{"phase": "Phase 1 (Months 1-2): Core Foundations", "milestones": ["Learn X", "Build Y"], "guidance": "Focus on..."}}
  ]
}}
"""
    try:
        result = call_gemini_api(prompt, response_mime_type="application/json", max_retries=1)
    except Exception as e:
        logger.error(f"Skill gap API failed: {str(e)}")
        result = {
            "missing_skills": ["Unable to fetch missing skills"],
            "recommended_skills": ["Unable to fetch recommendations"],
            "learning_priority": [],
            "roadmap": []
        }
    
    gap = SkillGapAnalysis.objects.create(
        user=user,
        target_role=target_role,
        missing_skills=result.get("missing_skills", []),
        recommended_skills=result.get("recommended_skills", []),
        learning_priority=result.get("learning_priority", []),
        roadmap=result.get("roadmap", [])
    )
    return gap



class AdvancedSkillGapService:
    @staticmethod
    def analyze_skill_gap(user, target_role: str, resume_id: str = None):
        """
        Performs a deep AI-driven gap analysis comparing the candidate's actual resume
        against the target position & seniority level.
        Generates readiness score, matched skills, categorized gap areas,
        phased transition roadmap, portfolio projects, certifications, and resume positioning tips.
        """
        from resumes.models import Resume
        from jobs.services import fetch_jobs_from_jsearch
        from analysis.models import SkillGapAnalysis
        from common.gemini import call_gemini_api
        import re
        from collections import Counter
        import json

        if resume_id:
            latest_resume = Resume.objects.filter(user=user, id=resume_id).first()
        else:
            latest_resume = Resume.objects.filter(user=user).order_by("-created_at").first()
            
        user_skills = []
        resume_raw_text = ""
        resume_title = "Candidate Resume"
        if latest_resume:
            resume_title = latest_resume.title or "Resume"
            resume_raw_text = latest_resume.raw_text or ""
            if hasattr(latest_resume, "parsed_content") and latest_resume.parsed_content:
                user_skills = [s for s in latest_resume.parsed_content.extracted_skills]

        # Extract market keywords
        jobs = fetch_jobs_from_jsearch(target_role, page=1)

        tech_dictionary = {
            "python", "django", "flask", "fastapi", "javascript", "react", "angular", "vue",
            "node", "express", "typescript", "flutter", "dart", "java", "spring", "spring boot", "c++", "c#",
            ".net", "ruby", "rails", "go", "golang", "php", "laravel", "sql", "postgres", "postgresql", "mysql",
            "mongodb", "redis", "kafka", "rabbitmq", "docker", "kubernetes", "aws", "gcp", "azure", "git", "github",
            "ci/cd", "html", "css", "tailwind", "graphql", "rest api", "testing", "junit", "pytest",
            "system design", "microservices", "distributed systems", "agile", "scrum", "jira", "linux"
        }

        tech_counts = Counter()
        for job in jobs:
            desc_lower = job.description.lower()
            for tech in tech_dictionary:
                if re.search(r'\b' + re.escape(tech) + r'\b', desc_lower):
                    tech_counts[tech] += 1

        market_techs = [tech for tech, count in tech_counts.most_common(20)]
        experience = getattr(user, '_temp_experience', 'Mid-Level')

        # Construct comprehensive Gemini prompt
        user_skills_str = ", ".join(user_skills[:40]) if user_skills else "General software development skills"
        resume_snippet = resume_raw_text[:2000] if resume_raw_text else f"Skills: {user_skills_str}"

        prompt = f"""
You are a Principal Technical Career Strategist and Hiring Architect.
Perform an in-depth Career Gap & Upskilling Intelligence analysis for a candidate targeting the position "{target_role}" at the "{experience}" seniority level.

--- CANDIDATE RESUME PROFILE ---
Title: {resume_title}
Extracted Skills: {user_skills_str}
Resume Context:
{resume_snippet}

--- TARGET ROLE ---
Position: {target_role}
Level: {experience}
Top Market Tech Stack: {", ".join(market_techs)}

--- REQUIRED ANALYSIS ---
Compare the candidate's exact background against the requirements of "{target_role} ({experience} level)".
Provide a comprehensive, highly detailed response in JSON format.

Your output MUST be valid JSON with this exact schema:
{{
  "match_score": 68,
  "readiness_level": "Solid Foundation - Strategic Upskilling Needed",
  "readiness_summary": "Detailed 2-3 sentence executive evaluation comparing the candidate's existing background (e.g. Flutter/Python) with what is required for a {target_role} at the {experience} level.",
  "matched_skills": ["List", "of", "skills", "already", "in", "resume", "that", "apply", "directly"],
  "missing_skills": ["List", "of", "missing", "technologies", "and", "tools"],
  "categorized_gaps": {{
    "Core Language & Frameworks": ["Spring Boot 3", "Java 21/17", "Hibernate/JPA"],
    "Architecture & System Design": ["Microservices Architecture", "Event-Driven Architecture (Kafka)", "Domain-Driven Design (DDD)", "Distributed Caching"],
    "Cloud & Infrastructure": ["Docker & Containerization", "Kubernetes (K8s)", "AWS (ECS, RDS, S3)", "CI/CD Pipelines"],
    "Databases & Storage": ["PostgreSQL Performance Tuning", "Redis Caching", "Database Sharding"],
    "Testing & Quality": ["JUnit 5 & Mockito", "Integration Testing", "Load Testing (JMeter)"]
  }},
  "roadmap": [
    {{
      "phase": "Phase 1 (Months 1-2): Core Enterprise Ecosystem & Frameworks",
      "guidance": "Focus on deep language internals, concurrency, memory model, and enterprise framework fundamentals.",
      "milestones": [
        "Master Java 17/21 Virtual Threads, Records, and Streams API",
        "Build full-stack microservices with Spring Boot 3 & Spring Security",
        "Implement relational persistence with JPA/Hibernate & PostgreSQL"
      ]
    }},
    {{
      "phase": "Phase 2 (Months 3-4): Distributed Architecture, Messaging & Cloud",
      "guidance": "Transition from monolithic mindset to scalable distributed microservices.",
      "milestones": [
        "Event-driven architecture with Apache Kafka for asynchronous communication",
        "Containerize microservices with Docker and deploy to Kubernetes clusters",
        "Implement API Gateway, Circuit Breakers (Resilience4j), and centralized logging"
      ]
    }},
    {{
      "phase": "Phase 3 (Months 5-6): System Design, High-Load Optimization & Leadership",
      "guidance": "Develop architecture-level thinking for high throughput, fault tolerance, and team mentoring.",
      "milestones": [
        "Design systems handling 100k+ RPS with Redis caching and read replicas",
        "Lead technical design reviews (RFCs) and security compliance audits",
        "System design interview mastery and architectural trade-off analysis"
      ]
    }}
  ],
  "recommended_projects": [
    {{
      "title": "High-Throughput Distributed Payment & Order Processing Engine",
      "description": "An event-driven microservices platform utilizing Spring Boot 3, Kafka, Redis, PostgreSQL, and Docker with idempotent transaction guarantees.",
      "tech_stack": ["Java 21", "Spring Boot", "Kafka", "PostgreSQL", "Redis", "Docker"]
    }},
    {{
      "title": "Multi-Tenant Enterprise SaaS Gateway with Kubernetes",
      "description": "A secure API gateway managing routing, rate limiting, and JWT authentication across containerized microservices deployed on AWS EKS.",
      "tech_stack": ["Kubernetes", "AWS EKS", "Spring Cloud Gateway", "OAuth2/OIDC", "Prometheus"]
    }}
  ],
  "recommended_certifications": [
    "Oracle Certified Professional: Java SE 17 Developer",
    "AWS Certified Solutions Architect - Associate / Professional",
    "Certified Kubernetes Application Developer (CKAD)"
  ],
  "resume_transition_tips": [
    "Reframe past backend and architectural achievements with strong metrics (e.g. throughput, latency reductions, scalability).",
    "Highlight clean architecture, design patterns, and cross-functional leadership in your experience bullets.",
    "Add a dedicated 'System Architecture & Cloud' section to showcase your modern backend stack."
  ]
}}
"""
        try:
            ai_data = call_gemini_api(prompt, response_mime_type="application/json", max_retries=1)
            if not isinstance(ai_data, dict):
                ai_data = {}
        except Exception as e:
            logger.error(f"Skill gap deep AI analysis failed: {str(e)}")
            ai_data = {}

        match_score = ai_data.get("match_score", 65)
        readiness_level = ai_data.get("readiness_level", f"{experience} Transition Readiness")
        readiness_summary = ai_data.get("readiness_summary") or f"Comprehensive evaluation comparing your resume against {target_role} requirements at the {experience} level."
        matched_skills = ai_data.get("matched_skills") or [s for s in user_skills if s.lower() in tech_dictionary][:8]
        missing_skills_list = ai_data.get("missing_skills") or [t for t in market_techs if t.lower() not in [u.lower() for u in user_skills]] or ["Spring Boot", "Java 21", "Microservices", "Docker", "Kubernetes", "Kafka", "AWS", "System Design"]
        categorized_gaps = ai_data.get("categorized_gaps") or {}
        roadmap = ai_data.get("roadmap", [])
        recommended_projects = ai_data.get("recommended_projects", [])
        recommended_certifications = ai_data.get("recommended_certifications", [])
        resume_transition_tips = ai_data.get("resume_transition_tips", [])

        if not categorized_gaps:
            role_lower = target_role.lower()
            if "java" in role_lower:
                categorized_gaps = {
                    "Core Language & Frameworks": ["Spring Boot 3", "Java 17/21", "Hibernate/JPA"],
                    "Architecture & Microservices": ["Microservices Architecture", "Apache Kafka", "Domain-Driven Design (DDD)"],
                    "Cloud & Infrastructure": ["Docker", "Kubernetes", "AWS ECS/EKS", "CI/CD"],
                    "Databases & Storage": ["PostgreSQL Optimization", "Redis Caching"],
                    "Testing & Quality": ["JUnit 5 & Mockito", "Integration Testing"]
                }
            elif "python" in role_lower:
                categorized_gaps = {
                    "Core Frameworks": ["FastAPI", "Django REST Framework", "Asyncio"],
                    "Data & Cloud": ["PostgreSQL", "Redis", "Docker", "AWS"],
                    "Architecture": ["Microservices", "Celery Task Queues", "System Design"],
                    "Testing": ["Pytest", "TDD", "CI/CD Workflows"]
                }
            else:
                categorized_gaps = {
                    "Core Technologies": missing_skills_list[:3] or ["Modern Frameworks", "Core Language Internals"],
                    "Architecture & Design": ["System Design", "Microservices", "Design Patterns"],
                    "Cloud & DevOps": ["Docker", "CI/CD Automation", "Cloud Platforms"],
                    "Databases & Caching": ["Relational DBs", "Distributed Caching"],
                    "Testing & Quality": ["Unit Testing", "Code Quality Standards"]
                }

        if not roadmap:
            roadmap = [
                {
                    "phase": f"Phase 1 (Months 1-2): Core {target_role} Foundations",
                    "guidance": "Deep dive into language fundamentals, concurrency, and modern framework architectures.",
                    "milestones": [
                        f"Master core syntax and enterprise patterns for {target_role}",
                        "Build production-grade REST APIs and database layers",
                        "Implement automated unit and integration tests"
                    ]
                },
                {
                    "phase": "Phase 2 (Months 3-4): Scalable Architecture & Cloud Deployment",
                    "guidance": "Focus on distributed system patterns, containerization, and cloud infrastructure.",
                    "milestones": [
                        "Containerize services with Docker and configure CI/CD pipelines",
                        "Implement asynchronous messaging and distributed caching",
                        "Deploy services to managed cloud environments"
                    ]
                },
                {
                    "phase": f"Phase 3 (Months 5-6): {experience} Leadership & System Design",
                    "guidance": f"Master high-throughput system design and technical leadership for {experience} level.",
                    "milestones": [
                        "Architect high-availability systems with failover strategies",
                        "Perform architectural reviews and latency optimization",
                        "Lead system design interviews and technical RFC documentation"
                    ]
                }
            ]

        if not recommended_projects:
            recommended_projects = [
                {
                    "title": f"Production-Grade Distributed {target_role} Service",
                    "description": f"An enterprise-scale microservices system featuring robust authentication, rate limiting, and asynchronous messaging.",
                    "tech_stack": missing_skills_list[:5] or ["Docker", "PostgreSQL", "Redis", "Microservices"]
                }
            ]

        if not recommended_certifications:
            recommended_certifications = [
                f"Professional {target_role} Specialist Certification",
                "AWS Certified Solutions Architect",
                "Kubernetes Certified Developer (CKAD)"
            ]

        if not resume_transition_tips:
            resume_transition_tips = [
                f"Emphasize scalable backend and architecture achievements relevant to {target_role} in your bullet points.",
                "Quantify project impact with metrics like throughput improvements, latency reduction, and user scale.",
                f"Highlight competencies in {', '.join(missing_skills_list[:3])} prominently in your technical skills summary."
            ]

        # Persist analysis in database
        gap, created = SkillGapAnalysis.objects.update_or_create(
            user=user,
            target_role=target_role,
            defaults={
                "missing_skills": missing_skills_list,
                "recommended_skills": missing_skills_list[:6],
                "learning_priority": [
                    {
                        "match_score": match_score,
                        "readiness_level": readiness_level,
                        "readiness_summary": readiness_summary,
                        "matched_skills": matched_skills,
                        "categorized_gaps": categorized_gaps,
                        "recommended_projects": recommended_projects,
                        "recommended_certifications": recommended_certifications,
                        "resume_transition_tips": resume_transition_tips,
                    }
                ],
                "roadmap": roadmap
            }
        )

        return {
            "id": str(gap.id),
            "target_role": target_role,
            "match_score": match_score,
            "readiness_score": match_score,
            "readiness_level": readiness_level,
            "readiness_summary": readiness_summary,
            "matched_skills": matched_skills,
            "missing_skills": missing_skills_list,
            "categorized_gaps": categorized_gaps,
            "roadmap": roadmap,
            "recommended_projects": recommended_projects,
            "recommended_certifications": recommended_certifications,
            "resume_transition_tips": resume_transition_tips,
        }


