import { NextResponse } from 'next/server'

export function GET() {
  return NextResponse.json({
    ok: true,
    service: 'huyen',
    modelProvider: 'qwen-cloud',
    runtime: 'nextjs',
  })
}
