# Use official Node.js LTS image
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy project files
COPY package*.json ./
COPY server.js ./
COPY .env ./
COPY certs/ ./certs/

# Install dependencies
RUN npm install

# Expose port (adjust if needed)
EXPOSE 3000

# Run the server
CMD ["node", "server.js"]
