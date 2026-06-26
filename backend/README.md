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

## PDF Photo Extraction

Text extraction works from the Node dependencies. For voter photo extraction from PDFs, install Poppler and make `pdfimages` available.

On Windows, install Poppler, then set in `.env` if needed:

```env
PDFIMAGES_PATH=C:\poppler\Library\bin\pdfimages.exe
```

If Poppler is not installed, PDF import still imports text data and returns an image extraction status message.
