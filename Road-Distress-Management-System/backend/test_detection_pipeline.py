"""
Automated Integration Verification: test_detection_pipeline.py
Verifies the end-to-end video detection pipeline including uploading, triggering, polling, querying, and deletion.
"""

import sys
import os
import urllib.request
import json
import logging
import time
import numpy as np
import cv2

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

BASE_URL = "http://localhost:8000/api/v1"


def create_temp_video(filename="temp_test_run.mp4"):
    """
    Creates a valid 2-second blank video file with OpenCV to ensure VideoCapture opens successfully.
    """
    logger.info(f"Creating a valid temporary dummy video for testing: {filename}")
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(filename, fourcc, 30.0, (640, 480))
    for i in range(60):  # 60 frames = 2 seconds at 30 fps
        frame = np.zeros((480, 640, 3), dtype=np.uint8)
        # Draw moving circle to simulate real video content
        cv2.circle(frame, (100 + i * 5, 240), 50, (0, 0, 255), -1)
        out.write(frame)
    out.release()
    logger.info("Temporary dummy video created successfully.")


def encode_multipart_formdata(fields: dict, files: list) -> tuple[dict, bytes]:
    """
    Encodes fields and files into multipart/form-data byte string for urllib upload.
    """
    boundary = b"----MultipartFormBoundaryUrllibClient"
    lines = []
    
    # Add form fields
    for key, val in fields.items():
        if val is not None:
            lines.append(b"--" + boundary)
            lines.append(f'Content-Disposition: form-data; name="{key}"'.encode("utf-8"))
            lines.append(b"")
            lines.append(str(val).encode("utf-8"))
            
    # Add files
    for key, filename, file_data, content_type in files:
        lines.append(b"--" + boundary)
        lines.append(f'Content-Disposition: form-data; name="{key}"; filename="{filename}"'.encode("utf-8"))
        lines.append(f"Content-Type: {content_type}".encode("utf-8"))
        lines.append(b"")
        lines.append(file_data)
        
    lines.append(b"--" + boundary + b"--")
    lines.append(b"")
    body = b"\r\n".join(lines)
    
    headers = {
        "Content-Type": f"multipart/form-data; boundary={boundary.decode('utf-8')}",
        "Content-Length": str(len(body))
    }
    return headers, body


def http_request(path: str, method: str = "GET", data: bytes = None, headers: dict = None) -> tuple[int, dict]:
    """
    Executes raw HTTP request with response handling.
    """
    url = f"{BASE_URL}{path}"
    if headers is None:
        headers = {}
    
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            body_bytes = resp.read()
            body_str = body_bytes.decode("utf-8")
            return resp.status, json.loads(body_str) if body_str else {}
    except urllib.error.HTTPError as e:
        body_bytes = e.read()
        body_str = body_bytes.decode("utf-8")
        try:
            res_body = json.loads(body_str)
        except Exception:
            res_body = {"detail": body_str}
        return e.code, res_body
    except Exception as e:
        return 500, {"detail": str(e)}


