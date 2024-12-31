#!/usr/bin/env python3
import argparse
import base64
import os
import sys
import time
from datetime import datetime

import jwt
import requests

GITHUB_TOKEN = ""
GITHUB_TOKEN_EXPIRY = ""


def generate_jwt(app_id, private_key):
    now = int(time.time())
    payload = {
        "iat": now,  # Issued at time
        "exp": now + 600,  # Token expiration time (10 minutes)
        "iss": app_id,  # GitHub App ID
    }
    headers = {"alg": "RS256", "typ": "JWT"}
    return jwt.encode(payload, private_key, algorithm="RS256", headers=headers)


def get_installation_token(jwt_token, installation_id):
    url = f"https://api.github.com/app/installations/{installation_id}/access_tokens"
    headers = {
        "Authorization": f"Bearer {jwt_token}",
        "Accept": "application/vnd.github+json",
    }
    response = requests.post(url, headers=headers)
    if response.status_code == 201:
        token = response.json()["token"]
        expiry = response.json()["expires_at"]
        return token, expiry
    else:
        raise Exception(f"Error: {response.status_code}, {response.json()}")


def github_token():
    global GITHUB_TOKEN
    global GITHUB_TOKEN_EXPIRY

    if GITHUB_TOKEN and GITHUB_TOKEN_EXPIRY:
        time_to_compare = GITHUB_TOKEN_EXPIRY
        time_to_compare_datetime = datetime.strptime(
            time_to_compare, "%Y-%m-%dT%H:%M:%SZ"
        )
        if datetime.now() < time_to_compare_datetime:
            return GITHUB_TOKEN

    app_id = os.environ["GITHUB_APP_ID"]
    private_key = os.environ["GITHUB_PRIVATE_KEY"]
    installation_id = os.environ["GITHUB_APP_INSTALLATION_ID"]
    jwt_token = generate_jwt(app_id, private_key)

    installation_id = os.environ.get("GITHUB_APP_INSTALLATION_ID")
    GITHUB_TOKEN, GITHUB_TOKEN_EXPIRY = get_installation_token(
        jwt_token, installation_id
    )

    return GITHUB_TOKEN


def github_get_file_contents(org, repository, file_path, branch=None):
    url = f"https://api.github.com/repos/{org}/{repository}/contents/{file_path}"
    if branch:
        url += f"?ref={branch}"

    headers = {
        "Authorization": f"token {github_token()}",
    }

    response = requests.get(url, headers=headers)

    if response.status_code == 200:
        file_content = response.json()
        # Decode the base64 content
        decoded_content = base64.b64decode(file_content["content"]).decode("utf-8")
        return decoded_content
    else:
        print(f"Failed to fetch file: {response.status_code}")
        print(response.json())
        raise Exception(f"Failed to fetch file via url {url}: {response.status_code}")


class FileURIParamter(argparse.Action):
    """Validate parameter"""

    def __call__(self, parser, namespace, values, option_string=None):
        destination = []
        for value in values:
            uri = value.split(":")
            if len(uri) != 4:
                parser.error(f"Invalid URI format: {value}")

            source = uri[0]
            org = uri[1].split("/")[0]
            repository = "/".join(uri[1].split("/")[1:])
            branch = uri[2]
            file_path = uri[3]

            if source not in ["github"]:
                parser.error(f"Invalid source {source} in URI format: {values}")

            if not (org and repository and file_path):
                parser.error(
                    f"Invalid URI format. org, repository and file path are required in URI: {values}"
                )

            uri = {
                "source": source,
                "org": org,
                "repository": repository,
                "branch": branch,
                "file_path": file_path,
                "uri_reference": value,
                "local_path": base64.b64encode(value.encode()).decode(),
            }
            destination.append(uri)

        setattr(namespace, self.dest, destination)


def main():
    parser = argparse.ArgumentParser(description="Get files")
    parser.add_argument(
        "file_uri",
        metavar="FILE-URI",
        type=str,
        nargs="+",
        help="List of files to get",
        action=FileURIParamter,
    )

    parser.add_argument(
        "--output-dir",
        metavar="output-dir",
        type=str,
        help="Directory where the files will be saved",
        required=True,
    )

    args = parser.parse_args()

    for file_uri in args.file_uri:
        if file_uri["source"] == "github":
            print(file_uri, file=sys.stderr)
            content = github_get_file_contents(
                file_uri["org"],
                file_uri["repository"],
                file_uri["file_path"],
                file_uri["branch"],
            )
            local_file_path = os.path.join(
                args.output_dir, file_uri["local_path"] + ".yaml"
            )

            with open(local_file_path, "w", encoding="utf-8") as f:
                print(f"Saving file to {local_file_path}", file=sys.stderr)
                print(f"File {content}", file=sys.stderr)
                f.write(content)


if __name__ == "__main__":
    main()
