FROM python:3.11-slim

WORKDIR /app

# Install dependencies first (for better caching)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    FLASK_APP=app.py

# Run as non-root user for better security
RUN adduser --disabled-password --gecos "" appuser
USER appuser

# Expose the application port
EXPOSE 5000

# Run the application
CMD ["python", "app.py"]