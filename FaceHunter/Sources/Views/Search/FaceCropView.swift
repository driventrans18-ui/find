import SwiftUI
import UIKit

struct FaceCropView: View {
    let imageData: Data

    var body: some View {
        if let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                        .stroke(Color.red.opacity(0.7), lineWidth: 2)
                )
                .shadow(color: .red.opacity(0.3), radius: 8)
        }
    }
}
