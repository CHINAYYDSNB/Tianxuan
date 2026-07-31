#!/usr/bin/env node
// Combined static file server + API proxy + SSH WebSocket proxy for Tianxuan Flutter app
// Serves Flutter web build, proxies /api/v2/* to 1Panel server, proxies SSH via WebSocket
//
// Usage:
//   node server.mjs
//
// Environment variables (or create .env file):
//   API_HOST   — 1Panel server IP (default: placeholder)
//   API_PORT   — 1Panel server port (default: 25567)
//   PORT       — dev server port   (default: 25568)
//   API_KEY    — API Key for auto-login (optional, omit to use login page)

import http from 'http';
import https from 'https';
import fs from 'fs';
import path from 'path';
import { execSync } from 'child_process';
import { WebSocketServer, WebSocket } from 'ws';
import { Client } from 'ssh2';
import { createHash } from 'crypto';

function fetchUrl(url, res) {
  const mod = url.startsWith('https') ? https : http;
  mod.get(url, pr => {
    const ct = pr.headers['content-type'] || 'application/octet-stream';
    res.writeHead(pr.statusCode, { 'Access-Control-Allow-Origin': '*', 'Content-Type': ct });
    pr.pipe(res);
  }).on('error', e => { res.writeHead(502); res.end(JSON.stringify({error: e.message})); });
}

// Load .env file if exists
const envPath = path.resolve(import.meta.dirname, '.env');
if (fs.existsSync(envPath)) {
  const lines = fs.readFileSync(envPath, 'utf-8').split('\n');
  for (const line of lines) {
    const m = line.match(/^\s*(\w+)=(.*)$/);
    if (m) process.env[m[1]] = m[2].trim();
  }
}

const PORT       = parseInt(process.env.PORT || '25568', 10);
const API_HOST   = process.env.API_HOST || 'your.1panel.server.ip';
const API_PORT   = parseInt(process.env.API_PORT || '25567', 10);
const API_KEY    = process.env.API_KEY || '';
const API_TLS    = process.env.API_TLS === '1' || process.env.API_TLS === 'true';
const STATIC_DIR = path.resolve(import.meta.dirname, 'build', 'web');

const MIME = {
  '.html': 'text/html',
  '.js': 'application/javascript',
  '.mjs': 'application/javascript',
  '.css': 'text/css',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.map': 'application/json',
  '.txt': 'text/plain',
};

function serveStatic(req, res) {
  let filePath = req.url === '/' ? '/index.html' : req.url.split('?')[0];
  const fullPath = path.join(STATIC_DIR, filePath);
  if (!fs.existsSync(fullPath) || fs.statSync(fullPath).isDirectory()) {
    filePath = '/index.html';
  }
  const absPath = path.join(STATIC_DIR, filePath);
  const ext = path.extname(filePath);
  const ct = MIME[ext] || 'application/octet-stream';
  try {
    let content = fs.readFileSync(absPath);
    if (filePath === '/index.html' && API_KEY) {
      const inject = `<script>
localStorage.setItem('server_url','http://localhost:${PORT}');
localStorage.setItem('api_key','${API_KEY}');
</script>`;
      content = Buffer.from(content.toString().replace('</head>', inject + '</head>'));
    }
    res.writeHead(200, { 'Content-Type': ct, 'Cache-Control': 'no-cache' });
    res.end(content);
  } catch {
    res.writeHead(404);
    res.end('Not found');
  }
}

function proxyAPI(req, res) {
  console.log(`[proxy] ${req.method} ${req.url}`);
  const proxyReq = http.request(
    {
      method: req.method,
      hostname: API_HOST,
      port: API_PORT,
      path: req.url,
      headers: { ...req.headers, host: `${API_HOST}:${API_PORT}` },
    },
    (proxyRes) => {
      res.writeHead(proxyRes.statusCode, { ...proxyRes.headers });
      proxyRes.pipe(res);
    }
  );
  proxyReq.on('error', (e) => {
    console.error(`[proxy] Error: ${e.message}`);
    if (res.headersSent) return;
    res.writeHead(502, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ code: 502, message: `Proxy error: ${e.message}` }));
  });
  req.pipe(proxyReq);
}

