import json
import gc
import os
import re
import sys
from pathlib import Path

import cv2
import pytesseract

cv2.setNumThreads(1)

sys.stdin.reconfigure(encoding="utf-8")
sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")


def ratio(name, default):
    return float(os.getenv(name, default))


def report_card_progress(page_no, cell_no):
    print(json.dumps({
        "type": "card_progress",
        "page": page_no,
        "cell": cell_no,
    }), file=sys.stderr, flush=True)


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
    name_line_pattern = r"नाम\s*[:：;\-]?\s*(.+)$"
    relation_line_pattern = r"(?:पिता|पि\S*|पति|पत्ति|प्रति|माता)\s*(?:का)?\s*नाम"
    fallback_name = ""
    for line in (text or "").splitlines():
        if "नाम" not in line or re.search(relation_line_pattern, line):
            continue
        fallback_name = clean_person_name(field(line, name_line_pattern))
        if fallback_name:
            break
    name = fallback_name
    name = clean_person_name(field(text, r"(?:निर्वा\S*|मतदाता)\s*(?:का)?\s*नाम\s*[:：;\-]?\s*([^\n]+)"))
    name = name or fallback_name
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
        print(json.dumps({"type": "progress", "page": page_no}), file=sys.stderr, flush=True)
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
    language = os.getenv("OCR_LANGUAGES", "hin+eng")
    page_data = pytesseract.image_to_data(
        image,
        lang=language,
        config="--psm 6",
        output_type=pytesseract.Output.DICT,
    )
    words = []
    for index, value in enumerate(page_data.get("text", [])):
        value = clean(value)
        try:
            confidence = float(page_data["conf"][index])
        except (TypeError, ValueError):
            confidence = -1
        if not value or confidence < 15:
            continue
        words.append({
            "text": value,
            "left": int(page_data["left"][index]),
            "top": int(page_data["top"][index]),
            "width": int(page_data["width"][index]),
            "height": int(page_data["height"][index]),
            "line": (
                page_data["block_num"][index],
                page_data["par_num"][index],
                page_data["line_num"][index],
            ),
        })

    # One English coordinate pass recovers EPICs without per-card processes.
    epic_data = pytesseract.image_to_data(
        image,
        lang="eng",
        config="--psm 11 -c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/",
        output_type=pytesseract.Output.DICT,
    )
    epic_words = []
    for index, value in enumerate(epic_data.get("text", [])):
        value = clean(value)
        if not value:
            continue
        epic_words.append({
            "text": value,
            "left": int(epic_data["left"][index]),
            "top": int(epic_data["top"][index]),
            "width": int(epic_data["width"][index]),
            "height": int(epic_data["height"][index]),
        })
    records = []
    fallback_limit = max(0, int(os.getenv("OCR_CARD_FALLBACKS_PER_PAGE", "3")))
    fallbacks_used = 0
    for cell_no, (x, y, card_w, card_h) in enumerate(boxes, start=1):
            card = image[y:y + card_h, x:x + card_w]
            if card.size == 0:
                report_card_progress(page_no, cell_no)
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

            card_words = [word for word in words if (
                x <= word["left"] + word["width"] / 2 <= x + card_w
                and y <= word["top"] + word["height"] / 2 <= y + card_h
            )]
            grouped = {}
            for word in card_words:
                grouped.setdefault(word["line"], []).append(word)
            text = "\n".join(
                " ".join(word["text"] for word in sorted(line, key=lambda item: item["left"]))
                for line in sorted(grouped.values(), key=lambda line: (line[0]["top"], line[0]["left"]))
            )
            if not text and fallbacks_used < fallback_limit:
                gray = cv2.cvtColor(card, cv2.COLOR_BGR2GRAY)
                gray = cv2.resize(gray, None, fx=1.6, fy=1.6, interpolation=cv2.INTER_CUBIC)
                text = pytesseract.image_to_string(gray, lang=language, config="--psm 6")
                fallbacks_used += 1

            epic_text = " ".join(word["text"] for word in epic_words if (
                x <= word["left"] + word["width"] / 2 <= x + card_w
                and y <= word["top"] + word["height"] / 2 <= y + round(card_h * 0.38)
            ))
            if not epic_from(epic_text):
                epic_text = ocr_epic(card)
            record = parse_card(text, epic_text, str(photo_file), page_no, cell_no)
            if os.getenv("OCR_DEEP_RETRY", "false").lower() == "true" and (not record["name"] or not record["voterId"]):
                gray = cv2.cvtColor(card, cv2.COLOR_BGR2GRAY)
                gray = cv2.resize(gray, None, fx=1.8, fy=1.8, interpolation=cv2.INTER_CUBIC)
                threshold = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)[1]
                alternate_text = pytesseract.image_to_string(threshold, lang=language, config="--psm 11")
                alternate = parse_card(alternate_text, "", str(photo_file), page_no, cell_no, record["houseNumber"])
                if alternate["confidence"] > record["confidence"]:
                    record = alternate
            if record["name"] or record["voterId"] or record["guardianName"] or record["houseNumber"] or record["age"]:
                record["needsReview"] = record["confidence"] < int(os.getenv("OCR_MIN_CONFIDENCE", "45")) or not record["name"] or not record["voterId"]
                records.append(record)
            report_card_progress(page_no, cell_no)
    print(json.dumps({"type": "progress", "page": page_no}), file=sys.stderr, flush=True)
    return records


