import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Asanify HR — Employee Status",
  description: "Admin dashboard for GitHub Actions-based Asanify HR clock-in system",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark">
      <body className="min-h-screen bg-slate-900 text-slate-100 antialiased">
        {children}
      </body>
    </html>
  );
}
