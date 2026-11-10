import { useCallback, useEffect, useState } from "react";
import type { FormEvent } from "react";
import { supabase } from "../lib/supabaseClient";

type DeviceRow = {
  device_id: string;
  name: string;
  type: string;
  battery_level: number;
  firmware_version: string;
  status: string;
  last_ping: string | null;
};

const emptyForm = { device_id: "", name: "", type: "", firmware_version: "" };

export function DevicesPage() {
  const [devices, setDevices] = useState<DeviceRow[]>([]);
  const [form, setForm] = useState(emptyForm);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);

  const loadDevices = useCallback(async () => {
    setLoading(true);
    setError("");
    const { data, error: queryError } = await supabase
      .from("hardware_devices")
      .select(
        "device_id, name, type, battery_level, firmware_version, status, last_ping",
      )
      .order("device_id");
    if (queryError) setError(queryError.message);
    else setDevices(data ?? []);
    setLoading(false);
  }, []);

  useEffect(() => {
    void loadDevices();
  }, [loadDevices]);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    const { error: insertError } = await supabase
      .from("hardware_devices")
      .insert({
        ...form,
        battery_level: 100,
        status: "online",
        last_ping: new Date().toISOString(),
      });
    if (insertError) {
      setError(insertError.message);
      return;
    }
    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError || !userData.user) {
      setError(
        `Device was registered, but its audit actor could not be verified: ${
          userError?.message ?? "No authenticated user."
        }`,
      );
      await loadDevices();
      return;
    }
    const { error: auditError } = await supabase.from("audit_logs").insert({
      action_id: `device-${crypto.randomUUID()}`,
      action_type: "hardware_device_registered",
      user_id: userData.user.id,
      module: "devices",
      record_id: form.device_id,
      previous_state: null,
      new_state: {
        ...form,
        battery_level: 100,
        status: "online",
      },
    });
    if (auditError) {
      setError(
        `Device was registered, but its audit record could not be saved: ${auditError.message}`,
      );
      setForm(emptyForm);
      await loadDevices();
      return;
    }
    setForm(emptyForm);
    await loadDevices();
  }

  return (
    <>
      <div className="page-heading">
        <div>
          <span className="eyebrow">HARDWARE INVENTORY</span>
          <h1>Devices</h1>
          <p>Register and track scanners and factory sensors.</p>
        </div>
      </div>
      <div className="content-grid">
        <section className="panel">
          <div className="panel-heading">
            <div>
              <h2>Register device</h2>
              <p>Add a device to the factory registry.</p>
            </div>
          </div>
          <form className="form-grid" onSubmit={submit}>
            <label>
              Device ID
              <input
                onChange={(event) =>
                  setForm({ ...form, device_id: event.target.value })
                }
                required
                value={form.device_id}
              />
            </label>
            <label>
              Device name
              <input
                onChange={(event) =>
                  setForm({ ...form, name: event.target.value })
                }
                required
                value={form.name}
              />
            </label>
            <label>
              Device type
              <input
                onChange={(event) =>
                  setForm({ ...form, type: event.target.value })
                }
                required
                value={form.type}
              />
            </label>
            <label>
              Firmware version
              <input
                onChange={(event) =>
                  setForm({ ...form, firmware_version: event.target.value })
                }
                required
                value={form.firmware_version}
              />
            </label>
            {error && <p className="error-message full-width">{error}</p>}
            <button className="primary-button full-width">Add device</button>
          </form>
        </section>
        <section className="panel user-list-panel">
          <div className="panel-heading">
            <div>
              <h2>Registered devices</h2>
              <p>{devices.length} devices</p>
            </div>
            <button className="secondary-button" onClick={loadDevices}>
              Refresh
            </button>
          </div>
          {error && <p className="error-message">{error}</p>}
          {loading ? (
            <p className="muted">Loading devices…</p>
          ) : (
            <div className="table-scroll">
              <table>
                <thead>
                  <tr>
                    <th>Device</th>
                    <th>Type</th>
                    <th>Battery</th>
                    <th>Firmware</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {devices.map((device) => (
                    <tr key={device.device_id}>
                      <td>
                        <strong>{device.name}</strong>
                        <span className="table-subtext">{device.device_id}</span>
                      </td>
                      <td>{device.type}</td>
                      <td>{device.battery_level}%</td>
                      <td>{device.firmware_version}</td>
                      <td>
                        <span className={`status-pill ${device.status}`}>
                          {device.status}
                        </span>
                      </td>
                    </tr>
                  ))}
                  {devices.length === 0 && (
                    <tr>
                      <td colSpan={5}>No devices registered.</td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          )}
        </section>
      </div>
    </>
  );
}
