import cv2
import pytesseract
import pandas as pd
import numpy as np
import re
import base64

# ----------------- CONFIG -----------------
# Ensure this path is correct on your server machine
pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"

MIN_CONF_QTY = 40
MIN_CONF_ID = 40
# ------------------------------------------

def otsu_no_resize(gray, invert=False):
    if gray is None or gray.size == 0: return None
    blur = cv2.GaussianBlur(gray, (3, 3), 0)
    th = cv2.threshold(blur, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)[1]
    return 255 - th if invert else th

def otsu_for_ocr(gray, scale=3, invert=False):
    if gray is None or gray.size == 0: return None
    up = cv2.resize(gray, None, fx=scale, fy=scale, interpolation=cv2.INTER_CUBIC)
    blur = cv2.GaussianBlur(up, (3, 3), 0)
    th = cv2.threshold(blur, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)[1]
    return 255 - th if invert else th

def ocr_df(img, config, min_conf):
    if img is None or img.size == 0:
        return pd.DataFrame(columns=["text", "conf", "left", "top", "width", "height"])
    df = pytesseract.image_to_data(img, config=config, output_type=pytesseract.Output.DATAFRAME)
    df = df.dropna(subset=["text"])
    df["text"] = df["text"].astype(str).str.strip()
    df = df[df["text"] != ""]
    df["conf"] = pd.to_numeric(df["conf"], errors="coerce").fillna(-1)
    df = df[df["conf"] >= min_conf]
    return df

def extract_quantities(gray):
    th = otsu_no_resize(gray, invert=False)
    df = ocr_df(th, "--psm 6 --dpi 300 -c tessedit_char_whitelist=0123456789xX", MIN_CONF_QTY)

    qs = []
    seen_boxes = set()

    for _, r in df.iterrows():
        t = str(r["text"]).strip().lower()
        if re.fullmatch(r"\d+x", t):
            qty = int(t[:-1])
            x, y, w, h = int(r["left"]), int(r["top"]), int(r["width"]), int(r["height"])
            
            box_key = (x // 10, y // 10) 
            if box_key in seen_boxes: continue
            seen_boxes.add(box_key)

            # Includes 'qty_bbox' to prevent crashes
            qs.append({"qty": qty, "qty_bbox": (x, y, w, h), "cx": x + w / 2, "cy": y + h / 2})

    qs.sort(key=lambda d: d["cx"])
    return qs

def ocr_partnum_from_crop(crop_gray):
    if crop_gray is None or crop_gray.size == 0: return None

    h, w = crop_gray.shape[:2]
    if h < 20 or w < 20: return None

    best = None 
    for rotcode in (cv2.ROTATE_90_CLOCKWISE, cv2.ROTATE_90_COUNTERCLOCKWISE):
        rot = cv2.rotate(crop_gray, rotcode)
        for invert in (False, True):
            th = otsu_for_ocr(rot, scale=3, invert=invert)
            if th is None: continue

            df = ocr_df(th, "--psm 6 -c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789", MIN_CONF_ID)
            for _, r in df.iterrows():
                t = str(r["text"]).strip().replace(" ", "")
                if t.endswith(".0"): t = t[:-2]
                
                # Check for IDs like "105304" or "A"
                if len(t) >= 1 and re.match(r"^[A-Z0-9]+$", t):
                    conf = float(r["conf"])
                    if best is None or conf > best[1]:
                        best = (t, conf)
    return best

def assign_partnums_by_quantity(img_bgr):
    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
    quantities = extract_quantities(gray)

    h_img, w_img = gray.shape[:2]
    results = []

    for q in quantities:
        x, y, w, h = q["qty_bbox"]
        cx = q["cx"]

        # ⚠️ ORIGINAL LOGIC: Look 2.5x width around the quantity
        pad_x = int(max(80, w * 2.5))
        
        top_y = 0
        bottom_y = max(0, y - 5)
        left_x = max(0, int(cx - pad_x))
        right_x = min(w_img, int(cx + pad_x))

        if bottom_y <= top_y or right_x <= left_x:
            best = None
            crop_box = (left_x, top_y, max(0, right_x - left_x), max(0, bottom_y - top_y))
        else:
            crop = gray[top_y:bottom_y, left_x:right_x]
            best = ocr_partnum_from_crop(crop)
            crop_box = (left_x, top_y, right_x - left_x, bottom_y - top_y)

        results.append({
            "qty": q["qty"],
            "qty_bbox": q["qty_bbox"], 
            "crop_box": crop_box,
            "partnum": best[0] if best else None,
            "partnum_conf": best[1] if best else None
        })

    return results

def analyze_single_crop_for_api(img_bgr):
    """
    Manual single crop analysis fallback
    """
    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
    config = "--psm 6 --dpi 300 -c tessedit_char_whitelist=0123456789xXabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-#"
    
    data = pytesseract.image_to_data(gray, config=config, output_type=pytesseract.Output.DICT)
    
    found_qty = 1 
    found_id = "UNKNOWN"
    best_conf = 0
    
    words = data['text']
    confs = data['conf']
    
    for i, word in enumerate(words):
        word = word.strip()
        if not word: continue
        
        conf = float(confs[i])
        if conf < 30: continue 
        
        if re.fullmatch(r"\d+[xX]", word) or re.fullmatch(r"[xX]\d+", word):
            nums = re.findall(r"\d+", word)
            if nums: found_qty = int(nums[0])
            
        elif (word.isdigit() and int(word) > 20) or (re.search(r"\d", word) and re.search(r"[a-zA-Z]", word)):
            if conf > best_conf:
                found_id = word
                best_conf = conf

    _, buffer = cv2.imencode('.png', img_bgr)
    img_base64 = base64.b64encode(buffer).decode('utf-8')

    return {
        "part_id": found_id,
        "quantity": found_qty,
        "image_base64": img_base64
    }

# ----------------- MAIN API FUNCTION -----------------
def analyze_image_for_api(img_bgr):
    assigned = assign_partnums_by_quantity(img_bgr)
    
    output_data = []
    H, W = img_bgr.shape[:2]

    for a in assigned:
        pid = a["partnum"] if a["partnum"] else "UNKNOWN"
        qty = a["qty"]

        # Restore original crop logic: Crop the calculated box
        cx, cy, cw, ch = a["crop_box"]
        cx2, cy2 = min(W, cx + cw), min(H, cy + ch)
        cx, cy = max(0, cx), max(0, cy)

        crop_disp = img_bgr[cy:cy2, cx:cx2].copy()
        
        if crop_disp.size == 0: continue

        # Draw red box for Qty (Debugging / Verification)
        qx, qy, qw, qh = a["qty_bbox"]
        ix1, iy1 = max(qx, cx), max(qy, cy)
        ix2, iy2 = min(qx + qw, cx2), min(qy + qh, cy2)

        if ix2 > ix1 and iy2 > iy1:
            cv2.rectangle(
                crop_disp,
                (ix1 - cx, iy1 - cy),
                (ix2 - cx, iy2 - cy),
                (0, 0, 255), 2
            )

        _, buffer = cv2.imencode('.png', crop_disp)
        img_base64 = base64.b64encode(buffer).decode('utf-8')

        output_data.append({
            "part_id": pid,
            "quantity": qty,
            "image_base64": img_base64
        })
        
    return output_data