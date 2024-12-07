import os

import re

import requests

from urllib.parse import unquote

import argparse


def extract_uuid(file_path, debug=False):

    """Extract the SSCONFIGPASSWORD (UUID) from the specified file."""

    try:

        if debug:

            print(f"DEBUG: Reading UUID from file: {file_path}")

        with open(file_path, "r") as file:

            for line in file:

                if line.startswith("SSCONFIGPASSWORD="):

                    uuid = line.split("=")[1].strip()

                    if debug:

                        print(f"DEBUG: Found UUID: {uuid}")

                    return uuid

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


def parse_subscription_details(line, debug=False):

    """Parse the subscription details from the decoded line."""

    try:

        decoded_line = unquote(line)

        if debug:

            print(f"DEBUG: Decoded Line: {decoded_line}")

        rem_volume = re.search(r"⏳ ([0-9.]+)/", decoded_line)

        rem_days = re.search(r" (\d+) days", decoded_line)

        if debug:

            print(f"DEBUG: Parsed Remaining Volume: {rem_volume.group(1) if rem_volume else None}")

            print(f"DEBUG: Parsed Remaining Days: {rem_days.group(1) if rem_days else None}")

        return (

            float(rem_volume.group(1)) if rem_volume else None,

            int(rem_days.group(1)) if rem_days else None,

        )

    except Exception as e:

        print(f"Error parsing subscription details: {e}")

    return None, None


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

        if status == 1:

            print("VPN service expired or not active.")

        else:

            print("VPN service is active.")

    except Exception as e:

        print(f"Error updating status file: {e}")


def main(uuid=None, debug=False):

    # Step 1: If no UUID is passed, extract it from the file

    if not uuid:

        config_file = "/hive-config/netconfig.txt"

        uuid = extract_uuid(config_file, debug)

        if not uuid:

            print("UUID not found in netconfig.txt or provided as a flag.")

            return


    # Step 2: Fetch the first line from the URL using the UUID

    url = f"https://bug.asus-tuf.com/SC5RcqEFFHBFUgtLXqupd/{uuid}/sub/"

    print(f"Fetching data from URL: {url}")

    first_line = fetch_first_line(url, debug)

    if debug:

        print(f"DEBUG: First Line (Encoded): {first_line}")

    if not first_line:

        print("Failed to retrieve subscription details or content unavailable.")

        send_message("danger", "شما سرویس فعالی ندارید")  # Send message if no subscription found

        update_status_file(1)  # Update the status file with 1 (expired)

        return


    # Step 3: Parse subscription details

    rem_volume, rem_days = parse_subscription_details(first_line, debug)

    if debug:

        print(f"DEBUG: Remaining Volume: {rem_volume}GB")

        print(f"DEBUG: Remaining Days: {rem_days}")


    # Step 4: Check for missing subscription details (None values)

    if rem_volume is None or rem_days is None:

        print("Failed to extract subscription details.")

        send_message("danger", "سرویس شما به اتمام رسیده است")

        update_status_file(1)  # Update the status file with 1 (expired)

        return


    # Step 5: Handle expired/invalid content format

    if "Package Ended" in first_line:

        send_message("error", "سرویس VPN تمام شده است")

        update_status_file(1)  # Update the status file with 1 (expired)

        return


    # Step 6: Check if subscription is expired or low on data

    if rem_days <= 0 or rem_volume < 0.001:

        send_message("error", "سرویس VPN تمام شده است")

        update_status_file(1)  # Update the status file with 1 (expired)

    else:

        send_message("success", f"روز باقیمانده: {rem_days}")

        update_status_file(0)  # Update the status file with 0 (active)


if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="Check account subscription details.")

    parser.add_argument("--uuid", type=str, help="Specify the UUID to check")

    parser.add_argument("--debug", action="store_true", help="Enable debug logging")

    args = parser.parse_args()

    main(uuid=args.uuid, debug=args.debug)

