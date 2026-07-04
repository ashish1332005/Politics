# Political Booth Management CRM - Backend

Node.js, Express, MongoDB, Mongoose, JWT, bcrypt, Multer, XLSX, PDFKit, QRCode.

## Setup

```bash
cd backend
cp .env.example .env
npm install
npm run seed:admin
npm run dev
```

## Main API

- `POST /api/auth/login`
- `POST /api/auth/users` admin creates booth/admin users
- `GET/POST/PUT/DELETE /api/wards`
- `GET/POST/PUT/DELETE /api/booths`
- `GET/POST/PUT/DELETE /api/parties`
- `GET/POST/PUT/DELETE /api/members`
- `GET /api/members/birthdays`
- `GET /api/members/duplicates`
- `POST /api/import/members` multipart field `file`
- `GET /api/export/members.xlsx`
- `GET /api/export/members/:id.pdf`
- `GET /api/export/backup`
- `GET /api/reports/dashboard`
- `GET /api/activity`
- `GET/POST /api/messages/templates`
- `POST /api/messages/broadcast`

Admin users can access all data. Booth users are automatically scoped to `assignedBooth` for member reads and writes.

## PDF/OCR Import

Text-based PDFs can be parsed from Node dependencies. Scanned voter-list PDFs need Poppler, Tesseract with Hindi data, ImageMagick, and Python OCR packages.

On Windows, install Poppler/Tesseract/ImageMagick, then set in `.env` if needed:

```env
PDFIMAGES_PATH=C:\poppler\Library\bin\pdfimages.exe
PDFTOPPM_PATH=C:\poppler\Library\bin\pdftoppm.exe
TESSERACT_PATH=C:\Program Files\Tesseract-OCR\tesseract.exe
IMAGEMAGICK_PATH=C:\Program Files\ImageMagick-7.1.2-Q16-HDRI\magick.exe
TESSDATA_PREFIX=D:\Politcs\backend\tessdata
```

On Render, deploy the backend as a Docker service using `backend/Dockerfile` or the root `render.yaml` blueprint. Do not use Windows paths in Render env vars. Use:

```env
PDFIMAGES_PATH=pdfimages
PDFTOPPM_PATH=pdftoppm
TESSERACT_PATH=tesseract
IMAGEMAGICK_PATH=magick
PYTHON_PATH=python3
OCR_LANGUAGES=hin+eng
USE_PYTHON_OCR=true
```

Leave `TESSDATA_PREFIX` unset on Render.
