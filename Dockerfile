
FROM ibmcom/swift-ubuntu:latest

COPY . .

# Build App
RUN swift build -c release
RUN swift test