def read_header(page_path):
    image = cv2.imread(str(page_path))
    if image is None:
        return ""
    height, width = image.shape[:2]
    header = image[0:round(height * 0.22), 0:width]
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
    normalized = re.sub(r"[ \t]+", " ", value.replace("\r", "\n"))
    digit_map = str.maketrans("०१२३४५६७८९OQILSZBG", "012345678900112586")

    def normalize_digits(raw):
        return clean(raw or "").translate(digit_map)

    def first_match(patterns):
        for pattern in patterns:
            match = re.search(pattern, normalized, re.IGNORECASE | re.MULTILINE)
            if match:
                return match
        return None

    def tidy_name(raw):
        name = clean(raw or "").strip(" -,:|।")
        name = re.sub(
            r"\s*(?:भाग\s*(?:संख्या|नं)|अनुभाग|मतदान\s*केन्द्र|निर्वाचक|नामावली).*$",
            "",
            name,
            flags=re.IGNORECASE,
        ).strip(" -,:|।")
        return name

    assembly = first_match([
        # Voter rolls often print: विधानसभा क्षेत्र की संख्या, नाम व आरक्षण स्थिति : 179 - सहाड़ा (सामान्य)
        r"विधान\s*सभा\s*(?:क्षेत्र)?[^\n:：]{0,100}[:：]\s*([0-9०-९OQILSZBG]{1,3})\s*[-–:]\s*([^\n]+)",
        r"(?:assembly\s*(?:constituency)?|AC)[^\n:：]{0,80}[:：]?\s*([0-9OQILSZBG]{1,3})\s*[-–:]\s*([^\n]+)",
    ])
    part = first_match([
        r"(?:भाग|part)\s*(?:संख्या|नं\.?|number|no\.?)?\s*[:：-]*\s*([0-9०-९OQILSZBG]{1,4})",
    ])

    section_map = {}
    section_block = re.search(
        r"(?:अनुभागों?|sections?)[^\n:：]{0,100}[:：]\s*(.+?)(?=\n\s*(?:मतदान\s*केन्द्र|मतदान\s*केंद्र|भाग\s*संख्या|पिन\s*कोड|\d+\s*[).]\s*नामावली|$))",
        normalized,
        re.IGNORECASE | re.DOTALL,
    )
    section_source = section_block.group(1) if section_block else normalized
    for match in re.finditer(
        r"(?:^|\n)\s*([0-9०-९OQILSZBG]{1,3})\s*[-–.)]\s*([^\n]+)",
        section_source,
        re.IGNORECASE,
    ):
        number = normalize_digits(match.group(1))
        name = tidy_name(match.group(2))
        if number and name and not re.search(r"(?:EPIC|RJ/|मतदाता|निर्वाचक)", name, re.IGNORECASE):
            section_map[number] = name

    section = first_match([
        r"(?:अनुभाग|section)[^\n:：]{0,80}[:：]\s*([0-9०-९OQILSZBG]{1,3})\s*[-–:]\s*([^\n]+)",
        r"(?:अनुभाग|section)\s*(?:की)?\s*(?:संख्या|नं\.?|number|no\.?)?\s*(?:व|एवं|and)?\s*(?:नाम|name)?\s*[:：-]*\s*([0-9०-९OQILSZBG]{1,3})\s*[-–:]\s*([^\n]+)",
    ])
    section_number = normalize_digits(section.group(1)) if section else ""
    section_name = tidy_name(section.group(2)) if section else ""
    if section_number and section_number in section_map:
        section_name = section_map[section_number]

    return {
        "assemblyNumber": normalize_digits(assembly.group(1)) if assembly else "",
        "assemblyName": tidy_name(assembly.group(2)) if assembly else "",
        "partNumber": normalize_digits(part.group(1)) if part else "",
        "sectionNumber": section_number,
        "sectionName": section_name,
        "sectionMap": section_map,
    }

