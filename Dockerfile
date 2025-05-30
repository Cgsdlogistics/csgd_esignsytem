# Dockerfile - Force npm et évite pnpm
FROM node:18-alpine AS base

# Install dependencies only when needed
FROM base AS deps
RUN apk add --no-cache libc6-compat curl
WORKDIR /app

# Force npm configuration
ENV NPM_CONFIG_LEGACY_PEER_DEPS=true
ENV NPM_CONFIG_FUND=false
ENV NPM_CONFIG_AUDIT=false
ENV NPM_CONFIG_STRICT_PEER_DEPS=false

# Copy package.json and npmrc
COPY package.json .npmrc ./

# Remove any existing lockfiles except package-lock.json
RUN rm -f yarn.lock pnpm-lock.yaml bun.lockb

# Install dependencies with npm ONLY
RUN npm install --legacy-peer-deps --no-fund --no-audit

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app

# Copy node_modules from deps stage
COPY --from=deps /app/node_modules ./node_modules

# Copy source code
COPY . .

# Set environment variables for build
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV NPM_CONFIG_LEGACY_PEER_DEPS=true

# Run database migrations (with error handling)
RUN npm run migrate:prod || echo "Migration skipped"

# Build the application
RUN npm run build

# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copy built application
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

# Copy package.json for metadata
COPY --from=builder /app/package.json ./package.json

USER nextjs

EXPOSE 3000

CMD ["node", "server.js"]