import urllib.request
import urllib.parse
import json
import sys

BASE_URL = "http://127.0.0.1:8000/api/v1"

def make_request(url_path, method="GET", data=None, token=None):
    url = f"{BASE_URL}{url_path}"
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
        
    req_data = None
    if data:
        req_data = json.dumps(data).encode("utf-8")
        
    req = urllib.request.Request(url, data=req_data, headers=headers, method=method)
    
    try:
        with urllib.request.urlopen(req) as response:
            res_data = response.read().decode("utf-8")
            return json.loads(res_data) if res_data else {}
    except urllib.error.HTTPError as e:
        print(f"\n[ERROR] Request to {url_path} failed with code {e.code}")
        try:
            error_body = e.read().decode("utf-8")
            print(f"Error details: {error_body}")
        except Exception:
            pass
        return None
    except Exception as e:
        print(f"\n[ERROR] Request to {url_path} encountered an error: {str(e)}")
        return None

def run_tests():
    print("=" * 60)
    print("STARTING BACKEND API INTEGRATION TESTS")
    print("=" * 60)

    # 1. Health Check
    print("\n1. Testing Health Check...")
    health = make_request("/health")
    if health:
        print(f"   [SUCCESS] Health check status: {health.get('status')}")
    else:
        print("   [FAILED] Health check failed.")
        sys.exit(1)

    # 2. Login
    print("\n2. Testing Admin Login...")
    login_payload = {
        "email": "admin@smartattend.com",
        "password": "admin123"
    }
    login_res = make_request("/auth/login", method="POST", data=login_payload)
    if login_res and "access_token" in login_res:
        print("   [SUCCESS] Login successful!")
        token = login_res["access_token"]
    else:
        print("   [FAILED] Login failed. Verify admin credentials and seeding.")
        sys.exit(1)

    # 3. Get profile
    print("\n3. Testing Get Profile (/auth/me)...")
    me = make_request("/auth/me", token=token)
    if me:
        print(f"   [SUCCESS] Profile retrieved. Name: '{me.get('name')}', Role: '{me.get('role')}'")
    else:
        print("   [FAILED] Profile retrieval failed.")

    # 4. List Subjects
    print("\n4. Testing List Subjects (/subjects/)...")
    subjects = make_request("/subjects/", token=token)
    if subjects is not None:
        print(f"   [SUCCESS] Subjects retrieved: {len(subjects)} subjects found.")
    else:
        print("   [FAILED] Subject retrieval failed.")

    # 5. List Students
    print("\n5. Testing List Students (/students/)...")
    students = make_request("/students/", token=token)
    if students is not None:
        print(f"   [SUCCESS] Students retrieved: {len(students)} students found.")
    else:
        print("   [FAILED] Student retrieval failed.")

    # 6. List Faculty
    print("\n6. Testing List Faculty (/faculty/)...")
    faculty = make_request("/faculty/", token=token)
    if faculty is not None:
        print(f"   [SUCCESS] Faculty retrieved: {len(faculty)} faculty members found.")
    else:
        print("   [FAILED] Faculty retrieval failed.")

    # 7. List Classes
    print("\n7. Testing List Classes (/classes/)...")
    classes = make_request("/classes/", token=token)
    if classes is not None:
        print(f"   [SUCCESS] Classes retrieved: {len(classes)} sessions found.")
    else:
        print("   [FAILED] Class session retrieval failed.")

    # 8. Student Login
    print("\n8. Testing Student Login (/student-auth/login)...")
    student_payload = {
        "roll_number": "S1001",
        "password": "student123"
    }
    student_res = make_request("/student-auth/login", method="POST", data=student_payload)
    if student_res and "access_token" in student_res:
        print("   [SUCCESS] Student login successful!")
        student_token = student_res["access_token"]
    else:
        print("   [FAILED] Student login failed.")
        student_token = None

    # 9. Liveness Challenge Request
    if student_token and classes and len(classes) > 0:
        class_id = classes[0]["id"]
        print(f"\n9. Testing Request Liveness Challenge (/attendance/challenge for Class {class_id})...")
        
        # Use urlencoded form data for /attendance/challenge endpoint
        url = f"{BASE_URL}/attendance/challenge"
        form_data = urllib.parse.urlencode({"class_id": class_id}).encode("utf-8")
        req = urllib.request.Request(
            url, 
            data=form_data, 
            headers={
                "Content-Type": "application/x-www-form-urlencoded",
                "Authorization": f"Bearer {student_token}"
            },
            method="POST"
        )
        try:
            with urllib.request.urlopen(req) as response:
                chal_res = json.loads(response.read().decode("utf-8"))
                if "challenge_id" in chal_res:
                    print(f"   [SUCCESS] Challenge generated successfully!")
                    print(f"             Challenge ID: {chal_res.get('challenge_id')}")
                    print(f"             Type: '{chal_res.get('challenge_type')}'")
                    print(f"             Instruction: '{chal_res.get('instruction')}'")
                else:
                    print("   [FAILED] Challenge generation returned invalid response.")
        except Exception as e:
            print(f"   [FAILED] Challenge generation request error: {str(e)}")

    print("\n" + "=" * 60)
    print("ALL API INTEGRATION TESTS COMPLETED")
    print("=" * 60)

if __name__ == "__main__":
    run_tests()
