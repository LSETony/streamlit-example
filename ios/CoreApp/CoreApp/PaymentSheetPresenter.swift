import SwiftUI
import StripePaymentSheet

/// Applies Stripe's `.paymentSheet` modifier once PaymentService has built a
/// PaymentSheet (its `paymentSheet` starts nil — the modifier needs a
/// concrete value, not an optional, so it's only attached once one exists).
/// Reports whether the payment actually succeeded via `onFinished`.
struct PaymentSheetPresenter: ViewModifier {
    @ObservedObject var paymentService: PaymentService
    let onFinished: (Bool) -> Void

    func body(content: Content) -> some View {
        if let sheet = paymentService.paymentSheet {
            content.paymentSheet(isPresented: $paymentService.isPresenting, paymentSheet: sheet) { result in
                onFinished(paymentService.handleCompletion(result))
            }
        } else {
            content
        }
    }
}
