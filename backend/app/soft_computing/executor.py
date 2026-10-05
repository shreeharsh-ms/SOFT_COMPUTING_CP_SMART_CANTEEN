import asyncio
from concurrent.futures import ThreadPoolExecutor
from typing import Callable, Any
from app.config import settings
import logging

logger = logging.getLogger("smart_canteen.soft_computing")

class CPUBoundExecutor:
    def __init__(self, max_workers: int = 4):
        self._pool = ThreadPoolExecutor(
            max_workers=max_workers,
            thread_name_prefix="SC_Worker"
        )

    async def run(self, func: Callable, *args: Any, **kwargs: Any) -> Any:
        loop = asyncio.get_running_loop()
        try:
            return await loop.run_in_executor(self._pool, lambda: func(*args, **kwargs))
        except Exception as e:
            logger.error(f"[SoftComputing] Execution failed in pool: {e}", exc_info=True)
            raise

    def shutdown(self):
        self._pool.shutdown(wait=True)

cpu_pool = CPUBoundExecutor(max_workers=settings.WORKER_THREADS)
