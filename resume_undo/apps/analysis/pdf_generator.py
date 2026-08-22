import io
import html
from reportlab.lib.pagesizes import letter
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, ListItem, ListFlowable, HRFlowable, Table, TableStyle, KeepTogether
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib import colors
from datetime import datetime


def generate_skill_gap_pdf(analysis, is_guiding_mode=False) -> io.BytesIO:
    """
    Generates a visually stunning, premium, executive-grade PDF report for Skill Gap Intelligence.
    Features:
    - Luxurious Indigo/Teal header banner
    - Executive Readiness scorecard & narrative card
    - Matched vs Missing Skills comparison matrix
    - Categorized competency cards
    - Phased transition timeline with milestones
    - Portfolio project blueprints & certifications
    - Actionable resume positioning tips
    """
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=letter,
        rightMargin=36,
        leftMargin=36,
        topMargin=36,
        bottomMargin=36
    )

    styles = getSampleStyleSheet()

    # Color Palette
    PRIMARY = colors.HexColor("#4F46E5")     # Indigo
    PRIMARY_LIGHT = colors.HexColor("#EEF2FF") # Indigo 50
    SECONDARY = colors.HexColor("#0D9488")   # Teal
    SECONDARY_LIGHT = colors.HexColor("#F0FDFA") # Teal 50
    SUCCESS = colors.HexColor("#16A34A")     # Emerald Green
    SUCCESS_LIGHT = colors.HexColor("#DCFCE7")
    DANGER = colors.HexColor("#E11D48")      # Rose Red
    DANGER_LIGHT = colors.HexColor("#FFE4E6")
    WARNING = colors.HexColor("#D97706")     # Amber
    WARNING_LIGHT = colors.HexColor("#FEF3C7")
    DARK_BG = colors.HexColor("#0F172A")     # Slate 900
    TEXT_DARK = colors.HexColor("#1E293B")   # Slate 800
    TEXT_MUTED = colors.HexColor("#64748B")  # Slate 500
    BORDER_COLOR = colors.HexColor("#CBD5E1") # Slate 300

    # Typography Styles
    banner_pre_style = ParagraphStyle(
        'BannerPre',
        parent=styles['Normal'],
        fontSize=8.5,
        leading=11,
        fontName='Helvetica-Bold',
        textColor=colors.HexColor("#A5B4FC"),
        spaceAfter=3
    )
    banner_title_style = ParagraphStyle(
        'BannerTitle',
        parent=styles['Heading1'],
        fontSize=20,
        leading=24,
        fontName='Helvetica-Bold',
        textColor=colors.white,
        spaceAfter=4
    )
    banner_sub_style = ParagraphStyle(
        'BannerSub',
        parent=styles['Normal'],
        fontSize=9.5,
        leading=13,
        textColor=colors.HexColor("#E0E7FF")
    )
    section_h1_style = ParagraphStyle(
        'SecH1',
        parent=styles['Heading2'],
        fontSize=13,
        leading=17,
        fontName='Helvetica-Bold',
        textColor=PRIMARY,
        spaceBefore=12,
        spaceAfter=6
    )
    score_num_style = ParagraphStyle(
        'ScoreNum',
        parent=styles['Normal'],
        fontSize=26,
        leading=28,
        fontName='Helvetica-Bold',
        textColor=PRIMARY,
        alignment=1
    )
    score_label_style = ParagraphStyle(
        'ScoreLabel',
        parent=styles['Normal'],
        fontSize=8.5,
        leading=11,
        fontName='Helvetica-Bold',
        textColor=TEXT_MUTED,
        alignment=1
    )
    body_style = ParagraphStyle(
        'BodyDark',
        parent=styles['Normal'],
        fontSize=9,
        leading=13,
        textColor=TEXT_DARK
    )
    body_bold_style = ParagraphStyle(
        'BodyDarkBold',
        parent=body_style,
        fontName='Helvetica-Bold'
    )
    milestone_style = ParagraphStyle(
        'MilestoneText',
        parent=styles['Normal'],
        fontSize=8.5,
        leading=12,
        textColor=TEXT_DARK
    )

    # Extract dynamic properties
    lp_data = {}
    if hasattr(analysis, 'learning_priority') and isinstance(analysis.learning_priority, list) and len(analysis.learning_priority) > 0:
        if isinstance(analysis.learning_priority[0], dict):
            lp_data = analysis.learning_priority[0]

    match_score = lp_data.get("match_score", 65)
    readiness_level = lp_data.get("readiness_level", "Role Transition Analysis")
    readiness_summary = lp_data.get("readiness_summary", f"Strategic career intelligence evaluation comparing candidate profile against industry standards for {analysis.target_role}.")
    matched_skills = lp_data.get("matched_skills", [])
    missing_skills = analysis.missing_skills or []
    categorized_gaps = lp_data.get("categorized_gaps", {})
    roadmap_phases = analysis.roadmap or []
    recommended_projects = lp_data.get("recommended_projects", [])
    recommended_certs = lp_data.get("recommended_certifications", [])
    resume_tips = lp_data.get("resume_transition_tips", [])
    gen_date = analysis.created_at.strftime("%B %d, %Y") if hasattr(analysis, "created_at") and analysis.created_at else datetime.now().strftime("%B %d, %Y")

    story = []

    # 1. HEADER BANNER
    header_content = [
        Paragraph("RESUMEAI • ADVANCED CAREER COPILOT & SKILL GAP INTELLIGENCE", banner_pre_style),
        Paragraph(f"Career Transition Plan: {html.escape(analysis.target_role)}", banner_title_style),
        Paragraph(f"Evaluation Level: <b>{html.escape(readiness_level)}</b> &nbsp;|&nbsp; Generated on: {gen_date}", banner_sub_style)
    ]
    banner_table = Table([[header_content]], colWidths=[540])
    banner_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), DARK_BG),
        ('TOPPADDING', (0, 0), (-1, -1), 16),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 16),
        ('LEFTPADDING', (0, 0), (-1, -1), 18),
        ('RIGHTPADDING', (0, 0), (-1, -1), 18),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
    ]))
    story.append(banner_table)
    story.append(Spacer(1, 12))

    # 2. EXECUTIVE READINESS SCORECARD
    score_box_content = [
        Paragraph(f"{match_score}%", score_num_style),
        Spacer(1, 2),
        Paragraph("MATCH SCORE", score_label_style)
    ]
    summary_box_content = [
        Paragraph(f"<b>Executive Readiness Evaluation</b> • <font color='#0D9488'><b>{html.escape(readiness_level)}</b></font>", body_bold_style),
        Spacer(1, 4),
        Paragraph(html.escape(readiness_summary), body_style)
    ]
    score_table = Table([[score_box_content, summary_box_content]], colWidths=[100, 440])
    score_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (0, 0), PRIMARY_LIGHT),
        ('BACKGROUND', (1, 0), (1, 0), colors.HexColor("#F8FAFC")),
        ('BOX', (0, 0), (-1, -1), 1, BORDER_COLOR),
        ('INNERGRID', (0, 0), (-1, -1), 1, BORDER_COLOR),
        ('TOPPADDING', (0, 0), (-1, -1), 10),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 10),
        ('LEFTPADDING', (0, 0), (-1, -1), 12),
        ('RIGHTPADDING', (0, 0), (-1, -1), 12),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
    ]))
    story.append(score_table)
    story.append(Spacer(1, 14))

    # 3. SKILLS COMPARISON MATRIX (Matched vs Missing)
    story.append(Paragraph("Skills & Technology Gap Analysis", section_h1_style))
    story.append(Spacer(1, 4))

    matched_txt = ", ".join(matched_skills) if matched_skills else "No direct matches identified in active keywords."
    missing_txt = ", ".join(missing_skills) if missing_skills else "No major skill gaps identified."

    matched_cell = [
        Paragraph("<font color='#16A34A'><b>✔ Matched Skills (From Your Resume)</b></font>", body_bold_style),
        Spacer(1, 4),
        Paragraph(html.escape(matched_txt), body_style)
    ]
    missing_cell = [
        Paragraph("<font color='#E11D48'><b>✖ Missing & Required Target Skills</b></font>", body_bold_style),
        Spacer(1, 4),
        Paragraph(html.escape(missing_txt), body_style)
    ]

    skills_table = Table([[matched_cell, missing_cell]], colWidths=[265, 265])
    skills_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (0, 0), SUCCESS_LIGHT),
        ('BACKGROUND', (1, 0), (1, 0), DANGER_LIGHT),
        ('BOX', (0, 0), (0, 0), 1, colors.HexColor("#86EFAC")),
        ('BOX', (1, 0), (1, 0), 1, colors.HexColor("#FDA4AF")),
        ('TOPPADDING', (0, 0), (-1, -1), 10),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 10),
        ('LEFTPADDING', (0, 0), (-1, -1), 12),
        ('RIGHTPADDING', (0, 0), (-1, -1), 12),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
    ]))
    story.append(skills_table)
    story.append(Spacer(1, 14))

    # 4. CATEGORIZED GAPS BREAKDOWN
    if categorized_gaps:
        story.append(Paragraph("Categorized Competency Areas", section_h1_style))
        story.append(Spacer(1, 4))
        cat_rows = []
        for cat_name, cat_skills in categorized_gaps.items():
            skills_str = ", ".join(cat_skills) if isinstance(cat_skills, list) else str(cat_skills)
            cat_rows.append([
                Paragraph(f"<b>{html.escape(cat_name)}</b>", body_bold_style),
                Paragraph(html.escape(skills_str), body_style)
            ])
        if cat_rows:
            cat_table = Table(cat_rows, colWidths=[180, 360])
            cat_table.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (0, -1), colors.HexColor("#F1F5F9")),
                ('BACKGROUND', (1, 0), (1, -1), colors.white),
                ('GRID', (0, 0), (-1, -1), 0.5, BORDER_COLOR),
                ('TOPPADDING', (0, 0), (-1, -1), 6),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
                ('LEFTPADDING', (0, 0), (-1, -1), 10),
                ('RIGHTPADDING', (0, 0), (-1, -1), 10),
                ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ]))
            story.append(cat_table)
            story.append(Spacer(1, 14))

    # 5. DETAILED CAREER ROADMAP PHASES
    if roadmap_phases:
        story.append(Paragraph("Actionable Step-by-Step Transition Phases", section_h1_style))
        story.append(Spacer(1, 4))

        for idx, phase in enumerate(roadmap_phases):
            phase_title = phase.get("phase", f"Phase {idx + 1}")
            guidance = phase.get("guidance", "")
            milestones = phase.get("milestones", [])

            phase_content = [
                Paragraph(f"<b>{html.escape(phase_title)}</b>", body_bold_style),
            ]
            if guidance:
                phase_content.append(Spacer(1, 2))
                phase_content.append(Paragraph(f"<i>Guidance: {html.escape(guidance)}</i>", body_style))
            if milestones:
                phase_content.append(Spacer(1, 4))
                m_items = [ListItem(Paragraph(html.escape(str(m)), milestone_style)) for m in milestones]
                phase_content.append(ListFlowable(m_items, bulletType='bullet', bulletColor=PRIMARY, leftIndent=12))

            phase_card = Table([[phase_content]], colWidths=[540])
            phase_card.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor("#F8FAFC")),
                ('BOX', (0, 0), (-1, -1), 1, BORDER_COLOR),
                ('TOPPADDING', (0, 0), (-1, -1), 8),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
                ('LEFTPADDING', (0, 0), (-1, -1), 12),
                ('RIGHTPADDING', (0, 0), (-1, -1), 12),
            ]))
            story.append(KeepTogether([phase_card, Spacer(1, 8)]))

    # 6. RECOMMENDED PORTFOLIO PROJECTS
    if recommended_projects:
        story.append(Spacer(1, 6))
        story.append(Paragraph("Recommended Portfolio Projects (To Prove Competence)", section_h1_style))
        story.append(Spacer(1, 4))

        proj_cards = []
        for p in recommended_projects:
            title = p.get("title", "Portfolio Project")
            desc = p.get("description", "")
            stack = ", ".join(p.get("tech_stack", [])) if isinstance(p.get("tech_stack"), list) else ""

            p_cell = [
                Paragraph(f"<b>{html.escape(title)}</b>", body_bold_style),
                Spacer(1, 2),
                Paragraph(html.escape(desc), body_style),
            ]
            if stack:
                p_cell.append(Spacer(1, 2))
                p_cell.append(Paragraph(f"<b>Tech Stack:</b> <font color='#4F46E5'>{html.escape(stack)}</font>", milestone_style))

            proj_cards.append([p_cell])

        if proj_cards:
            proj_table = Table(proj_cards, colWidths=[540])
            proj_table.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor("#F0FDFA")),
                ('GRID', (0, 0), (-1, -1), 1, colors.HexColor("#99F6E4")),
                ('TOPPADDING', (0, 0), (-1, -1), 8),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
                ('LEFTPADDING', (0, 0), (-1, -1), 12),
                ('RIGHTPADDING', (0, 0), (-1, -1), 12),
            ]))
            story.append(KeepTogether([proj_table, Spacer(1, 12)]))

    # 7. RECOMMENDED CERTIFICATIONS & RESUME TIPS
    if recommended_certs or resume_tips:
        story.append(Spacer(1, 6))
        story.append(Paragraph("Industry Certifications & Resume Positioning", section_h1_style))
        story.append(Spacer(1, 4))

        cert_cell = []
        if recommended_certs:
            cert_cell.append(Paragraph("<b>Recommended Certifications</b>", body_bold_style))
            cert_cell.append(Spacer(1, 4))
            c_items = [ListItem(Paragraph(html.escape(str(c)), milestone_style)) for c in recommended_certs]
            cert_cell.append(ListFlowable(c_items, bulletType='bullet', bulletColor=WARNING, leftIndent=10))

        tip_cell = []
        if resume_tips:
            tip_cell.append(Paragraph("<b>Resume Optimization Tips</b>", body_bold_style))
            tip_cell.append(Spacer(1, 4))
            t_items = [ListItem(Paragraph(html.escape(str(t)), milestone_style)) for t in resume_tips]
            tip_cell.append(ListFlowable(t_items, bulletType='bullet', bulletColor=PRIMARY, leftIndent=10))

        cert_tip_table = Table([[cert_cell, tip_cell]], colWidths=[265, 265])
        cert_tip_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (0, 0), WARNING_LIGHT if recommended_certs else colors.white),
            ('BACKGROUND', (1, 0), (1, 0), PRIMARY_LIGHT if resume_tips else colors.white),
            ('BOX', (0, 0), (0, 0), 1, colors.HexColor("#FDE68A")),
            ('BOX', (1, 0), (1, 0), 1, colors.HexColor("#C7D2FE")),
            ('TOPPADDING', (0, 0), (-1, -1), 8),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
            ('LEFTPADDING', (0, 0), (-1, -1), 10),
            ('RIGHTPADDING', (0, 0), (-1, -1), 10),
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ]))
        story.append(KeepTogether([cert_tip_table, Spacer(1, 14)]))

    # FOOTER
    story.append(Spacer(1, 10))
    story.append(HRFlowable(width="100%", thickness=0.5, color=BORDER_COLOR, spaceBefore=4, spaceAfter=6))
    footer_style = ParagraphStyle(
        'FooterText',
        parent=styles['Normal'],
        fontSize=7.5,
        leading=10,
        textColor=TEXT_MUTED,
        alignment=1
    )
    story.append(Paragraph("Confidential • Prepared for Candidate Career Acceleration • Powered by ResumeAI Platform", footer_style))

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
