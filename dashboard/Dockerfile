FROM node:20-alpine

WORKDIR /app

# Install dependencies for SkyNet agent + healthcheck
RUN apk add --no-cache bash curl wget jq bc procps python3 make g++

# Install all dependencies
COPY package*.json ./
RUN npm ci

# Copy source code
COPY . .

# Build Next.js application
RUN npm run build

# Copy startup script
COPY combined-start.sh /combined-start.sh
RUN chmod +x /combined-start.sh

EXPOSE 3000

CMD ["/bin/bash", "/combined-start.sh"]
