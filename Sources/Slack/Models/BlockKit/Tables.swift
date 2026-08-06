//
//  Tables.swift
//  SlackKit
//
//  The `table` and `data_table` block families. Both are grids of cells;
//  `data_table` adds a caption, pagination, sorting and filtering.
//
//  Spec: docs/systems/comms/blockkit-spec-2026-08.md §1.
//  Budgets: `table` 10,000 chars across all cells per table and per message;
//  `data_table` 20,000. `table`: max 100 rows × 20 cells. `data_table`:
//  2–201 rows (first row is the header), 1–20 columns, all rows equal width;
//  `rich_text` cells are not allowed in the header row.
//

import Foundation

extension Block {

    /**
     One table cell — `raw_text`, `raw_number` or `rich_text`, with unknown
     cell kinds kept verbatim. The wire `type` is owned by this enum.

     Sorting in a `data_table` is alphabetical unless a column is entirely
     `raw_number` cells (numeric).
     */
    public enum Cell: Codable, Equatable, Sendable {

        case rawText(String)
        /// `value` drives numeric sorting; `text` is the display string.
        case rawNumber(value: Double, text: String)
        /// A standard rich text block value.
        case richText([RichTextElement])
        case unknown(type: String, raw: [String: JSONValue])

        private enum CodingKeys: String, CodingKey {
            case type, text, value, elements
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let type = try c.decode(String.self, forKey: .type)
            switch type {
            case "raw_text":
                self = .rawText(try c.decode(String.self, forKey: .text))
            case "raw_number":
                self = .rawNumber(value: try c.decode(Double.self, forKey: .value),
                                  text: try c.decode(String.self, forKey: .text))
            case "rich_text":
                self = .richText(try c.decode([RichTextElement].self, forKey: .elements))
            default:
                let raw = try JSONValue(from: decoder)
                self = .unknown(type: type, raw: raw.objectDropping(["type"]))
            }
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case let .rawText(text):
                try c.encode("raw_text", forKey: .type)
                try c.encode(text, forKey: .text)
            case let .rawNumber(value, text):
                try c.encode("raw_number", forKey: .type)
                try c.encode(value, forKey: .value)
                try c.encode(text, forKey: .text)
            case let .richText(elements):
                try c.encode("rich_text", forKey: .type)
                try c.encode(elements, forKey: .elements)
            case let .unknown(type, raw):
                var fields = raw
                fields["type"] = .string(type)
                try JSONValue.object(fields).encode(to: encoder)
            }
        }
    }

    /**
     Payload of a `table` block.

     `column_settings` is positional — fewer entries than columns leaves the
     rest default, and a `nil` entry skips that column.
     */
    public struct Table: Codable, Equatable, Sendable {

        public var rows: [[Cell]]
        public var column_settings: [ColumnSettings?]?

        public init(rows: [[Cell]], columnSettings: [ColumnSettings?]? = nil) {
            self.rows = rows
            self.column_settings = columnSettings
        }

        public struct ColumnSettings: Codable, Equatable, Sendable {
            public var align: Align?
            /// Default `false`.
            public var is_wrapped: Bool?

            public init(align: Align? = nil, isWrapped: Bool? = nil) {
                self.align = align
                self.is_wrapped = isWrapped
            }

            /// Tolerant like ``Block/Style``: an unlisted value decodes rather than throws.
            public struct Align: RawRepresentable, Codable, Equatable, Sendable {
                public let rawValue: String
                public init(rawValue: String) { self.rawValue = rawValue }

                public static let left = Align(rawValue: "left")
                public static let center = Align(rawValue: "center")
                public static let right = Align(rawValue: "right")
            }
        }

        private enum CodingKeys: String, CodingKey {
            case rows, column_settings
        }
    }

    /**
     Payload of a `data_table` block — a rich table with pagination,
     sorting, filtering and interactivity. The first row is the header.
     */
    public struct DataTable: Codable, Equatable, Sendable {

        public var rows: [[Cell]]
        /// Required by Slack; used as the HTML caption.
        public var caption: String
        /// Rows per page, 1–100. Slack default 5.
        public var page_size: Int?
        /// 0-based row-header column. Slack default 0.
        public var row_header_column_index: Int?

        public init(caption: String, rows: [[Cell]], pageSize: Int? = nil, rowHeaderColumnIndex: Int? = nil) {
            self.rows = rows
            self.caption = caption
            self.page_size = pageSize
            self.row_header_column_index = rowHeaderColumnIndex
        }

        private enum CodingKeys: String, CodingKey {
            case rows, caption, page_size, row_header_column_index
        }
    }

    /**
     Displays structured information in a table.

     ## Available in Surfaces
     - Messages (via `blocks` or `attachments`)
     */
    public static func table(rows: [[Cell]], columnSettings: [Table.ColumnSettings?]? = nil) -> Block {
        var block = Block(type: "table")
        block.table = Table(rows: rows, columnSettings: columnSettings)
        return block
    }

    /**
     Displays a rich table with pagination, sorting and filtering. The
     first row is the header (no `rich_text` cells there).

     ## Available in Surfaces
     - Messages
     */
    public static func dataTable(caption: String, rows: [[Cell]], pageSize: Int? = nil, rowHeaderColumnIndex: Int? = nil) -> Block {
        var block = Block(type: "data_table")
        block.dataTable = DataTable(caption: caption, rows: rows, pageSize: pageSize, rowHeaderColumnIndex: rowHeaderColumnIndex)
        return block
    }
}
