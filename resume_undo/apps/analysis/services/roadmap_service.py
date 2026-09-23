import json
import logging
import urllib.parse
from common.gemini import call_gemini_api
from resumes.models import Resume
from analysis.models import CareerRoadmap

logger = logging.getLogger(__name__)

def generate_career_roadmap(user, current_role: str, target_role: str) -> CareerRoadmap:
    """
    Generates a rich, comprehensive, end-to-end Career Roadmap containing:
    - Step-by-step phased learning path with milestones & guidance
    - Target technology stack & top industry certifications
    - Practical production portfolio project blueprints
    - Curated YouTube video tutorials & top recommended YouTube channels
    - Documentation portals & reference sites (GeeksforGeeks, MDN, Official docs)
    - Popular online courses (Udemy, Coursera, Pluralsight)
    - Free course platforms & resources
    """
    context_desc = f"from current role '{current_role}' to target role '{target_role}'" if current_role and current_role.strip() else f"to master the target role '{target_role}' from fundamentals to expert level"

    prompt = f"""
You are a Principal Software Engineering Career Mentor and Curriculum Architect.
Generate a comprehensive, step-by-step career path and learning curriculum {context_desc}.

Include:
1. Phased learning path (e.g. Phase 1, Phase 2, Phase 3, Phase 4) with duration, strategic guidance, and concrete milestones.
2. Required target technologies stack.
3. Top recognized industry certifications with preparation advice.
4. 3 high-impact portfolio project ideas that prove job readiness.
5. 4 top recommended YouTube video tutorials with titles, channels, descriptions, and URLs.
6. 4 top YouTube channels dedicated to this field (e.g. freeCodeCamp, TechWorld with Nana, Hussein Nasser, ByteByteGo, NeetCode, Amigoscode, Fireship) with channel names, topics, and URLs.
7. 4 top technical documentation & reference websites (e.g. GeeksforGeeks, MDN Web Docs, DevDocs.io, Official Language/Framework Docs, Baeldung) with descriptions and URLs.
8. 4 popular online courses (on Udemy, Coursera, Pluralsight, edX) with course names, platforms, and URLs.
9. 4 free course platforms (e.g. freeCodeCamp, Coursera Free Audit, MIT OCW, roadmap.sh) with URLs.

Your response MUST be a single valid JSON object matching this schema:
{{
  "learning_path": [
     {{
       "phase": "Phase 1 (Months 1-2): Core Foundations & Architecture",
       "guidance": "Deep dive into language fundamentals, concurrency, memory models, and data structures.",
       "milestones": ["Master core language internals and asynchronous paradigms", "Build RESTful microservices with clean architecture", "Implement relational database modeling & indexing"]
     }},
     {{
       "phase": "Phase 2 (Months 3-4): Distributed Systems & Cloud Infrastructure",
       "guidance": "Transition to microservices, message brokers, and containerization.",
       "milestones": ["Event-driven architectures with Apache Kafka", "Containerization with Docker and Kubernetes cluster deployments", "Cloud deployments on AWS (ECS, RDS, S3) with CI/CD"]
     }},
     {{
       "phase": "Phase 3 (Months 5-6): High-Scale System Design & Leadership",
       "guidance": "Develop architectural mastery, fault tolerance, and high-throughput optimizations.",
       "milestones": ["Design distributed systems handling 50k+ RPS with Redis caching", "Implement Observability with Prometheus, Grafana & OpenTelemetry", "Lead technical RFC reviews and security compliance audits"]
     }}
  ],
  "technologies": ["Core Tech 1", "Framework 2", "Docker", "Kubernetes", "PostgreSQL", "Redis", "Kafka", "AWS", "CI/CD"],
  "certifications": [
     "AWS Certified Solutions Architect - Associate",
     "Certified Kubernetes Application Developer (CKAD)",
     "Oracle / Professional Certified Developer"
  ],
  "projects": [
     {{
       "title": "High-Throughput Distributed Microservices Engine",
       "description": "An event-driven platform utilizing message streaming, caching, and idempotent database transactions.",
       "tech_stack": ["Kafka", "PostgreSQL", "Redis", "Docker", "REST/gRPC"],
       "outcome": "Demonstrates distributed transactional guarantees and event-driven architecture."
     }},
     {{
       "title": "Multi-Tenant Cloud API Gateway with Kubernetes",
       "description": "A secure API gateway managing dynamic routing, rate limiting, and JWT OAuth2 authentication deployed on AWS EKS.",
       "tech_stack": ["Kubernetes", "AWS EKS", "OAuth2/OIDC", "Prometheus", "Docker"],
       "outcome": "Proves cloud infrastructure mastery and production container orchestration."
     }}
  ],
  "youtube_videos": [
     {{
       "title": "Complete Backend & Microservices Masterclass",
       "channel": "freeCodeCamp.org",
       "url": "https://www.youtube.com/results?search_query=backend+microservices+architecture+full+course",
       "description": "Comprehensive tutorial covering distributed architecture and backend systems."
     }},
     {{
       "title": "System Design & Distributed Systems Deep Dive",
       "channel": "Hussein Nasser",
       "url": "https://www.youtube.com/results?search_query=system+design+fundamentals+hussein+nasser",
       "description": "Exploration of database internals, networking, caching, and scalability patterns."
     }},
     {{
       "title": "Kubernetes & Docker for Production",
       "channel": "TechWorld with Nana",
       "url": "https://www.youtube.com/results?search_query=kubernetes+tutorial+techworld+with+nana",
       "description": "Step-by-step containerization, Pods, Deployments, and Helm charts."
     }}
  ],
  "youtube_channels": [
     {{
       "channel_name": "freeCodeCamp.org",
       "focus": "Full-length comprehensive masterclasses on backend, frontend, cloud, and databases.",
       "url": "https://www.youtube.com/@freecodecamp"
     }},
     {{
       "channel_name": "ByteByteGo",
       "focus": "Visual system design, architecture diagrams, and high-scale software engineering.",
       "url": "https://www.youtube.com/@bytebytego"
     }},
     {{
       "channel_name": "TechWorld with Nana",
       "focus": "DevOps, Kubernetes, Docker, CI/CD pipelines, and cloud automation tutorials.",
       "url": "https://www.youtube.com/@TechWorldwithNana"
     }},
     {{
       "channel_name": "Hussein Nasser",
       "focus": "Backend engineering, database engines, networking protocols (HTTP/3, WebSockets, TCP), and performance.",
       "url": "https://www.youtube.com/@hnasr"
     }}
  ],
  "documentation_sites": [
     {{
       "name": "GeeksforGeeks",
       "category": "Algorithms & Concepts",
       "description": "In-depth tutorials, system design patterns, and programming language guides.",
       "url": "https://www.geeksforgeeks.org"
     }},
     {{
       "name": "Official Framework & Language Docs",
       "category": "Official Standards",
       "description": "Authoritative API references, security guidelines, and architectural best practices.",
       "url": "https://devdocs.io"
     }},
     {{
       "name": "MDN Web Docs",
       "category": "Web & API Standards",
       "description": "Complete reference for web protocols, HTTP headers, authentication, and REST APIs.",
       "url": "https://developer.mozilla.org"
     }},
     {{
       "name": "Baeldung / Refactoring Guru",
       "category": "Design Patterns",
       "description": "Step-by-step implementation of Gang of Four and enterprise software design patterns.",
       "url": "https://refactoring.guru"
     }}
  ],
  "popular_courses": [
     {{
       "platform": "Udemy",
       "course_name": "Mastering Microservices with Spring Boot, Docker & Kubernetes",
       "url": "https://www.udemy.com/courses/search/?q=Mastering+Microservices+with+Spring+Boot+Docker+Kubernetes"
     }},
     {{
       "platform": "Coursera",
       "course_name": "Cloud Architecture & Engineering Specialization",
       "url": "https://www.coursera.org/search?query=Cloud+Architecture+Engineering+Specialization"
     }},
     {{
       "platform": "Pluralsight",
       "course_name": "Designing High-Scale Distributed Systems",
       "url": "https://www.pluralsight.com/search?q=Designing+High-Scale+Distributed+Systems"
     }},
     {{
       "platform": "edX",
       "course_name": "Software Engineering for Scalable Services",
       "url": "https://www.edx.org/search?q=Software+Engineering+Scalable+Services"
     }}
  ],
  "free_courses": [
     {{
       "platform": "freeCodeCamp",
       "course_name": "Full Stack & Distributed Systems Curriculum",
       "url": "https://www.freecodecamp.org/news/search/?query=Distributed+Systems"
     }},
     {{
       "platform": "roadmap.sh",
       "course_name": "Interactive Career & Role Developer Roadmap",
       "url": "https://roadmap.sh"
     }},
     {{
       "platform": "edX (Free Audit)",
       "course_name": "Computer Science & Engineering Fundamentals",
       "url": "https://www.edx.org"
     }},
     {{
       "platform": "MIT OpenCourseWare",
       "course_name": "Distributed Computer Systems & Architecture",
       "url": "https://ocw.mit.edu"
     }}
  ]
}}
"""
    try:
        result = call_gemini_api(prompt, response_mime_type="application/json", max_retries=1)
        if not isinstance(result, dict):
            result = {}
    except Exception as e:
        logger.error(f"Career roadmap API failed: {str(e)}")
        result = {}

    learning_path = result.get("learning_path", [])
    technologies = result.get("technologies", [])
    certifications = result.get("certifications", [])
    projects = result.get("projects", [])
    youtube_videos = result.get("youtube_videos", result.get("video_tutorials", []))
    youtube_channels = result.get("youtube_channels", [])
    documentation_sites = result.get("documentation_sites", [])
    popular_courses = result.get("popular_courses", [])
    free_courses = result.get("free_courses", [])

    q_target = urllib.parse.quote_plus(target_role)

    if not learning_path:
        learning_path = [
            {
                "phase": f"Phase 1 (Months 1-2): Core {target_role} Foundations",
                "guidance": "Master fundamental architecture patterns, core tools, and production workflows.",
                "milestones": [
                    f"Master core tools, platforms, and syntax for {target_role}",
                    "Build automated pipelines and modular services",
                    "Implement enterprise security best practices and automated testing"
                ]
            },
            {
                "phase": "Phase 2 (Months 3-4): Scalable Distributed Infrastructure & Cloud",
                "guidance": "Focus on cloud deployment, container orchestration, and asynchronous systems.",
                "milestones": [
                    "Deploy containerized microservices to cloud clusters (Kubernetes / ECS)",
                    "Implement centralized monitoring, logging, and observability",
                    "Automate infrastructure provisioning with Infrastructure-as-Code (IaC)"
                ]
            },
            {
                "phase": "Phase 3 (Months 5-6): High Availability, SRE & Leadership",
                "guidance": "Develop advanced reliability engineering, disaster recovery, and architecture leadership.",
                "milestones": [
                    "Design high-throughput, fault-tolerant production architecture",
                    "Establish SLIs/SLOs, automated failover, and incident management",
                    "Lead technical architecture design reviews and mentorship"
                ]
            }
        ]

    if not technologies:
        role_lower = target_role.lower()
        if "devops" in role_lower or "cloud" in role_lower or "sre" in role_lower:
            technologies = ["Docker", "Kubernetes", "Terraform", "AWS / GCP", "CI/CD (GitHub Actions)", "Prometheus", "Grafana", "Ansible", "Linux", "Python / Bash"]
        elif "python" in role_lower or "django" in role_lower:
            technologies = ["Python 3.12", "Django", "FastAPI", "PostgreSQL", "Redis", "Docker", "Celery", "Kafka", "AWS", "Pytest"]
        elif "java" in role_lower or "spring" in role_lower:
            technologies = ["Java 21", "Spring Boot 3", "Hibernate/JPA", "Kafka", "PostgreSQL", "Redis", "Docker", "Kubernetes", "AWS", "JUnit 5"]
        else:
            technologies = ["Docker", "Kubernetes", "PostgreSQL", "Redis", "REST APIs", "CI/CD", "AWS", "Linux", "Microservices"]

    if not certifications:
        role_lower = target_role.lower()
        if "devops" in role_lower or "cloud" in role_lower or "sre" in role_lower:
            certifications = [
                "AWS Certified DevOps Engineer - Professional",
                "Certified Kubernetes Administrator (CKA)",
                "HashiCorp Certified: Terraform Associate"
            ]
        else:
            certifications = [
                f"AWS Certified Solutions Architect - Associate",
                f"Professional {target_role} Specialist Certification",
                "Certified Kubernetes Application Developer (CKAD)"
            ]

    if not projects:
        projects = [
            {
                "title": f"Enterprise-Scale {target_role} Automation Platform",
                "description": "An end-to-end production platform with automated CI/CD pipelines, container orchestration, and observability.",
                "tech_stack": technologies[:5],
                "outcome": f"Demonstrates production-ready skills and modern engineering practices for {target_role}."
            },
            {
                "title": "High-Availability Distributed Infrastructure Blueprint",
                "description": "Multi-region scalable cloud architecture featuring automated failover, distributed caching, and zero-downtime deployments.",
                "tech_stack": technologies[2:7],
                "outcome": "Proves deep understanding of reliability, security, and scalability."
            }
        ]

    if not youtube_videos:
        youtube_videos = [
            {
                "title": f"Complete {target_role} Bootcamp & Roadmap",
                "channel": "freeCodeCamp.org",
                "url": f"https://www.youtube.com/results?search_query={q_target}+full+course",
                "description": f"Comprehensive step-by-step masterclass covering modern {target_role} tools and best practices."
            },
            {
                "title": f"{target_role} Architecture & Practical Projects",
                "channel": "TechWorld with Nana",
                "url": f"https://www.youtube.com/results?search_query={q_target}+techworld+with+nana",
                "description": "Hands-on implementation of enterprise architectures and pipelines."
            },
            {
                "title": "System Design & DevOps Deep Dive",
                "channel": "ByteByteGo",
                "url": "https://www.youtube.com/@bytebytego",
                "description": "Visual guides to scalable system design and high-load architectures."
            }
        ]

    if not youtube_channels:
        youtube_channels = [
            {
                "channel_name": "TechWorld with Nana",
                "focus": "DevOps, Kubernetes, Docker, CI/CD pipelines, and cloud automation.",
                "url": "https://www.youtube.com/@TechWorldwithNana"
            },
            {
                "channel_name": "freeCodeCamp.org",
                "focus": "Full-length comprehensive engineering courses and tutorials.",
                "url": "https://www.youtube.com/@freecodecamp"
            },
            {
                "channel_name": "ByteByteGo",
                "focus": "System design, cloud architecture diagrams, and scalability.",
                "url": "https://www.youtube.com/@bytebytego"
            },
            {
                "channel_name": "Hussein Nasser",
                "focus": "Backend engineering, database engines, networking protocols, and performance.",
                "url": "https://www.youtube.com/@hnasr"
            }
        ]

    if not documentation_sites:
        documentation_sites = [
            {
                "name": f"Official {target_role} Documentation",
                "category": "Official Guides",
                "description": "Official documentation, API references, and security best practices.",
                "url": "https://devdocs.io"
            },
            {
                "name": "GeeksforGeeks",
                "category": "Core Concepts",
                "description": "In-depth tutorials, system architecture patterns, and algorithms.",
                "url": "https://www.geeksforgeeks.org"
            },
            {
                "name": "roadmap.sh",
                "category": "Role Roadmaps",
                "description": "Community-driven visual developer roadmaps and skill guides.",
                "url": "https://roadmap.sh"
            }
        ]

    if not popular_courses:
        popular_courses = [
            {
                "platform": "Udemy",
                "course_name": f"{target_role} Masterclass: Zero to Hero",
                "url": f"https://www.udemy.com/courses/search/?q={q_target}"
            },
            {
                "platform": "Coursera",
                "course_name": f"Cloud & {target_role} Professional Certificate",
                "url": f"https://www.coursera.org/search?query={q_target}"
            },
            {
                "platform": "Pluralsight",
                "course_name": f"Advanced {target_role} Skill Path",
                "url": f"https://www.pluralsight.com/search?q={q_target}"
            }
        ]

    if not free_courses:
        free_courses = [
            {
                "platform": "freeCodeCamp",
                "course_name": f"Learn {target_role} - Full Tutorial for Beginners",
                "url": f"https://www.freecodecamp.org/news/search/?query={q_target}"
            },
            {
                "platform": "roadmap.sh",
                "course_name": f"Interactive {target_role} Developer Roadmap",
                "url": "https://roadmap.sh"
            },
            {
                "platform": "edX (Free Audit)",
                "course_name": f"Introduction to {target_role}",
                "url": f"https://www.edx.org/search?q={q_target}"
            },
            {
                "platform": "MIT OpenCourseWare",
                "course_name": f"Software Engineering & {target_role} Systems",
                "url": f"https://www.google.com/search?q=site:ocw.mit.edu+{q_target}"
            }
        ]

    milestones_payload = {
        "projects": projects,
        "youtube_videos": youtube_videos,
        "youtube_channels": youtube_channels,
        "documentation_sites": documentation_sites,
        "popular_courses": popular_courses,
        "free_courses": free_courses
    }
    
    roadmap = CareerRoadmap.objects.create(
        user=user,
        current_role=current_role or "Entry Level",
        target_role=target_role,
        learning_path=learning_path,
        technologies=technologies,
        certifications=certifications,
        milestones=milestones_payload
    )
    return roadmap



class CareerRoadmapService:
    @staticmethod
    def generate_roadmap(user, current_role: str, target_role: str):
        from analysis.services import generate_career_roadmap
        return generate_career_roadmap(user, current_role, target_role)


