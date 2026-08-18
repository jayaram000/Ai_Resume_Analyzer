import re
import logging
from typing import List, Dict, Any

logger = logging.getLogger(__name__)

SECTION_PATTERNS = {
    "SUMMARY": r"^(summary|professional summary|executive summary|about me|profile|overview)\b",
    "EXPERIENCE": r"^(experience|work experience|employment history|professional experience|work history|career history)\b",
    "EDUCATION": r"^(education|academic background|education and qualifications|qualifications|academic history)\b",
    "SKILLS": r"^(skills|technical skills|core competencies|areas of expertise|technologies|tools)\b",
    "PROJECTS": r"^(projects|key projects|personal projects|technical projects|featured projects)\b",
    "CERTIFICATIONS": r"^(certifications|licenses|courses|professional certifications|training)\b",
}


class SectionDetectionService:
    """
    Deterministic rule-based Section Detection Engine per SAD Section 1 & 2.
    Parses extracted raw text into structured section blocks with ordinal positions.
    """

    @staticmethod
    def detect_sections(raw_text: str) -> List[Dict[str, Any]]:
        """
        Segments raw text into structured sections.
        Returns list of dicts:
        [
            {"section_type": "SUMMARY", "content": "...", "ordinal_position": 1},
            {"section_type": "EXPERIENCE", "content": "...", "ordinal_position": 2},
            ...
        ]
        """
        lines = raw_text.split("\n")
        sections: List[Dict[str, Any]] = []

        current_type = "SUMMARY"
        current_content_lines: List[str] = []
        position = 1

        for line in lines:
            trimmed = line.strip()
            if not trimmed:
                continue

            # Check if line matches a known header pattern (short length & matches regex)
            detected_header = SectionDetectionService._match_header(trimmed)

            if detected_header:
                # Save previous section if it has content
                if current_content_lines:
                    sections.append({
                        "section_type": current_type,
                        "content": "\n".join(current_content_lines).strip(),
                        "ordinal_position": position,
                    })
                    position += 1
                    current_content_lines = []

                current_type = detected_header
            else:
                current_content_lines.append(trimmed)

        # Append final remaining section
        if current_content_lines:
            sections.append({
                "section_type": current_type,
                "content": "\n".join(current_content_lines).strip(),
                "ordinal_position": position,
            })

        logger.info(f"Section detector extracted {len(sections)} sections from resume text.")
        return sections

    @staticmethod
    def _match_header(line: str) -> str:
        """
        Matches a single line against known section header patterns.
        Headers are usually <= 6 words long and match known section patterns.
        """
        clean_line = line.lower().strip(":#- ")
        if len(clean_line.split()) > 6:
            return ""

        for section_type, pattern in SECTION_PATTERNS.items():
            if re.search(pattern, clean_line):
                return section_type

        return ""
