// Permissive SwiftUI / Charts / MapKit / AuthenticationServices / PhotosUI
// stand-ins so FlexUp's views type-check on Linux. Signatures mirror
// Apple's for what the app uses; most modifiers return `AnyV`, so app-side
// mistakes (wrong names, types, arguments) still surface while SwiftUI's
// generic internals don't matter. See tools/ios-typecheck/README.md.
import Foundation

// MARK: - Core

@MainActor @preconcurrency
public protocol View {
    associatedtype Body: View
    @ViewBuilder var body: Body { get }
}
extension Never: View { public var body: Never { return fatalError() } }
public struct AnyV: View { public init() {}; public var body: Never { return fatalError() } }
public struct AnyView: View { public init<V: View>(_ v: V) {}; public var body: Never { return fatalError() } }
public struct EmptyView: View { public init() {}; public var body: Never { return fatalError() } }

@resultBuilder public enum ViewBuilder {
    public static func buildExpression<C: View>(_ c: C) -> AnyV { AnyV() }
    public static func buildBlock() -> AnyV { AnyV() }
    public static func buildBlock(_ c: AnyV...) -> AnyV { AnyV() }
    public static func buildOptional(_ c: AnyV?) -> AnyV { AnyV() }
    public static func buildEither(first: AnyV) -> AnyV { AnyV() }
    public static func buildEither(second: AnyV) -> AnyV { AnyV() }
    public static func buildLimitedAvailability(_ c: AnyV) -> AnyV { AnyV() }
}

public protocol ViewModifier {
    associatedtype Body: View
    typealias Content = AnyV
    @MainActor func body(content: Content) -> Body
}

public protocol DynamicProperty {}

@propertyWrapper public struct State<Value>: DynamicProperty {
    var v: Value
    public init(wrappedValue: Value) { v = wrappedValue }
    public init(initialValue: Value) { v = initialValue }
    public var wrappedValue: Value { get { v } nonmutating set {} }
    public var projectedValue: Binding<Value> { Binding(get: { self.v }, set: { _ in }) }
}
extension State where Value: ExpressibleByNilLiteral { public init() { v = nil } }

@propertyWrapper @dynamicMemberLookup public struct Binding<Value> {
    let g: () -> Value
    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) { g = get }
    public init(projectedValue: Binding<Value>) { g = projectedValue.g }
    public var wrappedValue: Value { get { g() } nonmutating set {} }
    public var projectedValue: Binding<Value> { self }
    public static func constant(_ v: Value) -> Binding<Value> { Binding(get: { v }, set: { _ in }) }
    public subscript<T>(dynamicMember kp: WritableKeyPath<Value, T>) -> Binding<T> {
        Binding<T>(get: { self.g()[keyPath: kp] }, set: { _ in })
    }
}
extension Binding: Sequence where Value: MutableCollection & RandomAccessCollection, Value.Index == Int {
    public typealias Element = Binding<Value.Element>
    public typealias Iterator = IndexingIterator<Binding<Value>>
    public func makeIterator() -> IndexingIterator<Binding<Value>> { IndexingIterator(_elements: self) }
}
extension Binding: Collection, BidirectionalCollection, RandomAccessCollection where Value: MutableCollection & RandomAccessCollection, Value.Index == Int {
    public typealias Index = Int
    public typealias Indices = Range<Int>
    public var startIndex: Int { 0 }
    public var endIndex: Int { g().count }
    public var indices: Range<Int> { 0..<endIndex }
    public func index(after i: Int) -> Int { i + 1 }
    public func index(before i: Int) -> Int { i - 1 }
    public subscript(i: Int) -> Binding<Value.Element> { Binding<Value.Element>(get: { self.g()[i] }, set: { _ in }) }
}
extension Binding: Identifiable where Value: Identifiable { public var id: Value.ID { g().id } }

@propertyWrapper public struct Environment<Value>: DynamicProperty {
    public init(_ kp: KeyPath<EnvironmentValues, Value>) {}
    public init(_ t: Value.Type) where Value: AnyObject {}
    public var wrappedValue: Value { fatalError() }
}
@propertyWrapper public struct Bindable<Value: AnyObject>: DynamicProperty {
    public init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
    public var wrappedValue: Value
    public var projectedValue: Bindable<Value> { self }
}
@propertyWrapper public struct FocusState<Value: Hashable>: DynamicProperty {
    public struct Binding {}
    public init() where Value == Bool {}
    public var wrappedValue: Value { get { fatalError() } nonmutating set {} }
    public var projectedValue: FocusState<Value>.Binding { .init() }
}
@propertyWrapper public struct AppStorage<Value>: DynamicProperty {
    var v: Value
    public init(wrappedValue: Value, _ key: String) { v = wrappedValue }
    public var wrappedValue: Value { get { v } nonmutating set {} }
    public var projectedValue: Binding<Value> { Binding(get: { self.v }, set: { _ in }) }
}

public struct EnvironmentValues {
    public var dismiss: DismissAction { .init() }
    public var openURL: OpenURLAction { .init() }
    public var colorScheme: ColorScheme { .light }
    public var scenePhase: ScenePhase { .active }
    public var accessibilityReduceMotion: Bool { false }
    public var dynamicTypeSize: DynamicTypeSize { .large }
}
public struct DismissAction { public func callAsFunction() {} }
public struct OpenURLAction { public func callAsFunction(_ url: URL) {} }
public enum ColorScheme { case light, dark }
public enum ScenePhase: Equatable { case active, inactive, background }
public enum DynamicTypeSize: Comparable { case small, medium, large, xLarge, xxLarge, xxxLarge, accessibility1 }

// MARK: - App

public protocol App { associatedtype Body: Scene; @SceneBuilder var body: Body { get }; init() }
public protocol Scene {}
@resultBuilder public enum SceneBuilder { public static func buildBlock<S: Scene>(_ s: S) -> S { s } }
public struct WindowGroup: Scene { public init<C: View>(@ViewBuilder content: () -> C) {} }
extension App { public static func main() {} }

// MARK: - Layout

public enum HorizontalAlignment { case leading, center, trailing }
public enum VerticalAlignment { case top, center, bottom, firstTextBaseline, lastTextBaseline }
public struct Alignment {
    public static let leading = Alignment(), trailing = Alignment(), center = Alignment(), top = Alignment(), bottom = Alignment(),
        topLeading = Alignment(), topTrailing = Alignment(), bottomLeading = Alignment(), bottomTrailing = Alignment()
}
public enum Edge {
    case top, bottom, leading, trailing
    public struct Set: OptionSet {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let top = Set(rawValue: 1), bottom = Set(rawValue: 2), leading = Set(rawValue: 4), trailing = Set(rawValue: 8)
        public static let all: Set = [.top, .bottom, .leading, .trailing], horizontal: Set = [.leading, .trailing], vertical: Set = [.top, .bottom]
    }
}
public enum Axis {
    case horizontal, vertical
    public struct Set: OptionSet {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let horizontal = Set(rawValue: 1), vertical = Set(rawValue: 2)
    }
}
public struct UnitPoint {
    public init(x: CGFloat, y: CGFloat) {}
    public init() {}
    public static let top = UnitPoint(), bottom = UnitPoint(), leading = UnitPoint(), trailing = UnitPoint(), center = UnitPoint(),
        topLeading = UnitPoint(), topTrailing = UnitPoint(), bottomLeading = UnitPoint(), bottomTrailing = UnitPoint()
}

