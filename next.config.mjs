/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  experimental: {
    serverComponentsExternalPackages: ['mysql2']
  },
  eslint: {
    ignoreDuringBuilds: true,
  },
  typescript: {
    ignoreBuildErrors: true,
  },
  // Disable image optimization for simpler deployment
  images: {
    unoptimized: true
  },
  // Be more permissive with external packages
  transpilePackages: ['lucide-react'],
  // Reduce strictness
  swcMinify: false,
  // Handle potential import issues
  modularizeImports: {
    'lucide-react': {
      transform: 'lucide-react/dist/esm/icons/{{kebabCase member}}',
      skipDefaultConversion: true
    }
  }
}

module.exports = nextConfig