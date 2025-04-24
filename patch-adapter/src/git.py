import subprocess
import os


def execute_command(command: str) -> tuple[str, str]:
    '''
    Execute a command on the shell, retrieve stdout and stderr.
    @param command: the command to be executed
    @return: tuple with stdout, stderr
    '''
    out = subprocess.run(command.split(' '), stdout=subprocess.PIPE,
                         stderr=subprocess.PIPE)
    return out.stdout.decode(), out.stderr.decode()


def execute_in_directory(cmd: str, target_dir: str) -> tuple[str, str]:
    '''
    Executes a command in a directory, then changing the workdir to the
    original one.
    @param cmd: the command
    @param target_dir: the directory in which to execute the command
    @return: tuple with stdout, stderr
    '''
    current_dir = os.getcwd()
    os.chdir(target_dir)
    out, err = execute_command(cmd)
    os.chdir(current_dir)
    return out, err


def apply_check(patch_path: str, target_dir: str) -> tuple[bool, str]:
    '''
    Perform a git apply --check. If it works, the function returns True. Else,
    this function returns False and the error message.
    '''
    cmd = f"git apply --check {patch_path}"
    out, err = execute_in_directory(cmd, target_dir)
    if err is not None and len(err) > 0:
        return False, err
    return True, out


def full_apply(patch_path: str, target_dir: str) -> tuple[bool, str]:
    '''
    Apply the patch. This function returns true if the patch is applied
    correctly, otherwise it returns False with the stderr output.
    '''
    cmd = f"git am < {patch_path}"
    out, err = execute_in_directory(cmd, target_dir)
    if err is not None and len(err) > 0:
        return False, err
    return True, out


def reset_hard(commit: str, target_dir: str) -> tuple[bool, str]:
    '''
    Apply the patch. This function returns true if the patch is applied
    correctly, otherwise it returns False with the stderr output.
    '''
    cmd = f"git reset --hard {commit}"
    out, err = execute_in_directory(cmd, target_dir)
    if err is not None and len(err) > 0:
        return False, err
    return True, out


def init(target_dir: str) -> tuple[bool, str]:
    '''
    Apply the patch. This function returns true if the patch is applied
    correctly, otherwise it returns False with the stderr output.
    '''
    cmd = "git init"
    out, err = execute_in_directory(cmd, target_dir)
    return True, out


def remove_repo(target_dir: str) -> tuple[bool, str]:
    '''
    Apply the patch. This function returns true if the patch is applied
    correctly, otherwise it returns False with the stderr output.
    '''
    cmd = "rm -rf .git"
    out, err = execute_in_directory(cmd, target_dir)
    return True, out
