//go:build ignore

// Single-line comment
/*
 * Multi-line comment
 * Go syntax showcase
 */

// Package declaration
package main

// Imports
import (
	"context"
	"errors"
	"fmt"
	"math"
	"regexp"
	"strings"
	"sync"
	"time"
)

// Constants
const (
	MaxRetries  = 5
	DefaultPort = 8080
	Pi          = math.Pi
)

// Typed constant / iota enum
type Status int

const (
	StatusOK Status = iota
	StatusError
	StatusTimeout
)

func (s Status) String() string {
	switch s {
	case StatusOK:
		return "ok"
	case StatusError:
		return "error"
	case StatusTimeout:
		return "timeout"
	default:
		return "unknown"
	}
}

// Struct with tags (properties / fields)
type Config struct {
	Host    string   `json:"host"`
	Port    int      `json:"port"`
	Tags    []string `json:"tags,omitempty"`
	Timeout time.Duration
}

// Constructor function
func NewConfig(host string, port int) *Config {
	return &Config{
		Host:    host,
		Port:    port,
		Timeout: 30 * time.Second,
	}
}

// Method on struct (receiver = "self")
func (c *Config) Endpoint() string {
	return fmt.Sprintf("http://%s:%d", c.Host, c.Port)
}

// Interface
type Processor interface {
	Process(input string) (string, error)
	Name() string
}

// Struct implementing interface
type UpperProcessor struct {
	callCount int
}

func (p *UpperProcessor) Process(input string) (string, error) {
	if input == "" {
		return "", errors.New("empty input")
	}
	p.callCount++
	return strings.ToUpper(input), nil
}

func (p *UpperProcessor) Name() string { return "upper" }

// Generic function (Go 1.18+)
type Number interface {
	~int | ~int64 | ~float64
}

func Clamp[T Number](value, lo, hi T) T {
	if value < lo {
		return lo
	}
	if value > hi {
		return hi
	}
	return value
}

// Generic struct
type Queue[T any] struct {
	mu    sync.Mutex
	items []T
	label string
}

func NewQueue[T any](label string) *Queue[T] {
	return &Queue[T]{label: label}
}

func (q *Queue[T]) Push(item T) {
	q.mu.Lock()
	defer q.mu.Unlock()
	q.items = append(q.items, item)
}

func (q *Queue[T]) Pop() (T, bool) {
	q.mu.Lock()
	defer q.mu.Unlock()
	var zero T
	if len(q.items) == 0 {
		return zero, false
	}
	last := q.items[len(q.items)-1]
	q.items = q.items[:len(q.items)-1]
	return last, true
}

// Error wrapping
var ErrNotFound = errors.New("not found")

type AppError struct {
	Code    int
	Message string
	Err     error
}

func (e *AppError) Error() string {
	return fmt.Sprintf("code=%d: %s", e.Code, e.Message)
}
func (e *AppError) Unwrap() error { return e.Err }

// Async-style concurrency: goroutines + channels
func fetchAll(ctx context.Context, urls []string) <-chan string {
	out := make(chan string, len(urls))
	var wg sync.WaitGroup

	for _, url := range urls {
		wg.Add(1)
		go func(u string) {
			defer wg.Done()
			select {
			case <-ctx.Done():
				return
			case out <- fmt.Sprintf("fetched: %s", u):
			}
		}(url)
	}

	go func() {
		wg.Wait()
		close(out)
	}()
	return out
}

// Strings: raw, escaped, format verbs, regex
var (
	rawStr    = `raw\nstring with "quotes" and \t tabs`
	escaped   = "newline\n\ttab\t\"quoted\"\\"
	dateRegex = regexp.MustCompile(`^\d{4}-\d{2}-\d{2}$`)
)

// Operators: arithmetic, bitwise, comparison, short-circuit, address-of
func bitwiseDemo(a, b int) int {
	sum := a + b
	diff := a - b
	product := a * b
	quotient := a / max(b, 1)
	remainder := a % max(b, 1)
	shifted := sum >> 2
	masked := shifted & 0xFF
	flagged := masked | (1 << 3)
	_ = diff * product * quotient * remainder
	return flagged
}

func main() {
	cfg := NewConfig("localhost", DefaultPort)
	fmt.Println(cfg.Endpoint())

	proc := &UpperProcessor{}
	out, err := proc.Process("hello world")
	if err != nil {
		fmt.Println("error:", err)
		return
	}
	fmt.Println(out)

	q := NewQueue[int]("nums")
	for i := range 5 {
		q.Push(i * 2)
	}
	if val, ok := q.Pop(); ok {
		fmt.Println("popped:", val)
	}

	clamped := Clamp(150.0, 0.0, 100.0)
	fmt.Printf("clamped: %.1f\n", clamped)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	urls := []string{"https://example.com/a", "https://example.com/b"}
	for result := range fetchAll(ctx, urls) {
		fmt.Println(result)
	}

	fmt.Println(dateRegex.MatchString("2026-04-05"))
	fmt.Println(rawStr, escaped)
	fmt.Println(StatusOK, StatusTimeout)
	fmt.Println(bitwiseDemo(42, 7))
}
