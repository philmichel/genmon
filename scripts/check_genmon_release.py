#!/usr/bin/env python3
"""Check for new Genmon releases and set environment variables for GitHub Actions."""

import json
import os
import re
import requests


def get_latest_genmon_release():
    """Fetch the latest release from jgyates/genmon."""
    url = "https://api.github.com/repos/jgyates/genmon/releases/latest"
    response = requests.get(url)
    response.raise_for_status()
    data = response.json()
    # Tag format is V1.19.07, we strip the V prefix for our version
    tag = data["tag_name"]
    version = tag.lstrip("V").lstrip("v")
    return version


def get_current_version():
    """Read the current version from version.json."""
    try:
        with open("version.json", "r") as f:
            data = json.load(f)
            return data.get("version", "")
    except FileNotFoundError:
        return ""


def set_github_env(name, value):
    """Set an environment variable for GitHub Actions."""
    github_env = os.getenv("GITHUB_ENV")
    if github_env:
        with open(github_env, "a") as f:
            f.write(f"{name}={value}\n")
    else:
        # For local testing
        print(f"Would set {name}={value}")


def main():
    latest_version = get_latest_genmon_release()
    current_version = get_current_version()

    print(f"Latest Genmon version: {latest_version}")
    print(f"Current tracked version: {current_version}")

    is_new_release = latest_version != current_version

    set_github_env("LATEST_VERSION", latest_version)
    set_github_env("IS_NEW_RELEASE", str(is_new_release).lower())

    if is_new_release:
        print(f"New release detected: {latest_version}")
    else:
        print("No new release")


if __name__ == "__main__":
    main()