public struct VStack: View { public init<C: View>(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> C) {}; public var body: Never { return fatalError() } }
public struct HStack: View { public init<C: View>(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> C) {}; public var body: Never { return fatalError() } }
public struct ZStack: View { public init<C: View>(alignment: Alignment = .center, @ViewBuilder content: () -> C) {}; public var body: Never { return fatalError() } }
public struct LazyVStack: View { public init<C: View>(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> C) {}; public var body: Never { return fatalError() } }
public struct LazyHStack: View { public init<C: View>(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> C) {}; public var body: Never { return fatalError() } }
public struct GridItem {
    public enum Size { case flexible(minimum: CGFloat = 10, maximum: CGFloat = .infinity), fixed(CGFloat), adaptive(minimum: CGFloat, maximum: CGFloat = .infinity) }
    public init(_ size: Size = .flexible(), spacing: CGFloat? = nil, alignment: Alignment? = nil) {}
}
public struct LazyVGrid: View { public init<C: View>(columns: [GridItem], alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> C) {}; public var body: Never { return fatalError() } }
public struct ScrollView: View { public init<C: View>(_ axes: Axis.Set = .vertical, showsIndicators: Bool = true, @ViewBuilder content: () -> C) {}; public var body: Never { return fatalError() } }
public struct ScrollViewProxy { public func scrollTo<ID: Hashable>(_ id: ID, anchor: UnitPoint? = nil) {} }
public struct ScrollViewReader: View { public init<C: View>(@ViewBuilder content: (ScrollViewProxy) -> C) {}; public var body: Never { return fatalError() } }
public struct Group: View { public init<C: View>(@ViewBuilder content: () -> C) {}; public var body: Never { return fatalError() } }
public struct GeometryProxy { public var size: CGSize { .zero } }
public struct GeometryReader: View { public init<C: View>(@ViewBuilder content: @escaping (GeometryProxy) -> C) {}; public var body: Never { return fatalError() } }
public struct Spacer: View { public init(minLength: CGFloat? = nil) {}; public var body: Never { return fatalError() } }
public struct Divider: View { public init() {}; public var body: Never { return fatalError() } }

public struct ForEach<Data, ID: Hashable>: View { public var body: Never { return fatalError() } }
extension ForEach where Data: RandomAccessCollection, Data.Element: Identifiable, ID == Data.Element.ID {
    public init<C: View>(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> C) {}
}
extension ForEach where Data: RandomAccessCollection {
    public init<C: View>(_ data: Data, id: KeyPath<Data.Element, ID>, @ViewBuilder content: @escaping (Data.Element) -> C) {}
}
extension ForEach where Data == Range<Int>, ID == Int {
    public init<C: View>(_ data: Range<Int>, @ViewBuilder content: @escaping (Int) -> C) {}
}

public struct TimelineContext { public var date: Date { Date() } }
public struct TimelineSchedulePeriodic {}
extension TimelineSchedulePeriodic {
    public static func periodic(from: Date, by: TimeInterval) -> TimelineSchedulePeriodic { .init() }
}
public struct TimelineView: View {
    public init<C: View>(_ schedule: TimelineSchedulePeriodic, @ViewBuilder content: @escaping (TimelineContext) -> C) {}
    public var body: Never { return fatalError() }
}

// MARK: - Text, images, controls

