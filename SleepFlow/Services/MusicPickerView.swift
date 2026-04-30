import SwiftUI
import MediaPlayer

struct MusicPickerView: UIViewControllerRepresentable {
    var onPicked: ([MPMediaItem]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked)
    }

    func makeUIViewController(context: Context) -> MPMediaPickerController {
        let picker = MPMediaPickerController(mediaTypes: .anyAudio)
        picker.allowsPickingMultipleItems = true
        picker.showsCloudItems = false
        picker.prompt = "Elegí la música para dormir"
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: MPMediaPickerController, context: Context) {}

    final class Coordinator: NSObject, MPMediaPickerControllerDelegate {
        let onPicked: ([MPMediaItem]) -> Void
        init(onPicked: @escaping ([MPMediaItem]) -> Void) { self.onPicked = onPicked }

        func mediaPicker(_ mediaPicker: MPMediaPickerController,
                         didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
            mediaPicker.dismiss(animated: true)
            onPicked(mediaItemCollection.items)
        }

        func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
            mediaPicker.dismiss(animated: true)
            onPicked([])
        }
    }
}
