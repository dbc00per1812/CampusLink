import SwiftUI

struct AuthView: View {
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack {
            Text("CampusLink")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 30)

            Picker("Authentication", selection: $isSignUp) {
                Text("Sign In").tag(false)
                Text("Sign Up").tag(true)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)

            Form {
                Section(header: Text(isSignUp ? "Create an account" : "Sign in to your account")) {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    SecureField("Password", text: $password)
                }
            }
            .frame(height: 180)


            Button(action: {
                // Auth logic will go here
            }) {
                Text(isSignUp ? "Sign Up" : "Sign In")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }
}


struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView()
    }
} 