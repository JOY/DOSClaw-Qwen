import { NextRequest, NextResponse } from 'next/server'

const scenarios = {
  memory: {
    user: 'Minh asks if same-day delivery is available today.',
    qwenTask: 'Reason over a returning customer request.',
    tools: ['search_memory'],
    answer:
      'Huyen recalls that Minh prefers same-day delivery in Ho Chi Minh City, then confirms the availability window without asking again.',
  },
  knowledge: {
    user: 'A customer asks about warranty and return policy.',
    qwenTask: 'Draft a grounded policy answer after tool evidence.',
    tools: ['search_knowledge'],
    answer:
      'Huyen searches the business FAQ first, then answers with the 12-month warranty and 7-day unused return policy.',
  },
  handoff: {
    user: 'A customer says the product failed twice and asks for staff or a refund.',
    qwenTask: 'Classify escalation risk and prepare a concise case summary.',
    tools: ['handoff_to_human'],
    answer:
      'Huyen calls the handoff tool with the customer ask, issue summary, and reason, then confirms only after the tool succeeds.',
  },
} as const

export function GET() {
  return NextResponse.json({
    product: 'Huyen',
    runtime: 'OpenClaw orchestrated by DOSClaw',
    modelProvider: 'Qwen Cloud',
    endpointEnv: 'QWEN_CLOUD_BASE_URL',
    scenarios,
  })
}

export async function POST(request: NextRequest) {
  const body = (await request.json().catch(() => ({}))) as { scenario?: string }
  const key = body.scenario && body.scenario in scenarios ? body.scenario : 'memory'

  return NextResponse.json({
    ok: true,
    scenario: key,
    result: scenarios[key as keyof typeof scenarios],
    evidence: {
      qwenPrimaryModelRef: 'qwen-cloud/qwen3.7-plus',
      requiredEnv: ['QWEN_CLOUD_API_KEY', 'QWEN_CLOUD_BASE_URL', 'QWEN_CLOUD_MODEL'],
      mcpTools: scenarios[key as keyof typeof scenarios].tools,
    },
  })
}
