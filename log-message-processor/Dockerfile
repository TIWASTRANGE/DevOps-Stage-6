# log-processor/Dockerfile
FROM python:3.11-slim

# Install build tools needed for thriftpy
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    python3-dev \
 && rm -rf /var/lib/apt/lists/*


WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["python", "main.py"]