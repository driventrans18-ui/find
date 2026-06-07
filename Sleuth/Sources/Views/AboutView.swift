import SwiftUI

struct AboutView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Sleuth checks whether a **username** has a public profile on a list of supported sites — the same idea as the open-source Sherlock project, in a native iOS app.")
                }

                Section("How it works") {
                    Label("You type a username (a handle someone chose publicly).", systemImage: "at")
                    Label("Sleuth requests each site's public profile URL.", systemImage: "globe")
                    Label("A green result means that handle resolves to a live public page.", systemImage: "checkmark.seal")
                }

                Section("Please use this responsibly") {
                    Text("Sleuth only looks up usernames against public pages. It does **not** identify people from photos, scrape private data, or bypass logins. Don't use it to harass, stalk, or dox anyone. Respect each site's Terms of Service and the privacy of others.")
                        .font(.callout)
                }

                Section("Limitations") {
                    Text("Detection rules can break when sites change their pages, and rate-limiting or anti-bot measures may cause false negatives. Treat results as hints, not proof.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("About")
        }
    }
}
