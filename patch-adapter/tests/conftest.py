import pytest

from git import Git


@pytest.fixture(scope="session", autouse=True)
def start_git_repo():
    print("FIXTURE: Starting git repo...")
    git = Git("tests/data")
    git.remove_repo()
    git.init()
    git.add(["*"])
    git.fast_commit("First commit")
    latest_id, _ = git.execute_command("git log -n 1 --pretty=format:\"%H\"")
    yield
    print("FIXTURE: Cleanup git repo")
    git.stash()
    git.restore_all()
    git.reset_hard(latest_id)
    git.remove_repo()


@pytest.fixture(scope="function", autouse=True)
def git():
    return Git("tests/data")