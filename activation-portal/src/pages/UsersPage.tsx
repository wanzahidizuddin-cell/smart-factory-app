import { useCallback, useEffect, useState } from "react";
import type { FormEvent } from "react";
import { provisionEmployee } from "../lib/provisioning";
import type { AppRole, EmployeeInput } from "../lib/provisioning";
import { supabase } from "../lib/supabaseClient";

type ProfileRow = {
  id: string;
  full_name: string;
  employee_id: string;
  role: string;
  status: string;
  created_at: string;
};

const emptyForm: EmployeeInput = {
  full_name: "",
  employee_id: "",
  email: "",
  role: "Warehouse",
};

export function UsersPage() {
  const [users, setUsers] = useState<ProfileRow[]>([]);
  const [form, setForm] = useState(emptyForm);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");
  const [loading, setLoading] = useState(true);
  const [working, setWorking] = useState(false);

  const loadUsers = useCallback(async () => {
    setLoading(true);
    setError("");
    const { data, error: queryError } = await supabase
      .from("profiles")
      .select("id, full_name, employee_id, role, status, created_at")
      .order("created_at", { ascending: false });
    if (queryError) setError(queryError.message);
    else setUsers(data ?? []);
    setLoading(false);
  }, []);

  useEffect(() => {
    void loadUsers();
  }, [loadUsers]);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setWorking(true);
    setError("");
    setMessage("");
    try {
      await provisionEmployee(form);
      setForm(emptyForm);
      setMessage(`Invitation sent to ${form.email}.`);
      await loadUsers();
    } catch (submitError) {
      setError(
        submitError instanceof Error ? submitError.message : String(submitError),
      );
    } finally {
      setWorking(false);
    }
  }

  return (
    <>
      <div className="page-heading">
        <div>
          <span className="eyebrow">ACCESS MANAGEMENT</span>
          <h1>Users</h1>
          <p>Provision employees and assign application roles.</p>
        </div>
      </div>
      <div className="content-grid">
        <section className="panel">
          <div className="panel-heading">
            <div>
              <h2>Register employee</h2>
              <p>They receive an email invitation to activate their account.</p>
            </div>
          </div>
          <form className="form-grid" onSubmit={submit}>
            <label>
              Full name
              <input
                onChange={(event) =>
                  setForm({ ...form, full_name: event.target.value })
                }
                required
                value={form.full_name}
              />
            </label>
            <label>
              Employee ID
              <input
                onChange={(event) =>
                  setForm({ ...form, employee_id: event.target.value })
                }
                required
                value={form.employee_id}
              />
            </label>
            <label className="full-width">
              Work email
              <input
                onChange={(event) =>
                  setForm({ ...form, email: event.target.value })
                }
                required
                type="email"
                value={form.email}
              />
            </label>
            <label className="full-width">
              Application role
              <select
                onChange={(event) =>
                  setForm({ ...form, role: event.target.value as AppRole })
                }
                value={form.role}
              >
                <option value="Warehouse">Warehouse</option>
                <option value="QA">QA</option>
                <option value="QA Lead">QA Lead</option>
                <option value="Admin">Admin</option>
              </select>
            </label>
            {error && <p className="error-message full-width">{error}</p>}
            {message && <p className="success-message full-width">{message}</p>}
            <button className="primary-button full-width" disabled={working}>
              {working ? "Sending invitation…" : "Register employee"}
            </button>
          </form>
        </section>
        <section className="panel user-list-panel">
          <div className="panel-heading">
            <div>
              <h2>Employees</h2>
              <p>{users.length} accounts</p>
            </div>
            <button className="secondary-button" onClick={loadUsers}>
              Refresh
            </button>
          </div>
          {error && <p className="error-message">{error}</p>}
          {loading ? (
            <p className="muted">Loading employees…</p>
          ) : (
            <div className="table-scroll">
              <table>
                <thead>
                  <tr>
                    <th>Employee</th>
                    <th>Employee ID</th>
                    <th>Role</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {users.map((user) => (
                    <tr key={user.id}>
                      <td>{user.full_name}</td>
                      <td>{user.employee_id}</td>
                      <td>{user.role}</td>
                      <td>
                        <span className={`status-pill ${user.status}`}>
                          {user.status}
                        </span>
                      </td>
                    </tr>
                  ))}
                  {users.length === 0 && (
                    <tr>
                      <td colSpan={4}>No employee profiles found.</td>
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