def main():
    payload = json.loads(sys.stdin.read())
    pages = [Path(item) for item in payload["pages"]]
    page_numbers = payload.get("pageNumbers") or list(range(1, len(pages) + 1))
    if len(page_numbers) != len(pages):
        raise ValueError("pageNumbers must match pages")
    output_dir = Path(payload["outputDir"])
    output_dir.mkdir(parents=True, exist_ok=True)
    if os.getenv("TESSERACT_PATH"):
        pytesseract.pytesseract.tesseract_cmd = os.getenv("TESSERACT_PATH")
    def process_page_bundle(item):
        page_no, page = item
        # Header OCR used to run sequentially for every page before any voter
        # card work began. Keep the header associated with its page, but run it
        # inside the same bounded worker pool so useful card progress starts
        # early and low-CPU deployments do not spend minutes at 0/26.
        header = read_header(page)
        return header, process_page(page, output_dir, page_no)

    page_bundles = []
    for item in zip(page_numbers, pages):
        page_bundles.append(process_page_bundle(item))
        gc.collect()
    headers = [bundle[0] for bundle in page_bundles]
    page_records = [bundle[1] for bundle in page_bundles]
    page_headers = [parse_header_numbers(header) for header in headers]
    records = []
    summary_marker = "\u0928\u093e\u092e\u093e\u0935\u0932\u0940 \u0915\u093e \u092a\u094d\u0930\u0915\u093e\u0930"
    for index, result in enumerate(page_records):
        if summary_marker in clean(headers[index]):
            continue
        raw_header = page_headers[index]
        section_map = raw_header.get("sectionMap") or {}
        page_header = {key: value for key, value in raw_header.items() if value and key != "sectionMap"}
        if len(section_map) > 1:
            page_header.pop("sectionNumber", None)
            page_header.pop("sectionName", None)
        for record in result:
            merged = {**record, **page_header}
            if record.get("sectionNumber"):
                merged["sectionNumber"] = record["sectionNumber"]
            section_key = str(merged.get("sectionNumber") or "").strip()
            if section_key and section_map.get(section_key):
                merged["sectionName"] = section_map[section_key]
            records.append(merged)
    header_text = "\n".join(headers[:3])
    print(json.dumps({
        "records": records,
        "headerText": header_text,
        "header": parse_header_numbers(header_text),
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()












