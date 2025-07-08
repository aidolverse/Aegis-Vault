# Docker untuk deployment
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY src/frontend/package*.json ./
RUN npm ci --only=production

# Copy source code
COPY src/frontend/ ./

# Build the app
RUN npm run build

# Serve the app
EXPOSE 3000
CMD ["npm", "run", "preview", "--", "--host", "0.0.0.0", "--port", "3000"]
