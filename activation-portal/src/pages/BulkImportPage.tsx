import { useState } from "react";
import type { ChangeEvent } from "react";
import { provisionEmployee } from "../lib/provisioning";
import type { AppRole, EmployeeInput } from "../lib/provisioning";

const roles = new Set<AppRole>(["Admin", "QA Lead", "QA", "Warehouse"]);

export function BulkImportPage() {
  const [file, setFile] = useState<File | null>(null);
  const [working, setWorking] = useState(false);
  const [results, setResults] = useState<string[]>([]);
  const [error, setError] = useState("");

  async function importEmployees() {
    if (!file) return;
    setWorking(true);
    setError("");
    setResults([]);
    try {
      const text = await file.text();
      const rows = parseCsv(text);
      if (rows.length < 2) throw new Error("The CSV has no employee rows.");
      const headers = rows[0].map((header) => header.trim().toLowerCase());
      const required = ["full_name", "employee_id", "email", "role"];
      for (const header of required) {
        if (!headers.includes(header)) {
          throw new Error(`Missing required CSV column: ${header}`);
        }
      }

      const output: string[] = [];
      for (const [index, row] of rows.slice(1).entries()) {
        if (row.every((value) => !value.trim())) continue;
        try {
          const employee = employeeFromRow(headers, row, index + 2);
          await provisionEmployee(employee);
          output.push(`Row ${index + 2}: invitation sent to ${employee.email}.`);
        } catch (rowError) {
          output.push(
            `Row ${index + 2}: ${rowError instanceof Error ? rowError.message : String(rowError)}`,
          );
        }
      }
      setResults(output);
    } catch (importError) {
      setError(
        importError instanceof Error ? importError.message : String(importError),
      );
    } finally {
      setWorking(false);
    }
  }

  function chooseFile(event: ChangeEvent<HTMLInputElement>) {
    setFile(event.target.files?.[0] ?? null);
    setResults([]);
    setError("");
  }

  return (
    <>
      <div className="page-heading">
        <div>
          <span className="eyebrow">EMPLOYEE ONBOARDING</span>
          <h1>Bulk import</h1>
          <p>Invite multiple employees using a CSV file.</p>
        </div>
      </div>
      <section className="panel import-panel">
        <h2>Upload employee CSV</h2>
        <p>
          Required headers: <code>full_name, employee_id, email, role</code>.
          Roles: Admin, QA Lead, QA, or Warehouse.
        </p>
        <label className="file-picker">
          <span>Choose CSV file</span>
          <input accept=".csv,text/csv" onChange={chooseFile} type="file" />
        </label>
        {file && <p className="muted">Selected: {file.name}</p>}
        {error && <p className="error-message">{error}</p>}
        <button
          className="primary-button"
          disabled={!file || working}
          onClick={importEmployees}
          type="button"
        >
          {working ? "Processing invitations…" : "Import employees"}
        </button>
        {results.length > 0 && (
          <div aria-live="polite" className="import-results">
            <h3>Import results</h3>
            {results.map((result) => (
              <p key={result}>{result}</p>
            ))}
          </div>
        )}
      </section>
    </>
  );
}

function employeeFromRow(
  headers: string[],
  row: string[],
  lineNumber: number,
): EmployeeInput {
  const values = Object.fromEntries(headers.map((header, index) => [
    header,
    row[index]?.trim() ?? "",
  ]));
  const role = values.role as AppRole;
  if (!values.full_name || !values.employee_id || !values.email) {
    throw new Error("full_name, employee_id, and email are required.");
  }
  if (!roles.has(role)) {
    throw new Error(`Unsupported role "${values.role}" on CSV line ${lineNumber}.`);
  }
  return {
    full_name: values.full_name,
    employee_id: values.employee_id,
    email: values.email,
    role,
  };
}

function parseCsv(source: string): string[][] {
  source = source.replace(/^\uFEFF/, "");
  const rows: string[][] = [];
  let row: string[] = [];
  let cell = "";
  let quoted = false;

  for (let index = 0; index < source.length; index += 1) {
    const character = source[index];
    if (quoted) {
      if (character === '"' && source[index + 1] === '"') {
        cell += '"';
        index += 1;
      } else if (character === '"') {
        quoted = false;
      } else {
        cell += character;
      }
    } else if (character === '"' && cell.length === 0) {
      quoted = true;
    } else if (character === ",") {
      row.push(cell);
      cell = "";
    } else if (character === "\n" || character === "\r") {
      if (character === "\r" && source[index + 1] === "\n") index += 1;
      row.push(cell);
      rows.push(row);
      row = [];
      cell = "";
    } else {
      cell += character;
    }
  }
  if (quoted) throw new Error("The CSV contains an unterminated quoted field.");
  if (cell.length > 0 || row.length > 0) {
    row.push(cell);
    rows.push(row);
  }
  return rows;
}
