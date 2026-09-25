import type {
  CommandRequest,
  CommandResponse,
  HealthResponse,
  TelemetryResponse,
} from '../types/api'

async function request<T>(
  path: string,
  options?: RequestInit,
): Promise<T> {
  const response = await fetch(path, options)

  if (!response.ok) {
    throw new Error(
      `Backend request failed: ${response.status} ${response.statusText}`,
    )
  }

  return response.json() as Promise<T>
}

export function getHealth(): Promise<HealthResponse> {
  return request<HealthResponse>('/api/health')
}

export function getLatestTelemetry(): Promise<TelemetryResponse> {
  return request<TelemetryResponse>('/api/telemetry/latest')
}

export function sendCommand(
  command: CommandRequest,
): Promise<CommandResponse> {
  return request<CommandResponse>('/api/commands', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(command),
  })
}
