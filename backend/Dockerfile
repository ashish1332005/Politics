FROM node:20-bookworm-slim

WORKDIR /app

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    imagemagick \
    poppler-utils \
    python3 \
    python3-pip \
    tesseract-ocr \
    tesseract-ocr-eng \
    tesseract-ocr-hin \
  && rm -rf /var/lib/apt/lists/*

COPY package*.json ./
RUN npm ci --omit=dev

COPY python/requirements.txt ./python/requirements.txt
RUN pip3 install --break-system-packages --no-cache-dir -r python/requirements.txt

COPY . .

ENV NODE_ENV=production
ENV PYTHON_PATH=python3
ENV PDFTOPPM_PATH=pdftoppm
ENV PDFIMAGES_PATH=pdfimages
ENV TESSERACT_PATH=tesseract
ENV IMAGEMAGICK_PATH=magick
ENV OCR_LANGUAGES=hin+eng

CMD ["npm", "start"]
