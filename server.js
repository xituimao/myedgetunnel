import http from 'http';
import https from 'https';
import { WebSocketServer } from 'ws';
import { readFileSync } from 'fs';
import { Buffer } from 'buffer';

// 配置
const config = {
  PORT: process.env.PORT || 8080,
  ADMIN: (process.env.ADMIN || '').trim(),
  KEY: process.env.KEY || '勿动此默认密钥，有需求请自行通过添加变量KEY进行修改',
  HOST: process.env.HOST || '',
  UUID: process.env.UUID || '',
  PATH: process.env.PATH || '/',
  PROXYIP: process.env.PROXYIP || '',
  URL: process.env.URL || '',
  GO2SOCKS5: process.env.GO2SOCKS5 || '',
};

console.log('Loading environment configuration...');
console.log('PORT:', config.PORT);
console.log('ADMIN:', config.ADMIN ? '***' : '(not set)');

// 简单的 KV 存储模拟 (内存存储)
class SimpleKV {
  constructor() {
    this.store = new Map();
    console.log('SimpleKV storage initialized');
  }

  async get(key, type = 'text') {
    const value = this.store.get(key);
    if (!value) return null;
    if (type === 'json') {
      try {
        return JSON.parse(value);
      } catch {
        return null;
      }
    }
    return value;
  }

  async put(key, value, options = {}) {
    const stringValue = typeof value === 'object' ? JSON.stringify(value) : String(value);
    this.store.set(key, stringValue);
  }

  async delete(key) {
    return this.store.delete(key);
  }

  async list(options = {}) {
    const keys = Array.from(this.store.keys());
    return {
      keys: keys.map(name => ({ name })),
      list_complete: true,
      cursor: null
    };
  }
}

// 简单的 fetch polyfill 增强
const originalFetch = global.fetch;

// 创建环境对象
const env = {
  ADMIN: config.ADMIN,
  admin: config.ADMIN,
  PASSWORD: config.ADMIN,
  password: config.ADMIN,
  KEY: config.KEY,
  HOST: config.HOST,
  UUID: config.UUID,
  PATH: config.PATH,
  PROXYIP: config.PROXYIP,
  URL: config.URL,
  GO2SOCKS5: config.GO2SOCKS5,
  KV: new SimpleKV()
};

console.log('Environment object created');

// 动态加载 Worker 模块
let workerModule;

async function loadWorker() {
  try {
    const workerCode = readFileSync('./_worker.js', 'utf-8');

    // 创建一个修改版本的 worker 代码，添加必要的 polyfill
    const modifiedCode = `
// Cloudflare sockets polyfill
const connect = async (options) => {
  const net = await import('net');
  const { hostname, port } = options;

  return new Promise((resolve, reject) => {
    const socket = new net.Socket();

    const connectOptions = {
      host: hostname,
      port: port
    };

    socket.connect(connectOptions, () => {
      const readable = socket;
      const writable = socket;

      resolve({
        readable,
        writable,
        closed: new Promise((res) => {
          socket.on('close', res);
          socket.on('error', res);
        })
      });
    });

    socket.on('error', (err) => {
      console.error('Socket connection error:', err.message);
      reject(err);
    });
  });
};

// 导出 connect 函数供 worker 使用
export { connect };

${workerCode.replace('import { connect } from "cloudflare:sockets";', '// connect imported from polyfill')}
`;

    // 写入临时文件
    const tempFile = './_worker_adapted.js';
    const fs = await import('fs');
    fs.writeFileSync(tempFile, modifiedCode);

    // 导入修改后的 worker
    workerModule = await import('./_worker_adapted.js?v=' + Date.now());
    console.log('Worker module loaded successfully');
  } catch (error) {
    console.error('Failed to load worker:', error);
    throw error;
  }
}

