//
//  Untitled.swift
//  MentalHealthTrack
//
//  Created by KAZ on 6/4/25.
//
import SwiftUI
import Foundation

struct PieChartView: View {
    let data: [AppUsageData]
    @State private var animationProgress: CGFloat = 0
    
    var totalTime: TimeInterval {
        data.reduce(0) { $0 + $1.totalTime }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Pie Chart
                GeometryReader { geometry in
                    let radius = min(geometry.size.width, geometry.size.height) / 2
                    let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    
                    ZStack {
                        ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                            PieSliceView(
                                startAngle: startAngle(for: index),
                                endAngle: endAngle(for: index),
                                color: item.color,
                                center: center,
                                radius: radius,
                                animationProgress: animationProgress
                            )
                        }
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                
                // Center text
                VStack {
                    Text("今日の使用時間")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatTime(totalTime))
                        .font(.headline)
                        .fontWeight(.bold)
                }
            }
            .frame(height: 200)
            
            // Legend
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(data.prefix(6)) { item in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 10, height: 10)
                        Text(item.appName)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(formatTime(item.totalTime))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                animationProgress = 1.0
            }
        }
    }
    
    private func startAngle(for index: Int) -> Angle {
        let previousItems = data.prefix(index)
        let previousTotal = previousItems.reduce(0) { $0 + $1.totalTime }
        return Angle(degrees: (previousTotal / totalTime) * 360 - 90)
    }
    
    private func endAngle(for index: Int) -> Angle {
        let itemsUpToIndex = data.prefix(index + 1)
        let totalUpToIndex = itemsUpToIndex.reduce(0) { $0 + $1.totalTime }
        return Angle(degrees: (totalUpToIndex / totalTime) * 360 - 90)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)時間\(minutes)分"
        } else {
            return "\(minutes)分"
        }
    }
}
