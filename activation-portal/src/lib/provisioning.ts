import { supabase } from "./supabaseClient";

export type AppRole = "Admin" | "QA Lead" | "QA" | "Warehouse";

export interface EmployeeInput {
  full_name: string;
  employee_id: string;
  email: string;
  role: AppRole;
}

export async function provisionEmployee(employee: EmployeeInput) {
  const { data, error } = await supabase.functions.invoke(
    "provision-employee",
    { body: employee },
  );
  if (error) throw error;
  return data;
}
