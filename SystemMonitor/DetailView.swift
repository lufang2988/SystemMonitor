import SwiftUI
import Combine

class DetailViewModel: ObservableObject {
    @Published var cpuUsage: Double = 0
    @Published var cpuUser: Double = 0
    @Published var cpuSystem: Double = 0
    @Published var cpuIdle: Double = 0
    @Published var usedMemory: UInt64 = 0
    @Published var totalMemory: UInt64 = 0
    @Published var topProcesses: [AppProcessInfo] = []
    @Published var isLoading: Bool = false

    private var timer: AnyCancellable?
    private var isRefreshing = false

    init() {
        refresh()
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let stats = SystemMonitor.getStats()
            let processes = SystemMonitor.getTopProcesses(limit: 5)

            DispatchQueue.main.async {
                self?.cpuUsage = stats.cpuUsage
                self?.cpuUser = stats.cpuUser
                self?.cpuSystem = stats.cpuSystem
                self?.cpuIdle = stats.cpuIdle
                self?.usedMemory = stats.usedMemory
                self?.totalMemory = stats.totalMemory
                self?.topProcesses = processes
                self?.isLoading = false
                self?.isRefreshing = false
            }
        }
    }

    func startAutoRefresh() {
        guard timer == nil else { return }
        timer = Timer.publish(every: 3.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refresh()
            }
    }

    func stopAutoRefresh() {
        timer?.cancel()
        timer = nil
    }

    deinit {
        timer?.cancel()
    }
}

struct DetailView: View {
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
                    VStack(alignment: .leading) {
                        Text("User")
                            .font(.caption2)
                        Text("\(Int(viewModel.cpuUser * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    VStack(alignment: .leading) {
                        Text("System")
                            .font(.caption2)
                        Text("\(Int(viewModel.cpuSystem * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    VStack(alignment: .leading) {
                        Text("Idle")
                            .font(.caption2)
                        Text("\(Int(viewModel.cpuIdle * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                .foregroundColor(.secondary)
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
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
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

#Preview {
    DetailView()
        .environmentObject(DetailViewModel())
}