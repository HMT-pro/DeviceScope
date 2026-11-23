# DeviceScope

对标 DeviceKit 的 iOS 设备监控应用，但做的是实时监控而不只是静态参数表：

- **总览**：设备型号/标识符、芯片、CPU 核心、内存、系统版本与构建号、屏幕、开机时长；电量/CPU/内存/存储实时仪表；热状态、低电量模式
- **实时监控**：CPU 总占用与每核占用、内存占用，带最近 60 秒曲线图（Swift Charts），每秒刷新
- **电池**：通过 IOKit 读取 AppleSmartBattery 硬件数据——循环次数、设计容量、当前满充容量、电池健康 %、电压、温度（系统设置里看不到这么细）
- **网络**：当前连接类型、隧道接口检测（VPN/Loon 等）、自开机累计 Wi-Fi/蜂窝流量、各接口 IPv4/IPv6 地址
- **传感器**：姿态（俯仰/横滚/偏航）、加速度计、陀螺仪、磁力计、气压计实时读数

## 构建

GitHub Actions（macos-14）自动构建未签名 IPA：推送到 main 或手动触发 workflow 后，
在 Releases 里下载 `DeviceScope.ipa`，用 SideStore 签名安装即可（也可放进 LiveContainer 运行）。

本地构建需要 Xcode + XcodeGen：`xcodegen generate` 后打开 `DeviceScope.xcodeproj`。

最低系统：iOS 16。
