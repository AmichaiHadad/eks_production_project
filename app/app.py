"""
EKS Python Web Application Demo

This application displays:
- Client IP address
- Welcome message
- Container identifier
- Current temperature in Tel-Aviv
"""

import os
import socket
import logging
import requests
import time
import base64
from flask import Flask, request, jsonify, Response
import mysql.connector
from datetime import datetime
from prometheus_client import Counter, Histogram, generate_latest, REGISTRY

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# --- Function to safely decode base64 from env var (SINGLE DECODE) ---
def get_decoded_env(key, default_value=""):
    encoded_value = os.environ.get(key, "")
    if not encoded_value:
        # logger.warning(f"Environment variable {key} not set.")
        return default_value
    try:
        # Decode base64 and then decode utf-8 bytes to string
        return base64.b64decode(encoded_value).decode('utf-8')
    except Exception as e:
        logger.error(f"Error decoding base64 for {key}: {e}. Value was: {encoded_value}")
        # Return the original encoded value or default if decoding fails
        # Depending on expected app behavior, you might want to raise an error instead
        return default_value # Or potentially encoded_value if app might handle it
# --------------------------------------------------------------------

# --- Function to DOUBLE decode base64 from env var --- 
# WARNING: No error handling per user request. App will crash if env var is missing or invalid.
def get_double_decoded_env(key):
    double_encoded_value = os.environ.get(key) 
    first_decode_bytes = base64.b64decode(double_encoded_value)
    # Double decode and then wrap raw bytes result in str() per user instruction
    return str(base64.b64decode(first_decode_bytes))
# -----------------------------------------------------------

# Prometheus metrics
REQUEST_COUNT = Counter('http_requests_total', 'Total number of HTTP requests', ['method', 'endpoint', 'status'])
REQUEST_LATENCY = Histogram('http_request_duration_seconds', 'HTTP request latency in seconds', ['method', 'endpoint'])
TEMPERATURE_FETCH_ERRORS = Counter('temperature_fetch_errors_total', 'Total number of errors fetching temperature data')
DB_ERRORS = Counter('db_errors_total', 'Total number of database errors')

# Get environment variables with default values
WELCOME_MESSAGE = os.environ.get('WELCOME_MESSAGE', 'Welcome to the EKS Python Demo App!')
WEATHER_API_URL = os.environ.get('WEATHER_API_URL', 'https://api.openweathermap.org/data/2.5/weather')
DB_HOST = os.environ.get('DB_HOST', 'mysql')
DB_PORT = int(os.environ.get('DB_PORT', '3306'))
# DB_PASSWORD = os.environ.get('DB_PASSWORD', '') # <<< Keep original for reference, but comment out
DB_TABLE = os.environ.get('DB_TABLE', 'requests')

# Get and decode specific variables
WEATHER_API_KEY = get_decoded_env('WEATHER_API_KEY', '')
DB_USER = get_decoded_env('DB_USER', 'root')
DB_NAME = get_decoded_env('DB_NAME', 'app_db')
DB_PASSWORD = get_decoded_env('DB_PASSWORD', '')

# Get container ID (hostname in Kubernetes)
CONTAINER_ID = socket.gethostname()


def get_tel_aviv_temperature():
    """Get the current temperature in Tel-Aviv"""
    try:
        if not WEATHER_API_KEY:
            return "Weather API key not configured", None
        
        params = {
            'q': 'Tel Aviv',
            'appid': WEATHER_API_KEY,
            'units': 'metric'
        }
        
        response = requests.get(WEATHER_API_URL, params=params, timeout=5)
        
        if response.status_code == 200:
            data = response.json()
            temp = data.get('main', {}).get('temp')
            return f"{temp}°C", None
        else:
            error = f"Error fetching weather data: {response.status_code}"
            logger.error(error)
            TEMPERATURE_FETCH_ERRORS.inc()
            return None, error
    except Exception as e:
        error = f"Exception fetching weather data: {str(e)}"
        logger.error(error)
        TEMPERATURE_FETCH_ERRORS.inc()
        return None, error


def log_request_to_db(client_ip):
    """Log the request to MySQL database"""
    try:
        # Create a connection to the MySQL database
        conn = mysql.connector.connect(
            host=DB_HOST,
            port=DB_PORT,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME,
            auth_plugin='caching_sha2_password'
        )
        
        cursor = conn.cursor()
        
        # Create table if it doesn't exist
        cursor.execute(f"""
        CREATE TABLE IF NOT EXISTS {DB_TABLE} (
            id INT AUTO_INCREMENT PRIMARY KEY,
            timestamp DATETIME,
            client_ip VARCHAR(45),
            container_id VARCHAR(255)
        )
        """)
        
        # Insert request data
        cursor.execute(
            f"INSERT INTO {DB_TABLE} (timestamp, client_ip, container_id) VALUES (%s, %s, %s)",
            (datetime.now(), client_ip, CONTAINER_ID)
        )
        
        conn.commit()
        cursor.close()
        conn.close()
        
        return True, None
    except Exception as e:
        error = f"Database error: {str(e)}"
        logger.error(error)
        DB_ERRORS.inc()
        return False, error


@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({"status": "healthy"})


@app.route('/metrics')
def metrics():
    """Metrics endpoint for Prometheus"""
    return Response(generate_latest(REGISTRY), mimetype='text/plain')


@app.route('/')
def index():
    """Main application endpoint"""
    start_time = time.time()
    method = request.method
    endpoint = "/"
    
    try:
        # Get client IP
        client_ip = request.headers.get('X-Forwarded-For', request.remote_addr)
        
        # Get Tel-Aviv temperature
        temperature, temp_error = get_tel_aviv_temperature()
        
        # Log request to database
        db_success, db_error = log_request_to_db(client_ip)
        
        # Prepare response data
        response_data = {
            "client_ip": client_ip,
            "welcome_message": WELCOME_MESSAGE,
            "container_id": CONTAINER_ID,
            "tel_aviv_temperature": temperature if temperature else "Unavailable",
            "timestamp": datetime.now().isoformat()
        }
        
        # Add any errors
        errors = {}
        if temp_error:
            errors["temperature_error"] = temp_error
        if db_error:
            errors["database_error"] = db_error
        
        if errors:
            response_data["errors"] = errors
        
        # Log the request
        logger.info(f"Request from {client_ip} served by {CONTAINER_ID}")
        
        status_code = 200
        response = jsonify(response_data)
        return response
    
    except Exception as e:
        logger.error(f"Error processing request: {str(e)}")
        status_code = 500
        return jsonify({"error": str(e)}), status_code
    
    finally:
        # Record request latency
        request_latency = time.time() - start_time
        REQUEST_LATENCY.labels(method=method, endpoint=endpoint).observe(request_latency)
        REQUEST_COUNT.labels(method=method, endpoint=endpoint, status=status_code).inc()


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)