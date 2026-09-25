import { useEffect, useState } from 'react'

import { Card } from 'primereact/card'
import { Tag } from 'primereact/tag'

import { getLatestTelemetry } from '../api/backend'
import type { TelemetryResponse } from '../types/api'

const REFRESH_INTERVAL_MS = 2000

export function TelemetryPage() {
  const [telemetry, setTelemetry] =
    useState<TelemetryResponse | null>(null)

  const [error, setError] = useState<string | null>(null)
  const [lastUpdate, setLastUpdate] = useState<string>('--')

  useEffect(() => {
    let active = true

    const loadTelemetry = async () => {
      try {
        const data = await getLatestTelemetry()

        if (active) {
          setTelemetry(data)
          setError(null)

          setLastUpdate(
            new Date().toLocaleTimeString('de-DE'),
          )
        }
      } catch (requestError) {
        if (active) {
          setError(
            requestError instanceof Error
              ? requestError.message
              : 'Unknown telemetry error',
          )
        }
      }
    }

    void loadTelemetry()

    const timer = window.setInterval(
      () => void loadTelemetry(),
      REFRESH_INTERVAL_MS,
    )

    return () => {
      active = false
      window.clearInterval(timer)
    }
  }, [])

  return (
    <div className="telemetry-page">
      <div className="section-heading">
        <div>
          <h2>Live Telemetry</h2>
          <p>Current measurements from the edge device.</p>
        </div>

        <Tag
          value={error ? 'Offline' : telemetry ? 'LIVE' : 'Waiting'}
          severity={error ? 'danger' : telemetry ? 'success' : 'warning'}
          icon={error ? 'pi pi-times-circle' : 'pi pi-circle-fill'}
          rounded
        />
      </div>

      {error && (
        <div className="error-panel">
          <i className="pi pi-exclamation-triangle" />
          <span>{error}</span>
        </div>
      )}

      <div className="device-bar">
        <div>
          <span className="field-label">DEVICE</span>
          <strong>{telemetry?.device_id ?? '--'}</strong>
        </div>

        <div className="last-update">
          <span className="field-label">LAST UPDATE</span>
          <strong>{lastUpdate}</strong>
        </div>
      </div>

      <div className="metric-grid">
        <Card className="metric-card">
          <div className="metric-icon">
            <i className="pi pi-sun" />
          </div>

          <span className="metric-label">Temperature</span>

          <div className="metric-value">
            {telemetry
              ? telemetry.temperature_c.toFixed(2)
              : '--'}
            <span>°C</span>
          </div>
        </Card>

        <Card className="metric-card">
          <div className="metric-icon">
            <i className="pi pi-percentage" />
          </div>

          <span className="metric-label">Humidity</span>

          <div className="metric-value">
            {telemetry
              ? telemetry.humidity_percent.toFixed(2)
              : '--'}
            <span>%</span>
          </div>
        </Card>
      </div>
    </div>
  )
}
