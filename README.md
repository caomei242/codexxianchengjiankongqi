# codex线程监控器

一个本地 macOS 小工具，用来记录当前未收口的 Codex 开发线程、状态和下一步。它不是账号管理器，也不统计累计会话历史，只服务“切号或额度恢复后快速续上当前工作”。

## 功能

- 菜单栏常驻线程监控面板
- 主窗口按状态筛选当前开发线程
- 捕获、更新、收口当前线程
- 复制续接提示词
- 本地 JSON 持久化
- 同步当前线程 Markdown 到 Obsidian 线程手册目录

## 运行

```bash
swift test
./script/build_thread_radar.sh
```

打包产物会生成到：

```text
dist/codex线程监控器.app
```

如需安装到桌面：

```bash
./script/install_thread_radar_to_desktop.sh
```
