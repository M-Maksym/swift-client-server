import SwiftUI
import Network

class MathServer: ObservableObject {
    let port: NWEndpoint.Port = 8080
    var listener: NWListener?
    var connections: [NWConnection] = []
    
    @Published var logs: [String] = []
    @Published var rectangleAreas: [Double] = []
    @Published var totalArea: Double = 0.0
    @Published var rectangles: [(width: Double, height: Double, area: Double)] = []
    
    // ... (all existing code remains exactly the same)
}

struct RectangleView: View {
    let width: Double
    let height: Double
    let area: Double
    let color: Color
    
    var body: some View {
        VStack {
            ZStack {
                Rectangle()
                    .fill(color)
                    .frame(width: min(width * 5, 200), height: min(height * 5, 200))
                    .border(Color.black, width: 1)
                
                Text("\(width) x \(height)")
                    .font(.caption)
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 1)
            }
            Text("Area: \(String(format: "%.1f", area)) sq.cm")
                .font(.caption)
        }
    }
}

struct ContentView: View {
    @StateObject var server = MathServer()
    
    // Colors for rectangles
    let colors: [Color] = [.blue, .green, .orange, .purple]
    
    var body: some View {
        VStack {
            Text("Math Server").font(.largeTitle).bold()
            
            Text("Rectangle areas, sq.cm")
                .font(.title2)
                .padding()
            
            HStack {
                ForEach(0..<min(4, server.rectangleAreas.count), id: \.self) { index in
                    VStack {
                        Text("Thread \(index + 1)")
                        Text(String(format: "%.1f", server.rectangleAreas[index]))
                            .frame(width: 60, alignment: .center)
                    }
                }
            }
            .padding()
            
            Text("Thread 5 Total area: \(String(format: "%.1f", server.totalArea)) sq.cm")
                .font(.title3)
                .padding()
            
            // Rectangle visualization
            if !server.rectangles.isEmpty {
                Text("Rectangle visualization:")
                    .font(.title3)
                    .padding(.top)
                
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 20) {
                        ForEach(0..<server.rectangles.count, id: \.self) { index in
                            let rect = server.rectangles[index]
                            RectangleView(
                                width: rect.width,
                                height: rect.height,
                                area: rect.area,
                                color: colors[index % colors.count]
                            )
                        }
                    }
                    .padding()
                }
                .frame(height: 250)
            }
            
            Text("Port: 8080")
            Text("Connections: \(server.connections.count)")
            
            List(server.logs, id: \.self) { log in
                Text(log)
            }
        }
        .padding()
    }
}
