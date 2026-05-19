/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // Treat libsodium-wrappers as external — use Node.js require() at runtime
  // so it uses the CJS build instead of the ESM build (which has a broken relative import)
  experimental: {
    serverComponentsExternalPackages: ["libsodium-wrappers"],
  },
};

export default nextConfig;
