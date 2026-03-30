# SystemMonitor

macOS 菜单栏系统监控工具，实时显示 CPU 和内存占用情况。

## 功能特性

- **菜单栏显示**：顶部菜单栏实时显示 CPU 和内存使用率
- **点击详情**：点击弹出面板查看详细信息
- **Top 5 进程**：显示消耗内存最多的前5个程序
- **5秒自动关闭**：点击后面板5秒自动消失
- **开机自启**：支持设置开机自动启动
- **无 Dock 图标**：作为后台应用运行，不占用 Dock 空间

## 系统要求

- macOS 13.0 (Ventura) 或更高版本
- Apple Silicon 或 Intel 处理器

## 安装

### 方式一：直接安装

1. 下载 `SystemMonitor.app`
2. 复制到 `/Applications/` 目录
3. 双击运行即可

### 方式二：设置开机自启动

```bash
# 复制到应用程序目录
cp -r SystemMonitor.app /Applications/

# 创建启动项
mkdir -p ~/Library/LaunchAgents
cat > ~/Library/LaunchAgents/com.example.SystemMonitor.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.example.SystemMonitor</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/SystemMonitor.app/Contents/MacOS/SystemMonitor</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

# 加载启动项
launchctl load ~/Library/LaunchAgents/com.example.SystemMonitor.plist
```

## 使用

1. 运行应用后，顶部菜单栏会显示 `CPU: XX% | Mem: X.XGB`
2. 点击菜单栏项目查看详细信息（CPU 分项、内存使用、Top 5 进程）
3. 面板会在5秒后自动关闭
4. 点击其他区域也可手动关闭面板

## 卸载

```bash
# 停止应用
pkill SystemMonitor

# 移除启动项
launchctl unload ~/Library/LaunchAgents/com.example.SystemMonitor.plist
rm ~/Library/LaunchAgents/com.example.SystemMonitor.plist

# 删除应用
rm -rf /Applications/SystemMonitor.app
```

## 技术栈

- **语言**：Swift
- **UI 框架**：SwiftUI + AppKit
- **系统 API**：Mach host statistics, libproc
- **构建工具**：XcodeGen

## 项目结构

```
SystemMonitor/
├── project.yml              # XcodeGen 配置
├── SystemMonitor/
│   ├── main.swift          # 应用入口
│   ├── AppDelegate.swift   # 菜单栏和面板管理
│   ├── SystemMonitor.swift  # CPU/内存数据获取
│   ├── MenuBarView.swift   # 菜单栏 UI
│   ├── DetailView.swift    # 详情面板 UI
│   └── Info.plist          # 应用配置
└── Assets.xcassets/        # 资源文件
```

## 构建

```bash
# 生成 Xcode 项目
xcodegen generate

# 编译
xcodebuild -project SystemMonitor.xcodeproj -scheme SystemMonitor -configuration Debug build
```

## 隐私

本应用仅读取系统统计信息，不收集或上传任何用户数据。

## License

MIT License
