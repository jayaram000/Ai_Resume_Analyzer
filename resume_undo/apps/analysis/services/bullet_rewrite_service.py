import json
import logging
from common.gemini import call_gemini_api
from resumes.models import Resume
from analysis.models import ResumeImprovement
from ._common import _get_resume_text

logger = logging.getLogger(__name__)

def generate_resume_improvements(resume: Resume) -> ResumeImprovement:
    text = _get_resume_text(resume)
    parsed = getattr(resume, "parsed_content", None)
    
    candidate_bullets = []
    if parsed and parsed.extracted_experience:
        for exp in parsed.extracted_experience:
            if isinstance(exp, dict):
                for resp in exp.get("responsibilities", []):
                    if resp and str(resp).strip():
                        candidate_bullets.append(str(resp).strip())

    bullets_formatted = "\n".join([f"- {b}" for b in candidate_bullets])

    parsed_ctx = ""
    if parsed:
        parsed_ctx = f"""
Candidate Parsed Structure:
- Name: {parsed.name}
- Extracted Skills: {json.dumps(parsed.extracted_skills)}
- Extracted Education: {json.dumps(parsed.extracted_education)}
- Extracted Experience: {json.dumps(parsed.extracted_experience)}
"""

    prompt = f"""
Act as an elite Executive Recruiter and ATS-Resume Writer.
Review the following resume and provide a deeply comprehensive, professional ATS-friendly critique.
Focus on impact, action verbs, quantifiable metrics, keyword optimization, and structural completeness.

CRITICAL RULES:
1. DO NOT fabricate past experiences.
2. DO NOT criticize or mention truncated text or ellipses if the degree/education is intact in candidate structure. Focus on genuine career critique.
3. Identify top strengths, weaknesses, bullet point optimizations (mapping old text to STAR method rewrites), and professional summary advice.
4. FOR `better_bullet_points`:
   - The JSON keys MUST BE an EXACT word-for-word copy of one of the candidate's existing bullets from the list below. DO NOT rephrase, summarize, or alter the key string in any way.
   - The JSON value MUST be the improved, high-impact STAR method rewrite of that exact bullet point.

Candidate's EXACT existing bullet points to optimize:
{bullets_formatted if bullets_formatted else text[:3000]}

Your response MUST be a JSON object matching this schema exactly:
{{
  "strengths": ["Detailed strength 1", "Detailed strength 2"],
  "weaknesses": ["Detailed weakness 1", "Detailed weakness 2"],
  "better_bullet_points": {{
     "Exact existing bullet point copied word-for-word from above": "Improved bullet point using strong action verbs and metrics"
  }},
  "summary_suggestions": "A compelling, keyword-rich professional summary",
  "missing_sections": []
}}

{parsed_ctx}

Resume text:
{text[:6000]}
"""
    try:
        result = call_gemini_api(prompt, response_mime_type="application/json", max_retries=1)
    except Exception as e:
        logger.error(f"Resume improvements API failed: {str(e)}")
        result = {
            "strengths": ["Strong modern technical skill set", "Clear multi-domain project exposure"],
            "weaknesses": ["Lack of quantifiable metrics and KPIs", "Generic verb phrasing across experience section"],
            "better_bullet_points": {},
            "summary_suggestions": "Tailor your professional summary to highlight measurable achievements and leadership roles.",
            "missing_sections": []
        }
    
    weaknesses_list = result.get("weaknesses", [])
    # Clean up any hallucinated truncated/ellipses text from weaknesses
    cleaned_weaknesses = [
        w for w in weaknesses_list 
        if "truncated" not in w.lower() and "..." not in w and "lovely pr" not in w.lower()
    ]
    if not cleaned_weaknesses:
        cleaned_weaknesses = ["Lack of quantifiable metrics (KPIs) in experience bullet points."]

    improvement = ResumeImprovement.objects.create(
        resume=resume,
        strengths=result.get("strengths", []),
        weaknesses=cleaned_weaknesses,
        better_bullet_points=result.get("better_bullet_points", {}),
        summary_suggestions=result.get("summary_suggestions", ""),
        missing_sections=result.get("missing_sections", [])
    )
    return improvement



