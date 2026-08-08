import subprocess
import time
import sys
import re

PORT = 8080

def start_tunnel():
    print("=" * 70)
    print("  STARTING ZERO-PASSWORD PUBLIC TUNNEL FOR 4G/5G MOBILE ACCESS")
    print("=" * 70)
    
    # Try Localtunnel first
    try:
        print("[1/2] Connecting localtunnel instance...")
        proc = subprocess.Popen(
            "npx -y localtunnel --port 8080",
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1
        )
        
        tunnel_url = None
        start_time = time.time()
        while time.time() - start_time < 15:
            line = proc.stdout.readline()
            if not line:
                break
            sys.stdout.write(line)
            sys.stdout.flush()
            if "your url is:" in line.lower():
                tunnel_url = line.split("your url is:")[-1].strip()
                break
        
        if tunnel_url:
            print("\n" + "=" * 70)
            print(f"  PUBLIC MOBILE TUNNEL ACTIVE (4G/5G/Wi-Fi)")
            print(f"  URL: {tunnel_url}")
            print("=" * 70 + "\n")
            proc.wait()
            return
    except Exception as e:
        print(f"Localtunnel startup note: {e}")

    # Fallback to Pinggy via SSH
    try:
        print("[2/2] Attempting Pinggy SSH Tunnel Fallback...")
        cmd = ["ssh", "-o", "StrictHostKeyChecking=no", "-p", "443", "-R", f"0:localhost:{PORT}", "qr@a.pinggy.io"]
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1
        )
        for line in proc.stdout:
            sys.stdout.write(line)
            sys.stdout.flush()
    except Exception as e:
        print(f"Tunnel error: {e}")

if __name__ == "__main__":
    while True:
        try:
            start_tunnel()
        except KeyboardInterrupt:
            print("\nTunnel stopped by user.")
            sys.exit(0)
        except Exception as e:
            print(f"Tunnel connection lost ({e}). Restarting in 3 seconds...")
            time.sleep(3)
