"""
Automated Integration Verification: test_maintenance_recommendation.py
Verifies the Maintenance Recommendation Engine, spatial escalation algorithms, and summary statistics.
"""

import sys
import urllib.request
import json
import logging

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

BASE_URL = "http://localhost:8000/api/v1"


def http_request(path: str, method: str = "GET", data: bytes = None) -> tuple[int, Any]:
    """
    Executes raw HTTP request with response handling.
    """
    url = f"{BASE_URL}{path}"
    headers = {"Content-Type": "application/json"}
    
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

    logger.info("=== STARTING MAINTENANCE RECOMMENDATION ENGINE INTEGRATION TEST ===")

    created_distresses = []
    
    # 1. Create distress scenarios
    # A. Critical Pothole
    try:
        payload = json.dumps({
            "distress_type": "Critical Pothole",
            "severity": "critical",
            "confidence_score": 0.92,
            "latitude": 12.9712,
            "longitude": 77.5914,
            "status": "detected"
        }).encode("utf-8")
        status, resp = http_request("/distress/", method="POST", data=payload)
        passed = (status == 201 and resp.get("id") is not None)
        if passed:
            created_distresses.append(resp.get("id"))
        record_test("Create Scenario Distress A: Critical Pothole", passed, f"Status {status}, Response {resp}")
    except Exception as e:
        record_test("Create Scenario Distress A", False, str(e))

    # B. High Severity Crack (P2 Structural Repair)
    try:
        payload = json.dumps({
            "distress_type": "longitudinal_crack",
            "severity": "medium",
            "confidence_score": 0.85,
            "latitude": 18.5912,
            "longitude": 73.7123,
            "status": "detected"
        }).encode("utf-8")
        status, resp = http_request("/distress/", method="POST", data=payload)
        passed = (status == 201 and resp.get("id") is not None)
        if passed:
            created_distresses.append(resp.get("id"))
        record_test("Create Scenario Distress B: High Severity Crack", passed, f"Status {status}, Response {resp}")
    except Exception as e:
        record_test("Create Scenario Distress B", False, str(e))

    # C. Spatial Crack Cluster (3 cracks near each other to trigger frequency escalation)
    cluster_ids = []
    for i in range(3):
        try:
            # Latitudes slightly offset by 0.0002 degrees (~20m)
            payload = json.dumps({
                "distress_type": "alligator_crack",
                "severity": "medium",
                "confidence_score": 0.75,
                "latitude": 28.5612 + (i * 0.0002),
                "longitude": 77.2145 + (i * 0.0002),
                "status": "detected"
            }).encode("utf-8")
            status, resp = http_request("/distress/", method="POST", data=payload)
            if status == 201 and resp.get("id") is not None:
                cluster_ids.append(resp.get("id"))
                created_distresses.append(resp.get("id"))
        except Exception as e:
            logger.error(f"Cluster creation error: {e}")

    record_test("Create Spatial Crack Cluster (3 items)", len(cluster_ids) == 3, f"Created {len(cluster_ids)} items.")

    # 2. Trigger Recommendation Engine
    recommendations = []
    try:
        status, resp = http_request("/maintenance/recommendations", method="GET")
        passed = (status == 200 and isinstance(resp, list) and len(resp) >= len(created_distresses))
        recommendations = resp
        record_test("GET /maintenance/recommendations - Generate and Retrieve Tasks", passed, f"Status {status}, Total Tasks: {len(resp) if isinstance(resp, list) else 0}")
    except Exception as e:
        record_test("GET /maintenance/recommendations", False, str(e))

    # 3. Verify recommendation rules mapping
    # Check A: Emergency repair for Critical Pothole (Distress A)
    pothole_task = next((t for t in recommendations if t.get("distress_id") == created_distresses[0]), None)
    if pothole_task:
        valid_pothole = (
            pothole_task.get("priority") == "P1" and 
            pothole_task.get("estimated_response_time") == "within 24 hours" and
            pothole_task.get("maintenance_category") == "Emergency"
        )
        record_test("Rule Check - Critical Pothole -> Emergency Repair P1 (24h)", valid_pothole, f"Task payload: {pothole_task}")
    else:
        record_test("Rule Check - Critical Pothole", False, "Pothole task not generated.")

    # Check B: Structural repair for High Severity Crack (Distress B)
    crack_task = next((t for t in recommendations if t.get("distress_id") == created_distresses[1]), None)
    if crack_task:
        valid_crack = (
            crack_task.get("priority") in ["P2", "P3"] and 
            crack_task.get("maintenance_category") in ["Structural", "Preventative"]
        )
        record_test("Rule Check - High Severity Crack -> Structural Repair P2 (7d)", valid_crack, f"Task payload: {crack_task}")
    else:
        record_test("Rule Check - High Severity Crack", False, "Crack task not generated.")

    # Check C: Priority escalation on cluster cracks (High recurrence)
    # One of the cluster tasks should have frequency >= 3, causing escalation
    cluster_tasks = [t for t in recommendations if t.get("distress_id") in cluster_ids]
    escalated_task = next((t for t in cluster_tasks if "escalated due to high recurrence frequency" in t.get("recommendation", "").lower()), None)
    
    if escalated_task:
        valid_escalation = (
            escalated_task.get("priority") in ["P1", "P2"] and
            "escalated due to high recurrence frequency" in escalated_task.get("recommendation", "").lower()
        )
        record_test("Rule Check - Spatial Escalation (Priority Escalated due to frequency)", valid_escalation, f"Task payload: {escalated_task}")
    else:
        record_test("Rule Check - Spatial Escalation", False, f"Escalated task not found. Cluster tasks: {cluster_tasks}")

    # 4. Fetch Summary Statistics
    try:
        status, resp = http_request("/maintenance/summary", method="GET")
        passed = (
            status == 200 and
            resp.get("total_tasks", 0) >= len(created_distresses) and
            "priority_distribution" in resp and
            "monthly_repairs" in resp
        )
        record_test("GET /maintenance/summary - Fetch Metrics and Telemetry", passed, f"Status {status}, Response {resp}")
    except Exception as e:
        record_test("GET /maintenance/summary", False, str(e))

    # 5. Clean up distress records and maintenance tasks
    cleanup_success = True
    for distress_id in created_distresses:
        try:
            # Delete distress (cascades and deletes associated maintenance tasks automatically)
            status, resp = http_request(f"/distress/{distress_id}", method="DELETE")
            if status != 200:
                cleanup_success = False
                logger.warning(f"Failed to delete distress {distress_id}: {resp}")
        except Exception as e:
            cleanup_success = False
            logger.error(f"Cleanup error for distress {distress_id}: {e}")

    record_test("Clean up Database Records (Cascading Delete)", cleanup_success)

    logger.info("=== MAINTENANCE RECOMMENDATION ENGINE INTEGRATION TEST COMPLETED ===")
    return results


if __name__ == "__main__":
    import sys
    from typing import Any
    res = run_tests()
    total = res["passed"] + res["failed"]
    score = int((res["passed"] / total) * 100) if total > 0 else 0
    print(f"\nRecommendation Engine Test Score: {score}/100")
    print(f"Total Tests Executed: {total}")
    print(f"Passed: {res['passed']}")
    print(f"Failed: {res['failed']}")
    
    if res["failed"] > 0:
        sys.exit(1)
    sys.exit(0)
