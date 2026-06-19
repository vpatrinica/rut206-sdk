#! /usr/bin/env python3

import json
import re
import sys

from fpdf import FPDF, XPos, YPos
from fpdf.outline import TableOfContents

header_re = re.compile(r"^(#+)+\s+(.*)$")

pdf = FPDF()
pdf.set_margin(20)
pdf.set_display_mode(zoom="default")
pdf.add_font("dejavu-sans", style="", fname="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")
pdf.add_font("dejavu-sans", style="B", fname="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf")

if len(sys.argv) < 3:
    print("Usage: generate_license_pdf.py <input_file> <output_file>")
    sys.exit(1)

input_file = sys.argv[1]
output_file = sys.argv[2]

with open(input_file, "r") as f:
    data = json.load(f)

pdf.add_page()
pdf.set_font("dejavu-sans", style="B", size=16)
pdf.multi_cell(w=0, h=10, text="Table of contents", new_x=XPos.LMARGIN, new_y=YPos.NEXT, align="L")

toc = TableOfContents()
pdf.insert_toc_placeholder(toc.render_toc, allow_extra_pages=True)

for name, info in data.items():
    contents = {}

    for file in info.get("files", []):
        try:
            with open(file, "r", encoding="utf-8", errors="ignore") as f:
                contents[file] = f.read()
        except FileNotFoundError as e:
            print(f"Warning: Could not find file {file} for {name}")

    page_title = f"{name} - {info.get('license')}"

    if not contents:
        print(f"Warning: No license content found for {name}, license {info.get('license')}")
        continue
        page_title += " (no license content found)"

    pdf.add_page()

    pdf.start_section(name=page_title, level=0)

    pdf.set_font("dejavu-sans", style="B", size=16)
    pdf.multi_cell(w=0, h=10, text=page_title, new_x=XPos.LMARGIN, new_y=YPos.NEXT, align="L")

    pdf.set_font(size=11)
    for _, c in contents.items():
        pdf.multi_cell(w=0, text=c, align="L")

        pdf.ln(5)
        pdf.set_draw_color(0, 0, 0)
        pdf.set_line_width(0.5)
        pdf.line(pdf.l_margin, pdf.get_y(), pdf.w - pdf.r_margin, pdf.get_y())
        pdf.ln(5)

pdf.output(output_file)
