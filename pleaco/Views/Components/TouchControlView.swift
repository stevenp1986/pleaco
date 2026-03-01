import SwiftUI

struct TouchControlView: View {
    @ObservedObject var deviceManager = DeviceManager.shared
    @State private var intensity: Double = 0
    @State private var isTouching = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Manual Intensity", icon: "bolt.fill")
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background Bar
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.surfaceSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                        )
                    
                    // Progress Fill (Gradient)
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color.appAccent.opacity(0.3), Color.appAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, CGFloat(intensity / 100.0) * geometry.size.width))
                        .shadow(color: Color.appAccent.opacity(isTouching ? 0.5 : 0), radius: 10)
                    
                    // Intensity Label & Percentage
                    HStack {
                        Text("DRAG TO ACTIVATE")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(isTouching ? 0.8 : 0.2))
                            .padding(.leading, 20)
                        
                        Spacer()
                        
                        Text("\(Int(intensity))%")
                            .font(.system(size: 20, weight: .black).monospacedDigit())
                            .foregroundColor(.white)
                            .padding(.trailing, 20)
                            .opacity(isTouching ? 1 : 0.3)
                    }
                    
                    // Glossy Overlay
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.05), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .contentShape(RoundedRectangle(cornerRadius: 16))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isTouching = true
                            let normalizedX = value.location.x / geometry.size.width
                            intensity = min(100, max(0, normalizedX * 100))
                            deviceManager.applyManualControl()
                            deviceManager.sendLevel(intensity)
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isTouching = false
                                intensity = 0
                                deviceManager.sendLevel(0)
                            }
                        }
                )
            }
            .frame(height: 80)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