// ─── 脚本执行 API ───
async function handleScriptExec(req, res) {
  let body = '';
  req.on('data', c => body += c);
  req.on('end', () => {
    try {
      const { path: scriptPath, content } = JSON.parse(body);
      const absPath = path.resolve(scriptPath);
      if (content) fs.writeFileSync(absPath, content, 'utf-8');
      fs.chmodSync(absPath, 0o755);
      const out = execSync(`cd ${path.dirname(absPath)} && ./${path.basename(absPath)}`, {
        timeout: 60000, encoding: 'utf-8',
      });
      res.writeHead(200, { 'Content-Type': 'text/plain' });
      res.end(out);
    } catch (e) {
      res.writeHead(500, { 'Content-Type': 'text/plain' });
      res.end(e.stderr || e.message || String(e));
    }
  });
}

// ─── HTTP Server (static + API proxy) ───
const server = http.createServer((req, res) => {
  if (req.method === 'POST' && req.url === '/api/script/exec') {
    handleScriptExec(req, res);
  } else if (req.url === '/api/script/index') {
    // Try CNB first, fallback GitHub
    const cnbUrl = 'https://cnb.cool/Lingqi_Team/Tianxuan/-/raw/main/scripts/index.json';
    const ghUrl = 'https://raw.githubusercontent.com/CHINAYYDSNB/Tianxuan/main/scripts/index.json';
    const cnbReq = https.get(cnbUrl, cnbRes => {
      if (cnbRes.statusCode === 200) {
        res.writeHead(200, { 'Access-Control-Allow-Origin': '*', 'Content-Type': 'application/json' });
        cnbRes.pipe(res);
      } else {
        fetchUrl(ghUrl, res);
      }
    });
    cnbReq.on('error', () => fetchUrl(ghUrl, res));
    cnbReq.setTimeout(5000, () => { cnbReq.destroy(); fetchUrl(ghUrl, res); });
  } else if (req.url.startsWith('/api/script/detail/')) {
    const id = req.url.split('/').pop();
    const cnbUrl = `https://cnb.cool/Lingqi_Team/Tianxuan/-/raw/main/scripts/details/${id}.json`;
    const ghUrl = `https://raw.githubusercontent.com/CHINAYYDSNB/Tianxuan/main/scripts/details/${id}.json`;
    const cnbReq = https.get(cnbUrl, cnbRes => {
      if (cnbRes.statusCode === 200) {
        res.writeHead(200, { 'Access-Control-Allow-Origin': '*', 'Content-Type': 'application/json' });
        cnbRes.pipe(res);
      } else {
        fetchUrl(ghUrl, res);
      }
    });
    cnbReq.on('error', () => fetchUrl(ghUrl, res));
    cnbReq.setTimeout(5000, () => { cnbReq.destroy(); fetchUrl(ghUrl, res); });
  } else if (req.url.startsWith('/api/script-download')) {
    const up = new URL(req.url, `http://${req.headers.host}`);
    const target = decodeURIComponent(up.searchParams.get('url') || '');
    if (!target) { res.writeHead(400); res.end('Missing url'); return; }
    fetchUrl(target, res);
  } else if (req.url.startsWith('/scripts-store/')) {
    // 脚本商店：同源代理到 gitee raw CDN，规避浏览器 CORS（gitee 不返回 ACAO 头）
    const rest = req.url.slice('/scripts-store/'.length);
    const cdnUrl = 'https://raw.giteeusercontent.com/happyfurry/scripts_store/raw/main/scripts/' + rest;
    fetchUrl(cdnUrl, res);
  } else if (req.url.startsWith('/api/v2/')) {
    proxyAPI(req, res);
  } else {
    serveStatic(req, res);
  }
});

// ─── SSH WebSocket Proxy ───
const wss = new WebSocketServer({ noServer: true });

