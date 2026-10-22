# scripts

Windows 命令行实用脚本：切换 Claude 配置，以及通过 SSH 将本机代理共享给 Linux 服务器。

## 脚本一览

| 文件 | 功能 |
| --- | --- |
| `cc.cmd` | 将指定的 Claude 配置文件复制为当前生效的 `settings.json` |
| `pp.cmd` | `pp.ps1` 的命令行入口，通过 Windows PowerShell 执行并透传参数和退出码 |
| `pp.ps1` | 建立 SSH 反向端口转发，让远端会话通过本机 HTTP 代理访问网络 |

在脚本目录内可使用下面的 `.\` 形式运行；将该目录加入 `PATH` 后，也可以直接使用 `cc`、`pp`。

## cc：切换 Claude 配置

先在 `%USERPROFILE%\.claude` 目录中准备需要使用的配置文件：

| 命令 | 来源文件 | 写入文件 |
| --- | --- | --- |
| `.\cc.cmd dp` | `settings.dp.json` | `settings.json` |
| `.\cc.cmd hs` | `settings.hs.json` | `settings.json` |
| `.\cc.cmd or` | `settings.or.json` | `settings.json` |

`dp`、`hs`、`or` 是脚本支持的三个配置代号，具体内容由你自行维护。参数不区分大小写。

例如：

```powershell
.\cc.cmd dp
```

脚本会直接覆盖现有的 `settings.json`，不会合并配置或创建备份。来源文件不存在或复制失败时会报错退出；参数错误时显示用法。

## pp：将本机代理共享给 Linux 服务器

通过 SSH 反向转发，将服务器上的 `127.0.0.1:17897` 连接到 Windows 本机的代理端口，并在远端会话中设置代理环境变量。

### 使用条件

- Windows 已安装 PowerShell 5.1 或更高版本，以及可在命令行调用的 `ssh.exe`。
- 本机代理已启动，并支持 HTTP CONNECT，例如 Clash 的 HTTP/mixed 端口。
- 可以通过 SSH 登录目标 Linux 服务器，且 SSH 服务端允许远程端口转发。
- 远端具备 POSIX shell 和 `base64` 命令；交互会话的登录 shell 需支持相应的环境变量语法。

### 常用命令

自动探测本机代理端口，登录远端交互会话：

```powershell
.\pp.cmd user@server
```

指定本机代理端口、远端监听端口及 SSH 端口：

```powershell
.\pp.cmd user@server -LocalPort 7897 -RemotePort 17898 -SshPort 22
```

也可以直接调用 PowerShell 脚本，在设置代理后执行远端命令：

```powershell
.\pp.ps1 user@server -LocalPort 7897 -RemoteCommand 'curl -I https://example.com'
```

### 参数

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `Server` | 必填 | SSH 目标，例如 `user@server`，作为第一个位置参数传入 |
| `LocalPort` | `0` | 本机代理端口；`0` 表示自动探测 |
| `RemotePort` | `17897` | 服务器侧的回环监听端口，取值 `1–65535` |
| `SshPort` | `22` | SSH 服务端口，取值 `1–65535` |
| `RemoteCommand` | 未设置 | 设置代理后执行的远端命令；省略时打开交互式登录 shell |

自动探测依次检查 `7897`、`7890`、`10809`、`1080`、`8080`、`8888`，选择第一个可建立 TCP 连接的端口。探测只检查端口是否监听，不验证代理协议；选错端口时请显式指定 `-LocalPort`。

### 生效范围与排查

- 设置大小写两组 `http_proxy`、`https_proxy`、`all_proxy`，指向 `http://127.0.0.1:<RemotePort>`；`no_proxy` 包含 `localhost,127.0.0.1,::1`。
- 环境变量仅对本次远端会话及其子进程生效，程序仍需支持这些代理变量。其他 SSH 会话和系统服务需要自行配置。
- 保持 SSH 连接开启；退出会话或远端命令结束后，隧道随连接关闭。登录 shell 的启动配置若重设代理变量，可能影响最终设置。
- 远端监听地址为 `127.0.0.1`。如果端口已被占用，可用 `-RemotePort` 换一个端口；转发建立失败时 SSH 会退出。
- 提示找不到本机代理端口时，先启动代理，或通过 `-LocalPort` 指定实际监听端口。
