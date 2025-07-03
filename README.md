# Dify-Sandbox

原始文档：https://github.com/langgenius/dify-sandbox/tree/main

## 如何操作

整个项目是基于 go 语言，首先 linux 服务器本地有 go 安装包。

## 0 初始化

```bash
bash ./install.sh
```

生成必要依赖。

### 1 构建sandbox binary：生成.env 和main

```bash
bash build/build_amd64.sh
```

### 2 构建镜像

```bash
cd dify-sandbox
bash ./docker/amd64/build_and_push.sh
```



## 核心变动说明

### 变动 1：在 Dockerfile 构建中增加数据处理库

为了增强代码沙箱的数据处理能力，特别是在处理 Excel (`.xls`, `.xlsx`) 等表格文件时，我们在 Dockerfile 构建过程中预装了以下核心 Python 第三方库：
- **pandas**: 用于数据分析和操作。
- **xlrd**: 用于读取旧版 Excel 文件 (`.xls`)。
- **openpyxl**: 用于读写新版 Excel 文件 (`.xlsx`)。

这些库的加入确保了用户代码可以直接利用这些工具进行复杂的数据分析任务，无需在沙箱内手动安装。

### 变动 2：新增 `utils` 目录用于环境测试

项目新增了 `/utils` 目录，其中包含一系列测试脚本（如 `test.sh` 和 `test.py`）。这些脚本的主要目的是：
- **验证环境**: 确保沙箱容器内的所有必要组件、依赖库和配置都已正确安装和设置。
- **简化调试**: 提供一种快速检测环境问题的方法。

在构建并运行 Docker 镜像后，可以进入容器并执行这些脚本来确认环境的完整性和可用性，具体操作请参考「测试 Docker 镜像」一节。

在第一次构建的时候加入这个文件夹，测试出来需要哪些依赖库，然后测试出来之后，构建真正的镜像的时候就不该把这个文件夹放到镜像里边了。

注释掉：

```bash
# COPY utils /utils
```



### 变动 3：放开系统调用安全限制

安装第三方库之后，依然有"operation not permitted" 显示。

参考：

 https://github.com/langgenius/dify-sandbox/blob/main/FAQ.md 

https://www.bilibili.com/video/BV1EtBTYHE1y/?spm_id_from=333.1387.homepage.video_card.click&vd_source=b9920ddb623470bc4ee0a1306728742e

由于dify代码沙箱自身的安全限制，用户在沙箱环境下的代码无法实现对系统文件的写入和读取操作。因此绕过dify的代码沙箱环境是很有必要的。需要：

```bash
cd sandbox/conf/config.yaml
```

将代码沙箱的读写权限打开：该配置文件通过allowed_syscalls参数来控制允许开放哪些系统调用命令，本仓库将0-499 的权限全部放开。



**重要提示：在 macOS 上进行开发和构建的注意事项**

⚠️：不建议，已弃用。

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
./build/build_linux_binaries_on_mac.sh
```

完成此步骤后，您就可以继续执行 Docker 构建脚本（例如 `bash ./docker/amd64/build_and_push.sh`）。

但是最好不要在 macOS 进行开发，直接 linux 上开发。



---

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

## 测试 Docker 镜像

当 Docker 镜像构建成功后，您可以通过以下步骤进行测试：

1.  **运行 Docker 容器并进入交互式 Shell：**
    这将启动一个容器，并允许您进入其内部的 Bash Shell，以便检查文件系统和环境。

    ```bash
    docker run --rm -it yiya-acr-registry.cn-hangzhou.cr.aliyuncs.com/open/dify-sandbox:0.2.12.202507031523 /bin/bash
    ```

2.  **在另一个终端窗口进入正在运行的容器：**
    如果您想在容器运行时从另一个终端进入其内部，可以使用 `docker exec` 命令。首先，您需要获取容器的 ID 或名称（可以通过 `docker ps` 命令查看）。

    ```bash
    docker exec -it <容器ID或名称> /bin/bash
    ```

### 4. 配置 `config.yaml`

构建并运行 Docker 镜像后，您需要执行以下步骤来获取一个必要的配置值并更新 `conf/config.yaml` 文件。

1.  **查看构建好的镜像：**
    ```bash
    docker images
    ```

2.  **使用您的镜像ID启动容器：**
    请将 `yiya-acr-registry.cn-hangzhou.cr.aliyuncs.com/open/dify-sandbox:0.2.12.202507031603` 替换为您在上一步中看到的镜像名称和标签。
    ```bash
    docker run --rm -it yiya-acr-registry.cn-hangzhou.cr.aliyuncs.com/open/dify-sandbox:0.2.12.202507031603 /bin/bash
    ```

3.  **进入正在运行的容器：**
    在另一个终端窗口中，使用 `docker ps` 找到您容器的名称（例如 `keen_zhukovsky`），然后执行以下命令。
    ```bash
    docker exec -it keen_zhukovsky /bin/bash
    ```

4.  **在容器内执行测试脚本：**
    进入容器后，运行 `utils` 目录下的测试脚本。
    ```bash
    cd /utils
    bash test.sh
    ```

5.  **更新配置文件：**
    上一步的脚本会输出一个数字。请将这个数字填入项目根目录下的 `conf/config.yaml` 文件中对应的字段。
