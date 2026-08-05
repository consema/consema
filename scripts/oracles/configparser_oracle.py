"""Consema's repository-owned Python 3.14 ConfigParser differential adapter."""

from __future__ import annotations

import configparser
import hashlib
import platform
from pathlib import Path
import sys


def transport(value: str) -> str:
    return value.encode("utf-8").hex()


def runtime_facts() -> None:
    print(f"python.implementation\t{platform.python_implementation()}")
    print(f"python.version\t{platform.python_version()}")
    print(f"python.compiler\t{platform.python_compiler()}")
    print(f"os.name\t{platform.system()}")
    print(f"os.release\t{platform.release()}")
    print(f"os.machine\t{platform.machine()}")


def run_case(path: Path) -> None:
    source = path.read_bytes()
    print(f"input-sha256\t{hashlib.sha256(source).hexdigest()}")
    try:
        text = source.decode("utf-8", errors="strict")
        parser = configparser.ConfigParser()
        parser.read_string(text, source=str(path.name))
    except (UnicodeError, configparser.Error) as error:
        print(f"failed\t{type(error).__module__}.{type(error).__name__}")
        return

    print("complete")
    for key, value in parser.defaults().items():
        print(f"default\t{transport(key)}\t{transport(value)}")
    for section in parser.sections():
        encoded_section = transport(section)
        print(f"section\t{encoded_section}")
        for key, value in parser.items(section, raw=True):
            print(f"entry\t{encoded_section}\t{transport(key)}\t{transport(value)}")


def main() -> None:
    if sys.argv[1:] == ["--runtime"]:
        runtime_facts()
        return
    if len(sys.argv) != 2:
        raise SystemExit("usage: configparser_oracle.py <input> | --runtime")
    run_case(Path(sys.argv[1]))


if __name__ == "__main__":
    main()
