import SwiftUI
import Foundation

struct PieSliceView: View {
    let startAngle: Angle
    let endAngle: Angle
    let color: Color
    let center: CGPoint
    let radius: CGFloat
    let animationProgress: CGFloat
    
    var body: some View {
        Path { path in
            let actualEndAngle = Angle(degrees: startAngle.degrees + (endAngle.degrees - startAngle.degrees) * Double(animationProgress))
            
            path.move(to: center)
            path.addArc(
                center: center,
                radius: radius * 0.8,
                startAngle: startAngle,
                endAngle: actualEndAngle,
                clockwise: false
            )
            path.closeSubpath()
        }
        .fill(color)
    }
}
