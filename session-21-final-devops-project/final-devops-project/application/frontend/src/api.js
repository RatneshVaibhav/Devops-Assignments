// All calls are relative: nginx (Docker) or the Ingress (Kubernetes) routes /api to the backend.
async function request(path, options = {}) {
  const res = await fetch(path, {
    headers: { "Content-Type": "application/json" },
    ...options,
  });
  if (res.status === 204) return null;
  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    const detail = Array.isArray(body.detail) ? body.detail.map((d) => d.msg).join(", ") : body.detail;
    throw new Error(detail || `HTTP ${res.status}`);
  }
  return body;
}

export const api = {
  list: (params) => request(`/api/books?${new URLSearchParams(params)}`),
  stats: () => request("/api/books/stats"),
  create: (book) => request("/api/books", { method: "POST", body: JSON.stringify(book) }),
  update: (id, changes) => request(`/api/books/${id}`, { method: "PUT", body: JSON.stringify(changes) }),
  reserve: (id, name) => request(`/api/books/${id}/reserve`, { method: "POST", body: JSON.stringify({ reserved_by: name }) }),
  remove: (id) => request(`/api/books/${id}`, { method: "DELETE" }),
};
