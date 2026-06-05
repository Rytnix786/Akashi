import os
import sys
from pdf2image import convert_from_path, pdfinfo_from_path
import pytesseract

pdf_path = r"h:\Projects\Akashi\docs\knowledge_base\9712200299Bangla_content.pdf"
txt_path = r"h:\Projects\Akashi\docs\knowledge_base\9712200299Bangla_ocr.txt"
poppler_path = r"C:\Users\Mehedi D Nafis\AppData\Local\Microsoft\WinGet\Packages\oschwartz10612.Poppler_Microsoft.Winget.Source_8wekyb3d8bbwe\poppler-25.07.0\Library\bin"
tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"

tessdata_dir = "h:/Projects/Akashi/tessdata"
os.environ["TESSDATA_PREFIX"] = "h:/Projects/Akashi"
pytesseract.pytesseract.tesseract_cmd = tesseract_cmd

print("Checking PDF information...")
try:
    info = pdfinfo_from_path(pdf_path, poppler_path=poppler_path)
    num_pages = info["Pages"]
    print(f"Total pages in PDF: {num_pages}")
except Exception as e:
    print(f"Error reading PDF info: {str(e)}")
    sys.exit(1)

# Clean existing text file if any
if os.path.exists(txt_path):
    os.remove(txt_path)

print("Starting OCR text extraction with 'ben+eng' page-by-page...")
with open(txt_path, "w", encoding="utf-8") as f_out:
    for page_num in range(1, num_pages + 1):
        print(f"Extracting page {page_num}/{num_pages}...")
        try:
            pages = convert_from_path(
                pdf_path,
                first_page=page_num,
                last_page=page_num,
                poppler_path=poppler_path,
                dpi=100  # 100 DPI is faster and sufficient for OCR
            )
            if pages:
                config = f'--tessdata-dir {tessdata_dir}'
                text = pytesseract.image_to_string(pages[0], lang="ben+eng", config=config)
                f_out.write(f"--- PAGE {page_num} ---\n")
                f_out.write(text)
                f_out.write("\n")
                for p in pages:
                    p.close()
                del pages
        except Exception as page_err:
            print(f"Error on page {page_num}: {str(page_err)}")

print(f"OCR complete! Extracted text saved to: {txt_path}")
