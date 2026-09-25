import { useState } from 'react'

import { Button } from 'primereact/button'
import { Card } from 'primereact/card'
import { InputText } from 'primereact/inputtext'
import { Tag } from 'primereact/tag'

import { sendCommand } from '../api/backend'
import type { CommandResponse } from '../types/api'

export function CommandsPage() {
  const [command, setCommand] = useState('')
  const [value, setValue] = useState('')
  const [sending, setSending] = useState(false)

  const [response, setResponse] =
    useState<CommandResponse | null>(null)

  const [error, setError] =
    useState<string | null>(null)

  const [lastCommand, setLastCommand] =
    useState<string | null>(null)

  const handleSend = async () => {
    const normalizedCommand = command.trim()
    const normalizedValue = value.trim()

    if (!normalizedCommand) {
      return
    }

    setSending(true)
    setResponse(null)
    setError(null)

    try {
      const result = await sendCommand({
        command: normalizedCommand,
        value: normalizedValue,
      })

      setResponse(result)

      setLastCommand(
        normalizedValue
          ? `${normalizedCommand} = ${normalizedValue}`
          : normalizedCommand,
      )
    } catch (requestError) {
      setError(
        requestError instanceof Error
          ? requestError.message
          : 'Unknown command error',
      )
    } finally {
      setSending(false)
    }
  }

  return (
    <div className="commands-page">
      <div className="section-heading">
        <div>
          <h2>Device Commands</h2>
          <p>
            Send a command through the C++ backend
            to the ROS 2 device service.
          </p>
        </div>
      </div>

      <Card className="command-card">
        <div className="command-form">
          <div className="form-field">
            <label htmlFor="command">
              Command
            </label>

            <InputText
              id="command"
              value={command}
              onChange={(event) =>
                setCommand(event.target.value)
              }
              placeholder="e.g. test"
            />
          </div>

          <div className="form-field">
            <label htmlFor="value">
              Value
            </label>

            <InputText
              id="value"
              value={value}
              onChange={(event) =>
                setValue(event.target.value)
              }
              placeholder="e.g. hello"
            />
          </div>

          <Button
            label={
              sending
                ? 'Executing...'
                : 'Send Command'
            }
            icon="pi pi-send"
            loading={sending}
            disabled={
              !command.trim() || sending
            }
            onClick={() => void handleSend()}
          />
        </div>

        <div className="command-result">
          {response && (
            <div className="result-success">
              <Tag
                value={
                  response.success
                    ? 'Command executed'
                    : 'Command rejected'
                }
                severity={
                  response.success
                    ? 'success'
                    : 'danger'
                }
                icon={
                  response.success
                    ? 'pi pi-check-circle'
                    : 'pi pi-times-circle'
                }
                rounded
              />

              <div>
                <span>Device status</span>
                <strong>
                  {response.status}
                </strong>
              </div>

              <div>
                <span>Device response</span>
                <strong>
                  {response.message}
                </strong>
              </div>
            </div>
          )}

          {lastCommand && (
            <div className="last-command">
              <span className="field-label">
                LAST COMMAND
              </span>

              <strong>
                {lastCommand}
              </strong>
            </div>
          )}

          {error && (
            <div className="error-panel">
              <i className="pi pi-exclamation-triangle" />
              <span>{error}</span>
            </div>
          )}
        </div>
      </Card>
    </div>
  )
}
