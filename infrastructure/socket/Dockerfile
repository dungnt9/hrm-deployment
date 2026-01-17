FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --omit=dev

# Copy source code
COPY . .

# Expose port
EXPOSE 5001

# Run the application
CMD ["node", "index.js"]

