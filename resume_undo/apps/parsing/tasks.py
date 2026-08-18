import logging
from celery import shared_task
from django.db import transaction

logger = logging.getLogger(__name__)


@shared_task(queue="parsing_queue", name="apps.parsing.tasks.extract_resume_text_task")
def extract_resume_text_task(resume_id: str):
    """
    Celery background task bound to 'parsing_queue' per SAD Section 9.
    Executes parsing, section detection, and updates the database asynchronously.
    """
    from resumes.models import Resume, ResumeSection
    from parsing.services.pdf_parser import PDFParsingService
    from parsing.services.docx_parser import DOCXParsingService
    from parsing.services.section_detector import SectionDetectionService

    logger.info(f"Starting async background parsing task for Resume ID: {resume_id}")

    try:
        resume = Resume.objects.get(id=resume_id)
        file_path = resume.file.path
        file_ext = resume.file_type.lower()

        # 1. Execute Parser
        if file_ext == "pdf":
            parsed_data = PDFParsingService.extract_text(file_path)
        elif file_ext == "docx":
            parsed_data = DOCXParsingService.extract_text(file_path)
        else:
            raise ValueError(f"Unsupported file type for parsing: '{file_ext}'")

        raw_text = parsed_data["raw_text"]

        # 2. Detect Sections
        detected_sections = SectionDetectionService.detect_sections(raw_text)

        # 3. Transactional Database Update
        with transaction.atomic():
            resume.raw_text = raw_text
            resume.is_parsed = True
            resume.save()

            # Delete old sections if re-parsing
            ResumeSection.objects.filter(resume=resume).delete()

            # Create new section records
            sections_to_create = [
                ResumeSection(
                    resume=resume,
                    section_type=sec["section_type"],
                    content=sec["content"],
                    ordinal_position=sec["ordinal_position"],
                )
                for sec in detected_sections
            ]
            ResumeSection.objects.bulk_create(sections_to_create)

        # 4. Trigger ParsedResume structured extraction & ATS scoring
        try:
            from resumes.services import parse_and_save_resume
            from analysis.services import generate_ats_analysis, generate_resume_improvements
            parse_and_save_resume(resume)
            generate_ats_analysis(resume)
            generate_resume_improvements(resume)
        except Exception as str_err:
            logger.warning(f"Structured extraction/ATS scoring for Resume {resume_id} failed: {str_err}")

        logger.info(f"Successfully finished parsing Resume ID: {resume_id} ({len(sections_to_create)} sections created).")
        return {
            "status": "success",
            "resume_id": str(resume_id),
            "char_count": len(raw_text),
            "sections_count": len(sections_to_create),
        }

    except Exception as e:
        logger.error(f"Background parsing task failed for Resume ID {resume_id}: {str(e)}", exc_info=True)
        return {
            "status": "error",
            "resume_id": str(resume_id),
            "error": str(e),
        }
