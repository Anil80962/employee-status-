/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // Keep libsodium as an external package so Node require() resolves the CJS
  // build instead of the broken ESM build (which has a missing sibling import).
  serverExternalPackages: ["libsodium-wrappers"],
};

export default nextConfig;