def build_resume_markdown(resume: Resume) -> str:
    """
    Builds a clean Markdown representation of the resume from parsed structured data.
    NO AI is used — this preserves the exact original content without hallucination.
    """
    parsed = getattr(resume, "parsed_content", None)
    if not parsed:
        # Fallback to raw text if no parsed content
        return _get_resume_text(resume)

    lines = []

    # --- Header ---
    if parsed.name:
        lines.append(f"# {parsed.name}")

    contact_parts = []
    if parsed.email:
        contact_parts.append(parsed.email)
    if parsed.phone:
        contact_parts.append(parsed.phone)
    if parsed.location:
        contact_parts.append(parsed.location)
    if contact_parts:
        lines.append(" | ".join(contact_parts))
    lines.append("")

    # --- Professional Summary: extract from raw text ---
    raw_text = parsed.extracted_text or _get_resume_text(resume)
    summary = _extract_section_text(raw_text, ["PROFESSIONAL SUMMARY", "SUMMARY", "PROFILE", "OBJECTIVE", "CAREER SUMMARY"])
    if summary:
        lines.append("## PROFESSIONAL SUMMARY")
        lines.append(summary.strip())
        lines.append("")

    # --- Skills ---
    if parsed.extracted_skills and len(parsed.extracted_skills) > 0:
        # Try to extract structured skills sections from raw text first
        skills_section = _extract_section_text(raw_text, ["SKILLS", "TECHNICAL SKILLS", "CORE COMPETENCIES"])
        if skills_section and len(skills_section.strip()) > 30:
            lines.append("## SKILLS")
            # Preserve the original formatting from the raw text
            for skill_line in skills_section.strip().split("\n"):
                sl = skill_line.strip()
                if sl:
                    if not sl.startswith("- ") and not sl.startswith("* ") and not sl.startswith("•"):
                        lines.append(f"* {sl}")
                    else:
                        lines.append(f"* {sl.lstrip('-*• ').strip()}")
        else:
            lines.append("## SKILLS")
            for skill in parsed.extracted_skills:
                lines.append(f"* {skill}")
        lines.append("")

    # --- Professional Experience ---
    if parsed.extracted_experience and len(parsed.extracted_experience) > 0:
        lines.append("## PROFESSIONAL EXPERIENCE")
        lines.append("")
        for exp in parsed.extracted_experience:
            if isinstance(exp, dict):
                role = exp.get("role", exp.get("title", ""))
                company = exp.get("company", "")
                duration = exp.get("duration", exp.get("dates", ""))

                header_parts = [p for p in [role, company] if p]
                lines.append(f"### {' | '.join(header_parts)}")
                if duration:
                    lines.append(f"*{duration}*")

                responsibilities = exp.get("responsibilities", exp.get("bullets", []))
                if isinstance(responsibilities, list):
                    for resp in responsibilities:
                        if resp and str(resp).strip():
                            lines.append(f"* {str(resp).strip()}")
                elif responsibilities:
                    lines.append(f"* {str(responsibilities).strip()}")
                lines.append("")
            elif isinstance(exp, str):
                lines.append(f"* {exp}")
                lines.append("")

    # --- Projects ---
    if parsed.extracted_projects and len(parsed.extracted_projects) > 0:
        lines.append("## PROJECTS")
        lines.append("")
        for proj in parsed.extracted_projects:
            if isinstance(proj, dict):
                title = proj.get("title", proj.get("name", ""))
                description = proj.get("description", "")
                technologies = proj.get("technologies", proj.get("tech_stack", []))

                if title:
                    lines.append(f"### {title}")
                if description:
                    lines.append(description.strip())
                if technologies:
                    if isinstance(technologies, list):
                        lines.append(f"**Tech Stack:** {', '.join(technologies)}")
                    else:
                        lines.append(f"**Tech Stack:** {technologies}")
                lines.append("")
            elif isinstance(proj, str):
                lines.append(f"* {proj}")
                lines.append("")

    # --- Education ---
    if parsed.extracted_education and len(parsed.extracted_education) > 0:
        lines.append("## EDUCATION")
        lines.append("")
        for edu in parsed.extracted_education:
            if isinstance(edu, dict):
                degree = edu.get("degree", "")
                field = edu.get("field", "")
                school = edu.get("school", edu.get("institution", ""))
                year = edu.get("year", edu.get("dates", ""))

                degree_text = f"{degree} in {field}" if field and degree else (degree or field)
                if degree_text:
                    lines.append(f"### {degree_text}")

                meta_parts = []
                if year:
                    meta_parts.append(str(year))
                if school:
                    meta_parts.append(school)
                if meta_parts:
                    lines.append(f"*{' | '.join(meta_parts)}*")
                lines.append("")
            elif isinstance(edu, str):
                lines.append(f"* {edu}")
                lines.append("")

    # --- Certifications ---
    if parsed.extracted_certifications and len(parsed.extracted_certifications) > 0:
        lines.append("## CERTIFICATIONS")
        for cert in parsed.extracted_certifications:
            lines.append(f"* {cert}")
        lines.append("")

    # --- Languages: try to extract from raw text ---
    languages_section = _extract_section_text(raw_text, ["LANGUAGES", "LANGUAGES & ADDITIONAL"])
    if languages_section and len(languages_section.strip()) > 3:
        lines.append("## LANGUAGES")
        lines.append(languages_section.strip())
        lines.append("")

    result = "\n".join(lines)
    # If parsed data was too sparse, fall back to raw extracted text
    if len(result.strip()) < 100:
        return raw_text
    return result


