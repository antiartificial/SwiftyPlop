import SwiftUI
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins

class AudioManager: NSObject, AVAudioPlayerDelegate {
    var audioPlayers: [AVAudioPlayer] = []

    func playSound(_ name: String) {
        guard let soundURL = Bundle.main.url(forResource: name, withExtension: "mp3") else {
            print("Sound file not found: \(name).mp3")
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: soundURL)
            player.delegate = self
            player.play()
            audioPlayers.append(player)
        } catch {
            print("Failed to play sound: \(error.localizedDescription)")
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if let index = audioPlayers.firstIndex(of: player) {
            audioPlayers.remove(at: index)
        }
    }
}

struct ContentView: View {
    @State private var image: NSImage? = nil
    @State private var backgroundColor: Color = .white
    @State private var topColors: [(color: Color, hex: String, rgba: String)] = []
    @State private var isHovered: Bool = false
    @State private var hoveredIndex: Int? = nil
    @State private var selectedIndex: Int? = nil
    @State private var isProcessing: Bool = false
    private var audioManager = AudioManager()

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
                    if isProcessing {
                        ProgressCircle()
                            .frame(width: 50, height: 50)
                            .transition(.opacity)
                    } else {
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
                                audioManager.playSound("detail")
                            }
                            .onAppear {
                                withAnimation(.easeInOut(duration: 2.5).delay(Double(index) * 0.5)) {
                                    hoveredIndex = index
                                }
                            }
                        }
                    }
                }
                .frame(width: geometry.size.width / 3, height: geometry.size.height)
                .padding()
                .opacity(isProcessing ? 0.5 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: isProcessing)
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
                if let urlData = urlData as? Data,
                   let url = URL(dataRepresentation: urlData, relativeTo: nil),
                   let image = NSImage(contentsOf: url) {
                    DispatchQueue.main.async {
                        withAnimation(.interpolatingSpring(stiffness: 70, damping: 7)) {
                            self.image = image
                        }
                        self.backgroundColor = self.getDominantColor(image: image)
                    }
                    self.isProcessing = true
                    self.extractTopColorsAsync(image: image) { colors in
                        DispatchQueue.main.async {
                            self.topColors = colors
                            self.isProcessing = false
                        }
                    }
                    audioManager.playSound("plop")
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

    private func resizeImageIfNeeded(image: NSImage, maxDimension: CGFloat) -> NSImage {
        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > maxDimension else { return image }
        
        let scale = maxDimension / longestSide
        let newSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        
        let resizedImage = NSImage(size: newSize)
        resizedImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy,
                   fraction: 1.0)
        resizedImage.unlockFocus()
        return resizedImage
    }

    private func extractTopColorsAsync(image: NSImage, completion: @escaping ([(color: Color, hex: String, rgba: String)]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let resizedImage = self.resizeImageIfNeeded(image: image, maxDimension: 300)
            guard let imageData = resizedImage.tiffRepresentation,
                  let ciImage = CIImage(data: imageData) else {
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }
            
            let bitmap = ciImage.toBitmap()
            let colors = kMeansCluster(colors: bitmap, k: 5)
            
            let result = colors.map { color in
                let (r, g, b) = (color.red, color.green, color.blue)
                let hex = String(format: "#%02X%02X%02X", r, g, b)
                let rgba = String(format: "rgba(%d, %d, %d, %.2f)", r, g, b, color.alpha)
                return (color: Color(red: Double(r) / 255.0, green: Double(g) / 255.0, blue: Double(b) / 255.0, opacity: color.alpha), hex: hex, rgba: rgba)
            }
            
            completion(result)
        }
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

struct ProgressCircle: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(Color.blue, lineWidth: 5)
                .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
                .onAppear {
                    self.isAnimating = true
                }
        }
    }
}