wss.on('connection', (ws, req) => {
  console.log('[ssh] WebSocket connected');

  let sshConfig = null;
  let sshClient = null;
  let sshStream = null;
  let shellOpts = { cols: 80, rows: 24 };

  ws.on('message', (data) => {
    try {
      const msg = JSON.parse(data.toString());

      if (msg.type === 'connect') {
        // First message: SSH connection config
        sshConfig = msg;
        sshClient = new Client();

        sshClient.on('ready', () => {
          console.log('[ssh] Connected to ' + targetHost + ':' + targetPort);
          sshClient.shell(shellOpts, (err, stream) => {
            if (err) {
              ws.send(JSON.stringify({ type: 'error', message: err.message }));
              return;
            }
            sshStream = stream;

            stream.on('data', (chunk) => {
              ws.send(JSON.stringify({ type: 'data', data: chunk.toString('base64') }));
            });

            stream.stderr.on('data', (chunk) => {
              ws.send(JSON.stringify({ type: 'data', data: chunk.toString('base64') }));
            });

            stream.on('close', () => {
              console.log('[ssh] Shell closed');
              ws.send(JSON.stringify({ type: 'close' }));
            });

            ws.send(JSON.stringify({ type: 'ready' }));
          });
        });

        sshClient.on('error', (err) => {
          console.error('[ssh] Error:', err.message);
          ws.send(JSON.stringify({ type: 'error', message: err.message }));
        });

        sshClient.on('close', () => {
          console.log('[ssh] Connection closed');
          ws.close();
        });

        // Resolve the "1Panel host" sentinel (used by the auto-imported web
        // SSH connection) to the real 1Panel server for the proxy-side ssh2
        // connection. The browser never learns the real host (CORS proxy).
        let targetHost = sshConfig.host;
        let targetPort = sshConfig.port || 22;
        if (targetHost === 'panel' || targetHost === 'localhost' || targetHost === '127.0.0.1') {
          targetHost = API_HOST;
          targetPort = 22;
        }

        const connectOpts = {
          host: targetHost,
          port: targetPort,
          username: sshConfig.username,
          readyTimeout: 10000,
          tryKeyboard: true,
        };
        if (sshConfig.password) connectOpts.password = sshConfig.password;
        if (sshConfig.privateKey) connectOpts.privateKey = sshConfig.privateKey;

        sshClient.on('keyboard-interactive', (name, instructions, instructionsLang, prompts, finish) => {
          const password = sshConfig.password || '';
          finish([password]);
        });

        sshClient.connect(connectOpts);

      } else if (msg.type === 'resize') {
        shellOpts = { cols: msg.cols || 80, rows: msg.rows || 24 };
        if (sshStream) sshStream.setWindow(shellOpts.rows, shellOpts.cols, 0, 0);

      } else if (msg.type === 'input') {
        if (sshStream && msg.data) {
          sshStream.write(Buffer.from(msg.data, 'base64'));
        }
      }
    } catch (e) {
      console.error('[ssh] Message error:', e.message);
    }
  });

  ws.on('close', () => {
    console.log('[ssh] WebSocket disconnected');
    if (sshStream) sshStream.close();
    if (sshClient) sshClient.end();
  });

  ws.on('error', () => {});
});

// ─── 1Panel WsSSH Terminal Proxy ───
// Bridges the browser to the 1Panel `GET /api/v2/hosts/terminal` WebSocket.
// The 1Panel endpoint requires the `1Panel-Token` / `1Panel-Timestamp` headers,
// which browsers cannot set on a WebSocket — so this proxy computes them
// server-side from API_KEY and injects them into the upstream handshake.
// Opening the endpoint without a host `id` makes 1Panel spawn a PTY on the
// local machine, so no separate SSH credentials are needed.
function panelAuthHeaders() {
  const ts = Math.floor(Date.now() / 1000);
  const token = createHash('md5')
    .update('1panel' + API_KEY + ts)
    .digest('hex');
  return { '1Panel-Token': token, '1Panel-Timestamp': String(ts) };
}

