FROM node:20-alpine AS builder
WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Production stage
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production

# Install required tools for SkyNet Agent
RUN apk add --no-cache bash curl jq bc procps

# Copy built application
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./
COPY --from=builder /app/public ./public

# Copy combined startup script
COPY combined-start.sh /combined-start.sh
RUN chmod +x /combined-start.sh

# Expose port
EXPOSE 3000

# Start both dashboard and SkyNet Agent
CMD ["/bin/bash", "/combined-start.sh"]
