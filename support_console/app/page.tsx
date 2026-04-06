"use client";

import { FormEvent, useEffect, useState } from "react";

type ApiRecord = Record<string, unknown>;

type SessionState = {
  accessToken: string;
  refreshToken?: string;
  user?: ApiRecord;
};

const moduleCatalog = [
  "sales",
  "shifts",
  "finance",
  "customers",
  "suppliers",
  "expenses",
  "inventory",
  "tankers",
  "payroll",
  "reports",
  "financial_documents",
  "notifications",
  "hardware",
  "pos",
  "attendance",
  "governance",
];

function textValue(value: unknown, fallback = "Unknown") {
  if (value === null || value === undefined || value === "") return fallback;
  return String(value);
}

function numberValue(value: unknown) {
  return typeof value === "number" ? value : 0;
}

function boolValue(value: unknown) {
  return value === true;
}

function getId(item: ApiRecord) {
  return numberValue(item.id);
}

function upsertModuleSetting(current: ApiRecord[], setting: ApiRecord) {
  const moduleName = textValue(setting.module_name);
  const withoutCurrent = current.filter(
    (item) => textValue(item.module_name) !== moduleName,
  );
  return [...withoutCurrent, setting].sort((left, right) =>
    textValue(left.module_name).localeCompare(textValue(right.module_name)),
  );
}

async function readJson(response: Response) {
  const text = await response.text();
  if (!text) return {};
  try {
    return JSON.parse(text);
  } catch {
    return { detail: text };
  }
}

