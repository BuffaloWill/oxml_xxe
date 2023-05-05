FROM debian:stable-20230502-slim

# Install Python3 and pip3
RUN apt-get update && apt-get install -y python3 python3-pip

# Install python-docx library
RUN pip3 install python-docx==0.8.10
RUN pip3 install flask

# Set working directory
WORKDIR /app

# Copy your Python code to the container
COPY app.py .

# Run your Python code when the container starts
CMD ["python3", "app.py"]
