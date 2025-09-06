"""Emailinator tools package initialization and logging setup."""

import logging
import sys

__version__ = "0.1.0"


def _configure_logger() -> None:
    """Configure a package level logger that logs to stdout.

    Uvicorn configures its own loggers and does not automatically forward
    library loggers such as ``emailinator_tools``.  By attaching a ``StreamHandler``
    to the package logger we ensure that calls to ``logging.getLogger("emailinator_tools")``
    produce output when running ``make run`` or ``make web``.
    """

    logger = logging.getLogger("emailinator_tools")
    if not logger.handlers:
        handler = logging.StreamHandler(sys.stdout)
        formatter = logging.Formatter("%(levelname)s:%(name)s:%(message)s")
        handler.setFormatter(formatter)
        logger.addHandler(handler)
        logger.propagate = False
    logger.setLevel(logging.INFO)


_configure_logger()
