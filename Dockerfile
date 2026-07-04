FROM node:20-bookworm-slim

WORKDIR /app

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    imagemagick \
    poppler-utils \
    python3 \
    python-is-python3 \
    python3-pip \
    tesseract-ocr \
    tesseract-ocr-eng \
    tesseract-ocr-hin \
  && rm -rf /var/lib/apt/lists/*

COPY backend/package*.json ./
RUN npm ci --omit=dev

COPY backend/python/requirements.txt ./python/requirements.txt
RUN pip3 install --break-system-packages --no-cache-dir -r python/requirements.txt

COPY backend/ .

RUN pdftoppm -v \
  && pdfimages -v \
  && tesseract --list-langs \
  && magick -version \
  && python --version \
  && python3 --version

ENV NODE_ENV=production
ENV PYTHON_PATH=python3
ENV PDFTOPPM_PATH=pdftoppm
ENV PDFIMAGES_PATH=pdfimages
ENV TESSERACT_PATH=tesseract
ENV IMAGEMAGICK_PATH=magick
ENV OCR_LANGUAGES=hin+eng
ENV OCR_DPI=200
ENV OCR_CELL_CONCURRENCY=2
ENV IMAGE_CROP_CONCURRENCY=2

CMD ["npm", "start"]
