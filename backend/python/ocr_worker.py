import json
import os
import re
import sys
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

import cv2
import pytesseract

sys.stdin.reconfigure(encoding="utf-8")
sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")


def ratio(name, default):
    return float(os.getenv(name, default))


def clean(text):
    return re.sub(r"\s+", " ", text or "").strip()

def clean_person_name(value):
    value = re.sub(r"[^\u0900-\u097F\s.-]", " ", value or "")
    return clean(value).strip(" .-|")


def clean_house(value):
    match = re.search(r"[0-9०-९]+(?:[/\-][0-9०-९]+)?", value or "")
    return match.group(0) if match else ""


def ocr_house(card):
    height, width = card.shape[:2]
    region = card[
        round(height * 0.38):round(height * 0.78),
        0:round(width * 0.72),
    ]
    if region.size == 0:
        return ""
    gray = cv2.cvtColor(region, cv2.COLOR_BGR2GRAY)
    gray = cv2.resize(gray, None, fx=4, fy=4, interpolation=cv2.INTER_CUBIC)
    binary = cv2.threshold(
        gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU,
    )[1]
    text = pytesseract.image_to_string(
        binary,
        lang=os.getenv("OCR_LANGUAGES", "hin+eng"),
        config="--psm 6",
    )
    return clean_house(field(
        text,
        r"(?:गृह|मकान)\s*संख्या\s*[:：;\-]?\s*([^\n]+)",
    ))

def field(text, pattern):
    match = re.search(pattern, text, re.MULTILINE | re.IGNORECASE)
    return clean(match.group(1)) if match else ""


def epic_from(text):
    compact = re.sub(r"[^A-Z0-9/]", "", (text or "").upper().replace("\\", "/"))
    legacy = re.search(r"RJ/[0-9O]{1,3}/[0-9O]{1,3}/[0-9O]{5,8}", compact)
    if legacy:
        return legacy.group(0).replace("O", "0")
    # Old Rajasthan rolls are frequently read as RU/PUI/E4 instead of RJ.
    legacy_parts = re.search(r"[A-Z0-9]{0,3}/([0-9O]{1,3})/([0-9O]{1,3})/([0-9O]{5,8})", compact)
    if legacy_parts:
        return "RJ/{}/{}/{}".format(
            legacy_parts.group(1).replace("O", "0"),
            legacy_parts.group(2).replace("O", "0"),
            legacy_parts.group(3).replace("O", "0"),
        )
    letter_map = str.maketrans({"0": "O", "1": "I", "2": "Z", "5": "S", "6": "G", "8": "B"})
    digit_map = str.maketrans({"O": "0", "Q": "0", "D": "0", "I": "1", "L": "1", "Z": "2", "S": "5", "B": "8", "G": "6"})
    for value in re.findall(r"[A-Z0-9]{10}", compact):
        candidate = value[:3].translate(letter_map) + value[3:].translate(digit_map)
        if re.fullmatch(r"[A-Z]{3}[0-9]{7}", candidate):
            return candidate
    return ""


def ocr_epic(card):
    height, width = card.shape[:2]
    regions = [
        card[0:round(height * 0.25), round(width * 0.18):width],
        card[0:round(height * 0.32), round(width * 0.10):width],
    ]
    readings = []
    for region in regions:
        if region.size == 0:
            continue
        gray = cv2.cvtColor(region, cv2.COLOR_BGR2GRAY)
        gray = cv2.resize(gray, None, fx=5, fy=5, interpolation=cv2.INTER_CUBIC)
        variants = [
            cv2.createCLAHE(3.0, (8, 8)).apply(gray),
            cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)[1],
        ]
        for variant in variants:
            for psm in (7, 11):
                text = pytesseract.image_to_string(variant, lang="eng", config=f"--psm {psm} -c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/")
                value = epic_from(text)
                if value:
                    return value
    return ""


