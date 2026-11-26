/// 上限つきのリングバッファ。古いものから i 番目を O(1) で取る。ログに使う
public struct KodouRing<T> {
    private var buf: [T?]
    private var head = 0
    public private(set) var count = 0
    public let capacity: Int
    public init(capacity: Int) { self.capacity = capacity; buf = Array(repeating: nil, count: capacity) }
    public mutating func append(_ x: T) {
        buf[head] = x; head = (head + 1) % capacity
        if count < capacity { count += 1 }
    }
    /// i 番目に古いもの
    public subscript(i: Int) -> T { buf[(head - count + i + capacity) % capacity]! }
}
