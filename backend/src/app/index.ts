import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import { secureHeaders } from 'hono/secure-headers';
import { EnvBindings, CSP_POLICY } from '@/app/config';

// 稍后我们会在这里引入拆分好的路由模块
import authRoutes from '@/features/auth/authRoutes';
import vaultRoutes from '@/features/vault/vaultRoutes';
import backupRoutes, { handleScheduledBackup } from '@/features/backup/backupRoutes';
import telegramRoutes from '@/features/telegram/telegramRoutes';
import toolsRoutes from '@/features/tools/toolsRoutes';
import healthRoutes from '@/features/health/healthRoutes';
import { runHealthCheck } from '@/shared/utils/health';

// 扩展 EnvBindings 以包含 ASSETS (Cloudflare Pages/Workers Assets)
type Bindings = EnvBindings & { ASSETS: { fetch: (req: Request) => Promise<Response> } };

// 初始化 Hono 应用，并绑定 Cloudflare 的环境变量类型
const app = new Hono<{ Bindings: Bindings }>();

// 1. 全局中间件
app.use('*', logger()); // 自动打印请求日志
app.use('/api/*', cors({
    origin: (origin) => origin, // 允许携带 Cookie 时，Origin 不能为 *，这里改为动态反射
    credentials: true, // 允许浏览器发送 Cookie
    allowHeaders: ['Content-Type', 'Authorization', 'X-CSRF-Token'], // 允许自定义 CSRF 头
    allowMethods: ['POST', 'GET', 'OPTIONS', 'PUT', 'DELETE'],
    maxAge: 86400,
}));

// 1.1 安全头配置 (CSP & Security Headers)
app.use('*', secureHeaders({
    contentSecurityPolicy: {
        defaultSrc: ["'self'"],
        scriptSrc: CSP_POLICY.SCRIPTS, // 使用 config.ts 中的配置
        styleSrc: ["'self'", "'unsafe-inline'"], // Element Plus 需要 unsafe-inline
        imgSrc: CSP_POLICY.IMAGES,     // 使用 config.ts 中的配置
        connectSrc: CSP_POLICY.CONNECT,// 使用 config.ts 中的配置
        fontSrc: ["'self'", "data:"],
        frameSrc: CSP_POLICY.FRAMES,   // 使用 config.ts 中的配置
        workerSrc: ["'self'", "blob:"], // 允许 Service Worker
        objectSrc: ["'none'"], // 禁止 Flash 等插件
    },
}));

// 2. 健康检查接口 (用于测试后端是否正常启动)
app.get('/api', (c) => c.text('🔐 2FA Secure Manager API is running!'));

// ============================================================================
// --- 新增：D1 数据库自动初始化拦截器 ---
// ============================================================================
let isDbInitialized = false; // 内存缓存，避免每次请求都查库带来延迟

