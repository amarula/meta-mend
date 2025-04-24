import pytest

import git


@pytest.fixture(scope="session", autouse=True)
def start_git_repo():
    print("FIXTURE: Starting git repo...")
    git.execute_in_directory("rm -rf .git", "tests/data")
    git.execute_in_directory("git init", "tests/data")
    latest_id, _ = git.execute_in_directory("git log -n 1 --pretty=format:\"%H\"", "tests/data")
    yield
    print("FIXTURE: Cleanup git repo")
    git.execute_in_directory(f"git reset --hard {latest_id}", "tests/data")
    git.execute_in_directory("rm -rf .git", "tests/data")
