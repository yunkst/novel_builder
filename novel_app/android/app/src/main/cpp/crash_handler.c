// Native crash signal handler —— Android SIGSEGV/SIGABRT 等崩溃捕获
//
// 设计目标：进程被 OS kill 之前，把崩溃信息（信号号、fault addr、tid、
// 时间戳、backtrace 地址）写到 filesDir/crash/crash_<tid>_<ts>.txt，
// 供下次启动时 Flutter 侧读取并引导用户提 GitHub issue。
//
// ★ async-signal-safe 约束（POSIX）：signal handler 里只能调用
//   open/write/close/syscall/clock_gettime 等明确列为 async-signal-safe
//   的函数。禁止 malloc/stdio/snprintf/JNI/锁。
//   - 字符串拼接：栈上 buffer + 手写 u64→hex/dec，不用 snprintf
//   - 栈回溯：_Unwind_Backtrace（Android Bionic 不含 execinfo.h/backtrace()）
//   - 独立信号栈 sigaltstack：防栈溢出导致的二次崩溃
//
// handler 末尾恢复默认信号处理并 raise，让进程按系统默认方式死亡
// （Android 仍会生成 tombstone，不受影响）。
#include <jni.h>
#include <signal.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <time.h>
#include <stdint.h>
#include <stddef.h>
#include <sys/syscall.h>
#include <unwind.h>

#define CRASH_DUMP_DIR_MAX 256
#define CRASH_BT_MAX 64
// 独立信号栈大小。Bionic 的 SIGSTKSZ 在不同版本可能是常量也可能是运行时
// 值，这里用固定 32KB 规避编译期不确定性（足够展开栈）。
#define CRASH_ALT_STACK_SIZE 32768

// install 时写一次，handler 内只读 —— 线程安全。
static char g_dump_dir[CRASH_DUMP_DIR_MAX];
static int g_dump_dir_len = 0;

// 独立信号栈（进程级，避免在溢出的栈上跑 handler）。
static char g_alt_stack[CRASH_ALT_STACK_SIZE];

// 各信号保留旧 handler，handler 末尾恢复。
static struct sigaction g_prev[32];

// ---- async-signal-safe 整数 → 字符串 ----

static int u64_to_hex(uint64_t v, char *buf) {
    char tmp[16];
    int n = 0;
    if (v == 0) {
        buf[0] = '0';
        return 1;
    }
    while (v > 0 && n < 16) {
        const int d = (int)(v & 0xf);
        tmp[n++] = (d < 10) ? (char)('0' + d) : (char)('a' + d - 10);
        v >>= 4;
    }
    for (int i = 0; i < n; i++) buf[i] = tmp[n - 1 - i];
    return n;
}

static int u64_to_dec(uint64_t v, char *buf) {
    char tmp[20];
    int n = 0;
    if (v == 0) {
        buf[0] = '0';
        return 1;
    }
    while (v > 0 && n < 20) {
        tmp[n++] = (char)('0' + (int)(v % 10));
        v /= 10;
    }
    for (int i = 0; i < n; i++) buf[i] = tmp[n - 1 - i];
    return n;
}

// ---- write 包装（循环写完，处理 EINTR / 部分写） ----

static void write_all(int fd, const char *s, int len) {
    int off = 0;
    while (off < len) {
        const ssize_t w = write(fd, s + off, (size_t)(len - off));
        if (w <= 0) break;
        off += (int)w;
    }
}

static void write_str(int fd, const char *s) {
    write_all(fd, s, (int)strlen(s));
}

// ---- _Unwind_Backtrace（libgcc/libunwind 提供，NDK 默认链接） ----

struct bt_state {
    void **addrs;
    int max;
    int count;
};

static _Unwind_Reason_Code unwind_cb(struct _Unwind_Context *ctx, void *arg) {
    struct bt_state *const st = (struct bt_state *)arg;
    if (st->count >= st->max) return _URC_END_OF_STACK;
    st->addrs[st->count++] = (void *)(uintptr_t)_Unwind_GetIP(ctx);
    return _URC_NO_REASON;
}

static const char *signame(int signo) {
    switch (signo) {
        case SIGSEGV: return "SIGSEGV";
        case SIGABRT: return "SIGABRT";
        case SIGBUS:  return "SIGBUS";
        case SIGILL:  return "SIGILL";
        case SIGFPE:  return "SIGFPE";
        case SIGTRAP: return "SIGTRAP";
        default:      return "UNKNOWN";
    }
}

