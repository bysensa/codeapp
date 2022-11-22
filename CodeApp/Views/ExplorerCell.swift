//
//  FileFolderCell.swift
//  Code
//
//  Created by Ken Chung on 24/4/2022.
//

import SwiftUI
import UniformTypeIdentifiers

struct ExplorerCell: View {
    @EnvironmentObject var App: MainApp

    let item: WorkSpaceStorage.FileItemRepresentable
    let onDrag: () -> NSItemProvider
    let onDropToFolder: ([NSItemProvider]) -> Bool

    var body: some View {
        if item.subFolderItems != nil {
            FolderCell(item: item)
                .frame(height: 16)
                .onDrag(onDrag)
                .onDrop(
                    of: [.folder, .item], isTargeted: nil,
                    perform: onDropToFolder)
        } else {
            FileCell(item: item)
                .frame(height: 16)
                .onDrag(onDrag)
        }
    }
}

private struct FileCell: View {

    @EnvironmentObject var App: MainApp
    @State var item: WorkSpaceStorage.FileItemRepresentable
    @State var newname = ""
    @State var showsDirectoryPicker = false
    @FocusState var focusedField: Field?
    @State var isRenaming: Bool = false

    init(item: WorkSpaceStorage.FileItemRepresentable) {
        self._item = State.init(initialValue: item)
        self._newname = State.init(initialValue: item.name.removingPercentEncoding!)
    }

    enum Field {
        case rename
    }

    func onRename() {
        App.renameFile(url: URL(string: item.url)!, name: newname)
        focusedField = nil
    }

    func onOpenEditor() {
        guard let url = item._url else { return }
        Task {
            do {
                _ = try await App.openFile(url: url)
            } catch {
                App.notificationManager.showErrorMessage(error.localizedDescription)
            }
        }
    }

    func onCopyItemToFolder(url: URL) {
        guard let itemURL = URL(string: item.url) else {
            return
        }
        App.workSpaceStorage.copyItem(
            at: itemURL, to: url.appendingPathComponent(itemURL.lastPathComponent),
            completionHandler: { error in
                if let error = error {
                    App.notificationManager.showErrorMessage(error.localizedDescription)
                }
            })
    }

    var body: some View {
        Button(action: onOpenEditor) {
            HStack {
                FileIcon(url: newname, iconSize: 14, type: .file)
                    .frame(width: 14, height: 14)

                if isRenaming {
                    HStack {
                        TextField(
                            item.name.removingPercentEncoding!, text: $newname,
                            onCommit: onRename
                        )
                        .focused($focusedField, equals: .rename)
                        .font(.subheadline)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                        Spacer()
                        Image(systemName: "multiply.circle.fill")
                            .foregroundColor(.gray)
                            .padding(.trailing, 8)
                            .highPriorityGesture(
                                TapGesture()
                                    .onEnded({ self.newname = "" })
                            )
                    }
                } else {
                    if let status = App.gitTracks[URL(string: item.url)!.standardizedFileURL] {
                        FileDisplayName(
                            gitStatus: status, name: item.name.removingPercentEncoding!)
                    } else {
                        FileDisplayName(
                            gitStatus: nil, name: item.name.removingPercentEncoding!)
                    }
                    Spacer()
                }

            }
            .padding(5)
            .sheet(isPresented: $showsDirectoryPicker) {
                DirectoryPickerView(onOpen: onCopyItemToFolder)
            }
            .contextMenu {
                ContextMenu(
                    item: item,
                    onRename: {
                        isRenaming = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            focusedField = .rename
                        }
                    },
                    onCreateNewFile: {},
                    onCopyFile: { showsDirectoryPicker.toggle() }
                )
            }
            .onReceive(
                NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            ) { _ in
                isRenaming = false
                newname = item.name.removingPercentEncoding!
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UITextField.textDidBeginEditingNotification)
            ) { obj in
                if let textField = obj.object as? UITextField {
                    textField.selectedTextRange = textField.textRange(
                        from: textField.beginningOfDocument, to: textField.endOfDocument
                    )
                }
            }
        }
    }
}

private struct FolderCell: View {

    @EnvironmentObject var App: MainApp
    @State var item: WorkSpaceStorage.FileItemRepresentable
    @State var showingNewFileSheet = false
    @State var showsDirectoryPicker = false
    @State var newname = ""
    @FocusState var focusedField: Field?
    @State var isRenaming: Bool = false

    enum Field {
        case rename
    }

    init(item: WorkSpaceStorage.FileItemRepresentable) {
        self._item = State.init(initialValue: item)
        self._newname = State.init(initialValue: item.name.removingPercentEncoding!)
    }

    func onRename() {
        App.renameFile(url: URL(string: item.url)!, name: newname)
        focusedField = nil
    }

