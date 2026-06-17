import SwiftUI

struct ArchiveView: View {

    @ObservedObject var canvasVM: CanvasViewModel
    @State private var days: [Day] = []
    @State private var selectedDay: Day?

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            Group {
                if days.isEmpty {
                    ContentUnavailableView(
                        "아직 기록이 없어요",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("하루치 캔버스가 완성되면 여기에 쌓여요")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(days, id: \.id) { day in
                                DayThumbnail(day: day)
                                    .onTapGesture { selectedDay = day }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("기록")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedDay) { day in
                DayDetailView(day: day, canvasVM: canvasVM)
            }
            .onAppear {
                days = canvasVM.fetchAllDays().filter { $0.isComplete && !$0.objects.isEmpty }
            }
        }
    }
}

// MARK: - Identifiable conformance for sheet

extension Day: Identifiable {}

// MARK: - Grid thumbnail

struct DayThumbnail: View {
    let day: Day

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.92))
                    .aspectRatio(3/4, contentMode: .fit)

                // Up to 6 objects scattered deterministically
                ForEach(Array(day.objects.prefix(6).enumerated()), id: \.offset) { idx, obj in
                    if let img = UIImage(data: obj.imageData) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 55)
                            .rotationEffect(.degrees(deterministicAngle(seed: idx)))
                            .offset(
                                x: deterministicOffset(seed: idx * 31, range: 28),
                                y: deterministicOffset(seed: idx * 17, range: 36)
                            )
                    }
                }
            }

            Text(displayDate(day.id))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            Text("\(day.objects.count)개")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)
        }
    }

    private func deterministicAngle(seed: Int) -> Double {
        let values: [Double] = [-18, 12, -8, 22, -15, 6, -20, 10]
        return values[seed % values.count]
    }

    private func deterministicOffset(seed: Int, range: CGFloat) -> CGFloat {
        let norm = Double((seed * 6271 + 3947) % 1000) / 1000.0  // 0..1
        return CGFloat(norm * 2 - 1) * range
    }

    private func displayDate(_ id: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        guard let date = fmt.date(from: id) else { return id }
        let out = DateFormatter()
        out.dateFormat = "M월 d일"
        out.locale = Locale(identifier: "ko_KR")
        return out.string(from: date)
    }
}

// MARK: - Day detail

struct DayDetailView: View {
    let day: Day
    let canvasVM: CanvasViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showShare = false
    @State private var scene: CanvasScene?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.97).ignoresSafeArea()
                if let scene {
                    SpriteView(scene: scene, options: [.allowsTransparency])
                        .ignoresSafeArea()
                }
            }
            .navigationTitle(dayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showShare = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .sheet(isPresented: $showShare) {
                        if let sc = scene {
                            ShareView(scene: sc)
                        }
                    }
                }
            }
        }
        .onAppear(perform: loadScene)
    }

    private var dayTitle: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        guard let date = fmt.date(from: day.id) else { return day.id }
        let out = DateFormatter()
        out.dateFormat = "M월 d일 (E)"
        out.locale = Locale(identifier: "ko_KR")
        return out.string(from: date)
    }

    private func loadScene() {
        guard scene == nil else { return }
        let size = UIScreen.main.bounds.size
        let newScene = CanvasScene(size: size)
        newScene.scaleMode = .resizeFill

        let snapshots = day.objects.compactMap { obj -> (id: UUID, image: UIImage, scale: Double, x: Double, y: Double, rotation: Double)? in
            guard let img = UIImage(data: obj.imageData) else { return nil }
            return (obj.id, img, obj.scale, obj.positionX, obj.positionY, obj.rotation)
        }
        newScene.loadStaticObjects(snapshots: snapshots)
        scene = newScene
    }
}