def _extract_section_text(text: str, section_names: list) -> str:
    """
    Extract text belonging to a specific section from raw resume text.
    Looks for section headers and captures text until the next section header.
    """
    if not text:
        return ""

    # Common section headers in resumes
    all_sections = [
        "PROFESSIONAL SUMMARY", "SUMMARY", "PROFILE", "OBJECTIVE", "CAREER SUMMARY",
        "SKILLS", "TECHNICAL SKILLS", "CORE COMPETENCIES",
        "PROFESSIONAL EXPERIENCE", "WORK EXPERIENCE", "EXPERIENCE",
        "PROJECTS", "EDUCATION", "CERTIFICATIONS", "LANGUAGES",
        "LANGUAGES & ADDITIONAL", "ADDITIONAL INFO", "ACHIEVEMENTS",
    ]

    lines = text.split("\n")
    capturing = False
    captured = []

    for line in lines:
        stripped = line.strip().upper()
        # Check if this line is a section header
        is_section_header = any(stripped == s or stripped.startswith(s + ":") or stripped.startswith(s + " ") for s in all_sections)

        if is_section_header:
            if any(stripped == s or stripped.startswith(s + ":") or stripped.startswith(s + " ") for s in [sn.upper() for sn in section_names]):
                capturing = True
                continue
            elif capturing:
                # We've hit the next section, stop capturing
                break
        elif capturing:
            captured.append(line)

    return "\n".join(captured).strip()




def generate_improved_resume_content(resume: Resume) -> str:
    """
    Returns the resume content as Markdown.
    Uses saved tailored_content if available (user has already accepted suggestions),
    otherwise builds markdown from the parsed resume data.
    NO AI hallucination — preserves exact original content.
    """
    from analysis.models import ResumeImprovement

    # Check if user has already saved tailored content (via accepted suggestions)
    improvement = ResumeImprovement.objects.filter(resume=resume).order_by("-created_at").first()
    if improvement and improvement.tailored_content and len(improvement.tailored_content.strip()) > 150:
        return improvement.tailored_content

    # Build markdown from actual parsed resume data (no AI)
    markdown = build_resume_markdown(resume)

    # Save it so next time it's instant
    if improvement and markdown and len(markdown.strip()) > 100:
        improvement.tailored_content = markdown
        improvement.save(update_fields=['tailored_content'])

    return markdown


