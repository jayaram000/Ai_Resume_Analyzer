import logging
from typing import Dict, Any
import fitz  # PyMuPDF
import pdfplumber

logger = logging.getLogger(__name__)


class PDFParsingService:
    """
    Multi-stage hybrid PDF parser implementing PyMuPDF primary text extraction
    with pdfplumber column-boundary reordering per SAD Section 2.
    """

    @staticmethod
    def extract_text(file_path: str) -> Dict[str, Any]:
        """
        Extracts structured text from a PDF file.
        Returns dict with:
        - raw_text: str
        - char_count: int
        - is_scanned: bool
        - parser_used: str ('pymupdf' or 'pdfplumber')
        """
        raw_text = ""
        is_scanned = False
        parser_used = "pymupdf"

        try:
            # Stage 1: PyMuPDF Fast Text Extraction
            doc = fitz.open(file_path)
            for page in doc:
                text = page.get_text("text")
                if text:
                    raw_text += text + "\n"
            doc.close()

            raw_text = raw_text.strip()
            char_count = len(raw_text)

            # Stage 2: Scanned PDF Detection (SAD Section 2: char_count < 100)
            if char_count < 100:
                logger.warning(f"PDF '{file_path}' has low char count ({char_count}). Flagging as scanned.")
                is_scanned = True
                # In future tiers, route to Tesseract / Document AI OCR.

            # Stage 3: Two-Column Reordering via pdfplumber if text exists
            else:
                try:
                    reordered_text = PDFParsingService._pdfplumber_column_sort(file_path)
                    if reordered_text and len(reordered_text) >= (char_count * 0.8):
                        raw_text = reordered_text
                        parser_used = "pdfplumber_layout_aware"
                except Exception as plumber_err:
                    logger.warning(f"pdfplumber layout sorting skipped: {str(plumber_err)}. Using PyMuPDF output.")

            return {
                "raw_text": raw_text,
                "char_count": len(raw_text),
                "is_scanned": is_scanned,
                "parser_used": parser_used,
            }

        except Exception as e:
            logger.error(f"Error parsing PDF file at '{file_path}': {str(e)}", exc_info=True)
            raise RuntimeError(f"Failed to parse PDF document: {str(e)}") from e

    @staticmethod
    def _pdfplumber_column_sort(file_path: str) -> str:
        """
        Sorts text blocks by column boundary algorithm specified in SAD Section 2:
        Block Order = Page * 100000 + floor(X0 / Column Boundary) * 10000 + rounded(Y0)
        Groups words on the same line and preserves newlines.
        """
        extracted_blocks = []
        with pdfplumber.open(file_path) as pdf:
            for page_idx, page in enumerate(pdf.pages):
                page_width = page.width or 600
                col_boundary = page_width / 2.0  # Split down center

                words = page.extract_words(keep_blank_chars=True)
                if not words:
                    continue

                for word in words:
                    x0 = word.get("x0", 0)
                    top = word.get("top", 0)
                    col_index = 0 if x0 < col_boundary else 1
                    
                    # Round top to nearest 3 points to group words on same visual line
                    top_rounded = round(top / 3.0) * 3.0
                    
                    block_order = (page_idx * 100000) + (col_index * 10000) + top_rounded
                    extracted_blocks.append((block_order, x0, word.get("text", "")))

        # Sort by block_order (page, col, line), then by x0 (left-to-right)
        extracted_blocks.sort(key=lambda item: (item[0], item[1]))
        
        lines = []
        current_line = []
        last_block = None
        
        for block_order, x0, word_text in extracted_blocks:
            if last_block is not None and block_order != last_block:
                lines.append(" ".join(current_line))
                current_line = []
                
            current_line.append(word_text)
            last_block = block_order
            
        if current_line:
            lines.append(" ".join(current_line))
            
        return "\n".join(lines).strip()