    var body: some View {
        HStack {
            Image(systemName: "folder")
                .foregroundColor(.gray)
                .font(.system(size: 14))
                .frame(width: 14, height: 14)
            Spacer().frame(width: 10)

            if isRenaming {
                HStack {
                    TextField(
                        item.name.removingPercentEncoding!, text: $newname,
                        onCommit: onRename
                    )
                    .focused($focusedField, equals: .rename)
                    .font(.subheadline)
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                    .onReceive(
                        NotificationCenter.default.publisher(
                            for: UITextField.textDidBeginEditingNotification)
                    ) { obj in
                        if let textField = obj.object as? UITextField {
                            textField.selectedTextRange = textField.textRange(
                                from: textField.beginningOfDocument, to: textField.endOfDocument)
                        }
                    }
                    Spacer()
                    Image(systemName: "multiply.circle.fill")
                        .foregroundColor(.gray)
                        .padding(.trailing, 8)
                        .highPriorityGesture(
                            TapGesture()
                                .onEnded({ self.newname = "" })
                        )
                }
            } else {
                if let status = App.gitTracks[URL(string: item.url)!.standardizedFileURL] {
                    FileDisplayName(
                        gitStatus: status, name: item.name.removingPercentEncoding!)
                } else {
                    FileDisplayName(
                        gitStatus: nil, name: item.name.removingPercentEncoding!)
                }
                Spacer()
            }

        }
        .padding(5)
        .sheet(isPresented: $showingNewFileSheet) {
            NewFileView(targetUrl: item.url).environmentObject(App)
        }
        .sheet(isPresented: $showsDirectoryPicker) {
            DirectoryPickerView(onOpen: { url in
                guard let itemURL = URL(string: item.url) else {
                    return
                }
                App.workSpaceStorage.copyItem(
                    at: itemURL, to: url.appendingPathComponent(itemURL.lastPathComponent),
                    completionHandler: { error in
                        if let error = error {
                            App.notificationManager.showErrorMessage(error.localizedDescription)
                        }
                    })
            })
        }
        .contextMenu {
            ContextMenu(
                item: item,
                onRename: {
                    isRenaming = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        focusedField = .rename
                    }
                },
                onCreateNewFile: {
                    showingNewFileSheet.toggle()
                },
                onCopyFile: {
                    showsDirectoryPicker.toggle()
                })
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
        ) { _ in
            isRenaming = false
            newname = item.name.removingPercentEncoding!
        }
    }
}

private struct ContextMenu: View {

    @EnvironmentObject var App: MainApp

    let item: WorkSpaceStorage.FileItemRepresentable

    let onRename: () -> Void
    let onCreateNewFile: () -> Void
    let onCopyFile: () -> Void

    var body: some View {
        Group {

            if item.subFolderItems == nil {
                Button(action: {
                    if let url = item._url {
                        App.openFile(url: url, alwaysInNewTab: true)
                    }
                }) {
                    Text("Open in Tab")
                    Image(systemName: "doc.plaintext")
                }
            }

            Button(action: {
                openSharedFilesApp(
                    urlString: URL(string: item.url)!.deletingLastPathComponent()
                        .absoluteString
                )
            }) {
                Text("Show in Files App")
                Image(systemName: "folder")
            }

            Group {
                Button(action: {
                    onRename()
                }) {
                    Text("Rename")
                    Image(systemName: "pencil")
                }

                Button(action: {
                    App.duplicateItem(from: URL(string: item.url)!)
                }) {
                    Text("Duplicate")
                    Image(systemName: "plus.square.on.square")
                }

                Button(action: {
                    App.trashItem(url: URL(string: item.url)!)
                }) {
                    Text("Delete").foregroundColor(.red)
                    Image(systemName: "trash").foregroundColor(.red)
                }

                Button(action: {
                    onCopyFile()
                }) {
                    Label(
                        item.url.hasPrefix("file") ? "file.copy" : "file.download",
                        systemImage: "folder")
                }
            }

            Divider()

            Button(action: {
                let pasteboard = UIPasteboard.general
                guard let targetURL = URL(string: item.url),
                    let baseURL = (App.activeEditor as? EditorInstanceWithURL)?.url
                else {
                    return
                }
                pasteboard.string = targetURL.relativePath(from: baseURL)
            }) {
                Text("Copy Relative Path")
                Image(systemName: "link")
            }

            if item.subFolderItems != nil {
                Button(action: {
                    onCreateNewFile()
                }) {
                    Text("New File")
                    Image(systemName: "doc.badge.plus")
                }

                Button(action: {
                    App.createFolder(urlString: item.url)
                }) {
                    Text("New Folder")
                    Image(systemName: "folder.badge.plus")
                }

                Button(action: {
                    App.loadFolder(url: URL(string: item.url)!)
                }) {
                    Text("Assign as workplace folder")
                    Image(systemName: "folder.badge.gear")
                }
            }

            if item.subFolderItems == nil {
                Button(action: {
                    App.selectedForCompare = item.url
                }) {
                    Text("Select for compare")
                    Image(systemName: "square.split.2x1")
                }

                if App.selectedForCompare != "" && App.selectedForCompare != item.url {
                    Button(action: {
                        App.compareWithSelected(url: item.url)
                    }) {
                        Text("Compare with selected")
                        Image(systemName: "square.split.2x1")
                    }
                }
            }
        }
    }
}
