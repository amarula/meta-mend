import time
import urllib.request
from urllib.error import HTTPError


def check_github(url: str) -> bool:
    return "github.com" in url and "/commit/" in url


def download_github_commit(url: str) -> str:
    MAX_RETRIES = 10
    url = url + ".patch"
    for retry in range(MAX_RETRIES):
        try:
            with urllib.request.urlopen(url) as stream:
                return stream.read().decode("utf-8")
        except HTTPError as e:
            if e.code == 429:
                print(f"Retrying download... {retry}/{MAX_RETRIES}")
                time.sleep(60)
    return ""
