// swift-tools-version: 6.0
import PackageDescription

let package = Package(
	name: "markdownRenderer",
	platforms: [.macOS(.v15)],
	products: [
		.library(name: "MarkdownRendererLib", targets: ["MarkdownRendererLib"]),
	],
	targets: [
		.target(
			name: "MarkdownRendererLib",
			path: "MarkdownRenderer",
			exclude: ["MarkdownRendererApp.swift", "Info.plist"]
		),
		.testTarget(
			name: "MarkdownRendererLibTests",
			dependencies: ["MarkdownRendererLib"]
		),
	]
)

