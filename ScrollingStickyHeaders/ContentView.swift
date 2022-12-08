import SwiftUI

struct FramePreference: PreferenceKey {
    static var defaultValue: [Namespace.ID: CGRect] = [:]

    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue()) { $1 }
    }
}

enum StickyRects: EnvironmentKey {
    static var defaultValue: [Namespace.ID: CGRect]? = nil
}

extension EnvironmentValues {
    var stickyRects: StickyRects.Value {
        get { self[StickyRects.self] }
        set { self[StickyRects.self] = newValue }
    }
}

struct Sticky: ViewModifier {
    @Environment(\.stickyRects) var stickyRects
    @State var frame: CGRect = .zero
    @Namespace private var id

    var isSticking: Bool {
        frame.minY < 0
    }

    var offset: CGFloat {
        guard isSticking else { return 0 }
        guard let stickyRects else {
            print("Warning: Using .sticky() without .useStickyHeaders()")
            return 0
        }
        var o = -frame.minY
        if let other = stickyRects.first(where: { (key, value) in
            key != id && value.minY > frame.minY && value.minY < frame.height

        }) {
            o -= frame.height - other.value.minY
        }
        return o
    }

    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .zIndex(isSticking ? .infinity : 0)
            .overlay(GeometryReader { proxy in
                let f = proxy.frame(in: .named("container"))
                Color.clear
                    .onAppear { frame = f }
                    .onChange(of: f) { frame = $0 }
                    .preference(key: FramePreference.self, value: [id: frame])
            })
    }
}

extension View {
    func sticky() -> some View {
        modifier(Sticky())
    }
}

struct UseStickyHeaders: ViewModifier {
    @State private var frames: StickyRects.Value = [:]

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(FramePreference.self, perform: {
                frames = $0
            })
            .environment(\.stickyRects, frames)
            .coordinateSpace(name: "container")
    }
}

extension View {
    func useStickyHeaders() -> some View {
        modifier(UseStickyHeaders())
    }
}

enum Tab: Hashable, CaseIterable, Identifiable {
    case photos
    case videos

    var id: Self { self }

    var image: Image {
        switch self {
        case .photos: return Image(systemName: "photo")
        case .videos: return Image(systemName: "video")
        }
    }
}

extension View {
    func measureTop(in coordinateSpace: CoordinateSpace, perform: @escaping (CGFloat) -> ()) -> some View {
        overlay(alignment: .top) {
            GeometryReader { proxy in
                let top = proxy.frame(in: coordinateSpace).minY
                Color.clear
                    .onAppear {
                        perform(top)
                    }.onChange(of: top, perform: perform)
            }
        }
    }
}

struct TabbedScrollView<Header: View, Picker: View, Contents: View, T: Hashable>: View {
    @State private var scrollOffset: [T: CGFloat] = [:]
    @State private var scrollTargetOffset: CGFloat = 0
    @State private var pickerIsSticking = false
    @State private var pickerTop: CGFloat = 0 // in terms of the scroll view contents

    var currentTab: T
    @ViewBuilder var header: Header
    @ViewBuilder var picker: Picker
    @ViewBuilder var contents: Contents

    var body: some View {
        ScrollViewReader { scrollViewProxy in
            ScrollView {
                VStack(spacing: 0) {
                    header
                    picker
                        .measureTop(in: .named("OutsideScrollView")) {
                            pickerIsSticking = $0 == 0
                        }
                        .sticky()
                        .measureTop(in: .named("ScrollView"), perform: {
                            pickerTop = $0
                        })
                    contents
                }
                .coordinateSpace(name: "ScrollView")
                .measureTop(in: .named("OutsideScrollView")) { top in
                    scrollOffset[currentTab] = top
                }
                .overlay(alignment: .top) {
                    Color.clear
                        .frame(height: 0)
                        .id("scrollTarget")
                        .offset(y: scrollTargetOffset)

                }
            }
            .onChange(of: currentTab, perform: { _ in
                restoreScrollPosition(proxy: scrollViewProxy)
            })
        }
        .coordinateSpace(name: "OutsideScrollView")
        .useStickyHeaders()
    }

    func restoreScrollPosition(proxy: ScrollViewProxy) {
        guard pickerIsSticking else { return }
        scrollTargetOffset = -(scrollOffset[currentTab] ?? 0)
        if scrollTargetOffset < pickerTop {
            scrollTargetOffset = pickerTop
        }
        proxy.scrollTo("scrollTarget", anchor: .top)
    }
}

struct ContentView: View {
    @State private var selectedTab = Tab.photos

    let items1 = (0...50).map { _ in Item() }
    let items2 = (0...50).map { _ in Item(saturation: 0.3) }


    var body: some View {
        TabbedScrollView(currentTab: selectedTab, header: {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
                .padding()
            Text("Hello, World!")
                .font(.title)

        }, picker: {
            Picker("Tab", selection: $selectedTab) {
                ForEach(Tab.allCases) { tab in
                    tab.image
                }
            }
            .pickerStyle(.segmented)
            .background(.background)
        }, contents: {
            contents
        })
    }

    @ViewBuilder var contents: some View {
        LazyVGrid(columns: [.init(.adaptive(minimum: 100))]) {
            ForEach(selectedTab == .photos ? items1 : items2) { item in
                item.color
                    .aspectRatio(1, contentMode: .fit)
            }
        }
    }
}



struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
