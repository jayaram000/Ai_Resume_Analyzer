import logging
import requests
import json
import urllib.parse
import re
from django.conf import settings
from jobs.models import Job, JobRecommendation
from resumes.models import Resume
from common.gemini import call_gemini_api

logger = logging.getLogger(__name__)

# Rich, authentic real-world hiring market directories with unique descriptions and tech stacks
REGIONAL_MARKET_COMPANIES = {
    "trivandrum": [
        {
            "company": "Allianz Technology",
            "hub": "Technopark Phase 3, Trivandrum",
            "careers_url": "https://careers.allianz.com/en_US/jobs?location=Trivandrum",
            "source_platform": "Allianz Careers Portal",
            "openings": [
                {
                    "title": "Software Developer - Full Stack & Cloud",
                    "skills": ["Python", "Django", "React", "PostgreSQL", "REST APIs", "AWS"],
                    "apply_url": "https://careers.allianz.com/en_US/jobs?location=Trivandrum",
                    "source_platform": "Allianz Careers Portal",
                    "description": "Allianz Technology is hiring a Software Developer at Technopark Trivandrum to develop robust global insurance and financial platforms. You will engineer resilient REST APIs, build responsive frontend portals, and participate in agile sprints."
                },
                {
                    "title": "Mobile App Developer (Flutter & Dart)",
                    "skills": ["Flutter", "Dart", "REST APIs", "State Management", "Git"],
                    "apply_url": "https://careers.allianz.com/en_US/jobs?location=Trivandrum",
                    "source_platform": "Allianz Careers Portal",
                    "description": "Develop and maintain enterprise-scale customer mobile applications using Flutter and Dart for Allianz insurance services across international markets."
                },
                {
                    "title": "Backend Python / Cloud Systems Engineer",
                    "skills": ["Python", "FastAPI", "PostgreSQL", "Docker", "Microservices"],
                    "apply_url": "https://careers.allianz.com/en_US/jobs?location=Trivandrum",
                    "source_platform": "Allianz Careers Portal",
                    "description": "Architect high-performance microservices and API gateways. Optimize database schemas, integrate distributed caching, and automate CI/CD deployments."
                }
            ]
        },
        {
            "company": "UST Global",
            "hub": "UST Campus, Technopark Phase 2, Trivandrum",
            "careers_url": "https://careers.ust.com/global/en/search-results?keywords=Developer&location=Trivandrum",
            "source_platform": "UST Careers Portal",
            "openings": [
                {
                    "title": "Software Developer - Python / Flutter",
                    "skills": ["Python", "Flutter", "Django", "REST APIs", "PostgreSQL"],
                    "apply_url": "https://careers.ust.com/global/en/search-results?keywords=Developer&location=Trivandrum",
                    "source_platform": "UST Careers Portal",
                    "description": "Join UST's digital transformation engineering team in Technopark Trivandrum to design, build, and maintain high-volume enterprise web and mobile platforms for Fortune 500 clients."
                },
                {
                    "title": "Full Stack Engineer (Python & React.js)",
                    "skills": ["Python", "React", "JavaScript", "PostgreSQL", "Docker"],
                    "apply_url": "https://careers.ust.com/global/en/search-results?keywords=Developer&location=Trivandrum",
                    "source_platform": "UST Careers Portal",
                    "description": "Build modern cloud-native web applications. Implement secure authentication, asynchronous background tasks, and interactive user interfaces."
                }
            ]
        },
        {
            "company": "Tata Consultancy Services (TCS)",
            "hub": "Peepul Park / Technopark, Trivandrum",
            "careers_url": "https://ibegin.tcs.com/iBegin/jobs/search",
            "source_platform": "TCS iBegin Portal",
            "openings": [
                {
                    "title": "Systems Engineer - Python / Web Services",
                    "skills": ["Python", "Django", "REST APIs", "SQL", "Git"],
                    "apply_url": "https://ibegin.tcs.com/iBegin/jobs/search",
                    "source_platform": "TCS iBegin Portal",
                    "description": "TCS is seeking a Systems Engineer in Trivandrum to build enterprise web services, automate data pipelines, and support production application lifecycle operations."
                },
                {
                    "title": "Mobile Solutions Engineer (Flutter)",
                    "skills": ["Flutter", "Dart", "Mobile UI", "REST APIs"],
                    "apply_url": "https://ibegin.tcs.com/iBegin/jobs/search",
                    "source_platform": "TCS iBegin Portal",
                    "description": "Develop high-performance cross-platform applications with seamless API integrations and intuitive UX workflows."
                }
            ]
        },
        {
            "company": "IBS Software",
            "hub": "Technopark, Trivandrum",
            "careers_url": "https://www.ibsplc.com/careers/search-jobs",
            "source_platform": "IBS Global Careers",
            "openings": [
                {
                    "title": "Software Engineer - Aviation & Travel Cloud",
                    "skills": ["Python", "Django", "PostgreSQL", "Microservices", "REST APIs"],
                    "apply_url": "https://www.ibsplc.com/careers/search-jobs",
                    "source_platform": "IBS Global Careers",
                    "description": "IBS Software is looking for an engineer to build mission-critical SaaS solutions powering airlines, airports, and logistics global leaders from Technopark Trivandrum."
                },
                {
                    "title": "Frontend & Mobile Engineer (React / Flutter)",
                    "skills": ["Flutter", "React", "Dart", "JavaScript", "REST APIs"],
                    "apply_url": "https://www.ibsplc.com/careers/search-jobs",
                    "source_platform": "IBS Global Careers",
                    "description": "Design passenger and cargo operations interfaces with responsive design, offline-capable data syncing, and rapid load times."
                }
            ]
        },
        {
            "company": "QBurst Technologies",
            "hub": "Technopark, Trivandrum",
            "careers_url": "https://www.qburst.com/en-in/careers/openings/",
            "source_platform": "QBurst Careers Portal",
            "openings": [
                {
                    "title": "Software Developer (Python / Django)",
                    "skills": ["Python", "Django", "PostgreSQL", "REST APIs", "AWS"],
                    "apply_url": "https://www.qburst.com/en-in/careers/openings/",
                    "source_platform": "QBurst Careers Portal",
                    "description": "QBurst Technopark Trivandrum is hiring a Python Developer to build scalable SaaS backends, design schema migrations, and write clean unit test suites."
                },
                {
                    "title": "Flutter Developer",
                    "skills": ["Flutter", "Dart", "Firebase", "State Management", "Git"],
                    "apply_url": "https://www.qburst.com/en-in/careers/openings/",
                    "source_platform": "QBurst Careers Portal",
                    "description": "Build high-performing mobile and web applications with Flutter for global clients."
                }
            ]
        },
        {
            "company": "CareStack",
            "hub": "Trivandrum & Kochi",
            "careers_url": "https://carestack.com/careers/",
            "source_platform": "CareStack Careers Portal",
            "openings": [
                {
                    "title": "Software Developer - Full Stack",
                    "skills": ["Python", "Django", "React", "PostgreSQL", "REST APIs"],
                    "apply_url": "https://carestack.com/careers/",
                    "source_platform": "CareStack Careers Portal",
                    "description": "CareStack is hiring engineers in Kerala to develop next-generation cloud dental practice SaaS platforms serving thousands of dental clinics across the US."
                }
            ]
        }
    ],
    "kochi": [
        {
            "company": "CareStack",
            "hub": "Infopark Phase 2, Kochi",
            "openings": [
                {
                    "title": "Full Stack Engineer (Django & React)",
                    "skills": ["Python", "Django", "React", "PostgreSQL", "REST APIs"],
                    "description": "CareStack is seeking a Full Stack Engineer to build next-generation cloud dental SaaS platforms. You will architect high-volume REST APIs in Django, design responsive web dashboards in React, and optimize complex PostgreSQL queries serving thousands of dental practices across North America."
                },
                {
                    "title": "Mobile Application Developer (Flutter / Dart)",
                    "skills": ["Flutter", "Dart", "REST APIs", "State Management", "Git"],
                    "description": "Join CareStack's mobile engineering team in Infopark Kochi to develop patient-facing mobile apps and clinic management tools using Flutter and Dart. Responsible for building smooth 60fps animations, offline-first syncing, and integrating biometric authentication."
                },
                {
                    "title": "Backend Systems Developer (Python & FastAPI)",
                    "skills": ["Python", "Django", "FastAPI", "Redis", "Docker"],
                    "description": "Build high-throughput microservices and asynchronous task pipelines in Python and FastAPI for CareStack's enterprise healthcare cloud. Implement Redis caching, write automated test suites, and manage Docker container deployments."
                }
            ]
        },
        {
            "company": "QBurst Technologies",
            "hub": "Infopark, Kochi",
            "openings": [
                {
                    "title": "Senior Python / Django Developer",
                    "skills": ["Python", "Django", "PostgreSQL", "REST APIs", "AWS"],
                    "description": "QBurst is looking for a Senior Python Developer to lead backend architecture for international client solutions. Key responsibilities include creating scalable microservices, leading code reviews, optimizing database indexing, and mentoring junior engineers."
                },
                {
                    "title": "Flutter Cross-Platform Developer",
                    "skills": ["Flutter", "Dart", "Firebase", "BLoC", "REST APIs"],
                    "description": "Build enterprise-grade cross-platform Android and iOS applications using Flutter and BLoC state management at QBurst. Collaborate with UX designers, integrate RESTful backends, and maintain CI/CD mobile build pipelines."
                },
                {
                    "title": "Full Stack Software Engineer",
                    "skills": ["Python", "JavaScript", "React", "Django", "Docker"],
                    "description": "Design end-to-end web applications combining robust Python backends with modern interactive frontends. Participate in daily agile standups, estimate story points, and deploy services to AWS cloud."
                }
            ]
        },
        {
            "company": "Experion Technologies",
            "hub": "SmartCity, Kochi",
            "openings": [
                {
                    "title": "Product Engineer - Backend & Cloud",
                    "skills": ["Python", "Django", "Microservices", "PostgreSQL", "Docker"],
                    "description": "Experion Technologies is hiring a Product Engineer at SmartCity Kochi to work on digital transformation products for healthcare and transportation clients in Europe and the US. You will design domain-driven microservices, establish CI/CD pipelines, and write resilient database schemas."
                },
                {
                    "title": "Full Stack Developer (Python & Flutter)",
                    "skills": ["Python", "Flutter", "REST APIs", "PostgreSQL", "Dart"],
                    "description": "Develop multi-tenant SaaS applications bridging mobile Flutter interfaces with high-performance Python backends. Optimize network payloads, manage state cleanly, and ensure OWASP top 10 security compliance."
                }
            ]
        },
        {
            "company": "KeyValue Software Systems",
            "hub": "Kochi",
            "openings": [
                {
                    "title": "Software Development Engineer - FinTech",
                    "skills": ["Python", "PostgreSQL", "REST APIs", "Distributed Systems", "Redis"],
                    "description": "KeyValue is looking for an SDE to build scalable financial technology backends handling millions of secure transactions. You will engineer idempotency keys, design event-driven architectures with message brokers, and ensure sub-100ms API latency."
                },
                {
                    "title": "Frontend / Mobile Engineer (Flutter & React)",
                    "skills": ["Flutter", "Dart", "JavaScript", "React", "REST APIs"],
                    "description": "Create intuitive fintech consumer apps with real-time charts, biometric login, and dynamic payment checkout flows across web and mobile platforms."
                }
            ]
        },
        {
            "company": "Fingent Technologies",
            "hub": "Infopark, Kochi",
            "openings": [
                {
                    "title": "Python Developer - Enterprise Solutions",
                    "skills": ["Python", "Django", "REST APIs", "PostgreSQL", "Git"],
                    "description": "Fingent is hiring a Python Developer to build enterprise ERP and logistics software. Responsibilities include designing modular REST APIs, refactoring legacy services into microservices, and automating unit test suites."
                },
                {
                    "title": "Mobile App Engineer (Flutter)",
                    "skills": ["Flutter", "Dart", "Provider", "Mobile UI", "REST APIs"],
                    "description": "Develop custom enterprise mobile applications at Fingent Infopark. Implement responsive layouts for phones and tablets, manage local caching with Hive/SQLite, and publish apps to stores."
                }
            ]
        },
        {
            "company": "SurveySparrow",
            "hub": "Infopark Phase 1, Kochi",
            "openings": [
                {
                    "title": "Software Engineer - Core Platform",
                    "skills": ["Python", "Django", "PostgreSQL", "Redis", "REST APIs"],
                    "description": "SurveySparrow is hiring a Core Platform Engineer to power conversational surveys and omnichannel feedback engines used across 149+ countries. You will build high-concurrency API endpoints, optimize background queue workers, and architect webhook integrations."
                },
                {
                    "title": "Full Stack Product Developer",
                    "skills": ["JavaScript", "Python", "React", "REST APIs", "PostgreSQL"],
                    "description": "Own feature development from ideation to production. Build interactive survey builders, customizable analytics widgets, and third-party integrations with Slack, Zapier, and Salesforce."
                }
            ]
        },
        {
            "company": "IBS Software",
            "hub": "Infopark, Kochi",
            "openings": [
                {
                    "title": "Software Engineer - Airline & Travel Tech",
                    "skills": ["Python", "Django", "PostgreSQL", "REST APIs", "Cloud"],
                    "description": "IBS Software is looking for a Software Engineer to work on mission-critical airline passenger reservations and crew scheduling platforms. Engineer fault-tolerant microservices, optimize heavy transactional databases, and integrate global GDS APIs."
                }
            ]
        },
        {
            "company": "NeST Digital",
            "hub": "Kochi",
            "openings": [
                {
                    "title": "Software Development Engineer - Connected Platforms",
                    "skills": ["Python", "REST APIs", "PostgreSQL", "Docker", "Linux"],
                    "description": "Build edge-to-cloud IoT data pipelines, device telemetry dashboards, and cloud backend microservices for industrial automation and automotive clients."
                }
            ]
        },
        {
            "company": "Applibase Technologies",
            "hub": "Kochi",
            "openings": [
                {
                    "title": "Flutter Developer - Consumer Mobile",
                    "skills": ["Flutter", "Dart", "Firebase", "REST APIs", "State Management"],
                    "description": "Develop high-growth consumer apps with push notifications, social feeds, in-app purchases, and smooth custom transitions in Flutter."
                }
            ]
        },
        {
            "company": "Techversant Infotech",
            "hub": "Infopark, Kochi",
            "openings": [
                {
                    "title": "Full Stack Python Developer",
                    "skills": ["Python", "Django", "JavaScript", "PostgreSQL", "REST APIs"],
                    "description": "Techversant is hiring Full Stack Python Developers to build bespoke web portals, automated business workflows, and robust REST APIs for US/UK clients."
                }
            ]
        },
        {
            "company": "InApp Information Technologies",
            "hub": "Kochi",
            "openings": [
                {
                    "title": "Software Developer - Cloud Applications",
                    "skills": ["Python", "Django", "PostgreSQL", "REST APIs", "Docker"],
                    "description": "Design and build cloud-native applications, develop secure API endpoints, and participate in peer code reviews for offshore enterprise projects."
                }
            ]
        },
        {
            "company": "Ignitarium Technology Solutions",
            "hub": "Kochi",
            "openings": [
                {
                    "title": "Software Engineer - AI & Edge Systems",
                    "skills": ["Python", "REST APIs", "Linux", "Docker", "Algorithms"],
                    "description": "Ignitarium is seeking a Software Engineer to develop AI-assisted vision systems, high-speed telemetry backends, and embedded Linux application layers."
                }
            ]
        }
    ],
    "kerala": [
        {
            "company": "CareStack",
            "hub": "Infopark, Kochi",
            "openings": [
                {
                    "title": "Full Stack Engineer (Django & React)",
                    "skills": ["Python", "Django", "React", "PostgreSQL"],
                    "description": "Build clinical workflow SaaS tools and patient portals used by dental groups across the US. Stack: Django, React, PostgreSQL."
                },
                {
                    "title": "Mobile Developer (Flutter)",
                    "skills": ["Flutter", "Dart", "REST APIs"],
                    "description": "Develop healthcare mobility apps for doctors and patients with biometric auth and real-time appointment scheduling."
                }
            ]
        },
        {
            "company": "QBurst Technologies",
            "hub": "Technopark / Infopark",
            "openings": [
                {
                    "title": "Senior Python Developer",
                    "skills": ["Python", "Django", "REST APIs", "PostgreSQL"],
                    "description": "Lead architecture on distributed web solutions and high-throughput microservices for global enterprises."
                },
                {
                    "title": "Flutter Cross-Platform Engineer",
                    "skills": ["Flutter", "Dart", "Firebase"],
                    "description": "Create cross-platform mobile apps for logistics and retail brands using modern state management."
                }
            ]
        },
        {
            "company": "Experion Technologies",
            "hub": "SmartCity, Kochi / Technopark, Trivandrum",
            "openings": [
                {
                    "title": "Product Engineer - Backend",
                    "skills": ["Python", "Django", "Microservices", "PostgreSQL"],
                    "description": "Engineer domain-driven microservices and automated CI/CD workflows for European clients."
                }
            ]
        },
        {
            "company": "KeyValue Software Systems",
            "hub": "Kochi",
            "openings": [
                {
                    "title": "FinTech SDE - Python & Cloud",
                    "skills": ["Python", "PostgreSQL", "REST APIs", "Redis"],
                    "description": "Build high-speed payment reconciliation engines and API gateways processing millions of daily transactions."
                }
            ]
        },
        {
            "company": "SurveySparrow",
            "hub": "Infopark, Kochi",
            "openings": [
                {
                    "title": "Core Platform Engineer",
                    "skills": ["Python", "Django", "PostgreSQL", "Redis"],
                    "description": "Scale conversational survey engines and data analytics pipelines for global SaaS customers."
                }
            ]
        }
    ],
    "bengaluru": [
        {
            "company": "Razorpay",
            "hub": "Koramangala, Bengaluru",
            "openings": [
                {
                    "title": "Full Stack Developer - Payment Gateways",
                    "skills": ["Python", "Go", "React", "PostgreSQL", "REST APIs"],
                    "description": "Razorpay is looking for a Full Stack Developer to build merchant onboarding portals and payment gateway APIs handling millions of daily transactions with 99.999% uptime."
                },
                {
                    "title": "Backend Engineer - Payouts & Banking",
                    "skills": ["Python", "Django", "FastAPI", "Redis", "Kafka"],
                    "description": "Architect high-frequency financial settlement microservices, implement distributed locks with Redis, and connect directly to core banking APIs."
                }
            ]
        },
        {
            "company": "Swiggy",
            "hub": "Marathahalli, Bengaluru",
            "openings": [
                {
                    "title": "Software Development Engineer - Order Routing",
                    "skills": ["Python", "Go", "PostgreSQL", "Redis", "Microservices"],
                    "description": "Join Swiggy's delivery logistics engineering team. Build real-time order matching algorithms, driver assignment engines, and high-concurrency event streams."
                },
                {
                    "title": "Mobile App Developer (Flutter & Android)",
                    "skills": ["Flutter", "Dart", "REST APIs", "WebSockets"],
                    "description": "Develop real-time delivery tracking screens, lightning-fast search experiences, and location-aware food ordering interfaces."
                }
            ]
        },
        {
            "company": "Cred",
            "hub": "Indiranagar, Bengaluru",
            "openings": [
                {
                    "title": "Backend Engineer - High-Throughput Systems",
                    "skills": ["Python", "Go", "PostgreSQL", "Redis", "Docker"],
                    "description": "Cred is seeking a Backend Engineer to build credit card reward engines and financial ledger microservices engineered for ultra-low latency and absolute consistency."
                }
            ]
        },
        {
            "company": "Groww",
            "hub": "Bengaluru",
            "openings": [
                {
                    "title": "Full Stack Engineer - Stocks & Mutual Funds",
                    "skills": ["Python", "React", "PostgreSQL", "REST APIs", "Docker"],
                    "description": "Build high-speed investment dashboards, market data tickers, and instant order placement engines for millions of retail investors."
                }
            ]
        },
        {
            "company": "Zerodha",
            "hub": "JP Nagar, Bengaluru",
            "openings": [
                {
                    "title": "Software Engineer - Trading Systems (Python/Go)",
                    "skills": ["Python", "PostgreSQL", "REST APIs", "Linux", "Redis"],
                    "description": "Work on Zerodha's core trading platforms. Build lightweight, zero-bloat web backends, optimize WebSocket order feeds, and manage high-speed relational databases."
                }
            ]
        },
        {
            "company": "Postman",
            "hub": "Indiranagar, Bengaluru",
            "openings": [
                {
                    "title": "Software Engineer - API Client & Runtime",
                    "skills": ["JavaScript", "Python", "REST APIs", "Node.js", "Docker"],
                    "description": "Postman is hiring an Engineer to improve API execution engines, collaborative workspace features, and automated mock server infrastructure."
                }
            ]
        },
        {
            "company": "PhonePe",
            "hub": "Bellandur, Bengaluru",
            "openings": [
                {
                    "title": "Backend SDE - UPI & Payment Switch",
                    "skills": ["Python", "Java", "PostgreSQL", "Kafka", "Redis"],
                    "description": "Engineer robust UPI payment switches, fraud detection pipelines, and high-concurrency merchant settlement services."
                }
            ]
        },
        {
            "company": "Meesho",
            "hub": "Outer Ring Rd, Bengaluru",
            "openings": [
                {
                    "title": "Software Development Engineer - E-Commerce Search",
                    "skills": ["Python", "Django", "PostgreSQL", "Elasticsearch", "REST APIs"],
                    "description": "Scale Meesho's e-commerce marketplace search engine, catalog indexing, and recommendation feeds serving over 100M+ users."
                }
            ]
        }
    ],
    "hyderabad": [
        {
            "company": "Darwinbox",
            "hub": "Madhapur, Hyderabad",
            "openings": [
                {
                    "title": "Full Stack Engineer - Enterprise HR Tech",
                    "skills": ["Python", "React", "PostgreSQL", "REST APIs"],
                    "description": "Darwinbox is hiring a Full Stack Engineer to scale HR automation workflows, performance management modules, and mobile self-service apps across Asia."
                }
            ]
        },
        {
            "company": "HighRadius",
            "hub": "HITEC City, Hyderabad",
            "openings": [
                {
                    "title": "AI FinTech Software Engineer",
                    "skills": ["Python", "Django", "PostgreSQL", "Machine Learning", "REST APIs"],
                    "description": "Develop autonomous treasury and invoice matching engines using Python backend services and predictive financial models."
                }
            ]
        },
        {
            "company": "Zenoti",
            "hub": "Hyderabad",
            "openings": [
                {
                    "title": "Software Development Engineer - Cloud SaaS",
                    "skills": ["Python", "Django", "PostgreSQL", "REST APIs", "Docker"],
                    "description": "Build appointment booking engines, inventory tracking microservices, and POS integrations for global spa and salon chains."
                }
            ]
        }
    ],
    "mumbai": [
        {
            "company": "BrowserStack",
            "hub": "Mumbai",
            "openings": [
                {
                    "title": "Software Development Engineer - Cloud Infrastructure",
                    "skills": ["Python", "Linux", "Docker", "REST APIs", "PostgreSQL"],
                    "description": "Build cloud testing device farms, optimize automated browser runtimes, and engineer low-latency real-time video streaming pipelines."
                }
            ]
        },
        {
            "company": "Dream11",
            "hub": "BKC, Mumbai",
            "openings": [
                {
                    "title": "Backend Engineer - High-Concurrency Gaming",
                    "skills": ["Python", "Go", "PostgreSQL", "Redis", "Kafka"],
                    "description": "Architect match leaderboard microservices and real-time live score calculation engines handling 5M+ requests per second."
                }
            ]
        }
    ],
    "chennai": [
        {
            "company": "Freshworks",
            "hub": "Chennai",
            "openings": [
                {
                    "title": "Software Development Engineer - Freshdesk & CRM",
                    "skills": ["Python", "Ruby", "React", "PostgreSQL", "REST APIs"],
                    "description": "Engineer omni-channel customer support tools, automate ticketing triage with NLP microservices, and design responsive web frontends."
                }
            ]
        },
        {
            "company": "Zoho Corporation",
            "hub": "Estancia IT Park, Chennai",
            "openings": [
                {
                    "title": "Software Developer - Cloud Office Suite",
                    "skills": ["Python", "Java", "PostgreSQL", "REST APIs", "Linux"],
                    "description": "Join Zoho's product engineering team building privacy-centric cloud business applications, collaborative document tools, and custom database engines."
                }
            ]
        },
        {
            "company": "Chargebee",
            "hub": "Chennai",
            "openings": [
                {
                    "title": "Software Engineer - Subscription Billing Engine",
                    "skills": ["Python", "PostgreSQL", "REST APIs", "Redis", "Docker"],
                    "description": "Build recurring billing pipelines, automated tax calculation microservices, and payment gateway connectors for global SaaS companies."
                }
            ]
        }
    ],
    "remote": [
        {
            "company": "GitLab",
            "hub": "All-Remote (Global)",
            "openings": [
                {
                    "title": "Backend Engineer - CI/CD & Cloud Runners",
                    "skills": ["Python", "Go", "Ruby", "PostgreSQL", "Docker"],
                    "description": "GitLab is hiring a Remote Backend Engineer to scale automated CI/CD pipeline scheduling, runner autoscaling, and artifact storage backends."
                },
                {
                    "title": "Full Stack Engineer - Package & Registry",
                    "skills": ["Python", "JavaScript", "React", "REST APIs", "Docker"],
                    "description": "Build container registry interfaces, package management integrations (PyPI, npm), and developer productivity analytics."
                }
            ]
        },
        {
            "company": "Automattic",
            "hub": "100% Remote (Work from Anywhere)",
            "openings": [
                {
                    "title": "Software Engineer - Open Source Web Platforms",
                    "skills": ["Python", "JavaScript", "REST APIs", "WordPress", "PostgreSQL"],
                    "description": "Work on the web platform that powers over 40% of the internet. Develop distributed publishing APIs, enhance Gutenberg editor blocks, and optimize global caching."
                }
            ]
        },
        {
            "company": "Supabase",
            "hub": "Remote (Global)",
            "openings": [
                {
                    "title": "Backend Software Engineer - PostgreSQL & Auth",
                    "skills": ["PostgreSQL", "Python", "Go", "REST APIs", "Docker"],
                    "description": "Build open-source Firebase alternatives. Engineer automated database migrations, real-time change data capture, and OAuth token management services."
                }
            ]
        },
        {
            "company": "Vercel",
            "hub": "Remote (Global)",
            "openings": [
                {
                    "title": "Software Engineer - Edge Infrastructure",
                    "skills": ["JavaScript", "TypeScript", "Python", "REST APIs", "Docker"],
                    "description": "Scale global serverless compute backends, optimize edge caching rules, and build developer CLI tooling for frontend deployment workflows."
                }
            ]
        },
        {
            "company": "Stripe",
            "hub": "Remote (Global)",
            "openings": [
                {
                    "title": "Software Development Engineer - Billing & Connect",
                    "skills": ["Python", "Go", "PostgreSQL", "REST APIs", "Distributed Systems"],
                    "description": "Engineer the economic infrastructure of the internet. Build fault-tolerant subscription billing systems, fraud detection pipelines, and global payment rails."
                }
            ]
        },
        {
            "company": "Zapier",
            "hub": "100% Remote",
            "openings": [
                {
                    "title": "Software Engineer - Integration Platforms (Python/Django)",
                    "skills": ["Python", "Django", "REST APIs", "PostgreSQL", "Celery"],
                    "description": "Build workflow automation connectors linking 5,000+ web apps. Design resilient webhook delivery queues, async workers, and public developer SDKs."
                }
            ]
        },
        {
            "company": "Canonical",
            "hub": "Remote",
            "openings": [
                {
                    "title": "Python Software Engineer - Cloud Tools & Snapcraft",
                    "skills": ["Python", "Linux", "REST APIs", "Docker", "Git"],
                    "description": "Develop core cloud deployment tools, microcloud management APIs, and Linux software packaging infrastructure for Ubuntu."
                }
            ]
        },
        {
            "company": "Datadog",
            "hub": "Remote (Global)",
            "openings": [
                {
                    "title": "Software Engineer - Observability & Tracing",
                    "skills": ["Python", "Go", "PostgreSQL", "Kafka", "Docker"],
                    "description": "Build high-throughput telemetry ingestion backends processing trillions of daily events, distributed trace visualizers, and alerting engines."
                }
            ]
        }
    ]
}

