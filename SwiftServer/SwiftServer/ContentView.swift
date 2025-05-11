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
    
    init() {
        setupServer()
    }
    
    func setupServer() {
        do {
            listener = try NWListener(using: .tcp, on: port)
        } catch {
            logs.append("err: \(error.localizedDescription)")
            return
        }
        
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }
        
        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.logs.append("server started \(self?.port.rawValue ?? 0)")
            case .failed(let error):
                self?.logs.append("server err: \(error.localizedDescription)")
                self?.stopServer()
            case .cancelled:
                self?.logs.append("server stopped")
            default:
                break
            }
        }
        
        listener?.start(queue: .global())
    }
    
    func handleNewConnection(_ connection: NWConnection) {
        connections.append(connection)
        connection.start(queue: .global())
        DispatchQueue.main.async {
            self.logs.append("client connected: \(connection.endpoint)")
        }
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.receiveData(from: connection)
            case .failed(let error):
                self?.logs.append("connection failed: \(error.localizedDescription)")
                self?.removeConnection(connection)
            case .cancelled:
                self?.logs.append("client disconnected: \(connection.endpoint)")
                self?.removeConnection(connection)
            default:
                break
            }
        }
    }
    
    func receiveData(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.logs.append("error: \(error.localizedDescription)")
                }
                self.removeConnection(connection)
                return
            }
            
            if let data = data, !data.isEmpty, let request = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.logs.append("request: \(request)")
                }
                self.processRequest(request, from: connection)
            }
            
            if !isComplete {
                self.receiveData(from: connection)
            }
        }
    }
    
    func processRequest(_ request: String, from connection: NWConnection) {
        let components = request.split(separator: ",").map { String($0) }
        guard components.count % 2 == 0 else {
            DispatchQueue.main.async {
                self.logs.append("invalid request: \(request)")
            }
            return
        }
        
        var newRectangles: [(width: Double, height: Double)] = []
        for i in stride(from: 0, to: components.count, by: 2) {
            if let width = Double(components[i]), let height = Double(components[i+1]) {
                newRectangles.append((width: width, height: height))
            }
        }
        
        let group = DispatchGroup()
        var areas: [Double] = []
        var rectangleDetails: [(width: Double, height: Double, area: Double)] = []
        let queue = DispatchQueue(label: "com.areaCalculation", attributes: .concurrent)
        
        for (index, rect) in newRectangles.enumerated() {
            group.enter()
            DispatchQueue.global().async {
                let area = rect.width * rect.height
                
                queue.async(flags: .barrier) {
                    areas.append(area)
                    rectangleDetails.append((width: rect.width, height: rect.height, area: area))
                }
                
                DispatchQueue.main.async {
                    self.logs.append(">>> Thread \(index + 1): Start")
                }
                
                Thread.sleep(forTimeInterval: 2)
                
                DispatchQueue.main.async {
                    self.logs.append("<<< Thread \(index + 1): Stop")
                }
                
                group.leave()
            }
        }
        
        group.notify(queue: DispatchQueue.global()) {
            let totalArea = areas.reduce(0, +)
            let response = "\(totalArea)," + areas.map { String($0) }.joined(separator: ",")
            
            DispatchQueue.main.async {
                self.rectangleAreas = areas
                self.totalArea = totalArea
                self.rectangles = rectangleDetails
            }
            
            connection.send(content: response.data(using: .utf8), completion: .contentProcessed { [weak self] error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.logs.append("error: \(error.localizedDescription)")
                    }
                }
            })
        }
    }
    
    func removeConnection(_ connection: NWConnection) {
        connection.cancel()
        if let index = connections.firstIndex(where: { $0 === connection }) {
            connections.remove(at: index)
        }
    }
    
    func stopServer() {
        listener?.cancel()
        connections.forEach { $0.cancel() }
        connections.removeAll()
        DispatchQueue.main.async {
            self.logs.append("server stopped")
        }
    }
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
            Text("Area: \(String(format: "%.1f", area)) sq.sm")
                .font(.caption)
        }
    }
}

struct ContentView: View {
    @StateObject var server = MathServer()
    
    let colors: [Color] = [.blue, .green, .orange, .purple]
    
    var body: some View {
        VStack {
            Text("Math Server").font(.largeTitle).bold()
            
            Text("Rectangle areas")
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
            
            Text("Thread 5 Total area: \(String(format: "%.1f", server.totalArea)) sq.sm")
                .font(.title3)
                .padding()
            
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
