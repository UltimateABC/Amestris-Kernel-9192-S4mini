import os
import re
import requests
from urllib.parse import unquote
import argparse

""" CODENAME N3V3RM0R3 """

def extract_uuid(file_path, debug=False):
    """Extract the UUID from the specified file."""
    try:
        if debug:
            print(f"DEBUG: Reading UUID from file: {file_path}")
        with open(file_path, "r") as file:
            for line in file:
                if line.startswith("UUID="):
                    uuid = line.split("=")[1].strip()
                    if debug:
                        print(f"DEBUG: Found UUID: {uuid}")
                    return uuid
    except FileNotFoundError:
        print(f"File not found: {file_path}")
    return None

def extract_servername(file_path, debug=False):
    """Extract the SERVERNAME value from the specified file."""
    try:
        if debug:
            print(f"DEBUG: Reading SERVERNAME from file: {file_path}")
        with open(file_path, "r") as file:
            for line in file:
                if line.startswith("SERVERNAME="):
                    servername = line.split("=")[1].strip()
                    if debug:
                        print(f"DEBUG: Found SERVERNAME: {servername}")
                    return servername
    except FileNotFoundError:
        print(f"File not found: {file_path}")
    return None

def extract_useruuid(file_path, debug=False):
    """Extract the SSCONFIGPASSWORD (user UUID) from the specified file."""
    try:
        if debug:
            print(f"DEBUG: Reading USERUUID from file: {file_path}")
        with open(file_path, "r") as file:
            for line in file:
                if line.startswith("SSCONFIGPASSWORD="):
                    useruuid = line.split("=")[1].strip()
                    if debug:
                        print(f"DEBUG: Found USERUUID: {useruuid}")
                    return useruuid
    except FileNotFoundError:
        print(f"File not found: {file_path}")
    return None

def fetch_first_line(url, debug=False):
    """Fetch the first line from the given URL."""
    try:
        if debug:
            print(f"DEBUG: Sending request to URL: {url}")
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        lines = response.text.splitlines()
        if debug:
            print(f"DEBUG: Response content: {response.text}")
        return lines[0] if lines else None
    except requests.RequestException as e:
        print(f"Error fetching URL {url}: {e}")
    return None

def parse_subscription_details(line, version, debug=False):
    """Parse the subscription details from the decoded line based on the version."""
    try:
        decoded_line = unquote(line)
        if debug:
            print(f"DEBUG: Decoded Line: {decoded_line}")

        rem_volume_match = re.search(r"\u23f3 ([0-9.]+)/", decoded_line)
        if version == 1:
            rem_days_match = re.search(r" (\d+) days", decoded_line)
        else:  # version 2
            rem_days_match = re.search(r"\ud83d\udcc5 (\d+) Days", decoded_line)

        rem_volume = float(rem_volume_match.group(1)) if rem_volume_match else None
        rem_days = int(rem_days_match.group(1)) if rem_days_match else None

        if debug:
            print(f"DEBUG: Parsed Remaining Volume: {rem_volume}")
            print(f"DEBUG: Parsed Remaining Days: {rem_days}")
        return rem_volume, rem_days
    except Exception as e:
        print(f"Error parsing subscription details: {e}")
    return None, None

def detect_version(first_line, debug=False):
    """Detect the version of the data based on the content."""
    if debug:
        print(f"DEBUG: Detecting version from line: {first_line}")
    if "days" in first_line:
        return 1
    elif "Days" in first_line:
        return 2
    else:
        return None

def send_message(message_type, message):
    """Send a message based on the message type (success/error)."""
    command = f"/hive/bin/message {message_type} \"{message}\""
    os.system(command)

def update_status_file(status):
    """Create or update the file with the status value (1 or 0)."""
    file_path = "/tmp/vpn_status.txt"
    try:
        with open(file_path, "w") as file:
            file.write(str(status))
        print("VPN status updated.")
    except Exception as e:
        print(f"Error updating status file: {e}")

def main(uuid=None, debug=False):
    config_file = "/hive-config/netconfig.txt"

    if not uuid:
        uuid = extract_uuid(config_file, debug)
        if not uuid:
            uuid = "SC5RcqEFFHBFUgtLXqupd"
            print("UUID not found in netconfig.txt or provided as a flag. Using default UUID.")

    servername = extract_servername(config_file, debug)
    if not servername:
        print("SERVERNAME not found in netconfig.txt.")
        return

    useruuid = extract_useruuid(config_file, debug)
    if not useruuid:
        print("SSCONFIGPASSWORD not found in netconfig.txt.")
        return

    url = f"https://{servername}/{uuid}/{useruuid}/sub/"
    print(f"Fetching data from URL: {url}")
    first_line = fetch_first_line(url, debug)
    if debug:
        print(f"DEBUG: First Line (Encoded): {first_line}")
    if not first_line:
        print("Failed to retrieve subscription details or content unavailable.")
        send_message("danger", "\u0634\u0645\u0627 \u0633\u0631\u0648\u06cc\u0633 \u0641\u0639\u0627\u0644\u06cc \u0646\u062f\u0627\u0631\u06cc\u062f")
        update_status_file(1)
        return

    version = detect_version(first_line, debug)
    if version:
        print(f"Version {version} detected.")
        send_message("info", f"Detected subscription format version: {version}")
    else:
        print("Unable to detect version of the subscription details.")
        send_message("danger", "\u062e\u0637\u0627 \u062f\u0631 \u0641\u0631\u0645\u0627\u062a \u062f\u0627\u062f\u0647 \u0647\u0627")
        update_status_file(1)
        return

    rem_volume, rem_days = parse_subscription_details(first_line, version, debug)
    if debug:
        print(f"DEBUG: Remaining Volume: {rem_volume}GB")
        print(f"DEBUG: Remaining Days: {rem_days}")

    if rem_volume is None or rem_days is None:
        print("Failed to extract subscription details.")
        send_message("danger", "\u0633\u0631\u0648\u06cc\u0633 \u0634\u0645\u0627 \u0628\u0647 \u0627\u062a\u0645\u0627\u0645 \u0631\u0633\u06cc\u062f\u0647 \u0627\u0633\u062a")
        update_status_file(1)
        return

    if rem_days <= 0 or rem_volume < 0.001:
        send_message("error", "\u0633\u0631\u0648\u06cc\u0633 VPN \u062a\u0645\u0627\u0645 \u0634\u062f\u0647 \u0627\u0633\u062a")
        update_status_file(1)
    else:
        send_message("success", f"\u062d\u062c\u0645 \u0628\u0627\u0642\u06cc\u0645\u0627\u0646\u062f\u0647: {rem_volume}GB \u0648 \u0631\u0648\u0632 \u0628\u0627\u0642\u06cc\u0645\u0627\u0646\u062f\u0647: {rem_days}")
        update_status_file(0)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Check account subscription details.")
    parser.add_argument("--uuid", type=str, help="Specify the UUID to check")
    parser.add_argument("--debug", action="store_true", help="Enable debug logging")
    args = parser.parse_args()
    main(uuid=args.uuid, debug=args.debug)