public struct Text: View {
    public init(_ s: String) {}
    public init<S: StringProtocol>(_ s: S) {}
    public init(verbatim: String) {}
    public init(_ d: Date, style: DateStyle) {}
    public struct DateStyle { public static let timer = DateStyle(), relative = DateStyle(), time = DateStyle(), date = DateStyle() }
    public var body: Never { return fatalError() }
    public static func + (l: Text, r: Text) -> Text { l }
    public func bold() -> Text { self }
    public func fontWeight(_ w: Font.Weight?) -> Text { self }
    public func foregroundColor(_ c: Color?) -> Text { self }
    public func font(_ f: Font?) -> Text { self }
    public func monospacedDigit() -> Text { self }
    public func strikethrough(_ on: Bool = true, color: Color? = nil) -> Text { self }
}
public struct Image: View {
    public init(systemName: String) {}
    public init(_ name: String) {}
    public init(uiImage: UIImage) {}
    public var body: Never { return fatalError() }
    public func resizable() -> Image { self }
    public func renderingMode(_ m: TemplateRenderingMode) -> Image { self }
    public enum TemplateRenderingMode { case template, original }
}
public struct Label: View {
    public init<S: StringProtocol>(_ title: S, systemImage: String) {}
    public init<T: View, I: View>(@ViewBuilder title: () -> T, @ViewBuilder icon: () -> I) {}
    public var body: Never { return fatalError() }
}
public struct ButtonRole: Equatable { public static let destructive = ButtonRole(), cancel = ButtonRole() }
public struct Button: View {
    public init<L: View>(action: @escaping () -> Void, @ViewBuilder label: () -> L) {}
    public init<L: View>(role: ButtonRole?, action: @escaping () -> Void, @ViewBuilder label: () -> L) {}
    public init<S: StringProtocol>(_ title: S, action: @escaping () -> Void) {}
    public init<S: StringProtocol>(_ title: S, role: ButtonRole?, action: @escaping () -> Void) {}
    public init<S: StringProtocol>(_ title: S, systemImage: String, action: @escaping () -> Void) {}
    public init<S: StringProtocol>(_ title: S, systemImage: String, role: ButtonRole?, action: @escaping () -> Void) {}
    public var body: Never { return fatalError() }
}
public struct Menu: View {
    public init<C: View, L: View>(@ViewBuilder content: () -> C, @ViewBuilder label: () -> L) {}
    public init<S: StringProtocol, C: View>(_ title: S, @ViewBuilder content: () -> C) {}
    public var body: Never { return fatalError() }
}
public struct Picker: View {
    public init<S: StringProtocol, V: Hashable, C: View>(_ title: S, selection: Binding<V>, @ViewBuilder content: () -> C) {}
    public var body: Never { return fatalError() }
}
public struct Toggle: View {
    public init<L: View>(isOn: Binding<Bool>, @ViewBuilder label: () -> L) {}
    public init<S: StringProtocol>(_ title: S, isOn: Binding<Bool>) {}
    public var body: Never { return fatalError() }
}
public struct TextField: View {
    public init<S: StringProtocol>(_ title: S, text: Binding<String>) {}
    public init<S: StringProtocol>(_ title: S, text: Binding<String>, axis: Axis) {}
    public init<S: StringProtocol, V>(_ title: S, value: Binding<V>, format: NumberFormatStyleStub) {}
    public init<S: StringProtocol, V>(_ title: S, value: Binding<V?>, format: NumberFormatStyleStub) {}
    public var body: Never { return fatalError() }
}
public struct NumberFormatStyleStub {}
extension NumberFormatStyleStub { public static var number: NumberFormatStyleStub { .init() } }
public struct SecureField: View { public init<S: StringProtocol>(_ title: S, text: Binding<String>) {}; public var body: Never { return fatalError() } }
public struct DatePickerComponents: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let date = DatePickerComponents(rawValue: 1), hourAndMinute = DatePickerComponents(rawValue: 2)
}
public struct DatePicker: View {
    public init<S: StringProtocol>(_ title: S, selection: Binding<Date>, displayedComponents: DatePickerComponents = [.date, .hourAndMinute]) {}
    public init<S: StringProtocol>(_ title: S, selection: Binding<Date>, in range: PartialRangeFrom<Date>, displayedComponents: DatePickerComponents = [.date, .hourAndMinute]) {}
    public init<S: StringProtocol>(_ title: S, selection: Binding<Date>, in range: PartialRangeThrough<Date>, displayedComponents: DatePickerComponents = [.date, .hourAndMinute]) {}
    public init<S: StringProtocol>(_ title: S, selection: Binding<Date>, in range: ClosedRange<Date>, displayedComponents: DatePickerComponents = [.date, .hourAndMinute]) {}
    public var body: Never { return fatalError() }
}
public struct Stepper: View {
    public init<S: StringProtocol, V: Strideable>(_ title: S, value: Binding<V>, in range: ClosedRange<V>, step: V.Stride = 1) {}
    public init<L: View, V: Strideable>(value: Binding<V>, in range: ClosedRange<V>, step: V.Stride = 1, @ViewBuilder label: () -> L) {}
    public var body: Never { return fatalError() }
}
public struct Slider: View {
    public init<V: BinaryFloatingPoint>(value: Binding<V>, in range: ClosedRange<V>, step: V.Stride = 1) {}
    public var body: Never { return fatalError() }
}
public struct ProgressView: View {
    public init() {}
    public init<V: BinaryFloatingPoint>(value: V?, total: V = 1.0) {}
    public var body: Never { return fatalError() }
}
public struct ShareLink: View {
    public init<L: View>(item: String, @ViewBuilder label: () -> L) {}
    public init<L: View>(item: URL, @ViewBuilder label: () -> L) {}
    public var body: Never { return fatalError() }
}
public struct NavigationPath {
    public init() {}
    public var isEmpty: Bool { true }
    public var count: Int { 0 }
    public mutating func append<V: Hashable>(_ v: V) {}
    public mutating func removeLast(_ k: Int = 1) {}
}
public struct NavigationStack: View {
    public init<C: View>(@ViewBuilder root: () -> C) {}
    public init<C: View>(path: Binding<NavigationPath>, @ViewBuilder root: () -> C) {}
    public init<P, C: View>(path: Binding<[P]>, @ViewBuilder root: () -> C) {}
    public var body: Never { return fatalError() }
}
public struct NavigationLink: View {
    public init<P: Hashable, L: View>(value: P?, @ViewBuilder label: () -> L) {}
    public init<D: View, L: View>(destination: D, @ViewBuilder label: () -> L) {}
    public init<D: View, L: View>(@ViewBuilder destination: () -> D, @ViewBuilder label: () -> L) {}
    public var body: Never { return fatalError() }
}
public struct TabView: View {
    public init<C: View>(@ViewBuilder content: () -> C) {}
    public init<S: Hashable, C: View>(selection: Binding<S>, @ViewBuilder content: () -> C) {}
    public var body: Never { return fatalError() }
}
public struct PageTabViewStyle { public enum IndexDisplayMode { case always, never, automatic } }
public struct TabStyle {
    public static func page(indexDisplayMode: PageTabViewStyle.IndexDisplayMode = .automatic) -> TabStyle { .init() }
    public static var page: TabStyle { .init() }
}

// MARK: - Toolbar

public enum ToolbarItemPlacement {
    case topBarTrailing, topBarLeading, cancellationAction, confirmationAction, navigationBarTrailing, navigationBarLeading, principal, automatic, keyboard, bottomBar
}
public protocol ToolbarContent {}
public struct ToolbarItem: ToolbarContent { public init<C: View>(placement: ToolbarItemPlacement = .automatic, @ViewBuilder content: () -> C) {} }
public struct ToolbarItemGroup: ToolbarContent { public init<C: View>(placement: ToolbarItemPlacement = .automatic, @ViewBuilder content: () -> C) {} }
@resultBuilder public enum ToolbarContentBuilder {
    public static func buildExpression<T: ToolbarContent>(_ t: T) -> AnyToolbar { AnyToolbar() }
    public static func buildBlock(_ c: AnyToolbar...) -> AnyToolbar { AnyToolbar() }
    public static func buildOptional(_ c: AnyToolbar?) -> AnyToolbar { AnyToolbar() }
    public static func buildEither(first: AnyToolbar) -> AnyToolbar { AnyToolbar() }
    public static func buildEither(second: AnyToolbar) -> AnyToolbar { AnyToolbar() }
}
public struct AnyToolbar: ToolbarContent {}
public enum ToolbarPlacementBar { case navigationBar, tabBar }
public enum Visibility { case hidden, visible, automatic }

// MARK: - Shapes, colors, styles

public protocol ShapeStyle {}
public protocol Shape: View {}
extension Shape { public var body: Never { return fatalError() } }
public struct StrokeStyle {
    public init(lineWidth: CGFloat = 1, lineCap: CGLineCap = .butt, lineJoin: CGLineJoin = .miter, dash: [CGFloat] = []) {}
}
public enum CGLineCap { case butt, round, square }
public enum CGLineJoin { case miter, round, bevel }
extension Shape {
    public func fill<S: ShapeStyle>(_ s: S) -> AnyV { AnyV() }
    public func stroke<S: ShapeStyle>(_ s: S, lineWidth: CGFloat = 1) -> AnyV { AnyV() }
    public func stroke<S: ShapeStyle>(_ s: S, style: StrokeStyle) -> AnyV { AnyV() }
    public func strokeBorder<S: ShapeStyle>(_ s: S, lineWidth: CGFloat = 1) -> AnyV { AnyV() }
    public func strokeBorder<S: ShapeStyle>(_ s: S, style: StrokeStyle) -> AnyV { AnyV() }
    public func trim(from: CGFloat = 0, to: CGFloat = 1) -> TrimmedShape { TrimmedShape() }
}
public struct TrimmedShape: Shape {}
public struct Circle: Shape { public init() {} }
public struct Ellipse: Shape { public init() {} }
public struct Capsule: Shape { public init(style: RoundedCornerStyle = .circular) {} }
public struct Rectangle: Shape { public init() {} }
public enum RoundedCornerStyle { case circular, continuous }
public struct RoundedRectangle: Shape { public init(cornerRadius: CGFloat, style: RoundedCornerStyle = .circular) {} }
public struct UnevenRoundedRectangle: Shape {
    public init(topLeadingRadius: CGFloat = 0, bottomLeadingRadius: CGFloat = 0, bottomTrailingRadius: CGFloat = 0, topTrailingRadius: CGFloat = 0, style: RoundedCornerStyle = .circular) {}
}
public struct Path: Shape {
    public init() {}
    public init(_ build: (inout Path) -> Void) {}
    public mutating func move(to: CGPoint) {}
    public mutating func addLine(to: CGPoint) {}
    public mutating func addQuadCurve(to: CGPoint, control: CGPoint) {}
    public mutating func addArc(center: CGPoint, radius: CGFloat, startAngle: Angle, endAngle: Angle, clockwise: Bool) {}
    public mutating func closeSubpath() {}
}

