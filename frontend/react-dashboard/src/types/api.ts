export interface HealthResponse {
  status: string
  service: string
}

export interface TelemetryResponse {
  device_id: string
  temperature_c: number
  humidity_percent: number
}

export interface CommandRequest {
  command: string
  value: string
}

export interface CommandResponse {
  success: boolean
  status: string
  message: string
}
