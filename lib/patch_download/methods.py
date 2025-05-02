from patch_download.github import check_github, download_github_commit


'''
This dictionary contains all the methods to download patches from various
sources. Once a source is added, the check function shall be introduced as a key
and the download function shall be introduced as the value.
For a short example, please see how the github.py file works.
'''
PATCH_DOWNLOAD_METHODS = {
    check_github: download_github_commit
}
