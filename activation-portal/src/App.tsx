import { useEffect, useState } from "react";
import type { Session } from "@supabase/supabase-js";
import type { FormEvent, ReactNode } from "react";
import {
  Link,
  Navigate,
  Outlet,
  Route,
  Routes,
  useLocation,
} from "react-router-dom";
import { supabase } from "./lib/supabaseClient";
import { BulkImportPage } from "./pages/BulkImportPage";
import { DevicesPage } from "./pages/DevicesPage";
import { UsersPage } from "./pages/UsersPage";

type PortalProfile = {
  role: string;
  status: string;
};

export default function App() {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let active = true;
    void supabase.auth.getSession().then(({ data, error }) => {
      if (!active) return;
      if (error) console.error("Could not restore portal session.", error);
      setSession(data.session);
      setLoading(false);
    });
    const { data } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession);
      setLoading(false);
    });
    return () => {
      active = false;
      data.subscription.unsubscribe();
    };
  }, []);

  if (loading) return <FullScreenMessage>Checking session…</FullScreenMessage>;
  if (!session) return <SignInPage />;
  return <AdminPortal session={session} />;
}

function AdminPortal({ session }: { session: Session }) {
  const [profile, setProfile] = useState<PortalProfile | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    let active = true;
    void supabase
      .from("profiles")
      .select("role, status")
      .eq("id", session.user.id)
      .single()
      .then(({ data, error: queryError }) => {
        if (!active) return;
        if (queryError) setError(queryError.message);
        else setProfile(data);
      });
    return () => {
      active = false;
    };
  }, [session.user.id]);

  if (error) {
    return (
      <FullScreenMessage>
        <p>Could not verify administrator access: {error}</p>
        <SignOutButton />
      </FullScreenMessage>
    );
  }
  if (!profile) return <FullScreenMessage>Verifying access…</FullScreenMessage>;
  if (profile.role !== "Admin" || profile.status !== "approved") {
    return (
      <FullScreenMessage>
        <p>This portal is restricted to approved Admin accounts.</p>
        <SignOutButton />
      </FullScreenMessage>
    );
  }

  return (
    <Routes>
      <Route element={<DashboardLayout email={session.user.email ?? ""} />}>
        <Route index element={<Navigate to="/users" replace />} />
        <Route path="/users" element={<UsersPage />} />
        <Route path="/devices" element={<DevicesPage />} />
        <Route path="/bulk-import" element={<BulkImportPage />} />
      </Route>
      <Route path="*" element={<Navigate to="/users" replace />} />
    </Routes>
  );
}

function DashboardLayout({ email }: { email: string }) {
  const location = useLocation();
  const links = [
    { to: "/users", label: "Users", icon: "◉" },
    { to: "/devices", label: "Devices", icon: "⌁" },
    { to: "/bulk-import", label: "Bulk Import", icon: "⇧" },
  ];

  return (
    <div className="portal-shell">
      <aside className="sidebar">
        <div className="brand">
          <div className="brand-mark">SF</div>
          <div>
            <strong>Smart Factory</strong>
            <span>IT provisioning</span>
          </div>
        </div>
        <nav aria-label="Administration">
          {links.map((link) => (
            <Link
              className={`nav-link ${location.pathname === link.to ? "active" : ""}`}
              key={link.to}
              to={link.to}
            >
              <span aria-hidden="true">{link.icon}</span>
              {link.label}
            </Link>
          ))}
        </nav>
        <div className="sidebar-user">
          <span className="eyebrow">SIGNED IN</span>
          <span className="user-email">{email}</span>
          <SignOutButton />
        </div>
      </aside>
      <main className="main-panel">
        <header className="topbar">
          <span>Administration / <strong>Provisioning</strong></span>
          <span className="access-badge">Admin access verified</span>
        </header>
        <div className="page-content">
          <Outlet />
        </div>
      </main>
    </div>
  );
}

function SignInPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [working, setWorking] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setWorking(true);
    setError("");
    try {
      const { error: signInError } = await supabase.auth.signInWithPassword({
        email,
        password,
      });
      if (signInError) throw signInError;
    } catch (submitError) {
      setError(
        submitError instanceof Error ? submitError.message : String(submitError),
      );
    } finally {
      setWorking(false);
    }
  }

  return (
    <main className="sign-in-page">
      <form className="sign-in-card" onSubmit={submit}>
        <div className="brand-mark">SF</div>
        <span className="eyebrow">SMART FACTORY QC</span>
        <h1>Provisioning portal</h1>
        <p>Sign in with an approved administrator account.</p>
        <label>
          Work email
          <input
            autoComplete="username"
            onChange={(event) => setEmail(event.target.value)}
            required
            type="email"
            value={email}
          />
        </label>
        <label>
          Password
          <input
            autoComplete="current-password"
            onChange={(event) => setPassword(event.target.value)}
            required
            type="password"
            value={password}
          />
        </label>
        {error && <p className="error-message">{error}</p>}
        <button className="primary-button" disabled={working} type="submit">
          {working ? "Signing in…" : "Sign in"}
        </button>
      </form>
    </main>
  );
}

function SignOutButton() {
  const [error, setError] = useState("");
  async function signOut() {
    const { error: signOutError } = await supabase.auth.signOut();
    if (signOutError) setError(signOutError.message);
  }
  return (
    <>
      <button className="sign-out-button" onClick={signOut} type="button">
        Sign out
      </button>
      {error && <span className="error-message">{error}</span>}
    </>
  );
}

function FullScreenMessage({ children }: { children: ReactNode }) {
  return <main className="full-screen-message">{children}</main>;
}
