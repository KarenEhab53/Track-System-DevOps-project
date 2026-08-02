import React, { useEffect, useState } from 'react';

const API_BASE = import.meta.env.VITE_API_BASE_URL || '/api';

export default function App() {
  const [requests, setRequests] = useState([]);
  const [form, setForm] = useState({
    employee_name: '',
    leave_type: 'annual',
    start_date: '',
    end_date: '',
  });
  const [error, setError] = useState(null);

  const loadRequests = async () => {
    try {
      const res = await fetch(`${API_BASE}/leave-requests`);
      if (!res.ok) throw new Error('Failed to load leave requests');
      setRequests(await res.json());
    } catch (err) {
      setError(err.message);
    }
  };

  useEffect(() => {
    loadRequests();
  }, []);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError(null);
    try {
      const res = await fetch(`${API_BASE}/leave-requests`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(form),
      });
      if (!res.ok) throw new Error('Failed to submit leave request');
      setForm({ employee_name: '', leave_type: 'annual', start_date: '', end_date: '' });
      loadRequests();
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <div className="container">
      <h1>Track System - Leave Requests</h1>

      <form onSubmit={handleSubmit} className="form">
        <input
          placeholder="Employee name"
          value={form.employee_name}
          onChange={(e) => setForm({ ...form, employee_name: e.target.value })}
          required
        />
        <select
          value={form.leave_type}
          onChange={(e) => setForm({ ...form, leave_type: e.target.value })}
        >
          <option value="annual">Annual</option>
          <option value="sick">Sick</option>
          <option value="unpaid">Unpaid</option>
        </select>
        <input
          type="date"
          value={form.start_date}
          onChange={(e) => setForm({ ...form, start_date: e.target.value })}
          required
        />
        <input
          type="date"
          value={form.end_date}
          onChange={(e) => setForm({ ...form, end_date: e.target.value })}
          required
        />
        <button type="submit">Submit request</button>
      </form>

      {error && <p className="error">{error}</p>}

      <table>
        <thead>
          <tr>
            <th>Employee</th>
            <th>Type</th>
            <th>Start</th>
            <th>End</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          {requests.map((r) => (
            <tr key={r.id}>
              <td>{r.employee_name}</td>
              <td>{r.leave_type}</td>
              <td>{r.start_date}</td>
              <td>{r.end_date}</td>
              <td>{r.status}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