public struct Color: View, ShapeStyle, Hashable {
    public init(_ ui: UIColor) {}
    public init(uiColor: UIColor) {}
    public init(red: Double, green: Double, blue: Double, opacity: Double = 1) {}
    public init(_ name: String) {}
    public var body: Never { return fatalError() }
    public static let white = Color(red: 1, green: 1, blue: 1), black = Color(red: 0, green: 0, blue: 0), clear = Color(red: 0, green: 0, blue: 0),
        red = white, green = white, blue = white, orange = white, yellow = white, gray = white, indigo = white, teal = white,
        brown = white, purple = white, pink = white, mint = white, cyan = white, primary = white, secondary = white
    public func opacity(_ o: Double) -> Color { self }
    public var gradient: AnyGradient { AnyGradient() }
}
public struct AnyGradient: ShapeStyle {}
extension ShapeStyle where Self == Color {
    public static var white: Color { .white }
    public static var black: Color { .black }
    public static var clear: Color { .clear }
    public static var red: Color { .red }
    public static var primary: Color { .primary }
    public static var secondary: Color { .secondary }
    public static var orange: Color { .orange }
    public static var gray: Color { .gray }
}
public struct Material: ShapeStyle {
    public static let thinMaterial = Material(), ultraThinMaterial = Material(), regularMaterial = Material(), thickMaterial = Material()
}
extension ShapeStyle where Self == Material {
    public static var thinMaterial: Material { .thinMaterial }
    public static var ultraThinMaterial: Material { .ultraThinMaterial }
    public static var regularMaterial: Material { .regularMaterial }
}
public struct Gradient { public init(colors: [Color]) {} }
public struct LinearGradient: ShapeStyle, View {
    public init(colors: [Color], startPoint: UnitPoint, endPoint: UnitPoint) {}
    public init(gradient: Gradient, startPoint: UnitPoint, endPoint: UnitPoint) {}
    public var body: Never { return fatalError() }
}
public struct RadialGradient: ShapeStyle, View {
    public init(colors: [Color], center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) {}
    public var body: Never { return fatalError() }
}
public struct AngularGradient: ShapeStyle, View {
    public init(colors: [Color], center: UnitPoint) {}
    public var body: Never { return fatalError() }
}

public struct Font {
    public enum Weight { case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black }
    public enum Design { case `default`, rounded, monospaced, serif }
    public enum TextStyle { case largeTitle, title, title2, title3, headline, subheadline, body, callout, footnote, caption, caption2 }
    public static func system(size: CGFloat, weight: Weight = .regular, design: Design = .default) -> Font { .init() }
    public static func system(_ style: TextStyle, design: Design = .default, weight: Weight = .regular) -> Font { .init() }
    public static func system(_ style: TextStyle, weight: Weight) -> Font { .init() }
    public static let largeTitle = Font(), title = Font(), title2 = Font(), title3 = Font(), headline = Font(), subheadline = Font(),
        body = Font(), callout = Font(), footnote = Font(), caption = Font(), caption2 = Font()
    public func weight(_ w: Weight) -> Font { self }
    public func monospacedDigit() -> Font { self }
}
public enum ContentMode { case fit, fill }

public struct Animation {
    public static func spring(duration: Double = 0.5, bounce: Double = 0) -> Animation { .init() }
    public static func spring(response: Double = 0.5, dampingFraction: Double = 0.8) -> Animation { .init() }
    public static var spring: Animation { .init() }
    public static func easeOut(duration: Double) -> Animation { .init() }
    public static func easeIn(duration: Double) -> Animation { .init() }
    public static func easeInOut(duration: Double) -> Animation { .init() }
    public static func linear(duration: Double) -> Animation { .init() }
    public static var easeOut: Animation { .init() }
    public static var easeInOut: Animation { .init() }
    public static var linear: Animation { .init() }
    public static var `default`: Animation { .init() }
    public static var snappy: Animation { .init() }
    public static func snappy(duration: Double = 0.3, extraBounce: Double = 0) -> Animation { .init() }
    public static var bouncy: Animation { .init() }
    public func delay(_ d: Double) -> Animation { self }
    public func repeatForever(autoreverses: Bool = true) -> Animation { self }
    public func repeatCount(_ n: Int, autoreverses: Bool = true) -> Animation { self }
}
public func withAnimation<R>(_ a: Animation? = .default, _ body: () throws -> R) rethrows -> R { try body() }
public struct AnyTransition {
    public static let opacity = AnyTransition(), identity = AnyTransition(), scale = AnyTransition(), slide = AnyTransition()
    public static func move(edge: Edge) -> AnyTransition { .init() }
    public static func scale(scale: CGFloat, anchor: UnitPoint = .center) -> AnyTransition { .init() }
    public static func asymmetric(insertion: AnyTransition, removal: AnyTransition) -> AnyTransition { .init() }
    public static func push(from edge: Edge) -> AnyTransition { .init() }
    public func combined(with other: AnyTransition) -> AnyTransition { self }
}
public struct ContentTransition {
    public static func numericText(countsDown: Bool = false) -> ContentTransition { .init() }
    public static let opacity = ContentTransition(), identity = ContentTransition()
}
public struct Angle {
    public static func degrees(_ d: Double) -> Angle { .init() }
    public static func radians(_ r: Double) -> Angle { .init() }
    public static let zero = Angle()
}

public protocol ButtonStyle {
    associatedtype Body: View
    typealias Configuration = ButtonStyleConfiguration
    @MainActor @ViewBuilder func makeBody(configuration: Configuration) -> Body
}
public struct ButtonStyleConfiguration { public let label = AnyV(); public let isPressed = false; public let role: ButtonRole? = nil }
public struct PlainButtonStyle: ButtonStyle { public init() {}; public func makeBody(configuration: Configuration) -> AnyV { AnyV() } }
extension ButtonStyle where Self == PlainButtonStyle { public static var plain: PlainButtonStyle { .init() } }
public struct BorderlessButtonStyle: ButtonStyle { public init() {}; public func makeBody(configuration: Configuration) -> AnyV { AnyV() } }
extension ButtonStyle where Self == BorderlessButtonStyle { public static var borderless: BorderlessButtonStyle { .init() } }

