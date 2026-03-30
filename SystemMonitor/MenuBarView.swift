import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var viewModel: DetailViewModel

    var body: some View {
        VStack(spacing: 16) {
            // CPU Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "cpu")
                        .foregroundColor(.blue)
                    Text("CPU Usage")
                        .font(.headline)
                    Spacer()
                    Text("\(Int(viewModel.cpuUsage * 100))%")
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.semibold)
                }

                // CPU 进度条
                ProgressBarView(value: viewModel.cpuUsage, color: .blue)
                    .frame(height: 8)

                // 分项
                HStack(spacing: 16) {
                    Label("\(Int(viewModel.cpuUser * 100))%", systemImage: "person.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Label("\(Int(viewModel.cpuSystem * 100))%", systemImage: "gearshape.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Label("\(Int(viewModel.cpuIdle * 100))%", systemImage: "pause.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.top)

            Divider()

            // Memory Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "memorychip")
                        .foregroundColor(.green)
                    Text("Memory")
                        .font(.headline)
                    Spacer()
                    Text(formatMemory(viewModel.usedMemory))
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.semibold)
                }

                // 内存进度条
                let memoryFraction = Double(viewModel.usedMemory) / Double(viewModel.totalMemory)
                ProgressBarView(value: memoryFraction, color: .green)
                    .frame(height: 8)

                // 内存详情
                HStack {
                    Text("Used: \(formatMemory(viewModel.usedMemory))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Total: \(formatMemory(viewModel.totalMemory))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

            Divider()

            // Top Processes Section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "list.bullet")
                        .foregroundColor(.orange)
                    Text("Top Processes")
                        .font(.headline)
                    Spacer()
                    Text("Memory")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                ForEach(Array(viewModel.topProcesses.enumerated()), id: \.element.id) { index, process in
                    HStack {
                        Text("\(index + 1).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 16)

                        Text(process.name)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer()

                        Text(formatMemory(process.memoryUsage))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                if viewModel.topProcesses.isEmpty {
                    if viewModel.isLoading {
                        Text("Loading...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)

            Divider()

            // Buttons
            HStack {
                Button(action: {
                    viewModel.refresh()
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Label("Quit", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 280, height: 420)
    }

    private func formatMemory(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        return String(format: "%.1f GB", gb)
    }
}

// 进度条组件
struct ProgressBarView: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))

                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: geometry.size.width * CGFloat(min(max(value, 0), 1)))
            }
        }
    }
}

// ContentView - 使用环境中的 ViewModel
struct ContentView: View {
    @EnvironmentObject var viewModel: DetailViewModel

    var body: some View {
        MenuBarView()
    }
}

// 预览
#Preview {
    ContentView()
        .environmentObject(DetailViewModel())
}