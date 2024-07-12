import SwiftUI
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins

struct ContentView: View {
    @State private var image: NSImage? = nil
    @State private var backgroundColor: Color = .white
    @State private var topColors: [(color: Color, hex: String, rgba: String)] = []
    @State private var isHovered: Bool = false
    @State private var hoveredIndex: Int? = nil
    @State private var selectedIndex: Int? = nil

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                VStack {
                    ZStack {
                        if let image = image {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray, style: StrokeStyle(lineWidth: 3, dash: [5, 3]))
                                        .scaleEffect(isHovered ? 1.05 : 1.0)
                                        .animation(.easeInOut(duration: 0.5), value: isHovered)
                                )
                                .frame(width: geometry.size.width * 2 / 3 - 60, height: geometry.size.height - 60)
                                .onTapGesture {
                                    withAnimation(.interpolatingSpring(stiffness: 70, damping: 7)) {
                                        self.image = image
                                    }
                                }
                                .onDrop(of: ["public.file-url"], isTargeted: nil, perform: handleDrop)
                                .onHover { hovering in
                                    self.isHovered = hovering
                                }
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray)
                                .frame(width: geometry.size.width * 2 / 3 - 60, height: geometry.size.height - 60)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray, style: StrokeStyle(lineWidth: 3, dash: [5, 3]))
                                )
                                .onDrop(of: ["public.file-url"], isTargeted: nil, perform: handleDrop)
                        }
                    }
                    .padding(20)
                    .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
                    .cornerRadius(10)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Details")
                        .font(.largeTitle)
                    ForEach(Array(topColors.enumerated()), id: \.offset) { index, colorInfo in
                        HStack {
                            Circle()
                                .fill(colorInfo.color)
                                .frame(width: 30, height: 30)
                                .shadow(radius: 5)
                            VStack(alignment: .leading) {
                                Text("Hex: \(colorInfo.hex)")
                                    .foregroundColor(.white)
                                    .onTapGesture {
                                        copyToClipboard(colorInfo.hex)
                                        selectedIndex = index
                                    }
                                Text("RGBA: \(colorInfo.rgba)")
                                    .foregroundColor(.white)
                                    .onTapGesture {
                                        copyToClipboard(colorInfo.rgba)
                                        selectedIndex = index
                                    }
                            }
                        }
                        .padding()
                        .background(hoveredIndex == index ? Color.black.opacity(0.2) : Color.black.opacity(0.1))
                        .cornerRadius(10)
                        .scaleEffect(hoveredIndex == index ? 1.025 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: hoveredIndex == index)
                        .opacity(hoveredIndex == index || selectedIndex == index ? 1.0 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: hoveredIndex == index || selectedIndex == index)
                        .onHover { hovering in
                            hoveredIndex = hovering ? index : nil
                        }
                        .onAppear {
                            withAnimation(.easeInOut(duration: 2.5).delay(Double(index) * 0.5)) {
                                hoveredIndex = index
                            }
                        }
                    }
                }
                .frame(width: geometry.size.width / 3, height: geometry.size.height)
                .padding()
            }
            .background(VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                            .background(backgroundColor.opacity(0.5)))
            .animation(.easeInOut, value: backgroundColor)
        }
        .edgesIgnoringSafeArea(.all)
        .frame(minWidth: 600, minHeight: 400)
    }
    
    struct VisualEffectView: NSViewRepresentable {
        var material: NSVisualEffectView.Material
        var blendingMode: NSVisualEffectView.BlendingMode
        
        func makeNSView(context: Context) -> NSVisualEffectView {
            let view = NSVisualEffectView()
            view.material = material
            view.blendingMode = blendingMode
            view.state = .active
            return view
        }
        
        func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
            nsView.material = material
            nsView.blendingMode = blendingMode
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        if let item = providers.first {
            item.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (urlData, error) in
                DispatchQueue.main.async {
                    if let urlData = urlData as? Data,
                       let url = URL(dataRepresentation: urlData, relativeTo: nil),
                       let image = NSImage(contentsOf: url) {
                        withAnimation(.interpolatingSpring(stiffness: 70, damping: 7)) {
                            self.image = image
                        }
                        self.backgroundColor = self.getDominantColor(image: image)
                        self.topColors = self.extractTopColors(image: image)
                        self.playSound()
                    }
                }
            }
            return true
        }
        return false
    }

    private func getDominantColor(image: NSImage) -> Color {
        guard let imageData = image.tiffRepresentation,
              let ciImage = CIImage(data: imageData) else {
            return Color.white
        }
        
        let context = CIContext()
        let extent = ciImage.extent
        let inputImage = ciImage.clampedToExtent()
        
        let parameters: [String: Any] = [kCIInputExtentKey: CIVector(cgRect: extent),
                                         kCIInputImageKey: inputImage]
        
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: parameters),
              let outputImage = filter.outputImage else {
            return Color.white
        }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage,
                       toBitmap: &bitmap,
                       rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8,
                       colorSpace: CGColorSpaceCreateDeviceRGB())
        
        let red = Double(bitmap[0]) / 255.0
        let green = Double(bitmap[1]) / 255.0
        let blue = Double(bitmap[2]) / 255.0
        
        return Color(red: red, green: green, blue: blue)
    }

    private func extractTopColors(image: NSImage) -> [(color: Color, hex: String, rgba: String)] {
        // Use k-means clustering to get the top 5 colors from the image
        guard let imageData = image.tiffRepresentation,
              let ciImage = CIImage(data: imageData) else {
            return []
        }
        
        let context = CIContext()
        let kMeansFilter = CIFilter(name: "CIKMeans", parameters: [
            "inputImage": ciImage,
            "inputCount": 5
        ])!
        
        guard let outputImage = kMeansFilter.outputImage,
              let bitmap = context.createCGImage(outputImage, from: outputImage.extent) else {
            return []
        }
        
        let width = bitmap.width
        let height = bitmap.height
        let data = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height * 4)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        let context2 = CGContext(data: data,
                                 width: width,
                                 height: height,
                                 bitsPerComponent: 8,
                                 bytesPerRow: 4 * width,
                                 space: colorSpace,
                                 bitmapInfo: bitmapInfo.rawValue)
        
        context2?.draw(bitmap, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        
        var colors: [(color: Color, hex: String, rgba: String)] = []
        
        for i in 0..<5 {
            let offset = i * 4
            let r = data[offset]
            let g = data[offset + 1]
            let b = data[offset + 2]
            let a = data[offset + 3]
            
            let color = Color(red: Double(r) / 255.0, green: Double(g) / 255.0, blue: Double(b) / 255.0, opacity: Double(a) / 255.0)
            let hex = String(format: "#%02X%02X%02X", r, g, b)
            let rgba = String(format: "rgba(%d, %d, %d, %.2f)", r, g, b, Double(a) / 255.0)
            
            colors.append((color: color, hex: hex, rgba: rgba))
        }
        
        data.deallocate()
        
        return colors
    }

    private func playSound() {
        guard let soundURL = Bundle.main.url(forResource: "plop", withExtension: "mp3") else { return }
        do {
            player = try AVAudioPlayer(contentsOf: soundURL)
            player?.play()
        } catch {
            print("Failed to play sound: \(error.localizedDescription)")
        }
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

private var player: AVAudioPlayer?

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
