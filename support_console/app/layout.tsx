import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "PPMS Support Console",
  description: "Razex Solutions Master Admin support console for PPMS",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
