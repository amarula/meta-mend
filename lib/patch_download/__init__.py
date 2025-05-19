import os
import json
from patch_download.methods import PATCH_DOWNLOAD_METHODS


def load_json(json_path: str) -> dict:
    '''
    Loads json with vulnerabilities
    '''
    try:
        with open(json_path, "r", encoding="utf-8") as fin:
            data = fin.read()
            data = data.replace("\u003d", "=")
            return json.loads(data)
    except OSError:
        raise RuntimeError(f"Could not find file {json_path}")


def save_patch(file_name: str, patch: str, force: bool = False):
    '''
    Saves a patch downloaded through the download methods
    '''
    if file_name not in os.listdir() or force:
        with open(file_name, "w") as fout:
            fout.write(patch)


def download_all_patches(json: str) -> dict[str, str]:
    '''
    Downloads all the patches and stores them in memory.
    Return: A dictionary where the key is the CVE addressed and the value is the
    patch itself.
    '''
    patches = {}
    for idx, alert in enumerate(json["alerts"]):
        vulnerability = alert["vulnerability"]
        name = vulnerability["name"]
        length = len(json["alerts"])
        bb.note(f"{idx}/{length}) Found {name}")
        if "topFix" not in vulnerability:
            bb.warn("This package has no top fix")
            url = "None"
        else:
            top_fix = vulnerability["topFix"]
            url = top_fix["url"]
            check_success = False
            for check in PATCH_DOWNLOAD_METHODS:
                if check(url):
                    check_success = True
                    bb.note(f"Retrieving patch for {name}...")
                    patches[name] = PATCH_DOWNLOAD_METHODS[check](url)
            if not check_success:
                bb.warn("Missing method for retrieving fix to vulnerability")
    return patches


def get_patches(path: str, save_path: str):
    '''
    Main method to get called from external libraries. This method downloads all
    the patches it can and stores them in save_path.
    Param path: the path to the vulnerability json
    '''
    data = load_json(path)
    patches = download_all_patches(data)
    if not os.path.exists(save_path):
        os.makedirs(save_path)
    for patch_name in patches:
        save_patch(f"{save_path}/{patch_name}.patch", patches[patch_name])

