import docx
doc = docx.Document("Docs/PUMP MANAGEMENT SYSTEM.docx")
for i, para in enumerate(doc.paragraphs):
    if para.text.strip():
        print(f"[{i}] {para.text}")
