FROM python:3.11-slim

# System deps needed by opencv-python-headless / mediapipe / insightface at runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Storage folders (fallback only; SupabaseStorageService is the real persistent path)
RUN mkdir -p storage/faces storage/reports

# Most hosts (Render, Railway, Fly) inject $PORT at runtime; default to 8000 for local/docker-compose use
ENV PORT=8000
EXPOSE 8000

# Run pending Alembic migrations, then start the API server
CMD alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port ${PORT}
