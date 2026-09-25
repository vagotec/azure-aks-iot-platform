import { useEffect, useState } from 'react'

import { TabPanel, TabView } from 'primereact/tabview'
import { Tag } from 'primereact/tag'

import { getHealth } from './api/backend'
import { CommandsPage } from './pages/CommandsPage'
import { TelemetryPage } from './pages/TelemetryPage'

function App() {
  const [backendOnline, setBackendOnline] = useState(false)

  useEffect(() => {
    let active = true

    const checkBackend = async () => {
      try {
        const response = await getHealth()

        if (active) {
          setBackendOnline(response.status === 'ok')
        }
      } catch {
        if (active) {
          setBackendOnline(false)
        }
      }
    }

    void checkBackend()

    const timer = window.setInterval(
      () => void checkBackend(),
      5000,
    )

    return () => {
      active = false
      window.clearInterval(timer)
    }
  }, [])

  return (
    <main className="app-shell">
      <header className="app-header">
        <div>
          <div className="app-eyebrow">EDGE-TO-CLOUD PLATFORM</div>
          <h1>Azure AKS IoT Platform</h1>
          <p>Industrial IoT Dashboard</p>
        </div>

        <Tag
          value={backendOnline ? 'Backend Online' : 'Backend Offline'}
          severity={backendOnline ? 'success' : 'danger'}
          icon={backendOnline ? 'pi pi-check-circle' : 'pi pi-times-circle'}
          rounded
        />
      </header>

      <section className="dashboard">
        <TabView>
          <TabPanel
            header="Telemetry"
            leftIcon="pi pi-chart-line mr-2"
          >
            <TelemetryPage />
          </TabPanel>

          <TabPanel
            header="Commands"
            leftIcon="pi pi-send mr-2"
          >
            <CommandsPage />
          </TabPanel>
        </TabView>
      </section>
    </main>
  )
}

export default App
