#!/usr/bin/env node
// Standalone SSH WebSocket proxy for Tianxuan APK
// Run this on your 1Panel server with Node.js:
//   node ssh-proxy-server.mjs
//
// Environment:
//   PORT  — WebSocket server port (default: 25569)
//   HOST  — listen address      (default: 0.0.0.0)

import { WebSocketServer } from 'ws';
import { Client } from 'ssh2';

const PORT = parseInt(process.env.PORT || '25569', 10);
const HOST = process.env.HOST || '0.0.0.0';

const wss = new WebSocketServer({ port: PORT, host: HOST });

wss.on('connection', (ws) => {
  console.log('[ssh] WebSocket connected');
  let sshClient = null;
  let sshStream = null;
  let shellOpts = { cols: 80, rows: 24 };

  ws.on('message', (data) => {
    try {
      const msg = JSON.parse(data.toString());

      if (msg.type === 'connect') {
        sshClient = new Client();

        sshClient.on('ready', () => {
          console.log('[ssh] Connected to ' + msg.host);
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

        const opts = {
          host: msg.host,
          port: msg.port || 22,
          username: msg.username,
          readyTimeout: 10000,
          tryKeyboard: true,
        };
        if (msg.password) opts.password = msg.password;
        if (msg.privateKey) opts.privateKey = msg.privateKey;

        sshClient.on('keyboard-interactive', (name, instructions, instructionsLang, prompts, finish) => {
          finish([msg.password || '']);
        });

        sshClient.connect(opts);

      } else if (msg.type === 'exec') {
        if (!sshClient) {
          ws.send(JSON.stringify({ type: 'error', message: 'Not connected' }));
          return;
        }
        const cmd = msg.command;
        const timeout = (msg.timeout || 30) * 1000;
        console.log('[ssh] exec:', cmd.substring(0, 80));

        const timer = setTimeout(() => {
          ws.send(JSON.stringify({
            type: 'exec-result',
            id: msg.id,
            exitCode: -1,
            stdout: '',
            stderr: Buffer.from('Command timed out').toString('base64'),
          }));
        }, timeout);

        sshClient.exec(cmd, (err, stream) => {
          clearTimeout(timer);
          if (err) {
            ws.send(JSON.stringify({
              type: 'exec-result', id: msg.id,
              exitCode: -1,
              stdout: '',
              stderr: Buffer.from(err.message).toString('base64'),
            }));
            return;
          }
          const chunks = [], errChunks = [];
          stream.on('data', (d) => chunks.push(d));
          stream.stderr.on('data', (d) => errChunks.push(d));
          stream.on('close', (code) => {
            ws.send(JSON.stringify({
              type: 'exec-result',
              id: msg.id,
              exitCode: code ?? 0,
              stdout: Buffer.concat(chunks).toString('base64'),
              stderr: Buffer.concat(errChunks).toString('base64'),
            }));
          });
        });

      } else if (msg.type === 'stream-exec') {
        if (!sshClient) {
          ws.send(JSON.stringify({ type: 'error', message: 'Not connected' }));
          return;
        }
        const cmd = msg.command;
        console.log('[ssh] stream-exec:', cmd.substring(0, 80));

        sshClient.exec(cmd, (err, stream) => {
          if (err) {
            ws.send(JSON.stringify({
              type: 'stream-error', id: msg.id,
              message: err.message,
            }));
            return;
          }
          stream.on('data', (d) => {
            ws.send(JSON.stringify({
              type: 'stream-data', id: msg.id,
              data: d.toString('base64'),
            }));
          });
          stream.stderr.on('data', (d) => {
            ws.send(JSON.stringify({
              type: 'stream-data', id: msg.id,
              data: d.toString('base64'),
            }));
          });
          stream.on('close', () => {
            ws.send(JSON.stringify({
              type: 'stream-done', id: msg.id,
            }));
          });
        });

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

console.log(`Tianxuan SSH proxy → ws://${HOST}:${PORT}/`);
console.log(`Connect from app using ws://your-1panel-ip:${PORT}/`);
