import subprocess
import os


class Git(object):

    def __init__(self, path: str):
        self.path = path

    def execute_command(self, command: str) -> tuple[str, str]:
        '''
        Execute a command on the shell, retrieve stdout and stderr.
        @param command: the command to be executed
        @return: tuple with stdout, stderr
        '''
        current_dir = os.getcwd()
        os.chdir(self.path)
        out = subprocess.run(command.split(' '), stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE)
        os.chdir(current_dir)
        return out.stdout.decode(), out.stderr.decode()

    def apply_check(self, patch_path: str) -> tuple[bool, str]:
        '''
        Perform a git apply --check. If it works, the function returns True. Else,
        this function returns False and the error message.
        '''
        cmd = f"git apply --check {patch_path}"
        out, err = self.execute_command(cmd)
        if err is not None and len(err) > 0:
            return False, err
        return True, out

    def apply_R(self, patch_path: str) -> tuple[bool, str]:
        '''
        Apply the patch. This function returns true if the patch is applied
        correctly, otherwise it returns False with the stderr output.
        '''
        cmd = f"git apply -R {patch_path}"
        out, err = self.execute_command(cmd)
        if err is not None and len(err) > 0:
            return False, err
        return True, out

    def apply(self, patch_path: str) -> tuple[bool, str]:
        '''
        Apply the patch. This function returns true if the patch is applied
        correctly, otherwise it returns False with the stderr output.
        '''
        cmd = f"git apply {patch_path}"
        out, err = self.execute_command(cmd)
        if err is not None and len(err) > 0:
            return False, err
        return True, out

    def reset_hard(self, commit: str) -> tuple[bool, str]:
        '''
        Apply the patch. This function returns true if the patch is applied
        correctly, otherwise it returns False with the stderr output.
        '''
        cmd = f"git reset --hard {commit}"
        out, err = self.execute_command(cmd)
        if err is not None and len(err) > 0:
            return False, err
        return True, out

    def init(self) -> tuple[bool, str]:
        '''
        Apply the patch. This function returns true if the patch is applied
        correctly, otherwise it returns False with the stderr output.
        '''
        cmd = "git init"
        out, err = self.execute_command(cmd)
        return True, out

    def remove_repo(self) -> tuple[bool, str]:
        '''
        Apply the patch. This function returns true if the patch is applied
        correctly, otherwise it returns False with the stderr output.
        '''
        cmd = "rm -rf .git"
        out, err = self.execute_command(cmd)
        return True, out

    def stash(self) -> tuple[bool, str]:
        '''
        Apply the patch. This function returns true if the patch is applied
        correctly, otherwise it returns False with the stderr output.
        '''
        cmd = "git stash"
        out, err = self.execute_command(cmd)
        return True, out

    def fast_commit(self, message: str) -> tuple[bool, str]:
        cmd = f"git commit -m {message}"
        out, err = self.execute_command(cmd)
        if len(err) > 0:
            return False, err
        return True, out

    def add(self, paths: list) -> tuple[bool, str]:
        cmd = "git add "
        for path in paths:
            cmd += (path + " ")
        out, err = self.execute_command(cmd)
        if len(err) > 0:
            return False, err
        return True, out

    def restore_all(self) -> tuple[bool, str]:
        cmd = "git restore ."
        out, err = self.execute_command(cmd)
        if len(err) > 0:
            return False, err
        return True, out
