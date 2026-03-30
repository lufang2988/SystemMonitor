import Foundation
import Darwin
import AppKit

struct SystemStats {
    var cpuUsage: Double
    var cpuUser: Double
    var cpuSystem: Double
    var cpuIdle: Double
    var usedMemory: UInt64
    var totalMemory: UInt64
}

struct AppProcessInfo: Identifiable {
    let id: Int32  // PID
    let name: String
    let cpuUsage: Double
    let memoryUsage: UInt64
}

class SystemMonitor {
    static func getStats() -> SystemStats {
        return SystemStats(
            cpuUsage: getCPUUsage(),
            cpuUser: getCPUUser(),
            cpuSystem: getCPUSystem(),
            cpuIdle: getCPUIdle(),
            usedMemory: getUsedMemory(),
            totalMemory: getTotalMemory()
        )
    }

    // MARK: - 获取消耗资源前5的进程
    static func getTopProcesses(limit: Int = 5) -> [AppProcessInfo] {
        var processes: [AppProcessInfo] = []

        // 使用同步方式执行 ps 命令
        let output = runCommand("/bin/ps", arguments: ["aux"])

        let lines = output.components(separatedBy: "\n")

        for line in lines.dropFirst() { // 跳过标题行
            // 用空格分割，但保留 COMMAND 部分（可能包含空格）
            let parts = line.split(separator: " ", maxSplits: 10, omittingEmptySubsequences: true)
            guard parts.count >= 4 else { continue }

            let user = String(parts[0])
            // 只获取当前用户的进程
            guard user == NSUserName() else { continue }

            // 解析 PID
            guard let pid = Int32(parts[1]) else { continue }

            // 解析 CPU 使用率
            guard let cpu = Double(parts[2]) else { continue }

            // 解析 MEM 使用率 (不直接使用)
            _ = Double(parts[3]) ?? 0

            // 解析 RSS (驻留内存, KB) - 需要找到正确的索引
            // ps aux 格式: USER PID %CPU %MEM VSZ RSS TT STAT STARTED TIME COMMAND
            guard let rssKB = Double(parts[5]) else { continue }
            let memoryBytes = UInt64(rssKB * 1024)

            // 跳过内存太小的进程 (小于5MB)
            guard memoryBytes > 5_000_000 else { continue }

            // COMMAND 是第11个部分开始 (index >= 10)
            // 前面是: USER PID %CPU %MEM VSZ RSS TT STAT STARTED TIME
            var command = ""
            if parts.count >= 11 {
                // 从第11个部分开始是 COMMAND，可能包含空格
                let commandParts = parts[10...]
                command = commandParts.joined(separator: " ")
            } else {
                command = String(parts.last ?? "")
            }

            // 提取 app 名称
            var processName = command

            // 如果包含路径，找最后一个 / 后的内容
            if let lastSlash = command.lastIndex(of: "/") {
                processName = String(command[command.index(after: lastSlash)...])
            }

            // 移除 .app 后缀
            if let appRange = processName.range(of: ".app") {
                processName = String(processName[..<appRange.lowerBound])
            }
            // 移除 --type=xxx 等参数
            if let dashDashIndex = processName.range(of: " --") {
                processName = String(processName[..<dashDashIndex.lowerBound])
            }

            processName = processName.trimmingCharacters(in: .whitespaces)
            if processName.isEmpty { continue }

            processes.append(AppProcessInfo(
                id: pid,
                name: processName,
                cpuUsage: cpu,
                memoryUsage: memoryBytes
            ))
        }

        // 按内存使用排序，取前5
        processes.sort { $0.memoryUsage > $1.memoryUsage }
        return Array(processes.prefix(limit))
    }

    // 同步执行命令 (带超时)
    private static func runCommand(_ path: String, arguments: [String] = [], timeout: TimeInterval = 5.0) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = arguments

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        // 设置超时
        let timeoutWorkItem = DispatchWorkItem {
            if task.isRunning {
                task.terminate()
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem)

        do {
            try task.run()
            task.waitUntilExit()
            timeoutWorkItem.cancel()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            timeoutWorkItem.cancel()
            print("Command error: \(error)")
            return ""
        }
    }

    // MARK: - CPU Usage
    static func getCPUUsage() -> Double {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        let err = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )

        guard err == KERN_SUCCESS, let info = cpuInfo else {
            return 0
        }

        var totalUsage: Double = 0

        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            let user = Double(info[offset + Int(CPU_STATE_USER)])
            let system = Double(info[offset + Int(CPU_STATE_SYSTEM)])
            let idle = Double(info[offset + Int(CPU_STATE_IDLE)])
            let nice = Double(info[offset + Int(CPU_STATE_NICE)])

            let total = user + system + idle + nice
            if total > 0 {
                totalUsage += (user + system + nice) / total
            }
        }

        let size = vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.size)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)

        return totalUsage / Double(numCPUs)
    }

    static func getCPUUser() -> Double {
        return getCPULoad(type: Int(CPU_STATE_USER))
    }

    static func getCPUSystem() -> Double {
        return getCPULoad(type: Int(CPU_STATE_SYSTEM))
    }

    static func getCPUIdle() -> Double {
        return getCPULoad(type: Int(CPU_STATE_IDLE))
    }

    private static func getCPULoad(type: Int) -> Double {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        let err = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )

        guard err == KERN_SUCCESS, let info = cpuInfo else {
            return 0
        }

        var totalUser: Double = 0
        var totalSystem: Double = 0
        var totalIdle: Double = 0
        var totalNice: Double = 0

        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            totalUser += Double(info[offset + Int(CPU_STATE_USER)])
            totalSystem += Double(info[offset + Int(CPU_STATE_SYSTEM)])
            totalIdle += Double(info[offset + Int(CPU_STATE_IDLE)])
            totalNice += Double(info[offset + Int(CPU_STATE_NICE)])
        }

        let size = vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.size)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)

        let total = totalUser + totalSystem + totalIdle + totalNice
        guard total > 0 else { return 0 }

        switch type {
        case Int(CPU_STATE_USER):
            return totalUser / total
        case Int(CPU_STATE_SYSTEM):
            return totalSystem / total
        case Int(CPU_STATE_IDLE):
            return totalIdle / total
        default:
            return 0
        }
    }

    // MARK: - Memory Usage
    static func getTotalMemory() -> UInt64 {
        return ProcessInfo.processInfo.physicalMemory
    }

    static func getUsedMemory() -> UInt64 {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return 0
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let usedMemory = UInt64(stats.active_count + stats.inactive_count + stats.wire_count) * pageSize

        return usedMemory
    }
}