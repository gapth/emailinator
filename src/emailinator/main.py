import os
import logging

import uvicorn

from .service import app


def main():
    logging.basicConfig(level=logging.INFO)
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8000"))
    uvicorn.run(app, host=host, port=port, log_level="info")


if __name__ == "__main__":
    main()
