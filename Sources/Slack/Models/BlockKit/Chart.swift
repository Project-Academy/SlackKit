//
//  Chart.swift
//  SlackKit
//
//  The `data_visualization` block family — pie, bar, area and line charts.
//
//  Spec: docs/systems/comms/blockkit-spec-2026-08.md §1 `data_visualization`.
//  Limits: max 2 data_visualization blocks per message; 1–12 segments/series;
//  1–20 points per series; labels max 20 chars; title max 50.
//

import Foundation

extension Block {

    /**
     Payload of a `data_visualization` block: a required `title` (raw
     String, max 50) plus the `chart` object.
     */
    public struct DataVisualization: Codable, Equatable, Sendable {
        public var title: String
        public var chart: Chart

        public init(title: String, chart: Chart) {
            self.title = title
            self.chart = chart
        }

        private enum CodingKeys: String, CodingKey {
            case title, chart
        }
    }

    /**
     The chart inside a `data_visualization` block. The wire `type`
     (`pie` / `bar` / `area` / `line`) is owned by this enum's encode;
     chart kinds this kit doesn't know round-trip via ``unknown(type:raw:)``.

     Slack validates at runtime: every point label must match an
     `axis_config` category, series may not omit points, series names are
     unique, and category order is display order.
     */
    public enum Chart: Codable, Equatable, Sendable {

        /// 1–12 segments; rendered percentage is `value / sum`.
        case pie(segments: [Segment])
        /// 1–12 series; multiple series group bars by label.
        case bar(series: [Series], axis: AxisConfig)
        /// 1–12 series; layered in array order, first at the back.
        case area(series: [Series], axis: AxisConfig)
        /// 1–12 series.
        case line(series: [Series], axis: AxisConfig)
        case unknown(type: String, raw: [String: JSONValue])

        private enum CodingKeys: String, CodingKey {
            case type, segments, series, axis_config
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let type = try c.decode(String.self, forKey: .type)
            switch type {
            case "pie":
                self = .pie(segments: try c.decode([Segment].self, forKey: .segments))
            case "bar":
                self = .bar(series: try c.decode([Series].self, forKey: .series),
                            axis: try c.decode(AxisConfig.self, forKey: .axis_config))
            case "area":
                self = .area(series: try c.decode([Series].self, forKey: .series),
                             axis: try c.decode(AxisConfig.self, forKey: .axis_config))
            case "line":
                self = .line(series: try c.decode([Series].self, forKey: .series),
                             axis: try c.decode(AxisConfig.self, forKey: .axis_config))
            default:
                let raw = try JSONValue(from: decoder)
                self = .unknown(type: type, raw: raw.objectDropping(["type"]))
            }
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case let .pie(segments):
                try c.encode("pie", forKey: .type)
                try c.encode(segments, forKey: .segments)
            case let .bar(series, axis):
                try c.encode("bar", forKey: .type)
                try c.encode(series, forKey: .series)
                try c.encode(axis, forKey: .axis_config)
            case let .area(series, axis):
                try c.encode("area", forKey: .type)
                try c.encode(series, forKey: .series)
                try c.encode(axis, forKey: .axis_config)
            case let .line(series, axis):
                try c.encode("line", forKey: .type)
                try c.encode(series, forKey: .series)
                try c.encode(axis, forKey: .axis_config)
            case let .unknown(type, raw):
                var fields = raw
                fields["type"] = .string(type)
                try JSONValue.object(fields).encode(to: encoder)
            }
        }

        /// One pie slice. `label` max 20; `value` must be > 0.
        public struct Segment: Codable, Equatable, Sendable {
            public var label: String
            public var value: Double

            public init(_ label: String, value: Double) {
                self.label = label
                self.value = value
            }
        }

        /// One bar/area/line series. `name` max 20, unique within the chart;
        /// exactly one point per `axis_config` category.
        public struct Series: Codable, Equatable, Sendable {
            public var name: String
            public var data: [DataPoint]

            public init(_ name: String, data: [DataPoint]) {
                self.name = name
                self.data = data
            }
        }

        /// One point. `label` must match an `axis_config` category;
        /// negative values are permitted.
        public struct DataPoint: Codable, Equatable, Sendable {
            public var label: String
            public var value: Double

            public init(_ label: String, value: Double) {
                self.label = label
                self.value = value
            }
        }

        /// Categories define the valid point labels and their display order.
        /// Each max 20 chars; axis labels max 50.
        public struct AxisConfig: Codable, Equatable, Sendable {
            public var categories: [String]
            public var x_label: String?
            public var y_label: String?

            public init(categories: [String], xLabel: String? = nil, yLabel: String? = nil) {
                self.categories = categories
                self.x_label = xLabel
                self.y_label = yLabel
            }
        }
    }

    /**
     Displays data as a pie, bar, area or line chart.

     ## Available in Surfaces
     - Messages

     - important: Maximum 2 `data_visualization` blocks per message.
     */
    public static func dataVisualization(title: String, chart: Chart) -> Block {
        var block = Block(type: "data_visualization")
        block.dataVisualization = DataVisualization(title: title, chart: chart)
        return block
    }
}