def parse_card(text, epic_text, photo_path, page_no, cell_no, focused_house=""):
    name = clean_person_name(field(text, r"(?:निर्वा\S*|मतदाता)\s*(?:का)?\s*नाम\s*[:：;\-]?\s*([^\n]+)"))
    father = clean_person_name(field(text, r"(?:पिता|पि\S*)\s*(?:का)?\s*नाम\s*[:：;\-]?\s*([^\n]+)"))
    husband = clean_person_name(field(text, r"(?:पति|पत्ति|प्रति)\s*(?:का)?\s*नाम\s*[:：;\-]?\s*([^\n]+)"))
    mother = clean_person_name(field(text, r"माता\s*(?:का)?\s*नाम\s*[:：;\-]?\s*([^\n]+)"))
    house = focused_house or clean_house(field(text, r"(?:गृह|मकान)\s*संख्या\s*[:：;\-]?\s*([^\n]+)"))
    age = field(text, r"(?:उम्र|उप्र|आयु)\s*[:：;\-]?\s*(\d{1,3})")
    gender = "female" if "महिला" in text else "male" if "पुरुष" in text else ""
    guardian = father or husband or mother
    relation = "father" if father else "husband" if husband else "mother" if mother else ""
    devanagari = len(re.findall(r"[\u0900-\u097F]", name))
    confidence = 0
    confidence += 35 if devanagari >= 2 else 0
    confidence += 20 if guardian else 0
    confidence += 15 if house else 0
    confidence += 10 if age else 0
    confidence += 10 if gender else 0
    voter_id = epic_from(epic_text + "\n" + text)
    serial_match = re.search(r"(?:^|\n)\s*[\[\(\|]?\s*(\d{1,4})\s*[\]\)\|]?", text or "")
    voter_serial = serial_match.group(1) if serial_match else ""
    addition_match = re.search(
        r"(?:^|\n)\D*(\d{1,4})\D+(\d{1,2})\D+(?:[A-Z]{2,4}|RJ/)",
        text or "",
        re.IGNORECASE,
    )
    section_number = addition_match.group(2) if addition_match else ""
    confidence += 10 if voter_id else 0
    return {
        "name": name,
        "guardianName": guardian,
        "relationType": relation,
        "houseNumber": house,
        "age": int(age) if age.isdigit() else None,
        "gender": gender,
        "voterId": voter_id,
        "voterSerial": voter_serial,
        "sectionNumber": section_number,
        "photo": photo_path,
        "rawText": text,
        "confidence": confidence,
        "page": page_no,
        "cell": cell_no,
    }


