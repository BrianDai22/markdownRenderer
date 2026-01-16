import Darwin
import Foundation

final class FileSystemWatcher {
	private var source: DispatchSourceFileSystemObject?
	private var fileDescriptor: CInt = -1

	private let url: URL
	private let handler: @MainActor () -> Void

	init(url: URL, handler: @escaping @MainActor () -> Void) {
		self.url = url
		self.handler = handler
	}

	func start() {
		stop()

		guard url.isFileURL else { return }

		fileDescriptor = open(url.path, O_EVTONLY)
		guard fileDescriptor >= 0 else { return }

		let queue = DispatchQueue(label: "markdownrenderer.fswatch.\(UUID().uuidString)", qos: .utility)
		let mask: DispatchSource.FileSystemEvent = [.write, .delete, .rename, .attrib, .extend]
		let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: mask, queue: queue)
		let handler = self.handler

		source.setEventHandler {
			DispatchQueue.main.async {
				handler()
			}
		}

		source.setCancelHandler { [fileDescriptor] in
			if fileDescriptor >= 0 {
				close(fileDescriptor)
			}
		}

		self.source = source
		source.resume()
	}

	func stop() {
		source?.cancel()
		source = nil
		fileDescriptor = -1
	}

	deinit {
		stop()
	}
}