const panelWss = new WebSocketServer({ noServer: true });

panelWss.on('connection', (clientWs) => {
  console.log('[panel-terminal] client connected');

  const scheme = API_TLS ? 'wss' : 'ws';
  const downstreamUrl = `${scheme}://${API_HOST}:${API_PORT}/api/v2/hosts/terminal?cols=80&rows=24`;
  const _h = panelAuthHeaders();
  console.log('[panel-terminal] downstream', downstreamUrl, 'token', _h['1Panel-Token'].slice(0, 8) + '...');
  let downWs;
  try {
    downWs = new WebSocket(downstreamUrl, { headers: panelAuthHeaders() });
  } catch (e) {
    console.error('[panel-terminal] upstream init error:', e.message);
    safeSend(clientWs, JSON.stringify({
      type: 'cmd',
      data: Buffer.from(`\r\n[1Panel 终端错误] ${e.message}\r\n`).toString('base64'),
    }));
    clientWs.close();
    return;
  }

  let downstreamOpen = false;
  downWs.on('open', () => {
    downstreamOpen = true;
    console.log('[panel-terminal] upstream opened');
  });

  downWs.on('unexpected-response', (req, res) => {
    let body = '';
    res.on('data', (c) => (body += c));
    res.on('end', () => {
      console.error('[panel-terminal] upstream unexpected', res.statusCode, body);
    });
  });

  downWs.on('message', (data) => {
    if (clientWs.readyState === clientWs.OPEN) clientWs.send(data);
  });

  downWs.on('close', () => {
    console.log('[panel-terminal] upstream closed');
    if (clientWs.readyState === clientWs.OPEN) clientWs.close();
  });

  downWs.on('error', (e) => {
    console.error('[panel-terminal] upstream error:', e.message);
    safeSend(clientWs, JSON.stringify({
      type: 'cmd',
      data: Buffer.from(`\r\n[1Panel 终端错误] ${e.message}\r\n`).toString('base64'),
    }));
    if (clientWs.readyState === clientWs.OPEN) clientWs.close();
  });

  clientWs.on('message', (data) => {
    if (downstreamOpen && downWs.readyState === downWs.OPEN) {
      downWs.send(data);
    }
  });

  clientWs.on('close', () => {
    console.log('[panel-terminal] client disconnected');
    try { downWs.close(); } catch (_) {}
  });

  clientWs.on('error', () => {});
});

// Safely send a text frame to a client that is still open.
function safeSend(ws, data) {
  if (ws.readyState === ws.OPEN) {
    try { ws.send(data); } catch (_) {}
  }
}

// Single upgrade router for all WebSocket paths. Using `noServer: true`
// WebSocketServers avoids the collision where the first server rejects a
// non-matching path with HTTP 400 before the correct server can handle it.
server.on('upgrade', (req, socket, head) => {
  const { pathname } = new URL(req.url, 'http://localhost');
  if (pathname === '/ssh-proxy') {
    wss.handleUpgrade(req, socket, head, (ws) => wss.emit('connection', ws, req));
  } else if (pathname === '/panel-terminal') {
    panelWss.handleUpgrade(req, socket, head, (ws) => panelWss.emit('connection', ws, req));
  } else {
    socket.destroy();
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Tianxuan app → http://localhost:${PORT}`);
  console.log(`Static: ${STATIC_DIR}`);
  console.log(`API proxy: → ${API_HOST}:${API_PORT}`);
  console.log(`SSH proxy: ws://localhost:${PORT}/ssh-proxy`);
  console.log(`Panel terminal: ws://localhost:${PORT}/panel-terminal → ${(API_TLS ? 'wss' : 'ws')}://${API_HOST}:${API_PORT}/api/v2/hosts/terminal`);
  if (API_KEY) console.log('Auto-login: enabled (API_KEY set)');
  else         console.log('Auto-login: disabled (use login page)');
  console.log('\nOpen http://localhost:' + PORT + ' in your browser.');
});
