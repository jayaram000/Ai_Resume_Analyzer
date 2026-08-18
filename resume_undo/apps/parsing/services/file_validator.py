import os
import logging
from typing import Tuple
from django.core.exceptions import ValidationError

logger = logging.getLogger(__name__)

MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024  # 5 MB limit per SAD Section 12
ALLOWED_EXTENSIONS = {".pdf", ".docx"}
ALLOWED_MIME_TYPES = {
    "application/pdf",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
}


class FileValidationService:
    """
    Production-grade validation service for uploaded resumes.
    Strictly validates file size, extensions, and byte magic signatures.
    """

    @staticmethod
    def validate_resume_file(uploaded_file) -> Tuple[bool, str]:
        """
        Validates an uploaded file.
        Raises ValidationError if any security or constraint check fails.
        """
        if not uploaded_file:
            raise ValidationError("No file was uploaded.")

        # 1. File Size Check
        if uploaded_file.size > MAX_FILE_SIZE_BYTES:
            logger.warning(
                f"File upload rejected: Size {uploaded_file.size} bytes exceeds max allowed limit of {MAX_FILE_SIZE_BYTES} bytes."
            )
            raise ValidationError(
                f"File size exceeds maximum limit of {MAX_FILE_SIZE_BYTES // (1024 * 1024)}MB."
            )

        # 2. Extension Check
        filename = uploaded_file.name
        ext = os.path.splitext(filename)[1].lower()
        if ext not in ALLOWED_EXTENSIONS:
            logger.warning(f"File upload rejected: Disallowed extension '{ext}'.")
            raise ValidationError(
                f"Unsupported file extension '{ext}'. Only .pdf and .docx files are accepted."
            )

        # 3. Magic Header Byte Check
        # Read the first 1024 bytes for inspection
        header_bytes = uploaded_file.read(1024)
        uploaded_file.seek(0)  # Reset stream position immediately

        if ext == ".pdf":
            if not header_bytes.startswith(b"%PDF-"):
                logger.error(f"File validation failed: File '{filename}' claims to be PDF but lacks %PDF- magic signature.")
                raise ValidationError("Invalid PDF file structure or corrupt file magic header.")
        elif ext == ".docx":
            # DOCX files are zip archives starting with 'PK\x03\x04'
            if not header_bytes.startswith(b"PK\x03\x04"):
                logger.error(f"File validation failed: File '{filename}' claims to be DOCX but lacks PK zip magic signature.")
                raise ValidationError("Invalid DOCX file structure or corrupt file magic header.")

        logger.info(f"File validation succeeded for '{filename}' ({ext}, {uploaded_file.size} bytes).")
        return True, ext[1:]  # returns ('pdf' or 'docx')
