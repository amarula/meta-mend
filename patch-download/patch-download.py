import os
import json
import time
from download_methods import PATCH_DOWNLOAD_METHODS

def load_json(json_path: str) -> dict:
    try:
        with open(json_path, "r", encoding="utf-8") as fin:
            data = fin.read()
            data = data.replace("\u003d", "=")
            return json.loads(data)
    except OSError:
        raise RuntimeError(f"Could not find file {json_path}")


def save_patch(file_name: str, patch: str, force: bool = False):
    if file_name not in os.listdir() or force:
        with open(file_name, "w") as fout:
            fout.write(patch)


def get_all_patches(json: str):
    patches = []
    for idx, vulnerability in enumerate(json["vulnerabilities"]):
        name = vulnerability["name"]
        print(f"{idx}/{len(json["vulnerabilities"])}) Found {name}")
        if "topFix" not in vulnerability:
            print("WARNING! This package has no top fix")
            url = "None"
        else:
            top_fix = vulnerability["topFix"]
            url = top_fix["url"]
            check_success = False
            for check in PATCH_DOWNLOAD_METHODS:
                if check(url):
                        check_success = True
                        print(f"Retrieving patch for {name}...")
                        patches.append(PATCH_DOWNLOAD_METHODS[check](url))
            if not check_success:
                print("WARNING! Missing method for retrieving fix to vulnerability")
    return patches


if __name__ == "__main__":
    data = load_json("vulnerabilities.json")
    patches = get_all_patches(data)