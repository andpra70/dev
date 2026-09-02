import { useState } from 'react'

const DEMO_USER = {
  username: 'demo',
  password: 'password123',
}

function Login({ onLogin }) {
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [showPassword, setShowPassword] = useState(false)

  function handleSubmit(event) {
    event.preventDefault()
    setError('')

    if (!username.trim() || !password) {
      setError('Inserisci username e password.')
      return
    }

    if (username.trim() !== DEMO_USER.username || password !== DEMO_USER.password) {
      setError('Credenziali non valide. Riprova.')
      return
    }

    onLogin(username.trim())
  }

  return (
    <main className="app-shell">
      <section className="login-card" aria-labelledby="login-title">
        <div className="brand" aria-hidden="true">H</div>
        <div className="heading">
          <span className="eyebrow">Area riservata</span>
          <h1 id="login-title">Bentornato</h1>
          <p>Accedi per continuare nella tua area personale.</p>
        </div>

        <form onSubmit={handleSubmit} noValidate>
          <label htmlFor="username">Username</label>
          <input
            id="username"
            name="username"
            type="text"
            autoComplete="username"
            placeholder="Il tuo username"
            value={username}
            onChange={(event) => setUsername(event.target.value)}
            aria-invalid={Boolean(error)}
            autoFocus
          />

          <label htmlFor="password">Password</label>
          <div className="password-field">
            <input
              id="password"
              name="password"
              type={showPassword ? 'text' : 'password'}
              autoComplete="current-password"
              placeholder="La tua password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              aria-invalid={Boolean(error)}
            />
            <button
              className="show-password"
              type="button"
              onClick={() => setShowPassword((visible) => !visible)}
              aria-label={showPassword ? 'Nascondi password' : 'Mostra password'}
            >
              {showPassword ? 'Nascondi' : 'Mostra'}
            </button>
          </div>

          {error && <p className="error" role="alert">{error}</p>}

          <button className="submit-button" type="submit">Accedi <span>→</span></button>
        </form>

        <div className="demo-note">
          <span>Credenziali demo</span>
          <code>demo / password123</code>
        </div>
      </section>
    </main>
  )
}

function Welcome({ username, onLogout }) {
  return (
    <main className="app-shell">
      <section className="welcome-card">
        <div className="success-mark" aria-hidden="true">✓</div>
        <span className="eyebrow">Accesso effettuato</span>
        <h1>Hello World!</h1>
        <p>Ciao <strong>{username}</strong>, sei entrato correttamente.</p>
        <button className="logout-button" type="button" onClick={onLogout}>Esci</button>
      </section>
    </main>
  )
}

export default function App() {
  const [user, setUser] = useState(() => sessionStorage.getItem('loggedUser'))

  function handleLogin(username) {
    sessionStorage.setItem('loggedUser', username)
    setUser(username)
  }

  function handleLogout() {
    sessionStorage.removeItem('loggedUser')
    setUser(null)
  }

  return user
    ? <Welcome username={user} onLogout={handleLogout} />
    : <Login onLogin={handleLogin} />
}