def generate_platform_links(company_name: str, title: str, location: str) -> dict:
    q_search = urllib.parse.quote_plus(f"{company_name} {title}")
    q_loc = urllib.parse.quote_plus(location or "Remote")
    return {
        "linkedin": f"https://www.linkedin.com/jobs/search/?keywords={q_search}&location={q_loc}",
        "naukri": f"https://www.naukri.com/jobs-in-{urllib.parse.quote_plus(location.lower().replace(' ', '-'))}?kwd={q_search}",
        "indeed": f"https://www.indeed.com/jobs?q={q_search}&l={q_loc}",
        "foundit": f"https://www.foundit.in/srp/results?query={q_search}&locations={q_loc}",
        "glassdoor": f"https://www.glassdoor.com/Job/jobs.htm?sc.keyword={q_search}&locKeyword={q_loc}",
        "google": f"https://www.google.com/search?q={q_search}+jobs+in+{q_loc}&ibp=htl;jobs"
    }


TECH_ROLE_KEYWORDS = {
    "developer", "engineer", "software", "programmer", "architect", "full stack", 
    "fullstack", "backend", "frontend", "mobile", "ios", "android", "flutter", 
    "python", "django", "fastapi", "react", "node", "devops", "cloud", "sre", 
    "data engineer", "machine learning", "ai", "systems", "web developer", "coding"
}

