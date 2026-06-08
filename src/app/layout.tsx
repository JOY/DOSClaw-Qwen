import type { Metadata } from 'next'
import './styles.css'

export const metadata: Metadata = {
  title: 'Huyen - Qwen-powered SME Support Autopilot',
  description:
    'A Qwen Cloud-powered Vietnamese SME support autopilot built on DOSClaw and OpenClaw.',
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
