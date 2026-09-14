FROM python:3.11-alpine

# Install Docker CLI and dependencies
RUN apk add --no-cache docker-cli curl

# Set working directory
WORKDIR /app

# Install Python dependencies
RUN pip install --no-cache-dir docker psutil requests

# Copy orchestrator script
COPY rl_agent.py /app/rl_agent.py

# Create logs directory
RUN mkdir -p /app/logs

# Set permissions
RUN chmod +x /app/rl_agent.py

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import docker; docker.from_env().ping()" || exit 1

# Run the orchestrator
CMD ["python", "/app/rl_agent.py"]
