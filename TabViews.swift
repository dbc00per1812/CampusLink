import SwiftUI

struct SearchView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Search")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Search for items on campus")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Search")
        }
    }
}

struct PostView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Create Listing")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Post items for sale")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Post")
        }
    }
}

struct PaymentsView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Payments")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Manage your transactions")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Payments")
        }
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView()
    }
}

struct PostView_Previews: PreviewProvider {
    static var previews: some View {
        PostView()
    }
}

struct PaymentsView_Previews: PreviewProvider {
    static var previews: some View {
        PaymentsView()
    }
} 