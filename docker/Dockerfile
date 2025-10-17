FROM python:3.11-slim
WORKDIR /app
# Copy from build context (repo root). docker-compose sets context to repo root.
COPY app/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY app/ ./
EXPOSE 5000
CMD ["python", "app.py"]
