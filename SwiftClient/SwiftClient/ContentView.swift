import SwiftUI
import Network

class TCPClient: ObservableObject {
    @Published var response: String = ">>> Not connected"
    @Published var isConnected = false
    @Published var totalArea: String = ""
    @Published var rectangleAreas: [String] = []

    private var connection: NWConnection?

    func connectToServer(host: String, port: String) {
        guard let portValue = UInt16(port) else { return }

        connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: portValue)!, using: .tcp)

        connection?.stateUpdateHandler = { [weak self] newState in
            DispatchQueue.main.async {
                switch newState {
                case .ready:
                    self?.isConnected = true
                    self?.response = ">>> Connected to \(host):\(port)"
                    print("TCPClient: Підключено до \(host):\(port)") // Лог
                case .failed(let error):
                    self?.response = ">>> Connection error: \(error.localizedDescription)"
                    self?.isConnected = false
                    print("TCPClient: Помилка підключення: \(error.localizedDescription)") // Лог
                default:
                    break
                }
            }
        }

        connection?.start(queue: .global())
    }

    func disconnectFromServer() {
        connection?.cancel()
        connection = nil
        isConnected = false
        response = ">>> Not connected"
        print("TCPClient: Відключено") // Лог
    }

    func sendRequest(rectangles: [String]) {
        guard let connection = connection, isConnected else {
            response = ">>> Not connected"
            print("TCPClient: Не підключено, неможливо відправити запит") // Лог
            return
        }

        if rectangles.isEmpty {
            DispatchQueue.main.async {
                self.response = ">>> No rectangles selected"
                print("TCPClient: Не вибрано жодного прямокутника") // Лог
            }
            return
        }

        let requestString = rectangles.joined(separator: ",")
        let requestData = requestString.data(using: .utf8)

        print("TCPClient: Відправлення запиту: \(requestString)") // Лог

        connection.send(content: requestData, completion: .contentProcessed({ error in
            if let error = error {
                DispatchQueue.main.async {
                    self.response = ">>> Send error: \(error.localizedDescription)"
                    print("TCPClient: Помилка відправлення: \(error.localizedDescription)") // Лог
                }
                return
            }
            print("TCPClient: Запит успішно відправлено") // Лог
            self.receiveResponse()
        }))
    }

    private func receiveResponse() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 1024) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let data = data, let result = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    let results = result.components(separatedBy: ",")
                    if results.count > 1 {
                        self.totalArea = results[0]
                        self.rectangleAreas = Array(results[1...])
                        self.response = ">>> Received response: \(result)"
                        print("TCPClient: Отримано відповідь: \(result)") // Лог
                    }
                }
            } else if let error = error {
                DispatchQueue.main.async {
                    self.response = ">>> Receive error: \(error.localizedDescription)"
                    print("TCPClient: Помилка отримання: \(error.localizedDescription)") // Лог
                }
            }

            if !isComplete {
                self.receiveResponse()
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var client = TCPClient()

    @State private var port: String = "8080"
    @State private var host: String = "127.0.0.1"
    @State private var rectangleDimensions: [String] = ["", "", "", ""]
    @State private var switches: [Bool] = [false, false, false, false]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Client").bold().foregroundColor(.blue)

            Text(client.response)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .border(Color.gray)

            HStack {
                VStack(alignment: .leading) {
                    Text("Port")
                    TextField("8080", text: $port)
                        .textFieldStyle(.roundedBorder)
                    Text("Host")
                    TextField("127.0.0.1", text: $host)
                        .textFieldStyle(.roundedBorder)
                }
                VStack {
                    Button("Connect") {
                        client.connectToServer(host: host, port: port)
                    }
                    .disabled(client.isConnected)
                    .padding()
                    .background(Color.gray.opacity(client.isConnected ? 0.5 : 1))
                    .cornerRadius(5)
                    .foregroundColor(.white)

                    Button("Disconnect") {
                        client.disconnectFromServer()
                    }
                    .padding()
                    .background(Color.red)
                    .cornerRadius(5)
                    .foregroundColor(.white)
                }
            }

            Text("Total area, sq.cm:")
            Text(client.totalArea)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .border(Color.gray)

            Text("Rectangle areas, sq.cm:")
            ForEach(0..<4) { index in
                Text(client.rectangleAreas.count > index ? client.rectangleAreas[index] : "")
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .border(Color.gray)
            }

            ForEach(0..<4, id: \.self) { index in
                HStack {
                    TextField("Rectangle \(index + 1) dimensions (width,height)", text: $rectangleDimensions[index])
                        .textFieldStyle(.roundedBorder)
                    Toggle("", isOn: $switches[index])
                }
            }

            Button("Calculate") {
                var activeRectangles: [String] = []
                
                for (index, dimensions) in rectangleDimensions.enumerated() {
                    if !dimensions.isEmpty && switches[index] {
                        activeRectangles.append(dimensions)
                    }
                }
                
                client.sendRequest(rectangles: activeRectangles)
            }
            .padding()
            .background(Color.orange)
            .cornerRadius(5)
            .foregroundColor(.white)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