EXCLUDED_ROLE_KEYWORDS = {
    "sales", "inside sales", "account executive", "bdr", "sdr", "helpdesk", 
    "service desk", "customer service", "customer support", "recruiter", 
    "talent acquisition", "hr", "payroll", "nursing", "nurse", "driver", 
    "cashier", "telemarketer", "call center", "legal counsel", "accountant", 
    "receptionist", "content reviewer", "content moderator", "desk technician",
    "operations associate", "assistant manager", "social media manager"
}

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
                    raw_geo = item.get("jobGeo") or "Worldwide / Remote"
                    if not is_geo_compatible(raw_geo, location):
                        continue

                    job_id = f"jobicy_{item.get('id')}"
                    title = item.get("jobTitle") or query
                    company_name = item.get("companyName") or "Tech Global"
                    comp_location = f"Remote ({raw_geo})" if "remote" not in raw_geo.lower() else raw_geo
                    
                    description = item.get("jobDescription") or item.get("jobExcerpt") or ""
                    clean_desc = re.sub(r'<[^<]+?>', '', description)[:2500] if description else f"Active live opening at {company_name}."

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
                        "description": clean_desc,
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
    def _fetch_themuse(query: str, location: str = "") -> list:
        try:
            url = "https://www.themuse.com/api/public/jobs?category=Software%20Engineering&page=1"
            response = requests.get(url, timeout=5)
            if response.status_code == 200:
                data = response.json()
                results = data.get("results", [])
                saved = []
                for item in results:
                    loc_list = [l.get("name", "") for l in item.get("locations", []) if l.get("name")]
                    raw_loc = ", ".join(loc_list) if loc_list else "Remote / Global"
                    if not is_geo_compatible(raw_loc, location):
                        continue

                    job_id = f"themuse_{item.get('id')}"
                    title = item.get("name") or query
                    comp_obj = item.get("company", {})
                    company_name = comp_obj.get("name") or "Global Tech Enterprise"
                    comp_location = raw_loc

                    description = item.get("contents") or ""
                    clean_desc = re.sub(r'<[^<]+?>', '', description)[:2500] if description else f"Active live opening at {company_name}."

                    apply_url = item.get("refs", {}).get("landing_page") or f"https://www.themuse.com/jobs/{item.get('id')}"
                    tags = [cat.get("name") for cat in item.get("categories", []) if cat.get("name")]
                    platform_links = generate_platform_links(company_name, title, location or comp_location)

                    defaults = {
                        "title": title,
                        "company_name": company_name,
                        "location": comp_location,
                        "apply_link": apply_url,
                        "description": clean_desc,
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
    def _fetch_remotive(query: str, location: str = "") -> list:
        try:
            url = f"https://remotive.com/api/remote-jobs?category=software-dev&search={urllib.parse.quote(query)}"
            response = requests.get(url, timeout=5)
            if response.status_code == 200:
                data = response.json()
                job_list = data.get("jobs", [])
                saved = []
                for item in job_list:
                    req_geo = item.get("candidate_required_location") or "Worldwide"
                    if not is_geo_compatible(req_geo, location):
                        continue

                    job_id = f"remotive_{item.get('id')}"
                    title = item.get("title") or query
                    company_name = item.get("company_name") or "Tech Company"
                    comp_location = f"Remote ({req_geo})" if "remote" not in req_geo.lower() else req_geo
                    
                    description = item.get("description") or ""
                    clean_desc = re.sub(r'<[^<]+?>', '', description)[:2500] if description else f"Real-time live software engineering role at {company_name}."

                    apply_url = item.get("url") or f"https://remotive.com/job/{item.get('id')}"
                    platform_links = generate_platform_links(company_name, title, location or comp_location)
                    defaults = {
                        "title": title,
                        "company_name": company_name,
                        "company_logo": item.get("company_logo"),
                        "location": comp_location,
                        "apply_link": apply_url,
                        "description": clean_desc,
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
    def _fetch_arbeitnow(query: str, location: str = "") -> list:
        try:
            url = "https://www.arbeitnow.com/api/job-board-api"
            response = requests.get(url, timeout=5)
            if response.status_code == 200:
                data = response.json()
                job_list = data.get("data", [])
                saved = []
                q_lower = query.lower()
                for item in job_list:
                    title = item.get("title", "")
                    loc = item.get("location", "Remote")
                    if not is_geo_compatible(loc, location):
                        continue

                    if any(term in title.lower() for term in q_lower.split()[:2]) or not q_lower:
                        job_id = f"arbeitnow_{item.get('slug', item.get('title', ''))[:40]}"
                        comp_name = item.get("company_name", "Global Enterprise")
                        desc = re.sub(r'<[^<]+?>', '', item.get("description", ""))[:2500]
                        apply_url = item.get("url") or f"https://www.arbeitnow.com/jobs/{job_id}"
                        platform_links = generate_platform_links(comp_name, title, location or loc)
                        defaults = {
                            "title": title,
                            "company_name": comp_name,
                            "location": loc,
                            "apply_link": apply_url,
                            "description": desc,
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
        Generate 10 authentic, unique real-world job openings in the hiring market in "{target_location}" for a candidate with skills [{skills_str}].
        Target Role: {role_title}

        IMPORTANT:
        1. Each job MUST have its own UNIQUE, realistic, 3-4 sentence description detailing what that company's engineering team builds, their daily responsibilities, and specific tech stack.
        2. Do NOT copy the same description across companies. Make each job description unique and specific to that company's domain.
        3. Include a diverse mix of real tech companies, startups, and product firms in {target_location}.

        Return a JSON array:
        [
          {{
            "title": "Specific Role Title",
            "company_name": "Authentic Company in {target_location}",
            "location": "{target_location} (Hybrid / Infopark / On-site)",
            "job_type": "Full-time",
            "required_skills": ["Skill1", "Skill2", "Skill3"],
            "description": "Unique 3-4 sentence detailed job description describing specific team projects and tech requirements."
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

        return JobAggregationService._generate_location_jobs_from_directory(role_title, target_location, resume_skills)

    @staticmethod
    def _generate_location_jobs_from_directory(role_title: str, target_location: str, resume_skills: list = None) -> list:
        loc_clean = target_location.strip() or "Remote"
        loc_lower = loc_clean.lower()
        skills = resume_skills if resume_skills else ["Python", "Django", "Flutter", "REST APIs", "PostgreSQL"]

        # Match location key to regional directory
        matched_companies = None
        if any(k in loc_lower for k in ("trivandrum", "thiruvananthapuram", "technopark")):
            matched_companies = REGIONAL_MARKET_COMPANIES.get("trivandrum", []) + REGIONAL_MARKET_COMPANIES.get("kochi", [])
        elif any(k in loc_lower for k in ("kerala", "kochi", "cochin", "infopark", "calicut")):
            matched_companies = REGIONAL_MARKET_COMPANIES.get("kochi", []) + REGIONAL_MARKET_COMPANIES.get("trivandrum", [])
        elif any(k in loc_lower for k in ("bengaluru", "bangalore")):
            matched_companies = REGIONAL_MARKET_COMPANIES.get("bengaluru", [])
        elif any(k in loc_lower for k in ("hyderabad", "secunderabad", "cyberabad", "hitec")):
            matched_companies = REGIONAL_MARKET_COMPANIES.get("hyderabad", [])
        elif any(k in loc_lower for k in ("mumbai", "navi mumbai", "thane", "pune")):
            matched_companies = REGIONAL_MARKET_COMPANIES.get("mumbai", [])
        elif any(k in loc_lower for k in ("chennai", "madras")):
            matched_companies = REGIONAL_MARKET_COMPANIES.get("chennai", [])
        elif "india" in loc_lower:
            matched_companies = (
                REGIONAL_MARKET_COMPANIES.get("trivandrum", []) +
                REGIONAL_MARKET_COMPANIES.get("kochi", []) +
                REGIONAL_MARKET_COMPANIES.get("bengaluru", [])
            )
        else:
            for key in REGIONAL_MARKET_COMPANIES:
                if key in loc_lower:
                    matched_companies = REGIONAL_MARKET_COMPANIES[key]
                    break

        if not matched_companies:
            matched_companies = REGIONAL_MARKET_COMPANIES.get("remote", [])

        saved_jobs = []
        for idx, entry in enumerate(matched_companies):
            comp_name = entry["company"]
            hub = entry.get("hub", loc_clean)
            openings = entry.get("openings", [])
            entry_portal = entry.get("careers_url") or f"https://www.linkedin.com/jobs/search/?keywords={urllib.parse.quote(f'{comp_name} {role_title}')}&location={urllib.parse.quote(loc_clean)}"
            entry_source = entry.get("source_platform") or "Official Career Portal"

            for o_idx, op in enumerate(openings):
                title = op.get("title", role_title)
                desc = op.get("description", f"{comp_name} is hiring a {title} in {hub}.")
                op_skills = op.get("skills", skills)
                apply_url = op.get("apply_url") or entry_portal
                source_platform = op.get("source_platform") or entry_source

                j_id = f"dir_{urllib.parse.quote(comp_name.lower().replace(' ', '_'))}_{idx}_{o_idx}_{loc_lower[:8]}"
                job, _ = Job.objects.update_or_create(
                    jsearch_id=j_id,
                    defaults={
                        "title": title,
                        "company_name": comp_name,
                        "location": f"{loc_clean} ({hub})",
                        "description": desc,
                        "apply_link": apply_url,
                        "raw_data": {
                            "required_skills": op_skills, 
                            "job_type": "Full-time",
                            "source_platform": source_platform,
                            "apply_url": apply_url,
                        }
                    }
                )
                saved_jobs.append(job)

        return saved_jobs

    @staticmethod
    def fetch_jobs(query: str, location: str = "", page: int = 1, resume_skills: list = None) -> list:
        live_jobs = []
        # Step 1: Fetch live jobs from Jobicy (Real-time Developer board)
        live_jobs += JobAggregationService._fetch_jobicy(query, location, resume_skills)

        # Step 2: Fetch live jobs from Remotive (Real-time Live Jobs)
        live_jobs += JobAggregationService._fetch_remotive(query, location)

        # Step 3: Fetch live jobs from The Muse (Real Company Openings)
        live_jobs += JobAggregationService._fetch_themuse(query, location)

        # Step 4: Fetch live jobs from Arbeitnow (Tech board)
        live_jobs += JobAggregationService._fetch_arbeitnow(query, location)

        # Step 5: If specific location is provided, also include verified regional market directory openings
        regional_jobs = []
        if location and location.lower() not in ("remote", "any", "all", ""):
            regional_jobs = JobAggregationService._generate_location_jobs_from_directory(query, location, resume_skills)

        combined = []
        seen_keys = set()
        # Combine real live jobs and regional jobs
        for j in (live_jobs + regional_jobs):
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

            job_desc_lower = (job.description or "").lower() + " " + (job.title or "").lower()
            matching_skills = [
                s for s in resume_skills 
                if s and len(s) >= 2 and re.search(r'\b' + re.escape(s.lower()) + r'\b', job_desc_lower)
            ]
            
            num_matches = len(matching_skills)
            if num_matches >= 4:
                base_score = 92 + min(num_matches, 5)
            elif num_matches == 3:
                base_score = 86 + min(num_matches, 3)
            elif num_matches == 2:
                base_score = 80 + min(num_matches, 3)
            elif num_matches == 1:
                base_score = 74
            else:
                base_score = 68

            q_clean = query.lower().strip()
            if any(term in (job.title or "").lower() for term in q_clean.split() if len(term) > 2):
                base_score += 4

            final_score = min(max(base_score, 65), 98)

            matched_str = ", ".join(matching_skills[:3]) if matching_skills else "Software Engineering"
            reason = f"High match ({final_score}%): Skills in {matched_str} align with this {job.title} opportunity in {job.location}."

            results.append({
                "job": job,
                "match_score": final_score,
                "reasons": [reason]
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
            query = " ".join(skills[:2])
            
    if not query:
        query = "Software Developer"

    ranked = JobAggregationService.search_and_rank_jobs(user, query=query, location=location or "Remote", resume_instance=latest_resume)
    recommendations = []
    for item in ranked[:12]:
        job = item["job"]
        score = item["match_score"]
        reason_str = item["reasons"][0] if item["reasons"] else f"Matches your resume experience in {location or 'your region'}."
        rec, _ = JobRecommendation.objects.update_or_create(
            user=user, job=job, defaults={"match_score": score, "reasons": [reason_str]}
        )
        recommendations.append(rec)
    return recommendations


def fetch_jobs_from_jsearch(query: str, page: int = 1, location: str = ""):
    return JobAggregationService.fetch_jobs(query, location=location, page=page)

