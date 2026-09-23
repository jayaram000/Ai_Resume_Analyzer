import logging
from resumes.models import Resume

logger = logging.getLogger(__name__)

def _get_resume_text(resume: Resume) -> str:
    """Helper to extract text from resume parse history, raw text, or file."""
    parsed = getattr(resume, "parsed_content", None)
    if parsed and parsed.extracted_text and len(parsed.extracted_text.strip()) > 50:
        return parsed.extracted_text
    if hasattr(resume, "raw_text") and resume.raw_text and len(resume.raw_text.strip()) > 50:
        return resume.raw_text
    try:
        if resume.file:
            ext = resume.file.name.split('.')[-1].lower()
            with resume.file.open('rb') as f:
                if ext == 'pdf':
                    from common.utils import extract_text_from_pdf
                    return extract_text_from_pdf(f)
                elif ext == 'docx':
                    from common.utils import extract_text_from_docx
                    return extract_text_from_docx(f)
    except Exception as e:
        logger.error(f"Failed direct text extraction for resume {resume.id}: {str(e)}")
    return ""