public enum DatePickerStyleKind { case wheel, compact, graphical }
public enum TextInputAutocapitalization { case never, words, sentences, characters }
public enum UIKeyboardType { case `default`, numberPad, decimalPad, emailAddress, phonePad, URL }
public struct UITextContentType {
    public static let name = UITextContentType(), givenName = UITextContentType(), familyName = UITextContentType(),
        emailAddress = UITextContentType(), password = UITextContentType(), newPassword = UITextContentType(),
        username = UITextContentType(), addressCity = UITextContentType(), oneTimeCode = UITextContentType()
}
public enum ControlSize { case mini, small, regular, large }
public enum ScrollIndicatorVisibility { case hidden, visible, automatic, never }
public enum ScrollDismissesKeyboardMode { case interactively, immediately, never, automatic }
public enum PresentationDetent: Hashable {
    case medium, large
    public static func height(_ h: CGFloat) -> PresentationDetent { .medium }
    public static func fraction(_ f: CGFloat) -> PresentationDetent { .medium }
}
public enum NavigationBarItemTitleDisplayMode { case inline, large, automatic }
public enum TextSelectability { case enabled, disabled }
public enum SubmitLabel { case done, go, search, next, `return`, send }
public struct SensoryFeedback {
    public static let success = SensoryFeedback(), warning = SensoryFeedback(), error = SensoryFeedback(),
        selection = SensoryFeedback(), impact = SensoryFeedback(), increase = SensoryFeedback(), decrease = SensoryFeedback()
    public static func impact(weight: Weight = .medium, intensity: Double = 1) -> SensoryFeedback { .init() }
    public enum Weight { case light, medium, heavy }
}
public struct AccessibilityChildBehavior {
    public static let combine = AccessibilityChildBehavior(), ignore = AccessibilityChildBehavior(), contain = AccessibilityChildBehavior()
}
public struct AccessibilityTraits: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let isSelected = AccessibilityTraits(rawValue: 1), isButton = AccessibilityTraits(rawValue: 2), isHeader = AccessibilityTraits(rawValue: 4)
}
public enum VerticalEdge { case top, bottom }
public enum TextAlignment { case leading, center, trailing }

// MARK: - View modifiers

