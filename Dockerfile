# Dockerfile - Version diagnostic complète
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

# ===== DIAGNOSTICS COMPLETS =====
RUN echo "🔍 ===== DIAGNOSTIC INFORMATION ====="
RUN echo "📋 Node.js version: $(node --version)"
RUN echo "📋 npm version: $(npm --version)"  
RUN echo "📋 Working directory: $(pwd)"

RUN echo "📁 Files in root directory:"
RUN ls -la

RUN echo "📁 Files in app directory:"
RUN find . -maxdepth 2 -type f -name "*.js" -o -name "*.ts" -o -name "*.json" | head -20

RUN echo "📦 Checking package.json:"
RUN cat package.json | head -30

RUN echo "📦 Checking if critical files exist:"
RUN ls -la package.json && echo "✅ package.json exists" || echo "❌ package.json missing"
RUN ls -la next.config.js && echo "✅ next.config.js exists" || echo "❌ next.config.js missing"
RUN ls -la tsconfig.json && echo "✅ tsconfig.json exists" || echo "❌ tsconfig.json missing"

RUN echo "📦 Checking node_modules:"
RUN ls -la node_modules/ | head -10
RUN echo "📦 Checking critical packages:"
RUN ls -la node_modules/next && echo "✅ next installed" || echo "❌ next missing"
RUN ls -la node_modules/react && echo "✅ react installed" || echo "❌ react missing"

RUN echo "📦 npm list (critical packages):"
RUN npm list next react mysql2 lucide-react --depth=0 || echo "Some packages missing"

RUN echo "🏗️ Attempting Next.js build with verbose output..."

# Try build with maximum verbosity
RUN npm run build 2>&1 || (
    echo "❌ ===== BUILD FAILED - SHOWING DETAILS =====" && \
    echo "📋 Next.js info:" && \
    npx next info 2>&1 || echo "Could not get Next.js info" && \
    echo "📋 Trying simple next build:" && \
    npx next build 2>&1 || echo "Direct next build also failed" && \
    echo "📋 Checking app directory structure:" && \
    find app -type f -name "*.tsx" -o -name "*.ts" | head -10 && \
    echo "📋 Checking pages directory:" && \
    ls -la pages/ 2>/dev/null || echo "No pages directory" && \
    echo "📋 Environment variables:" && \
    env | grep -E "(NODE|NEXT|NPM)" && \
    echo "===== END DIAGNOSTICS =====" && \
    exit 1
)

RUN echo "✅ Build completed successfully!"

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

# Copy scripts for runtime
COPY --from=builder /app/scripts ./scripts
COPY --from=builder /app/package.json ./package.json

USER nextjs

EXPOSE 3000

CMD ["node", "server.js"]