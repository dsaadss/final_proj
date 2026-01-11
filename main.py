import uvicorn
from fastapi import FastAPI, File, UploadFile, Response
import requests
import base64
import subprocess
import time
import numpy as np
import cv2
import trimesh
import zipfile
import io
import os
from contextlib import asynccontextmanager

# --- IMPORT YOUR OCR FILE ---
import ocrtest5withimges 

# =========================================================
# ⚙️ CONFIGURATION
# =========================================================
BAT_FILE_PATH = r"C:\Users\yarden\python codes\hunyuan3d\5-start-api-server.bat"
WORKING_DIR = r"C:\Users\yarden\python codes\hunyuan3d"

model_server_process = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    global model_server_process
    print("\n🚀 [Pipeline] Launching .bat file...")
    try:
        model_server_process = subprocess.Popen(
            BAT_FILE_PATH, 
            cwd=WORKING_DIR,
            creationflags=subprocess.CREATE_NEW_CONSOLE
        )
        print("⏳ [Pipeline] Waiting 15 seconds for Model Server...")
        time.sleep(15) 
        print("✅ [Pipeline] Ready.\n")
    except Exception as e:
        print(f"❌ [Pipeline] Failed to start .bat file: {e}")
    yield
    print("\n🛑 [Pipeline] Shutting down...")
    if model_server_process:
        model_server_process.terminate()

app = FastAPI(lifespan=lifespan)
@app.get("/")
async def root_connection_test():
    """
    Provides a handshake for the Flutter app.
    When this is hit, the terminal will print a green success message.
    """
    # 🟢 Server-side Terminal Feedback
    # \033[92m is the ANSI escape code for GREEN text
    print("\n\033[92m" + " [SUCCESS] " + "\033[0m" + "Phone connected to Pipeline Server via Tailscale!")
    
    return {
        "status": "connected",
        "message": "Hello from the 3D Pipeline Server!",
        "timestamp": time.time()
    }
# =========================================================
# 🎨 HELPER: COLORING & ZIPPING
# =========================================================
def generate_color_variants_and_zip(original_glb_bytes):
    """
    Takes raw GLB bytes.
    Generates: White (Original), Black, Wood.
    Returns: Bytes of a ZIP file containing all 3.
    """
    print("🎨 Generating Color Variants...")
    
    # Define Colors [R, G, B, A]
    variants = {
        "white": None,  # Original
        "black": [40, 40, 40, 255], # Dark Grey
        "wood":  [139, 69, 19, 255] # Saddle Brown
    }

    # Load the original mesh from bytes
    original_mesh = trimesh.load(io.BytesIO(original_glb_bytes), file_type='glb', force='mesh')

    # Create a wrapper for the ZIP file
    zip_buffer = io.BytesIO()

    with zipfile.ZipFile(zip_buffer, "w", zipfile.ZIP_DEFLATED) as zip_file:
        for name, color in variants.items():
            filename = f"model_{name}.glb"
            
            if color is None:
                # Write original bytes directly
                zip_file.writestr(filename, original_glb_bytes)
            else:
                # Create colored copy
                colored_mesh = original_mesh.copy()
                # Apply color to all vertices
                colored_mesh.visual.vertex_colors = np.tile(color, (len(original_mesh.vertices), 1))
                
                # Export to bytes
                export_bytes = trimesh.exchange.gltf.export_glb(colored_mesh)
                zip_file.writestr(filename, export_bytes)
    
    print("✅ ZIP archive created with 3 variants.")
    return zip_buffer.getvalue()

# =========================================================
# 1. 3D GENERATION (HUNYUAN)
# =========================================================
def get_glb_from_hunyuan(image_bytes: bytes):
    print("Pipeline Server: Converting image to Base64...")
    img_b64_str = base64.b64encode(image_bytes).decode('utf-8')
    
    model_server_url = "http://127.0.0.1:8081/generate"
    json_payload = {"image": img_b64_str}
    
    print(f"Pipeline Server: Requesting model from {model_server_url}...")
    try:
        response = requests.post(model_server_url, json=json_payload, timeout=120)
        if response.status_code == 200:
            return response.content 
        else:
            print(f"Hunyuan Error: {response.status_code}")
            return None
    except Exception as e:
        print(f"Connection Error: {e}")
        return None

@app.post("/upload_image")
async def upload_and_process_image(file: UploadFile = File(...)):
    print(f"Flutter App: Uploaded 3D Request: {file.filename}")
    image_contents = await file.read()
    
    # 1. Get Raw Model
    raw_glb_bytes = get_glb_from_hunyuan(image_contents)
    
    if raw_glb_bytes:
        # 2. Generate Colors & Zip
        zip_bytes = generate_color_variants_and_zip(raw_glb_bytes)
        # 3. Return the ZIP file
        return Response(content=zip_bytes, media_type="application/zip")
    else:
        return Response(content="Error generating model", status_code=500)


# =========================================================
# 2. PARTS ANALYSIS (OCR)
# =========================================================
@app.post("/analyze_parts_page")
async def analyze_parts_page(file: UploadFile = File(...)):
    print(f"Flutter App: Uploaded Parts Page: {file.filename}")
    contents = await file.read()
    nparr = np.frombuffer(contents, np.uint8)
    img_bgr = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    if img_bgr is None:
        return {"error": "Could not decode image"}

    try:
        parts_data = ocrtest5withimges.analyze_image_for_api(img_bgr)
        print(f"✅ Found {len(parts_data)} parts.")
        return {"parts": parts_data}
    except Exception as e:
        print(f"❌ Error in OCR script: {e}")
        return {"error": str(e)}

@app.post("/analyze_single_crop")
async def analyze_single_crop(file: UploadFile = File(...)):
    print(f"Flutter App: Uploaded Manual Crop: {file.filename}")
    contents = await file.read()
    nparr = np.frombuffer(contents, np.uint8)
    img_bgr = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    if img_bgr is None:
        return {"error": "Could not decode image"}

    try:
        result = ocrtest5withimges.analyze_single_crop_for_api(img_bgr)
        print(f"✅ Analyzed Crop: {result}")
        return result
    except Exception as e:
        print(f"❌ Error in OCR: {e}")
        return {"error": str(e)}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)