'use client'

import { useMemo, useState } from 'react'

type ScenarioKey = 'memory' | 'knowledge' | 'handoff'

const scenarios: Record<
  ScenarioKey,
  {
    label: string
    customer: string
    huyen: string
    evidence: string[]
    tool: string
    outcome: string
  }
> = {
  memory: {
    label: 'Returning customer',
    customer: 'Chi oi, hom nay giao trong TP.HCM kip khong?',
    huyen:
      'Da anh Minh, em thay anh hay chon giao trong ngay o TP.HCM. Hom nay van kip neu minh chot truoc 5pm.',
    evidence: ['search_memory returned Minh and same-day delivery preference', 'Qwen Cloud drafted the reply using only returned memory'],
    tool: 'search_memory',
    outcome: 'No repeated question. The customer feels remembered without exposing raw memory.',
  },
  knowledge: {
    label: 'Policy question',
    customer: 'Bao hanh may thang, neu khong hop thi doi tra sao?',
    huyen:
      'Ben em bao hanh 12 thang cho loi san xuat. Doi tra trong 7 ngay neu san pham chua su dung va con nguyen dong goi a.',
    evidence: ['search_knowledge returned warranty and return policy rows', 'Qwen Cloud summarized the policy in Vietnamese'],
    tool: 'search_knowledge',
    outcome: 'Grounded policy answer. No guessing about warranty or refund rules.',
  },
  handoff: {
    label: 'Human handoff',
    customer: 'May bi loi lan thu hai roi, cho anh gap nhan vien hoac hoan tien.',
    huyen:
      'Da em da chuyen thong tin cho nhan vien phu trach sau khi gui tom tat su co. Anh cho ben em kiem tra va lien he lai ngay a.',
    evidence: ['handoff_to_human accepted the case summary', 'Huyen confirmed only after tool success'],
    tool: 'handoff_to_human',
    outcome: 'Escalation is real, auditable, and honest.',
  },
}

const stack = [
  ['Runtime', 'OpenClaw container per business'],
  ['Model', 'Qwen Cloud primary reasoning path'],
  ['Memory', 'Per-customer MCP memory'],
  ['Knowledge', 'Live FAQ/search MCP'],
  ['Handoff', 'Structured staff escalation'],
]

export default function Page() {
  const [active, setActive] = useState<ScenarioKey>('memory')
  const scenario = scenarios[active]
  const completion = useMemo(() => {
    return active === 'handoff' ? 92 : active === 'knowledge' ? 78 : 64
  }, [active])

  return (
    <main>
      <section className="shell">
        <header className="topbar">
          <div>
            <span className="brand">Huyen</span>
            <span className="subbrand">Qwen-powered SME support autopilot</span>
          </div>
          <a className="repoLink" href="/api/demo">
            Demo API
          </a>
        </header>

        <div className="heroGrid">
          <section className="introPanel" aria-label="Product overview">
            <div className="introCopy">
              <h1>Support agent for Vietnamese SMEs that remembers, checks, and escalates.</h1>
              <p>
                Huyen is spun out from DOSClaw as a focused hackathon product: one agent, one customer support outcome,
                powered by Qwen Cloud and orchestrated through OpenClaw.
              </p>
            </div>
            <img className="productVisual" src="/images/huyen-dashboard.png" alt="Huyen support operations dashboard" />
          </section>

          <section className="controlPanel" aria-label="Live demo controls">
            <div className="panelHeader">
              <span>Scenario runner</span>
              <strong>{completion}% ready</strong>
            </div>
            <div className="scenarioTabs" role="tablist" aria-label="Demo scenario">
              {(Object.keys(scenarios) as ScenarioKey[]).map((key) => (
                <button
                  key={key}
                  type="button"
                  className={key === active ? 'active' : ''}
                  onClick={() => setActive(key)}
                >
                  {scenarios[key].label}
                </button>
              ))}
            </div>

            <div className="chatSurface">
              <p className="bubble customer">{scenario.customer}</p>
              <p className="bubble agent">{scenario.huyen}</p>
            </div>

            <div className="toolLine">
              <span>Tool used</span>
              <strong>{scenario.tool}</strong>
            </div>
          </section>
        </div>

        <section className="evidenceBand" aria-label="Architecture and evidence">
          <div className="architecture">
            <h2>Separate product boundary</h2>
            <p>
              The public submission can ship this Huyen slice without exposing the private DOS-AI monorepo: runtime
              adapter, Qwen Cloud env contract, synthetic demo data, and deployment proof.
            </p>
            <div className="stackGrid">
              {stack.map(([name, value]) => (
                <div className="stackItem" key={name}>
                  <span>{name}</span>
                  <strong>{value}</strong>
                </div>
              ))}
            </div>
          </div>

          <div className="proofList">
            <h2>Current scenario evidence</h2>
            <ul>
              {scenario.evidence.map((item) => (
                <li key={item}>{item}</li>
              ))}
            </ul>
            <p>{scenario.outcome}</p>
          </div>
        </section>

        <section className="checklist" aria-label="Hackathon checklist">
          <h2>Submission gates</h2>
          <div className="checks">
            <span>Qwen Cloud primary model</span>
            <span>Alibaba Cloud deployment proof</span>
            <span>Public sanitized repo</span>
            <span>Three-minute demo video</span>
          </div>
        </section>
      </section>
    </main>
  )
}
