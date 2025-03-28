import os
import re
import requests
from urllib.parse import unquote
import argparse

""" CODENAME R4V3N """

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
            print("DEBUG: Sending request to VPN subscription server")
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        lines = response.text.splitlines()
        if debug:
            print(f"DEBUG: Response content: {response.text}")
        return lines[0] if lines else None
    except requests.RequestException as e:
        print(f"Error fetching subscription data: {e}")
    return None

def parse_subscription_details(line, debug=False):
    """Parse the subscription details from the decoded line."""
    try:
        decoded_line = unquote(line)
        if debug:
            print(f"DEBUG: Decoded Line: {decoded_line}")

        rem_days_match = re.search(r"(?:\u23f3 [0-9.]+/\d+GB .{0,3})?(\d+) Days", decoded_line)
        rem_days = int(rem_days_match.group(1)) if rem_days_match else None

        if debug:
            print(f"DEBUG: Parsed Remaining Days: {rem_days}")
        return rem_days
    except Exception as e:
        print(f"Error parsing subscription details: {e}")
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
    if debug:
        print(f"DEBUG: Constructed URL: {url}")
    first_line = fetch_first_line(url, debug)
    if debug:
        print(f"DEBUG: First Line (Encoded): {first_line}")
    if not first_line:
        print("Failed to retrieve subscription details or content unavailable.")
        send_message("danger", "سرویس VPN شما فعال نیست")
        update_status_file(1)
        return

    rem_days = parse_subscription_details(first_line, debug)
    if debug:
        print(f"DEBUG: Remaining Days: {rem_days}")

    if rem_days is None or rem_days <= 0:
        send_message("error", "سرویس VPN تمام شده است")
        update_status_file(1)
    else:
        send_message("success", f"VPN باقی مانده {rem_days} روز")
        update_status_file(0)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Check account subscription details.")
    parser.add_argument("--uuid", type=str, help="Specify the UUID to check")
    parser.add_argument("--debug", action="store_true", help="Enable debug logging")
    args = parser.parse_args()
    main(uuid=args.uuid, debug=args.debug)