extension CIImage {
    func toBitmap() -> [(red: Int, green: Int, blue: Int, alpha: Double)] {
        let context = CIContext()
        let extent = self.extent
        guard let cgImage = context.createCGImage(self, from: extent) else { return [] }
        
        let width = Int(extent.width)
        let height = Int(extent.height)
        var bitmapData = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapContext = CGContext(data: &bitmapData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        bitmapContext?.draw(cgImage, in: extent)
        
        var bitmap: [(red: Int, green: Int, blue: Int, alpha: Double)] = []
        
        for x in 0..<width {
            for y in 0..<height {
                let offset = 4 * (x + y * width)
                let r = Int(bitmapData[offset])
                let g = Int(bitmapData[offset + 1])
                let b = Int(bitmapData[offset + 2])
                let a = Double(bitmapData[offset + 3]) / 255.0
                bitmap.append((red: r, green: g, blue: b, alpha: a))
            }
        }
        
        return bitmap
    }
}

func kMeansCluster(colors: [(red: Int, green: Int, blue: Int, alpha: Double)], k: Int) -> [(red: Int, green: Int, blue: Int, alpha: Double)] {
    var centroids = kMeansPlusPlusInit(colors: colors, k: k)
    var clusters = Array(repeating: [(red: Int, green: Int, blue: Int, alpha: Double)](), count: k)
    
    var didChange = true
    while didChange {
        clusters = Array(repeating: [(red: Int, green: Int, blue: Int, alpha: Double)](), count: k)
        
        for color in colors {
            let distances = centroids.map { centroid in
                pow(Double(color.red - centroid.red), 2) +
                pow(Double(color.green - centroid.green), 2) +
                pow(Double(color.blue - centroid.blue), 2)
            }
            let closestCentroidIndex = distances.enumerated().min(by: { $0.element < $1.element })!.offset
            clusters[closestCentroidIndex].append(color)
        }
        
        let newCentroids = clusters.map { cluster -> (red: Int, green: Int, blue: Int, alpha: Double) in
            if cluster.isEmpty {
                // If the cluster is empty, reinitialize the centroid with a random color from the original list
                return colors[Int.random(in: 0..<colors.count)]
            } else {
                let count = cluster.count
                let sum = cluster.reduce((red: 0, green: 0, blue: 0, alpha: 0.0)) { sum, color in
                    (red: sum.red + color.red, green: sum.green + color.green, blue: sum.blue + color.blue, alpha: sum.alpha + color.alpha)
                }
                return (red: sum.red / count, green: sum.green / count, blue: sum.blue / count, alpha: sum.alpha / Double(count))
            }
        }
        
        didChange = !zip(centroids, newCentroids).allSatisfy { $0 == $1 }
        centroids = newCentroids
    }
    
    return centroids
}

func kMeansPlusPlusInit(colors: [(red: Int, green: Int, blue: Int, alpha: Double)], k: Int) -> [(red: Int, green: Int, blue: Int, alpha: Double)] {
    var centroids: [(red: Int, green: Int, blue: Int, alpha: Double)] = []
    
    // Step 1: Randomly select the first centroid
    centroids.append(colors[Int.random(in: 0..<colors.count)])
    
    while centroids.count < k {
        var distances = [Double]()
        for color in colors {
            let minDistance = centroids.map { centroid in
                pow(Double(color.red - centroid.red), 2) +
                pow(Double(color.green - centroid.green), 2) +
                pow(Double(color.blue - centroid.blue), 2)
            }.min()!
            distances.append(minDistance)
        }
        
        let totalDistance = distances.reduce(0, +)
        let probabilities = distances.map { $0 / totalDistance }
        
        let cumulativeProbabilities = probabilities.reduce(into: [Double]()) { result, probability in
            result.append((result.last ?? 0) + probability)
        }
        
        let randomValue = Double.random(in: 0..<1)
        for (index, cumulativeProbability) in cumulativeProbabilities.enumerated() {
            if randomValue < cumulativeProbability {
                centroids.append(colors[index])
                break
            }
        }
    }
    
    return centroids
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
