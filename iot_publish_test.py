"""Compatibility script for legacy CI checks.

AWS IoT Core is no longer part of the active RAPIRO-LSA cloud path. Use
``scripts/test_ec2_backend.py`` to test the current EC2 FastAPI backend.
"""


def main():
    print("IoT legacy publisher removed. Use scripts/test_ec2_backend.py instead.")


if __name__ == "__main__":
    main()
