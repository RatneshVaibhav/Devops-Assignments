"""Deliberately insecure helper used ONLY in the security-gate demo.

security/demo/inject-issues.sh copies this into app/ to show that SAST blocks
it; it is never part of the real application.
"""
import hashlib
import subprocess

import yaml


def run_maintenance(command):
    # command injection: user input reaches a shell
    return subprocess.run(command, shell=True, capture_output=True, text=True).stdout


def load_settings(text):
    # unsafe deserialisation: yaml.load without SafeLoader can build arbitrary objects
    return yaml.load(text, Loader=yaml.Loader)


def password_hash(password):
    # weak hash for passwords
    return hashlib.md5(password.encode()).hexdigest()


if __name__ == "__main__":
    from app.main import app
    app.run(host="0.0.0.0", debug=True)