def run_tests() -> dict:
    results = {"passed": 0, "failed": 0, "details": []}

    def record_test(name: str, passed: bool, error_msg: str = ""):
        if passed:
            results["passed"] += 1
            results["details"].append(f"PASS: {name}")
            logger.info(f"PASS: {name}")
        else:
            results["failed"] += 1
            results["details"].append(f"FAIL: {name} - {error_msg}")
            logger.error(f"FAIL: {name} - {error_msg}")

    logger.info("=== STARTING AI DETECTION PIPELINE INTEGRATION TEST ===")

    temp_video_name = "temp_test_run.mp4"
    try:
        create_temp_video(temp_video_name)
        with open(temp_video_name, "rb") as f:
            video_bytes = f.read()
    except Exception as e:
        record_test("Prepare Temporary Video File", False, str(e))
        return results

    video_id = None
    
    # 1. Upload Video
    try:
        headers, body = encode_multipart_formdata(
            fields={},
            files=[("file", "temp_test_run.mp4", video_bytes, "video/mp4")]
        )
        status, resp = http_request("/videos/upload", method="POST", data=body, headers=headers)
        passed = (status == 201 and resp.get("processing_status") == "pending")
        video_id = resp.get("id")
        record_test("POST /videos/upload - Upload Test Video", passed, f"Status {status}, Response {resp}")
    except Exception as e:
        record_test("POST /videos/upload - Upload Test Video", False, str(e))

    if not video_id:
        record_test("Pipeline Execution", False, "Skipping: Video upload failed.")
        if os.path.exists(temp_video_name):
            os.remove(temp_video_name)
        return results

    # 2. Trigger detection pipeline
    try:
        status, resp = http_request(f"/detection/video/{video_id}", method="POST")
        passed = (status == 202 and resp.get("status") == "processing")
        record_test("POST /detection/video/{id} - Trigger Pipeline", passed, f"Status {status}, Response {resp}")
    except Exception as e:
        record_test("POST /detection/video/{id} - Trigger Pipeline", False, str(e))

    # 3. Poll status until completed or failed
    try:
        max_attempts = 100
        current_attempt = 0
        is_completed = False
        processing_status = "pending"
        
        while current_attempt < max_attempts:
            time.sleep(1.0)
            status, resp = http_request(f"/videos/{video_id}")
            if status == 200:
                processing_status = resp.get("processing_status")
                logger.info(f"Polling video status: attempt {current_attempt + 1}, status={processing_status}")
                if processing_status in ["completed", "failed"]:
                    if processing_status == "completed":
                        is_completed = True
                    break
            else:
                logger.warning(f"Failed to query video status: status code {status}")
            current_attempt += 1
            
        record_test("AI Pipeline Background Task Execution", is_completed, f"Final status: {processing_status}")
    except Exception as e:
        record_test("AI Pipeline Background Task Execution", False, str(e))

    # 4. Fetch results
    try:
        status, resp = http_request(f"/detection/results/{video_id}")
        passed = (status == 200 and isinstance(resp, list))
        record_test("GET /detection/results/{id} - Fetch Detections", passed, f"Status {status}, Results count: {len(resp) if isinstance(resp, list) else 0}")
    except Exception as e:
        record_test("GET /detection/results/{id} - Fetch Detections", False, str(e))

    # 5. Fetch summary
    try:
        status, resp = http_request("/detection/summary")
        passed = (
            status == 200 and 
            "total_detections" in resp and 
            "distress_type_distribution" in resp and 
            "severity_distribution" in resp
        )
        record_test("GET /detection/summary - Fetch Analytics Summary", passed, f"Status {status}, Response {resp}")
    except Exception as e:
        record_test("GET /detection/summary - Fetch Analytics Summary", False, str(e))

    # 6. Delete video to clean up database and filesystem
    try:
        status, resp = http_request(f"/videos/{video_id}", method="DELETE")
        passed = (status == 200 and resp.get("id") == video_id)
        record_test("DELETE /videos/{id} - Clean Up Video and Files", passed, f"Status {status}, Response {resp}")
    except Exception as e:
        record_test("DELETE /videos/{id} - Clean Up Video and Files", False, str(e))

    # 7. Clean up temporary video source file
    if os.path.exists(temp_video_name):
        try:
            os.remove(temp_video_name)
            logger.info(f"Cleaned up local temporary video: {temp_video_name}")
        except Exception as e:
            logger.warning(f"Could not remove local temporary video {temp_video_name}: {e}")

    logger.info("=== AI DETECTION PIPELINE INTEGRATION TEST COMPLETED ===")
    return results


if __name__ == "__main__":
    res = run_tests()
    total = res["passed"] + res["failed"]
    score = int((res["passed"] / total) * 100) if total > 0 else 0
    print(f"\nAI Detection Pipeline Test Score: {score}/100")
    print(f"Total Tests Executed: {total}")
    print(f"Passed: {res['passed']}")
    print(f"Failed: {res['failed']}")
    
    if res["failed"] > 0:
        sys.exit(1)
    sys.exit(0)
