# Rectangle Area Calculator (Client-Server)

A Swift implementation of a TCP client-server system for calculating rectangle areas.

## Features
- **Server**: Processes rectangle dimensions and returns calculated areas
- **Client**: Sends requests and visualizes results
- Multi-threaded server-side processing
- Real-time connection status monitoring

## Requirements
- Xcode 13+
- macOS 12+ (for Network framework)
- Swift 5.5+

## Setup

### Server
1. Open project in Xcode
2. Run the `MathServer` target
3. Server starts on port `8080` (default)

### Client
1. Open project in Xcode
2. Run the `MathClient` target
3. Configure connection:
   - Host: `127.0.0.1` (for local testing)
   - Port: `8080`

## Usage Example
1. In client app, enter rectangle dimensions (width,height):
  10,20
  5,5
  15,30
2. Click "Calculate"
3. Server returns:
- Individual rectangle areas
- Total combined area

**Testing Connectivity**
nc -zv 127.0.0.1 8080

### Troubleshooting

**- Connection refused**: Ensure server is running before starting client

**- No response**: Verify firewall isn't blocking the port

**- Invalid data**: Use comma-separated values (width,height)


<img width="901" alt="Screenshot 2025-05-11 at 16 02 19" src="https://github.com/user-attachments/assets/620db3b1-a8e7-4062-b2d8-b410007a5422" />
<img width="895" alt="Screenshot 2025-05-11 at 15 55 30" src="https://github.com/user-attachments/assets/1d41202d-c81a-4cda-a9b2-34cbfbac5e5c" />
<img width="1721" alt="Screenshot 2025-05-11 at 16 19 48" src="https://github.com/user-attachments/assets/ef7238ce-12aa-4d40-b9c9-c59546f40c22" />
