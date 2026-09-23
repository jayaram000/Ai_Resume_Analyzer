from unittest.mock import patch, MagicMock
from django.test import TestCase
from django.contrib.auth import get_user_model
from resumes.models import Resume, ParsedResume
from analysis.services import (
    ATSScoringService,
    JDMatchingService,
    PositionAnalysisService,
    generate_ats_analysis,
    generate_resume_improvements,
    build_resume_markdown,
    generate_skill_gap,
    generate_career_roadmap,
    generate_interview_prep,
    generate_cover_letter,
    generate_project_recommendation,
    CareerScoreService,
)

User = get_user_model()

class AnalysisServicesUnitTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email="testdev@career.ai",
            username="testdev",
            password="testpassword123"
        )
        self.resume = Resume.objects.create(
            user=self.user,
            title="Senior Fullstack Resume"
        )
        self.parsed = ParsedResume.objects.create(
            resume=self.resume,
            extracted_text="Experienced Software Engineer with Python, Django, Flutter, Docker, AWS, and PostgreSQL.",
            extracted_skills=["Python", "Django", "Flutter", "PostgreSQL", "Docker", "AWS", "Git", "REST APIs"],
            extracted_experience=[{"title": "Senior Developer", "company": "Tech Corp", "years": 4}],
            extracted_education=[{"degree": "B.Tech Computer Science"}],
            extracted_projects=[{"title": "AI Copilot Platform"}],
            extracted_certifications=["AWS Certified Solutions Architect"]
        )

    def test_ats_scoring_service_deterministic(self):
        """Test ATSScoringService computes deterministic, non-random scores."""
        scores = ATSScoringService.calculate_ats_score(self.resume)
        self.assertIsInstance(scores, dict)
        self.assertIn("ats_score", scores)
        self.assertGreaterEqual(scores["ats_score"], 0)
        self.assertLessEqual(scores["ats_score"], 100)
        self.assertIn("keyword_score", scores)
        self.assertIn("skills_score", scores)
        self.assertIn("completeness_score", scores)
        self.assertIn("suggestions", scores)

    def test_build_resume_markdown(self):
        """Test build_resume_markdown builds structured markdown without external calls."""
        md = build_resume_markdown(self.resume)
        self.assertIn("Python", md)
        self.assertIn("Senior Developer", md)

    def test_generate_ats_analysis(self):
        """Test generate_ats_analysis creates an ATSAnalysis instance mathematically."""
        analysis = generate_ats_analysis(self.resume)
        self.assertIsNotNone(analysis.id)
        self.assertGreater(analysis.ats_score, 0)
        self.assertEqual(analysis.resume, self.resume)

    @patch("analysis.services.bullet_rewrite_service.call_gemini_api")
    def test_generate_resume_improvements_with_mock(self, mock_gemini):
        """Test bullet rewrite service improvement generation."""
        mock_gemini.return_value = {
            "strengths": ["Clear technical stack", "Good progression"],
            "weaknesses": ["Needs more impact metrics"],
            "better_bullet_points": {
                "Engineered scalable backend": "Architected high-throughput REST APIs handling 50k req/min"
            },
            "summary_suggestions": "Add cloud specialization focus",
            "missing_sections": []
        }
        improvement = generate_resume_improvements(self.resume)
        self.assertIsNotNone(improvement.id)
        self.assertEqual(len(improvement.strengths), 2)
        self.assertIn("Engineered scalable backend", improvement.better_bullet_points)

    @patch("analysis.services.roadmap_service.call_gemini_api")
    def test_generate_career_roadmap_with_mock(self, mock_gemini):
        """Test career roadmap generation with mocked Gemini."""
        mock_gemini.return_value = {
            "target_role": "Cloud Architect",
            "learning_path": [{"phase": 1, "topic": "AWS Solutions"}],
            "technologies": ["Terraform", "Kubernetes", "AWS"],
            "certifications": ["AWS Solutions Architect Professional"],
            "milestones": [{"title": "Cloud Architecture", "duration": "4 weeks"}]
        }
        roadmap = generate_career_roadmap(self.user, "Software Engineer", "Cloud Architect")
        self.assertIsNotNone(roadmap.id)
        self.assertEqual(roadmap.target_role, "Cloud Architect")

    @patch("analysis.services.cover_letter_service.call_gemini_api")
    def test_generate_cover_letter_with_mock(self, mock_gemini):
        """Test cover letter generation with mocked Gemini."""
        mock_gemini.return_value = {
            "content": "Dear Hiring Manager, I am excited to apply for the position...",
            "tone": "Professional"
        }
        cover_letter = generate_cover_letter(
            self.resume,
            job_title="Senior Python Engineer",
            company_name="InnovateTech",
            job_description="We need an experienced Python and Django developer."
        )
        self.assertIsNotNone(cover_letter.id)
        self.assertIn("Hiring Manager", cover_letter.content)

    @patch("analysis.services.interview_service.call_gemini_api")
    def test_generate_interview_prep_with_mock(self, mock_gemini):
        """Test interview prep generation with mocked Gemini."""
        mock_gemini.return_value = {
            "technical_questions": [{"question": "Explain Django ORM select_related vs prefetch_related", "sample_answer": "select_related performs a SQL join..."}],
            "behavioral_questions": [{"question": "Describe a difficult conflict", "star_approach": "Situation: ..."}]
        }
        prep = generate_interview_prep(self.resume, "Backend Architect")
        self.assertIsNotNone(prep.id)
        self.assertEqual(len(prep.technical_questions), 1)