// HTTP 服务器
const server = http.createServer(async (req, res) => {
  try {
    // 构造完整的 URL
    const protocol = req.headers['x-forwarded-proto'] || 'http';
    const host = req.headers['host'] || 'localhost';
    const url = `${protocol}://${host}${req.url}`;

    // 读取请求体
    const chunks = [];
    for await (const chunk of req) {
      chunks.push(chunk);
    }
    const bodyBuffer = chunks.length > 0 ? Buffer.concat(chunks) : null;

    // 构造 Request 对象
    const headers = new Headers();
    Object.entries(req.headers).forEach(([key, value]) => {
      if (Array.isArray(value)) {
        value.forEach(v => headers.append(key, v));
      } else if (value) {
        headers.set(key, value);
      }
    });

    const requestInit = {
      method: req.method,
      headers: headers
    };

    // 只在需要时添加 body
    if (bodyBuffer && req.method !== 'GET' && req.method !== 'HEAD') {
      requestInit.body = bodyBuffer;
    }

    const request = new Request(url, requestInit);

    // 添加 Cloudflare 特有的属性
    request.cf = {
      colo: 'SJC',
      country: 'US',
      city: 'San Francisco',
      postalCode: '94107',
      latitude: '37.76980',
      longitude: '-122.39330',
      timezone: 'America/Los_Angeles',
      clientTcpRtt: 25,
      httpProtocol: 'HTTP/1.1',
      tlsVersion: 'TLSv1.3',
      tlsCipher: 'AEAD-AES128-GCM-SHA256',
      asn: 13335,
      asOrganization: 'Cloudflare'
    };

    // 创建上下文
    const ctx = {
      waitUntil: (promise) => {
        promise.catch(err => console.error('Background task error:', err));
      },
      passThroughOnException: () => {
        console.log('passThroughOnException called');
      }
    };

    // 调用 worker 的 fetch 处理器
    const response = await workerModule.default.fetch(request, env, ctx);

    // 设置响应状态码
    res.statusCode = response.status;
    res.statusMessage = response.statusText;

    // 设置响应头
    response.headers.forEach((value, key) => {
      res.setHeader(key, value);
    });

    // 发送响应体
    if (response.body) {
      const reader = response.body.getReader();
      try {
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          res.write(value);
        }
      } finally {
        reader.releaseLock();
      }
    }

    res.end();
  } catch (error) {
    console.error('Request handling error:', error);
    if (!res.headersSent) {
      res.statusCode = 500;
      res.setHeader('Content-Type', 'text/plain');
    }
    if (!res.writableEnded) {
      res.end('Internal Server Error');
    }
  }
});

// WebSocket 服务器
const wss = new WebSocketServer({
  server,
  handleProtocols: (protocols, request) => {
    // 处理 WebSocket 子协议
    return protocols[0] || '';
  }
});

wss.on('connection', async (ws, req) => {
  console.log('WebSocket connection established');

  try {
    const protocol = req.headers['x-forwarded-proto'] || 'http';
    const host = req.headers['host'] || 'localhost';
    const url = `${protocol}://${host}${req.url}`;

    const headers = new Headers();
    Object.entries(req.headers).forEach(([key, value]) => {
      headers.set(key, value);
    });
    headers.set('Upgrade', 'websocket');

    const request = new Request(url, {
      method: 'GET',
      headers: headers
    });

    request.cf = {
      colo: 'SJC',
      country: 'US',
      city: 'San Francisco'
    };

    const ctx = {
      waitUntil: (promise) => {
        promise.catch(err => console.error('Background task error:', err));
      },
      passThroughOnException: () => {}
    };

    // WebSocket 需要特殊处理
    // 这里简化处理，实际的 WebSocket 升级由 ws 库处理

    ws.on('message', async (data) => {
      try {
        // 这里可以添加 WebSocket 消息处理逻辑
        console.log('WebSocket message received');
      } catch (error) {
        console.error('WebSocket message error:', error);
      }
    });

    ws.on('error', (error) => {
      console.error('WebSocket error:', error);
    });

    ws.on('close', () => {
      console.log('WebSocket connection closed');
    });

  } catch (error) {
    console.error('WebSocket connection error:', error);
    ws.close();
  }
});

// 启动服务器
async function startServer() {
  try {
    console.log('Starting EdgeTunnel server...');

    if (!config.ADMIN) {
      console.error('ERROR: ADMIN environment variable is not set. Please set a strong admin password before starting the server.');
      process.exit(1);
    }

    // 加载 worker
    await loadWorker();

    // 启动 HTTP 服务器
    server.listen(config.PORT, '0.0.0.0', () => {
      console.log('');
      console.log('╔════════════════════════════════════════════════════════════╗');
      console.log('║                                                            ║');
      console.log('║          EdgeTunnel Server Running                         ║');
      console.log('║                                                            ║');
      console.log(`║  Port:  ${String(config.PORT).padEnd(50)}║`);
      console.log(`║  Admin: ${String('***').padEnd(50)}║`);
      console.log('║                                                            ║');
      console.log(`║  访问地址: http://localhost:${config.PORT}${' '.repeat(31 - String(config.PORT).length)}║`);
      console.log(`║  管理后台: http://localhost:${config.PORT}/admin${' '.repeat(25 - String(config.PORT).length)}║`);
      console.log('║                                                            ║');
      console.log('╚════════════════════════════════════════════════════════════╝');
      console.log('');
    });

    server.on('error', (error) => {
      if (error.code === 'EADDRINUSE') {
        console.error(`Error: Port ${config.PORT} is already in use`);
        console.error('Please stop the other application or use a different port');
        process.exit(1);
      } else {
        console.error('Server error:', error);
        process.exit(1);
      }
    });

  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
}

// 优雅关闭
function gracefulShutdown(signal) {
  console.log(`\n${signal} received, closing server gracefully...`);

  server.close(() => {
    console.log('HTTP server closed');
    wss.close(() => {
      console.log('WebSocket server closed');
      console.log('Server shutdown complete');
      process.exit(0);
    });
  });

  // 强制退出超时
  setTimeout(() => {
    console.error('Forced shutdown due to timeout');
    process.exit(1);
  }, 10000);
}

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// 未捕获的异常处理
process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
  gracefulShutdown('uncaughtException');
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
});

// 启动
startServer();