export default function SupportConsolePage() {
  const [session, setSession] = useState<SessionState | null>(null);
  const [username, setUsername] = useState("masteradmin");
  const [password, setPassword] = useState("master123");
  const [organizations, setOrganizations] = useState<ApiRecord[]>([]);
  const [stations, setStations] = useState<ApiRecord[]>([]);
  const [users, setUsers] = useState<ApiRecord[]>([]);
  const [employeeProfiles, setEmployeeProfiles] = useState<ApiRecord[]>([]);
  const [notificationSummary, setNotificationSummary] =
    useState<ApiRecord | null>(null);
  const [notificationDiagnostics, setNotificationDiagnostics] =
    useState<ApiRecord | null>(null);
  const [documentDiagnostics, setDocumentDiagnostics] =
    useState<ApiRecord | null>(null);
  const [recentNotifications, setRecentNotifications] = useState<ApiRecord[]>(
    [],
  );
  const [recentDispatches, setRecentDispatches] = useState<ApiRecord[]>([]);
  const [plans, setPlans] = useState<ApiRecord[]>([]);
  const [subscription, setSubscription] = useState<ApiRecord | null>(null);
  const [organizationModules, setOrganizationModules] = useState<ApiRecord[]>(
    [],
  );
  const [stationModules, setStationModules] = useState<ApiRecord[]>([]);
  const [selectedOrganizationId, setSelectedOrganizationId] = useState<
    number | null
  >(null);
  const [selectedStationId, setSelectedStationId] = useState<number | null>(
    null,
  );
  const [status, setStatus] = useState<string | null>(null);
  const [isBusy, setIsBusy] = useState(false);

  useEffect(() => {
    const stored = window.localStorage.getItem("ppms-support-session");
    if (!stored) return;
    try {
      const parsed = JSON.parse(stored) as SessionState;
      setSession(parsed);
      void loadSupportData(parsed);
    } catch {
      window.localStorage.removeItem("ppms-support-session");
    }
    // Restore the persisted browser session once on page load.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function apiFetch(path: string, options: RequestInit = {}) {
    const headers = new Headers(options.headers);
    headers.set("Content-Type", "application/json");
    if (session?.accessToken) {
      headers.set("Authorization", `Bearer ${session.accessToken}`);
    }
    const response = await fetch(`/api/ppms${path}`, {
      ...options,
      headers,
      cache: "no-store",
    });
    const json = await readJson(response);
    if (!response.ok) {
      const detail = json.detail ?? json.message ?? response.statusText;
      throw new Error(typeof detail === "string" ? detail : JSON.stringify(detail));
    }
    return json;
  }

  async function login(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setIsBusy(true);
    setStatus(null);
    try {
      const response = await fetch("/api/ppms/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ username, password }),
      });
      const token = await readJson(response);
      if (!response.ok) {
        throw new Error(textValue(token.detail, "Login failed"));
      }
      const nextSession: SessionState = {
        accessToken: textValue(token.access_token, ""),
        refreshToken: textValue(token.refresh_token, ""),
        user: token,
      };
      setSession(nextSession);
      window.localStorage.setItem(
        "ppms-support-session",
        JSON.stringify(nextSession),
      );
      await loadSupportData(nextSession);
      setStatus("Signed in to the support console.");
    } catch (error) {
      setStatus(error instanceof Error ? error.message : "Login failed");
    } finally {
      setIsBusy(false);
    }
  }

  async function loadSupportData(activeSession = session) {
    if (!activeSession?.accessToken) return;
    setIsBusy(true);
    setStatus(null);
    try {
      const headers = {
        Authorization: `Bearer ${activeSession.accessToken}`,
        "Content-Type": "application/json",
      };
      const [
        meResponse,
        organizationResponse,
        planResponse,
        notificationSummaryResponse,
        notificationDiagnosticsResponse,
        documentDiagnosticsResponse,
        notificationResponse,
        dispatchResponse,
      ] =
        await Promise.all([
          fetch("/api/ppms/auth/me", { headers, cache: "no-store" }),
          fetch("/api/ppms/organizations?limit=200", {
            headers,
            cache: "no-store",
          }),
          fetch("/api/ppms/saas/plans", { headers, cache: "no-store" }),
          fetch("/api/ppms/notifications/summary", {
            headers,
            cache: "no-store",
          }),
          fetch("/api/ppms/notifications/deliveries/diagnostics", {
            headers,
            cache: "no-store",
          }),
          fetch("/api/ppms/financial-documents/dispatches/diagnostics", {
            headers,
            cache: "no-store",
          }),
          fetch("/api/ppms/notifications?limit=8", {
            headers,
            cache: "no-store",
          }),
          fetch("/api/ppms/financial-documents/dispatches?limit=8", {
            headers,
            cache: "no-store",
          }),
        ]);
      const [
        me,
        organizationJson,
        planJson,
        notificationSummaryJson,
        notificationDiagnosticsJson,
        documentDiagnosticsJson,
        notificationJson,
        dispatchJson,
      ] = await Promise.all([
        readJson(meResponse),
        readJson(organizationResponse),
        readJson(planResponse),
        readJson(notificationSummaryResponse),
        readJson(notificationDiagnosticsResponse),
        readJson(documentDiagnosticsResponse),
        readJson(notificationResponse),
        readJson(dispatchResponse),
      ]);
      if (!meResponse.ok) throw new Error(textValue(me.detail, "Session failed"));
      if (!organizationResponse.ok) {
        throw new Error(textValue(organizationJson.detail, "Organization load failed"));
      }
      if (!planResponse.ok) throw new Error(textValue(planJson.detail, "Plan load failed"));
      if (!notificationSummaryResponse.ok) {
        throw new Error(
          textValue(notificationSummaryJson.detail, "Notification summary failed"),
        );
      }
      if (!notificationDiagnosticsResponse.ok) {
        throw new Error(
          textValue(
            notificationDiagnosticsJson.detail,
            "Notification diagnostics failed",
          ),
        );
      }
      if (!documentDiagnosticsResponse.ok) {
        throw new Error(
          textValue(documentDiagnosticsJson.detail, "Document diagnostics failed"),
        );
      }
      if (!notificationResponse.ok) {
        throw new Error(textValue(notificationJson.detail, "Notification list failed"));
      }
      if (!dispatchResponse.ok) {
        throw new Error(textValue(dispatchJson.detail, "Dispatch list failed"));
      }

      const organizationList = Array.isArray(organizationJson)
        ? organizationJson
        : [];
      const planList = Array.isArray(planJson) ? planJson : [];
      const nextOrganizationId =
        selectedOrganizationId ?? getId(organizationList[0] ?? {});

      const nextSession = { ...activeSession, user: me };
      setSession(nextSession);
      window.localStorage.setItem(
        "ppms-support-session",
        JSON.stringify(nextSession),
      );
      setOrganizations(organizationList);
      setPlans(planList);
      setNotificationSummary(notificationSummaryJson);
      setNotificationDiagnostics(notificationDiagnosticsJson);
      setDocumentDiagnostics(documentDiagnosticsJson);
      setRecentNotifications(Array.isArray(notificationJson) ? notificationJson : []);
      setRecentDispatches(Array.isArray(dispatchJson) ? dispatchJson : []);
      setSelectedOrganizationId(nextOrganizationId || null);

      if (nextOrganizationId) {
        await loadOrganizationContext(nextOrganizationId, activeSession);
      }
    } catch (error) {
      setStatus(error instanceof Error ? error.message : "Support data load failed");
    } finally {
      setIsBusy(false);
    }
  }

  async function loadOrganizationContext(
    organizationId: number,
    activeSession = session,
  ) {
    if (!activeSession?.accessToken) return;
    const headers = {
      Authorization: `Bearer ${activeSession.accessToken}`,
      "Content-Type": "application/json",
    };
    const [
      stationResponse,
      subscriptionResponse,
      moduleResponse,
      userResponse,
      employeeProfileResponse,
    ] =
      await Promise.all([
        fetch(`/api/ppms/stations?organization_id=${organizationId}&limit=200`, {
          headers,
          cache: "no-store",
        }),
        fetch(`/api/ppms/saas/organizations/${organizationId}/subscription`, {
          headers,
          cache: "no-store",
        }),
        fetch(`/api/ppms/organization-modules/${organizationId}`, {
          headers,
          cache: "no-store",
        }),
        fetch(`/api/ppms/users?organization_id=${organizationId}&limit=200`, {
          headers,
          cache: "no-store",
        }),
        fetch(
          `/api/ppms/employee-profiles?organization_id=${organizationId}&limit=200`,
          {
            headers,
            cache: "no-store",
          },
        ),
      ]);
    const [
      stationJson,
      subscriptionJson,
      moduleJson,
      userJson,
      employeeProfileJson,
    ] = await Promise.all([
      readJson(stationResponse),
      readJson(subscriptionResponse),
      readJson(moduleResponse),
      readJson(userResponse),
      readJson(employeeProfileResponse),
    ]);
    if (!stationResponse.ok) {
      throw new Error(textValue(stationJson.detail, "Station load failed"));
    }
    if (!subscriptionResponse.ok) {
      throw new Error(textValue(subscriptionJson.detail, "Subscription load failed"));
    }
    if (!moduleResponse.ok) {
      throw new Error(textValue(moduleJson.detail, "Module load failed"));
    }
    if (!userResponse.ok) {
      throw new Error(textValue(userJson.detail, "User load failed"));
    }
    if (!employeeProfileResponse.ok) {
      throw new Error(
        textValue(employeeProfileJson.detail, "Employee profile load failed"),
      );
    }
    const stationList = Array.isArray(stationJson) ? stationJson : [];
    const nextStationId = getId(stationList[0] ?? {}) || null;
    setStations(stationList);
    setSubscription(subscriptionJson);
    setOrganizationModules(Array.isArray(moduleJson) ? moduleJson : []);
    setUsers(Array.isArray(userJson) ? userJson : []);
    setEmployeeProfiles(
      Array.isArray(employeeProfileJson) ? employeeProfileJson : [],
    );
    setSelectedStationId(nextStationId);
    if (nextStationId) {
      await loadStationModules(nextStationId, activeSession);
    } else {
      setStationModules([]);
    }
  }

  async function loadStationModules(stationId: number, activeSession = session) {
    if (!activeSession?.accessToken) return;
    const response = await fetch(`/api/ppms/station-modules/${stationId}`, {
      headers: {
        Authorization: `Bearer ${activeSession.accessToken}`,
        "Content-Type": "application/json",
      },
      cache: "no-store",
    });
    const json = await readJson(response);
    if (!response.ok) {
      throw new Error(textValue(json.detail, "Station module load failed"));
    }
    setStationModules(Array.isArray(json) ? json : []);
  }

  async function selectOrganization(organizationId: number) {
    setSelectedOrganizationId(organizationId);
    setStatus(null);
    setIsBusy(true);
    try {
      await loadOrganizationContext(organizationId);
    } catch (error) {
      setStatus(error instanceof Error ? error.message : "Organization load failed");
    } finally {
      setIsBusy(false);
    }
  }

  async function selectStation(stationId: number) {
    setSelectedStationId(stationId);
    setStatus(null);
    setIsBusy(true);
    try {
      await loadStationModules(stationId);
    } catch (error) {
      setStatus(error instanceof Error ? error.message : "Station module load failed");
    } finally {
      setIsBusy(false);
    }
  }

  async function updateOrganizationModule(moduleName: string, isEnabled: boolean) {
    if (!selectedOrganizationId) return;
    setIsBusy(true);
    try {
      const setting = await apiFetch(`/organization-modules/${selectedOrganizationId}`, {
        method: "PUT",
        body: JSON.stringify({ module_name: moduleName, is_enabled: isEnabled }),
      });
      setOrganizationModules((current) =>
        upsertModuleSetting(current, setting as ApiRecord),
      );
      setStatus(`${moduleName} ${isEnabled ? "enabled" : "disabled"} for organization.`);
    } catch (error) {
      setStatus(error instanceof Error ? error.message : "Module update failed");
    } finally {
      setIsBusy(false);
    }
  }

  async function updateStationModule(moduleName: string, isEnabled: boolean) {
    if (!selectedStationId) return;
    setIsBusy(true);
    try {
      const setting = await apiFetch(`/station-modules/${selectedStationId}`, {
        method: "PUT",
        body: JSON.stringify({ module_name: moduleName, is_enabled: isEnabled }),
      });
      setStationModules((current) =>
        upsertModuleSetting(current, setting as ApiRecord),
      );
      setStatus(`${moduleName} ${isEnabled ? "enabled" : "disabled"} for station.`);
    } catch (error) {
      setStatus(error instanceof Error ? error.message : "Station module update failed");
    } finally {
      setIsBusy(false);
    }
  }

  function logout() {
    setSession(null);
    setOrganizations([]);
    setStations([]);
    setUsers([]);
    setEmployeeProfiles([]);
    setNotificationSummary(null);
    setNotificationDiagnostics(null);
    setDocumentDiagnostics(null);
    setRecentNotifications([]);
    setRecentDispatches([]);
    setPlans([]);
    setSubscription(null);
    setOrganizationModules([]);
    setStationModules([]);
    window.localStorage.removeItem("ppms-support-session");
  }

  const selectedOrganization = organizations.find(
    (item) => getId(item) === selectedOrganizationId,
  );
  const selectedStation = stations.find((item) => getId(item) === selectedStationId);
  const enabledOrganizationModules = organizationModules.filter((item) =>
    boolValue(item.is_enabled),
  ).length;
  const enabledStationModules = stationModules.filter((item) =>
    boolValue(item.is_enabled),
  ).length;
  const activeUsers = users.filter((user) => boolValue(user.is_active)).length;
  const loginEnabledProfiles = employeeProfiles.filter((profile) =>
    boolValue(profile.can_login),
  ).length;
  const payrollEnabledProfiles = employeeProfiles.filter((profile) =>
    boolValue(profile.payroll_enabled),
  ).length;
  const stationProfiles = selectedStationId
    ? employeeProfiles.filter(
        (profile) => numberValue(profile.station_id) === selectedStationId,
      )
    : employeeProfiles;
  const failedNotificationDeliveries = numberValue(
    notificationDiagnostics?.failed,
  );
  const pendingNotificationDeliveries = numberValue(
    notificationDiagnostics?.pending,
  );
  const failedDocumentDispatches = numberValue(documentDiagnostics?.failed);
  const pendingDocumentDispatches = numberValue(documentDiagnostics?.pending);

  if (!session) {
    return (
      <main className="page">
        <section className="card login">
          <p className="eyebrow">Razex support</p>
          <h1>Master Admin Console</h1>
          <p>
            Sign in with a platform account to inspect tenants, subscriptions,
            station setup, and module controls without crowding the Flutter
            operations app.
          </p>
          <form className="form-grid" onSubmit={login}>
            <label>
              Username
              <input
                value={username}
                onChange={(event) => setUsername(event.target.value)}
                autoComplete="username"
              />
            </label>
            <label>
              Password
              <input
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                type="password"
                autoComplete="current-password"
              />
            </label>
            <div className="actions">
              <button disabled={isBusy} type="submit">
                {isBusy ? "Signing in..." : "Open support console"}
              </button>
            </div>
          </form>
          {status ? <p className="status">{status}</p> : null}
        </section>
      </main>
    );
  }

  return (
    <main className="page">
      <div className="shell">
        <section className="hero">
          <div>
            <p className="eyebrow">PPMS support console</p>
            <h1>Tenant support without tenant-app clutter.</h1>
            <p>
              Open a customer organization, inspect station setup, check package
              state, and correct module visibility from a separate Master Admin
              workspace.
            </p>
            <div className="actions">
              <button disabled={isBusy} onClick={() => void loadSupportData()}>
                Refresh support data
              </button>
              <button className="secondary" onClick={logout}>
                Sign out
              </button>
            </div>
          </div>
          <div className="card">
            <p className="eyebrow">Signed in</p>
            <h2>{textValue(session.user?.full_name, session.user?.username as string)}</h2>
            <p>
              Role {textValue(session.user?.role_name)} -{" "}
              {boolValue(session.user?.is_platform_user)
                ? "platform scope"
                : "tenant scope"}
            </p>
            <div className="chip-row">
              <span className="chip">{organizations.length} organizations</span>
              <span className="chip">{plans.length} plans</span>
              <span className="chip">{stations.length} selected-org stations</span>
              <span className="chip">{users.length} users in scope</span>
            </div>
          </div>
        </section>

        {status ? <p className="status">{status}</p> : null}

        <section className="grid">
          <div className="card span-4">
            <p className="eyebrow">Organizations</p>
            <h2>Open tenant</h2>
            <div className="list">
              {organizations.map((organization) => {
                const organizationId = getId(organization);
                return (
                  <button
                    className={`list-item ${
                      organizationId === selectedOrganizationId ? "active" : ""
                    }`}
                    disabled={isBusy}
                    key={organizationId}
                    onClick={() => void selectOrganization(organizationId)}
                    type="button"
                  >
                    <strong>{textValue(organization.name)}</strong>
                    <span className="muted">
                      {textValue(organization.code)} -{" "}
                      {textValue(organization.billing_status, "billing unknown")}
                    </span>
                  </button>
                );
              })}
            </div>
          </div>

          <div className="card span-8">
            <p className="eyebrow">Support overview</p>
            <h2>{textValue(selectedOrganization?.name, "Select an organization")}</h2>
            <div className="metric-row">
              <div className="metric">
                <span>Stations</span>
                <strong>{stations.length}</strong>
                <small>{textValue(selectedOrganization?.onboarding_status, "status unknown")}</small>
              </div>
              <div className="metric">
                <span>Subscription</span>
                <strong>{textValue(subscription?.status, "-")}</strong>
                <small>Plan #{textValue(subscription?.plan_id, "not assigned")}</small>
              </div>
              <div className="metric">
                <span>Org modules</span>
                <strong>{enabledOrganizationModules}</strong>
                <small>{organizationModules.length} configured</small>
              </div>
              <div className="metric">
                <span>Station modules</span>
                <strong>{enabledStationModules}</strong>
                <small>{stationModules.length} configured</small>
              </div>
              <div className="metric">
                <span>Users</span>
                <strong>{activeUsers}</strong>
                <small>{users.length} total accounts</small>
              </div>
            </div>
            <div className="chip-row">
              <span className="chip">
                Brand {textValue(selectedOrganization?.brand_name)}
              </span>
              <span className="chip">
                Contact {textValue(selectedOrganization?.contact_email)}
              </span>
              <span className="chip">
                Billing {textValue(selectedOrganization?.billing_status)}
              </span>
            </div>
          </div>

          <div className="card span-5">
            <p className="eyebrow">Station inspection</p>
            <h2>Stations</h2>
            <div className="list">
              {stations.length === 0 ? (
                <p>No stations found for this organization yet.</p>
              ) : (
                stations.map((station) => {
                  const stationId = getId(station);
                  return (
                    <button
                      className={`list-item ${
                        stationId === selectedStationId ? "active" : ""
                      }`}
                      disabled={isBusy}
                      key={stationId}
                      onClick={() => void selectStation(stationId)}
                      type="button"
                    >
                      <strong>{textValue(station.name)}</strong>
                      <span className="muted">
                        {textValue(station.code)} - setup{" "}
                        {textValue(station.setup_status)}
                      </span>
                    </button>
                  );
                })
              )}
            </div>
          </div>

          <div className="card span-7">
            <p className="eyebrow">Selected station</p>
            <h2>{textValue(selectedStation?.name, "No station selected")}</h2>
            <div className="chip-row">
              <span className="chip">
                POS {boolValue(selectedStation?.has_pos) ? "on" : "off"}
              </span>
              <span className="chip">
                Tankers {boolValue(selectedStation?.has_tankers) ? "on" : "off"}
              </span>
              <span className="chip">
                Hardware {boolValue(selectedStation?.has_hardware) ? "on" : "off"}
              </span>
              <span className="chip">
                Meter adjustments{" "}
                {boolValue(selectedStation?.allow_meter_adjustments) ? "on" : "off"}
              </span>
            </div>
            <p>
              Use this area for support-side investigation first. Deeper audited
              correction flows can be added here without overloading the tenant
              Flutter app.
            </p>
          </div>

          <div className="card span-6">
            <p className="eyebrow">User inspection</p>
            <h2>Login accounts</h2>
            <div className="metric-row compact">
              <div className="metric">
                <span>Active users</span>
                <strong>{activeUsers}</strong>
                <small>{users.length} total</small>
              </div>
              <div className="metric">
                <span>Platform users</span>
                <strong>
                  {
                    users.filter((user) => boolValue(user.is_platform_user))
                      .length
                  }
                </strong>
                <small>Across this query</small>
              </div>
            </div>
            <div className="list support-list">
              {users.length === 0 ? (
                <p>No user accounts found for this organization.</p>
              ) : (
                users.slice(0, 8).map((user) => (
                  <div className="list-item" key={getId(user)}>
                    <strong>{textValue(user.full_name)}</strong>
                    <span className="muted">
                      @{textValue(user.username)} - role #{textValue(user.role_id)}
                    </span>
                    <div className="chip-row">
                      <span className="chip">
                        {boolValue(user.is_active) ? "active" : "inactive"}
                      </span>
                      <span className="chip">{textValue(user.scope_level)}</span>
                      <span className="chip">
                        Station {textValue(user.station_id, "none")}
                      </span>
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>

          <div className="card span-6">
            <p className="eyebrow">Staff inspection</p>
            <h2>Employee profiles</h2>
            <div className="metric-row compact">
              <div className="metric">
                <span>Station staff</span>
                <strong>{stationProfiles.length}</strong>
                <small>Selected station scope</small>
              </div>
              <div className="metric">
                <span>Payroll ready</span>
                <strong>{payrollEnabledProfiles}</strong>
                <small>{loginEnabledProfiles} can log in</small>
              </div>
            </div>
            <div className="list support-list">
              {stationProfiles.length === 0 ? (
                <p>No employee profiles found for this station.</p>
              ) : (
                stationProfiles.slice(0, 8).map((profile) => (
                  <div className="list-item" key={getId(profile)}>
                    <strong>{textValue(profile.full_name)}</strong>
                    <span className="muted">
                      {textValue(profile.staff_type)} -{" "}
                      {textValue(profile.employee_code, "no code")}
                    </span>
                    <div className="chip-row">
                      <span className="chip">
                        {boolValue(profile.is_active) ? "active" : "inactive"}
                      </span>
                      <span className="chip">
                        payroll {boolValue(profile.payroll_enabled) ? "on" : "off"}
                      </span>
                      <span className="chip">
                        login {boolValue(profile.can_login) ? "yes" : "no"}
                      </span>
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>

          <div className="card span-6">
            <p className="eyebrow">Organization modules</p>
            <h2>Package visibility</h2>
            <ModuleGrid
              settings={organizationModules}
              disabled={isBusy || !selectedOrganizationId}
              onToggle={updateOrganizationModule}
            />
          </div>

          <div className="card span-6">
            <p className="eyebrow">Station modules</p>
            <h2>Station visibility</h2>
            <ModuleGrid
              settings={stationModules}
              disabled={isBusy || !selectedStationId}
              onToggle={updateStationModule}
            />
          </div>

          <div className="card span-12">
            <p className="eyebrow">Communications health</p>
            <h2>Notifications and document dispatch</h2>
            <p>
              Review delivery pressure before support starts changing tenant
              settings. Retry and process-due controls can stay in a later
              audited support slice.
            </p>
            <div className="metric-row">
              <div className="metric">
                <span>Unread</span>
                <strong>{textValue(notificationSummary?.unread_count, "0")}</strong>
                <small>{textValue(notificationSummary?.total_count, "0")} total</small>
              </div>
              <div className="metric">
                <span>Pending notification</span>
                <strong>{pendingNotificationDeliveries}</strong>
                <small>{failedNotificationDeliveries} failed</small>
              </div>
              <div className="metric">
                <span>Pending documents</span>
                <strong>{pendingDocumentDispatches}</strong>
                <small>{failedDocumentDispatches} failed</small>
              </div>
              <div className="metric">
                <span>Recent activity</span>
                <strong>{recentNotifications.length + recentDispatches.length}</strong>
                <small>Support-visible rows</small>
              </div>
            </div>
            <div className="grid nested-grid">
              <div className="span-6">
                <h3>Recent notifications</h3>
                <div className="list support-list">
                  {recentNotifications.length === 0 ? (
                    <p>No recent notifications found.</p>
                  ) : (
                    recentNotifications.map((notification) => (
                      <div className="list-item" key={getId(notification)}>
                        <strong>{textValue(notification.title)}</strong>
                        <span className="muted">
                          {textValue(notification.event_type)} -{" "}
                          {boolValue(notification.is_read) ? "read" : "unread"}
                        </span>
                        <span className="muted">
                          {textValue(notification.created_at, "created time unknown")}
                        </span>
                      </div>
                    ))
                  )}
                </div>
              </div>
              <div className="span-6">
                <h3>Recent document dispatches</h3>
                <div className="list support-list">
                  {recentDispatches.length === 0 ? (
                    <p>No recent document dispatches found.</p>
                  ) : (
                    recentDispatches.map((dispatch) => (
                      <div className="list-item" key={getId(dispatch)}>
                        <strong>
                          {textValue(dispatch.document_type, "Document")} #{
                            textValue(dispatch.id)
                          }
                        </strong>
                        <span className="muted">
                          {textValue(dispatch.channel)} -{" "}
                          {textValue(dispatch.status)}
                        </span>
                        <span className="muted">
                          {textValue(dispatch.recipient_contact, "no recipient")}
                        </span>
                      </div>
                    ))
                  )}
                </div>
              </div>
            </div>
          </div>
        </section>
      </div>
    </main>
  );
}

function ModuleGrid({
  settings,
  disabled,
  onToggle,
}: {
  settings: ApiRecord[];
  disabled: boolean;
  onToggle: (moduleName: string, isEnabled: boolean) => Promise<void>;
}) {
  const settingMap = new Map(
    settings.map((setting) => [
      textValue(setting.module_name),
      boolValue(setting.is_enabled),
    ]),
  );
  const modules = Array.from(
    new Set([...moduleCatalog, ...settings.map((item) => textValue(item.module_name))]),
  ).sort();

  return (
    <div className="module-grid">
      {modules.map((moduleName) => {
        const isEnabled = settingMap.get(moduleName) ?? false;
        return (
          <label className="module-toggle" key={moduleName}>
            <span>{moduleName.replaceAll("_", " ")}</span>
            <input
              checked={isEnabled}
              disabled={disabled}
              onChange={(event) => void onToggle(moduleName, event.target.checked)}
              type="checkbox"
            />
          </label>
        );
      })}
    </div>
  );
}