extension View {
    public func strikethrough(_ on: Bool = true, color: Color? = nil) -> AnyV { AnyV() }
    public func bold(_ on: Bool = true) -> AnyV { AnyV() }
    public func italic(_ on: Bool = true) -> AnyV { AnyV() }
    public func underline(_ on: Bool = true, color: Color? = nil) -> AnyV { AnyV() }
    public func font(_ f: Font?) -> AnyV { AnyV() }
    public func fontWeight(_ w: Font.Weight?) -> AnyV { AnyV() }
    public func foregroundStyle<S: ShapeStyle>(_ s: S) -> AnyV { AnyV() }
    public func foregroundColor(_ c: Color?) -> AnyV { AnyV() }
    public func tint(_ c: Color?) -> AnyV { AnyV() }
    public func padding(_ e: Edge.Set = .all, _ l: CGFloat? = nil) -> AnyV { AnyV() }
    public func padding(_ l: CGFloat) -> AnyV { AnyV() }
    public func background<S: ShapeStyle>(_ s: S) -> AnyV { AnyV() }
    public func background<S: ShapeStyle, T: Shape>(_ s: S, in shape: T) -> AnyV { AnyV() }
    public func background<V: View>(alignment: Alignment = .center, @ViewBuilder content: () -> V) -> AnyV { AnyV() }
    public func overlay<V: View>(alignment: Alignment = .center, @ViewBuilder content: () -> V) -> AnyV { AnyV() }
    public func overlay<V: View>(_ v: V, alignment: Alignment = .center) -> AnyV { AnyV() }
    public func frame(width: CGFloat? = nil, height: CGFloat? = nil, alignment: Alignment = .center) -> AnyV { AnyV() }
    public func frame(minWidth: CGFloat? = nil, idealWidth: CGFloat? = nil, maxWidth: CGFloat? = nil, minHeight: CGFloat? = nil, idealHeight: CGFloat? = nil, maxHeight: CGFloat? = nil, alignment: Alignment = .center) -> AnyV { AnyV() }
    public func position(x: CGFloat = 0, y: CGFloat = 0) -> AnyV { AnyV() }
    public func tracking(_ t: CGFloat) -> AnyV { AnyV() }
    public func kerning(_ t: CGFloat) -> AnyV { AnyV() }
    public func clipShape<S: Shape>(_ s: S) -> AnyV { AnyV() }
    public func clipped() -> AnyV { AnyV() }
    public func cornerRadius(_ r: CGFloat) -> AnyV { AnyV() }
    public func buttonStyle<S: ButtonStyle>(_ s: S) -> AnyV { AnyV() }
    public func opacity(_ o: Double) -> AnyV { AnyV() }
    public func lineLimit(_ n: Int?) -> AnyV { AnyV() }
    public func lineLimit(_ r: ClosedRange<Int>) -> AnyV { AnyV() }
    public func lineLimit(_ r: PartialRangeFrom<Int>) -> AnyV { AnyV() }
    public func lineSpacing(_ s: CGFloat) -> AnyV { AnyV() }
    public func multilineTextAlignment(_ a: TextAlignment) -> AnyV { AnyV() }
    public func minimumScaleFactor(_ f: CGFloat) -> AnyV { AnyV() }
    public func monospacedDigit() -> AnyV { AnyV() }
    public func fixedSize() -> AnyV { AnyV() }
    public func fixedSize(horizontal: Bool, vertical: Bool) -> AnyV { AnyV() }
    public func sheet<C: View>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> C) -> AnyV { AnyV() }
    public func sheet<I: Identifiable, C: View>(item: Binding<I?>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping (I) -> C) -> AnyV { AnyV() }
    public func fullScreenCover<C: View>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> C) -> AnyV { AnyV() }
    public func fullScreenCover<I: Identifiable, C: View>(item: Binding<I?>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping (I) -> C) -> AnyV { AnyV() }
    public func confirmationDialog<S: StringProtocol, A: View>(_ title: S, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: () -> A) -> AnyV { AnyV() }
    public func confirmationDialog<S: StringProtocol, A: View, M: View>(_ title: S, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: () -> A, @ViewBuilder message: () -> M) -> AnyV { AnyV() }
    public func alert<S: StringProtocol, A: View>(_ title: S, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A) -> AnyV { AnyV() }
    public func alert<S: StringProtocol, A: View, M: View>(_ title: S, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A, @ViewBuilder message: () -> M) -> AnyV { AnyV() }
    public func disabled(_ d: Bool) -> AnyV { AnyV() }
    public func scrollIndicators(_ v: ScrollIndicatorVisibility) -> AnyV { AnyV() }
    public func scrollDismissesKeyboard(_ m: ScrollDismissesKeyboardMode) -> AnyV { AnyV() }
    public func animation<V: Equatable>(_ a: Animation?, value: V) -> AnyV { AnyV() }
    public func transition(_ t: AnyTransition) -> AnyV { AnyV() }
    public func navigationTitle<S: StringProtocol>(_ t: S) -> AnyV { AnyV() }
    public func navigationBarTitleDisplayMode(_ m: NavigationBarItemTitleDisplayMode) -> AnyV { AnyV() }
    public func navigationDestination<D: Hashable, C: View>(for: D.Type, @ViewBuilder destination: @escaping (D) -> C) -> AnyV { AnyV() }
    public func navigationDestination<C: View>(isPresented: Binding<Bool>, @ViewBuilder destination: () -> C) -> AnyV { AnyV() }
    public func presentationDetents(_ d: Set<PresentationDetent>) -> AnyV { AnyV() }
    public func presentationBackground<S: ShapeStyle>(_ s: S) -> AnyV { AnyV() }
    public func presentationDragIndicator(_ v: Visibility) -> AnyV { AnyV() }
    public func interactiveDismissDisabled(_ d: Bool = true) -> AnyV { AnyV() }
    public func toolbar(@ToolbarContentBuilder content: () -> AnyToolbar) -> AnyV { AnyV() }
    public func toolbar(_ v: Visibility, for bars: ToolbarPlacementBar...) -> AnyV { AnyV() }
    public func environment<T: AnyObject>(_ o: T) -> AnyV { AnyV() }
    public func environment<V>(_ kp: WritableKeyPath<EnvironmentValues, V>, _ v: V) -> AnyV { AnyV() }
    public func modifier<M: ViewModifier>(_ m: M) -> AnyV { AnyV() }
    public func onAppear(perform: (() -> Void)? = nil) -> AnyV { AnyV() }
    public func onDisappear(perform: (() -> Void)? = nil) -> AnyV { AnyV() }
    public func task(priority: TaskPriority = .userInitiated, _ action: @escaping @Sendable () async -> Void) -> AnyV { AnyV() }
    public func task<T: Equatable>(id: T, priority: TaskPriority = .userInitiated, _ action: @escaping @Sendable () async -> Void) -> AnyV { AnyV() }
    public func refreshable(action: @escaping @Sendable () async -> Void) -> AnyV { AnyV() }
    public func onChange<V: Equatable>(of v: V, initial: Bool = false, _ action: @escaping (V, V) -> Void) -> AnyV { AnyV() }
    public func onChange<V: Equatable>(of v: V, initial: Bool = false, _ action: @escaping () -> Void) -> AnyV { AnyV() }
    public func onSubmit(_ action: @escaping () -> Void) -> AnyV { AnyV() }
    public func onTapGesture(count: Int = 1, perform: @escaping () -> Void) -> AnyV { AnyV() }
    public func onLongPressGesture(minimumDuration: Double = 0.5, perform: @escaping () -> Void) -> AnyV { AnyV() }
    public func onReceive<P>(_ p: P, perform: @escaping (Date) -> Void) -> AnyV { AnyV() }
    public func contextMenu<M: View>(@ViewBuilder menuItems: () -> M) -> AnyV { AnyV() }
    public func contentShape<S: Shape>(_ s: S) -> AnyV { AnyV() }
    public func shadow(color: Color = .black, radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) -> AnyV { AnyV() }
    public func offset(x: CGFloat = 0, y: CGFloat = 0) -> AnyV { AnyV() }
    public func offset(_ s: CGSize) -> AnyV { AnyV() }
    public func scaleEffect(_ s: CGFloat, anchor: UnitPoint = .center) -> AnyV { AnyV() }
    public func rotationEffect(_ a: Angle, anchor: UnitPoint = .center) -> AnyV { AnyV() }
    public func rotation3DEffect(_ a: Angle, axis: (x: CGFloat, y: CGFloat, z: CGFloat), anchor: UnitPoint = .center, anchorZ: CGFloat = 0, perspective: CGFloat = 1) -> AnyV { AnyV() }
    public func aspectRatio(_ r: CGFloat? = nil, contentMode: ContentMode) -> AnyV { AnyV() }
    public func scaledToFill() -> AnyV { AnyV() }
    public func scaledToFit() -> AnyV { AnyV() }
    public func ignoresSafeArea(_ r: Int = 0, edges: Edge.Set = .all) -> AnyV { AnyV() }
    public func ignoresSafeArea(edges: Edge.Set) -> AnyV { AnyV() }
    public func safeAreaInset<V: View>(edge: VerticalEdge, alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> V) -> AnyV { AnyV() }
    public func id<ID: Hashable>(_ id: ID) -> AnyV { AnyV() }
    public func tag<T: Hashable>(_ t: T) -> AnyV { AnyV() }
    public func tabItem<V: View>(@ViewBuilder _ label: () -> V) -> AnyV { AnyV() }
    public func tabViewStyle(_ s: TabStyle) -> AnyV { AnyV() }
    public func labelsHidden() -> AnyV { AnyV() }
    public func keyboardType(_ k: UIKeyboardType) -> AnyV { AnyV() }
    public func textContentType(_ t: UITextContentType?) -> AnyV { AnyV() }
    public func textInputAutocapitalization(_ a: TextInputAutocapitalization?) -> AnyV { AnyV() }
    public func autocorrectionDisabled(_ d: Bool = true) -> AnyV { AnyV() }
    public func datePickerStyle(_ s: DatePickerStyleKind) -> AnyV { AnyV() }
    public func controlSize(_ s: ControlSize) -> AnyV { AnyV() }
    public func accessibilityLabel<S: StringProtocol>(_ s: S) -> AnyV { AnyV() }
    public func accessibilityHint<S: StringProtocol>(_ s: S) -> AnyV { AnyV() }
    public func accessibilityValue<S: StringProtocol>(_ s: S) -> AnyV { AnyV() }
    public func accessibilityHidden(_ h: Bool) -> AnyV { AnyV() }
    public func accessibilityElement(children: AccessibilityChildBehavior = .ignore) -> AnyV { AnyV() }
    public func accessibilityAddTraits(_ t: AccessibilityTraits) -> AnyV { AnyV() }
    public func contentTransition(_ t: ContentTransition) -> AnyV { AnyV() }
    public func textSelection(_ t: TextSelectability) -> AnyV { AnyV() }
    public func allowsHitTesting(_ a: Bool) -> AnyV { AnyV() }
    public func blur(radius: CGFloat) -> AnyV { AnyV() }
    public func zIndex(_ z: Double) -> AnyV { AnyV() }
    public func redacted(reason: Int) -> AnyV { AnyV() }
    public func symbolEffect(_ e: Int) -> AnyV { AnyV() }
    public func focused(_ b: FocusState<Bool>.Binding) -> AnyV { AnyV() }
    public func submitLabel(_ l: SubmitLabel) -> AnyV { AnyV() }
    public func sensoryFeedback<T: Equatable>(_ f: SensoryFeedback, trigger: T) -> AnyV { AnyV() }
    public func mapStyle(_ s: MapStyle) -> AnyV { AnyV() }
    public func chartXAxis<C: AxisContent>(@AxisContentBuilder content: () -> C) -> AnyV { AnyV() }
    public func chartYAxis<C: AxisContent>(@AxisContentBuilder content: () -> C) -> AnyV { AnyV() }
    public func chartXAxis(_ v: Visibility) -> AnyV { AnyV() }
    public func chartYAxis(_ v: Visibility) -> AnyV { AnyV() }
    public func chartXScale<D>(domain: D) -> AnyV { AnyV() }
    public func chartYScale<D>(domain: D) -> AnyV { AnyV() }
    public func chartYScale(domain: ScaleDomainAuto) -> AnyV { AnyV() }
    public func chartLegend(_ v: Visibility) -> AnyV { AnyV() }
    public func signInWithAppleButtonStyle(_ s: SignInWithAppleButton.Style) -> AnyV { AnyV() }
}

