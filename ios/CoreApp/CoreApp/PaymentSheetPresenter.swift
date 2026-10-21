import SwiftUI
import StripePaymentSheet

/// Applies Stripe's `.paymentSheet` modifier unconditionally, from the
/// view's very first render — not only once PaymentService has a real
/// PaymentSheet. Stripe's modifier detects the true `isPresented`
/// transition to fire presentation; when it was attached for the first
/// time in the *same* render where `isPresented` already flipped to true
/// (the old conditional `if let sheet = ...` approach), there's no
/// false-to-true transition for it to observe, so nothing visibly opens
/// even though PaymentSheet itself finished initializing fine. Keeping the
/// modifier always mounted, backed by a harmless placeholder PaymentSheet
/// until a real one is built, avoids that.
struct PaymentSheetPresenter: ViewModifier {
    @ObservedObject var paymentService: PaymentService
    let onFinished: (Bool) -> Void

    func body(content: Content) -> some View {
        content.paymentSheet(isPresented: $paymentService.isPresenting, paymentSheet: paymentService.paymentSheet) { result in
            onFinished(paymentService.handleCompletion(result))
        }
    }
}
