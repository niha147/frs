import logging
import time
from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware

# Configure standard logger
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s - %(message)s",
    handlers=[
        logging.StreamHandler()
    ]
)

logger = logging.getLogger("smart_attend")

class LoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        start_time = time.time()
        
        # Capture route information
        method = request.method
        path = request.url.path
        
        try:
            response = await call_next(request)
            process_time = (time.time() - start_time) * 1000
            
            logger.info(
                f"HTTP {method} {path} - Completed {response.status_code} in {process_time:.2f}ms"
            )
            return response
        except Exception as e:
            process_time = (time.time() - start_time) * 1000
            logger.error(
                f"HTTP {method} {path} - Failed with exception: {str(e)} in {process_time:.2f}ms",
                exc_info=True
            )
            raise e
