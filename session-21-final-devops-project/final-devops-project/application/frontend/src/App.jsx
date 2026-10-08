import { useCallback, useEffect, useState } from "react";
import { api } from "./api.js";

const STATUSES = ["all", "available", "reserved", "exchanged"];
const EMPTY = { title: "", author: "", course_code: "", condition: "good", owner_name: "" };

function StatCard({ label, value, tone }) {
  return (
    <div className={`stat stat-${tone}`}>
      <span className="stat-value">{value}</span>
      <span className="stat-label">{label}</span>
    </div>
  );
}

function BookCard({ book, onReserve, onExchange, onRelease, onDelete }) {
  const [name, setName] = useState("");
  return (
    <article className="book">
      <header>
        <span className="course">{book.course_code}</span>
        <span className={`pill pill-${book.status}`}>{book.status}</span>
      </header>
      <h3>{book.title}</h3>
      <p className="author">{book.author}</p>
      <p className="meta">
        Condition <b>{book.condition}</b> · listed by <b>{book.owner_name}</b>
        {book.reserved_by && <> · reserved by <b>{book.reserved_by}</b></>}
      </p>
      <footer>
        {book.status === "available" && (
          <form onSubmit={(e) => { e.preventDefault(); if (name.trim()) onReserve(book.id, name.trim()); }}>
            <input value={name} onChange={(e) => setName(e.target.value)} placeholder="Your name" aria-label="Your name" />
            <button className="primary">Reserve</button>
          </form>
        )}
        {book.status === "reserved" && (
          <>
            <button className="primary" onClick={() => onExchange(book.id)}>Mark exchanged</button>
            <button onClick={() => onRelease(book.id)}>Release</button>
          </>
        )}
        <button className="ghost" onClick={() => onDelete(book.id)} aria-label={`Remove ${book.title}`}>Remove</button>
      </footer>
    </article>
  );
}

export default function App() {
  const [books, setBooks] = useState([]);
  const [stats, setStats] = useState(null);
  const [status, setStatus] = useState("all");
  const [query, setQuery] = useState("");
  const [form, setForm] = useState(EMPTY);
  const [showForm, setShowForm] = useState(false);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    try {
      const params = {};
      if (status !== "all") params.status = status;
      if (query) params.q = query;
      const [list, s] = await Promise.all([api.list(params), api.stats()]);
      setBooks(list);
      setStats(s);
      setError("");
    } catch (e) {
      setError(`Cannot reach the ShelfShare API (${e.message}).`);
    } finally {
      setLoading(false);
    }
  }, [status, query]);

  useEffect(() => { load(); }, [load]);

  const run = (action) => async (...args) => {
    try { await action(...args); await load(); } catch (e) { setError(e.message); }
  };

  const submit = run(async (e) => {
    e.preventDefault();
    await api.create({ ...form, course_code: form.course_code.toUpperCase() });
    setForm(EMPTY);
    setShowForm(false);
  });

  return (
    <div className="page">
      <header className="top">
        <div className="brand">
          <img src="/favicon.svg" alt="" width="36" height="36" />
          <div>
            <h1>ShelfShare</h1>
            <p>Lend and reserve textbooks with students on your campus</p>
          </div>
        </div>
        <button className="primary" onClick={() => setShowForm(!showForm)}>
          {showForm ? "Close" : "List a book"}
        </button>
      </header>

      {error && <div className="banner" role="alert">{error}</div>}

      {stats && (
        <section className="stats" aria-label="Exchange statistics">
          <StatCard label="Books listed" value={stats.total} tone="total" />
          <StatCard label="Available" value={stats.by_status.available} tone="available" />
          <StatCard label="Reserved" value={stats.by_status.reserved} tone="reserved" />
          <StatCard label="Exchanged" value={stats.by_status.exchanged} tone="exchanged" />
        </section>
      )}

      {showForm && (
        <form className="new-book" onSubmit={submit}>
          <h2>List a book</h2>
          <div className="grid">
            <input required minLength={2} placeholder="Title" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
            <input required minLength={2} placeholder="Author" value={form.author} onChange={(e) => setForm({ ...form, author: e.target.value })} />
            <input required pattern="[A-Za-z]{2,4}[0-9]{3}" placeholder="Course code, e.g. CS301" value={form.course_code} onChange={(e) => setForm({ ...form, course_code: e.target.value })} />
            <select value={form.condition} onChange={(e) => setForm({ ...form, condition: e.target.value })}>
              {["new", "good", "fair", "worn"].map((c) => <option key={c}>{c}</option>)}
            </select>
            <input required minLength={2} placeholder="Your name" value={form.owner_name} onChange={(e) => setForm({ ...form, owner_name: e.target.value })} />
            <button className="primary">Publish listing</button>
          </div>
        </form>
      )}

      <section className="toolbar">
        <input type="search" placeholder="Search title or author" value={query} onChange={(e) => setQuery(e.target.value)} aria-label="Search" />
        <div className="chips" role="tablist">
          {STATUSES.map((s) => (
            <button key={s} role="tab" aria-selected={status === s} className={status === s ? "chip active" : "chip"} onClick={() => setStatus(s)}>{s}</button>
          ))}
        </div>
      </section>

      <main className="layout">
        <section className="books" aria-live="polite">
          {loading && <p className="muted">Loading books...</p>}
          {!loading && books.length === 0 && !error && <p className="muted">No books match. List one!</p>}
          {books.map((b) => (
            <BookCard key={b.id} book={b}
              onReserve={run(api.reserve)}
              onExchange={run((id) => api.update(id, { status: "exchanged" }))}
              onRelease={run((id) => api.update(id, { status: "available" }))}
              onDelete={run(api.remove)} />
          ))}
        </section>
        {stats && stats.top_courses.length > 0 && (
          <aside className="courses">
            <h2>Most shared courses</h2>
            <ol>
              {stats.top_courses.map((c) => (
                <li key={c.course_code}><span>{c.course_code}</span><b>{c.books}</b></li>
              ))}
            </ol>
          </aside>
        )}
      </main>
      <footer className="foot">ShelfShare · Session 21 final DevOps project · Ratnesh Vaibhav</footer>
    </div>
  );
}
