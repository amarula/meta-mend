from download_methods.github import check_github, download_github_commit

PATCH_DOWNLOAD_METHODS = {
    check_github: download_github_commit
}
