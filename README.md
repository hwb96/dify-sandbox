# Dify-Sandbox

**重要提示：在 macOS 上进行开发和构建的注意事项**

由于 `dify-sandbox` 项目的 Go 核心部分（特别是涉及到 `libseccomp` 和系统调用的部分）是为 Linux 环境设计的，因此在 macOS 上直接编译会遇到兼容性问题。为了解决这个问题，我们引入了一个辅助脚本 `build_linux_binaries_on_mac.sh`。

**`build_linux_binaries_on_mac.sh` 的作用：**

该脚本会在一个临时的 Docker 容器内部构建 Linux 环境所需的 `main` 和 `env` 二进制文件。它会：
1.  动态创建一个临时的 Dockerfile，其中包含 Go 编译环境和所有必要的 Linux 依赖。
2.  在 Docker 容器中执行编译过程，确保所有 Linux 特有的系统调用和库都能被正确处理。
3.  将编译好的 `main` 和 `env` 可执行文件从容器中复制到您的本地项目目录。
4.  自动清理所有临时创建的 Docker 资源。

**何时使用：**

当您在 macOS 上进行开发，并且需要生成 `main` 和 `env` 这两个 Linux 二进制文件（例如，为了后续构建 Docker 镜像）时，请首先运行此脚本。

```bash
./build_linux_binaries_on_mac.sh
```

完成此步骤后，您就可以继续执行 Docker 构建脚本（例如 `bash ./docker/amd64/build_and_push.sh`）。

---

## 简介
## 简介
Dify-Sandbox 提供了一种在安全环境中运行不受信任代码的简单方法。它旨在用于多租户环境，其中多个用户可以提交代码以供执行。代码在沙盒环境中执行，这限制了代码可以访问的资源和系统调用。

## 使用
### 要求
DifySandbox 目前仅支持 Linux，因为它专为 Docker 容器设计。它需要以下依赖项：
- libseccomp
- pkg-config
- gcc
- golang 1.20.6

### 步骤
1. 使用 `git clone https://github.com/langgenius/dify-sandbox` 克隆仓库并导航到项目目录。
2. 运行 `./install.sh` 安装必要的依赖项。
3. 运行 `./build/build_[amd64|arm64].sh` 构建沙盒二进制文件。
4. 运行 `./main` 启动服务器。

如果您想调试服务器，首先使用构建脚本构建沙盒库二进制文件，然后根据您的 IDE 进行调试。


## 常见问题

请参阅 [常见问题文档](FAQ.md)


## 工作流程
![workflow](workflow.png)

## 构建问题排查

本节介绍构建过程中遇到的常见问题。

### 1. `package cmd/lib/python/main.go is not in std` 错误

**问题：**
运行 `go build` 或构建脚本时，您可能会遇到类似以下错误：
```
package cmd/lib/python/main.go is not in std (/usr/local/go/src/cmd/lib/python/main.go)
```
这表明 Go 编译器正在标准 Go 库路径而不是您的项目目录中查找包。

**原因：**
这通常发生在从子目录（例如 `build/`）而不是 `go.mod` 文件所在的项目根目录执行 `go build` 命令时。Go 期望相对于模块根目录查找源文件。

**解决方案：**
始终从项目根目录执行构建脚本。

```bash
# 如果您在 'build' 目录中
cd ..
# 然后运行构建脚本
bash ./build/build_amd64.sh
```
或者，如果您在任何其他目录中，请首先导航到项目根目录：
```bash
cd /path/to/your/dify-sandbox/project/root
bash ./build/build_amd64.sh
```

### 2. `Package libseccomp was not found in the pkg-config search path.` 错误

**问题：**
在构建过程中，您可能会看到与 `libseccomp` 相关的错误：
```
# github.com/seccomp/libseccomp-golang
# [pkg-config --cflags  -- libseccomp]
Package libseccomp was not found in the pkg-config search path.
Perhaps you should add the directory containing `libseccomp.pc'
to the PKG_CONFIG_PATH environment variable
Package 'libseccomp', required by 'virtual:world', not found
```
此错误表示您的系统缺少 `libseccomp` 库的开发文件。

**原因：**
`dify-sandbox` 项目，特别是 `github.com/seccomp/libseccomp-golang` 模块，需要 `libseccomp` 库进行编译。`pkg-config` 用于定位必要的库配置，但它找不到。

**解决方案：**
安装适用于您的 Linux 发行版的 `libseccomp` 开发包。

*   **对于基于 Debian/Ubuntu 的系统（例如 Ubuntu、Debian）：**
    ```bash
    sudo apt-get update
    sudo apt-get install libseccomp-dev
    ```
*   **对于基于 Red Hat 的系统（例如 CentOS、Fedora、RHEL）：**
    ```bash
    # 对于 CentOS/RHEL 7 或更早版本
    sudo yum install libseccomp-devel
    # 对于 CentOS/RHEL 8+ 或 Fedora
    sudo dnf install libseccomp-devel
    ```
安装后，从项目根目录重新运行构建脚本。

### 3. `pattern python.so: no matching files found` 错误

**问题：**
您可能会遇到类似以下错误：
```
internal/core/runner/python/setup.go:20:12: pattern python.so: no matching files found
```

**原因：**
此错误通常是 `libseccomp` 缺失错误（问题 2）的*结果*。如果找不到 `libseccomp`，则无法成功编译和生成 `python.so` 文件。构建过程或期望 `python.so` 存在的代码的后续部分将因此失败。

**解决方案：**
一旦您成功安装了 `libseccomp` 开发包并在构建过程中生成了 `python.so` 文件，此错误将自动解决。