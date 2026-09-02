import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

const proxyBase = '/proxy/5173/'

function proxyPathCompatibility() {
  return {
    name: 'proxy-path-compatibility',
    configureServer(server) {
      server.middlewares.use((request, _response, next) => {
        if (request.url && !request.url.startsWith(proxyBase)) {
          request.url = `${proxyBase.slice(0, -1)}${request.url}`
        }
        next()
      })
    },
  }
}

export default defineConfig(({ command }) => ({
  plugins: [
    proxyPathCompatibility(),
    react(),
  ],
  base: command === 'serve' ? proxyBase : './',
}))