app.use('/api/*', async (c, next) => {
    // 如果还没初始化过，且环境中绑定了 DB
    if (!isDbInitialized && c.env.DB) {
        try {
            // 尝试查询一下 vault 表，如果表不存在会抛出异常
            await c.env.DB.prepare("SELECT 1 FROM vault LIMIT 1").run();
            isDbInitialized = true; // 没报错说明表存在，标记为已初始化
        } catch (e: any) {
            // 捕捉到表不存在的错误，开始自动建表
            if (e.message && e.message.includes("no such table")) {
                console.log("[Auto-Init] 数据库未初始化，正在自动建表...");
                const initSQL = `
                    CREATE TABLE IF NOT EXISTS vault (
                        id TEXT PRIMARY KEY, service TEXT NOT NULL, account TEXT NOT NULL,
                        category TEXT, secret TEXT NOT NULL, digits INTEGER DEFAULT 6,
                        period INTEGER DEFAULT 30, algorithm TEXT DEFAULT 'SHA1',
                        sort_order INTEGER DEFAULT 0, created_at INTEGER,
                        created_by TEXT, updated_at INTEGER, updated_by TEXT
                    );
                    CREATE TABLE IF NOT EXISTS backup_providers (
                        id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT NOT NULL,
                        name TEXT NOT NULL, is_enabled BOOLEAN DEFAULT 1,
                        config TEXT NOT NULL, auto_backup BOOLEAN DEFAULT 0,
                        auto_backup_password TEXT, auto_backup_retain INTEGER DEFAULT 30,
                        last_backup_at INTEGER, last_backup_status TEXT,
                        created_at INTEGER, updated_at INTEGER
                    );
                    CREATE TABLE IF NOT EXISTS backup_telegram_history (
                        id INTEGER PRIMARY KEY AUTOINCREMENT, provider_id INTEGER NOT NULL,
                        filename TEXT NOT NULL, file_id TEXT NOT NULL,
                        message_id INTEGER NOT NULL, size INTEGER NOT NULL,
                        created_at INTEGER NOT NULL
                    );
                    DROP INDEX IF EXISTS idx_vault_service;
                    CREATE INDEX IF NOT EXISTS idx_vault_created_at ON vault(created_at DESC);
                    CREATE INDEX IF NOT EXISTS idx_backup_providers_type ON backup_providers(type);
                    CREATE INDEX IF NOT EXISTS idx_vault_service_created_at ON vault(service, created_at DESC);
                    CREATE INDEX IF NOT EXISTS idx_backup_telegram_history_provider_id ON backup_telegram_history(provider_id, created_at DESC);
                    DELETE FROM vault WHERE rowid NOT IN ( SELECT MIN(rowid) FROM vault GROUP BY lower(service), lower(account) );
                    CREATE UNIQUE INDEX IF NOT EXISTS vault_service_account_uq ON vault(lower(service), lower(account));
                `;

                // 将长 SQL 按分号切割成单条指令，利用 D1 的批量执行功能 (batch) 一次性打入
                const statements = initSQL.split(';').map(s => s.trim()).filter(s => s !== '');
                const batch = statements.map(s => c.env.DB.prepare(s));
                
                try {
                    await c.env.DB.batch(batch);
                    console.log("[Auto-Init] D1 数据库自动建表成功！");
                    isDbInitialized = true;
                } catch (batchError) {
                    console.error("[Auto-Init] 自动建表失败:", batchError);
                }
            } else {
                console.error("[Auto-Init] 数据库检查发生未知错误:", e);
            }
        }
    }
    await next(); // 放行给下一个中间件或路由
});
// ============================================================================


// 3. 全局安全安检拦截器 (Security Shield Middleware)
app.use('/api/*', async (c, next) => {
    // 豁免路由: 允许放行 /api/health 系列接口, 允许已登录用户强制登出
    const path = c.req.path;
    if (path.startsWith('/api/health') || path === '/api/oauth/logout') {
        await next();
        return;
    }

    // 执行安检
    const securityResult = runHealthCheck(c.env);
    if (!securityResult.passed) {
        // 发现安全环境不合格，阻断此请求
        return c.json({
            code: 403,
            success: false,
            message: 'health_check_failed',
            data: securityResult.issues
        }, 403);
    }

    await next();
});

// 4. 挂载子路由
app.route('/api/health', healthRoutes);
app.route('/api/oauth', authRoutes);
app.route('/api/vault', vaultRoutes); // 'accounts' is now 'vault'
app.route('/api/backups', backupRoutes);
app.route('/api/telegram', telegramRoutes);
app.route('/api/tools', toolsRoutes);

// 5. API 404 处理 (必须在静态资源 fallback 之前，确保 API 路径返回 JSON)
app.all('/api/*', (c) => {
    return c.json({ success: false, error: 'API Not Found' }, 404);
});

// 6. 静态资源托管 (让 Hono 接管所有非 API 请求，以便应用 CSP 安全头)
app.get('*', async (c) => {
    const res = await c.env.ASSETS.fetch(c.req.raw);
    // 关键修复：ASSETS 返回的 Response 可能是不可变的。创建副本以允许 Hono 中间件添加 CSP 头。
    return new Response(res.body, res);
});

// 7. 全局错误处理 (修复了原代码中序号重复的注释)
app.onError((err, c) => {
    const statusCode = (err as any).statusCode || (err as any).status || 500;

    // 特殊处理: WebDAV list 接口如果返回 404，说明目录不存在，视为无备份，返回空列表
    if (c.req.path.includes('/files') && (Number(statusCode) === 404 || err.message.includes('404'))) {
        return c.json({ success: true, backups: [] });
    }

    console.error(`[Server Error] ${err.message}`);
    // 标准化响应
    return c.json({
        code: statusCode,
        success: false,
        message: err.message || 'Internal Server Error',
        data: null
    }, statusCode as any);
});

export default app;
