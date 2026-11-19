import time
import sys
import threading
import httpx
import uvicorn
from pathlib import Path

# Add backend directory to sys.path
backend_dir = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(backend_dir))

from main import app

def run_server():
    uvicorn.run(app, host="127.0.0.1", port=8000, log_level="warning")

if __name__ == "__main__":
    server_thread = threading.Thread(target=run_server, daemon=True)
    server_thread.start()

    # Wait for server to initialize
    time.sleep(2)

    try:
        response = httpx.get("http://127.0.0.1:8000/api/v1/health", timeout=5.0)
        print("STATUS CODE:", response.status_code)
        print("HEALTH RESPONSE:", response.json())
        
        root_response = httpx.get("http://127.0.0.1:8000/", timeout=5.0)
        print("ROOT RESPONSE:", root_response.json())

        if response.status_code == 200 and response.json().get("status") == "healthy":
            print("VERIFICATION_SUCCESS")
            sys.exit(0)
        else:
            print("VERIFICATION_FAILED")
            sys.exit(1)
    except Exception as e:
        print("ERROR:", e)
        sys.exit(1)
