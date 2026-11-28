import SwiftUI
import Supabase

/// The sheet behind "Continue with email": the user types an address, gets a
/// one-time code by mail and types it in. Supabase checks the code and opens
/// the session; `AuthViewModel` hears about it and shows the app, as for
/// Apple and Google. A new address becomes a new account.
struct EmailSignInView: View {
  private enum Field: Hashable {
    case email
    case code
  }

  @Environment(\.dismiss) private var dismiss
  @State private var email = ""
  @State private var code = ""
  /// The address the code was sent to; nil while the address is being typed.
  @State private var sentToEmail: String?
  @State private var lastSentAt: Date?
  @State private var isWorking = false
  @State private var message = ""
  @FocusState private var focusedField: Field?

  var body: some View {
    NavigationStack {
      ZStack {
        AeroBackground()

        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            if let sentToEmail {
              codeStep(sentTo: sentToEmail)
            } else {
              emailStep
            }

            if !message.isEmpty {
              Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
          .padding(20)
        }
      }
      .navigationTitle("Sign in with email")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
            .buttonStyle(.plain)
        }
      }
    }
    .onAppear {
      focusedField = .email
    }
  }

  private var emailStep: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("We send a one-time code to your email address. No password needed.")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      TextField("Email address", text: $email)
        .keyboardType(.emailAddress)
        .textContentType(.emailAddress)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .submitLabel(.send)
        .focused($focusedField, equals: .email)
        .onSubmit {
          Task { await sendCode() }
        }
        .padding(12)
        .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

      Button(isWorking ? "Sending..." : "Send code") {
        Task { await sendCode() }
      }
      .buttonStyle(AeroGlossButtonStyle())
      .disabled(isWorking || !EmailSignIn.isPlausibleEmail(email))
    }
    .padding(16)
    .aeroCard()
  }

  private func codeStep(sentTo sentToEmail: String) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Enter the code we sent to \(sentToEmail). It can take a minute to arrive; look in the spam folder too.")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      TextField("Code", text: $code)
        .keyboardType(.numberPad)
        .textContentType(.oneTimeCode)
        .font(.title2.monospacedDigit())
        .focused($focusedField, equals: .code)
        .onChange(of: code) { _, typed in
          let cleaned = EmailSignIn.cleanedCode(typed)
          if cleaned != typed {
            code = cleaned
          }
        }
        .padding(12)
        .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

      Button(isWorking ? "Signing in..." : "Sign in") {
        Task { await verifyCode(sentTo: sentToEmail) }
      }
      .buttonStyle(AeroGlossButtonStyle())
      .disabled(isWorking || !EmailSignIn.isCompleteCode(code))

      // Redrawn every second, so the wait counts down.
      TimelineView(.periodic(from: .now, by: 1)) { context in
        let wait = EmailSignIn.secondsUntilResend(lastSentAt: lastSentAt, now: context.date)
        Button(wait > 0 ? "Send again in \(wait) s" : "Send again") {
          Task { await sendCode() }
        }
        .buttonStyle(.plain)
        .font(.footnote.weight(.semibold))
        .foregroundStyle(wait > 0 || isWorking ? Color.secondary : AeroTheme.aqua)
        .disabled(isWorking || wait > 0)
      }

      Button("Use another address") {
        useAnotherAddress()
      }
      .buttonStyle(.plain)
      .font(.footnote.weight(.semibold))
      .foregroundStyle(isWorking ? Color.secondary : AeroTheme.aqua)
      .disabled(isWorking)
    }
    .padding(16)
    .aeroCard()
  }

  @MainActor
  private func sendCode() async {
    // While a code is waiting to be typed, "Send again" goes to that address.
    let address = sentToEmail ?? EmailSignIn.cleanedEmail(email)
    guard !isWorking, EmailSignIn.isPlausibleEmail(address) else { return }
    guard EmailSignIn.secondsUntilResend(lastSentAt: lastSentAt, now: Date()) == 0 || sentToEmail == nil else {
      return
    }

    isWorking = true
    message = ""
    defer { isWorking = false }

    do {
      try await supabase.auth.signInWithOTP(email: address)
      let isResend = sentToEmail != nil
      sentToEmail = address
      lastSentAt = Date()
      code = ""
      focusedField = .code
      if isResend {
        message = "A new code is on its way. The earlier one no longer works."
      }
    } catch {
      message = UserFacingError.message(couldNot: "send the code", error: error)
    }
  }

  @MainActor
  private func verifyCode(sentTo address: String) async {
    let token = EmailSignIn.cleanedCode(code)
    guard !isWorking, EmailSignIn.isCompleteCode(token) else { return }

    isWorking = true
    message = ""
    defer { isWorking = false }

    do {
      _ = try await supabase.auth.verifyOTP(email: address, token: token, type: .email)
      dismiss()
    } catch let error as URLError {
      message = UserFacingError.message(couldNot: "sign in", error: error)
    } catch {
      // The server answered and said no: nearly always a mistyped code or one
      // that is more than an hour old.
      message = "That code didn't work. Check it, or ask for a new one."
    }
  }

  private func useAnotherAddress() {
    sentToEmail = nil
    code = ""
    message = ""
    focusedField = .email
  }
}