def detect_card_boxes(image):
    height, width = image.shape[:2]
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    binary = cv2.adaptiveThreshold(
        gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY_INV, 31, 9,
    )
    horizontal = cv2.morphologyEx(
        binary,
        cv2.MORPH_OPEN,
        cv2.getStructuringElement(cv2.MORPH_RECT, (max(40, width // 20), 1)),
    )
    vertical = cv2.morphologyEx(
        binary,
        cv2.MORPH_OPEN,
        cv2.getStructuringElement(cv2.MORPH_RECT, (1, max(20, height // 80))),
    )
    grid = cv2.bitwise_or(horizontal, vertical)
    contours, _ = cv2.findContours(grid, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)
    boxes = []
    for contour in contours:
        x, y, w, h = cv2.boundingRect(contour)
        if (
            width * 0.25 <= w <= width * 0.34
            and height * 0.065 <= h <= height * 0.105
            and y > height * 0.02
        ):
            boxes.append((x, y, w, h))
    unique = []
    for box in sorted(boxes, key=lambda b: (b[1], b[0])):
        if not any(abs(box[0] - old[0]) < 8 and abs(box[1] - old[1]) < 8 for old in unique):
            unique.append(box)
    return unique


def detect_photo_box(card):
    height, width = card.shape[:2]
    gray = cv2.cvtColor(card, cv2.COLOR_BGR2GRAY)
    edges = cv2.Canny(gray, 50, 150)
    contours, _ = cv2.findContours(edges, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)
    candidates = []
    for contour in contours:
        x, y, w, h = cv2.boundingRect(contour)
        if (
            x >= width * 0.55
            and width * 0.14 <= w <= width * 0.32
            and height * 0.40 <= h <= height * 0.85
        ):
            candidates.append((x, y, w, h))
    if candidates:
        return max(candidates, key=lambda b: b[2] * b[3])
    return (
        round(width * 0.70),
        round(height * 0.20),
        round(width * 0.29),
        round(height * 0.68),
    )


def process_page(page_path, output_dir, page_no):
    image = cv2.imread(str(page_path))
    if image is None:
        return []
    height, width = image.shape[:2]
    boxes = detect_card_boxes(image)
    if not boxes:
        left = round(width * ratio("VOTER_GRID_LEFT_RATIO", 0.02))
        top = round(height * ratio("VOTER_GRID_HEADER_RATIO", 0.03))
        card_w = round(width * ratio("VOTER_GRID_CARD_WIDTH_RATIO", 0.288))
        card_h = round(height * ratio("VOTER_GRID_CARD_HEIGHT_RATIO", 0.088))
        gap_x = round(width * ratio("VOTER_GRID_GAP_X_RATIO", 0.006))
        gap_y = round(height * ratio("VOTER_GRID_GAP_Y_RATIO", 0.005))
        boxes = [
            (left + col * (card_w + gap_x), top + row * (card_h + gap_y), card_w, card_h)
            for row in range(int(os.getenv("VOTER_GRID_ROWS", "10")))
            for col in range(int(os.getenv("VOTER_GRID_COLUMNS", "3")))
        ]
    records = []
    for cell_no, (x, y, card_w, card_h) in enumerate(boxes, start=1):
            card = image[y:y + card_h, x:x + card_w]
            if card.size == 0:
                continue
            px, py, pw, ph = detect_photo_box(card)
            pad_x = max(2, round(pw * 0.04))
            pad_y = max(2, round(ph * 0.04))
            px = max(0, px - pad_x)
            py = max(0, py - pad_y)
            pw = min(card_w - px, pw + pad_x * 2)
            ph = min(card_h - py, ph + pad_y * 2)
            photo = card[py:py + ph, px:px + pw]
            photo_name = f"page-{page_no}-voter-{cell_no}.jpg"
            photo_file = output_dir / photo_name
            if photo.size:
                cv2.imwrite(str(photo_file), photo, [cv2.IMWRITE_JPEG_QUALITY, 92])

            gray = cv2.cvtColor(card, cv2.COLOR_BGR2GRAY)
            gray = cv2.resize(gray, None, fx=2.2, fy=2.2, interpolation=cv2.INTER_CUBIC)
            gray = cv2.fastNlMeansDenoising(gray, None, 8, 7, 21)
            gray = cv2.createCLAHE(2.0, (8, 8)).apply(gray)
            language = os.getenv("OCR_LANGUAGES", "hin+eng")
            text = pytesseract.image_to_string(gray, lang=language, config="--psm 6")

            epic_text = ocr_epic(card)
            record = parse_card(text, epic_text, str(photo_file), page_no, cell_no)
            house_digits = re.sub(r"\D", "", record["houseNumber"] or "")
            if not house_digits or set(house_digits).issubset({"1", "7"}):
                focused_house = ocr_house(card)
                if focused_house:
                    record["houseNumber"] = focused_house
            if not record["name"] or not record["voterId"]:
                threshold = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)[1]
                alternate_text = pytesseract.image_to_string(threshold, lang=language, config="--psm 11")
                alternate = parse_card(alternate_text, epic_text, str(photo_file), page_no, cell_no, record["houseNumber"])
                if alternate["confidence"] > record["confidence"]:
                    record = alternate
            if record["name"] or record["voterId"] or record["guardianName"] or record["houseNumber"] or record["age"]:
                record["needsReview"] = record["confidence"] < int(os.getenv("OCR_MIN_CONFIDENCE", "45")) or not record["name"] or not record["voterId"]
                records.append(record)
    return records


def read_header(page_path):
    image = cv2.imread(str(page_path))
    if image is None:
        return ""
    height, width = image.shape[:2]
    header = image[0:round(height * 0.12), 0:width]
    gray = cv2.cvtColor(header, cv2.COLOR_BGR2GRAY)
    gray = cv2.resize(gray, None, fx=2.2, fy=2.2, interpolation=cv2.INTER_CUBIC)
    gray = cv2.createCLAHE(2.0, (8, 8)).apply(gray)
    english = pytesseract.image_to_string(
        gray,
        lang="eng",
        config="--psm 6",
    )
    hindi = pytesseract.image_to_string(
        gray,
        lang=os.getenv("OCR_LANGUAGES", "hin+eng"),
        config="--psm 6",
    )
    return english + "\n" + hindi

def parse_header_numbers(text):
    value = text or ""
    digit_map = str.maketrans("\u0966\u0967\u0968\u0969\u096a\u096b\u096c\u096d\u096e\u096f", "0123456789")
    assembly = re.search(
        r"\u0935\u093f\u0927\u093e\u0928\s*\u0938\u092d\u093e\s*\u0915\u094d\u0937\u0947\u0924\u094d\u0930\s*\u0915\u0940\s*\u0938\u0902\u0916\u094d\u092f\u093e\s*\u0935\s*\u0928\u093e\u092e\s*[:\uff1a]?\s*([0-9\u0966-\u096f]{2,3})\s*[-\u2013:]?\s*(.+?)(?=\s+\u092d\u093e\u0917\s*\u0938\u0902\u0916\u094d\u092f\u093e|\n|$)", value)
    part = re.search(r"\u092d\u093e\u0917\s*\u0938\u0902\u0916\u094d\u092f\u093e\s*[:\uff1a]*\s*([0-9\u0966-\u096f]+)", value)
    section = re.search(r"\u0905\u0928\u0941\u092d\u093e\u0917\s*\u0915\u0940\s*\u0938\u0902\u0916\u094d\u092f\u093e\s*\u0935\s*\u0928\u093e\u092e\s*[:\uff1a]?\s*([0-9\u0966-\u096f]+)\s*[-\u2013:]\s*([^\n]+)", value)
    number = lambda match, index: clean(match.group(index)).translate(digit_map) if match else ""
    return {
        "assemblyNumber": number(assembly, 1),
        "assemblyName": clean(assembly.group(2)) if assembly else "",
        "partNumber": number(part, 1),
        "sectionNumber": number(section, 1),
        "sectionName": clean(section.group(2)).strip(" -,:|") if section else "",
    }

def main():
    payload = json.loads(sys.stdin.read())
    pages = [Path(item) for item in payload["pages"]]
    output_dir = Path(payload["outputDir"])
    output_dir.mkdir(parents=True, exist_ok=True)
    if os.getenv("TESSERACT_PATH"):
        pytesseract.pytesseract.tesseract_cmd = os.getenv("TESSERACT_PATH")
    headers = [read_header(page) for page in pages]
    page_headers = [parse_header_numbers(header) for header in headers]
    workers = max(1, min(int(os.getenv("OCR_PAGE_CONCURRENCY", "2")), len(pages)))
    with ThreadPoolExecutor(max_workers=workers) as executor:
        page_records = list(executor.map(
            lambda item: process_page(item[1], output_dir, item[0]),
            enumerate(pages, start=1),
        ))
    records = []
    summary_marker = "\u0928\u093e\u092e\u093e\u0935\u0932\u0940 \u0915\u093e \u092a\u094d\u0930\u0915\u093e\u0930"
    for index, result in enumerate(page_records):
        if summary_marker in clean(headers[index]):
            continue
        page_header = {key: value for key, value in page_headers[index].items() if value}
        for record in result:
            merged = {**record, **page_header}
            if record.get("sectionNumber") and not page_header.get("sectionNumber"):
                merged["sectionNumber"] = record["sectionNumber"]
            records.append(merged)
    header_text = "\n".join(headers[:3])
    print(json.dumps({
        "records": records,
        "headerText": header_text,
        "header": parse_header_numbers(header_text),
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()