// ---- 核心 signal handler ----
//
// 注意：此函数运行在崩溃线程 + 可能已损坏的栈上（由 sigaltstack 兜底），
// 全程 async-signal-safe。
static void crash_handler(int signo, siginfo_t *info, void *ucontext) {
    (void)ucontext;

    // dump_dir 未初始化时跳过写文件，直接 raise 让进程死亡。
    if (g_dump_dir_len > 0) {
        // 组装路径：<dump_dir>/crash_<tid>_<ts>.txt
        char path[CRASH_DUMP_DIR_MAX + 64];
        int off = 0;
        memcpy(path, g_dump_dir, (size_t)g_dump_dir_len);
        off = g_dump_dir_len;
        path[off++] = '/';

        const char *prefix = "crash_";
        memcpy(path + off, prefix, 6);
        off += 6;

        const long tid = (long)syscall(SYS_gettid);
        off += u64_to_dec((uint64_t)tid, path + off);
        path[off++] = '_';

        struct timespec ts;
        clock_gettime(CLOCK_REALTIME, &ts);
        off += u64_to_dec((uint64_t)ts.tv_sec, path + off);

        memcpy(path + off, ".txt", 4);
        off += 4;
        path[off] = '\0';

        const int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0600);
        if (fd >= 0) {
            char buf[64];
            int len;

            write_str(fd, "=== NOVEL_CRASH_DUMP v1 ===\n");

            // signal:11 (SIGSEGV)
            write_str(fd, "signal:");
            len = u64_to_dec((uint64_t)signo, buf);
            write_all(fd, buf, len);
            write_str(fd, " (");
            write_str(fd, signame(signo));
            write_str(fd, ")\n");

            // fault_addr:0x...
            write_str(fd, "fault_addr:0x");
            len = u64_to_hex((uint64_t)(uintptr_t)(info ? info->si_addr : NULL), buf);
            write_all(fd, buf, len);
            write_str(fd, "\n");

            // tid:<gettid>
            write_str(fd, "tid:");
            len = u64_to_dec((uint64_t)tid, buf);
            write_all(fd, buf, len);
            write_str(fd, "\n");

            // timestamp:<epoch seconds>
            write_str(fd, "timestamp:");
            len = u64_to_dec((uint64_t)ts.tv_sec, buf);
            write_all(fd, buf, len);
            write_str(fd, "\n");

            // backtrace（PC 地址数组）
            write_str(fd, "backtrace:\n");
            void *addrs[CRASH_BT_MAX];
            struct bt_state st = { .addrs = addrs, .max = CRASH_BT_MAX, .count = 0 };
            _Unwind_Backtrace(unwind_cb, &st);

            for (int i = 0; i < st.count; i++) {
                write_str(fd, "  #");
                len = u64_to_dec((uint64_t)i, buf);
                write_all(fd, buf, len);
                write_str(fd, " pc 0x");
                len = u64_to_hex((uint64_t)(uintptr_t)addrs[i], buf);
                write_all(fd, buf, len);
                write_str(fd, "\n");
            }

            write_str(fd, "=== END ===\n");
            close(fd);
        }
    }

    // 恢复该信号的默认 handler，re-raise 让进程按系统默认方式死亡
    // （Android 仍会生成 tombstone；本 handler 不改变 OS 的崩溃善后行为）。
    if (signo > 0 && signo < 32) {
        sigaction(signo, &g_prev[signo], NULL);
    }
    raise(signo);
}

static void install_signal(int signo) {
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = crash_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_SIGINFO | SA_ONSTACK;
    sigaction(signo, &sa, &g_prev[signo]);
}

// ---- JNI 入口：Kotlin CrashReporter.nativeInstall(dumpDir) 调用 ----
//
// 包名 com.example.novel_app 中的下划线按 JNI 规则编码为 _1。
JNIEXPORT void JNICALL
Java_com_example_novel_1app_CrashReporter_nativeInstall(
    JNIEnv *env, jclass clazz, jstring dumpDir) {
    (void)clazz;
    if (dumpDir == NULL) return;

    const char *str = (*env)->GetStringUTFChars(env, dumpDir, NULL);
    if (str == NULL) return;
    size_t len = strlen(str);
    if (len >= CRASH_DUMP_DIR_MAX) len = CRASH_DUMP_DIR_MAX - 1;
    memcpy(g_dump_dir, str, len);
    g_dump_dir[len] = '\0';
    g_dump_dir_len = (int)len;
    (*env)->ReleaseStringUTFChars(env, dumpDir, str);

    // 独立信号栈：handler 跑在它上面，避免栈溢出导致 handler 二次崩溃。
    stack_t ss;
    ss.ss_sp = g_alt_stack;
    ss.ss_size = CRASH_ALT_STACK_SIZE;
    ss.ss_flags = 0;
    sigaltstack(&ss, NULL);

    install_signal(SIGSEGV);
    install_signal(SIGABRT);
    install_signal(SIGBUS);
    install_signal(SIGILL);
    install_signal(SIGFPE);
    install_signal(SIGTRAP);
}
