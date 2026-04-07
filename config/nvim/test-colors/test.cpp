// Single-line comment
/*
 * Multi-line comment
 * C++ syntax showcase
 */

// Preprocessor directives
#include <algorithm>
#include <concepts>
#include <coroutine>
#include <format>
#include <iostream>
#include <memory>
#include <optional>
#include <span>
#include <string>
#include <unordered_map>
#include <variant>
#include <vector>

#define MAX_RETRIES 5
#define LOG(msg) std::cerr << "[LOG] " << (msg) << '\n'

// Namespace
namespace app {

// Constants
constexpr std::size_t BUFFER_SIZE = 4096;
constexpr double PI = 3.14159265358979;
static const std::string DEFAULT_HOST = "localhost";

// Enum class
enum class Status : uint8_t {
    Ok      = 0,
    Error   = 1,
    Timeout = 2,
};

// Concept (C++20)
template<typename T>
concept Numeric = std::integral<T> || std::floating_point<T>;

// Generic struct with constructor and member functions
template<typename K, typename V>
struct Cache {
    std::unordered_map<K, V> data;
    std::string label;

    // Constructor
    explicit Cache(std::string lbl) : label(std::move(lbl)) {}

    // Method with parameter
    void insert(K key, V value) {
        data[std::move(key)] = std::move(value);
    }

    std::optional<V> get(const K& key) const {
        if (auto it = data.find(key); it != data.end()) {
            return it->second;
        }
        return std::nullopt;
    }
};

// Class with inheritance, virtual, override
class Processor {
public:
    virtual ~Processor() = default;
    virtual std::string process(std::string_view input) = 0;
    virtual const char* name() const noexcept = 0;
};

class UpperProcessor : public Processor {
    int call_count_ = 0;  // field / property

public:
    explicit UpperProcessor() = default;

    std::string process(std::string_view input) override {
        ++call_count_;
        std::string out{input};
        std::ranges::transform(out, out.begin(), ::toupper);
        return out;
    }

    const char* name() const noexcept override { return "upper"; }
    int calls() const { return call_count_; }
};

// Template function with concept constraint
template<Numeric T>
T clamp(T value, T lo, T hi) {
    return (value < lo) ? lo : (value > hi) ? hi : value;
}

// Variant + visitor pattern
using Result = std::variant<std::string, int, std::nullptr_t>;

Result parse(const std::string& s) {
    try {
        return std::stoi(s);
    } catch (const std::invalid_argument&) {
        if (s.empty()) return nullptr;
        return s;
    }
}

// Lambda, structured bindings, string formatting
void demonstrate() {
    // Raw string literal
    const std::string raw = R"(raw\nstring with "quotes")";
    const std::string escaped = "tab\there\nnewline";
    const std::string fmt = std::format("PI = {:.4f}, MAX = {}", PI, MAX_RETRIES);

    auto proc = std::make_unique<UpperProcessor>();
    std::string out = proc->process("hello world");
    LOG(out);
    LOG(fmt);

    // Structured bindings + lambda
    Cache<std::string, int> cache{"scores"};
    cache.insert("alice", 42);
    cache.insert("bob", 99);

    auto scores = std::vector<std::pair<std::string, int>>{{"alice", 42}, {"bob", 99}};
    std::ranges::sort(scores, [](const auto& a, const auto& b) {
        return a.second > b.second;
    });

    for (const auto& [name, score] : scores) {
        std::cout << name << ": " << score << '\n';
    }

    // Optional chaining
    if (auto val = cache.get("alice"); val.has_value()) {
        std::cout << "alice score = " << *val << '\n';
    }

    // Operators: bitwise, arithmetic, pointer, ternary
    int x = 0xFF & (clamp(42, 0, 100) << 2);
    bool flag = (x != 0) && (x >= 10) || (x == -1);
    int* ptr = &x;
    *ptr += 1;

    // Visit variant
    Result r = parse("123");
    std::visit([](auto&& v) { std::cout << v << '\n'; }, r);

    (void)raw; (void)escaped; (void)flag;
}

}  // namespace app

int main() {
    app::demonstrate();
    return 0;
}
