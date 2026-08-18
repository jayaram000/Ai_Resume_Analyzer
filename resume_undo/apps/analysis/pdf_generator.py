import io
import html
from reportlab.lib.pagesizes import letter
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, ListItem, ListFlowable, HRFlowable
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib import colors


def generate_skill_gap_pdf(analysis, is_guiding_mode=False) -> io.BytesIO:
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=letter, rightMargin=54, leftMargin=54, topMargin=54, bottomMargin=36)
    
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Heading1'],
        fontSize=18,
        leading=22,
        textColor=colors.HexColor("#1E293B"),
        spaceAfter=12
    )
    subtitle_style = ParagraphStyle(
        'SubTitle',
        parent=styles['Heading2'],
        fontSize=13,
        leading=16,
        textColor=colors.HexColor("#0F766E"),
        spaceBefore=10,
        spaceAfter=6
    )
    normal_style = ParagraphStyle(
        'Body',
        parent=styles['Normal'],
        fontSize=10,
        leading=14,
        textColor=colors.HexColor("#334155")
    )
    bold_style = ParagraphStyle(
        'BoldBody',
        parent=normal_style,
        fontName='Helvetica-Bold'
    )

    story = []
    
    story.append(Paragraph(f"Career Roadmap: {analysis.target_role}", title_style))
    story.append(Spacer(1, 10))
    
    if is_guiding_mode:
        story.append(Paragraph("Required Technologies & Skills", subtitle_style))
    else:
        story.append(Paragraph("Missing Technologies & Skills", subtitle_style))
    story.append(Spacer(1, 4))
    
    if analysis.missing_skills:
        skill_text = ", ".join(analysis.missing_skills)
        story.append(Paragraph(html.escape(skill_text), normal_style))
    else:
        story.append(Paragraph("None identified.", normal_style))
    story.append(Spacer(1, 10))

    story.append(Paragraph("Detailed Career Roadmap", subtitle_style))
    story.append(Spacer(1, 10))
    
    if analysis.roadmap:
        for phase in analysis.roadmap:
            phase_title = phase.get("phase", "Phase")
            story.append(Paragraph(html.escape(phase_title), bold_style))
            story.append(Spacer(1, 4))
            
            guidance = phase.get("guidance", "")
            if guidance:
                story.append(Paragraph(html.escape(guidance), normal_style))
                story.append(Spacer(1, 4))
                
            milestones = phase.get("milestones", [])
            if milestones:
                items = [ListItem(Paragraph(html.escape(m), normal_style)) for m in milestones]
                story.append(ListFlowable(items, bulletType='bullet'))
                story.append(Spacer(1, 8))
    else:
        story.append(Paragraph("No detailed roadmap generated.", normal_style))
        
    doc.build(story)
    buffer.seek(0)
    return buffer


