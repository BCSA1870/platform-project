FROM python:3.12-slim
 
WORKDIR /app
 
# Copy and install dependencies first (Docker layer caching)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
 
COPY app.py .
 
# Run with gunicorn (production WSGI server, not Flask dev server)
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]
 
EXPOSE 5000