// MARK: - Charts

public protocol ChartContent {}
@resultBuilder public enum ChartContentBuilder {
    public static func buildExpression<C: ChartContent>(_ c: C) -> AnyChart { AnyChart() }
    public static func buildBlock(_ c: AnyChart...) -> AnyChart { AnyChart() }
    public static func buildOptional(_ c: AnyChart?) -> AnyChart { AnyChart() }
    public static func buildEither(first: AnyChart) -> AnyChart { AnyChart() }
    public static func buildEither(second: AnyChart) -> AnyChart { AnyChart() }
}
public struct AnyChart: ChartContent {}
public struct Chart: View {
    public init(@ChartContentBuilder content: () -> AnyChart) {}
    public init<D: RandomAccessCollection>(_ data: D, @ChartContentBuilder content: @escaping (D.Element) -> AnyChart) where D.Element: Identifiable {}
    public init<D: RandomAccessCollection, ID: Hashable>(_ data: D, id: KeyPath<D.Element, ID>, @ChartContentBuilder content: @escaping (D.Element) -> AnyChart) {}
    public var body: Never { return fatalError() }
}
extension ForEach: ChartContent {}
extension ForEach where Data: RandomAccessCollection, Data.Element: Identifiable, ID == Data.Element.ID {
    public init(_ data: Data, @ChartContentBuilder content: @escaping (Data.Element) -> AnyChart) {}
}
public struct PlottableValue<V> {
    public static func value<S: StringProtocol>(_ label: S, _ v: V) -> PlottableValue<V> { .init() }
    public static func value<S: StringProtocol>(_ label: S, _ v: V, unit: Calendar.Component) -> PlottableValue<V> { .init() }
}
public enum MarkDimension { case ratio(CGFloat), fixed(CGFloat), automatic }
public enum InterpolationMethod { case linear, catmullRom, monotone, cardinal }
public struct BarMark: ChartContent {
    public init<X, Y>(x: PlottableValue<X>, y: PlottableValue<Y>, width: MarkDimension = .automatic) {}
    public init<X, Y>(x: PlottableValue<X>, yStart: PlottableValue<Y>, yEnd: PlottableValue<Y>, width: MarkDimension = .automatic) {}
}
public struct LineMark: ChartContent { public init<X, Y>(x: PlottableValue<X>, y: PlottableValue<Y>) {} }
public struct PointMark: ChartContent { public init<X, Y>(x: PlottableValue<X>, y: PlottableValue<Y>) {} }
public struct AreaMark: ChartContent { public init<X, Y>(x: PlottableValue<X>, y: PlottableValue<Y>) {} }
public struct RuleMark: ChartContent {
    public init<Y>(y: PlottableValue<Y>) {}
    public init<X>(x: PlottableValue<X>) {}
}
public struct SectorMark: ChartContent {
    public init<V>(angle: PlottableValue<V>, innerRadius: MarkDimension = .automatic, outerRadius: MarkDimension = .automatic, angularInset: CGFloat? = nil) {}
}
extension ChartContent {
    public func foregroundStyle<S: ShapeStyle>(_ s: S) -> AnyChart { AnyChart() }
    public func foregroundStyle<V>(by: PlottableValue<V>) -> AnyChart { AnyChart() }
    public func interpolationMethod(_ m: InterpolationMethod) -> AnyChart { AnyChart() }
    public func lineStyle(_ s: StrokeStyle) -> AnyChart { AnyChart() }
    public func symbolSize(_ s: CGFloat) -> AnyChart { AnyChart() }
    public func cornerRadius(_ r: CGFloat) -> AnyChart { AnyChart() }
    public func opacity(_ o: Double) -> AnyChart { AnyChart() }
    public func annotation<C: View>(position: AnnotationPosition = .automatic, alignment: Alignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> C) -> AnyChart { AnyChart() }
}
public enum AnnotationPosition { case automatic, top, bottom, leading, trailing, overlay }
public protocol AxisContent {}
@resultBuilder public enum AxisContentBuilder {
    public static func buildExpression<C: AxisContent>(_ c: C) -> AnyAxis { AnyAxis() }
    public static func buildBlock(_ c: AnyAxis...) -> AnyAxis { AnyAxis() }
}
public struct AnyAxis: AxisContent {}
public struct AxisMarkValues {
    public static func stride(by: Calendar.Component, count: Int = 1) -> AxisMarkValues { .init() }
    public static var automatic: AxisMarkValues { .init() }
    public static func automatic(desiredCount: Int) -> AxisMarkValues { .init() }
}
public enum AxisMarkPosition { case leading, trailing, bottom, top, automatic }
public struct AxisValue {
    public func `as`<T>(_ t: T.Type) -> T? { nil }
}
public struct AxisMarks: AxisContent {
    public init(values: AxisMarkValues = .automatic, @AxisContentBuilder content: @escaping (AxisValue) -> AnyAxis) {}
    public init(position: AxisMarkPosition = .automatic, values: AxisMarkValues = .automatic, @AxisContentBuilder content: @escaping (AxisValue) -> AnyAxis) {}
    public init(values: AxisMarkValues = .automatic) {}
}
public struct AxisValueLabel: AxisContent {
    public init() {}
    public init(format: Date.FormatStyle, centered: Bool? = nil) {}
    public init<C: View>(@ViewBuilder content: () -> C) {}
    public func font(_ f: Font) -> AxisValueLabel { self }
    public func foregroundStyle<S: ShapeStyle>(_ s: S) -> AxisValueLabel { self }
}
public struct AxisGridLine: AxisContent {
    public init() {}
    public func foregroundStyle<S: ShapeStyle>(_ s: S) -> AxisGridLine { self }
}
public struct ScaleDomainAuto { public static func automatic(includesZero: Bool) -> ScaleDomainAuto { .init() } }

// MARK: - MapKit

