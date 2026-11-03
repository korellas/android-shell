// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import CryptoKit
import Flutter
import Security
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    private var platform: IosPlatform?

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        platform = IosPlatform(messenger: engineBridge.applicationRegistrar.messenger())
    }
}

private final class IosPlatform: NSObject, UIDocumentPickerDelegate {
    private let channel: FlutterMethodChannel
    private let queue = DispatchQueue(label: "dev.korellas.tilde.storage")
    private var pickerResult: FlutterResult?
    private var exportURL: URL?

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "dev.korellas.tilde/ios", binaryMessenger: messenger)
        super.init()
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    private func background(_ result: @escaping FlutterResult, _ work: @escaping () throws -> Any?) {
        queue.async {
            do {
                let value = try work()
                DispatchQueue.main.async { result(value) }
            } catch {
                let failure = FlutterError(code: "ios_platform", message: error.localizedDescription, details: nil)
                DispatchQueue.main.async { result(failure) }
            }
        }
    }

    private func storageDirectory() throws -> URL {
        let root = try FileManager.default.url(for: .applicationSupportDirectory,
                                              in: .userDomainMask, appropriateFor: nil, create: true)
        var directory = root.appendingPathComponent("Tilde", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.protectionKey: FileProtectionType.complete])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        return directory
    }

    private func storageKey(create: Bool) throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\(Bundle.main.bundleIdentifier!).storage",
            kSecAttrAccount as String: "state-key",
        ]
        var search = query
        search[kSecReturnData as String] = true
        var value: CFTypeRef?
        let status = SecItemCopyMatching(search as CFDictionary, &value)
        if status == errSecSuccess, let bytes = value as? Data {
            return SymmetricKey(data: bytes)
        }
        guard status == errSecItemNotFound && create else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
        let key = SymmetricKey(size: .bits256)
        var item = query
        item[kSecValueData as String] = key.withUnsafeBytes { Data($0) }
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let added = SecItemAdd(item as CFDictionary, nil)
        guard added == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(added))
        }
        return key
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "storageDirectory":
            background(result) { try self.storageDirectory().path }
        case "protect", "unprotect":
            guard let bytes = args["bytes"] as? FlutterStandardTypedData else {
                result(FlutterError(code: "invalid_bytes", message: "인증정보 형식이 올바르지 않습니다.", details: nil))
                return
            }
            background(result) {
                let encrypt = call.method == "protect"
                let key = try self.storageKey(create: encrypt)
                let data: Data
                if encrypt {
                    data = try AES.GCM.seal(bytes.data, using: key).combined!
                } else {
                    data = try AES.GCM.open(AES.GCM.SealedBox(combined: bytes.data), using: key)
                }
                return FlutterStandardTypedData(bytes: data)
            }
        case "openUrl":
            guard let text = args["url"] as? String, let url = URL(string: text),
                  ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") else {
                result(FlutterError(code: "invalid_url", message: "지원하지 않는 링크입니다.", details: nil))
                return
            }
            UIApplication.shared.open(url, options: [:]) { opened in
                result(opened ? nil : FlutterError(code: "open_url", message: "링크를 열 수 없습니다.", details: nil))
            }
        case "openFile":
            present(UIDocumentPickerViewController(documentTypes: ["public.data"], in: .import), result: result)
        case "saveFile":
            background(result) {
                let folder = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString, isDirectory: true)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let name = URL(fileURLWithPath: args["name"] as? String ?? "Tilde.txt").lastPathComponent
                return folder.appendingPathComponent(name).path
            }
        case "exportFile":
            guard let path = args["path"] as? String else {
                result(FlutterError(code: "invalid_path", message: "내보낼 파일이 없습니다.", details: nil))
                return
            }
            let url = URL(fileURLWithPath: path)
            present(UIDocumentPickerViewController(url: url, in: .exportToService),
                    export: url, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func present(_ picker: UIDocumentPickerViewController, export: URL? = nil,
                         result: @escaping FlutterResult) {
        guard pickerResult == nil else {
            result(FlutterError(code: "picker_busy", message: "열려 있는 파일 선택 창을 먼저 닫으세요.", details: nil))
            return
        }
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }),
              var controller = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            result(FlutterError(code: "no_window", message: "파일 선택 창을 열 수 없습니다.", details: nil))
            return
        }
        while let presented = controller.presentedViewController { controller = presented }
        pickerResult = result
        exportURL = export
        picker.delegate = self
        picker.allowsMultipleSelection = false
        controller.present(picker, animated: true)
    }

    private func finishPicker(_ value: Any?) {
        let result = pickerResult
        pickerResult = nil
        exportURL = nil
        result?(value)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        finishPicker(nil)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if exportURL != nil {
            finishPicker(nil)
            return
        }
        guard let source = urls.first else { finishPicker(nil); return }
        background({ value in self.finishPicker(value) }) {
            let accessed = source.startAccessingSecurityScopedResource()
            defer { if accessed { source.stopAccessingSecurityScopedResource() } }
            let folder = try self.storageDirectory().appendingPathComponent("Imports", isDirectory: true)
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
                                                    attributes: [.protectionKey: FileProtectionType.complete])
            let destination = folder.appendingPathComponent(source.lastPathComponent)
            try FileManager.default.copyItem(at: source, to: destination)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete],
                                                  ofItemAtPath: destination.path)
            return destination.path
        }
    }
}
