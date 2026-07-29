import SwiftUI

struct FormicMarkView: View {
    var color: Color = .white

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let origin = CGPoint(
                x: (size.width - side) / 2,
                y: (size.height - side) / 2
            )

            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: origin.x + (x * side), y: origin.y + (y * side))
            }

            func polygon(_ coordinates: [(CGFloat, CGFloat)]) -> Path {
                var path = Path()
                guard let first = coordinates.first else { return path }
                path.move(to: point(first.0, first.1))

                for coordinate in coordinates.dropFirst() {
                    path.addLine(to: point(coordinate.0, coordinate.1))
                }

                path.closeSubpath()
                return path
            }

            func polyline(_ coordinates: [(CGFloat, CGFloat)]) -> Path {
                var path = Path()
                guard let first = coordinates.first else { return path }
                path.move(to: point(first.0, first.1))

                for coordinate in coordinates.dropFirst() {
                    path.addLine(to: point(coordinate.0, coordinate.1))
                }

                return path
            }

            let strokeStyle = StrokeStyle(
                lineWidth: max(1, side * 0.045),
                lineCap: .square,
                lineJoin: .miter
            )

            let limbs: [[(CGFloat, CGFloat)]] = [
                [(0.43, 0.22), (0.36, 0.11), (0.24, 0.04)],
                [(0.57, 0.22), (0.64, 0.11), (0.76, 0.04)],
                [(0.38, 0.43), (0.23, 0.35), (0.11, 0.24)],
                [(0.62, 0.43), (0.77, 0.35), (0.89, 0.24)],
                [(0.37, 0.55), (0.22, 0.55), (0.10, 0.48)],
                [(0.63, 0.55), (0.78, 0.55), (0.90, 0.48)],
                [(0.40, 0.67), (0.25, 0.76), (0.14, 0.89)],
                [(0.60, 0.67), (0.75, 0.76), (0.86, 0.89)]
            ]

            for limb in limbs {
                context.stroke(polyline(limb), with: .color(color), style: strokeStyle)
            }

            let head = polygon([
                (0.43, 0.20), (0.57, 0.20), (0.63, 0.29),
                (0.57, 0.38), (0.43, 0.38), (0.37, 0.29)
            ])
            let thorax = polygon([
                (0.42, 0.40), (0.58, 0.40), (0.64, 0.52),
                (0.58, 0.64), (0.42, 0.64), (0.36, 0.52)
            ])
            let abdomen = polygon([
                (0.42, 0.66), (0.58, 0.66), (0.69, 0.75),
                (0.69, 0.82), (0.60, 0.82), (0.60, 0.91),
                (0.50, 0.97), (0.34, 0.83), (0.34, 0.75)
            ])
            let foldedCorner = polygon([
                (0.61, 0.84), (0.69, 0.84), (0.61, 0.91)
            ])

            context.fill(head, with: .color(color))
            context.fill(thorax, with: .color(color))
            context.fill(abdomen, with: .color(color))
            context.fill(foldedCorner, with: .color(color))
        }
        .accessibilityHidden(true)
    }
}
