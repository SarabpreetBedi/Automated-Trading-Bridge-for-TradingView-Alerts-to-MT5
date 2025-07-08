# Use official Node.js LTS image
FROM node:20-alpine

# Set working directory
WORKDIR /app

# Copy dependency files first for better caching
COPY package*.json ./

# Install dependencies (production only)
RUN npm install --production

# Copy the rest of the project files
COPY server.js ./
COPY .env ./
COPY certs/ ./certs/

# Expose all used ports
EXPOSE 8443 9000 5000

# Run the server
CMD ["node", "server.js"]