def generate_resume_pdf(markdown_content: str, template_style: str = "classic") -> io.BytesIO:
    """
    Generates a professional ATS-friendly PDF document from Markdown content.
    Supports 3 distinct layout themes:
    1. 'classic'   - Classic ATS Standard (Navy Blue, Traditional 1-column layout)
    2. 'modern'    - Modern Executive (Emerald & Slate, Left Badges, Sleek padding)
    3. 'minimalist'- Clean Minimalist (Dark Charcoal & Teal, Compact single column)
    """
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=letter,
        rightMargin=45 if template_style == "minimalist" else 54,
        leftMargin=45 if template_style == "minimalist" else 54,
        topMargin=45 if template_style == "minimalist" else 54,
        bottomMargin=45 if template_style == "minimalist" else 54,
    )

    styles = getSampleStyleSheet()

    # Determine theme color palette
    if template_style == "modern":
        primary_color = colors.HexColor("#0F766E")   # Emerald
        secondary_color = colors.HexColor("#0284C7") # Slate Blue
        divider_color = colors.HexColor("#CBD5E1")
    elif template_style == "minimalist":
        primary_color = colors.HexColor("#0D9488")   # Teal
        secondary_color = colors.HexColor("#334155") # Charcoal
        divider_color = colors.HexColor("#E2E8F0")
    else:
        # Default "classic"
        primary_color = colors.HexColor("#1E3A8A")   # Deep Navy
        secondary_color = colors.HexColor("#1E293B") # Dark Slate
        divider_color = colors.HexColor("#94A3B8")

    title_style = ParagraphStyle(
        'ResumeTitle',
        parent=styles['Heading1'],
        fontSize=22 if template_style != "minimalist" else 20,
        leading=26,
        fontName='Helvetica-Bold',
        textColor=primary_color,
        alignment=1 if template_style == "classic" else 0, # Center for Classic, Left for Modern/Minimalist
        spaceAfter=4
    )

    contact_style = ParagraphStyle(
        'ResumeContact',
        parent=styles['Normal'],
        fontSize=9.5,
        leading=13,
        textColor=colors.HexColor("#475569"),
        alignment=1 if template_style == "classic" else 0,
        spaceAfter=12
    )

    h2_style = ParagraphStyle(
        'ResumeSectionHeader',
        parent=styles['Heading2'],
        fontSize=12.5,
        leading=16,
        fontName='Helvetica-Bold',
        textColor=primary_color,
        spaceBefore=10,
        spaceAfter=4
    )

    h3_style = ParagraphStyle(
        'ResumeSubHeader',
        parent=styles['Heading3'],
        fontSize=10.5,
        leading=14,
        fontName='Helvetica-Bold',
        textColor=secondary_color,
        spaceBefore=6,
        spaceAfter=3
    )

    body_style = ParagraphStyle(
        'ResumeBody',
        parent=styles['Normal'],
        fontSize=9.5,
        leading=13.5,
        textColor=colors.HexColor("#1E293B")
    )

    story = []
    lines = markdown_content.split('\n')
    current_list_items = []
    is_first_header = True

    def flush_list():
        if current_list_items:
            items = []
            for item_text in current_list_items:
                formatted_item = format_inline_markdown(item_text)
                items.append(ListItem(Paragraph(formatted_item, body_style)))
            story.append(ListFlowable(items, bulletType='bullet', leftIndent=12, bulletColor=primary_color))
            story.append(Spacer(1, 4))
            current_list_items.clear()

    def format_inline_markdown(text: str) -> str:
        # Convert **bold** to <b>bold</b> and *italic* to <i>italic</i>
        parts = text.split('**')
        result = []
        for i, part in enumerate(parts):
            if i % 2 == 1:
                result.append(f"<b>{html.escape(part)}</b>")
            else:
                result.append(html.escape(part))
        return "".join(result)

    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue

        if stripped.startswith('# '):
            flush_list()
            name_text = stripped[2:].strip()
            story.append(Paragraph(html.escape(name_text), title_style))
            is_first_header = True

        elif stripped.startswith('## '):
            flush_list()
            section_name = stripped[3:].strip()
            story.append(Spacer(1, 6))
            story.append(Paragraph(html.escape(section_name).upper(), h2_style))
            story.append(HRFlowable(width="100%", thickness=1, color=divider_color, spaceBefore=2, spaceAfter=6))

        elif stripped.startswith('### '):
            flush_list()
            sub_text = stripped[4:].strip()
            story.append(Paragraph(format_inline_markdown(sub_text), h3_style))
            story.append(Spacer(1, 2))

        elif stripped.startswith('- ') or stripped.startswith('* '):
            bullet_text = stripped[2:].strip()
            current_list_items.append(bullet_text)

        else:
            flush_list()
            if is_first_header and ("@" in stripped or "|" in stripped or "+" in stripped or "http" in stripped or "LinkedIn" in stripped):
                # Contact info line under main name header
                story.append(Paragraph(html.escape(stripped), contact_style))
                is_first_header = False
            else:
                formatted_line = format_inline_markdown(stripped)
                story.append(Paragraph(formatted_line, body_style))
                story.append(Spacer(1, 3))

    flush_list()
    doc.build(story)
    buffer.seek(0)
    return buffer
