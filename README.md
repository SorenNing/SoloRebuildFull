# SoloRebuild

基于 `com.oakstheawesome.solo_1.0.1-12_iphoneos-arm64e.deb` 的可维护源码重建工程。

> 这不是原作者源码的逐字恢复。`evidence/` 保存二进制元数据、类/方法清单和逆向证据；`Tweak/` 与 `Prefs/` 是可编译方向的重建源码。原始局部变量、注释和被优化掉的源结构无法从 dylib 恢复。

## 当前状态（2026-11-15）

`1.0.1-16` 的桌面、卡片和侧栏采用了未经用户同意的替代界面，不能作为原版恢复完成的版本。这三处仍未按原版恢复，121 个动作也尚未全部接通；原生小组件拖放、部分第三方联动仍未完成。

本次仅修设置页的数据源冲突：Root/Section 恢复继承 `PSListController`，使用原生 plist 加载及 `_specifiers` 分组；轮播、快捷、日历等自管表页面继承 `PSViewController`，避免原生表和自建表同时驱动。此实现依据原包设置类元数据及 Root `0x41c0`、Section `0x8164` 的调用链。Hero/预览等原版设置外观尚未完整恢复；未完成新包构建或真机验证，不能据语法通过认定闪退已实机修复。

## 当前已落地

- 64 个 Objective-C 自定义类的恢复接口清单（`Tweak/RecoveredInterfaces.h`）
- 主库 Unduo* 与增强库 SX*/SXL* 分开的源码边界
- rootful/rootless/roothide 打包变量
- arm64 + arm64e 构建目标（增强库不再被原包限制为 arm64e）
- 偏好读取、默认值、ReloadPrefs 通知和安全 Hook 辅助层
- 设置页 Root、主屏幕、轮播、快捷操作、日历、时钟的可修改控制器入口
- 原始 plist/图标资源快照和逆向 evidence

## 构建

需要在 macOS + Theos + iPhoneOS SDK 环境执行；当前 iSH 仅负责源码生成和静态检查。

```sh
export THEOS=/path/to/theos
make package
```

默认：

- `ARCHS = arm64 arm64e`
- `THEOS_PACKAGE_SCHEME = roothide`
- `TARGET = iphone:clang:latest:15.0`

如果目标是标准 rootless，可在有对应 Theos 环境时改为 `THEOS_PACKAGE_SCHEME = rootless`；不要在没有设备布局确认时混用 `Library/` 和 `var/jb/`。

## 目录

- `Tweak/`：主库、增强库、共享 Hook/偏好代码
- `Prefs/`：设置 bundle 源码
- `Resources/`：设置 plist、图标和包资源
- `Vendor/Headers/`：仅放必要的兼容声明
- `evidence/`：样本哈希、plist、类/方法 JSON
- `main-evidence/`、`enh-evidence/`：主库和增强库的逆向证据
- `tools/`：接口生成和静态验证脚本

## 重建原则

1. 私有类通过 `NSClassFromString`/`NSSelectorFromString` 弱绑定，避免 SDK 缺失时直接链接失败。
2. Hook 安装使用一次性门控，避免重复安装覆盖 orig 槽造成递归。
3. 未确认 ABI 的私有方法不伪造强类型实现；先保留 selector/地址证据，再按目标功能逐点恢复。
4. 原包保留在上传目录，重建工程不覆盖样本。