public struct MapCameraPosition {
    public static var automatic: MapCameraPosition { .init() }
    public static func userLocation(fallback: MapCameraPosition) -> MapCameraPosition { .init() }
    public static func userLocation(followsHeading: Bool = false, fallback: MapCameraPosition) -> MapCameraPosition { .init() }
    public static func region(_ r: MKCoordinateRegion) -> MapCameraPosition { .init() }
    public static func camera(_ c: MapCamera) -> MapCameraPosition { .init() }
}
public struct MapCamera { public init(centerCoordinate: CLLocationCoordinate2D, distance: Double, heading: Double = 0, pitch: Double = 0) {} }
public struct MKCoordinateSpan { public init(latitudeDelta: Double, longitudeDelta: Double) {} }
public struct MKCoordinateRegion {
    public init(center: CLLocationCoordinate2D, span: MKCoordinateSpan) {}
    public init(center: CLLocationCoordinate2D, latitudinalMeters: Double, longitudinalMeters: Double) {}
}
public struct MapInteractionModes: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let zoom = Self(rawValue: 1), pan = Self(rawValue: 2), rotate = Self(rawValue: 4), all = Self(rawValue: 7)
}
public protocol MapContent {}
@resultBuilder public enum MapContentBuilder {
    public static func buildExpression<C: MapContent>(_ c: C) -> AnyMapContent { AnyMapContent() }
    public static func buildBlock(_ c: AnyMapContent...) -> AnyMapContent { AnyMapContent() }
    public static func buildOptional(_ c: AnyMapContent?) -> AnyMapContent { AnyMapContent() }
    public static func buildEither(first: AnyMapContent) -> AnyMapContent { AnyMapContent() }
    public static func buildEither(second: AnyMapContent) -> AnyMapContent { AnyMapContent() }
}
public struct AnyMapContent: MapContent {}
extension ForEach: MapContent {}
extension ForEach where Data: RandomAccessCollection, Data.Element: Identifiable, ID == Data.Element.ID {
    public init(_ data: Data, @MapContentBuilder content: @escaping (Data.Element) -> AnyMapContent) {}
}
extension ForEach where Data: RandomAccessCollection {
    public init(_ data: Data, id: KeyPath<Data.Element, ID>, @MapContentBuilder content: @escaping (Data.Element) -> AnyMapContent) {}
}
public struct Map: View {
    public init(position: Binding<MapCameraPosition>, interactionModes: MapInteractionModes = .all, @MapContentBuilder content: () -> AnyMapContent) {}
    public init(initialPosition: MapCameraPosition, interactionModes: MapInteractionModes = .all, @MapContentBuilder content: () -> AnyMapContent) {}
    public var body: Never { return fatalError() }
}
public struct MapPolyline: MapContent { public init(coordinates: [CLLocationCoordinate2D]) {} }
public struct MapPolygon: MapContent { public init(coordinates: [CLLocationCoordinate2D]) {} }
public struct MapCircle: MapContent { public init(center: CLLocationCoordinate2D, radius: Double) {} }
extension MapContent {
    public func stroke<S: ShapeStyle>(_ s: S, lineWidth: CGFloat) -> AnyMapContent { AnyMapContent() }
    public func stroke<S: ShapeStyle>(_ s: S, style: StrokeStyle) -> AnyMapContent { AnyMapContent() }
    public func foregroundStyle<S: ShapeStyle>(_ s: S) -> AnyMapContent { AnyMapContent() }
    public func tag<T: Hashable>(_ t: T) -> AnyMapContent { AnyMapContent() }
}
public struct UserAnnotation: MapContent { public init() {} }
public struct Annotation: MapContent {
    public init<C: View>(_ title: String, coordinate: CLLocationCoordinate2D, anchor: UnitPoint = .center, @ViewBuilder content: () -> C) {}
}
public struct Marker: MapContent {
    public init(_ title: String, coordinate: CLLocationCoordinate2D) {}
    public init(_ title: String, systemImage: String, coordinate: CLLocationCoordinate2D) {}
    public func tint(_ c: Color) -> Marker { self }
}
public struct MapStyle {
    public enum Elevation { case automatic, flat, realistic }
    public enum Emphasis { case muted, automatic }
    public static func standard(elevation: Elevation = .automatic, emphasis: Emphasis = .automatic, pointsOfInterest: Int = 0) -> MapStyle { .init() }
    public static var standard: MapStyle { .init() }
}

// MARK: - AuthenticationServices

public final class ASAuthorizationAppleIDRequest { public var requestedScopes: [ASAuthorization.Scope]? }
public final class ASAuthorization { public enum Scope { case fullName, email }; public var credential: Any { fatalError() } }
public final class ASAuthorizationAppleIDCredential {
    public var user = ""
    public var fullName: PersonNameComponents?
    public var email: String?
    public var identityToken: Data?
}
public struct ASAuthorizationError: Error {
    public enum Code { case canceled, failed, unknown, invalidResponse, notHandled }
    public var code: Code
}
public struct SignInWithAppleButton: View {
    public enum Label { case signIn, signUp, `continue` }
    public enum Style { case black, white, whiteOutline }
    public init(_ label: Label, onRequest: @escaping (ASAuthorizationAppleIDRequest) -> Void, onCompletion: @escaping (Result<ASAuthorization, Error>) -> Void) {}
    public var body: Never { return fatalError() }
}

// MARK: - UIKit bridging

public class UIViewController: NSObject {}
public protocol UINavigationControllerDelegate: AnyObject {}
public protocol UIImagePickerControllerDelegate: AnyObject {}
public final class UIImagePickerController: UIViewController {
    public enum SourceType { case camera, photoLibrary }
    public enum CameraDevice { case rear, front }
    public struct InfoKey: Hashable { public static let originalImage = InfoKey(), editedImage = InfoKey() }
    public var sourceType: SourceType = .photoLibrary
    public var cameraDevice: CameraDevice = .rear
    public var allowsEditing = false
    public weak var delegate: (UIImagePickerControllerDelegate & UINavigationControllerDelegate)?
    public static func isSourceTypeAvailable(_ t: SourceType) -> Bool { false }
}
public protocol UIViewControllerRepresentable: View where Body == Never {
    associatedtype UIViewControllerType: UIViewController
    associatedtype Coordinator = Void
    typealias Context = UIViewControllerRepresentableContext<Self>
    func makeUIViewController(context: Context) -> UIViewControllerType
    func updateUIViewController(_ vc: UIViewControllerType, context: Context)
    func makeCoordinator() -> Coordinator
}
extension UIViewControllerRepresentable { public var body: Never { return fatalError() } }
extension UIViewControllerRepresentable where Coordinator == Void { public func makeCoordinator() {} }
public struct UIViewControllerRepresentableContext<R: UIViewControllerRepresentable> { public var coordinator: R.Coordinator { fatalError() } }

// MARK: - PhotosUI

public struct PHPickerFilter { public static let images = PHPickerFilter() }
public struct PHPickerConfiguration { public init() {}; public var filter: PHPickerFilter?; public var selectionLimit = 1 }
public final class PHPickerResult { public let itemProvider = NSItemProvider() }
public protocol PHPickerViewControllerDelegate: AnyObject { func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) }
public final class PHPickerViewController: UIViewController {
    public init(configuration: PHPickerConfiguration) {}
    public weak var delegate: PHPickerViewControllerDelegate?
}
public final class NSItemProvider {
    public func canLoadObject(ofClass: Any.Type) -> Bool { true }
    public func loadObject(ofClass: Any.Type, completionHandler: @escaping (Any?, Error?) -> Void) -> Progress { Progress(totalUnitCount: 1) }
}

// MARK: - Combine

public struct TimerPublisherStub { public func autoconnect() -> TimerPublisherStub { self } }
extension Timer {
    public static func publish(every: TimeInterval, on: RunLoop, in: RunLoop.Mode) -> TimerPublisherStub { .init() }
}

public struct Preview {}
