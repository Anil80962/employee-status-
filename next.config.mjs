/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // Keep libsodium external so Node require() uses the CJS build (not the
  // broken ESM build). Both keys needed: Next.js 14.x uses the experimental
  // key; Next.js 15+ uses the stable top-level key.
  experimental: {
    serverComponentsExternalPackages: ["libsodium-wrappers"],
  },
  serverExternalPackages: ["libsodium-wrappers"],
};

export default nextConfig;
